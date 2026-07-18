--!strict
-- Headless tests for duel tournaments: the four-bracket kumbha.

local process = require("@lune/process")
local Tournament = require("../src/shared/Tournament")

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

print("Tournament")

check("four names make a kumbha", Tournament.Size == 4)
check("three names do not", Tournament.seed({ 1, 2, 3 }) == nil)

local b = Tournament.seed({ 11, 22, 33, 44 }) :: Tournament.Bracket
check("queue order seeds the semis", b.semis[1][1] == 11 and b.semis[1][2] == 22 and b.semis[2][1] == 33 and b.semis[2][2] == 44)

check("a semifinal winner advances", Tournament.reportSemiWin(b, 22) and b.finalists[1] == 22)
check("advancing twice is refused", not Tournament.reportSemiWin(b, 22))
check("a stranger cannot advance", not Tournament.reportSemiWin(b, 99))
check("the final waits for both", not Tournament.isFinalReady(b))
Tournament.reportSemiWin(b, 33)
check("two finalists ready the final", Tournament.isFinalReady(b))
check("only a finalist takes the crown", not Tournament.reportFinalWin(b, 11))
check("the champion is crowned once", Tournament.reportFinalWin(b, 33) and b.champion == 33 and not Tournament.reportFinalWin(b, 22))

-- Walkovers.
local w = Tournament.seed({ 1, 2, 3, 4 }) :: Tournament.Bracket
check("a vanished semifinalist forfeits", Tournament.walkover(w, 1) == 2 and w.finalists[1] == 2)
Tournament.reportSemiWin(w, 3)
check("a vanished finalist crowns the other", Tournament.walkover(w, 2) == 3 and w.champion == 3)
local q = Tournament.seed({ 5, 6, 7, 8 }) :: Tournament.Bracket
Tournament.reportSemiWin(q, 5)
check("a resolved semi ignores the fallen loser", Tournament.walkover(q, 6) == 0)

print(string.format("\n%d passed, %d failed", passed, failed))
if failed > 0 then
	print("FAILURES: " .. table.concat(failures, ", "))
	process.exit(1)
end
