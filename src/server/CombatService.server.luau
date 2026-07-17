--!strict
-- Server authority for player melee: validates swings, finds targets, applies damage.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CollectionService = game:GetService("CollectionService")

local Net = require(ReplicatedStorage.Shared.Net)
local Combat = require(ReplicatedStorage.Shared.Combat)
local Progression = require(ReplicatedStorage.Shared.Progression)
local Shop = require(ReplicatedStorage.Shared.Shop)
local Weapons = require(ReplicatedStorage.Shared.Weapons)
local Paths = require(ReplicatedStorage.Shared.Paths)
local Relics = require(ReplicatedStorage.Shared.Relics)
local Vara = require(ReplicatedStorage.Shared.Vara)
local Enchants = require(ReplicatedStorage.Shared.Enchants)
local StatusEffects = require(ReplicatedStorage.Shared.StatusEffects)
local PvP = require(ReplicatedStorage.Shared.PvP)
local PlayerRegistry = require(script.Parent.PlayerRegistry)
local PvPService = require(script.Parent.PvPService)
local EnemyService = require(script.Parent.EnemyService)

local Debris = game:GetService("Debris")

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
local function findTargets(fromRoot: BasePart, reachBonus: number): { Humanoid }
	local origin = fromRoot.Position
	local forward = fromRoot.CFrame.LookVector
	local reach = MELEE_REACH + reachBonus

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
		if distance > reach then
			continue
		end
		if distance > 0.01 and forward:Dot(offset.Unit) < MELEE_ARC_DOT then
			continue
		end
		table.insert(hits, humanoid)
	end
	return hits
end

-- Agni's Kiss: a burn that ticks on the enemy for a few seconds. One burn at a time
-- per enemy; the flame visual rides on the enemy so everyone sees who's alight.
local function igniteEnemy(model: Model, humanoid: Humanoid, totalDamage: number, seconds: number)
	if model:GetAttribute("Burning") == true then
		return
	end
	model:SetAttribute("Burning", true)
	local root = getRoot(model)
	if root then
		local flame = Instance.new("Fire")
		flame.Size = 4
		flame.Heat = 8
		flame.Color = Color3.fromRGB(255, 120, 30)
		flame.SecondaryColor = Color3.fromRGB(140, 40, 10)
		flame.Parent = root
		Debris:AddItem(flame, seconds)
	end
	task.spawn(function()
		local ticks = math.max(1, math.floor(seconds))
		for _ = 1, ticks do
			task.wait(1)
			if humanoid.Health <= 0 or not model.Parent then
				break
			end
			humanoid:TakeDamage(totalDamage / ticks)
		end
		model:SetAttribute("Burning", nil)
	end)
end

-- Sudarshana's Storm: sky-fire crashes down on the struck enemy.
local function skyFire(targetRoot: BasePart, humanoid: Humanoid, damage: number)
	humanoid:TakeDamage(damage)
	local bolt = Instance.new("Part")
	bolt.Anchored = true
	bolt.CanCollide = false
	bolt.CanQuery = false
	bolt.Material = Enum.Material.Neon
	bolt.Color = Color3.fromRGB(150, 220, 255)
	bolt.Size = Vector3.new(0.6, 42, 0.6)
	bolt.CFrame = CFrame.new(targetRoot.Position + Vector3.new(0, 21, 0))
	bolt.Parent = workspace
	Debris:AddItem(bolt, 0.25)
	-- The crack outlives the flash, so it rides the enemy, not the bolt.
	local crack = Instance.new("Sound")
	crack.SoundId = "rbxasset://sounds/glassbreak.wav"
	crack.Volume = 0.7
	crack.PlaybackSpeed = 0.5
	crack.RollOffMaxDistance = 150
	crack.Parent = targetRoot
	crack:Play()
	Debris:AddItem(crack, 3)
end

Net.AttackRequest.OnServerEvent:Connect(function(player: Player)
	local character = player.Character
	if not character or character:GetAttribute("DharmaDowned") == true or character:GetAttribute("DharmaBhoota") == true then
		return -- the downed crawl; they do not swing
	end
	local root = getRoot(character)
	if not root then
		return
	end

	local state = PlayerRegistry.get(player)
	local sig = Weapons.signatureOf(state.weapon.id)

	-- The chain decides light vs heavy and gates cadence / finisher recovery.
	local swing = state.chain:tryAdvance(os.clock())
	if not swing.accepted then
		return -- swinging too fast, or recovering after a finisher
	end
	local kind: Combat.AttackKind = if swing.kind == "Heavy" then "Heavy" else "Light"

	-- Everyone sees the swing (combo1..combo4).
	Net.AnimEvent:FireAllClients(character, "combo" .. math.clamp(swing.index, 1, 4))

	local targets = findTargets(root, sig.reachBonus)

	-- A live duel foe within reach and arc is also a valid target.
	local foe = PvPService.duelOpponentOf(player)
	local foeRoot: BasePart? = nil
	local foeHum: Humanoid? = nil
	if foe then
		local fchar = foe.Character
		local fr = fchar and getRoot(fchar)
		local fh = fchar and fchar:FindFirstChildOfClass("Humanoid")
		if fr and fh and fh.Health > 0 then
			local offset = fr.Position - root.Position
			local d = offset.Magnitude
			if d <= MELEE_REACH and (d <= 0.01 or root.CFrame.LookVector:Dot(offset.Unit) >= MELEE_ARC_DOT) then
				foeRoot, foeHum = fr, fh
			end
		end
	end

	if #targets == 0 and not foeHum then
		Net.CombatFeedback:FireClient(player, { outcome = "Whiff", chain = swing.index })
		return
	end

	local comboCount = state.combo:registerHit(os.clock())
	local level = Progression.resolve(state.totalXp).level
	local ench = Enchants.effects(state.enchant)
	local passive = Paths.passiveOf(state.path)
	local relicBonus = Relics.totalBonus(Relics.equippedList(state.relics.equipped))
	local varaFx = Vara.totalEffects(state.vara)
	local isCrit = Combat.rollCrit(nil, (ench.critChanceBonus or 0) + relicBonus.critChance + varaFx.critChance)
	-- Static Ward and kin: an active empower scales everything dealt while it lasts.
	local empower = if os.clock() < state.empowerUntil then state.empowerMult else 1
	local damage = Combat.critDamage(
		Combat.computeAttackDamage(kind, comboCount - 1)
			* Progression.damageMultiplierForLevel(level)
			* Shop.damageMult(state.upgrades.damage)
			* Weapons.damageMult(state.weapon.id, state.weapon.tier)
			* passive.damageMult
			* relicBonus.damageMult
			* varaFx.damageMult
			* empower,
		isCrit,
		(ench.critMultiplier or Combat.Config.CritMultiplier) + sig.critDamageBonus
	)

	local healed = 0
	local anyExecuted = false
	for _, humanoid in targets do
		-- Tag the enemy with who hit it so it can grant XP on death.
		local enemyModel = humanoid.Parent
		if enemyModel and enemyModel:IsA("Model") then
			enemyModel:SetAttribute("LastAttacker", player.UserId)
			Net.AnimEvent:FireAllClients(enemyModel, "flinch")
		end

		-- Yama's Ledger: a non-boss left below the threshold is claimed outright.
		local dealt = damage
		if
			ench.executeThreshold
			and enemyModel
			and enemyModel:GetAttribute("IsBoss") ~= true
			and humanoid.Health - damage <= humanoid.MaxHealth * ench.executeThreshold
		then
			dealt = humanoid.Health
			if humanoid.Health > damage then
				anyExecuted = true -- the ledger did the killing, not the swing
			end
		end

		humanoid:TakeDamage(dealt)
		state.tejas = Combat.clampTejas(state.tejas + (Combat.Config.TejasPerHitLanded + sig.tejasPerHitBonus) * (ench.tejasMult or 1) * passive.tejasMult * relicBonus.tejasMult * varaFx.tejasMult)

		if ench.lifesteal then
			healed += dealt * ench.lifesteal
		end
		if varaFx.lifesteal > 0 then
			healed += dealt * varaFx.lifesteal -- Rakta: the boon drinks alongside the mantra
		end
		if ench.burnDamage and humanoid.Health > 0 and enemyModel and enemyModel:IsA("Model") then
			igniteEnemy(enemyModel, humanoid, ench.burnDamage, ench.burnSeconds or 3)
		end
		if ench.procChance and humanoid.Health > 0 and math.random() < ench.procChance then
			local eroot = humanoid.RootPart
			if eroot then
				skyFire(eroot, humanoid, ench.procDamage or 0)
			end
		end

		-- The heavy finisher knocks enemies back.
		local hrp = humanoid.RootPart
		if swing.isFinisher and hrp then
			local dir = hrp.Position - root.Position
			dir = Vector3.new(dir.X, 0, dir.Z)
			dir = if dir.Magnitude > 0.01 then dir.Unit else root.CFrame.LookVector
			hrp.AssemblyLinearVelocity = dir * 60 * sig.finisherKnockbackMult + Vector3.new(0, 30 * sig.finisherKnockbackMult, 0)
		end
	end

	-- The duel foe: softened damage through the SAME defense pipeline — they can
	-- dodge, block, and parry you. Mantras' PvE teeth (burn/execute/lifesteal/proc)
	-- stay out of duels; this is a contest of skill, not of luck.
	if foe and foeRoot and foeHum then
		EnemyService.resolveHitOnPlayer(foe, foeRoot, foeHum, damage * PvP.Config.DamageMult, root.Position, nil)
		state.tejas = Combat.clampTejas(state.tejas + Combat.Config.TejasPerHitLanded * (ench.tejasMult or 1) * passive.tejasMult * relicBonus.tejasMult)
		if swing.isFinisher then
			local dir = foeRoot.Position - root.Position
			dir = Vector3.new(dir.X, 0, dir.Z)
			dir = if dir.Magnitude > 0.01 then dir.Unit else root.CFrame.LookVector
			foeRoot.AssemblyLinearVelocity = dir * 60 + Vector3.new(0, 30, 0)
		end
	end

	-- Rakta Thirst: drink back a share of everything dealt (curses thin the draught).
	if healed > 0 then
		local myHum = character:FindFirstChildOfClass("Humanoid")
		if myHum and myHum.Health > 0 then
			local amount = StatusEffects.effectiveHeal(healed, os.clock() < state.curseUntil)
			myHum.Health = math.min(myHum.MaxHealth, myHum.Health + amount)
		end
	end

	Net.CombatFeedback:FireClient(player, {
		outcome = "Hit",
		kind = kind,
		combo = comboCount,
		chain = swing.index,
		isFinisher = swing.isFinisher,
		isCrit = isCrit,
		executed = anyExecuted,
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
		-- Brief i-frames; Vayu's Grace (mantra) and the Path of Vayu both stretch them.
		local ench = Enchants.effects(state.enchant)
		state.dodgeUntil = os.clock()
			+ Combat.Config.ParryWindowSeconds * (1 + (ench.dodgeBonus or 0))
			+ Paths.passiveOf(state.path).dodgeBonusSeconds
			+ Vara.totalEffects(state.vara).dodgeBonusSeconds
		if char then
			Net.AnimEvent:FireAllClients(char, "dash")
		end
	end
end)

-- Player-leave state cleanup is owned by DataService (it saves *before* removing).

print("[Dharma] CombatService ready.")
