--!strict
-- Bandit-beater director: spawns escalating waves, tracks clears, rewards, repeats.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local Net = require(ReplicatedStorage.Shared.Net)
local Waves = require(ReplicatedStorage.Shared.Waves)
local Survival = require(ReplicatedStorage.Shared.Survival)
local Milestones = require(ReplicatedStorage.Shared.Milestones)
local Doshas = require(ReplicatedStorage.Shared.Doshas)
local Grade = require(ReplicatedStorage.Shared.Grade)
local Loot = require(ReplicatedStorage.Shared.Loot)
local Trial = require(ReplicatedStorage.Shared.Trial)
local TrialBoss = require(script.Parent.TrialBoss)
local Ravana = require(ReplicatedStorage.Shared.Ravana)
local RavanaRaid = require(script.Parent.RavanaRaid)
local EnemyTypes = require(ReplicatedStorage.Shared.EnemyTypes)
local Bosses = require(ReplicatedStorage.Shared.Bosses)
local Elites = require(ReplicatedStorage.Shared.Elites)
local Affixes = require(ReplicatedStorage.Shared.Affixes)
local EnemyService = require(script.Parent.EnemyService)
local ZoneService = require(script.Parent.ZoneService)
local UtsavaService = require(script.Parent.UtsavaService)
local BhootaService = require(script.Parent.BhootaService)
local VaraService = require(script.Parent.VaraService)
local RitesService = require(script.Parent.RitesService)
local Shapatha = require(ReplicatedStorage.Shared.Shapatha)
local ProgressionService = require(script.Parent.ProgressionService)
local PlayerRegistry = require(script.Parent.PlayerRegistry)
local QuestService = require(script.Parent.QuestService)
local StoryService = require(script.Parent.StoryService)

local ARENA_RADIUS = 45

local currentWave = 0
local remaining = 0
local started = false
local checkpoint = 0 -- deepest boss wave banked; a wiped run reforms just past it
local waveGen = 0 -- bumps on every (re)start; invalidates stale enemy-death callbacks
local failing = false -- true from the moment the party wipes until the run reforms
local waveSpawnCount = 0 -- how many foes this wave fielded (grades judge against it)
local activeDosha: { wave: number, def: Doshas.DoshaDef }? = nil
local activeOath: { wave: number, def: Shapatha.OathDef }? = nil
local alivePlayers: { [Player]: boolean } = {}

-- A meditator is away from the war; the war owes them nothing.
local function isMeditating(p: Player): boolean
	local c = p.Character
	return c ~= nil and c:GetAttribute("DharmaDhyana") == true
end

local function announce(data: { [string]: any })
	for _, p in Players:GetPlayers() do
		Net.CombatFeedback:FireClient(p, data)
	end
end

-- Fetch the archetype for an id: elite roll, then this wave's dosha (if marked).
local function resolveArchetype(id: string)
	local archetype = EnemyTypes.get(id)
	if Elites.roll() then
		archetype = Elites.makeElite(archetype)
	end
	local dosha = activeDosha
	if dosha and dosha.wave == currentWave then
		archetype = Doshas.applyToArchetype(dosha.def, archetype)
	end
	local oathState = activeOath
	if oathState and oathState.wave == currentWave then
		archetype = Shapatha.applyToArchetype(oathState.def, archetype)
	end
	local affixId = Affixes.roll(currentWave, archetype.isBoss == true, function()
		return math.random()
	end)
	if affixId then
		archetype = Affixes.tag(archetype, affixId)
	end
	return archetype
end

local startWave: (number) -> ()
local failRun: () -> ()

local function onWaveClear(wave: number)
	checkpoint = Survival.checkpointFor(wave, checkpoint, Waves.BossInterval)
	-- Punarjanma: the wave breaks, and every wandering bhoota returns to flesh.
	BhootaService.setBattleActive(false)
	RitesService.setBattleActive(false)

	-- A kept oath pays its multiplied bounty to everyone standing.
	local oathState = activeOath
	if oathState and oathState.wave == wave then
		activeOath = nil
		local bounty = Shapatha.bountyFor(oathState.def, wave)
		for _, p in Players:GetPlayers() do
			if isMeditating(p) then
				continue
			end
			local pstate = PlayerRegistry.get(p)
			pstate.gold = Loot.clampGold(pstate.gold + bounty.gold)
			ProgressionService.awardXp(p, bounty.xp)
			Net.CombatFeedback:FireClient(p, { goldUpdate = true, gained = 0, gold = pstate.gold })
			Net.CombatFeedback:FireClient(p, { oathBounty = true, name = oathState.def.name, gold = bounty.gold, xp = bounty.xp })
		end
	end
	for _, p in BhootaService.releaseAll() do
		alivePlayers[p] = true
	end
	local bonus = Waves.bonusXp(wave)
	for _, p in Players:GetPlayers() do
		if isMeditating(p) then
			continue -- the grove pays the grove's wage
		end
		-- The wave judges your conduct; S-rank pays half again.
		local state = PlayerRegistry.get(p)
		local tally = { kills = state.waveKills, parries = state.waveParries, timesHit = state.waveTimesHit, downs = state.waveDowns }
		local grade = Grade.gradeFor(Grade.score(tally), waveSpawnCount)
		ProgressionService.awardXp(p, math.floor(bonus * Grade.xpMult(grade)))
		Net.CombatFeedback:FireClient(p, {
			waveGrade = grade,
			gradeColor = Grade.Color[grade],
			kills = state.waveKills,
			parries = state.waveParries,
		})
		-- Everyone standing when the wave falls records the depth.
		state.bestWave = math.max(state.bestWave, wave)
		QuestService.onWaveClear(p)
		StoryService.onEvent(p) -- a deeper wave may turn an Adhyaya's page
	end
	announce({ waveState = "clear", wave = wave, bonusXp = bonus, intermission = Waves.Intermission })

	-- A slain boss leaves boons on its corpse (the god's trial blesses instead).
	if Waves.isBossWave(wave) and not Trial.isTrialWave(wave) then
		VaraService.offerAll()
	end

	-- A marked wave pays its bounty when it breaks.
	local dosha = activeDosha
	if dosha and dosha.wave == wave then
		activeDosha = nil
		local bounty = Doshas.bountyFor(dosha.def, wave)
		for _, p in Players:GetPlayers() do
			if isMeditating(p) then
				continue
			end
			local state = PlayerRegistry.get(p)
			state.gold = Loot.clampGold(state.gold + bounty.gold)
			ProgressionService.awardXp(p, bounty.xp)
			Net.CombatFeedback:FireClient(p, { goldUpdate = true, gained = 0, gold = state.gold })
			Net.CombatFeedback:FireClient(p, { doshaBounty = true, name = dosha.def.name, gold = bounty.gold, xp = bounty.xp })
		end
	end

	-- Landmark waves pay a bounty and confer a title.
	local milestone = Milestones.forWave(wave)
	if milestone then
		for _, p in Players:GetPlayers() do
			if isMeditating(p) then
				continue
			end
			local state = PlayerRegistry.get(p)
			state.gold = Loot.clampGold(state.gold + milestone.gold)
			-- Silent gold-counter refresh, then the headline title banner.
			Net.CombatFeedback:FireClient(p, { goldUpdate = true, gained = 0, gold = state.gold })
			Net.CombatFeedback:FireClient(p, {
				milestone = true,
				title = milestone.title,
				wave = milestone.wave,
				gold = milestone.gold,
			})
		end
	end

	task.delay(Waves.Intermission, function()
		startWave(wave + 1)
	end)
end

-- A boss wave: one scaled boss plus a handful of adds.
local function spawnBossWave(wave: number, gen: number)
	local boss = Bosses.forWave(wave, Waves.BossInterval)
	local adds = Waves.compose(math.max(1, math.floor(wave / 3)), EnemyTypes.List :: any)
	remaining = 1 + #adds
	waveSpawnCount = remaining
	announce({ waveState = "boss", wave = wave, bossName = boss.displayName, bossTitle = boss.title })

	local function onOneDead(_killer: Player?)
		if gen ~= waveGen then
			return -- this wave was wiped/superseded; ignore the straggler
		end
		remaining -= 1
		announce({ waveState = "progress", wave = currentWave, enemiesLeft = math.max(0, remaining) })
		if remaining <= 0 then
			onWaveClear(wave)
		end
	end

	task.spawn(function()
		EnemyService.spawn(boss :: any, Vector3.new(0, 8, -ARENA_RADIUS), onOneDead)
	end)
	for i, id in adds do
		task.spawn(function()
			local a = resolveArchetype(id)
			local angle = (2 * math.pi * i) / #adds
			local pos = Vector3.new(math.cos(angle) * ARENA_RADIUS, 6, math.sin(angle) * ARENA_RADIUS)
			EnemyService.spawn(a, pos, onOneDead)
		end)
	end
end

function startWave(wave: number)
	waveGen += 1
	local gen = waveGen
	currentWave = wave
	ZoneService.applyForWave(wave)
	BhootaService.setBattleActive(true)
	RitesService.setBattleActive(true)
	activeOath = nil

	-- Fresh conduct ledgers for the new wave.
	for _, p in Players:GetPlayers() do
		local state = PlayerRegistry.get(p)
		state.waveKills = 0
		state.waveParries = 0
		state.waveTimesHit = 0
		state.waveDowns = 0
	end
	waveSpawnCount = 10 -- nominal for bespoke encounters (trial/raid); real waves overwrite

	-- The mark of the age: waves ending in 7 arrive afflicted.
	activeDosha = nil
	if Doshas.isDoshaWave(wave) then
		local def = Doshas.roll(wave, function()
			return math.random()
		end)
		if def then
			activeDosha = { wave = wave, def = def }
			announce({ dosha = true, name = def.name, announce = def.announce })
		end
	end

	-- Festival roll: never on the spectacle nights (boss / trial / raid).
	UtsavaService.onWaveStart(wave, Trial.isTrialWave(wave) or Ravana.isRaidWave(wave) or Waves.isBossWave(wave))

	-- The Kirata Trial claims its waves outright (no adds — the god comes alone).
	if Trial.isTrialWave(wave) then
		announce({ waveState = "boss", wave = wave, bossName = Trial.Phase1.name, bossTitle = Trial.Phase1.title })
		TrialBoss.begin(wave, function()
			if gen == waveGen then
				onWaveClear(wave)
			end
		end)
		return
	end

	-- The Ten-Headed King claims wave 50 and every 50th after (below the Trial, by law).
	if Ravana.isRaidWave(wave) then
		announce({ waveState = "boss", wave = wave, bossName = "Ravana", bossTitle = "the Ten-Headed King" })
		RavanaRaid.begin(wave, function()
			if gen == waveGen then
				onWaveClear(wave)
			end
		end)
		return
	end

	if Waves.isBossWave(wave) then
		spawnBossWave(wave, gen)
		return
	end
	-- A sworn oath binds only an ORDINARY wave (bespoke nights ignore the
	-- archetype scaling, so an oath there would be a free bounty). It WAITS
	-- through boss/trial/raid waves for the next plain one.
	local oathDef = RitesService.takePendingOath()
	if oathDef then
		activeOath = { wave = wave, def = oathDef }
		announce({ oathBegins = true, name = oathDef.name })
	end

	local ids = Waves.compose(wave, EnemyTypes.List :: any)
	remaining = #ids
	waveSpawnCount = remaining
	announce({ waveState = "start", wave = wave, enemiesLeft = remaining })

	local total = #ids
	for i, id in ids do
		task.spawn(function()
			local archetype = resolveArchetype(id)
			local angle = (2 * math.pi * i) / total + math.random() * 0.4
			local pos = Vector3.new(math.cos(angle) * ARENA_RADIUS, 6, math.sin(angle) * ARENA_RADIUS)
			EnemyService.spawn(archetype, pos, function(_killer: Player?)
				if gen ~= waveGen then
					return -- this wave was wiped/superseded; ignore the straggler
				end
				remaining -= 1
				announce({ waveState = "progress", wave = currentWave, enemiesLeft = math.max(0, remaining) })
				if remaining <= 0 then
					onWaveClear(wave)
				end
			end)
		end)
	end
end

-- Total party wipe: freeze the doomed wave, clear the board, reform at the checkpoint.
function failRun()
	if failing then
		return
	end
	failing = true
	waveGen += 1 -- every in-flight enemy-death callback from the doomed wave is now void
	local failedWave = currentWave
	-- The wipe scatters every boon, extinguishes the fire, and voids the oath.
	VaraService.scatterAll()
	RitesService.extinguish()
	RitesService.setBattleActive(false)
	activeOath = nil
	-- The reform restores everyone; wandering spirits come back to flesh with it.
	BhootaService.setBattleActive(false)
	for _, p in BhootaService.releaseAll() do
		alivePlayers[p] = true
	end
	EnemyService.clearAll()
	TrialBoss.clear() -- a wiped trial dissolves too (no blessing, no reward)
	RavanaRaid.clear() -- and the king keeps his heads
	local resume = Survival.restartWave(checkpoint, Waves.BossInterval)
	announce({
		waveState = "wipe",
		failedWave = failedWave,
		restartWave = resume,
		delay = Survival.RestartDelay,
	})
	task.delay(Survival.RestartDelay, function()
		failing = false
		startWave(resume)
	end)
end

local function countDowned(): (number, number)
	local total, downed = 0, 0
	for _, p in Players:GetPlayers() do
		total += 1
		-- Only players who spawned and then fell count as down; a player still
		-- loading in (no entry yet) mustn't trigger a wipe when a teammate dies.
		if alivePlayers[p] == false then
			downed += 1
		end
	end
	return total, downed
end

local function onPlayerDied(player: Player)
	if alivePlayers[player] == false then
		return -- this death already counted
	end
	alivePlayers[player] = false
	PlayerRegistry.get(player).stats.deaths += 1
	Net.CombatFeedback:FireClient(player, { youFell = true, wave = currentWave })
	if failing then
		return
	end
	local total, downed = countDowned()
	if Survival.isPartyWipe(total, downed) then
		failRun()
	end
end

local function hookPlayer(player: Player)
	local function onChar(char: Model)
		-- A body that spawns into the wander is not a fighter yet.
		alivePlayers[player] = not (BhootaService.shouldGhost(player) or BhootaService.isGhost(player))
		task.spawn(function()
			local hum = char:WaitForChild("Humanoid", 10)
			if hum and hum:IsA("Humanoid") then
				hum.Died:Connect(function()
					onPlayerDied(player)
				end)
			end
		end)
	end
	player.CharacterAdded:Connect(onChar)
	if player.Character then
		onChar(player.Character)
	end
end

local function beginIfNeeded()
	if started then
		return
	end
	started = true
	task.wait(3) -- let the world and players load in
	startWave(1)
end

Players.PlayerAdded:Connect(function(player)
	hookPlayer(player)
	task.spawn(beginIfNeeded)
end)
for _, p in Players:GetPlayers() do
	hookPlayer(p)
end
if #Players:GetPlayers() > 0 then
	task.spawn(beginIfNeeded)
end

Players.PlayerRemoving:Connect(function(player)
	alivePlayers[player] = nil
end)

print("[Dharma] WaveService ready.")
