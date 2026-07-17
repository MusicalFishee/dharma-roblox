--!strict
-- Headless tests for wave grades: scoring, thresholds, and the XP multipliers.

local process = require("@lune/process")
local Grade = require("../src/shared/Grade")

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

local function tally(kills: number, parries: number, timesHit: number, downs: number): Grade.Tally
	return { kills = kills, parries = parries, timesHit = timesHit, downs = downs }
end

print("Grade")

-- Scoring.
check("kills raise the mark", Grade.score(tally(3, 0, 0, 0)) == 3 * Grade.KillPoints)
check("parries raise it more per act", Grade.ParryPoints > Grade.KillPoints)
check("eaten blows stain it", Grade.score(tally(2, 0, 2, 0)) < Grade.score(tally(2, 0, 0, 0)))
check("a fall stains it hard", Grade.DownPenalty > Grade.HitPenalty * 4)
check("the mark never goes below zero", Grade.score(tally(0, 0, 10, 3)) == 0)

-- Judgement against the wave's size.
check("killing your whole share cleanly is S", Grade.gradeFor(Grade.score(tally(8, 2, 0, 0)), 8) == "S")
check("a decent showing is A", Grade.gradeFor(Grade.score(tally(7, 1, 3, 0)), 8) == "A")
check("half-measures earn B", Grade.gradeFor(Grade.score(tally(5, 1, 2, 0)), 8) == "B")
check("bystanding earns C", Grade.gradeFor(Grade.score(tally(1, 0, 5, 1)), 8) == "C")
check("an empty wave judges C", Grade.gradeFor(100, 0) == "C")

-- Every grade pays; S pays half again.
check("S pays half again", Grade.xpMult("S") == 1.5)
check("grades never punish the bounty", Grade.xpMult("C") == 1.0 and Grade.xpMult("B") > 1.0)
check("multipliers descend with the mark", Grade.xpMult("S") > Grade.xpMult("A") and Grade.xpMult("A") > Grade.xpMult("B"))
check("unknown grades pay plain", Grade.xpMult("Z") == 1.0)

-- Colors for the HUD.
local colorsOk = true
for _, g in { "S", "A", "B", "C" } do
	local c = Grade.Color[g]
	if not c or #c ~= 3 then
		colorsOk = false
	end
end
check("every grade has a color", colorsOk)


-- Support play is honored: a parry-heavy guardian can still mark well.
local guardian = Grade.score(tally(2, 4, 1, 0))
check("a shield-brother can reach A", Grade.gradeFor(guardian, 8) == "A")
check("a parry-master earns the S outright", Grade.gradeFor(Grade.score(tally(2, 6, 1, 0)), 8) == "S")
check("more kills never lower the mark", Grade.score(tally(6, 0, 0, 0)) > Grade.score(tally(5, 0, 0, 0)))
check("the S boundary is exact", Grade.gradeFor(math.ceil(8 * Grade.KillPoints * 1.15), 8) == "S")
check("C is the floor, never worse", Grade.gradeFor(0, 8) == "C")

local tableAgrees = true
for _, g in { "S", "A", "B", "C" } do
	if Grade.xpMult(g) ~= Grade.XpMult[g] then
		tableAgrees = false
	end
end
check("the multiplier table and the function agree", tableAgrees)

print(string.format("\n%d passed, %d failed", passed, failed))
if failed > 0 then
	print("FAILURES: " .. table.concat(failures, ", "))
	process.exit(1)
end
