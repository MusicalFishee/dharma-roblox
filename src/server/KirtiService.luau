--!strict
-- Kirti claims, live: every earned tier in the glory ledger owes a one-time
-- gold bounty. The server recomputes the earned tier from the REAL stats on
-- every claim — the client's panel is a window, never a wallet.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Net = require(ReplicatedStorage.Shared.Net)
local Deeds = require(ReplicatedStorage.Shared.Deeds)
local Loot = require(ReplicatedStorage.Shared.Loot)
local Progression = require(ReplicatedStorage.Shared.Progression)
local PlayerRegistry = require(script.Parent.PlayerRegistry)

local KirtiService = {}

local function snapOf(state: any): Deeds.Snapshot
	return {
		kills = state.stats.kills,
		bossKills = state.stats.bossKills,
		bestWave = state.bestWave,
		duelWins = state.stats.duelWins,
		raidClears = state.stats.raidClears,
		revives = state.stats.revives,
		trials = state.stats.trialsPassed,
		level = Progression.resolve(state.totalXp).level,
		playtimeSeconds = state.stats.playtimeSeconds,
		deaths = state.stats.deaths,
		deerKills = state.stats.deerKills,
	}
end

local function sendClaims(player: Player)
	local state = PlayerRegistry.get(player)
	local claims: { [string]: number } = {}
	for id, tier in state.kirtiClaims do
		claims[id] = tier
	end
	Net.CombatFeedback:FireClient(player, { kirtiInfo = true, claims = claims })
end

Net.KirtiRequest.OnServerEvent:Connect(function(player: Player, data: any)
	if typeof(data) ~= "table" then
		return
	end
	local state = PlayerRegistry.get(player)

	if data.action == "info" then
		sendClaims(player)
		return
	end

	if data.action == "claim" then
		if not state.dataLoaded then
			return -- bounties must land on a save that can keep them
		end
		local id = tostring(data.id)
		local def: Deeds.DeedDef? = nil
		for _, d in Deeds.List do
			if d.id == id then
				def = d
			end
		end
		if not def then
			return
		end
		local deed = def :: Deeds.DeedDef
		local snap = snapOf(state)
		local value = Deeds.statFor(deed.kind, snap)
		local claimed = state.kirtiClaims[id] or 0
		local owed = Deeds.owedFor(deed, value, claimed)
		if owed.gold <= 0 then
			return
		end
		state.kirtiClaims[id] = Deeds.tierFor(deed, value)
		state.gold = Loot.clampGold(state.gold + owed.gold)
		Net.CombatFeedback:FireClient(player, { goldUpdate = true, gained = 0, gold = state.gold })
		Net.CombatFeedback:FireClient(player, { kirtiClaimed = true, name = deed.name, gold = owed.gold, tiers = owed.tiers })
		sendClaims(player)
	end
end)

print("[Dharma] KirtiService ready — glory pays its debts.")

return KirtiService
