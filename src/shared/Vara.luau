--!strict
-- Vara ("the boon"): fell a boss and choose one of three boons for the RUN.
-- Boons stack draft by draft into a build that exists only tonight — and a
-- party wipe scatters every one of them. Nothing here persists, by design:
-- vara is the run's story, not the account's. Pure pool + draw + merge math
-- (Lune-tested); VaraService offers, validates, and applies.

local Vara = {}

export type BoonDef = {
	id: string,
	name: string,
	line: string,
	effect: { [string]: number }, -- one effect key each (test-enforced)
}

local function boon(def: BoonDef): BoonDef
	return def
end

Vara.Pool = {
	boon({ id = "tikshna", name = "Tīkshna", line = "+8% to all damage", effect = { damageMult = 1.08 } }),
	boon({ id = "drdha", name = "Dṛḍha", line = "+40 max health", effect = { healthBonus = 40 } }),
	boon({ id = "rakta", name = "Rakta", line = "Melee blows return 3% as health", effect = { lifesteal = 0.03 } }),
	boon({ id = "vega", name = "Vega", line = "+8% move speed", effect = { speedMult = 1.08 } }),
	boon({ id = "laksya", name = "Lakṣya", line = "+5% critical chance", effect = { critChance = 0.05 } }),
	boon({ id = "urja", name = "Ūrjā", line = "+15% Tejas gain", effect = { tejasMult = 1.15 } }),
	boon({ id = "dhana", name = "Dhana", line = "+10% gold find", effect = { goldMult = 1.1 } }),
	boon({ id = "jnana", name = "Jñāna", line = "+10% XP gain", effect = { xpMult = 1.1 } }),
	boon({ id = "kavaca", name = "Kavaca", line = "-8% damage taken", effect = { damageTakenMult = 0.92 } }),
	boon({ id = "chapala", name = "Chapala", line = "Dodge windows last 0.1s longer", effect = { dodgeBonusSeconds = 0.1 } }),
	boon({ id = "jvala", name = "Jvālā", line = "Astras strike 10% harder", effect = { abilityDamageMult = 1.1 } }),
	boon({ id = "sthira", name = "Sthira", line = "Heals mend 15% deeper", effect = { healMult = 1.15 } }),
} :: { BoonDef }

Vara.OfferSize = 3

local byId: { [string]: BoonDef } = {}
for _, def in Vara.Pool do
	byId[def.id] = def
end

function Vara.get(id: string): BoonDef?
	return byId[id]
end

local function has(list: { string }, id: string): boolean
	for _, v in list do
		if v == id then
			return true
		end
	end
	return false
end

-- Draw up to OfferSize distinct boons the runner doesn't already hold.
-- rng defaults to math.random; an exhausted pool draws fewer, then none.
function Vara.draw(owned: { string }, rng: (() -> number)?): { BoonDef }
	local function roll(): number
		if rng then
			return rng()
		end
		return math.random()
	end
	local candidates: { BoonDef } = {}
	for _, def in Vara.Pool do
		if not has(owned, def.id) then
			table.insert(candidates, def)
		end
	end
	local offer: { BoonDef } = {}
	for _ = 1, math.min(Vara.OfferSize, #candidates) do
		local index = math.clamp(math.floor(roll() * #candidates) + 1, 1, #candidates)
		table.insert(offer, table.remove(candidates, index) :: BoonDef)
	end
	return offer
end

export type Effects = {
	damageMult: number,
	healthBonus: number,
	lifesteal: number,
	speedMult: number,
	critChance: number,
	tejasMult: number,
	goldMult: number,
	xpMult: number,
	damageTakenMult: number,
	dodgeBonusSeconds: number,
	abilityDamageMult: number,
	healMult: number,
}

-- Everything a run's boons add up to. Multipliers multiply, flats add,
-- unknown ids are skipped, duplicates count once.
function Vara.totalEffects(ids: { string }): Effects
	local total: Effects = {
		damageMult = 1,
		healthBonus = 0,
		lifesteal = 0,
		speedMult = 1,
		critChance = 0,
		tejasMult = 1,
		goldMult = 1,
		xpMult = 1,
		damageTakenMult = 1,
		dodgeBonusSeconds = 0,
		abilityDamageMult = 1,
		healMult = 1,
	}
	local seen: { [string]: boolean } = {}
	for _, id in ids do
		local def = byId[id]
		if not def or seen[id] then
			continue
		end
		seen[id] = true
		local e = def.effect
		total.damageMult *= e.damageMult or 1
		total.healthBonus += e.healthBonus or 0
		total.lifesteal += e.lifesteal or 0
		total.speedMult *= e.speedMult or 1
		total.critChance += e.critChance or 0
		total.tejasMult *= e.tejasMult or 1
		total.goldMult *= e.goldMult or 1
		total.xpMult *= e.xpMult or 1
		total.damageTakenMult *= e.damageTakenMult or 1
		total.dodgeBonusSeconds += e.dodgeBonusSeconds or 0
		total.abilityDamageMult *= e.abilityDamageMult or 1
		total.healMult *= e.healMult or 1
	end
	return total
end

-- Gate a pick: it must be one of the offered ids and not already held.
function Vara.canPick(offer: { string }, owned: { string }, id: string): boolean
	return byId[id] ~= nil and has(offer, id) and not has(owned, id)
end

return Vara
