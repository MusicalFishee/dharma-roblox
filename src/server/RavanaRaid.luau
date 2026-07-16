--!strict
-- Ravana (server): the wave-50 raid — the mightiest thing in the game that can
-- die. Ten crown-orbs circle his head; every tenth of his pool severs one: he
-- kneels (a stagger you should feast on), the orb falls dark, and he taunts you
-- through the loss. Certain severances call rakshasa reinforcements; shedding
-- Krodha unlocks the Chandrahasa Arc slam; when only Ahamkara — the Ego —
-- remains, he enrages. Victory pays everyone XP + shards and a GUARANTEED
-- Dashanana mythic relic. He sits beneath the Kirata Trial in every number,
-- always (the supremacy test in ravana.spec holds the line).

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CollectionService = game:GetService("CollectionService")
local TweenService = game:GetService("TweenService")
local Players = game:GetService("Players")
local Debris = game:GetService("Debris")

local Net = require(ReplicatedStorage.Shared.Net)
local Ravana = require(ReplicatedStorage.Shared.Ravana)
local EnemyTypes = require(ReplicatedStorage.Shared.EnemyTypes)
local BossSpecials = require(ReplicatedStorage.Shared.BossSpecials)
local Enchants = require(ReplicatedStorage.Shared.Enchants)
local Relics = require(ReplicatedStorage.Shared.Relics)
local PlayerRegistry = require(script.Parent.PlayerRegistry)
local ProgressionService = require(script.Parent.ProgressionService)
local EnemyService = require(script.Parent.EnemyService)
local RelicService = require(script.Parent.RelicService)
local QuestService = require(script.Parent.QuestService)
local StoryService = require(script.Parent.StoryService)

local ENEMY_TAG = "DharmaEnemy"
local SPAWN_POS = Vector3.new(0, 8, -40)
local SKIN = Color3.fromRGB(42, 32, 54)
local GOLD = Color3.fromRGB(255, 200, 60)

local RavanaRaid = {}

type FightState = {
	model: Model,
	humanoid: Humanoid,
	root: BasePart,
	maxHealth: number,
	encounter: number,
	severed: number,
	orbs: { BasePart },
	active: boolean,
	sequenceRunning: boolean,
	nextVolleyAt: number,
	nextMeleeAt: number,
	nextSlamAt: number,
	saidHalfway: boolean,
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
		if not root or not hum or hum.Health <= 0 or char:GetAttribute("DharmaDowned") == true then
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
		warn("[Dharma] Failed to create Ravana rig: " .. tostring(model))
		return nil
	end
	return model
end

-- The crown: ten gold orbs ringing his head, one per unsevered vice.
local function buildCrown(model: Model): { BasePart }
	local head = model:FindFirstChild("Head")
	local orbs: { BasePart } = {}
	if not head or not head:IsA("BasePart") then
		return orbs
	end
	for i = 1, Ravana.HeadCount do
		local angle = (2 * math.pi * i) / Ravana.HeadCount
		local orb = Instance.new("Part")
		orb.Name = "CrownOrb" .. i
		orb.Shape = Enum.PartType.Ball
		orb.Size = Vector3.new(1.1, 1.1, 1.1)
		orb.Color = GOLD
		orb.Material = Enum.Material.Neon
		orb.CanCollide = false
		orb.CanQuery = false
		orb.Massless = true
		orb.CFrame = head.CFrame * CFrame.new(math.cos(angle) * 3.4, 3.2, math.sin(angle) * 3.4)
		orb.Parent = model
		local weld = Instance.new("WeldConstraint")
		weld.Part0 = orb
		weld.Part1 = head
		weld.Parent = orb
		table.insert(orbs, orb)
	end
	return orbs
end

-- Chandrahasa bolt: a dark-gold arrow with real flight time and a miss window.
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
	bolt.Color = Color3.fromRGB(220, 160, 40)
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

local function volley(st: FightState, stats: Ravana.StageStats, target: Player)
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

-- The Chandrahasa Arc: a telegraphed ring of the moon-blade.
local function slamArc(st: FightState)
	local cx, cy, cz = st.root.Position.X, st.root.Position.Y - 2.5, st.root.Position.Z
	Net.AnimEvent:FireAllClients(st.model, "ult")
	broadcastAll({
		bossSpecial = "telegraph",
		name = "Chandrahasa Arc",
		x = cx,
		y = cy,
		z = cz,
		radius = Ravana.Slam.radius,
		duration = Ravana.Slam.telegraph,
	})
	task.wait(Ravana.Slam.telegraph)
	if not st.active then
		return
	end

	Net.AnimEvent:FireAllClients(st.model, "combo4")
	broadcastAll({ bossSpecial = "impact", x = cx, y = cy, z = cz, radius = Ravana.Slam.radius })

	local targets: { BossSpecials.Target } = {}
	for _, plr in Players:GetPlayers() do
		local char = plr.Character
		local hrp = char and getRoot(char)
		if hrp then
			table.insert(targets, { key = plr, x = hrp.Position.X, z = hrp.Position.Z })
		end
	end
	for _, key in BossSpecials.hitTargets({ x = cx, z = cz }, targets, Ravana.Slam.radius) do
		local victim = key :: Player
		local char = victim.Character
		local hum = char and char:FindFirstChildOfClass("Humanoid")
		local hrp = char and getRoot(char)
		if not char or not hum or hum.Health <= 0 then
			continue
		end
		local vstate = PlayerRegistry.get(victim)
		local res = BossSpecials.resolveBlast(Ravana.Slam.damage, os.clock() < vstate.dodgeUntil, vstate.isBlocking)
		if res.damage > 0 then
			local vench = Enchants.effects(vstate.enchant)
			local vward = if os.clock() < vstate.wardUntil then vstate.wardMult else 1
			local vrelic = Relics.totalBonus(Relics.equippedList(vstate.relics.equipped))
			hum:TakeDamage(res.damage * (vench.damageTakenMult or 1) * vward * vrelic.damageTakenMult)
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

-- Certain severances tear reinforcements out of the dark.
local function summonAdds(st: FightState, count: number)
	local archetype = EnemyTypes.get(Ravana.SummonArchetype)
	for i = 1, count do
		local angle = (2 * math.pi * i) / count
		local pos = st.root.Position + Vector3.new(math.cos(angle) * 18, 4, math.sin(angle) * 18)
		task.spawn(function()
			EnemyService.spawn(archetype, pos, function() end)
		end)
	end
end

-- One head falls: he kneels, the orb drops dark, the head taunts, he rises crueler.
local function severHead(st: FightState)
	st.sequenceRunning = true
	st.severed += 1
	local head = Ravana.Heads[st.severed]
	local remaining = Ravana.HeadCount - st.severed

	-- The stagger: rooted and readable — feast.
	st.humanoid.WalkSpeed = 0
	Net.AnimEvent:FireAllClients(st.model, "flinch")

	-- The orb falls dark and drops from the crown.
	local orb = st.orbs[st.severed]
	if orb and orb.Parent then
		local weld = orb:FindFirstChildOfClass("WeldConstraint")
		if weld then
			weld:Destroy()
		end
		orb.Anchored = false
		orb.CanCollide = false
		orb.Color = Color3.fromRGB(30, 26, 34)
		orb.Material = Enum.Material.Slate
		Debris:AddItem(orb, 4)
	end

	broadcastAll({
		headFall = true,
		headName = head.name,
		vice = head.vice,
		remaining = remaining,
	})
	speak("Ravana", head.line)

	if st.saidHalfway == false and st.severed >= 5 then
		st.saidHalfway = true
		task.delay(1.2, function()
			if st.active then
				speak("Ravana", Ravana.Lines.halfway)
			end
		end)
	end

	local addCount = Ravana.SummonAtSevered[st.severed]
	if addCount then
		summonAdds(st, addCount)
	end

	task.wait(Ravana.StaggerSeconds)
	if not st.active then
		return
	end

	-- He rises, fiercer. Only the Ego left: enrage.
	local stats = Ravana.statsForStage(st.severed)
	st.humanoid.WalkSpeed = stats.walkSpeed
	if stats.enraged then
		speak("Ravana", Ravana.Lines.enrage)
		local headPart = st.model:FindFirstChild("Head")
		if headPart and headPart:IsA("BasePart") then
			local rage = Instance.new("Fire")
			rage.Size = 6
			rage.Heat = 12
			rage.Color = Color3.fromRGB(255, 60, 30)
			rage.SecondaryColor = Color3.fromRGB(120, 10, 10)
			rage.Parent = headPart
		end
		broadcastAll({ raidEnrage = true })
	end
	st.sequenceRunning = false
end

-- The fall of Dashanana: dying words, spoils for all, a guaranteed mythic each.
local function victory(st: FightState, killer: Player?, onClear: () -> ())
	if not st.active then
		return
	end
	st.active = false
	st.sequenceRunning = true
	CollectionService:RemoveTag(st.model, ENEMY_TAG)

	speak("Ravana", Ravana.Lines.defeated)
	broadcastAll({ bossState = "defeated", bossName = "Ravana" })
	task.wait(2.0)

	local spoils = Ravana.rewardFor(st.encounter)
	for _, p in Players:GetPlayers() do
		local pstate = PlayerRegistry.tryGet(p)
		if not pstate then
			continue
		end
		pstate.stats.raidClears += 1 -- unlocks « Ravana's Bane »
		pstate.shards += spoils.shards
		Net.CombatFeedback:FireClient(p, { shardUpdate = true, gained = spoils.shards, shards = pstate.shards })
		ProgressionService.awardXp(p, spoils.xp)
		RelicService.grantRaidTrophy(p)
		StoryService.onEvent(p) -- the king's fall turns Adhyaya VI
	end
	-- The killing blow gets the kill-ledger credit (kills, boss quests, dailies).
	if killer then
		local kstate = PlayerRegistry.tryGet(killer)
		if kstate then
			kstate.stats.kills += 1
			kstate.stats.bossKills += 1
			QuestService.onKill(killer, "Ravana", true, false)
		end
	end

	broadcastAll({ raidVictory = true, message = Ravana.Lines.victory })

	-- Any reinforcements die with their king.
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

function RavanaRaid.begin(wave: number, onClear: () -> ())
	local model = spawnRig()
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

	local encounter = math.max(1, Ravana.encounterIndex(wave))
	local maxHealth = Ravana.healthFor(encounter)
	local baseStats = Ravana.statsForStage(0)

	humanoid.MaxHealth = maxHealth
	humanoid.Health = maxHealth
	humanoid.WalkSpeed = baseStats.walkSpeed
	humanoid.DisplayName = "Ravana"
	pcall(function()
		model:ScaleTo(2.8) -- vast — but Nataraja towers higher, by law
	end)
	model:PivotTo(CFrame.new(SPAWN_POS))
	model.Name = "Ravana"
	model:SetAttribute("IsBoss", true)
	model.Parent = workspace
	CollectionService:AddTag(model, ENEMY_TAG)

	local head = model:FindFirstChild("Head")
	if head and head:IsA("BasePart") then
		local light = Instance.new("PointLight")
		light.Brightness = 4
		light.Range = 26
		light.Color = GOLD
		light.Parent = head
	end

	local st: FightState = {
		model = model,
		humanoid = humanoid,
		root = root,
		maxHealth = maxHealth,
		encounter = encounter,
		severed = 0,
		orbs = buildCrown(model),
		active = true,
		sequenceRunning = false,
		nextVolleyAt = os.clock() + 3.0,
		nextMeleeAt = 0,
		nextSlamAt = math.huge,
		saidHalfway = false,
	}
	fight = st

	broadcastAll({
		bossState = "spawn",
		bossName = "Ravana",
		bossTitle = "the Ten-Headed King",
		bossHealth = maxHealth,
		bossMaxHealth = maxHealth,
	})
	humanoid.HealthChanged:Connect(function(health: number)
		broadcastAll({ bossState = "health", bossHealth = health, bossMaxHealth = st.maxHealth })
	end)

	local killedBy: Player? = nil
	humanoid.Died:Connect(function()
		local killerId = model:GetAttribute("LastAttacker")
		if typeof(killerId) == "number" then
			killedBy = Players:GetPlayerByUserId(killerId)
		end
		task.spawn(victory, st, killedBy, onClear)
	end)

	task.delay(1.2, function()
		if st.active then
			speak("Ravana", Ravana.Lines.spawn)
		end
	end)

	-- The fight loop.
	task.spawn(function()
		while st.active and st.model.Parent do
			task.wait(0.25)
			if not st.active or st.sequenceRunning then
				continue
			end

			-- Heads fall as tenths of the pool go — one severance at a time.
			if st.humanoid.Health > 0 then
				local targetStage = Ravana.stageFor(st.humanoid.Health / st.maxHealth)
				if st.severed < targetStage then
					severHead(st)
					continue
				end
			end

			local stats = Ravana.statsForStage(st.severed)
			if stats.slamEnabled and st.nextSlamAt == math.huge then
				st.nextSlamAt = os.clock() + 4 -- the Arc wakes when Krodha falls
			end

			local player, playerRoot, playerHum, dist = nearestPlayer(st.root.Position)
			if not player or not playerRoot or not playerHum then
				continue
			end

			-- The king always walks you down.
			st.humanoid:MoveTo(playerRoot.Position)

			local now = os.clock()
			if stats.slamEnabled and now >= st.nextSlamAt and dist <= Ravana.Slam.radius + 12 then
				st.nextSlamAt = now + Ravana.Slam.cooldown
				task.spawn(slamArc, st)
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

-- Party wipe: the king keeps his heads (no spoils, no mercy).
function RavanaRaid.clear()
	local st = fight
	if not st then
		return
	end
	st.active = false
	st.sequenceRunning = true
	if st.model then
		st.model:Destroy()
	end
	fight = nil
end

return RavanaRaid
