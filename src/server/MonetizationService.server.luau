--!strict
-- The Vajra Bazaar, server-side: MarketplaceService receipts for the currency
-- bundles in shared Products. Design law: CURRENCIES ONLY — never power.
--
-- Idempotency: every granted PurchaseId is recorded in a ledger DataStore.
-- A replayed receipt that's already in the ledger grants nothing twice.
-- If the player (or their save) isn't ready, we return NotProcessedYet and
-- Roblox retries the receipt later — the purchase is never lost.

local MarketplaceService = game:GetService("MarketplaceService")
local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Net = require(ReplicatedStorage.Shared.Net)
local Products = require(ReplicatedStorage.Shared.Products)
local Loot = require(ReplicatedStorage.Shared.Loot)
local PlayerRegistry = require(script.Parent.PlayerRegistry)

local ledger = DataStoreService:GetDataStore("DharmaPurchaseLedger_v1")

MarketplaceService.ProcessReceipt = function(receipt): Enum.ProductPurchaseDecision
	local product = Products.byProductId(receipt.ProductId)
	if not product then
		-- Not one of ours (or not yet registered) — leave it pending, never eat it.
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end

	local player = Players:GetPlayerByUserId(receipt.PlayerId)
	if not player then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	local state = PlayerRegistry.tryGet(player)
	if not state or not state.dataLoaded then
		return Enum.ProductPurchaseDecision.NotProcessedYet -- wait for the save
	end

	-- Already granted once? (A replayed receipt after a recorded grant.)
	local checked, existing = pcall(function()
		return ledger:GetAsync(receipt.PurchaseId)
	end)
	if checked and existing then
		return Enum.ProductPurchaseDecision.PurchaseGranted
	end
	if not checked then
		return Enum.ProductPurchaseDecision.NotProcessedYet -- ledger unreachable; retry later
	end

	-- Grant.
	if product.kind == "gold" then
		state.gold = Loot.clampGold(state.gold + product.amount)
		Net.CombatFeedback:FireClient(player, { goldUpdate = true, gained = 0, gold = state.gold })
	else
		state.shards += product.amount
		Net.CombatFeedback:FireClient(player, { shardUpdate = true, gained = product.amount, shards = state.shards })
	end
	Net.CombatFeedback:FireClient(player, {
		bazaarGranted = true,
		name = product.name,
		kind = product.kind,
		amount = product.amount,
	})

	-- Record it. If the record fails, we still grant (the error lands in the
	-- player's favor — the rare retry double-grant beats a swallowed purchase).
	pcall(function()
		ledger:SetAsync(receipt.PurchaseId, { at = os.time(), userId = receipt.PlayerId, key = product.key })
	end)

	return Enum.ProductPurchaseDecision.PurchaseGranted
end

print("[Dharma] MonetizationService ready — the Bazaar's ledger is open.")
