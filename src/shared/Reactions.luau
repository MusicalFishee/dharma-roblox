--!strict
-- Astra Reactions: every Astra carries its deva's element — fire, wind, water,
-- storm. A damaging Astra MARKS its victim for a few seconds; strike a marked
-- foe with a DIFFERENT element and the two react. Six reactions cover every
-- pair. Marks live on the enemy, so two players can combo each other's casts —
-- "you soak, I shock" is now a real strategy.
-- Pure element map + pair table + gating (Lune-tested); AbilityService applies.

local Reactions = {}

Reactions.Window = 6 -- seconds a mark clings before it fades

-- Which element each catalog ability carries (kits are mono-element per path;
-- a test enforces both that and full coverage of every damaging ability).
Reactions.ElementOf = {
	-- Agni: fire
	agni_astra = "fire",
	ember_rush = "fire",
	pyre_nova = "fire",
	pralaya_flame = "fire",
	-- Vayu: wind
	vayu_blade = "wind",
	vayu_dash = "wind",
	gale_step = "wind",
	zephyr_veil = "wind",
	tempest = "wind",
	-- Varuna: water
	tide_lash = "water",
	undertow = "water",
	varuna_grace = "water",
	deep_mending = "water",
	the_deluge = "water",
	-- Indra: storm
	vajra_bolt = "storm",
	thunderstep = "storm",
	static_ward = "storm",
	indra_wrath = "storm",
} :: { [string]: string }

export type ReactionDef = {
	id: string,
	name: string,
	bonusDamage: number,
	-- One flourish each: "ignite" | "slow" | "none" | "knockback" | "tejas" | "chain"
	flourish: string,
	magnitude: number, -- ignite: total DoT; slow: walkspeed mult; knockback: impulse;
	-- tejas: surge to caster; chain: damage to neighbours; none: 0
}

-- The six pairs, keyed both ways at module load.
local PAIRS: { [string]: ReactionDef } = {}
local function pairUp(a: string, b: string, def: ReactionDef)
	PAIRS[a .. "+" .. b] = def
	PAIRS[b .. "+" .. a] = def
end

pairUp("fire", "wind", { id = "firestorm", name = "FIRESTORM", bonusDamage = 30, flourish = "ignite", magnitude = 40 })
pairUp("fire", "water", { id = "scalding_mist", name = "SCALDING MIST", bonusDamage = 25, flourish = "slow", magnitude = 0.6 })
pairUp("fire", "storm", { id = "conflagration", name = "CONFLAGRATION", bonusDamage = 45, flourish = "none", magnitude = 0 })
pairUp("wind", "water", { id = "monsoon", name = "MONSOON", bonusDamage = 20, flourish = "knockback", magnitude = 70 })
pairUp("wind", "storm", { id = "tempest_charge", name = "TEMPEST CHARGE", bonusDamage = 30, flourish = "tejas", magnitude = 15 })
pairUp("water", "storm", { id = "charged_waters", name = "CHARGED WATERS", bonusDamage = 30, flourish = "chain", magnitude = 15 })

Reactions.Elements = { "fire", "wind", "water", "storm" }

function Reactions.elementOf(abilityId: string): string?
	return Reactions.ElementOf[abilityId]
end

-- The reaction two elements make (order-insensitive; same element makes none).
function Reactions.reactionFor(a: string, b: string): ReactionDef?
	if a == b then
		return nil
	end
	return PAIRS[a .. "+" .. b]
end

-- Gate a strike on a marked foe: the mark must be live and the element new.
function Reactions.tryReact(markElement: string, markExpiresAt: number, now: number, incoming: string): ReactionDef?
	if now > markExpiresAt then
		return nil
	end
	return Reactions.reactionFor(markElement, incoming)
end

return Reactions
