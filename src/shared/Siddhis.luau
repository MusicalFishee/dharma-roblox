--!strict
-- Astra Siddhis: mastery earned by USING your path. Every cast feeds mastery XP
-- (equal to the Tejas it burned), and mastery levels unlock siddhis — permanent
-- upgrades to the kit's own abilities. Additive forever: mastery never resets,
-- never rolls back, and each path keeps its own ledger even through a respec.
-- Pure ladder + merge math (Lune-tested); AbilityService feeds and applies it.

local Siddhis = {}

Siddhis.MaxLevel = 10

-- Mastery XP to go FROM `level` to `level + 1`. Early levels come quick.
function Siddhis.xpToNext(level: number): number
	if level < 1 then
		level = 1
	end
	return math.floor(600 * (level ^ 1.4))
end

export type MasteryInfo = {
	level: number,
	xpIntoLevel: number,
	xpForNext: number,
	isMax: boolean,
}

function Siddhis.resolve(masteryXp: number): MasteryInfo
	if masteryXp < 0 then
		masteryXp = 0
	end
	local level = 1
	local remaining = masteryXp
	while level < Siddhis.MaxLevel do
		local need = Siddhis.xpToNext(level)
		if remaining < need then
			break
		end
		remaining -= need
		level += 1
	end
	local isMax = level >= Siddhis.MaxLevel
	return {
		level = level,
		xpIntoLevel = isMax and 0 or remaining,
		xpForNext = isMax and 0 or Siddhis.xpToNext(level),
		isMax = isMax,
	}
end

-- One effect block. Multipliers default 1, flats 0; pierce/fork name an ability.
export type Effect = {
	damageMult: number?, -- ability damage only (melee is the path passive's job)
	radiusMult: number?, -- nova + smite reach
	cooldownMult: number?, -- every kit cooldown
	wardBonusSeconds: number?, -- ward duration
	healBonusFraction: number?, -- added to heal fractions
	selfHealMult: number?, -- smite self-heal
	ultIFrames: number?, -- i-frame seconds granted by the ultimate
	pierceAbility: string?, -- this projectile hits one more enemy
	forkAbility: string?, -- this projectile looses a twin
}

export type SiddhiDef = {
	level: number,
	id: string,
	name: string,
	line: string,
	effect: Effect,
}

local function siddhi(def: SiddhiDef): SiddhiDef
	return def
end

Siddhis.Ladders = {
	agni = {
		siddhi({ level = 2, id = "piercing_flame", name = "Piercing Flame", line = "Agni Astra burns through one more foe.", effect = { pierceAbility = "agni_astra" } }),
		siddhi({ level = 4, id = "hungry_flame", name = "Hungry Flame", line = "+8% Astra damage.", effect = { damageMult = 1.08 } }),
		siddhi({ level = 6, id = "wider_ruin", name = "Wider Ruin", line = "Novas reach 15% further.", effect = { radiusMult = 1.15 } }),
		siddhi({ level = 8, id = "tireless_fire", name = "Tireless Fire", line = "Kit cooldowns fall 15%.", effect = { cooldownMult = 0.85 } }),
		siddhi({ level = 10, id = "pralaya_unbound", name = "Pralaya Unbound", line = "+10% more Astra damage. Everything burns.", effect = { damageMult = 1.10 } }),
	},
	vayu = {
		siddhi({ level = 2, id = "twin_blade", name = "Twin Blade", line = "Vayu Blade looses a second crescent.", effect = { forkAbility = "vayu_blade" } }),
		siddhi({ level = 4, id = "lasting_veil", name = "Lasting Veil", line = "Zephyr Veil holds 1.5s longer.", effect = { wardBonusSeconds = 1.5 } }),
		siddhi({ level = 6, id = "storms_pace", name = "Storm's Pace", line = "Kit cooldowns fall 20%.", effect = { cooldownMult = 0.8 } }),
		siddhi({ level = 8, id = "razor_wind", name = "Razor Wind", line = "+12% Astra damage.", effect = { damageMult = 1.12 } }),
		siddhi({ level = 10, id = "eye_of_tempest", name = "Eye of the Tempest", line = "Tempest leaves you untouchable for 1.5s.", effect = { ultIFrames = 1.5 } }),
	},
	varuna = {
		siddhi({ level = 2, id = "deeper_mending", name = "Deeper Mending", line = "Heals mend 8% more of your health.", effect = { healBonusFraction = 0.08 } }),
		siddhi({ level = 4, id = "tides_reach", name = "Tide's Reach", line = "Tide Lash crashes through one more foe.", effect = { pierceAbility = "tide_lash" } }),
		siddhi({ level = 6, id = "weight_of_water", name = "Weight of Water", line = "+8% Astra damage.", effect = { damageMult = 1.08 } }),
		siddhi({ level = 8, id = "great_wave", name = "The Great Wave", line = "The Deluge reaches 20% further.", effect = { radiusMult = 1.2 } }),
		siddhi({ level = 10, id = "amrita_rain", name = "Amrita Rain", line = "The Deluge mends you twice as deep.", effect = { selfHealMult = 2 } }),
	},
	indra = {
		siddhi({ level = 2, id = "twin_vajra", name = "Twin Vajra", line = "Vajra Bolt looses a second spear.", effect = { forkAbility = "vajra_bolt" } }),
		siddhi({ level = 4, id = "long_charge", name = "Long Charge", line = "Static Ward holds 2s longer.", effect = { wardBonusSeconds = 2 } }),
		siddhi({ level = 6, id = "storm_hunger", name = "Storm Hunger", line = "+10% Astra damage.", effect = { damageMult = 1.10 } }),
		siddhi({ level = 8, id = "wider_wrath", name = "Wider Wrath", line = "Smites reach 20% further.", effect = { radiusMult = 1.2 } }),
		siddhi({ level = 10, id = "endless_storm", name = "Endless Storm", line = "Kit cooldowns fall 20%.", effect = { cooldownMult = 0.8 } }),
	},
} :: { [string]: { SiddhiDef } }

export type Effects = {
	damageMult: number,
	radiusMult: number,
	cooldownMult: number,
	wardBonusSeconds: number,
	healBonusFraction: number,
	selfHealMult: number,
	ultIFrames: number,
	pierce: { [string]: number }, -- ability id -> extra targets
	fork: { [string]: number }, -- ability id -> extra twins
}

-- Everything a path's mastery level has earned, merged into one block.
-- Multipliers multiply, flats add; unknown paths get the identity block.
function Siddhis.effectsFor(pathId: string, level: number): Effects
	local total: Effects = {
		damageMult = 1,
		radiusMult = 1,
		cooldownMult = 1,
		wardBonusSeconds = 0,
		healBonusFraction = 0,
		selfHealMult = 1,
		ultIFrames = 0,
		pierce = {},
		fork = {},
	}
	local ladder = Siddhis.Ladders[pathId]
	if not ladder then
		return total
	end
	for _, def in ladder do
		if level < def.level then
			continue
		end
		local e = def.effect
		total.damageMult *= e.damageMult or 1
		total.radiusMult *= e.radiusMult or 1
		total.cooldownMult *= e.cooldownMult or 1
		total.wardBonusSeconds += e.wardBonusSeconds or 0
		total.healBonusFraction += e.healBonusFraction or 0
		total.selfHealMult *= e.selfHealMult or 1
		total.ultIFrames = math.max(total.ultIFrames, e.ultIFrames or 0)
		if e.pierceAbility then
			total.pierce[e.pierceAbility] = (total.pierce[e.pierceAbility] or 0) + 1
		end
		if e.forkAbility then
			total.fork[e.forkAbility] = (total.fork[e.forkAbility] or 0) + 1
		end
	end
	return total
end

-- The siddhi (if any) that unlocks exactly AT this level — for level-up toasts.
function Siddhis.unlockAt(pathId: string, level: number): SiddhiDef?
	local ladder = Siddhis.Ladders[pathId]
	if not ladder then
		return nil
	end
	for _, def in ladder do
		if def.level == level then
			return def
		end
	end
	return nil
end

-- The next siddhi still ahead of this level — for "what am I chasing" UI.
function Siddhis.nextUnlock(pathId: string, level: number): SiddhiDef?
	local ladder = Siddhis.Ladders[pathId]
	if not ladder then
		return nil
	end
	for _, def in ladder do
		if def.level > level then
			return def
		end
	end
	return nil
end

return Siddhis
