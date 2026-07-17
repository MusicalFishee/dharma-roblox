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


-- Walking a real streak announces each rank exactly once.
local announces = 0
local count, lastAt = 0, 0
for i = 1, 40 do
	local now = i * 2 -- always inside the window
	local reg = Vira.register(count, lastAt, now)
	count, lastAt = reg.count, now
	if Vira.rankAt(count) then
		announces += 1
	end
end
check("a 40-kill chain announces every rank once", announces == #Vira.Ranks)
local nameSeen: { [string]: boolean } = {}
local namesUnique = true
for _, rank in Vira.Ranks do
	if nameSeen[rank.name] then
		namesUnique = false
	end
	nameSeen[rank.name] = true
end
check("rank names are distinct", namesUnique)
check("the very first kill is never 'cooled'", not Vira.register(0, -999, 0).cooled)
check("cooling truly resets the ladder", Vira.rankAt(Vira.register(35, 0, 100).count) == nil)

check("a chained kill always climbs by exactly one", Vira.register(7, 100, 101).count == 8)

print(string.format("\n%d passed, %d failed", passed, failed))
if failed > 0 then
	print("FAILURES: " .. table.concat(failures, ", "))
	process.exit(1)
end
