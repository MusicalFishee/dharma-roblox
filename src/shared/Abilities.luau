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

export type CastCheck = {
	ok: boolean,
	reason: string, -- "ok" | "unknown" | "cooldown" | "tejas"
	-- Tejas remaining after the cast (unchanged when not ok).
	tejasAfter: number,
}

-- Gate a cast: does the slot exist, is it off cooldown, can the caster afford it?
function Abilities.tryCast(slot: string, tejas: number, lastUsedAt: number, now: number): CastCheck
	local cfg = Abilities.Config[slot]
	if not cfg then
		return { ok = false, reason = "unknown", tejasAfter = tejas }
	end
	if now - lastUsedAt < cfg.cooldown then
		return { ok = false, reason = "cooldown", tejasAfter = tejas }
	end
	if tejas < cfg.tejasCost then
		return { ok = false, reason = "tejas", tejasAfter = tejas }
	end
	return { ok = true, reason = "ok", tejasAfter = tejas - cfg.tejasCost }
end

return Abilities
