--!strict
-- Bandit-beater director: spawns escalating waves, tracks clears, rewards, repeats.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local Net = require(ReplicatedStorage.Shared.Net)
local Waves = require(ReplicatedStorage.Shared.Waves)
local EnemyTypes = require(ReplicatedStorage.Shared.EnemyTypes)
local Bosses = require(ReplicatedStorage.Shared.Bosses)
local EnemyService = require(script.Parent.EnemyService)
local ProgressionService = require(script.Parent.ProgressionService)
local PlayerRegistry = require(script.Parent.PlayerRegistry)
local QuestService = require(script.Parent.QuestService)

local ARENA_RADIUS = 45

local currentWave = 0
local remaining = 0
local started = false

local function announce(data: { [string]: any })
	for _, p in Players:GetPlayers() do
		Net.CombatFeedback:FireClient(p, data)
	end
end

local startWave: (number) -> ()

local function onWaveClear(wave: number)
	local bonus = Waves.bonusXp(wave)
	for _, p in Players:GetPlayers() do
		ProgressionService.awardXp(p, bonus)
		-- Everyone standing when the wave falls records the depth.
		local state = PlayerRegistry.get(p)
		state.bestWave = math.max(state.bestWave, wave)
		QuestService.onWaveClear(p)
	end
	announce({ waveState = "clear", wave = wave, bonusXp = bonus, intermission = Waves.Intermission })
	task.delay(Waves.Intermission, function()
		startWave(wave + 1)
	end)
end

-- A boss wave: one scaled boss plus a handful of adds.
local function spawnBossWave(wave: number)
	local boss = Bosses.forWave(wave, Waves.BossInterval)
	local adds = Waves.compose(math.max(1, math.floor(wave / 3)), EnemyTypes.List :: any)
	remaining = 1 + #adds
	announce({ waveState = "boss", wave = wave, bossName = boss.displayName, bossTitle = boss.title })

	local function onOneDead(_killer: Player?)
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
			local a = EnemyTypes.get(id)
			local angle = (2 * math.pi * i) / #adds
			local pos = Vector3.new(math.cos(angle) * ARENA_RADIUS, 6, math.sin(angle) * ARENA_RADIUS)
			EnemyService.spawn(a, pos, onOneDead)
		end)
	end
end

function startWave(wave: number)
	currentWave = wave
	if Waves.isBossWave(wave) then
		spawnBossWave(wave)
		return
	end
	local ids = Waves.compose(wave, EnemyTypes.List :: any)
	remaining = #ids
	announce({ waveState = "start", wave = wave, enemiesLeft = remaining })

	local total = #ids
	for i, id in ids do
		task.spawn(function()
			local archetype = EnemyTypes.get(id)
			local angle = (2 * math.pi * i) / total + math.random() * 0.4
			local pos = Vector3.new(math.cos(angle) * ARENA_RADIUS, 6, math.sin(angle) * ARENA_RADIUS)
			EnemyService.spawn(archetype, pos, function(_killer: Player?)
				remaining -= 1
				announce({ waveState = "progress", wave = currentWave, enemiesLeft = math.max(0, remaining) })
				if remaining <= 0 then
					onWaveClear(wave)
				end
			end)
		end)
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

Players.PlayerAdded:Connect(function()
	task.spawn(beginIfNeeded)
end)
if #Players:GetPlayers() > 0 then
	task.spawn(beginIfNeeded)
end

print("[Dharma] WaveService ready.")
