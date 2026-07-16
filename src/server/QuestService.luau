--!strict
-- Quest engine: keeps 3 active quests per player, advances them on game events,
-- pays out on completion, and draws a fresh quest to fill the slot.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local Net = require(ReplicatedStorage.Shared.Net)
local Quests = require(ReplicatedStorage.Shared.Quests)
local Dailies = require(ReplicatedStorage.Shared.Dailies)
local Loot = require(ReplicatedStorage.Shared.Loot)
local PlayerRegistry = require(script.Parent.PlayerRegistry)
local ProgressionService = require(script.Parent.ProgressionService)

local QuestService = {}

local function activeIds(state: PlayerRegistry.PlayerState): { string }
	local ids: { string } = {}
	for _, slot in state.quests do
		table.insert(ids, slot.id)
	end
	return ids
end

-- Push the quest panel state to the client (regular quests + today's trials).
function QuestService.sync(player: Player)
	local state = PlayerRegistry.get(player)
	local view = {}
	for _, slot in state.quests do
		local def = Quests.Catalog[slot.id]
		if def then
			table.insert(view, {
				id = def.id,
				title = def.title,
				desc = def.desc,
				progress = slot.progress,
				goal = def.goal,
				rewardGold = def.rewardGold,
				rewardXp = def.rewardXp,
			})
		end
	end
	local dview = {}
	for _, slot in state.dailies.slots do
		local def = Dailies.get(slot.id)
		if def then
			table.insert(dview, {
				id = def.id,
				title = def.title,
				desc = def.desc,
				progress = slot.progress,
				goal = def.goal,
				done = slot.done,
				rewardGold = def.rewardGold,
				rewardXp = def.rewardXp,
				rewardShards = def.rewardShards,
			})
		end
	end
	Net.CombatFeedback:FireClient(player, { questUpdate = true, quests = view, dailies = dview })
end

-- Drop unknown ids (old saves), clamp progress, fill empty slots.
function QuestService.ensureFilled(player: Player)
	local state = PlayerRegistry.get(player)

	local cleaned: { { id: string, progress: number } } = {}
	for _, slot in state.quests do
		local def = Quests.Catalog[slot.id]
		if def and #cleaned < Quests.ActiveCount then
			table.insert(cleaned, { id = slot.id, progress = Quests.clampProgress(def, slot.progress) })
		end
	end
	state.quests = cleaned

	while #state.quests < Quests.ActiveCount do
		local id = Quests.draw(activeIds(state))
		if not id then
			break
		end
		table.insert(state.quests, { id = id, progress = 0 })
	end

	QuestService.sync(player)
end

-- Stand up today's trials: a stale (or junk) day stamp rerolls the whole set from
-- the shared per-day pick; a current stamp just drops unknown ids and clamps.
function QuestService.ensureDailies(player: Player, announceReset: boolean?)
	local state = PlayerRegistry.get(player)
	local today = Dailies.dayStamp(os.time())

	if state.dailies.stamp ~= today then
		local slots = {}
		for _, id in Dailies.forDay(today) do
			table.insert(slots, { id = id, progress = 0, done = false })
		end
		state.dailies = { stamp = today, slots = slots }
		if announceReset then
			Net.CombatFeedback:FireClient(player, { dailyReset = true })
		end
	else
		local cleaned = {}
		for _, slot in state.dailies.slots do
			local def = Dailies.get(slot.id)
			if def and #cleaned < Dailies.ActiveCount then
				table.insert(cleaned, {
					id = slot.id,
					progress = Dailies.clampProgress(def, slot.progress),
					done = slot.done == true,
				})
			end
		end
		state.dailies.slots = cleaned
	end

	QuestService.sync(player)
end

local function complete(player: Player, state: PlayerRegistry.PlayerState, slotIndex: number, def: Quests.QuestDef)
	-- Payout.
	if def.rewardGold > 0 then
		state.gold = Loot.clampGold(state.gold + def.rewardGold)
		Net.CombatFeedback:FireClient(player, { goldUpdate = true, gained = def.rewardGold, gold = state.gold })
	end
	if def.rewardXp > 0 then
		ProgressionService.awardXp(player, def.rewardXp)
	end

	Net.CombatFeedback:FireClient(player, {
		questComplete = true,
		title = def.title,
		rewardGold = def.rewardGold,
		rewardXp = def.rewardXp,
	})

	-- Replace the finished quest with a fresh one (no duplicates).
	table.remove(state.quests, slotIndex)
	local id = Quests.draw(activeIds(state))
	if id then
		table.insert(state.quests, { id = id, progress = 0 })
	end
end

-- A finished daily pays big (gold, XP, and sometimes shards) and stays checked off
-- until midnight — no redraw; scarcity is what makes dailies daily.
local function completeDaily(player: Player, state: PlayerRegistry.PlayerState, def: Dailies.DailyDef)
	if def.rewardGold > 0 then
		state.gold = Loot.clampGold(state.gold + def.rewardGold)
		Net.CombatFeedback:FireClient(player, { goldUpdate = true, gained = def.rewardGold, gold = state.gold })
	end
	if def.rewardXp > 0 then
		ProgressionService.awardXp(player, def.rewardXp)
	end
	if def.rewardShards > 0 then
		state.shards += def.rewardShards
		Net.CombatFeedback:FireClient(player, { shardUpdate = true, gained = def.rewardShards, shards = state.shards })
	end
	Net.CombatFeedback:FireClient(player, {
		dailyComplete = true,
		title = def.title,
		rewardGold = def.rewardGold,
		rewardXp = def.rewardXp,
		rewardShards = def.rewardShards,
	})
end

-- Advance all matching active quests (regular + daily) for one event.
local function handleEvent(player: Player, event: Quests.Event)
	local state = PlayerRegistry.tryGet(player)
	if not state then
		return
	end

	local changed = false
	-- Walk backwards: completion mutates the list.
	for i = #state.quests, 1, -1 do
		local slot = state.quests[i]
		local def = Quests.Catalog[slot.id]
		if not def then
			continue
		end
		local inc = Quests.increment(def, event)
		if inc > 0 then
			slot.progress = Quests.clampProgress(def, slot.progress + inc)
			changed = true
			if Quests.isComplete(def, slot.progress) then
				complete(player, state, i, def)
			end
		end
	end

	-- Today's trials (done ones sleep until midnight).
	for _, slot in state.dailies.slots do
		if slot.done then
			continue
		end
		local def = Dailies.get(slot.id)
		if not def then
			continue
		end
		local inc = Quests.increment(def :: any, event)
		if inc > 0 then
			slot.progress = Dailies.clampProgress(def, slot.progress + inc)
			changed = true
			if Dailies.isComplete(def, slot.progress) then
				slot.done = true
				completeDaily(player, state, def)
			end
		end
	end

	if changed then
		QuestService.sync(player)
	end
end

function QuestService.onKill(player: Player, enemyId: string, isBoss: boolean, isElite: boolean?)
	handleEvent(player, { type = "kill", enemyId = enemyId, isBoss = isBoss, isElite = isElite == true })
end

function QuestService.onWaveClear(player: Player)
	handleEvent(player, { type = "waveClear" })
end

function QuestService.onParry(player: Player)
	handleEvent(player, { type = "parry" })
end

function QuestService.onGold(player: Player, amount: number)
	handleEvent(player, { type = "gold", amount = amount })
end

function QuestService.onAbility(player: Player)
	handleEvent(player, { type = "ability" })
end

-- Midnight watcher: players mid-session at UTC midnight get fresh trials on the spot.
task.spawn(function()
	while true do
		task.wait(60)
		local today = Dailies.dayStamp(os.time())
		for _, player in Players:GetPlayers() do
			local state = PlayerRegistry.tryGet(player)
			if state and state.dataReady and state.dailies.stamp ~= today then
				QuestService.ensureDailies(player, true)
			end
		end
	end
end)

return QuestService
