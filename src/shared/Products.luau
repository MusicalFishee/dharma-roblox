--!strict
-- The Vajra Bazaar: Robux developer products, CURRENCIES ONLY by design law —
-- gold and Vajra Shards, never weapons, relics, paths, or power. Power is
-- earned, never bought.
--
-- productId 0 = not yet registered on the Roblox site. After publishing:
-- Creator Hub -> the experience -> Monetization -> Developer Products, create
-- one per entry below, then paste the real ids here. The Bazaar UI shows
-- "AT LAUNCH" for any id still 0, and ProcessReceipt ignores unknown ids.

local Products = {}

export type ProductDef = {
	key: string,
	name: string,
	kind: string, -- "gold" | "shards"
	amount: number,
	productId: number, -- 0 until registered on the Roblox site
}

Products.List = {
	{ key = "gold_small", name = "Pouch of Gold", kind = "gold", amount = 800, productId = 0 },
	{ key = "gold_medium", name = "Chest of Gold", kind = "gold", amount = 2600, productId = 0 },
	{ key = "gold_large", name = "A King's Ransom", kind = "gold", amount = 7000, productId = 0 },
	{ key = "shards_small", name = "A Few Vajra Shards", kind = "shards", amount = 5, productId = 0 },
	{ key = "shards_medium", name = "Handful of Vajra Shards", kind = "shards", amount = 15, productId = 0 },
	{ key = "shards_large", name = "Reliquary of Vajra Shards", kind = "shards", amount = 40, productId = 0 },
} :: { ProductDef }

function Products.byKey(key: string): ProductDef?
	for _, def in Products.List do
		if def.key == key then
			return def
		end
	end
	return nil
end

-- Receipt lookup: only registered (nonzero) ids ever match.
function Products.byProductId(productId: number): ProductDef?
	if productId == 0 then
		return nil
	end
	for _, def in Products.List do
		if def.productId == productId then
			return def
		end
	end
	return nil
end

return Products
