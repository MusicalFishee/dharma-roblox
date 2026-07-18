--!strict
-- Headless tests for the Yatra: the free pilgrimage road.

local process = require("@lune/process")
local Yatra = require("../src/shared/Yatra")

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

print("Yatra")

-- The road is well-laid: strictly ascending, ends at the cap.
local ascending = true
for i = 2, #Yatra.Milestones do
	if Yatra.Milestones[i].level <= Yatra.Milestones[i - 1].level then
		ascending = false
	end
end
check("the road climbs, never dips", ascending)
check("the road ends at the summit", Yatra.Milestones[#Yatra.Milestones].level == 100)
check("every step is named and pays", (function()
	for _, step in Yatra.Milestones do
		if #step.name == 0 or step.gold <= 0 then
			return false
		end
	end
	return true
end)())

-- Owed math: sequential, level-gated, recomputed from truth.
local fresh = Yatra.owedFor(1, 0)
check("level one is owed nothing", fresh.count == 0 and fresh.gold == 0)
local early = Yatra.owedFor(5, 0)
check("level five is owed the first two steps", early.count == 2 and early.gold == 300 and early.shards == 1)
check("claims consume the road in order", Yatra.owedFor(5, 2).count == 0)
check("a deep level owes the whole walked road", Yatra.owedFor(100, 0).count == #Yatra.Milestones)
check("junk claims are clamped", Yatra.owedFor(100, 999).count == 0 and Yatra.owedFor(5, -5).count == 2)

-- The next step points forward.
local nxt = Yatra.nextFor(5, 2)
check("the next step waits uphill", nxt ~= nil and (nxt :: Yatra.Milestone).level == 8)
check("a finished road has no next step", Yatra.nextFor(100, #Yatra.Milestones) == nil)

print(string.format("\n%d passed, %d failed", passed, failed))
if failed > 0 then
	print("FAILURES: " .. table.concat(failures, ", "))
	process.exit(1)
end
