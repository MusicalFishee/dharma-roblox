--!strict
-- Affixes: marked foes beyond the elites. From wave 10, ordinary spawns may
-- carry one — SHIELDED (the first blows clink off a fading ward; Astra
-- reactions pierce it), TWINNED (splits into two lesser copies on death —
-- bonus bounty, never wave-blocking), or VENGEFUL (enrages when a nearby
-- ally falls). Never on bosses; may stack with elite (a shielded elite is
-- a PROBLEM, and that's the point).
-- Pure defs + roll + tag (Lune-tested); EnemyService runs the behaviors.

local Affixes = {}

Affixes.Config = {
	Chance = 0.08,
	MinWave = 10,
}

export type AffixDef = {
	id: string,
	name: string, -- worn as a nameplate prefix
	line: string,
	shieldCharges: number?, -- shielded only
	enrageDamageMult: number?, -- vengeful only
	enrageSpeedMult: number?,
	glow: { number }, -- highlight color
}

Affixes.Defs = {
	shielded = {
		id = "shielded",
		name = "Shielded",
		line = "The first blows clink off the ward.",
		shieldCharges = 4,
		glow = { 90, 160, 255 },
	},
	twinned = {
		id = "twinned",
		name = "Twinned",
		line = "Cut one down, face two more.",
		glow = { 200, 110, 255 },
	},
	vengeful = {
		id = "vengeful",
		name = "Vengeful",
		line = "It watches its kin fall — and remembers.",
		enrageDamageMult = 1.4,
		enrageSpeedMult = 1.25,
		glow = { 235, 70, 60 },
	},
} :: { [string]: AffixDef }

Affixes.Order = { "shielded", "twinned", "vengeful" }

function Affixes.get(id: string): AffixDef?
	return Affixes.Defs[id]
end

-- Roll an affix for a spawn. Bosses never carry one; early waves are clean.
function Affixes.roll(wave: number, isBoss: boolean, rng: (() -> number)?): string?
	if isBoss or wave < Affixes.Config.MinWave then
		return nil
	end
	local function roll(): number
		if rng then
			return rng()
		end
		return math.random()
	end
	if roll() >= Affixes.Config.Chance then
		return nil
	end
	local index = math.clamp(math.floor(roll() * #Affixes.Order) + 1, 1, #Affixes.Order)
	return Affixes.Order[index]
end

-- An immutable copy carrying the mark (stats untouched — behavior is the affix).
function Affixes.tag(archetype: any, affixId: string): any
	local out = table.clone(archetype)
	out.affix = affixId
	return out
end

-- The lesser copies a twinned foe splits into: half the health, a third the
-- bounty, slightly smaller, never affixed themselves, never wave-blocking.
function Affixes.twinOf(archetype: any): any
	local out = table.clone(archetype)
	out.affix = nil
	out.isTwinChild = true
	out.maxHealth = math.max(1, math.floor(archetype.maxHealth / 2))
	out.xpReward = math.max(1, math.floor(archetype.xpReward / 3))
	out.scale = archetype.scale * 0.8
	return out
end

return Affixes
