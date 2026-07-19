--!strict
-- Headless tests for the Ripu-Grantha: the coverage law (no bloodline ships
-- unwritten), page-turn math, and the ledger's owed bounties.

local process = require("@lune/process")
local Grantha = require("../src/shared/Grantha")
local EnemyTypes = require("../src/shared/EnemyTypes")
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

print("Grantha")

-- THE COVERAGE LAW: every roster archetype belongs to a family. A new
-- bloodline that ships without a page fails the suite.
local covered = true
for id in EnemyTypes.List do
	if not Grantha.familyOf(id) then
		covered = false
		print("    !! unwritten foe: " .. id)
	end
end
check("no bloodline ships unwritten", covered)

-- And every member the book names must be REAL: a roster grunt, a boss lord
-- (harvested through the public door), or the torn illusion himself.
local knownIds: { [string]: boolean } = { MarichaRevealed = true }
for id in EnemyTypes.List do
	knownIds[id] = true
end
for k = 1, 14 do
	knownIds[Bosses.forWave(k * 5, 5).id] = true
end
local membersReal = true
local seenMember: { [string]: boolean } = {}
for _, def in Grantha.Families do
	for _, member in def.members do
		if not knownIds[member] then
			membersReal = false
			print("    !! phantom member: " .. member)
		end
		if seenMember[member] then
			membersReal = false
			print("    !! member on two pages: " .. member)
		end
		seenMember[member] = true
	end
end
check("every named foe is real, on exactly one page", membersReal)

-- Well-formed pages: three ascending tiers, three field notes each.
local pagesOk = true
for _, def in Grantha.Families do
	if #def.tiers ~= 3 or #def.lore ~= 3 or #def.name == 0 then
		pagesOk = false
	end
	if not (def.tiers[1] < def.tiers[2] and def.tiers[2] < def.tiers[3]) then
		pagesOk = false
	end
	for _, note in def.lore do
		if #note == 0 then
			pagesOk = false
		end
	end
end
check("every page has three ascending tiers and three notes", pagesOk)
check("the bounties deepen per tier", Grantha.TierReward[1] < Grantha.TierReward[2] and Grantha.TierReward[2] < Grantha.TierReward[3])

-- Page-turn math.
local naga = Grantha.get("naga") :: Grantha.FamilyDef
check("an unbloodied page is unturned", Grantha.tierFor(naga, 0) == 0)
check("the first threshold turns the first page", Grantha.tierFor(naga, naga.tiers[1]) == 1 and Grantha.tierFor(naga, naga.tiers[1] - 1) == 0)
check("a legend turns all three", Grantha.tierFor(naga, naga.tiers[3]) == 3)

-- Owed math: sequential, junk-proof.
local owedFresh = Grantha.owedFor(naga, naga.tiers[2], 0)
check("two turned pages owe two bounties", owedFresh.tiers == 2 and owedFresh.gold == Grantha.TierReward[1] + Grantha.TierReward[2])
check("claimed pages owe nothing again", Grantha.owedFor(naga, naga.tiers[2], 2).tiers == 0)
check("junk claims are clamped", Grantha.owedFor(naga, naga.tiers[3], 99).tiers == 0 and Grantha.owedFor(naga, naga.tiers[1], -5).tiers == 1)

-- The lords' page exists and demands less blood (there are fewer lords).
local lords = Grantha.get("lords") :: Grantha.FamilyDef
check("the lords keep a shorter ledger", lords.tiers[1] < naga.tiers[1])
check("unknown families stay unknown", Grantha.get("devas") == nil and Grantha.familyOf("Shiva") == nil)

print(string.format("\n%d passed, %d failed", passed, failed))
if failed > 0 then
	print("FAILURES: " .. table.concat(failures, ", "))
	process.exit(1)
end
