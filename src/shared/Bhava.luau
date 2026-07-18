--!strict
-- Bhava: fighting stances. Four postures — the balance and three trades.
-- EVERY stance pays for what it grants (no posture dominates, by tested
-- law). Session tactics, not persistence: you choose a posture for the
-- fight, not for your save. Pure defs + cycle math; BhavaService wears it,
-- and the damage/tejas chains read it.

local Bhava = {}

export type Effects = {
	damageMult: number,
	damageTakenMult: number,
	tejasMult: number,
}

export type StanceDef = {
	id: string,
	name: string,
	line: string,
	glyph: string,
	color: { number },
	effects: Effects,
}

local function stance(def: StanceDef): StanceDef
	return def
end

Bhava.Defs = {
	sama = stance({ id = "sama", name = "Sama", line = "Balance. Nothing given, nothing owed.", glyph = "◈", color = { 200, 200, 210 }, effects = { damageMult = 1, damageTakenMult = 1, tejasMult = 1 } }),
	raudra = stance({ id = "raudra", name = "Raudra", line = "Fury. Strike harder; bleed harder.", glyph = "🔥", color = { 235, 90, 70 }, effects = { damageMult = 1.2, damageTakenMult = 1.2, tejasMult = 1 } }),
	sthira = stance({ id = "sthira", name = "Sthira", line = "Stone. Endure more; give less.", glyph = "🛡", color = { 150, 170, 200 }, effects = { damageMult = 0.85, damageTakenMult = 0.8, tejasMult = 1 } }),
	pravaha = stance({ id = "pravaha", name = "Pravaha", line = "Flow. Tejas floods; the skin thins.", glyph = "🌊", color = { 110, 200, 255 }, effects = { damageMult = 1, damageTakenMult = 1.1, tejasMult = 1.3 } }),
} :: { [string]: StanceDef }

Bhava.Order = { "sama", "raudra", "sthira", "pravaha" }

function Bhava.get(id: string): StanceDef
	return Bhava.Defs[id] or Bhava.Defs.sama
end

function Bhava.effectsOf(id: string): Effects
	return Bhava.get(id).effects
end

-- The wheel of postures: cycle in order, wrapping; the unknown returns home.
function Bhava.next(id: string): string
	for i, current in Bhava.Order do
		if current == id then
			return Bhava.Order[(i % #Bhava.Order) + 1]
		end
	end
	return "sama"
end

return Bhava
