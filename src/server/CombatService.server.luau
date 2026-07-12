--!strict
-- Server authority for player melee: validates swings, finds targets, applies damage.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CollectionService = game:GetService("CollectionService")

local Net = require(ReplicatedStorage.Shared.Net)
local Combat = require(ReplicatedStorage.Shared.Combat)
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

Net.AttackRequest.OnServerEvent:Connect(function(player: Player, kindArg: any)
	local kind: Combat.AttackKind = "Light"
	if kindArg == "Heavy" then
		kind = "Heavy"
	end

	local character = player.Character
	if not character then
		return
	end
	local root = getRoot(character)
	if not root then
		return
	end

	local targets = findTargets(root)
	if #targets == 0 then
		-- A whiff still costs the swing but breaks nothing.
		Net.CombatFeedback:FireClient(player, {
			outcome = "Whiff",
			combo = 0,
		})
		return
	end

	local state = PlayerRegistry.get(player)
	local comboCount = state.combo:registerHit(os.clock())
	local damage = Combat.computeAttackDamage(kind, comboCount - 1)

	for _, humanoid in targets do
		humanoid:TakeDamage(damage)
		state.tejas = Combat.clampTejas(state.tejas + Combat.Config.TejasPerHitLanded)
	end

	Net.CombatFeedback:FireClient(player, {
		outcome = "Hit",
		kind = kind,
		combo = comboCount,
		damage = damage,
		tejas = state.tejas,
	})
end)

Net.DefenseState.OnServerEvent:Connect(function(player: Player, data: any)
	if typeof(data) ~= "table" then
		return
	end
	local state = PlayerRegistry.get(player)
	state.isBlocking = data.isBlocking == true
	if state.isBlocking then
		state.blockStartedAt = os.clock()
	end
	if data.dodge == true then
		state.dodgeUntil = os.clock() + Combat.Config.ParryWindowSeconds -- brief i-frames
	end
end)

game:GetService("Players").PlayerRemoving:Connect(PlayerRegistry.remove)

print("[Dharma] CombatService ready.")
