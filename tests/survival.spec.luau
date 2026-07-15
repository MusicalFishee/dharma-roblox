--!strict
-- Survival-run rules: party-wipe detection + checkpoint/restart math.

local process = require("@lune/process")
local Survival = require("../src/shared/Survival")

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

print("Survival")

-- isPartyWipe: everyone present must be down.
check("no players is never a wipe", Survival.isPartyWipe(0, 0) == false)
check("solo standing is not a wipe", Survival.isPartyWipe(1, 0) == false)
check("solo down is a wipe", Survival.isPartyWipe(1, 1) == true)
check("one of three standing is not a wipe", Survival.isPartyWipe(3, 2) == false)
check("all three down is a wipe", Survival.isPartyWipe(3, 3) == true)
check("downed exceeding total still wipes", Survival.isPartyWipe(2, 3) == true)

-- checkpointFor: boss waves bank a checkpoint; ordinary waves don't; never regresses.
check("clearing a boss wave banks it", Survival.checkpointFor(5, 0, 5) == 5)
check("clearing an ordinary wave keeps the old checkpoint", Survival.checkpointFor(7, 5, 5) == 5)
check("a shallower boss clear never lowers the checkpoint", Survival.checkpointFor(5, 10, 5) == 10)
check("a deeper boss clear raises the checkpoint", Survival.checkpointFor(10, 5, 5) == 10)
check("wave 0 banks nothing", Survival.checkpointFor(0, 0, 5) == 0)

-- restartWave: resume just past your deepest cleared boss.
check("no boss cleared -> restart at wave 1", Survival.restartWave(0, 5) == 1)
check("boss 5 cleared -> restart at wave 6", Survival.restartWave(5, 5) == 6)
check("boss 20 cleared -> restart at wave 21", Survival.restartWave(20, 5) == 21)
check("a sub-interval checkpoint falls back to wave 1", Survival.restartWave(3, 5) == 1)
check("zero interval degrades safely to wave 1", Survival.restartWave(20, 0) == 1)

-- End-to-end: clear waves 5 and 10, wipe at 13 -> banked 10 -> reform at 11.
local cp = 0
cp = Survival.checkpointFor(5, cp, 5)
cp = Survival.checkpointFor(6, cp, 5)
cp = Survival.checkpointFor(10, cp, 5)
check("run that beat boss 10 reforms at wave 11", Survival.restartWave(cp, 5) == 11)

check("restart delay is a positive number", type(Survival.RestartDelay) == "number" and Survival.RestartDelay > 0)

print(string.format("\n%d passed, %d failed", passed, failed))
if failed > 0 then
	print("FAILURES: " .. table.concat(failures, ", "))
	process.exit(1)
end
