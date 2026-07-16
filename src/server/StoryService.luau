--!strict
-- The Adhyayas, server-side: Agastya's voice. Chapter math lives in the pure
-- Story module; this speaks the lines (personally — narration is FireClient,
-- not broadcast: every player walks the arc at their own pace), pays the
-- chapter rewards, and persists progress. Triggers ride stats the services
-- already record, so a single onEvent(player) after any milestone suffices.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local Net = require(ReplicatedStorage.Shared.Net)
local Story = require(ReplicatedStorage.Shared.Story)
local Loot = require(ReplicatedStorage.Shared.Loot)
local PlayerRegistry = require(script.Parent.PlayerRegistry)
local ProgressionService = require(script.Parent.ProgressionService)

local StoryService = {}

local narrating: { [Player]: boolean } = {} -- one ceremony chain at a time

Players.PlayerRemoving:Connect(function(player)
	narrating[player] = nil
end)

local function snapshotOf(state: any): Story.Snapshot
	return {
		bestWave = state.bestWave,
		bossKills = state.stats.bossKills,
		trialsPassed = state.stats.trialsPassed,
		raidClears = state.stats.raidClears,
	}
end

local function speakTo(player: Player, text: string)
	Net.CombatFeedback:FireClient(player, { bossLine = true, speaker = Story.Narrator, text = text })
end

-- The active chapter's opening beats, spoken one line at a time.
local function narrateBegin(player: Player, chapterIndex: number)
	local def = Story.chapterAt(chapterIndex)
	if not def then
		return
	end
	for _, line in def.beginLines do
		if not player.Parent then
			return
		end
		speakTo(player, line)
		task.wait(4.5)
	end
end

-- A chapter completes: the closing word, the toast, the pay.
local function ceremony(player: Player, def: Story.ChapterDef)
	local state = PlayerRegistry.get(player)
	speakTo(player, def.closeLine)
	state.gold = Loot.clampGold(state.gold + def.reward.gold)
	Net.CombatFeedback:FireClient(player, { goldUpdate = true, gained = 0, gold = state.gold })
	Net.CombatFeedback:FireClient(player, {
		storyChapter = true,
		numeral = def.numeral,
		title = def.title,
		gold = def.reward.gold,
		xp = def.reward.xp,
		chapter = state.storyChapter,
	})
	ProgressionService.awardXp(player, def.reward.xp)
end

-- Call after anything that can move the story (wave clear, boss fall, trial,
-- raid). Cascades every newly-satisfied chapter with full ceremony.
function StoryService.onEvent(player: Player)
	local state = PlayerRegistry.tryGet(player)
	if not state or not state.dataLoaded or narrating[player] then
		return
	end
	local before = state.storyChapter
	local after = Story.advance(before, snapshotOf(state))
	if after == before then
		return
	end
	state.storyChapter = after
	narrating[player] = true
	task.spawn(function()
		for i = before + 1, after do
			local def = Story.chapterAt(i)
			if def and player.Parent then
				ceremony(player, def)
				task.wait(3.0)
			end
		end
		if player.Parent then
			task.wait(2.0)
			narrateBegin(player, after + 1)
		end
		narrating[player] = nil
	end)
end

-- On data load: quiet catch-up (a veteran's record may already satisfy chapters
-- written after their deeds), then this session's opening narration.
function StoryService.ensure(player: Player)
	local state = PlayerRegistry.tryGet(player)
	if not state then
		return
	end
	local before = state.storyChapter
	local after = Story.advance(before, snapshotOf(state))
	if after > before then
		state.storyChapter = after
		-- Pay everything owed in one quiet sweep — no line-by-line replay.
		local gold, xp = 0, 0
		for i = before + 1, after do
			local def = Story.chapterAt(i)
			if def then
				gold += def.reward.gold
				xp += def.reward.xp
			end
		end
		local last = Story.chapterAt(after)
		state.gold = Loot.clampGold(state.gold + gold)
		Net.CombatFeedback:FireClient(player, { goldUpdate = true, gained = 0, gold = state.gold })
		Net.CombatFeedback:FireClient(player, {
			storyCatchup = true,
			numeral = if last then last.numeral else "",
			gold = gold,
			xp = xp,
			chapter = after,
		})
		ProgressionService.awardXp(player, xp)
	end
	-- Agastya re-grounds the tale each session, softly, once the world settles.
	task.delay(9, function()
		if player.Parent and not narrating[player] then
			narrateBegin(player, state.storyChapter + 1)
		end
	end)
end

Net.StoryRequest.OnServerEvent:Connect(function(player: Player, data: any)
	if typeof(data) ~= "table" or data.action ~= "info" then
		return
	end
	local state = PlayerRegistry.get(player)
	Net.CombatFeedback:FireClient(player, { storyInfo = true, chapter = state.storyChapter })
end)

print("[Dharma] StoryService ready — Agastya clears his throat.")

return StoryService
