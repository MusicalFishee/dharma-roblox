--!strict
-- Server authority for player melee: validates swings, finds targets, applies damage.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CollectionService = game:GetService("CollectionService")

local Net = require(ReplicatedStorage.Shared.Net)
local Combat = require(ReplicatedStorage.Shared.Combat)
local Progression = require(ReplicatedStorage.Shared.Progression)
local Shop = require(ReplicatedStorage.Shared.Shop)
local Weapons = require(ReplicatedStorage.Shared.Weapons)
local PlayerRegistry = require(script.Parent.PlayerRegistry)

local MELEE_REACH = 13 -- studs
local MELEE_ARC_DOT = 0.25 -- how forward-facing a target must be

export type EnemyTag = "DharmaEnemy"
local ENEMY_TAG: string = "DharmaEnemy"

local function getRoot(model: Model): BasePart?
	local root = model:FindFirstChild("HumanoidRootPart")
	if root and root:IsA("BasePart") then
		return root
	end
	return model.PrimaryPart
end

-- Returns living enemy Humanoids within reach and roughly in front of `fromRoot`.
local function findTargets(fromRoot: BasePart): { Humanoid }
	local origin = fromRoot.Position
	local forward = fromRoot.CFrame.LookVector

	local hits: { Humanoid } = {}
	for _, enemy in CollectionService:GetTagged(ENEMY_TAG) do
		if not enemy:IsA("Model") then
			continue
		end
		local humanoid = enemy:FindFirstChildOfClass("Humanoid")
		local root = getRoot(enemy)
		if not humanoid or not root or humanoid.Health <= 0 then
			continue
		end

		local offset = root.Position - origin
		local distance = offset.Magnitude
		if distance > MELEE_REACH then
			continue
		end
		if distance > 0.01 and forward:Dot(offset.Unit) < MELEE_ARC_DOT then
			continue
		end
		table.insert(hits, humanoid)
	end
	return hits
end

Net.AttackRequest.OnServerEvent:Connect(function(player: Player)
	local character = player.Character
	if not character then
		return
	end
	local root = getRoot(character)
	if not root then
		return
	end

	local state = PlayerRegistry.get(player)

	-- The chain decides light vs heavy and gates cadence / finisher recovery.
	local swing = state.chain:tryAdvance(os.clock())
	if not swing.accepted then
		return -- swinging too fast, or recovering after a finisher
	end
	local kind: Combat.AttackKind = if swing.kind == "Heavy" then "Heavy" else "Light"

	-- Everyone sees the swing (combo1..combo4).
	Net.AnimEvent:FireAllClients(character, "combo" .. math.clamp(swing.index, 1, 4))

	local targets = findTargets(root)
	if #targets == 0 then
		Net.CombatFeedback:FireClient(player, { outcome = "Whiff", chain = swing.index })
		return
	end

	local comboCount = state.combo:registerHit(os.clock())
	local level = Progression.resolve(state.totalXp).level
	local isCrit = Combat.rollCrit()
	local damage = Combat.critDamage(
		Combat.computeAttackDamage(kind, comboCount - 1)
			* Progression.damageMultiplierForLevel(level)
			* Shop.damageMult(state.upgrades.damage)
			* Weapons.damageMult(state.weapon.id, state.weapon.tier),
		isCrit
	)

	for _, humanoid in targets do
		-- Tag the enemy with who hit it so it can grant XP on death.
		local enemyModel = humanoid.Parent
		if enemyModel and enemyModel:IsA("Model") then
			enemyModel:SetAttribute("LastAttacker", player.UserId)
			Net.AnimEvent:FireAllClients(enemyModel, "flinch")
		end

		humanoid:TakeDamage(damage)
		state.tejas = Combat.clampTejas(state.tejas + Combat.Config.TejasPerHitLanded)

		-- The heavy finisher knocks enemies back.
		local hrp = humanoid.RootPart
		if swing.isFinisher and hrp then
			local dir = hrp.Position - root.Position
			dir = Vector3.new(dir.X, 0, dir.Z)
			dir = if dir.Magnitude > 0.01 then dir.Unit else root.CFrame.LookVector
			hrp.AssemblyLinearVelocity = dir * 60 + Vector3.new(0, 30, 0)
		end
	end

	Net.CombatFeedback:FireClient(player, {
		outcome = "Hit",
		kind = kind,
		combo = comboCount,
		chain = swing.index,
		isFinisher = swing.isFinisher,
		isCrit = isCrit,
		damage = damage,
		tejas = state.tejas,
	})
end)

Net.DefenseState.OnServerEvent:Connect(function(player: Player, data: any)
	if typeof(data) ~= "table" then
		return
	end
	local state = PlayerRegistry.get(player)
	local char = player.Character

	if data.isBlocking ~= nil then
		state.isBlocking = data.isBlocking == true
		if state.isBlocking then
			state.blockStartedAt = os.clock()
		end
		if char then
			Net.AnimEvent:FireAllClients(char, if state.isBlocking then "blockstart" else "blockend")
		end
	end

	if data.dodge == true then
		state.dodgeUntil = os.clock() + Combat.Config.ParryWindowSeconds -- brief i-frames
		if char then
			Net.AnimEvent:FireAllClients(char, "dash")
		end
	end
end)

-- Player-leave state cleanup is owned by DataService (it saves *before* removing).

print("[Dharma] CombatService ready.")
