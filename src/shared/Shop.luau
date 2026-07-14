--!strict
-- The Siddhi Shop: permanent upgrades bought with gold. Pure catalog + buy logic
-- so prices and effects are Lune-tested; ShopService applies them.

local Shop = {}

Shop.MaxTier = 10

export type Upgrade = {
	id: string,
	name: string,
	desc: string,
	basePrice: number,
	priceGrowth: number,
}

Shop.Catalog = {
	damage = {
		id = "damage",
		name = "Sharpened Astras",
		desc = "+4% damage per tier",
		basePrice = 100,
		priceGrowth = 1.55,
	},
	health = {
		id = "health",
		name = "Iron Body",
		desc = "+15 max health per tier",
		basePrice = 80,
		priceGrowth = 1.55,
	},
} :: { [string]: Upgrade }

-- Price of buying the NEXT tier when you currently own `tier`.
function Shop.price(id: string, tier: number): number
	local u = Shop.Catalog[id]
	if not u then
		return math.huge
	end
	return math.floor(u.basePrice * (u.priceGrowth ^ math.max(0, tier)))
end

-- Effects.
function Shop.damageMult(tier: number): number
	return 1 + math.clamp(tier, 0, Shop.MaxTier) * 0.04
end

function Shop.healthBonus(tier: number): number
	return math.clamp(tier, 0, Shop.MaxTier) * 15
end

export type BuyResult = {
	ok: boolean,
	reason: string, -- "ok" | "unknown" | "max" | "gold"
	goldAfter: number,
}

function Shop.tryBuy(id: string, gold: number, currentTier: number): BuyResult
	if not Shop.Catalog[id] then
		return { ok = false, reason = "unknown", goldAfter = gold }
	end
	if currentTier >= Shop.MaxTier then
		return { ok = false, reason = "max", goldAfter = gold }
	end
	local cost = Shop.price(id, currentTier)
	if gold < cost then
		return { ok = false, reason = "gold", goldAfter = gold }
	end
	return { ok = true, reason = "ok", goldAfter = gold - cost }
end

-- Clamp a persisted tier value.
function Shop.clampTier(value: any): number
	if type(value) ~= "number" or value ~= value or value < 0 then
		return 0
	end
	return math.min(math.floor(value), Shop.MaxTier)
end

return Shop
