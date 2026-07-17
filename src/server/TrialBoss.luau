--!strict
-- The Kirata Trial (server): the summit encounter, in three acts. Phase 1 is the
-- Kirata, a kiting hunter with arrow volleys. At the first threshold the disguise
-- burns away — Mahadeva — slower, vaster, flame volleys, the telegraphed Tandava
-- stomp. Press him to the second threshold and the world itself darkens: Nataraja,
-- the dance at the end of time — faster, vaster still, chained stomp rings in an
-- accelerating rhythm. He cannot be slain: at his last measure the fight ends in a
-- blessing, not a death, and the boon deepens each visitation.
-- Reuses the shared defense pipeline, telegraph renderer, and blast rules.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CollectionService = game:GetService("CollectionService")
local TweenService = game:GetService("TweenService")
local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local Debris = game:GetService("Debris")

local Net = require(ReplicatedStorage.Shared.Net)
local Trial = require(ReplicatedStorage.Shared.Trial)
local BossSpecials = require(ReplicatedStorage.Shared.BossSpecials)
local Enchants = require(ReplicatedStorage.Shared.Enchants)
local Relics = require(ReplicatedStorage.Shared.Relics)
local Vara = require(ReplicatedStorage.Shared.Vara)
local Loot = require(ReplicatedStorage.Shared.Loot)
local PlayerRegistry = require(script.Parent.PlayerRegistry)
local ProgressionService = require(script.Parent.ProgressionService)
local EnemyService = require(script.Parent.EnemyService)
local StoryService = require(script.Parent.StoryService)

local ENEMY_TAG = "DharmaEnemy"
local SPAWN_POS = Vector3.new(0, 8, -40)

local TrialBoss = {}

type SavedLighting = {
	clockTime: number,
	fogEnd: number,
	fogColor: Color3,
	ambient: Color3,
	outdoorAmbient: Color3,
}

type FightState = {
	model: Model,
	humanoid: Humanoid,
	root: BasePart,
	phase: number,
	maxHealth: number,
	encounter: number, -- 1st visitation, 2nd, ... (scales pool + boon)
	active: boolean,
	sequenceRunning: boolean, -- transformation / blessing cutscenes pause the AI
	nextVolleyAt: number,
	nextMeleeAt: number,
	nextStompAt: number,
	saidFury: boolean,
	saidMid: boolean,
	saidMid3: boolean,
	savedLighting: SavedLighting?,
}

local fight: FightState? = nil

local function broadcastAll(data: { [string]: any })
	for _, p in Players:GetPlayers() do
		Net.CombatFeedback:FireClient(p, data)
	end
end

local function speak(speaker: string, text: string)
	broadcastAll({ bossLine = true, speaker = speaker, text = text })
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
		if not root or not hum or hum.Health <= 0 or char:GetAttribute("DharmaDowned") == true or char:GetAttribute("DharmaBhoota") == true then
			continue
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

local function spawnRig(cfg: Trial.PhaseConfig): Model?
	local skin = Color3.fromRGB(cfg.skin[1], cfg.skin[2], cfg.skin[3])
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
		warn("[Dharma] Failed to create trial rig: " .. tostring(model))
		return nil
	end
	return model
end

-- The Tandava darkens the world; the blessing gives the light back.
local function darkenWorld(st: FightState)
	st.savedLighting = {
		clockTime = Lighting.ClockTime,
		fogEnd = Lighting.FogEnd,
		fogColor = Lighting.FogColor,
		ambient = Lighting.Ambient,
		outdoorAmbient = Lighting.OutdoorAmbient,
	}
	TweenService:Create(Lighting, TweenInfo.new(2.5), {
		ClockTime = 0.05,
		FogEnd = 260,
		FogColor = Color3.fromRGB(12, 10, 24),
		Ambient = Color3.fromRGB(28, 26, 46),
		OutdoorAmbient = Color3.fromRGB(24, 22, 44),
	}):Play()
end

local function restoreWorld(st: FightState)
	local saved = st.savedLighting
	if not saved then
		return
	end
	st.savedLighting = nil
	TweenService:Create(Lighting, TweenInfo.new(2.5), {
		ClockTime = saved.clockTime,
		FogEnd = saved.fogEnd,
		FogColor = saved.fogColor,
		Ambient = saved.ambient,
		OutdoorAmbient = saved.outdoorAmbient,
	}):Play()
end

-- One arrow of a volley: real flight time, 6-stud miss window, shared defense rules.
local function looseArrow(st: FightState, target: Player, damage: number, speed: number, flame: boolean)
	local tchar = target.Character
	local troot = tchar and getRoot(tchar)
	if not troot then
		return
	end
	local origin = st.root.Position + Vector3.new(0, 2, 0)
	local targetPos = troot.Position
	local flight = (targetPos - origin).Magnitude / speed

	local arrow = Instance.new("Part")
	arrow.Anchored = true
	arrow.CanCollide = false
	arrow.CanQuery = false
	arrow.CanTouch = false
	arrow.Material = Enum.Material.Neon
	arrow.Color = if flame then Color3.fromRGB(255, 120, 30) else Color3.fromRGB(255, 190, 90)
	arrow.Size = if flame then Vector3.new(0.35, 0.35, 3.6) else Vector3.new(0.25, 0.25, 3)
	arrow.CFrame = CFrame.lookAt(origin, targetPos)
	arrow.Parent = workspace
	TweenService:Create(arrow, TweenInfo.new(flight, Enum.EasingStyle.Linear), {
		CFrame = CFrame.lookAt(targetPos, targetPos + (targetPos - origin)),
	}):Play()
	Debris:AddItem(arrow, flight + 0.1)

	task.delay(flight, function()
		local char = target.Character
		local root = char and getRoot(char)
		local hum = char and char:FindFirstChildOfClass("Humanoid")
		if not char or not root or not hum or hum.Health <= 0 then
			return
		end
		if (root.Position - targetPos).Magnitude > 6 then
			return
		end
		EnemyService.resolveHitOnPlayer(target, root, hum, damage, origin, nil)
	end)
end

local function volley(st: FightState, cfg: Trial.PhaseConfig, target: Player)
	task.spawn(function()
		for _ = 1, cfg.volleyCount do
			if not st.active or st.sequenceRunning then
				return
			end
			Net.AnimEvent:FireAllClients(st.model, "throw")
			looseArrow(st, target, cfg.arrowDamage, cfg.projectileSpeed, st.phase >= 2)
			task.wait(cfg.volleyInterval)
		end
	end)
end

-- One stomp ring: telegraph, then ruin (ward + relic soaks apply, like any blast).
local function stompRing(st: FightState, radius: number, damage: number, telegraph: number)
	local cx, cy, cz = st.root.Position.X, st.root.Position.Y - 2.5, st.root.Position.Z
	broadcastAll({
		bossSpecial = "telegraph",
		name = "Tandava",
		x = cx,
		y = cy,
		z = cz,
		radius = radius,
		duration = telegraph,
	})
	task.wait(telegraph)
	if not st.active then
		return
	end

	Net.AnimEvent:FireAllClients(st.model, "combo4")
	broadcastAll({ bossSpecial = "impact", x = cx, y = cy, z = cz, radius = radius })

	local targets: { BossSpecials.Target } = {}
	for _, plr in Players:GetPlayers() do
		local char = plr.Character
		local hrp = char and getRoot(char)
		if hrp then
			table.insert(targets, { key = plr, x = hrp.Position.X, z = hrp.Position.Z })
		end
	end
	for _, key in BossSpecials.hitTargets({ x = cx, z = cz }, targets, radius) do
		local victim = key :: Player
		local char = victim.Character
		local hum = char and char:FindFirstChildOfClass("Humanoid")
		local hrp = char and getRoot(char)
		if not char or not hum or hum.Health <= 0 or char:GetAttribute("DharmaDowned") == true or char:GetAttribute("DharmaBhoota") == true then
			continue
		end
		local vstate = PlayerRegistry.get(victim)
		local res = BossSpecials.resolveBlast(damage, os.clock() < vstate.dodgeUntil, vstate.isBlocking)
		if res.damage > 0 then
			local vench = Enchants.effects(vstate.enchant)
			local vward = if os.clock() < vstate.wardUntil then vstate.wardMult else 1
			local vrelic = Relics.totalBonus(Relics.equippedList(vstate.relics.equipped))
			hum:TakeDamage(res.damage * (vench.damageTakenMult or 1) * vward * vrelic.damageTakenMult * Vara.totalEffects(vstate.vara).damageTakenMult)
			Net.AnimEvent:FireAllClients(char, "flinch")
			if hrp then
				local away = Vector3.new(hrp.Position.X - cx, 0, hrp.Position.Z - cz)
				away = if away.Magnitude > 0.01 then away.Unit else Vector3.new(0, 0, 1)
				hrp.AssemblyLinearVelocity = away * 65 + Vector3.new(0, 40, 0)
			end
		end
		Net.CombatFeedback:FireClient(victim, { outcome = res.outcome, incoming = true })
	end
end

-- Phase 2: a single Tandava stomp.
local function tandavaStomp(st: FightState)
	Net.AnimEvent:FireAllClients(st.model, "ult")
	stompRing(st, Trial.Stomp.radius, Trial.Stomp.damage, Trial.Stomp.telegraph)
end

-- Phase 3: the dance itself — three chained rings, each following his moving feet.
local function tandavaChain(st: FightState)
	Net.AnimEvent:FireAllClients(st.model, "ult")
	for i, ring in Trial.TandavaChain.rings do
		if not st.active or st.sequenceRunning then
			return
		end
		stompRing(st, ring.radius, ring.damage, ring.telegraph)
		if i < #Trial.TandavaChain.rings then
			task.wait(Trial.TandavaChain.betweenRings)
		end
	end
end

-- Recolor + regrow the rig into a phase's shape.
local function reshape(st: FightState, cfg: Trial.PhaseConfig)
	local skin = Color3.fromRGB(cfg.skin[1], cfg.skin[2], cfg.skin[3])
	for _, part in st.model:GetDescendants() do
		if part:IsA("BasePart") and part.Name ~= "HumanoidRootPart" then
			part.Color = skin
		end
	end
	pcall(function()
		st.model:ScaleTo(cfg.scale)
	end)
	st.humanoid.WalkSpeed = cfg.walkSpeed
	st.humanoid.DisplayName = cfg.name
end

-- The disguise burns away: recolor, grow, ignite the third eye, rename the bar.
local function transform(st: FightState)
	st.sequenceRunning = true
	CollectionService:RemoveTag(st.model, ENEMY_TAG) -- untargetable mid-reveal
	st.humanoid:MoveTo(st.root.Position)

	speak(Trial.Phase1.name, Trial.Lines.transitionA)
	task.wait(1.4)
	if not st.active then
		return
	end

	Net.AnimEvent:FireAllClients(st.model, "ult")
	reshape(st, Trial.Phase2)
	local head = st.model:FindFirstChild("Head")
	if head and head:IsA("BasePart") then
		local eye = Instance.new("Fire")
		eye.Size = 4
		eye.Heat = 10
		eye.Color = Color3.fromRGB(255, 120, 30)
		eye.SecondaryColor = Color3.fromRGB(120, 30, 10)
		eye.Parent = head
		local light = Instance.new("PointLight")
		light.Brightness = 5
		light.Range = 24
		light.Color = Color3.fromRGB(255, 140, 60)
		light.Parent = head
	end
	st.phase = 2

	-- Rename the boss bar for everyone (drums keep rolling).
	broadcastAll({
		bossState = "spawn",
		bossName = Trial.Phase2.name,
		bossTitle = Trial.Phase2.title,
		bossHealth = st.humanoid.Health,
		bossMaxHealth = st.maxHealth,
	})
	task.wait(0.8)
	speak(Trial.Phase2.name, Trial.Lines.transitionB)
	task.wait(1.0)

	if st.active then
		CollectionService:AddTag(st.model, ENEMY_TAG)
	end
	st.nextStompAt = os.clock() + 3
	st.sequenceRunning = false
end

-- The dance begins: the world darkens, the god grows past the treeline, and
-- flame wreathes both hands. Nataraja.
local function ascend(st: FightState)
	st.sequenceRunning = true
	CollectionService:RemoveTag(st.model, ENEMY_TAG)
	st.humanoid:MoveTo(st.root.Position)

	speak(Trial.Phase2.name, Trial.Lines.transition2A)
	darkenWorld(st)
	task.wait(2.2)
	if not st.active then
		return
	end

	Net.AnimEvent:FireAllClients(st.model, "ult")
	reshape(st, Trial.Phase3)
	for _, handName in { "LeftHand", "RightHand", "Left Arm", "Right Arm" } do
		local hand = st.model:FindFirstChild(handName)
		if hand and hand:IsA("BasePart") then
			local flame = Instance.new("Fire")
			flame.Size = 5
			flame.Heat = 12
			flame.Color = Color3.fromRGB(150, 200, 255)
			flame.SecondaryColor = Color3.fromRGB(40, 60, 140)
			flame.Parent = hand
		end
	end
	local head = st.model:FindFirstChild("Head")
	if head and head:IsA("BasePart") then
		local light = head:FindFirstChildOfClass("PointLight")
		if light then
			light.Brightness = 8
			light.Range = 40
			light.Color = Color3.fromRGB(160, 200, 255)
		end
	end
	st.phase = 3

	broadcastAll({
		bossState = "spawn",
		bossName = Trial.Phase3.name,
		bossTitle = Trial.Phase3.title,
		bossHealth = st.humanoid.Health,
		bossMaxHealth = st.maxHealth,
	})
	task.wait(0.8)
	speak(Trial.Phase3.name, Trial.Lines.transition2B)
	task.wait(1.0)

	if st.active then
		CollectionService:AddTag(st.model, ENEMY_TAG)
	end
	st.nextStompAt = os.clock() + 2.5
	st.sequenceRunning = false
end

-- The ending no other fight has: a blessing.
local function bless(st: FightState, onClear: () -> ())
	st.sequenceRunning = true
	st.active = false
	CollectionService:RemoveTag(st.model, ENEMY_TAG)
	st.humanoid:MoveTo(st.root.Position)

	speak(Trial.Phase3.name, Trial.Lines.blessing)
	restoreWorld(st)
	task.wait(2.0)

	-- The boon: mended, cleansed, enriched — deeper each visitation.
	local boon = Trial.rewardFor(st.encounter)
	for _, p in Players:GetPlayers() do
		local char = p.Character
		local hum = char and char:FindFirstChildOfClass("Humanoid")
		if hum and hum.Health > 0 then
			hum.Health = hum.MaxHealth
		end
		local pstate = PlayerRegistry.get(p)
		pstate.curseUntil = 0
		pstate.venomUntil = 0
		pstate.stats.trialsPassed += 1 -- Blessed of Mahadeva / Witness of the Tandava
		pstate.shards += boon.shards
		pstate.gold = Loot.clampGold(pstate.gold + boon.gold)
		Net.CombatFeedback:FireClient(p, { shardUpdate = true, gained = boon.shards, shards = pstate.shards })
		Net.CombatFeedback:FireClient(p, { goldUpdate = true, gained = boon.gold, gold = pstate.gold })
		ProgressionService.awardXp(p, boon.xp)
		StoryService.onEvent(p) -- a blessing may turn Adhyaya IV — or the finale
	end

	broadcastAll({ bossState = "passed", bossName = Trial.Phase3.name, message = Trial.Lines.passed })

	-- He does not fall. He leaves.
	for _, part in st.model:GetDescendants() do
		if part:IsA("BasePart") then
			TweenService:Create(part, TweenInfo.new(1.6), { Transparency = 1 }):Play()
		elseif part:IsA("Fire") or part:IsA("PointLight") then
			part:Destroy()
		end
	end
	task.wait(1.7)
	st.model:Destroy()
	fight = nil
	onClear()
end

function TrialBoss.begin(wave: number, onClear: () -> ())
	local cfg = Trial.Phase1
	local model = spawnRig(cfg)
	if not model then
		onClear() -- never stall the wave director on a failed rig
		return
	end
	local humanoid = model:FindFirstChildOfClass("Humanoid")
	local root = getRoot(model)
	if not humanoid or not root then
		model:Destroy()
		onClear()
		return
	end

	local encounter = math.max(1, Trial.encounterIndex(wave))
	local maxHealth = Trial.healthFor(encounter)

	humanoid.MaxHealth = maxHealth
	humanoid.Health = maxHealth
	humanoid.WalkSpeed = cfg.walkSpeed
	humanoid.DisplayName = cfg.name
	pcall(function()
		model:ScaleTo(cfg.scale)
	end)
	model:PivotTo(CFrame.new(SPAWN_POS))
	model.Name = cfg.name
	model:SetAttribute("IsBoss", true) -- Yama's Ledger cannot claim a god
	model.Parent = workspace
	CollectionService:AddTag(model, ENEMY_TAG)

	local st: FightState = {
		model = model,
		humanoid = humanoid,
		root = root,
		phase = 1,
		maxHealth = maxHealth,
		encounter = encounter,
		active = true,
		sequenceRunning = false,
		nextVolleyAt = os.clock() + 2.5,
		nextMeleeAt = 0,
		nextStompAt = math.huge,
		saidFury = false,
		saidMid = false,
		saidMid3 = false,
		savedLighting = nil,
	}
	fight = st

	broadcastAll({
		bossState = "spawn",
		bossName = cfg.name,
		bossTitle = cfg.title,
		bossHealth = maxHealth,
		bossMaxHealth = maxHealth,
	})
	humanoid.HealthChanged:Connect(function(health: number)
		-- He cannot be slain — the floor holds until the blessing takes over.
		if health < 1 then
			humanoid.Health = 1
			health = 1
		end
		broadcastAll({ bossState = "health", bossHealth = health, bossMaxHealth = st.maxHealth })
	end)

	task.delay(1.0, function()
		if st.active then
			speak(cfg.name, Trial.Lines.spawn)
		end
	end)

	-- The fight loop.
	task.spawn(function()
		while st.active and st.model.Parent do
			task.wait(0.25)
			if not st.active or st.sequenceRunning then
				continue
			end

			-- Phase gates.
			local hp = st.humanoid.Health
			if st.phase == 1 and hp <= st.maxHealth * Trial.Phase2At then
				transform(st)
				continue
			end
			if st.phase == 2 and hp <= st.maxHealth * Trial.Phase3At then
				ascend(st)
				continue
			end
			if st.phase == 3 and hp <= st.maxHealth * Trial.BlessAt then
				bless(st, onClear)
				return
			end
			if st.phase == 2 and not st.saidMid and hp <= st.maxHealth * 0.4 then
				st.saidMid = true
				speak(Trial.Phase2.name, Trial.Lines.midPhase2)
			end
			if st.phase == 3 and not st.saidMid3 and hp <= st.maxHealth * 0.15 then
				st.saidMid3 = true
				speak(Trial.Phase3.name, Trial.Lines.midPhase3)
			end

			local phaseCfg = if st.phase == 3 then Trial.Phase3 elseif st.phase == 2 then Trial.Phase2 else Trial.Phase1
			local player, playerRoot, playerHum, dist = nearestPlayer(st.root.Position)
			if not player or not playerRoot or not playerHum then
				continue
			end

			-- Movement: the hunter keeps his distance; the god walks you down.
			if dist > phaseCfg.preferredRange + 6 then
				st.humanoid:MoveTo(playerRoot.Position)
			elseif st.phase == 1 and dist < phaseCfg.preferredRange - 8 then
				local away = st.root.Position - playerRoot.Position
				away = Vector3.new(away.X, 0, away.Z)
				away = if away.Magnitude > 0.01 then away.Unit else Vector3.new(0, 0, 1)
				st.humanoid:MoveTo(st.root.Position + away * 16)
			elseif st.phase >= 2 then
				st.humanoid:MoveTo(playerRoot.Position)
			end

			local now = os.clock()
			if st.phase == 3 and now >= st.nextStompAt and dist <= Trial.TandavaChain.rings[1].radius + 14 then
				st.nextStompAt = now + Trial.TandavaChain.cooldown
				task.spawn(tandavaChain, st)
			elseif st.phase == 2 and now >= st.nextStompAt and dist <= Trial.Stomp.radius + 12 then
				st.nextStompAt = now + Trial.Stomp.cooldown
				task.spawn(tandavaStomp, st)
			elseif dist <= phaseCfg.meleeRange and now >= st.nextMeleeAt then
				st.nextMeleeAt = now + phaseCfg.meleeCooldown
				Net.AnimEvent:FireAllClients(st.model, "enemySwing")
				EnemyService.resolveHitOnPlayer(player, playerRoot, playerHum, phaseCfg.meleeDamage, st.root.Position, nil)
			elseif now >= st.nextVolleyAt then
				st.nextVolleyAt = now + phaseCfg.volleyCooldown
				if not st.saidFury then
					st.saidFury = true
					speak(phaseCfg.name, Trial.Lines.fury)
				end
				volley(st, phaseCfg, player)
			end
		end
	end)
end

-- Party wipe: the trial dissolves with the wave (no blessing, no reward).
function TrialBoss.clear()
	local st = fight
	if not st then
		return
	end
	st.active = false
	st.sequenceRunning = true
	restoreWorld(st)
	if st.model then
		st.model:Destroy()
	end
	fight = nil
end

return TrialBoss
