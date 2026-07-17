--!strict
-- Adhyaya 0, live: runs the First Lesson for anyone whose save says they
-- haven't finished it. QuestService feeds the same events it already tracks
-- (kills, parries, abilities, gold, wave clears); each page turn updates the
-- checklist, and the last one pays Agastya's blessing and closes the lesson
-- forever (persisted via PlayerData.tutorialDone).

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local Net = require(ReplicatedStorage.Shared.Net)
local Tutorial = require(ReplicatedStorage.Shared.Tutorial)
local Loot = require(ReplicatedStorage.Shared.Loot)
local PlayerRegistry = require(script.Parent.PlayerRegistry)

local TutorialService = {}

type Lesson = {
	step: number,
	progress: number,
}

local lessons: { [Player]: Lesson } = {}

local function sendStep(player: Player, lesson: Lesson)
	local step = Tutorial.stepAt(lesson.step)
	if not step then
		return
	end
	Net.CombatFeedback:FireClient(player, {
		tutorial = true,
		text = step.text,
		progress = lesson.progress,
		count = step.count,
		step = lesson.step,
		total = #Tutorial.Steps,
	})
end

-- Called by DataService once the save has resolved.
function TutorialService.ensure(player: Player)
	local state = PlayerRegistry.get(player)
	if state.tutorialDone or lessons[player] then
		return
	end
	lessons[player] = { step = 1, progress = 0 }
	task.delay(2.0, function()
		local lesson = lessons[player]
		if lesson and player.Parent then
			Net.CombatFeedback:FireClient(player, { bossLine = true, speaker = "Agastya", text = Tutorial.Lines.intro })
			sendStep(player, lesson)
		end
	end)
end

-- QuestService relays every tracked event here (one integration point).
function TutorialService.onEvent(player: Player, eventKind: string)
	local lesson = lessons[player]
	if not lesson then
		return
	end

	local advance = Tutorial.advance(lesson.step, lesson.progress, eventKind)
	lesson.step = advance.stepIndex
	lesson.progress = advance.progress

	if advance.done then
		lessons[player] = nil
		local state = PlayerRegistry.get(player)
		state.tutorialDone = true
		state.gold = Loot.clampGold(state.gold + Tutorial.Reward.gold)
		Net.CombatFeedback:FireClient(player, { goldUpdate = true, gained = Tutorial.Reward.gold, gold = state.gold })
		Net.CombatFeedback:FireClient(player, { bossLine = true, speaker = "Agastya", text = Tutorial.Lines.outro })
		Net.CombatFeedback:FireClient(player, { tutorialDone = true, gold = Tutorial.Reward.gold })
		return
	end

	if advance.completedStep then
		sendStep(player, lesson) -- the next page
	elseif eventKind == (Tutorial.stepAt(lesson.step) :: Tutorial.Step).event then
		sendStep(player, lesson) -- progress within the page
	end
end

Players.PlayerRemoving:Connect(function(player)
	lessons[player] = nil
end)

print("[Dharma] TutorialService ready — Agastya waits for the unlearned.")

return TutorialService
