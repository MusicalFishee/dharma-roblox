--!strict
-- Yajna: the fire ritual. Feed gold into the sacred flame and the whole party
-- carries the blessing until the line breaks — a wipe extinguishes everything.
-- Costs escalate with each offering of the same kind in a run, so the fire is
-- a gold SINK, not a subscription. Pure catalog + cost + merge (Lune-tested).

local Yajna = {}

Yajna.CostGrowth = 1.5 -- each repeat offering of a kind costs half again more

export type OfferingDef = {
	id: string,
	name: string,
	line: string,
	baseCost: number,
	effect: { [string]: number }, -- one effect key each (test-enforced)
}

local function offering(def: OfferingDef): OfferingDef
	return def
end

Yajna.Catalog = {
	ghrta = offering({ id = "ghrta", name = "Ghṛta Offering", line = "Clarified butter feeds the flame: party +10% XP", baseCost = 600, effect = { xpMult = 1.1 } }),
	soma = offering({ id = "soma", name = "Soma Offering", line = "The pressed nectar: party +10% gold find", baseCost = 600, effect = { goldMult = 1.1 } }),
	bilva = offering({ id = "bilva", name = "Bilva Leaves", line = "The leaves He loves: party +5% damage", baseCost = 800, effect = { damageMult = 1.05 } }),
} :: { [string]: OfferingDef }

Yajna.Order = { "ghrta", "soma", "bilva" }

function Yajna.get(id: string): OfferingDef?
	return Yajna.Catalog[id]
end

-- The price of the NEXT offering of a kind, after `timesOffered` this run.
function Yajna.costFor(id: string, timesOffered: number): number
	local def = Yajna.Catalog[id]
	if not def then
		return 0
	end
	return math.floor(def.baseCost * Yajna.CostGrowth ^ math.max(0, timesOffered))
end

export type OfferCheck = {
	ok: boolean,
	reason: string, -- "ok" | "unknown" | "gold" | "lit"
	goldAfter: number,
}

-- Gate an offering: the kind must exist, be unlit, and be affordable.
-- (One flame per kind per run — the blessing doesn't stack, it BURNS.)
function Yajna.tryOffer(id: string, gold: number, alreadyLit: boolean, timesOffered: number): OfferCheck
	if not Yajna.Catalog[id] then
		return { ok = false, reason = "unknown", goldAfter = gold }
	end
	if alreadyLit then
		return { ok = false, reason = "lit", goldAfter = gold }
	end
	local cost = Yajna.costFor(id, timesOffered)
	if gold < cost then
		return { ok = false, reason = "gold", goldAfter = gold }
	end
	return { ok = true, reason = "ok", goldAfter = gold - cost }
end

export type Blessings = {
	xpMult: number,
	goldMult: number,
	damageMult: number,
}

-- What the lit flames add up to for the whole party.
function Yajna.blessingsFor(lit: { [string]: boolean }): Blessings
	local total: Blessings = { xpMult = 1, goldMult = 1, damageMult = 1 }
	for id in lit do
		local def = Yajna.Catalog[id]
		if def then
			total.xpMult *= def.effect.xpMult or 1
			total.goldMult *= def.effect.goldMult or 1
			total.damageMult *= def.effect.damageMult or 1
		end
	end
	return total
end

return Yajna
