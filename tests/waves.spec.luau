--!strict
-- Headless tests for wave composition.

local process = require("@lune/process")
local Waves = require("../src/shared/Waves")
local EnemyTypes = require("../src/shared/EnemyTypes")

local passed, failed = 0, 0
local failures: { string } = {}
local function check(name: string, cond: boolean)
	if cond then
		passed += 1
		print("  ok   " .. name)
	else
		failed += 1
		table.insert(failures, name)
		print("  FAIL " .. name)
	end
end

print("Waves")

-- Counts and rewards escalate.
check("wave 1 has 3 enemies", Waves.enemyCount(1) == 3)
check("later waves are bigger", Waves.enemyCount(10) > Waves.enemyCount(1))
check("enemy count is capped", Waves.enemyCount(1000) <= 18)
check("bonus XP grows with wave", Waves.bonusXp(10) > Waves.bonusXp(1))

-- Composition returns the right count of valid archetypes.
local roster = EnemyTypes.List :: any
local comp1 = Waves.compose(1, roster)
check("compose(1) returns enemyCount ids", #comp1 == Waves.enemyCount(1))

local comp8 = Waves.compose(8, roster)
check("compose(8) returns enemyCount ids", #comp8 == Waves.enemyCount(8))

local allValid = true
for _, id in comp8 do
	if EnemyTypes.List[id] == nil then
		allValid = false
	end
end
check("all composed ids are real archetypes", allValid)

-- Determinism: same rng -> same composition.
local function fixedRng(): () -> number
	local seq = { 0.05, 0.35, 0.65, 0.95, 0.5, 0.2, 0.8, 0.1 }
	local i = 0
	return function()
		i += 1
		return seq[((i - 1) % #seq) + 1]
	end
end
local a = Waves.compose(3, roster, fixedRng())
local b = Waves.compose(3, roster, fixedRng())
check("same rng -> identical wave", table.concat(a, ",") == table.concat(b, ","))

-- Boss waves land every 5th wave.
check("wave 5 is a boss wave", Waves.isBossWave(5))
check("wave 10 is a boss wave", Waves.isBossWave(10))
check("wave 4 is not a boss wave", not Waves.isBossWave(4))

-- The minWave gate: a bloodline absent before its hour.
local gatedRoster = {
	Common = { weight = 5, maxHealth = 100 },
	Serpent = { weight = 100, maxHealth = 100, minWave = 30 },
}
local function midRng(): number
	return 0.5
end
local before = Waves.compose(29, gatedRoster :: any, midRng)
local seenBefore = false
for _, id in before do
	if id == "Serpent" then
		seenBefore = true
	end
end
check("the serpents sleep before their hour", #before > 0 and not seenBefore)
local after = Waves.compose(30, gatedRoster :: any, midRng)
local seenAfter = false
for _, id in after do
	if id == "Serpent" then
		seenAfter = true
	end
end
check("the serpents wake on the hour", seenAfter)
check("wave 0 is not a boss wave", not Waves.isBossWave(0))

print(string.format("\n%d passed, %d failed", passed, failed))
if failed > 0 then
	print("FAILURES: " .. table.concat(failures, ", "))
	process.exit(1)
end
