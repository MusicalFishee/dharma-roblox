--!strict
-- The weekly vow, live: everyone in the world grinds the SAME vrata each week
-- (deterministic rotation). QuestService relays the events it already tracks;
-- keeping the vow pays on the spot, and the week turning discards unfinished
-- progress without mercy (an hourly watcher catches mid-session turns).

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local Net = require(ReplicatedStorage.Shared.Net)
local Vrata = require(ReplicatedStorage.Shared.Vrata)
local Loot = require(ReplicatedStorage.Shared.Loot)
local PlayerRegistry = require(script.Parent.PlayerRegistry)

local VrataService = {}

local function sendInfo(player: Player)
	local state = PlayerRegistry.get(player)
	local def = Vrata.forWeek(state.vrata2.stamp)
	Net.CombatFeedback:FireClient(player, {
		vrataInfo = true,
		name = def.name,
		line = def.line,
		progress = state.vrata2.progress,
		target = def.target,
		kept = state.vrata2.kept,
	})
end

-- Reset a stale week (or initialize a fresh save) to the current vow.
local function ensureCurrent(player: Player, announceReset: boolean)
	local state = PlayerRegistry.get(player)
	local nowStamp = Vrata.weekStamp(os.time())
	if state.vrata2.stamp ~= nowStamp then
		state.vrata2 = { stamp = nowStamp, progress = 0, kept = false }
		if announceReset then
			Net.CombatFeedback:FireClient(player, { vrataReset = true, name = Vrata.forWeek(nowStamp).name })
		end
	end
end

function VrataService.ensure(player: Player)
	ensureCurrent(player, false)
	sendInfo(player)
end

-- QuestService relays every tracked event here (same pattern as the tutorial).
function VrataService.onEvent(player: Player, eventKind: string, amount: number?)
	local state = PlayerRegistry.tryGet(player)
	if not state or not state.dataLoaded or state.vrata2.kept then
		return
	end
	ensureCurrent(player, true)
	local def = Vrata.forWeek(state.vrata2.stamp)
	local before = state.vrata2.progress
	local advance = Vrata.advance(def, before, eventKind, amount)
	if advance.progress == before then
		return
	end
	state.vrata2.progress = advance.progress

	if advance.kept then
		state.vrata2.kept = true
		state.gold = Loot.clampGold(state.gold + def.rewardGold)
		state.shards += def.rewardShards
		Net.CombatFeedback:FireClient(player, { goldUpdate = true, gained = 0, gold = state.gold })
		Net.CombatFeedback:FireClient(player, { shardUpdate = true, gained = def.rewardShards, shards = state.shards })
		Net.CombatFeedback:FireClient(player, { vrataKept = true, name = def.name, gold = def.rewardGold, shards = def.rewardShards })
		sendInfo(player)
		return
	end

	-- Refresh the tracker each time another 5% falls (events are torrential).
	local step = math.max(1, math.floor(def.target / 20))
	if math.floor(advance.progress / step) > math.floor(before / step) then
		sendInfo(player)
	end
end

-- The hourly watcher: a week can turn mid-session.
task.spawn(function()
	while true do
		task.wait(3600)
		for _, p in Players:GetPlayers() do
			local state = PlayerRegistry.tryGet(p)
			if state and state.dataLoaded then
				ensureCurrent(p, true)
				sendInfo(p)
			end
		end
	end
end)

print("[Dharma] VrataService ready — one vow, the whole world, all week.")

return VrataService
