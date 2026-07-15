--!strict
-- Mantras: enchantments inscribed onto your weapon at the Mantra Altar, paid for with
-- Vajra Shards that only slain BOSSES drop. Inscribing rolls a random mantra from the
-- weighted pool below and REPLACES whatever was there — that's the gamble. Mythics sit
-- under 1% each and carry a custom aura the weapon itself wears. Pure data + math
-- (Lune-tested); EnchantService applies rolls, combat services apply the effects.

local Enchants = {}

-- Economy: bosses drop shards; one inscription costs a few.
Enchants.ShardsPerBossKill = 2
Enchants.Cost = 3

export type Effect = {
	lifesteal: number?, -- fraction of damage dealt returned as health
	damageTakenMult: number?, -- incoming damage multiplier (<1 = tougher)
	tejasMult: number?, -- multiplier on Tejas gains
	bonusGoldPerKill: number?, -- flat bonus gold per killing blow
	burnDamage: number?, -- total burn damage, spread over burnSeconds
	burnSeconds: number?,
	executeThreshold: number?, -- non-bosses at/below this fraction of max HP die outright
	dodgeBonus: number?, -- fractional extension of dodge i-frames
	critChanceBonus: number?, -- additive crit chance
	critMultiplier: number?, -- replaces the default crit multiplier
	procChance: number?, -- per-hit chance of the sky-fire proc
	procDamage: number?,
	aura: string?, -- "fire" | "sparkles" — mythics only; the weapon visibly wears it
	auraColor: { number }?,
}

export type Rarity = "common" | "rare" | "mythic"

export type Enchant = {
	id: string,
	name: string,
	desc: string,
	rarity: Rarity,
	weight: number,
	effect: Effect,
}

Enchants.RarityColor = {
	common = { 190, 200, 210 },
	rare = { 130, 170, 255 },
	mythic = { 255, 170, 50 },
} :: { [string]: { number } }

Enchants.List = {
	-- Commons: steady, dependable boons.
	{
		id = "kubera_whisper",
		name = "Kubera's Whisper",
		desc = "The god of wealth murmurs over every kill. +10 gold per slaying blow.",
		rarity = "common",
		weight = 21,
		effect = { bonusGoldPerKill = 10 },
	},
	{
		id = "rakta_thirst",
		name = "Rakta Thirst",
		desc = "The blade drinks deep. Heal 10% of the damage you deal.",
		rarity = "common",
		weight = 21,
		effect = { lifesteal = 0.10 },
	},
	{
		id = "stoneskin_sutra",
		name = "Stoneskin Sutra",
		desc = "Verses of iron woven into the skin. Take 12% less damage.",
		rarity = "common",
		weight = 21,
		effect = { damageTakenMult = 0.88 },
	},
	{
		id = "tejas_wellspring",
		name = "Tejas Wellspring",
		desc = "Sacred energy pools faster. +40% Tejas gained.",
		rarity = "common",
		weight = 21,
		effect = { tejasMult = 1.4 },
	},
	-- Rares: fight-changing tricks.
	{
		id = "agni_kiss",
		name = "Agni's Kiss",
		desc = "Every strike ignites. Foes burn for 15 damage over 3 seconds.",
		rarity = "rare",
		weight = 5,
		effect = { burnDamage = 15, burnSeconds = 3 },
	},
	{
		id = "yama_ledger",
		name = "Yama's Ledger",
		desc = "The death-god settles his accounts instantly: foes under 12% health are claimed outright.",
		rarity = "rare",
		weight = 5,
		effect = { executeThreshold = 0.12 },
	},
	{
		id = "vayu_grace",
		name = "Vayu's Grace",
		desc = "The wind carries you longer. Dodge i-frames last 60% longer.",
		rarity = "rare",
		weight = 5,
		effect = { dodgeBonus = 0.6 },
	},
	-- Mythics: under 1% each, and the weapon itself wears the blessing.
	{
		id = "trinetra",
		name = "Trinetra, the Third Eye",
		desc = "The third eye opens. +10% crit chance, and crits strike for 3x. The weapon burns.",
		rarity = "mythic",
		weight = 0.5,
		effect = { critChanceBonus = 0.10, critMultiplier = 3, aura = "fire", auraColor = { 255, 120, 30 } },
	},
	{
		id = "sudarshana_storm",
		name = "Sudarshana's Storm",
		desc = "Vishnu's discus rides your strikes: 10% chance to call sky-fire for 45 bonus damage. The weapon crackles.",
		rarity = "mythic",
		weight = 0.5,
		effect = { procChance = 0.10, procDamage = 45, aura = "sparkles", auraColor = { 120, 220, 255 } },
	},
} :: { Enchant }

local byId: { [string]: Enchant } = {}
local totalWeight = 0
for _, e in Enchants.List do
	byId[e.id] = e
	totalWeight += e.weight
end

function Enchants.get(id: string): Enchant?
	return byId[id]
end

-- Effects for an id; an unknown/empty id (no mantra yet) has no effects.
local EMPTY: Effect = {}
function Enchants.effects(id: string): Effect
	local e = byId[id]
	if e then
		return e.effect
	end
	return EMPTY
end

-- Weighted roll across the whole pool. `rng` returns [0, 1); injectable for tests.
function Enchants.roll(rng: (() -> number)?): string
	local r: () -> number = rng or function(): number
		return math.random()
	end
	local pick = r() * totalWeight
	local acc = 0
	for _, e in Enchants.List do
		acc += e.weight
		if pick <= acc then
			return e.id
		end
	end
	return Enchants.List[#Enchants.List].id
end

export type InscribeResult = {
	ok: boolean,
	reason: string, -- "ok" | "shards"
	shardsAfter: number,
}

function Enchants.tryInscribe(shards: number): InscribeResult
	if shards < Enchants.Cost then
		return { ok = false, reason = "shards", shardsAfter = shards }
	end
	return { ok = true, reason = "ok", shardsAfter = shards - Enchants.Cost }
end

-- Clamp a persisted shard count.
function Enchants.clampShards(value: any): number
	if type(value) ~= "number" or value ~= value or value < 0 then
		return 0
	end
	return math.min(math.floor(value), 1e6)
end

return Enchants
