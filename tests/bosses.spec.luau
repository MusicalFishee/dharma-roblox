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
local b4 = Bosses.forWave(20, interval) -- 4th
local b5 = Bosses.forWave(25, interval) -- 5th
local b6 = Bosses.forWave(30, interval) -- 6th (Vritra, the Himavat expansion)
local b7 = Bosses.forWave(35, interval) -- 7th (Kalanemi)
local b8 = Bosses.forWave(40, interval) -- 8th -> cycles back to first boss id

check("boss is flagged isBoss", b1.isBoss == true)
check("boss has a title", #b1.title > 0)
check("bosses are far tankier than normal enemies", b1.maxHealth >= 1000)
check("boss reward is big", b1.xpReward >= 400)

local distinct = { b1.id, b2.id, b3.id, b4.id, b5.id, b6.id, b7.id }
local seen: { [string]: boolean } = {}
local allDistinct = true
for _, id in distinct do
	if seen[id] then
		allDistinct = false
	end
	seen[id] = true
end
check("roster has 7 distinct bosses in a cycle", allDistinct)
check("roster cycles (8th encounter == 1st boss id)", b8.id == b1.id)
check("deeper encounters scale health up", b8.maxHealth > b1.maxHealth)
check("deeper encounters scale damage up", b8.attackDamage > b1.attackDamage)
check("deeper encounters scale XP up", b8.xpReward > b1.xpReward)

print(string.format("\n%d passed, %d failed", passed, failed))
if failed > 0 then
	print("FAILURES: " .. table.concat(failures, ", "))
	process.exit(1)
end
