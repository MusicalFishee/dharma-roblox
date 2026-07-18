--!strict
-- Enemy engine (module): the wave system asks it to spawn enemies; it runs their
-- AI, applies their strikes, grants XP on death, and reports deaths back.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CollectionService = game:GetService("CollectionService")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Players = game:GetService("Players")
local Debris = game:GetService("Debris")

local Net = require(ReplicatedStorage.Shared.Net)
local Combat = require(ReplicatedStorage.Shared.Combat)
local Progression = require(ReplicatedStorage.Shared.Progression)
local EnemyAI = require(ReplicatedStorage.Shared.EnemyAI)
local EnemyTypes = require(ReplicatedStorage.Shared.EnemyTypes)
local BossSpecials = require(ReplicatedStorage.Shared.BossSpecials)
local Enchants = require(ReplicatedStorage.Shared.Enchants)
local Paths = require(ReplicatedStorage.Shared.Paths)
local Vira = require(ReplicatedStorage.Shared.Vira)
local Affixes = require(ReplicatedStorage.Shared.Affixes)
local Vara = require(ReplicatedStorage.Shared.Vara)
local Weapons = require(ReplicatedStorage.Shared.Weapons)
local Loot = require(ReplicatedStorage.Shared.Loot)
local StatusEffects = require(ReplicatedStorage.Shared.StatusEffects)
local Relics = require(ReplicatedStorage.Shared.Relics)
local PlayerRegistry = require(script.Parent.PlayerRegistry)
local ProgressionService = require(script.Parent.ProgressionService)
local LootService = require(script.Parent.LootService)
local QuestService = require(script.Parent.QuestService)
local RelicService = require(script.Parent.RelicService)
local StoryService = require(script.Parent.StoryService)

local ENEMY_TAG = "DharmaEnemy"

local EnemyService = {}

type EnemyState = {
	model: Model,
	humanoid: Humanoid,
	root: BasePart,
	archetype: EnemyTypes.EnemyArchetype,
	nextAttackAt: number,
	staggeredUntil: number,
	castingUntil: number,
	onDeath: ((Player?) -> ())?,
}

local enemies: { [Model]: EnemyState } = {}
local alive = 0

local function broadcastAll(data: { [string]: any })
	for _, p in Players:GetPlayers() do
		Net.CombatFeedback:FireClient(p, data)
	end
end

local function getRoot(model: Model): BasePart?
	local root = model:FindFirstChild("HumanoidRootPart")
	if root and root:IsA("BasePart") then
		return root
	end
	return model.PrimaryPart
end

local function nearestPlayer(pos: Vector3): (Player?, BasePart?, Humanoid?, number)
	local bestPlayer: Player? = nil
	local bestRoot: BasePart? = nil
	local bestHum: Humanoid? = nil
	local bestDist = math.huge

	for _, player in Players:GetPlayers() do
		local char = player.Character
		if not char then
			continue
		end
		local root = getRoot(char)
		local hum = char:FindFirstChildOfClass("Humanoid")
		if not root or not hum or hum.Health <= 0 then
			continue
		end
		if char:GetAttribute("DharmaDowned") == true or char:GetAttribute("DharmaBhoota") == true or char:GetAttribute("DharmaDhyana") == true then
			continue -- the fallen and the still are beneath the horde's notice
		end
		local d = (root.Position - pos).Magnitude
		if d < bestDist then
			bestDist = d
			bestPlayer = player
			bestRoot = root
			bestHum = hum
		end
	end

	return bestPlayer, bestRoot, bestHum, bestDist
end

local function facingDot(fromRoot: BasePart, targetPos: Vector3): number
	local offset = targetPos - fromRoot.Position
	if offset.Magnitude < 0.01 then
		return 1
	end
	return fromRoot.CFrame.LookVector:Dot(offset.Unit)
end

-- Shared incoming-hit pipeline (melee blows and arrow impacts alike): reads the
-- defender's dodge/block state, resolves, applies damage/tejas/mantra soaks, quests
-- the parry, and toasts the outcome. Returns the resolution for attacker-side effects.
-- Envenom a player: a short DoT with a sickly green flame. A fresh bite while
-- already poisoned is wasted (no stacking).
local function applyVenom(player: Player, playerHum: Humanoid)
	local pstate = PlayerRegistry.get(player)
	local now = os.clock()
	if now < pstate.venomUntil then
		return
	end
	pstate.venomUntil = now + StatusEffects.Venom.seconds

	local char = player.Character
	local root = char and getRoot(char)
	if root then
		local sick = Instance.new("Fire")
		sick.Size = 3
		sick.Heat = 2
		sick.Color = Color3.fromRGB(110, 255, 110)
		sick.SecondaryColor = Color3.fromRGB(30, 90, 30)
		sick.Parent = root
		Debris:AddItem(sick, StatusEffects.Venom.seconds)
	end
	Net.CombatFeedback:FireClient(player, { statusEffect = "venom", seconds = StatusEffects.Venom.seconds })

	task.spawn(function()
		for _ = 1, StatusEffects.Venom.seconds do
			task.wait(1)
			if playerHum.Health <= 0 or not playerHum.Parent then
				break
			end
			playerHum:TakeDamage(StatusEffects.venomTick())
		end
	end)
end

-- Curse a player: healing halved while it lasts (heal paths read curseUntil).
local function applyCurse(player: Player)
	local pstate = PlayerRegistry.get(player)
	pstate.curseUntil = os.clock() + StatusEffects.Curse.seconds
	Net.CombatFeedback:FireClient(player, { statusEffect = "curse", seconds = StatusEffects.Curse.seconds })
end

local function resolveHitOnPlayer(
	player: Player,
	playerRoot: BasePart,
	playerHum: Humanoid,
	damage: number,
	attackerPos: Vector3,
	inflicts: string?
): Combat.Resolution
	local pstate = PlayerRegistry.get(player)
	local now = os.clock()

	local state = {
		isDodging = now < pstate.dodgeUntil,
		isBlocking = pstate.isBlocking,
		blockAgeSeconds = now - pstate.blockStartedAt,
		facingAttacker = facingDot(playerRoot, attackerPos) > 0.1,
	}

	local resolution = Combat.resolveIncomingAttack(damage, state)
	local ench = Enchants.effects(pstate.enchant)
	local relicBonus = Relics.totalBonus(Relics.equippedList(pstate.relics.equipped))
	local varaFx = Vara.totalEffects(pstate.vara)

	if resolution.damage > 0 then
		-- Stoneskin Sutra and kin: the defender's mantra soaks part of the blow;
		-- an active shield ward (Zephyr Veil) and worn relics soak their share on top.
		local ward = if now < pstate.wardUntil then pstate.wardMult else 1
		playerHum:TakeDamage(resolution.damage * (ench.damageTakenMult or 1) * ward * relicBonus.damageTakenMult * varaFx.damageTakenMult * Weapons.signatureOf(pstate.weapon.id).damageTakenMult)
		local char = player.Character
		if char and resolution.outcome == "Hit" then
			Net.AnimEvent:FireAllClients(char, "flinch")
		end
	end
	if resolution.defenderTejasGain > 0 then
		local pmax = Progression.maxTejasForLevel(Progression.resolve(pstate.totalXp).level)
		pstate.tejas = Combat.clampTejas(pstate.tejas + resolution.defenderTejasGain * (ench.tejasMult or 1) * Paths.passiveOf(pstate.path).tejasMult * relicBonus.tejasMult * varaFx.tejasMult, pmax)
	end
	if resolution.outcome == "Parry" then
		pstate.waveParries += 1
		QuestService.onParry(player)
		if resolution.isPerfect then
			pstate.riposteUntil = now + 2.5
			Net.CombatFeedback:FireClient(player, { perfectParry = true })
		end
	elseif resolution.outcome == "Hit" then
		pstate.waveTimesHit += 1
	end

	-- A clean HIT delivers the striker's affliction; any defense wards it off.
	if resolution.outcome == "Hit" and inflicts then
		if inflicts == "venom" then
			applyVenom(player, playerHum)
		elseif inflicts == "curse" then
			applyCurse(player)
		end
	end

	Net.CombatFeedback:FireClient(player, {
		outcome = resolution.outcome,
		incoming = true,
		tejas = pstate.tejas,
	})
	return resolution
end

-- Exposed so bespoke encounters (the Kirata Trial) share the exact same defense rules.
EnemyService.resolveHitOnPlayer = resolveHitOnPlayer

-- SHIELDED affix: returns true if this blow clinks off the ward (a charge is
-- spent; the glow shatters with the last one). Astra REACTIONS pierce shields
-- by simply never calling this.
function EnemyService.absorbShield(model: Model): boolean
	local charges = model:GetAttribute("AffixShield")
	if typeof(charges) ~= "number" or charges <= 0 then
		return false
	end
	model:SetAttribute("AffixShield", charges - 1)
	if charges - 1 <= 0 then
		local glow = model:FindFirstChild("AffixGlow")
		if glow then
			glow:Destroy()
		end
	end
	return true
end

local function enemyStrikes(enemy: EnemyState, player: Player, playerRoot: BasePart, playerHum: Humanoid)
	-- Everyone sees the wind-up haymaker.
	Net.AnimEvent:FireAllClients(enemy.model, "enemySwing")

	local resolution =
		resolveHitOnPlayer(player, playerRoot, playerHum, enemy.archetype.attackDamage, enemy.root.Position, enemy.archetype.inflicts)
	if resolution.attackerStaggered then
		enemy.staggeredUntil = os.clock() + 1.0
		enemy.humanoid:MoveTo(enemy.root.Position)
	end
end

-- Ranged strike: loose a visible arrow at where the target stands NOW. It flies in
-- real time — step out of its path and it thuds into the dirt. Impacts run through
-- the same defense pipeline (yes, you can parry an arrow).
local function rangedStrikes(enemy: EnemyState, player: Player, playerRoot: BasePart)
	local a = enemy.archetype
	Net.AnimEvent:FireAllClients(enemy.model, "throw")

	local origin = enemy.root.Position + Vector3.new(0, 1.5, 0)
	local targetPos = playerRoot.Position
	local speed = a.projectileSpeed or 70
	local flight = (targetPos - origin).Magnitude / speed

	local arrow = Instance.new("Part")
	arrow.Anchored = true
	arrow.CanCollide = false
	arrow.CanQuery = false
	arrow.CanTouch = false
	arrow.Material = Enum.Material.Neon
	arrow.Color = Color3.fromRGB(255, 190, 90)
	arrow.Size = Vector3.new(0.25, 0.25, 3)
	arrow.CFrame = CFrame.lookAt(origin, targetPos)
	arrow.Parent = workspace
	TweenService:Create(arrow, TweenInfo.new(flight, Enum.EasingStyle.Linear), {
		CFrame = CFrame.lookAt(targetPos, targetPos + (targetPos - origin)),
	}):Play()
	Debris:AddItem(arrow, flight + 0.1)

	task.delay(flight, function()
		local char = player.Character
		local root = char and getRoot(char)
		local hum = char and char:FindFirstChildOfClass("Humanoid")
		if not char or not root or not hum or hum.Health <= 0 or char:GetAttribute("DharmaDowned") == true or char:GetAttribute("DharmaBhoota") == true then
			return
		end
		if (root.Position - targetPos).Magnitude > 6 then
			return -- they moved; the arrow misses
		end
		resolveHitOnPlayer(player, root, hum, a.attackDamage, origin, a.inflicts)
	end)
end

local function stepEnemy(enemy: EnemyState)
	local now = os.clock()
	if now < enemy.staggeredUntil or now < enemy.castingUntil then
		return -- staggered by a parry, or winding up a special
	end

	local player, playerRoot, playerHum, dist = nearestPlayer(enemy.root.Position)
	local a = enemy.archetype

	local action = EnemyAI.decide({
		distance = dist,
		aggroRange = a.aggroRange,
		attackRange = a.attackRange,
		attackReady = now >= enemy.nextAttackAt,
		targetAlive = player ~= nil,
		retreatRange = a.retreatRange,
	})

	if action == "Chase" and playerRoot then
		enemy.humanoid:MoveTo(playerRoot.Position)
	elseif action == "Retreat" and playerRoot then
		-- Kite away from the crowding target.
		local away = enemy.root.Position - playerRoot.Position
		away = Vector3.new(away.X, 0, away.Z)
		away = if away.Magnitude > 0.01 then away.Unit else Vector3.new(0, 0, 1)
		enemy.humanoid:MoveTo(enemy.root.Position + away * 14)
	elseif action == "Attack" and player and playerRoot and playerHum then
		enemy.nextAttackAt = now + a.attackInterval
		if a.ranged then
			rangedStrikes(enemy, player, playerRoot)
		else
			enemyStrikes(enemy, player, playerRoot, playerHum)
		end
	end
end

function EnemyService.aliveCount(): number
	return alive
end

function EnemyService.spawn(archetype: EnemyTypes.EnemyArchetype, position: Vector3, onDeath: ((Player?) -> ())?)
	local skin = Color3.fromRGB(archetype.skin[1], archetype.skin[2], archetype.skin[3])

	local ok, model = pcall(function()
		local desc = Instance.new("HumanoidDescription")
		desc.HeadColor = skin
		desc.TorsoColor = skin
		desc.LeftArmColor = skin
		desc.RightArmColor = skin
		desc.LeftLegColor = skin
		desc.RightLegColor = skin
		return Players:CreateHumanoidModelFromDescription(desc, Enum.HumanoidRigType.R15)
	end)

	if not ok or typeof(model) ~= "Instance" or not model:IsA("Model") then
		warn("[Dharma] Failed to create enemy rig: " .. tostring(model))
		if onDeath then
			onDeath(nil) -- don't stall the wave on a failed spawn
		end
		return
	end

	local humanoid = model:FindFirstChildOfClass("Humanoid")
	local root = getRoot(model)
	if not humanoid or not root then
		model:Destroy()
		if onDeath then
			onDeath(nil)
		end
		return
	end

	humanoid.MaxHealth = archetype.maxHealth
	humanoid.Health = archetype.maxHealth
	humanoid.WalkSpeed = archetype.walkSpeed
	humanoid.DisplayName = archetype.displayName
	local affixDef = if (archetype :: any).affix then Affixes.get((archetype :: any).affix) else nil
	if affixDef then
		humanoid.DisplayName = affixDef.name .. " " .. archetype.displayName
	end

	pcall(function()
		model:ScaleTo(archetype.scale)
	end)

	model:PivotTo(CFrame.new(position))
	model.Name = archetype.displayName
	model:SetAttribute("IsBoss", archetype.isBoss == true) -- read by CombatService (executes never claim bosses)
	if affixDef then
		model:SetAttribute("Affix", affixDef.id)
		if affixDef.shieldCharges then
			model:SetAttribute("AffixShield", affixDef.shieldCharges)
		end
		local mark = Instance.new("Highlight")
		mark.Name = "AffixGlow"
		mark.FillColor = Color3.fromRGB(affixDef.glow[1], affixDef.glow[2], affixDef.glow[3])
		mark.FillTransparency = 0.8
		mark.OutlineColor = Color3.fromRGB(affixDef.glow[1], affixDef.glow[2], affixDef.glow[3])
		mark.OutlineTransparency = 0.1
		mark.Parent = model
	end
	if (archetype :: any).isTwinChild then
		model:SetAttribute("TwinChild", true)
	end
	model.Parent = workspace
	CollectionService:AddTag(model, ENEMY_TAG)

	-- Elites burn gold so you can spot the threat (and the payday) at a glance.
	if archetype.isElite then
		local glow = Instance.new("Highlight")
		glow.FillColor = Color3.fromRGB(255, 200, 40)
		glow.FillTransparency = 0.75
		glow.OutlineColor = Color3.fromRGB(255, 220, 90)
		glow.OutlineTransparency = 0.2
		glow.Parent = model
	end

	enemies[model] = {
		model = model,
		humanoid = humanoid,
		root = root,
		archetype = archetype,
		nextAttackAt = 0,
		staggeredUntil = 0,
		castingUntil = 0,
		onDeath = onDeath,
	}
	alive += 1

	-- Bosses drive the on-screen health bar.
	if archetype.isBoss then
		local maxHp = archetype.maxHealth
		broadcastAll({
			bossState = "spawn",
			bossName = archetype.displayName,
			bossTitle = archetype.title,
			bossHealth = maxHp,
			bossMaxHealth = maxHp,
		})
		humanoid.HealthChanged:Connect(function(health: number)
			broadcastAll({ bossState = "health", bossHealth = math.max(0, health), bossMaxHealth = maxHp })
		end)

		-- Telegraphed special on a cooldown: wind up (boss halts), then AoE the danger zone.
		-- Self-centered slam, or — for hunters — dropped on the nearest player's feet.
		local special = BossSpecials.forBoss(archetype.id)
		task.spawn(function()
			while enemies[model] and humanoid.Health > 0 do
				task.wait(special.cooldown)
				local st = enemies[model]
				if not st or humanoid.Health <= 0 then
					break
				end

				local nearP, nearRoot, _h, dist = nearestPlayer(st.root.Position)
				if not nearP or dist > special.radius + 55 then
					continue -- nobody close enough to bother
				end

				local now = os.clock()
				st.castingUntil = now + special.telegraph

				-- Blast centre: the hunter marks YOUR position; slammers use their own.
				local centerPos = if special.targetPlayer and nearRoot then nearRoot.Position else st.root.Position
				local cx, cy, cz = centerPos.X, st.root.Position.Y - 2.5, centerPos.Z

				-- Windup: arms to the sky (also gives the warn sound via AnimSounds).
				Net.AnimEvent:FireAllClients(model, "ult")
				broadcastAll({
					bossSpecial = "telegraph",
					name = special.name,
					x = cx,
					y = cy,
					z = cz,
					radius = special.radius,
					duration = special.telegraph,
				})

				task.wait(special.telegraph)
				if humanoid.Health <= 0 then
					break
				end

				-- Impact: slam animation + boom, then resolve everyone in the zone.
				Net.AnimEvent:FireAllClients(model, "combo4")
				broadcastAll({ bossSpecial = "impact", x = cx, y = cy, z = cz, radius = special.radius })

				local boom = Instance.new("Part")
				boom.Anchored = true
				boom.CanCollide = false
				boom.CanQuery = false
				boom.Transparency = 1
				boom.Size = Vector3.new(1, 1, 1)
				boom.Position = Vector3.new(cx, cy + 2, cz)
				boom.Parent = workspace
				local boomSound = Instance.new("Sound")
				boomSound.SoundId = "rbxasset://sounds/bass.wav"
				boomSound.Volume = 1
				boomSound.PlaybackSpeed = 0.4
				boomSound.RollOffMaxDistance = 200
				boomSound.Parent = boom
				boomSound:Play()
				game:GetService("Debris"):AddItem(boom, 3)

				local targets: { BossSpecials.Target } = {}
				for _, plr in Players:GetPlayers() do
					local char = plr.Character
					if not char then
						continue
					end
					local hrp = char:FindFirstChild("HumanoidRootPart")
					if hrp and hrp:IsA("BasePart") then
						table.insert(targets, { key = plr, x = hrp.Position.X, z = hrp.Position.Z })
					end
				end
				for _, key in BossSpecials.hitTargets({ x = cx, z = cz }, targets, special.radius) do
					local victim = key :: Player
					local char = victim.Character
					local hum = char and char:FindFirstChildOfClass("Humanoid")
					local hrp = char and char:FindFirstChild("HumanoidRootPart")
					if not char or not hum or hum.Health <= 0 or char:GetAttribute("DharmaDowned") == true or char:GetAttribute("DharmaBhoota") == true then
						continue
					end

					-- Vayu-dash i-frames escape it; blocking soaks half; otherwise full hit.
					local vstate = PlayerRegistry.get(victim)
					local res = BossSpecials.resolveBlast(special.damage, os.clock() < vstate.dodgeUntil, vstate.isBlocking)

					if res.damage > 0 then
						local vench = Enchants.effects(vstate.enchant)
						local vward = if os.clock() < vstate.wardUntil then vstate.wardMult else 1
						local vrelic = Relics.totalBonus(Relics.equippedList(vstate.relics.equipped))
						hum:TakeDamage(res.damage * (vench.damageTakenMult or 1) * vward * vrelic.damageTakenMult * Vara.totalEffects(vstate.vara).damageTakenMult * Weapons.signatureOf(vstate.weapon.id).damageTakenMult)
						Net.AnimEvent:FireAllClients(char, "flinch")
						-- Shockwave knockback, away from the blast centre.
						if hrp and hrp:IsA("BasePart") then
							local away = Vector3.new(hrp.Position.X - cx, 0, hrp.Position.Z - cz)
							away = if away.Magnitude > 0.01 then away.Unit else Vector3.new(0, 0, 1)
							hrp.AssemblyLinearVelocity = away * 55 + Vector3.new(0, 35, 0)
						end
					end
					Net.CombatFeedback:FireClient(victim, {
						outcome = res.outcome,
						incoming = true,
					})
				end
			end
		end)
	end

	local handled = false
	humanoid.Died:Connect(function()
		if handled then
			return
		end
		handled = true
		enemies[model] = nil
		alive = math.max(0, alive - 1)
		CollectionService:RemoveTag(model, ENEMY_TAG)

		local killerId = model:GetAttribute("LastAttacker")
		local killer: Player? = nil
		if typeof(killerId) == "number" then
			killer = Players:GetPlayerByUserId(killerId)
			if killer then
				ProgressionService.awardXp(killer, archetype.xpReward)
				QuestService.onKill(killer, archetype.id, archetype.isBoss == true, archetype.isElite == true)

				local kstate = PlayerRegistry.get(killer)
				-- Lifetime records.
				kstate.stats.kills += 1
				kstate.waveKills += 1
				-- Vīra: chained kills chant your rank and surge your Tejas.
				local streakNow = os.clock()
				local streak = Vira.register(kstate.viraCount, kstate.viraLastAt, streakNow)
				kstate.viraCount = streak.count
				kstate.viraLastAt = streakNow
				local rank = Vira.rankAt(streak.count)
				if rank then
					kstate.tejas = Combat.clampTejas(kstate.tejas + rank.tejas, Progression.maxTejasForLevel(Progression.resolve(kstate.totalXp).level))
					Net.CombatFeedback:FireClient(killer, { vira = true, name = rank.name, count = rank.count, tejas = kstate.tejas })
				end
				if archetype.isBoss then
					kstate.stats.bossKills += 1
				end
				-- Only bosses yield Vajra Shards — the mantra currency.
				if archetype.isBoss then
					kstate.shards += Enchants.ShardsPerBossKill
					Net.CombatFeedback:FireClient(killer, {
						shardUpdate = true,
						gained = Enchants.ShardsPerBossKill,
						shards = kstate.shards,
					})
					StoryService.onEvent(killer) -- a first felled lord turns Adhyaya II
				end
				-- Kubera's Whisper: bonus gold rides every killing blow.
				local kench = Enchants.effects(kstate.enchant)
				if kench.bonusGoldPerKill then
					kstate.gold = Loot.clampGold(kstate.gold + kench.bonusGoldPerKill)
					Net.CombatFeedback:FireClient(killer, {
						goldUpdate = true,
						gained = kench.bonusGoldPerKill,
						gold = kstate.gold,
					})
				end
			end
		end

		if archetype.isBoss then
			broadcastAll({ bossState = "defeated", bossName = archetype.displayName })
		end

		-- TWINNED: the fallen splits into two lesser copies. Uncounted by the
		-- wave (onDeath nil) — piñatas, not gatekeepers.
		if model:GetAttribute("Affix") == "twinned" and model:GetAttribute("TwinChild") ~= true then
			local twinBase = Affixes.twinOf(archetype)
			for offset = -1, 1, 2 do
				local pos = root.Position + Vector3.new(offset * 3, 2, 0)
				task.spawn(function()
					EnemyService.spawn(twinBase, pos, nil)
				end)
			end
		end

		-- VENGEFUL: nearby marked kin enrage when this one falls (once each).
		for otherModel, st in enemies do
			if
				otherModel ~= model
				and otherModel:GetAttribute("Affix") == "vengeful"
				and otherModel:GetAttribute("Enraged") ~= true
				and st.root
				and (st.root.Position - root.Position).Magnitude <= 20
			then
				otherModel:SetAttribute("Enraged", true)
				local vdef = Affixes.Defs.vengeful
				local enraged = table.clone(st.archetype)
				enraged.attackDamage = math.floor(st.archetype.attackDamage * (vdef.enrageDamageMult or 1))
				st.archetype = enraged
				st.humanoid.WalkSpeed = st.humanoid.WalkSpeed * (vdef.enrageSpeedMult or 1)
				local fury = Instance.new("Fire")
				fury.Size = 4
				fury.Heat = 8
				fury.Color = Color3.fromRGB(235, 70, 60)
				fury.Parent = st.root
			end
		end

		-- Relics: a fallen boss lets EVERYONE roll; a fallen elite, its killer.
		if archetype.isBoss then
			RelicService.onBossDefeated(archetype.id)
		elseif archetype.isElite == true and killer then
			RelicService.onEliteKilled(killer)
		end

		-- Venomous corpses melt into a toxic pool — stand clear while it looses.
		if archetype.leavesPool then
			local center = root.Position
			local pool = Instance.new("Part")
			pool.Shape = Enum.PartType.Cylinder
			pool.Size = Vector3.new(0.4, StatusEffects.Pool.radius * 2, StatusEffects.Pool.radius * 2)
			pool.CFrame = CFrame.new(center.X, center.Y - 2.2, center.Z) * CFrame.Angles(0, 0, math.rad(90))
			pool.Color = Color3.fromRGB(90, 200, 70)
			pool.Material = Enum.Material.Neon
			pool.Transparency = 0.55
			pool.Anchored = true
			pool.CanCollide = false
			pool.CanQuery = false
			pool.Parent = workspace
			game:GetService("Debris"):AddItem(pool, StatusEffects.Pool.lifetime)

			task.spawn(function()
				local ticks = math.floor(StatusEffects.Pool.lifetime / StatusEffects.Pool.tick)
				for _ = 1, ticks do
					task.wait(StatusEffects.Pool.tick)
					if not pool.Parent then
						break
					end
					for _, plr in Players:GetPlayers() do
						local char = plr.Character
						local hrp = char and getRoot(char)
						local hum = char and char:FindFirstChildOfClass("Humanoid")
						if not hrp or not hum or hum.Health <= 0 or (char and char:GetAttribute("DharmaDowned") == true or char:GetAttribute("DharmaBhoota") == true) then
							continue
						end
						local flat = Vector3.new(hrp.Position.X - center.X, 0, hrp.Position.Z - center.Z)
						local dmg = StatusEffects.poolTickDamage(flat.Magnitude)
						if dmg > 0 then
							hum:TakeDamage(dmg)
						end
					end
				end
			end)
		end

		-- Burst into loot where it fell.
		LootService.dropAt(root.Position, archetype)

		if onDeath then
			onDeath(killer)
		end
		task.delay(3, function()
			model:Destroy()
		end)
	end)
end

function EnemyService.clearAll()
	for model in enemies do
		model:Destroy()
	end
	table.clear(enemies)
	alive = 0
end

RunService.Heartbeat:Connect(function()
	for _, enemy in enemies do
		stepEnemy(enemy)
	end
end)

return EnemyService
