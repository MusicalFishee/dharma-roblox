--!strict
-- Doshas: afflictions of the age. Every wave ending in 7 arrives marked —
-- the moon hides, the sky eclipses, fever quickens the horde, or the veil
-- of Māyā thickens everything. Marked waves fight harder and pay a bounty
-- on clear. Cadence is fixed (players learn to brace); the dosha is rolled.
-- Pure defs + roll + archetype math (Lune-tested); WaveService applies them.

local Doshas = {}

export type DoshaDef = {
	id: string,
	name: string,
	announce: string,
	enemyHealthMult: number,
	enemyDamageMult: number,
	enemySpeedMult: number,
	bonusGoldPerWave: number, -- clear bounty = this * wave
	bonusXpPerWave: number,
	weight: number,
}

Doshas.Defs = {
	amavasya = {
		id = "amavasya",
		name = "Amavasya, the New Moon",
		announce = "The moon hides its face — the horde strikes harder, and carries more gold.",
		enemyHealthMult = 1,
		enemyDamageMult = 1.25,
		enemySpeedMult = 1,
		bonusGoldPerWave = 18,
		bonusXpPerWave = 6,
		weight = 30,
	},
	grahana = {
		id = "grahana",
		name = "Grahana, the Eclipse",
		announce = "The sky swallows the sun — the horde endures beyond reason.",
		enemyHealthMult = 1.4,
		enemyDamageMult = 1,
		enemySpeedMult = 1,
		bonusGoldPerWave = 8,
		bonusXpPerWave = 14,
		weight = 25,
	},
	jvara = {
		id = "jvara",
		name = "Jvara, the Fever",
		announce = "A fever runs through the horde — faster, wilder, hungrier.",
		enemyHealthMult = 1,
		enemyDamageMult = 1.1,
		enemySpeedMult = 1.2,
		bonusGoldPerWave = 12,
		bonusXpPerWave = 8,
		weight = 25,
	},
	maya = {
		id = "maya",
		name = "Māyā, the Veil",
		announce = "The veil thickens — everything is more than it seems.",
		enemyHealthMult = 1.15,
		enemyDamageMult = 1.15,
		enemySpeedMult = 1.05,
		bonusGoldPerWave = 14,
		bonusXpPerWave = 10,
		weight = 20,
	},
} :: { [string]: DoshaDef }

Doshas.Order = { "amavasya", "grahana", "jvara", "maya" }

-- Marked waves: every wave ending in 7 (7, 17, 27, ...). Never collides with
-- boss waves (multiples of 5), trials (25 + 50k), or raids (multiples of 50).
function Doshas.isDoshaWave(wave: number): boolean
	return wave >= 7 and wave % 10 == 7
end

-- Which dosha marks this wave (weighted; rng defaults to math.random).
function Doshas.roll(wave: number, rng: (() -> number)?): DoshaDef?
	if not Doshas.isDoshaWave(wave) then
		return nil
	end
	local function roll(): number
		if rng then
			return rng()
		end
		return math.random()
	end
	local total = 0
	for _, id in Doshas.Order do
		total += Doshas.Defs[id].weight
	end
	local r = roll() * total
	for _, id in Doshas.Order do
		local def = Doshas.Defs[id]
		if r < def.weight then
			return def
		end
		r -= def.weight
	end
	return Doshas.Defs[Doshas.Order[#Doshas.Order]]
end

-- An immutable, scaled copy of an enemy archetype (same trick as Elites).
function Doshas.applyToArchetype(def: DoshaDef, archetype: any): any
	local out = table.clone(archetype)
	out.maxHealth = math.floor(archetype.maxHealth * def.enemyHealthMult)
	out.attackDamage = math.floor(archetype.attackDamage * def.enemyDamageMult)
	out.walkSpeed = archetype.walkSpeed * def.enemySpeedMult
	return out
end

export type Bounty = {
	gold: number,
	xp: number,
}

-- The clear bounty: deeper marked waves pay more.
function Doshas.bountyFor(def: DoshaDef, wave: number): Bounty
	return {
		gold = def.bonusGoldPerWave * wave,
		xp = def.bonusXpPerWave * wave,
	}
end

return Doshas
