--!strict
-- Headless tests for Varna ranks: the ladder, the boundaries, the boons,
-- and the capstone's agreement with the level cap itself.

local process = require("@lune/process")
local Ranks = require("../src/shared/Ranks")
local Progression = require("../src/shared/Progression")

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

print("Ranks")

-- The ladder.
check("seven ranks climb the ladder", #Ranks.List == 7)
check("the ladder starts at level 1", Ranks.List[1].level == 1)
local prev = 0
local ladderOk = true
local names: { [string]: boolean } = {}
for _, def in Ranks.List do
	if def.level <= prev or #def.name == 0 or #def.line == 0 or names[def.name] then
		ladderOk = false
	end
	prev = def.level
	names[def.name] = true
end
check("bands ascend with distinct names", ladderOk)
check("the capstone sits exactly at the level cap", Ranks.List[#Ranks.List].level == Progression.MaxLevel)
check("chakravartin crowns the ladder", Ranks.List[#Ranks.List].name == "Chakravartin")

-- Boundaries.
local i1 = Ranks.rankFor(1)
check("level 1 is a shishya", i1 == 1)
check("level 9 is still a shishya", (Ranks.rankFor(9)) == 1)
check("level 10 becomes a sainika", (Ranks.rankFor(10)) == 2)
check("level 99 holds mahasena", (Ranks.rankFor(99)) == 6)
check("level 100 turns the wheel", (Ranks.rankFor(100)) == 7)
check("beyond the cap stays sovereign", (Ranks.rankFor(999)) == 7)
check("junk levels clamp to the student", (Ranks.rankFor(-5)) == 1)

-- Boons: additive forever, never punishing.
local none = Ranks.boonFor(1)
check("the student earns no boon yet", none.healthBonus == 0 and none.goldMult == 1)
local mid = Ranks.boonFor(4)
check("boons scale by rank held", mid.healthBonus == 3 * Ranks.HealthPerRank and math.abs(mid.goldMult - 1.06) < 1e-9)
local top = Ranks.boonFor(7)
check("the sovereign's boon is the greatest", top.healthBonus > mid.healthBonus and top.goldMult > mid.goldMult)
check("gold find stays honest", top.goldMult <= 1.15)

-- The chase.
check("nextRank names what's ahead", (Ranks.nextRank(35) :: Ranks.RankDef).name == "Kshatriya")
check("nothing lies past the wheel", Ranks.nextRank(100) == nil)
check("the cap itself is reachable", Progression.resolve(Progression.totalXpForLevel(Progression.MaxLevel)).level == Progression.MaxLevel)

print(string.format("\n%d passed, %d failed", passed, failed))
if failed > 0 then
	print("FAILURES: " .. table.concat(failures, ", "))
	process.exit(1)
end
