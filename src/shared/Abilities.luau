--!strict
-- The Astra kit on Z / X / C / V: configs + cast gating (Tejas cost, cooldown).
-- Pure logic so costs/cooldowns are Lune-tested; the server applies the effects.

local Abilities = {}

export type AbilityConfig = {
	slot: string,
	name: string,
	tejasCost: number,
	cooldown: number, -- seconds
	-- Effect magnitudes (interpreted per-ability by the server).
	power: number,
	radius: number?,
}

Abilities.Config = {
	Z = {
		slot = "Z",
		name = "Agni Astra",
		tejasCost = 35,
		cooldown = 0.8,
		power = 30, -- projectile damage
	},
	X = {
		slot = "X",
		name = "Vayu Dash",
		tejasCost = 20,
		cooldown = 3.0,
		power = 110, -- dash impulse (studs/s)
	},
	C = {
		slot = "C",
		name = "Varuna's Grace",
		tejasCost = 45,
		cooldown = 12.0,
		power = 0.4, -- heal fraction of max health
	},
	V = {
		slot = "V",
		name = "Indra's Wrath",
		tejasCost = 100,
		cooldown = 30.0,
		power = 80, -- lightning damage per enemy struck
		radius = 60, -- studs around the caster
	},
} :: { [string]: AbilityConfig }

-- ---------------------------------------------------------------------------
-- The full Astra catalog (Astra Paths). Every ability is one of six primitives
-- the server knows how to cast; a def is pure data steering that primitive.
-- Paths.kit entries point at these ids; the classic slot Config above mirrors
-- the four originals (a test guards against drift).
-- ---------------------------------------------------------------------------

export type AbilityDef = {
	id: string,
	name: string,
	kind: string, -- "projectile" | "dash" | "heal" | "ward" | "nova" | "smite"
	line: string, -- short description for pickers/tooltips
	tejasCost: number,
	cooldown: number,
	power: number, -- damage / impulse / heal fraction / ward multiplier (per kind)
	color: { number }, -- {r, g, b}
	radius: number?, -- nova / smite reach (studs)
	speed: number?, -- projectile studs/s
	iFrames: number?, -- dash i-frame seconds
	duration: number?, -- ward seconds
	knockback: number?, -- nova outward shove (studs/s)
	cleanse: boolean?, -- heal also clears venom + curse
	selfHeal: number?, -- smite heals the caster this fraction of max HP
	flame: boolean?, -- projectile/dash carries a fire visual
	wardKind: string?, -- "shield" (damage taken x power) | "empower" (damage dealt x power)
}

Abilities.Catalog = {
	-- Projectiles (Z).
	agni_astra = { id = "agni_astra", name = "Agni Astra", kind = "projectile", line = "A searing fire-bolt.", tejasCost = 35, cooldown = 0.8, power = 30, speed = 90, flame = true, color = { 255, 120, 30 } },
	vayu_blade = { id = "vayu_blade", name = "Vayu Blade", kind = "projectile", line = "A blistering-fast crescent of wind.", tejasCost = 30, cooldown = 0.7, power = 24, speed = 130, color = { 210, 240, 255 } },
	tide_lash = { id = "tide_lash", name = "Tide Lash", kind = "projectile", line = "A whip-crack of crushing water.", tejasCost = 32, cooldown = 0.8, power = 26, speed = 95, color = { 80, 170, 255 } },
	vajra_bolt = { id = "vajra_bolt", name = "Vajra Bolt", kind = "projectile", line = "A spear of raw lightning.", tejasCost = 33, cooldown = 0.75, power = 28, speed = 110, color = { 180, 220, 255 } },
	-- Dashes (X).
	vayu_dash = { id = "vayu_dash", name = "Vayu Dash", kind = "dash", line = "A wind-step with brief i-frames.", tejasCost = 20, cooldown = 3.0, power = 110, iFrames = 0.5, color = { 210, 240, 255 } },
	ember_rush = { id = "ember_rush", name = "Ember Rush", kind = "dash", line = "A burning lunge that carries flame.", tejasCost = 22, cooldown = 3.2, power = 115, iFrames = 0.45, flame = true, color = { 255, 120, 30 } },
	gale_step = { id = "gale_step", name = "Gale Step", kind = "dash", line = "The longest step, the longest i-frames.", tejasCost = 18, cooldown = 2.4, power = 140, iFrames = 0.7, color = { 210, 240, 255 } },
	undertow = { id = "undertow", name = "Undertow", kind = "dash", line = "Slip away like the receding tide.", tejasCost = 20, cooldown = 3.0, power = 110, iFrames = 0.55, color = { 80, 170, 255 } },
	thunderstep = { id = "thunderstep", name = "Thunderstep", kind = "dash", line = "Arrive with a crack of static.", tejasCost = 20, cooldown = 2.8, power = 120, iFrames = 0.5, color = { 180, 220, 255 } },
	-- Heals + wards (C).
	varuna_grace = { id = "varuna_grace", name = "Varuna's Grace", kind = "heal", line = "Mend 40% of your health.", tejasCost = 45, cooldown = 12.0, power = 0.4, color = { 80, 170, 255 } },
	deep_mending = { id = "deep_mending", name = "Deep Mending", kind = "heal", line = "Mend 45% and wash away venom and curses.", tejasCost = 45, cooldown = 12.0, power = 0.45, cleanse = true, color = { 80, 170, 255 } },
	zephyr_veil = { id = "zephyr_veil", name = "Zephyr Veil", kind = "ward", line = "Winds soak half of all damage for 4s.", tejasCost = 40, cooldown = 14.0, power = 0.5, duration = 4, wardKind = "shield", color = { 210, 240, 255 } },
	static_ward = { id = "static_ward", name = "Static Ward", kind = "ward", line = "Storm-charge: +25% damage dealt for 5s.", tejasCost = 40, cooldown = 16.0, power = 1.25, duration = 5, wardKind = "empower", color = { 180, 220, 255 } },
	pyre_nova = { id = "pyre_nova", name = "Pyre Nova", kind = "nova", line = "Detonate the air around you.", tejasCost = 45, cooldown = 9.0, power = 45, radius = 14, knockback = 40, flame = true, color = { 255, 120, 30 } },
	-- Ultimates (V) — all cost a full Tejas bar.
	indra_wrath = { id = "indra_wrath", name = "Indra's Wrath", kind = "smite", line = "Lightning falls on every foe near you.", tejasCost = 100, cooldown = 30.0, power = 80, radius = 60, color = { 180, 220, 255 } },
	pralaya_flame = { id = "pralaya_flame", name = "Pralaya Flame", kind = "nova", line = "The dissolution fire, unleashed.", tejasCost = 100, cooldown = 30.0, power = 95, radius = 28, knockback = 55, flame = true, color = { 255, 120, 30 } },
	tempest = { id = "tempest", name = "Tempest", kind = "nova", line = "A hurricane burst that hurls foes away.", tejasCost = 100, cooldown = 28.0, power = 70, radius = 24, knockback = 85, color = { 210, 240, 255 } },
	the_deluge = { id = "the_deluge", name = "The Deluge", kind = "smite", line = "Drowning rain crushes all foes and mends you.", tejasCost = 100, cooldown = 30.0, power = 65, radius = 50, selfHeal = 0.2, color = { 80, 170, 255 } },
} :: { [string]: AbilityDef }

export type CastCheck = {
	ok: boolean,
	reason: string, -- "ok" | "unknown" | "cooldown" | "tejas"
	-- Tejas remaining after the cast (unchanged when not ok).
	tejasAfter: number,
}

local function gate(tejasCost: number, cooldown: number, tejas: number, lastUsedAt: number, now: number): CastCheck
	if now - lastUsedAt < cooldown then
		return { ok = false, reason = "cooldown", tejasAfter = tejas }
	end
	if tejas < tejasCost then
		return { ok = false, reason = "tejas", tejasAfter = tejas }
	end
	return { ok = true, reason = "ok", tejasAfter = tejas - tejasCost }
end

-- Gate a cast: does the slot exist, is it off cooldown, can the caster afford it?
function Abilities.tryCast(slot: string, tejas: number, lastUsedAt: number, now: number): CastCheck
	local cfg = Abilities.Config[slot]
	if not cfg then
		return { ok = false, reason = "unknown", tejasAfter = tejas }
	end
	return gate(cfg.tejasCost, cfg.cooldown, tejas, lastUsedAt, now)
end

-- Same gate, keyed by catalog ability id (the Astra Paths dispatch).
-- `cooldownMult` lets mastery siddhis shorten cooldowns (default 1).
function Abilities.tryCastAbility(abilityId: string, tejas: number, lastUsedAt: number, now: number, cooldownMult: number?): CastCheck
	local def = Abilities.Catalog[abilityId]
	if not def then
		return { ok = false, reason = "unknown", tejasAfter = tejas }
	end
	return gate(def.tejasCost, def.cooldown * (cooldownMult or 1), tejas, lastUsedAt, now)
end

return Abilities
