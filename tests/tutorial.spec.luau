--!strict
-- Headless tests for Adhyaya 0: step order, advance math, and the lesson's end.

local process = require("@lune/process")
local Tutorial = require("../src/shared/Tutorial")

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

print("Tutorial")

-- The lesson plan.
check("the lesson has five steps", #Tutorial.Steps == 5)
local events = { kill = true, parry = true, ability = true, gold = true, waveClear = true }
local stepsOk = true
local ids: { [string]: boolean } = {}
for _, s in Tutorial.Steps do
	if ids[s.id] or not events[s.event] or s.count <= 0 or #s.text == 0 then
		stepsOk = false
	end
	ids[s.id] = true
end
check("steps are well-formed with real events", stepsOk)
check("the lesson opens with blood, ends with the line", Tutorial.Steps[1].event == "kill" and Tutorial.Steps[#Tutorial.Steps].event == "waveClear")
check("agastya speaks at both ends", #Tutorial.Lines.intro > 0 and #Tutorial.Lines.outro > 0)
check("the lesson pays", Tutorial.Reward.gold > 0)

-- Advance math.
local a = Tutorial.advance(1, 0, "kill")
check("a matching event counts", a.stepIndex == 1 and a.progress == 1 and not a.completedStep)

local wrong = Tutorial.advance(1, 2, "parry")
check("the lesson is ordered — early parries don't skip ahead", wrong.stepIndex == 1 and wrong.progress == 2)

local finish = Tutorial.advance(1, 2, "kill")
check("the third kill turns the page", finish.stepIndex == 2 and finish.progress == 0 and finish.completedStep and not finish.done)

local lastStep = #Tutorial.Steps
local graduate = Tutorial.advance(lastStep, 0, "waveClear")
check("the last step ends the lesson", graduate.done and graduate.completedStep)

local past = Tutorial.advance(lastStep + 1, 0, "kill")
check("a finished lesson stays finished", past.done and not past.completedStep)

check("stepAt finds and misses", Tutorial.stepAt(1) ~= nil and Tutorial.stepAt(99) == nil)


-- A full playthrough: feed exactly the right events, graduate exactly once.
local stepIndex, progress = 1, 0
local graduations = 0
for _, s in Tutorial.Steps do
	for _ = 1, s.count do
		local adv = Tutorial.advance(stepIndex, progress, s.event)
		stepIndex, progress = adv.stepIndex, adv.progress
		if adv.done then
			graduations += 1
		end
	end
end
check("the exact lesson graduates exactly once", graduations == 1 and stepIndex == #Tutorial.Steps + 1)
check("wrong events never regress progress", Tutorial.advance(2, 1, "gold").progress == 1)
check("the lesson is short enough to finish in two waves", (function()
	local total = 0
	for _, s in Tutorial.Steps do
		total += s.count
	end
	return total <= 10
end)())

local Paths = require("../src/shared/Paths")
check("the lesson's blessing never trivializes the economy", Tutorial.Reward.gold < Paths.RespecCost)
check("agastya's intro and outro are different words", Tutorial.Lines.intro ~= Tutorial.Lines.outro)

print(string.format("\n%d passed, %d failed", passed, failed))
if failed > 0 then
	print("FAILURES: " .. table.concat(failures, ", "))
	process.exit(1)
end
