--!strict
-- TournamentService: four-name kumbhas on the ordinary duel machinery. Queue
-- from the PvP panel; at four names the bracket seeds and matches run one at
-- a time (the arena stays readable): two semifinals, then the final. The
-- champion takes the purse. Vanished names forfeit by walkover; a stalled
-- draw advances the first seed. Pure bracket math lives in Tournament.luau.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local Net = require(ReplicatedStorage.Shared.Net)
local Tournament = require(ReplicatedStorage.Shared.Tournament)
local Loot = require(ReplicatedStorage.Shared.Loot)
local PlayerRegistry = require(script.Parent.PlayerRegistry)
local PvPService = require(script.Parent.PvPService)

local TournamentService = {}

local queue: { Player } = {}
local bracket: Tournament.Bracket? = nil
local playersById: { [number]: Player } = {}
local awaiting: { a: number, b: number, isFinal: boolean }? = nil

local function broadcastAll(data: { [string]: any })
	for _, p in Players:GetPlayers() do
		Net.CombatFeedback:FireClient(p, data)
	end
end

local function livePlayer(id: number): Player?
	local p = playersById[id]
	if p and p.Parent then
		return p
	end
	return nil
end

local function announceQueue()
	local names: { string } = {}
	for _, p in queue do
		table.insert(names, p.DisplayName)
	end
	broadcastAll({ tourney = "queue", count = #queue, needed = Tournament.Size, names = names })
end

local nextMatch: () -> ()

local function concludeIfCrowned()
	local br = bracket
	if not br or not br.champion then
		return
	end
	local champ = livePlayer(br.champion)
	if champ then
		local state = PlayerRegistry.tryGet(champ)
		if state then
			state.gold = Loot.clampGold(state.gold + Tournament.Purse.gold)
			state.shards += Tournament.Purse.shards
			Net.CombatFeedback:FireClient(champ, { goldUpdate = true, gained = Tournament.Purse.gold, gold = state.gold })
			Net.CombatFeedback:FireClient(champ, { shardUpdate = true, gained = Tournament.Purse.shards, shards = state.shards })
		end
		broadcastAll({ tourney = "champion", name = champ.DisplayName, gold = Tournament.Purse.gold, shards = Tournament.Purse.shards })
	end
	bracket = nil
	awaiting = nil
	table.clear(playersById)
end

local function startPair(aId: number, bId: number, isFinal: boolean)
	local br = bracket
	if not br then
		return
	end
	local a = livePlayer(aId)
	local b = livePlayer(bId)
	if not a then
		Tournament.walkover(br, aId)
		nextMatch()
		return
	end
	if not b then
		Tournament.walkover(br, bId)
		nextMatch()
		return
	end
	awaiting = { a = aId, b = bId, isFinal = isFinal }
	broadcastAll({
		tourney = if isFinal then "final" else "semi",
		aName = a.DisplayName,
		bName = b.DisplayName,
	})
	PvPService.beginDuel(a, b)
end

nextMatch = function()
	local br = bracket
	if not br then
		return
	end
	concludeIfCrowned()
	br = bracket
	if not br then
		return
	end
	-- An unresolved semifinal runs first.
	for _, pair in br.semis do
		local resolved = false
		for _, f in br.finalists do
			if f == pair[1] or f == pair[2] then
				resolved = true
			end
		end
		if not resolved then
			startPair(pair[1], pair[2], false)
			return
		end
	end
	if Tournament.isFinalReady(br) then
		startPair(br.finalists[1], br.finalists[2], true)
	end
end

-- The duel machinery reports back through these seams.
PvPService.onDuelEnd = function(winner: Player, loser: Player)
	local br, aw = bracket, awaiting
	if not br or not aw then
		return
	end
	local wid, lid = winner.UserId, loser.UserId
	if (wid == aw.a or wid == aw.b) and (lid == aw.a or lid == aw.b) then
		awaiting = nil
		if aw.isFinal then
			Tournament.reportFinalWin(br, wid)
		else
			Tournament.reportSemiWin(br, wid)
		end
		task.delay(3, nextMatch)
	end
end

PvPService.onDuelDraw = function(a: Player, b: Player)
	local br, aw = bracket, awaiting
	if not br or not aw then
		return
	end
	local ids = { [a.UserId] = true, [b.UserId] = true }
	if ids[aw.a] and ids[aw.b] then
		-- A stalled kumbha match advances the first seed.
		awaiting = nil
		Tournament.walkover(br, aw.b)
		task.delay(3, nextMatch)
	end
end

Net.PvPRequest.OnServerEvent:Connect(function(player: Player, data: any)
	if typeof(data) ~= "table" then
		return
	end

	if data.action == "tourneyJoin" then
		if bracket then
			Net.CombatFeedback:FireClient(player, { tourney = "busy" })
			return
		end
		for _, p in queue do
			if p == player then
				return
			end
		end
		table.insert(queue, player)
		announceQueue()
		if #queue >= Tournament.Size then
			local four = { queue[1], queue[2], queue[3], queue[4] }
			for _ = 1, Tournament.Size do
				table.remove(queue, 1)
			end
			local ids: { number } = {}
			for _, p in four do
				playersById[p.UserId] = p
				table.insert(ids, p.UserId)
			end
			bracket = Tournament.seed(ids)
			local names: { string } = {}
			for _, p in four do
				table.insert(names, p.DisplayName)
			end
			broadcastAll({ tourney = "begins", names = names })
			task.delay(3, nextMatch)
		end
		return
	end

	if data.action == "tourneyLeave" then
		for i, p in queue do
			if p == player then
				table.remove(queue, i)
				announceQueue()
				break
			end
		end
		return
	end
end)

-- A vanished name forfeits its whole road.
Players.PlayerRemoving:Connect(function(player: Player)
	for i, p in queue do
		if p == player then
			table.remove(queue, i)
			announceQueue()
			break
		end
	end
	local br = bracket
	if br and playersById[player.UserId] then
		local aw = awaiting
		if aw and (aw.a == player.UserId or aw.b == player.UserId) then
			awaiting = nil
		end
		Tournament.walkover(br, player.UserId)
		playersById[player.UserId] = nil
		task.delay(2, nextMatch)
	end
end)

print("[Dharma] TournamentService ready — four names, one crown.")

return TournamentService
