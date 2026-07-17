--!strict
-- Vara, live: after a slain boss wave, every warrior is offered three boons —
-- pick one, stack the run's build. A party wipe scatters everything. Nothing
-- persists: the draft is the run's story, not the account's.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local Net = require(ReplicatedStorage.Shared.Net)
local Vara = require(ReplicatedStorage.Shared.Vara)
local PlayerRegistry = require(script.Parent.PlayerRegistry)
local ProgressionService = require(script.Parent.ProgressionService)

local VaraService = {}

-- A boss has fallen: deal every ready warrior their offer.
function VaraService.offerAll()
	for _, player in Players:GetPlayers() do
		local state = PlayerRegistry.tryGet(player)
		if not state or not state.dataReady then
			continue
		end
		local offer = Vara.draw(state.vara, function()
			return math.random()
		end)
		if #offer == 0 then
			continue -- a full draft has nothing left to take
		end
		local ids: { string } = {}
		local options = {}
		for _, def in offer do
			table.insert(ids, def.id)
			table.insert(options, { id = def.id, name = def.name, line = def.line })
		end
		state.varaOffer = ids
		Net.CombatFeedback:FireClient(player, { varaOffer = true, options = options })
	end
end

-- The wipe takes everything the run gave.
function VaraService.scatterAll()
	for _, player in Players:GetPlayers() do
		local state = PlayerRegistry.tryGet(player)
		if not state then
			continue
		end
		state.varaOffer = {}
		if #state.vara > 0 then
			state.vara = {}
			ProgressionService.refreshStats(player)
			Net.CombatFeedback:FireClient(player, { varaScattered = true })
		end
	end
end

Net.VaraRequest.OnServerEvent:Connect(function(player: Player, data: any)
	if typeof(data) ~= "table" or data.action ~= "pick" then
		return
	end
	local state = PlayerRegistry.get(player)
	local id = tostring(data.id)
	if not Vara.canPick(state.varaOffer, state.vara, id) then
		return
	end
	state.varaOffer = {}
	table.insert(state.vara, id)
	-- Health/speed boons land immediately (no free heal).
	ProgressionService.refreshStats(player)
	local def = Vara.get(id) :: Vara.BoonDef
	Net.CombatFeedback:FireClient(player, { varaPicked = true, name = def.name, line = def.line, held = #state.vara })
end)

print("[Dharma] VaraService ready — the boons wait on the boss's corpse.")

return VaraService
