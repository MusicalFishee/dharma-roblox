--!strict
-- Shapatha: the oath. Between waves, any warrior may swear the NEXT wave
-- crueler for the whole party — and the party reaps the multiplied bounty if
-- the wave breaks. One oath per wave; the harder the vow, the fatter the pay.
-- Pure defs + gating + archetype math (Lune-tested); WaveService applies it.

local Shapatha = {}

export type OathDef = {
	id: string,
	name: string,
	line: string,
	enemyHealthMult: number,
	enemyDamageMult: number,
	rewardMult: number, -- multiplies the wave-clear bounty (gold + XP)
}

local function oath(def: OathDef): OathDef
	return def
end

Shapatha.Catalog = {
	raudra = oath({ id = "raudra", name = "Raudra Shapatha", line = "The wrathful vow: foes strike 50% harder — the bounty doubles.", enemyHealthMult = 1, enemyDamageMult = 1.5, rewardMult = 2 }),
	ghora = oath({ id = "ghora", name = "Ghora Shapatha", line = "The terrible vow: foes endure 40% more and hit 20% harder — 2.5x bounty.", enemyHealthMult = 1.4, enemyDamageMult = 1.2, rewardMult = 2.5 }),
	maha = oath({ id = "maha", name = "Mahā Shapatha", line = "The great vow: foes 60% crueler in all things — the bounty TRIPLES.", enemyHealthMult = 1.6, enemyDamageMult = 1.6, rewardMult = 3 }),
} :: { [string]: OathDef }

Shapatha.Order = { "raudra", "ghora", "maha" }

function Shapatha.get(id: string): OathDef?
	return Shapatha.Catalog[id]
end

export type OathCheck = {
	ok: boolean,
	reason: string, -- "ok" | "unknown" | "sworn" | "battle"
}

-- Gate an oath: it must exist, be sworn BETWEEN waves, and only once per wave.
function Shapatha.tryOath(id: string, battleActive: boolean, alreadySworn: boolean): OathCheck
	if not Shapatha.Catalog[id] then
		return { ok = false, reason = "unknown" }
	end
	if battleActive then
		return { ok = false, reason = "battle" }
	end
	if alreadySworn then
		return { ok = false, reason = "sworn" }
	end
	return { ok = true, reason = "ok" }
end

-- An immutable, crueler copy of an enemy archetype (same trick as the doshas).
function Shapatha.applyToArchetype(def: OathDef, archetype: any): any
	local out = table.clone(archetype)
	out.maxHealth = math.floor(archetype.maxHealth * def.enemyHealthMult)
	out.attackDamage = math.floor(archetype.attackDamage * def.enemyDamageMult)
	return out
end

export type OathBounty = {
	gold: number,
	xp: number,
}

-- The extra bounty an oath pays on the wave's break, atop the plain clear:
-- base scales with the wave, then the vow's multiplier minus the plain share.
function Shapatha.bountyFor(def: OathDef, wave: number): OathBounty
	local base = 12 * wave
	return {
		gold = math.floor(base * (def.rewardMult - 1)),
		xp = math.floor(base * 0.6 * (def.rewardMult - 1)),
	}
end

return Shapatha
