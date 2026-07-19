--!strict
-- HeraldService: the Charana's voice. proclaim() cries a warrior's deed to
-- every soul online — but only ONCE per warrior per deed per server session,
-- so a legendary moment lands as a moment, never a drip.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local Net = require(ReplicatedStorage.Shared.Net)
local Herald = require(ReplicatedStorage.Shared.Herald)
local PlayerRegistry = require(script.Parent.PlayerRegistry)

local HeraldService = {}

function HeraldService.proclaim(player: Player, kind: string)
	if not Herald.isKind(kind) then
		return
	end
	local state = PlayerRegistry.tryGet(player)
	if not state then
		return
	end
	if state.heralded[kind] then
		return -- this warrior has already been cried for this deed this session
	end
	state.heralded[kind] = true

	local text = Herald.proclaim(kind, player.DisplayName)
	if not text then
		return
	end
	local color = Herald.colorOf(kind)
	for _, p in Players:GetPlayers() do
		Net.CombatFeedback:FireClient(p, {
			herald = true,
			kind = kind,
			text = text,
			r = color[1],
			g = color[2],
			b = color[3],
		})
	end
end

print("[Dharma] HeraldService ready — the Charana watches for greatness.")

return HeraldService
