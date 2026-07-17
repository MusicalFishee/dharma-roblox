--!strict
-- The rites, live. YAJNA: any warrior feeds gold to the flame and the WHOLE
-- party carries the blessing until the line breaks (wipe = extinguished,
-- costs reset — a fresh run relights from the base price). SHAPATHA: between
-- waves, one oath makes the NEXT wave crueler for a multiplied bounty;
-- WaveService consumes the pending oath at the next wave start.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local Net = require(ReplicatedStorage.Shared.Net)
local Yajna = require(ReplicatedStorage.Shared.Yajna)
local Shapatha = require(ReplicatedStorage.Shared.Shapatha)
local PlayerRegistry = require(script.Parent.PlayerRegistry)

local RitesService = {}

local lit: { [string]: boolean } = {}
local timesOffered: { [string]: number } = {}
local pendingOath: Shapatha.OathDef? = nil
local battleActive = false

local function broadcastAll(data: { [string]: any })
	for _, p in Players:GetPlayers() do
		Net.CombatFeedback:FireClient(p, data)
	end
end

local function snapshot(player: Player)
	local costs: { [string]: number } = {}
	for _, id in Yajna.Order do
		costs[id] = Yajna.costFor(id, timesOffered[id] or 0)
	end
	local litCopy: { [string]: boolean } = {}
	for id in lit do
		litCopy[id] = true
	end
	Net.CombatFeedback:FireClient(player, {
		ritesInfo = true,
		lit = litCopy,
		costs = costs,
		oathPending = if pendingOath then pendingOath.name else nil,
		battle = battleActive,
	})
end

-- The party-wide blessing multipliers (read by combat/xp/gold chains).
function RitesService.mults(): Yajna.Blessings
	return Yajna.blessingsFor(lit)
end

-- WaveService flips this at wave start / clear / wipe (oaths swear between waves).
function RitesService.setBattleActive(active: boolean)
	battleActive = active
end

-- WaveService takes the sworn oath as the next wave begins (nil = plain wave).
function RitesService.takePendingOath(): Shapatha.OathDef?
	local oathDef = pendingOath
	pendingOath = nil
	return oathDef
end

-- The wipe puts out every flame and voids the oath. Costs reset with the run.
function RitesService.extinguish()
	local hadFlames = next(lit) ~= nil
	lit = {}
	timesOffered = {}
	pendingOath = nil
	if hadFlames then
		broadcastAll({ yajnaExtinguished = true })
	end
end

Net.RitesRequest.OnServerEvent:Connect(function(player: Player, data: any)
	if typeof(data) ~= "table" then
		return
	end
	local state = PlayerRegistry.get(player)

	if data.action == "info" then
		snapshot(player)
		return
	end

	if data.action == "offer" then
		local id = tostring(data.id)
		local checkResult = Yajna.tryOffer(id, state.gold, lit[id] == true, timesOffered[id] or 0)
		if not checkResult.ok then
			Net.CombatFeedback:FireClient(player, { ritesDenied = true, reason = checkResult.reason })
			snapshot(player)
			return
		end
		state.gold = checkResult.goldAfter
		lit[id] = true
		timesOffered[id] = (timesOffered[id] or 0) + 1
		local def = Yajna.get(id) :: Yajna.OfferingDef
		Net.CombatFeedback:FireClient(player, { goldUpdate = true, gained = 0, gold = state.gold })
		broadcastAll({ yajnaLit = true, name = def.name, line = def.line, byName = player.Name })
		snapshot(player)
		return
	end

	if data.action == "swear" then
		local id = tostring(data.id)
		local checkResult = Shapatha.tryOath(id, battleActive, pendingOath ~= nil)
		if not checkResult.ok then
			Net.CombatFeedback:FireClient(player, { ritesDenied = true, reason = checkResult.reason })
			snapshot(player)
			return
		end
		pendingOath = Shapatha.get(id)
		local def = pendingOath :: Shapatha.OathDef
		broadcastAll({ oathSworn = true, name = def.name, line = def.line, byName = player.Name })
		snapshot(player)
		return
	end
end)

print("[Dharma] RitesService ready — the fire waits for ghee, the oath for nerve.")

return RitesService
