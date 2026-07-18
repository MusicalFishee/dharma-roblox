--!strict
-- BhavaService: the stance wheel. One request cycles the posture; the
-- damage and tejas chains read it straight off the registry.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Net = require(ReplicatedStorage.Shared.Net)
local Bhava = require(ReplicatedStorage.Shared.Bhava)
local PlayerRegistry = require(script.Parent.PlayerRegistry)

local BhavaService = {}

local function send(player: Player)
	local state = PlayerRegistry.get(player)
	local def = Bhava.get(state.bhava)
	Net.CombatFeedback:FireClient(player, {
		bhavaSet = true,
		id = def.id,
		name = def.name,
		line = def.line,
		glyph = def.glyph,
		r = def.color[1],
		g = def.color[2],
		b = def.color[3],
	})
end

Net.BhavaRequest.OnServerEvent:Connect(function(player: Player, data: any)
	if typeof(data) ~= "table" then
		return
	end
	local state = PlayerRegistry.get(player)
	if data.action == "cycle" then
		state.bhava = Bhava.next(state.bhava)
		send(player)
	elseif data.action == "info" then
		send(player)
	end
end)

print("[Dharma] BhavaService ready — the posture wheel turns (Tab).")

return BhavaService
