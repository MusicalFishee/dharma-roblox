--!strict
-- Headless tests for the Adhyayas: chapter integrity, trigger kinds, ordered
-- cascade math — and the narrative law: Ravana falls in the second-to-last
-- chapter, but the FINALE belongs to the Trial. The last word is Mahadeva's.

local process = require("@lune/process")
local Story = require("../src/shared/Story")

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

local function snap(bestWave: number, bossKills: number, trials: number, raids: number): Story.Snapshot
	return { bestWave = bestWave, bossKills = bossKills, trialsPassed = trials, raidClears = raids }
end

print("Story")

-- Shape.
check("seven adhyayas", Story.chapterCount() == 7 and #Story.Chapters == 7)

local kinds = { wave = true, bossKills = true, trials = true, raids = true }
local chaptersValid = true
local idsSeen: { [string]: boolean } = {}
local numeralsSeen: { [string]: boolean } = {}
for _, ch in Story.Chapters do
	if idsSeen[ch.id] or numeralsSeen[ch.numeral] then
		chaptersValid = false
	end
	idsSeen[ch.id] = true
	numeralsSeen[ch.numeral] = true
	if #ch.title == 0 or #ch.requirement == 0 or #ch.closeLine == 0 or #ch.beginLines == 0 then
		chaptersValid = false
	end
	for _, line in ch.beginLines do
		if #line == 0 then
			chaptersValid = false
		end
	end
	if not kinds[ch.trigger.kind] or ch.trigger.value <= 0 then
		chaptersValid = false
	end
	if ch.reward.gold <= 0 or ch.reward.xp <= 0 then
		chaptersValid = false
	end
end
check("every chapter is well-formed and unique", chaptersValid)

local rewardsGrow = true
for i = 2, #Story.Chapters do
	if Story.Chapters[i].reward.xp <= Story.Chapters[i - 1].reward.xp then
		rewardsGrow = false
	end
end
check("rewards deepen chapter by chapter", rewardsGrow)

-- THE NARRATIVE LAW: Ravana is the penultimate beat; the finale is the Trial.
local finale = Story.Chapters[#Story.Chapters]
local penultimate = Story.Chapters[#Story.Chapters - 1]
check("the finale belongs to Mahadeva", finale.trigger.kind == "trials")
check("Ravana falls second-to-last", penultimate.trigger.kind == "raids")
check("the narrator is Agastya", Story.Narrator == "Rishi Agastya")

-- Trigger satisfaction per kind.
check("wave trigger reads bestWave", Story.isSatisfied(Story.Chapters[1], snap(5, 0, 0, 0)) and not Story.isSatisfied(Story.Chapters[1], snap(4, 0, 0, 0)))
check("bossKills trigger reads the ledger", Story.isSatisfied(Story.Chapters[2], snap(0, 1, 0, 0)) and not Story.isSatisfied(Story.Chapters[2], snap(99, 0, 0, 0)))
check("trials trigger reads trialsPassed", Story.isSatisfied(Story.Chapters[4], snap(0, 0, 1, 0)))
check("raids trigger reads raidClears", Story.isSatisfied(Story.Chapters[6], snap(0, 0, 0, 1)))

-- The cascade: chapters complete in order, never skipping an unmet gate.
check("a fresh record has no chapters", Story.advance(0, snap(0, 0, 0, 0)) == 0)
check("clearing wave 5 completes only chapter I", Story.advance(0, snap(5, 0, 0, 0)) == 1)
check("a boss kill without wave 5 completes nothing", Story.advance(0, snap(4, 3, 0, 0)) == 0)
check("wave 5 + a boss cascades through II", Story.advance(0, snap(5, 1, 0, 0)) == 2)
check("a veteran record cascades to the gate it misses", Story.advance(0, snap(40, 20, 1, 0)) == 5)
check("the full legend completes all seven", Story.advance(0, snap(75, 30, 2, 1)) == 7)
check("done never regresses or overflows", Story.advance(7, snap(0, 0, 0, 0)) == 7 and Story.advance(99, snap(0, 0, 0, 0)) == 7 and Story.advance(-3, snap(0, 0, 0, 0)) == 0)
check("one trial alone cannot reach the finale (Ravana bars the road)", Story.advance(0, snap(75, 30, 5, 0)) == 5)

print(string.format("\n%d passed, %d failed", passed, failed))
if failed > 0 then
	print("FAILURES: " .. table.concat(failures, ", "))
	process.exit(1)
end
