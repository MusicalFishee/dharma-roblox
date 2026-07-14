--!strict
-- The Siddhi Shop, server-side: validates purchases, applies permanent upgrades,
-- and keeps the client's shop panel in sync.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Net = require(ReplicatedStorage.Shared.Net)
local Shop = require(ReplicatedStorage.Shared.Shop)
local PlayerRegistry = require(script.Parent.PlayerRegistry)
local ProgressionService = require(script.Parent.ProgressionService)

local function shopSnapshot(player: Player): { [string]: any }
	local state = PlayerRegistry.get(player)
	local items = {}
	for id, u in Shop.Catalog do
		local tier = (state.upgrades :: any)[id] or 0
		items[id] = {
			name = u.name,
			desc = u.desc,
			tier = tier,
			maxTier = Shop.MaxTier,
			price = if tier >= Shop.MaxTier then 0 else Shop.price(id, tier),
		}
	end
	return { shop = true, gold = state.gold, items = items }
end

Net.ShopRequest.OnServerEvent:Connect(function(player: Player, data: any)
	if typeof(data) ~= "table" then
		return
	end

	if data.action == "info" then
		Net.CombatFeedback:FireClient(player, shopSnapshot(player))
		return
	end

	if data.action == "buy" then
		local id = tostring(data.id)
		local state = PlayerRegistry.get(player)
		local currentTier = (state.upgrades :: any)[id]
		if type(currentTier) ~= "number" then
			return
		end

		local result = Shop.tryBuy(id, state.gold, currentTier)
		if result.ok then
			state.gold = result.goldAfter;
			(state.upgrades :: any)[id] = currentTier + 1
			-- New max health applies immediately (no free heal).
			ProgressionService.refreshStats(player)
			Net.CombatFeedback:FireClient(player, { goldUpdate = true, gained = 0, gold = state.gold })
			Net.CombatFeedback:FireClient(player, {
				shopBought = true,
				itemName = Shop.Catalog[id].name,
				tier = currentTier + 1,
			})
		else
			Net.CombatFeedback:FireClient(player, { shopDenied = true, reason = result.reason })
		end
		-- Always refresh the panel.
		Net.CombatFeedback:FireClient(player, shopSnapshot(player))
	end
end)

print("[Dharma] ShopService ready — the Siddhi Shop is open.")
