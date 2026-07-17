--!strict
-- Headless tests for Vīra streaks: the window, the ladder, the announcements.

local process = require("@lune/process")
local Vira = require("../src/shared/Vira")

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

print("Vira")

-- The ladder.
check("window is a real pause", Vira.Window > 0)
local prev = 0
local ladderOk = true
for _, rank in Vira.Ranks do
	if rank.count <= prev or #rank.name == 0 or rank.tejas <= 0 then
		ladderOk = false
	end
	prev = rank.count
end
check("ranks ascend with names and surges", ladderOk)
check("surges grow with rank", Vira.Ranks[#Vira.Ranks].tejas > Vira.Ranks[1].tejas)

-- Streak math.
local first = Vira.register(0, 0, 100)
check("first blood starts at 1", first.count == 1 and not first.cooled)

local chained = Vira.register(4, 100, 100 + Vira.Window - 0.5)
check("a quick kill chains", chained.count == 5 and not chained.cooled)

local edge = Vira.register(4, 100, 100 + Vira.Window)
check("the window's edge still chains", edge.count == 5)

local cooled = Vira.register(12, 100, 100 + Vira.Window + 0.1)
check("a slow kill cools to 1", cooled.count == 1 and cooled.cooled)

-- Announcements fire once, exactly at the rung.
check("rank sounds at 5", (Vira.rankAt(5) :: Vira.Rank).name == "VĪRA")
check("no rank between rungs", Vira.rankAt(6) == nil and Vira.rankAt(19) == nil)
check("the summit rank exists", Vira.rankAt(35) ~= nil)
check("no rank at zero", Vira.rankAt(0) == nil)

print(string.format("\n%d passed, %d failed", passed, failed))
if failed > 0 then
	print("FAILURES: " .. table.concat(failures, ", "))
	process.exit(1)
end
