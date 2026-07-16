--!strict
-- Astra Paths: swear yourself to one deva and wield their full kit.
-- Pure data + choose/respec gating (colors as {r,g,b}) so it's Lune-tested;
-- PathService applies the effects. Shared modules never require each other:
-- kit entries are ability IDs, and a test cross-checks them against Abilities.Catalog.

local Paths = {}

Paths.RespecCost = 2500 -- gold, to walk a different path after swearing the first oath

export type Passive = {
	damageMult: number, -- all damage dealt
	healthBonus: number, -- flat max HP
	speedMult: number, -- WalkSpeed multiplier
	tejasMult: number, -- Tejas gain multiplier
	dodgeBonusSeconds: number, -- added to the dodge i-frame window
}

export type PathDef = {
	id: string,
	name: string,
	epithet: string,
	description: string,
	passiveLine: string,
	color: { number }, -- {r, g, b}
	kit: { Z: string, X: string, C: string, V: string }, -- ability ids
	passive: Passive,
}

local NEUTRAL: Passive = {
	damageMult = 1,
	healthBonus = 0,
	speedMult = 1,
	tejasMult = 1,
	dodgeBonusSeconds = 0,
}

Paths.Defs = {
	agni = {
		id = "agni",
		name = "Path of Agni",
		epithet = "The Immolant",
		description = "The fire that ends ages. Every answer is more flame.",
		passiveLine = "+10% to all damage you deal",
		color = { 255, 120, 30 },
		kit = { Z = "agni_astra", X = "ember_rush", C = "pyre_nova", V = "pralaya_flame" },
		passive = { damageMult = 1.10, healthBonus = 0, speedMult = 1, tejasMult = 1, dodgeBonusSeconds = 0 },
	},
	vayu = {
		id = "vayu",
		name = "Path of Vayu",
		epithet = "The Untouchable",
		description = "The wind cannot be struck. Move, cut, vanish.",
		passiveLine = "+12% move speed, longer dodge windows",
		color = { 210, 240, 255 },
		kit = { Z = "vayu_blade", X = "gale_step", C = "zephyr_veil", V = "tempest" },
		passive = { damageMult = 1, healthBonus = 0, speedMult = 1.12, tejasMult = 1, dodgeBonusSeconds = 0.10 },
	},
	varuna = {
		id = "varuna",
		name = "Path of Varuna",
		epithet = "The Deep's Warden",
		description = "The ocean outlasts every fire. Endure, mend, hold the line.",
		passiveLine = "+30 max health",
		color = { 80, 170, 255 },
		kit = { Z = "tide_lash", X = "undertow", C = "deep_mending", V = "the_deluge" },
		passive = { damageMult = 1, healthBonus = 30, speedMult = 1, tejasMult = 1, dodgeBonusSeconds = 0 },
	},
	indra = {
		id = "indra",
		name = "Path of Indra",
		epithet = "The Stormcaller",
		description = "The storm always has more to give. Cycle your Astras without end.",
		passiveLine = "+30% Tejas gain",
		color = { 180, 220, 255 },
		kit = { Z = "vajra_bolt", X = "thunderstep", C = "static_ward", V = "indra_wrath" },
		passive = { damageMult = 1, healthBonus = 0, speedMult = 1, tejasMult = 1.30, dodgeBonusSeconds = 0 },
	},
} :: { [string]: PathDef }

-- Deterministic display order (table iteration order isn't).
Paths.Order = { "agni", "vayu", "varuna", "indra" }

-- The unsworn kit: one spark from each deva (the classic Z/X/C/V mix).
Paths.DefaultKit = { Z = "agni_astra", X = "vayu_dash", C = "varuna_grace", V = "indra_wrath" }

function Paths.get(id: string): PathDef?
	return Paths.Defs[id]
end

function Paths.isValid(id: string): boolean
	return Paths.Defs[id] ~= nil
end

-- The slot->ability mapping for a player; unsworn (or corrupt) ids get the classic mix.
function Paths.kitFor(id: string): { Z: string, X: string, C: string, V: string }
	local def = Paths.Defs[id]
	return if def then def.kit else Paths.DefaultKit
end

-- The passive for a player; unsworn (or corrupt) ids are neutral.
function Paths.passiveOf(id: string): Passive
	local def = Paths.Defs[id]
	return if def then def.passive else NEUTRAL
end

export type ChooseCheck = {
	ok: boolean,
	reason: string, -- "ok" | "unknown" | "same" | "gold"
	-- Gold remaining after the choice (unchanged when not ok; first oath is free).
	goldAfter: number,
}

-- Gate a choose/respec: the first oath is free; changing paths costs gold.
function Paths.tryChoose(currentPath: string, targetId: string, gold: number): ChooseCheck
	if not Paths.Defs[targetId] then
		return { ok = false, reason = "unknown", goldAfter = gold }
	end
	if currentPath == targetId then
		return { ok = false, reason = "same", goldAfter = gold }
	end
	if currentPath == "" then
		return { ok = true, reason = "ok", goldAfter = gold }
	end
	if gold < Paths.RespecCost then
		return { ok = false, reason = "gold", goldAfter = gold }
	end
	return { ok = true, reason = "ok", goldAfter = gold - Paths.RespecCost }
end

return Paths
