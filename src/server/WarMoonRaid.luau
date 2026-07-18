--!strict
-- Tarakasura (server): the wave-150 raid. Phase 1 — he hovers untouchable
-- beneath the War-Moon while three moon-anchors stand; each felled anchor
-- bleeds guards into the arena. Phase 2 — the Moon sets: he descends, tagged
-- and mortal-adjacent, escalating through stages as his health wanes. But his
-- boon holds: at the broken threshold he KNEELS, unkillable — and the Vel of
-- Karttikeya falls from the sky to end what mortals may only break. Even this
-- victory belongs to Shiva's house (tarakasura.spec holds the hierarchy).

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CollectionService = game:GetService("CollectionService")
local TweenService = game:GetService("TweenService")
local Players = game:GetService("Players")
local Debris = game:GetService("Debris")

local Net = require(ReplicatedStorage.Shared.Net)
local Tarakasura = require(ReplicatedStorage.Shared.Tarakasura)
local EnemyTypes = require(ReplicatedStorage.Shared.EnemyTypes)
local BossSpecials = require(ReplicatedStorage.Shared.BossSpecials)
local Enchants = require(ReplicatedStorage.Shared.Enchants)
local Relics = require(ReplicatedStorage.Shared.Relics)
local Vara = require(ReplicatedStorage.Shared.Vara)
local Bhava = require(ReplicatedStorage.Shared.Bhava)
local Loot = require(ReplicatedStorage.Shared.Loot)
local PlayerRegistry = require(script.Parent.PlayerRegistry)
local ProgressionService = require(script.Parent.ProgressionService)
local EnemyService = require(script.Parent.EnemyService)
local QuestService = require(script.Parent.QuestService)
local StoryService = require(script.Parent.StoryService)

local ENEMY_TAG = "DharmaEnemy"
local HOVER_POS = Vector3.new(0, 46, -30)
local LAND_POS = Vector3.new(0, 8, -30)
local SKIN = Color3.fromRGB(36, 40, 64)
local MOONLIGHT = Color3.fromRGB(200, 215, 255)

local WarMoonRaid = {}

type FightState = {
	model: Model,
	humanoid: Humanoid,
	root: BasePart,
	maxHealth: number,
	encounter: number,
	stage: number,
	anchorsLeft: number,
	anchors: { Model },
	active: boolean,
	descended: boolean,
	broken: boolean,
	sequenceRunning: boolean,
	nextVolleyAt: number,
	nextMeleeAt: number,
	nextSlamAt: number,
}

local fight: FightState? = nil

local function broadcastAll(data: { [string]: any })
	for _, p in Players:GetPlayers() do
		Net.CombatFeedback:FireClient(p, data)
	end
end

local function speak(text: string)
	broadcastAll({ bossLine = true, speaker = "Tarakasura", text = text })
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
		if not root or not hum or hum.Health <= 0 or char:GetAttribute("DharmaDowned") == true or char:GetAttribute("DharmaBhoota") == true or char:GetAttribute("DharmaDhyana") == true then
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

local function spawnRig(): Model?
	local ok, model = pcall(function()
		local desc = Instance.new("HumanoidDescription")
		desc.HeadColor = SKIN
		desc.TorsoColor = SKIN
		desc.LeftArmColor = SKIN
		desc.RightArmColor = SKIN
		desc.LeftLegColor = SKIN
		desc.RightLegColor = SKIN
		return Players:CreateHumanoidModelFromDescription(desc, Enum.HumanoidRigType.R15)
	end)
	if not ok or typeof(model) ~= "Instance" or not model:IsA("Model") then
		warn("[Dharma] Failed to create Tarakasura rig: " .. tostring(model))
		return nil
	end
	return model
end

-- A moon-anchor: a pale pillar with a humanoid heart, so every blade and
-- Astra can find it through the ordinary enemy tag. Anchored, executeless.
local function buildAnchor(index: number, health: number, onFelled: () -> ()): Model
	local angle = (2 * math.pi * index) / Tarakasura.AnchorCount + math.pi / 6
	local pos = Vector3.new(math.cos(angle) * 30, 7, math.sin(angle) * 30)

	local model = Instance.new("Model")
	model.Name = "MoonAnchor"

	local pillar = Instance.new("Part")
	pillar.Name = "HumanoidRootPart"
	pillar.Size = Vector3.new(4, 14, 4)
	pillar.Position = pos
	pillar.Color = MOONLIGHT
	pillar.Material = Enum.Material.Neon
	pillar.Anchored = true
	pillar.Parent = model
	model.PrimaryPart = pillar

	local beam = Instance.new("Part")
	beam.Size = Vector3.new(0.8, 60, 0.8)
	beam.Position = pos + Vector3.new(0, 37, 0)
	beam.Color = MOONLIGHT
	beam.Material = Enum.Material.Neon
	beam.Transparency = 0.55
	beam.Anchored = true
	beam.CanCollide = false
	beam.CanQuery = false
	beam.Parent = model

	local humanoid = Instance.new("Humanoid")
	humanoid.MaxHealth = health
	humanoid.Health = health
	humanoid.Parent = model

	local billboard = Instance.new("BillboardGui")
	billboard.Size = UDim2.fromOffset(190, 40)
	billboard.StudsOffset = Vector3.new(0, 9, 0)
	billboard.AlwaysOnTop = true
	billboard.Parent = pillar
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.GothamBold
	label.TextSize = 15
	label.TextColor3 = MOONLIGHT
	label.TextStrokeTransparency = 0.4
	label.Text = "MOON-ANCHOR"
	label.Parent = billboard

	model:SetAttribute("IsBoss", true) -- no execute claims a chain
	model.Parent = workspace
	CollectionService:AddTag(model, ENEMY_TAG)

	humanoid.Died:Connect(function()
		CollectionService:RemoveTag(model, ENEMY_TAG)
		for _, part in model:GetDescendants() do
			if part:IsA("BasePart") then
				TweenService:Create(part, TweenInfo.new(1.0), { Transparency = 1 }):Play()
			end
		end
		Debris:AddItem(model, 1.2)
		onFelled()
	end)

	return model
end

local function summonGuards(center: Vector3, archetypeId: string, count: number)
	local archetype = EnemyTypes.get(archetypeId)
	for i = 1, count do
		local angle = (2 * math.pi * i) / count
		local pos = center + Vector3.new(math.cos(angle) * 10, 4, math.sin(angle) * 10)
		task.spawn(function()
			EnemyService.spawn(archetype, pos, function() end)
		end)
	end
end

-- Crescent bolt: pale light with real flight time and a miss window.
local function looseBolt(st: FightState, target: Player, damage: number, speed: number)
	local tchar = target.Character
	local troot = tchar and getRoot(tchar)
	if not troot then
		return
	end
	local origin = st.root.Position + Vector3.new(0, 4, 0)
	local targetPos = troot.Position
	local flight = (targetPos - origin).Magnitude / speed

	local bolt = Instance.new("Part")
	bolt.Anchored = true
	bolt.CanCollide = false
	bolt.CanQuery = false
	bolt.CanTouch = false
	bolt.Material = Enum.Material.Neon
	bolt.Color = MOONLIGHT
	bolt.Size = Vector3.new(0.4, 0.4, 4.2)
	bolt.CFrame = CFrame.lookAt(origin, targetPos)
	bolt.Parent = workspace
	TweenService:Create(bolt, TweenInfo.new(flight, Enum.EasingStyle.Linear), {
		CFrame = CFrame.lookAt(targetPos, targetPos + (targetPos - origin)),
	}):Play()
	Debris:AddItem(bolt, flight + 0.1)

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

local function volley(st: FightState, stats: Tarakasura.StageStats, target: Player)
	task.spawn(function()
		for _ = 1, stats.volleyCount do
			if not st.active or st.sequenceRunning then
				return
			end
			Net.AnimEvent:FireAllClients(st.model, "throw")
			looseBolt(st, target, stats.volleyDamage, stats.projectileSpeed)
			task.wait(0.2)
		end
	end)
end

-- Moonfall: the War-Moon itself hammers a telegraphed ring.
local function moonfall(st: FightState)
	local cx, cy, cz = st.root.Position.X, st.root.Position.Y - 2.5, st.root.Position.Z
	Net.AnimEvent:FireAllClients(st.model, "ult")
	broadcastAll({
		bossSpecial = "telegraph",
		name = "Moonfall",
		x = cx,
		y = cy,
		z = cz,
		radius = Tarakasura.Slam.radius,
		duration = Tarakasura.Slam.telegraph,
	})
	task.wait(Tarakasura.Slam.telegraph)
	if not st.active then
		return
	end

	Net.AnimEvent:FireAllClients(st.model, "combo4")
	broadcastAll({ bossSpecial = "impact", x = cx, y = cy, z = cz, radius = Tarakasura.Slam.radius })

	local targets: { BossSpecials.Target } = {}
	for _, plr in Players:GetPlayers() do
		local char = plr.Character
		local hrp = char and getRoot(char)
		if hrp then
			table.insert(targets, { key = plr, x = hrp.Position.X, z = hrp.Position.Z })
		end
	end
	for _, key in BossSpecials.hitTargets({ x = cx, z = cz }, targets, Tarakasura.Slam.radius) do
		local victim = key :: Player
		local char = victim.Character
		local hum = char and char:FindFirstChildOfClass("Humanoid")
		local hrp = char and getRoot(char)
		if not char or not hum or hum.Health <= 0 then
			continue
		end
		local vstate = PlayerRegistry.get(victim)
		local res = BossSpecials.resolveBlast(Tarakasura.Slam.damage, os.clock() < vstate.dodgeUntil, vstate.isBlocking)
		if res.damage > 0 then
			local vench = Enchants.effects(vstate.enchant)
			local vward = if os.clock() < vstate.wardUntil then vstate.wardMult else 1
			local vrelic = Relics.totalBonus(Relics.equippedList(vstate.relics.equipped))
			hum:TakeDamage(res.damage * (vench.damageTakenMult or 1) * vward * vrelic.damageTakenMult * Vara.totalEffects(vstate.vara).damageTakenMult * Bhava.effectsOf(vstate.bhava).damageTakenMult)
			Net.AnimEvent:FireAllClients(char, "flinch")
			if hrp then
				local away = Vector3.new(hrp.Position.X - cx, 0, hrp.Position.Z - cz)
				away = if away.Magnitude > 0.01 then away.Unit else Vector3.new(0, 0, 1)
				hrp.AssemblyLinearVelocity = away * 60 + Vector3.new(0, 35, 0)
			end
		end
		Net.CombatFeedback:FireClient(victim, { outcome = res.outcome, incoming = true })
	end
end

-- The Vel of Karttikeya: a spear of dawn-gold light that ends what mortals
-- may only break. Plays over `seconds`, then the boon-holder dies.
local function velFalls(st: FightState, seconds: number)
	broadcastAll({ velFalls = true })
	speak(Tarakasura.Lines.vel)

	local pos = st.root.Position
	local spear = Instance.new("Part")
	spear.Size = Vector3.new(2.2, 90, 2.2)
	spear.Position = pos + Vector3.new(0, 70, 0)
	spear.Color = Color3.fromRGB(255, 220, 90)
	spear.Material = Enum.Material.Neon
	spear.Anchored = true
	spear.CanCollide = false
	spear.CanQuery = false
	spear.Parent = workspace
	local light = Instance.new("PointLight")
	light.Brightness = 8
	light.Range = 40
	light.Color = Color3.fromRGB(255, 230, 140)
	light.Parent = spear
	TweenService:Create(spear, TweenInfo.new(seconds, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
		Position = pos + Vector3.new(0, 4, 0),
	}):Play()
	Debris:AddItem(spear, seconds + 1.5)

	task.wait(seconds)
	if st.model.Parent and st.humanoid.Health > 0 then
		st.humanoid.Health = 0 -- the boy's spear, not a mortal hand
	end
end

-- The Moon sets: spoils for all, credit for the hand that broke him.
local function victory(st: FightState, breaker: Player?, onClear: () -> ())
	st.sequenceRunning = true
	CollectionService:RemoveTag(st.model, ENEMY_TAG)

	speak(Tarakasura.Lines.defeated)
	broadcastAll({ bossState = "defeated", bossName = "Tarakasura" })
	task.wait(2.0)

	local spoils = Tarakasura.rewardFor(st.encounter)
	for _, p in Players:GetPlayers() do
		local pstate = PlayerRegistry.tryGet(p)
		if not pstate then
			continue
		end
		local pchar = p.Character
		if pchar and pchar:GetAttribute("DharmaDhyana") == true then
			continue -- the Moon's spoils belong to those who dragged it down
		end
		pstate.shards += spoils.shards
		pstate.gold = Loot.clampGold(pstate.gold + spoils.gold)
		Net.CombatFeedback:FireClient(p, { shardUpdate = true, gained = spoils.shards, shards = pstate.shards })
		Net.CombatFeedback:FireClient(p, { goldUpdate = true, gained = spoils.gold, gold = pstate.gold })
		ProgressionService.awardXp(p, spoils.xp)
		StoryService.onEvent(p)
	end
	-- The breaker's ledger: the kill credit is theirs; the ENDING was the Vel's.
	if breaker then
		local kstate = PlayerRegistry.tryGet(breaker)
		if kstate then
			kstate.stats.kills += 1
			kstate.stats.bossKills += 1
			QuestService.onKill(breaker, "Tarakasura", true, false)
		end
	end

	broadcastAll({ raidVictory = true, message = Tarakasura.Lines.victory })

	EnemyService.clearAll()

	for _, part in st.model:GetDescendants() do
		if part:IsA("BasePart") then
			TweenService:Create(part, TweenInfo.new(2.2), { Transparency = 1 }):Play()
		elseif part:IsA("Fire") or part:IsA("PointLight") then
			part:Destroy()
		end
	end
	task.wait(2.4)
	st.model:Destroy()
	fight = nil
	onClear()
end

-- The boon holds: he kneels unkillable, and the sky answers.
local function breakSequence(st: FightState, onClear: () -> ())
	st.broken = true
	st.sequenceRunning = true
	st.active = false
	CollectionService:RemoveTag(st.model, ENEMY_TAG) -- past mortal reach now
	st.humanoid.WalkSpeed = 0
	st.humanoid.Health = math.max(st.humanoid.Health, 1)
	Net.AnimEvent:FireAllClients(st.model, "flinch")

	local breakerId = st.model:GetAttribute("LastAttacker")
	local breaker = if typeof(breakerId) == "number" then Players:GetPlayerByUserId(breakerId) else nil

	speak(Tarakasura.Lines.broken)
	task.wait(2.2)
	velFalls(st, Tarakasura.VelSeconds)
	victory(st, breaker, onClear)
end

function WarMoonRaid.begin(wave: number, onClear: () -> ())
	local model = spawnRig()
	if not model then
		onClear()
		return
	end
	local humanoid = model:FindFirstChildOfClass("Humanoid")
	local root = getRoot(model)
	if not humanoid or not root then
		model:Destroy()
		onClear()
		return
	end

	local encounter = math.max(1, Tarakasura.encounterIndex(wave))
	local maxHealth = Tarakasura.healthFor(encounter)
	local baseStats = Tarakasura.statsForStage(0)

	humanoid.MaxHealth = maxHealth
	humanoid.Health = maxHealth
	humanoid.WalkSpeed = 0
	humanoid.DisplayName = "Tarakasura"
	pcall(function()
		model:ScaleTo(2.85) -- above the king — but Nataraja towers higher, by law
	end)
	model.Name = "Tarakasura"
	model:SetAttribute("IsBoss", true)
	root.Anchored = true -- held aloft by the War-Moon
	model:PivotTo(CFrame.new(HOVER_POS))
	model.Parent = workspace

	-- The War-Moon itself, hanging behind him.
	local moon = Instance.new("Part")
	moon.Shape = Enum.PartType.Ball
	moon.Size = Vector3.new(18, 18, 18)
	moon.Position = HOVER_POS + Vector3.new(0, 14, -12)
	moon.Color = MOONLIGHT
	moon.Material = Enum.Material.Neon
	moon.Transparency = 0.25
	moon.Anchored = true
	moon.CanCollide = false
	moon.CanQuery = false
	moon.Parent = model

	local st: FightState = {
		model = model,
		humanoid = humanoid,
		root = root,
		maxHealth = maxHealth,
		encounter = encounter,
		stage = 0,
		anchorsLeft = Tarakasura.AnchorCount,
		anchors = {},
		active = true,
		descended = false,
		broken = false,
		sequenceRunning = false,
		nextVolleyAt = 0,
		nextMeleeAt = 0,
		nextSlamAt = 0,
	}
	fight = st

	-- Phase 2: the Moon sets and the fight truly begins.
	local function descend()
		if not st.active or st.descended then
			return
		end
		st.descended = true
		speak(Tarakasura.Lines.descend)
		TweenService:Create(moon, TweenInfo.new(2.0), { Transparency = 1 }):Play()
		task.delay(1.0, function()
			if not st.active then
				return
			end
			root.Anchored = false
			model:PivotTo(CFrame.new(LAND_POS))
			humanoid.WalkSpeed = baseStats.walkSpeed
			CollectionService:AddTag(model, ENEMY_TAG)
			broadcastAll({
				bossState = "spawn",
				bossName = "Tarakasura",
				bossTitle = "the War-Moon",
				bossHealth = st.humanoid.Health,
				bossMaxHealth = st.maxHealth,
			})
		end)
	end

	-- Phase 1: the three anchors.
	local anchorHealth = Tarakasura.anchorHealthFor(encounter)
	for i = 1, Tarakasura.AnchorCount do
		local anchor = buildAnchor(i, anchorHealth, function()
			if not st.active then
				return
			end
			st.anchorsLeft -= 1
			broadcastAll({ moonAnchor = true, remaining = st.anchorsLeft })
			summonGuards(Vector3.new(0, 4, 0), Tarakasura.GuardArchetype, Tarakasura.GuardsPerAnchor)
			if st.anchorsLeft > 0 then
				speak(Tarakasura.Lines.anchorDown)
			else
				descend()
			end
		end)
		table.insert(st.anchors, anchor)
	end

	task.delay(1.2, function()
		if st.active then
			speak(Tarakasura.Lines.spawn)
		end
	end)

	humanoid.HealthChanged:Connect(function(health: number)
		if st.descended and not st.broken then
			broadcastAll({ bossState = "health", bossHealth = health, bossMaxHealth = st.maxHealth })
			-- The boon: mortals may break him, never end him.
			if health > 0 and health <= st.maxHealth * Tarakasura.BrokenFraction then
				task.spawn(breakSequence, st, onClear)
			end
		end
	end)

	-- If a single blow overkills straight past the boon, the Vel still takes
	-- the ending — the myth is not optional.
	humanoid.Died:Connect(function()
		if st.broken or not st.active then
			return
		end
		st.broken = true
		st.active = false
		local breakerId = model:GetAttribute("LastAttacker")
		local breaker = if typeof(breakerId) == "number" then Players:GetPlayerByUserId(breakerId) else nil
		task.spawn(function()
			velFalls(st, 1.0)
			victory(st, breaker, onClear)
		end)
	end)

	-- The fight loop (phase 2 only; the anchors carry phase 1).
	task.spawn(function()
		while st.active and st.model.Parent do
			task.wait(0.25)
			if not st.active or st.sequenceRunning or not st.descended or st.broken then
				continue
			end

			local frac = st.humanoid.Health / st.maxHealth
			local targetStage = Tarakasura.stageFor(frac)
			if targetStage > st.stage then
				st.stage = targetStage
				local stats = Tarakasura.statsForStage(st.stage)
				st.humanoid.WalkSpeed = stats.walkSpeed
				local addCount = Tarakasura.SummonAtStage[st.stage]
				if addCount then
					summonGuards(st.root.Position, Tarakasura.SummonArchetype, addCount)
				end
				if st.stage == 1 then
					speak(Tarakasura.Lines.wounded)
				elseif st.stage == 2 then
					speak(Tarakasura.Lines.furious)
				elseif st.stage == 3 then
					speak(Tarakasura.Lines.enrage)
					broadcastAll({ raidEnrage = true })
					local headPart = st.model:FindFirstChild("Head")
					if headPart and headPart:IsA("BasePart") then
						local rage = Instance.new("Fire")
						rage.Size = 6
						rage.Heat = 12
						rage.Color = MOONLIGHT
						rage.SecondaryColor = Color3.fromRGB(60, 80, 160)
						rage.Parent = headPart
					end
				end
			end

			local stats = Tarakasura.statsForStage(st.stage)
			local player, playerRoot, playerHum, dist = nearestPlayer(st.root.Position)
			if not player or not playerRoot or not playerHum then
				continue
			end

			st.humanoid:MoveTo(playerRoot.Position)

			local now = os.clock()
			if st.nextSlamAt == 0 then
				st.nextSlamAt = now + 6
			end
			if now >= st.nextSlamAt and dist <= Tarakasura.Slam.radius + 12 then
				st.nextSlamAt = now + Tarakasura.Slam.cooldown
				task.spawn(moonfall, st)
			elseif dist <= stats.meleeRange and now >= st.nextMeleeAt then
				st.nextMeleeAt = now + stats.meleeCooldown
				Net.AnimEvent:FireAllClients(st.model, "enemySwing")
				EnemyService.resolveHitOnPlayer(player, playerRoot, playerHum, stats.meleeDamage, st.root.Position, nil)
			elseif dist > stats.meleeRange and now >= st.nextVolleyAt then
				st.nextVolleyAt = now + stats.volleyCooldown
				volley(st, stats, player)
			end
		end
	end)
end

-- Party wipe: the Moon keeps its captive (no spoils, no mercy).
function WarMoonRaid.clear()
	local st = fight
	if not st then
		return
	end
	st.active = false
	st.sequenceRunning = true
	for _, anchor in st.anchors do
		if anchor.Parent then
			anchor:Destroy()
		end
	end
	if st.model then
		st.model:Destroy()
	end
	fight = nil
end

return WarMoonRaid
