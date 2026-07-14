--!strict
-- Headless tests for the boss roster.

local process = require("@lune/process")
local Bosses = require("../src/shared/Bosses")

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

print("Bosses")

local interval = 5
local b1 = Bosses.forWave(5, interval) -- 1st boss encounter
local b2 = Bosses.forWave(10, interval) -- 2nd
local b3 = Bosses.forWave(15, interval) -- 3rd
local b4 = Bosses.forWave(20, interval) -- 4th -> cycles back to first boss id

check("boss is flagged isBoss", b1.isBoss == true)
check("boss has a title", #b1.title > 0)
check("bosses are far tankier than normal enemies", b1.maxHealth >= 1000)
check("boss reward is big", b1.xpReward >= 400)

check("roster cycles (4th encounter == 1st boss id)", b4.id == b1.id)
check("deeper encounters scale health up", b4.maxHealth > b1.maxHealth)
check("deeper encounters scale damage up", b4.attackDamage > b1.attackDamage)
check("deeper encounters scale XP up", b4.xpReward > b1.xpReward)

-- Distinct bosses in a cycle.
check("consecutive boss waves are different bosses", b1.id ~= b2.id and b2.id ~= b3.id)

print(string.format("\n%d passed, %d failed", passed, failed))
if failed > 0 then
	print("FAILURES: " .. table.concat(failures, ", "))
	process.exit(1)
end
