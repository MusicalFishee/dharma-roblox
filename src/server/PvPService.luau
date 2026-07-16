--!strict
-- Honor duels, server-side: challenge -> accept -> countdown -> live blades until one
-- falls (or the clock calls a draw). Consent-only; CombatService asks duelOpponentOf()
-- before letting a swing touch another player. Wins are lifetime stats (Duelist title).

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local Net = require(ReplicatedStorage.Shared.Net)
local PvP = require(ReplicatedStorage.Shared.PvP)
local PlayerRegistry = require(script.Parent.PlayerRegistry)

local PvPService = {}

type Challenge = {
	target: Player,
	expiresAt: number,
}

type Duel = {
	foe: Player,
	endsAt: number,
	live: boolean, -- false during the countdown
}

local challenges: { [Player]: Challenge } = {}
local duels: { [Player]: Duel } = {}

local function send(player: Player, data: { [string]: any })
	Net.CombatFeedback:FireClient(player, data)
end

local function broadcastAll(data: { [string]: any })
	for _, p in Players:GetPlayers() do
		Net.CombatFeedback:FireClient(p, data)
	end
end

-- Busy = mid-duel (or countdown), or waiting on a challenge in either direction.
local function isBusy(player: Player): boolean
	if duels[player] then
		return true
	end
	if challenges[player] then
		return true
	end
	for _, c in challenges do
		if c.target == player then
			return true
		end
	end
	return false
end

-- The opponent a player may currently strike (nil outside a LIVE duel).
function PvPService.duelOpponentOf(player: Player): Player?
	local duel = duels[player]
	if duel and duel.live then
		return duel.foe
	end
	return nil
end

local function roster(player: Player): { [string]: any }
	local list = {}
	for _, p in Players:GetPlayers() do
		if p ~= player then
			table.insert(list, { userId = p.UserId, name = p.DisplayName, busy = isBusy(p) })
		end
	end
	return { pvp = "roster", players = list, busy = isBusy(player) }
end

local function endDuel(a: Player, b: Player)
	duels[a] = nil
	duels[b] = nil
end

-- Somebody won. Pay respects, pay the stat, tell the world.
local function declareWinner(winner: Player, loser: Player)
	endDuel(winner, loser)
	local wstate = PlayerRegistry.tryGet(winner)
	if wstate then
		wstate.stats.duelWins += 1
	end
	send(winner, { pvp = "won", foeName = loser.DisplayName })
	send(loser, { pvp = "lost", foeName = winner.DisplayName })
	broadcastAll({ pvp = "announce", winner = winner.DisplayName, loser = loser.DisplayName })
end

-- Watch a duelist's humanoid for the deciding fall.
local function watchForFall(player: Player)
	local char = player.Character
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	if not hum then
		return
	end
	local conn: RBXScriptConnection
	conn = hum.Died:Connect(function()
		conn:Disconnect()
		local duel = duels[player]
		if duel and duel.live then
			declareWinner(duel.foe, player)
		end
	end)
end

local function beginDuel(a: Player, b: Player)
	local endsAt = os.clock() + PvP.Config.CountdownSeconds + PvP.Config.DuelDuration
	duels[a] = { foe = b, endsAt = endsAt, live = false }
	duels[b] = { foe = a, endsAt = endsAt, live = false }

	task.spawn(function()
		for n = PvP.Config.CountdownSeconds, 1, -1 do
			if not duels[a] or not duels[b] then
				return -- somebody vanished mid-standoff
			end
			send(a, { pvp = "countdown", n = n })
			send(b, { pvp = "countdown", n = n })
			task.wait(1)
		end
		local da, db = duels[a], duels[b]
		if not da or not db then
			return
		end
		da.live = true
		db.live = true
		send(a, { pvp = "begin", foeName = b.DisplayName })
		send(b, { pvp = "begin", foeName = a.DisplayName })
		watchForFall(a)
		watchForFall(b)
	end)
end

Net.PvPRequest.OnServerEvent:Connect(function(player: Player, data: any)
	if typeof(data) ~= "table" then
		return
	end

	if data.action == "list" then
		send(player, roster(player))
		return
	end

	if data.action == "challenge" then
		local target = Players:GetPlayerByUserId(tonumber(data.userId) or 0)
		if not target then
			return
		end
		local verdict = PvP.canChallenge(target == player, isBusy(player), isBusy(target))
		if not verdict.ok then
			send(player, { pvp = "denied", reason = verdict.reason })
			send(player, roster(player))
			return
		end
		challenges[player] = { target = target, expiresAt = os.clock() + PvP.Config.ChallengeExpiry }
		send(player, { pvp = "sent", toName = target.DisplayName })
		send(target, { pvp = "challenged", fromName = player.DisplayName, fromUserId = player.UserId })
		return
	end

	if data.action == "accept" or data.action == "decline" then
		-- Find the (unexpired) challenge aimed at this player from that user.
		local challenger = Players:GetPlayerByUserId(tonumber(data.userId) or 0)
		if not challenger then
			return
		end
		local challenge = challenges[challenger]
		if not challenge or challenge.target ~= player or PvP.isExpired(os.clock(), challenge.expiresAt) then
			return
		end
		challenges[challenger] = nil

		if data.action == "decline" then
			send(challenger, { pvp = "declined", byName = player.DisplayName })
			return
		end
		beginDuel(challenger, player)
	end
end)

-- Housekeeping: expire stale challenges, call overtime duels a draw.
task.spawn(function()
	while true do
		task.wait(5)
		local now = os.clock()
		for challenger, c in challenges do
			if PvP.isExpired(now, c.expiresAt) then
				challenges[challenger] = nil
				send(challenger, { pvp = "expired", toName = c.target.DisplayName })
			end
		end
		for player, duel in duels do
			if duel.live and now >= duel.endsAt and duels[player] then
				local foe = duel.foe
				endDuel(player, foe)
				send(player, { pvp = "draw" })
				send(foe, { pvp = "draw" })
			end
		end
	end
end)

-- Walking out mid-duel forfeits it.
Players.PlayerRemoving:Connect(function(player)
	challenges[player] = nil
	for challenger, c in challenges do
		if c.target == player then
			challenges[challenger] = nil
			send(challenger, { pvp = "expired", toName = player.DisplayName })
		end
	end
	local duel = duels[player]
	if duel then
		if duel.live then
			declareWinner(duel.foe, player)
		else
			endDuel(player, duel.foe)
		end
	end
end)

print("[Dharma] PvPService ready — honor duels open.")

return PvPService
