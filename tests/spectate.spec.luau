--!strict
-- Headless tests for bhoota spectate: eligibility and the cycle.

local process = require("@lune/process")
local Spectate = require("../src/shared/Spectate")

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

print("Spectate")

check("fighters are a show", Spectate.isWatchable(true, false, false, false))
check("the dead are not", not Spectate.isWatchable(false, false, false, false))
check("spirits do not watch spirits", not Spectate.isWatchable(true, true, false, false))
check("the downed are not a show", not Spectate.isWatchable(true, false, true, false))
check("the meditating are left in peace", not Spectate.isWatchable(true, false, false, true))

check("an empty arena has no index", Spectate.cycle(0, 1, 1) == 0)
check("forward wraps", Spectate.cycle(3, 3, 1) == 1)
check("backward wraps", Spectate.cycle(3, 1, -1) == 3)
check("a lone fighter cycles to themselves", Spectate.cycle(1, 1, 1) == 1)
check("clamp holds a stale index", Spectate.clampIndex(2, 5) == 2 and Spectate.clampIndex(0, 3) == 0)

print(string.format("\n%d passed, %d failed", passed, failed))
if failed > 0 then
	print("FAILURES: " .. table.concat(failures, ", "))
	process.exit(1)
end
