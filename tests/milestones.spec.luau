--!strict
-- Milestone rewards: landmark waves, ascending bounties, boss-wave alignment.

local process = require("@lune/process")
local Milestones = require("../src/shared/Milestones")
local Waves = require("../src/shared/Waves")

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

print("Milestones")

local list = Milestones.List
check("there are milestones to chase", #list > 0)

local wavesAscend, goldAscends = true, true
for i = 2, #list do
	if list[i].wave <= list[i - 1].wave then
		wavesAscend = false
	end
	if list[i].gold <= list[i - 1].gold then
		goldAscends = false
	end
end
check("milestone waves ascend", wavesAscend)
check("milestone bounties ascend", goldAscends)

local titledAndPaid, bossAligned = true, true
for _, m in list do
	if m.title == "" or m.gold <= 0 then
		titledAndPaid = false
	end
	if m.wave % Waves.BossInterval ~= 0 then
		bossAligned = false
	end
end
check("every milestone has a title and a positive bounty", titledAndPaid)
check("every milestone lands on a boss wave", bossAligned)

local first = list[1]
check("forWave hits an exact milestone", Milestones.forWave(first.wave) ~= nil)
check("forWave misses a non-milestone wave", Milestones.forWave(first.wave + 1) == nil)
check("forWave returns the matching milestone", (Milestones.forWave(first.wave) :: any).title == first.title)
check("forWave on wave 0 is nil", Milestones.forWave(0) == nil)

print(string.format("\n%d passed, %d failed", passed, failed))
if failed > 0 then
	print("FAILURES: " .. table.concat(failures, ", "))
	process.exit(1)
end
