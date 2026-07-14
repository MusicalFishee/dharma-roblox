--!strict
-- Quest engine: keeps 3 active quests per player, advances them on game events,
-- pays out on completion, and draws a fresh quest to fill the slot.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Net = require(ReplicatedStorage.Shared.Net)
local Quests = require(ReplicatedStorage.Shared.Quests)
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

-- Push the quest panel state to the client.
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
	Net.CombatFeedback:FireClient(player, { questUpdate = true, quests = view })
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

-- Advance all matching active quests for one event.
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

	if changed then
		QuestService.sync(player)
	end
end

function QuestService.onKill(player: Player, enemyId: string, isBoss: boolean)
	handleEvent(player, { type = "kill", enemyId = enemyId, isBoss = isBoss })
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

return QuestService
