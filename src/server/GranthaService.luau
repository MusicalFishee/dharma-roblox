--!strict
-- GranthaService: inks the book of foes. Every kill that reaches the killer
-- ledger also inks its family's page; claims recompute the earned tiers from
-- the REAL kill counts — the book is a window, never a wallet.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Net = require(ReplicatedStorage.Shared.Net)
local Grantha = require(ReplicatedStorage.Shared.Grantha)
local Loot = require(ReplicatedStorage.Shared.Loot)
local PlayerRegistry = require(script.Parent.PlayerRegistry)

local GranthaService = {}

function GranthaService.onKill(killer: Player, archetypeId: string)
	local familyId = Grantha.familyOf(archetypeId)
	if not familyId then
		return
	end
	local state = PlayerRegistry.tryGet(killer)
	if not state or not state.dataReady then
		return -- never ink a page the save can't keep
	end
	state.granthaKills[familyId] = (state.granthaKills[familyId] or 0) + 1
end

local function snapshot(player: Player)
	local state = PlayerRegistry.get(player)
	Net.CombatFeedback:FireClient(player, {
		granthaInfo = true,
		kills = state.granthaKills,
		claims = state.granthaClaims,
	})
end

Net.GranthaRequest.OnServerEvent:Connect(function(player: Player, data: any)
	if typeof(data) ~= "table" then
		return
	end
	local state = PlayerRegistry.get(player)
	if not state.dataReady then
		return
	end

	if data.action == "info" then
		snapshot(player)
		return
	end

	if data.action == "claim" then
		local def = Grantha.get(tostring(data.id))
		if not def then
			return
		end
		local kills = state.granthaKills[def.id] or 0
		local owed = Grantha.owedFor(def, kills, state.granthaClaims[def.id] or 0)
		if owed.tiers == 0 then
			snapshot(player)
			return
		end
		state.granthaClaims[def.id] = Grantha.tierFor(def, kills)
		state.gold = Loot.clampGold(state.gold + owed.gold)
		Net.CombatFeedback:FireClient(player, { goldUpdate = true, gained = owed.gold, gold = state.gold })
		Net.CombatFeedback:FireClient(player, { granthaClaimed = true, name = def.name, gold = owed.gold, tiers = owed.tiers })
		snapshot(player)
	end
end)

print("[Dharma] GranthaService ready — the book of foes is open (;).")

return GranthaService
