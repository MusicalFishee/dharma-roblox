--!strict
-- Zone hazards: past the ashram, the WORLD itself joins the fight. Each realm
-- throws its own telegraphed burst on ordinary waves — roots, geysers,
-- avalanches, stray bolts — always announced, always dodgeable, never on the
-- spectacle nights (boss / trial / raid keep their own stage).
-- Pure data + math (Lune-tested); HazardService throws them.

local Hazards = {}

export type HazardDef = {
	id: string,
	zoneId: string,
	name: string,
	line: string,
	telegraph: number, -- seconds of warning — readable by law
	radius: number,
	damage: number, -- base; scales gently with depth past the zone's gate
	count: number, -- blast points per burst
	intervalMin: number, -- seconds between bursts
	intervalMax: number,
}

local function hazard(def: HazardDef): HazardDef
	return def
end

-- The ashram has NO entry: the training grounds are sanctuary, by law.
Hazards.Defs = {
	dandakaranya = hazard({ id = "roots", zoneId = "dandakaranya", name = "Grasping Roots", line = "The haunted forest claws at the living.", telegraph = 2.0, radius = 7, damage = 18, count = 2, intervalMin = 22, intervalMax = 34 }),
	sagara = hazard({ id = "geyser", zoneId = "sagara", name = "Drowning Geyser", line = "The deep exhales.", telegraph = 2.0, radius = 8, damage = 24, count = 2, intervalMin = 22, intervalMax = 34 }),
	himavat = hazard({ id = "avalanche", zoneId = "himavat", name = "Avalanche", line = "The roof of the world sheds its snow.", telegraph = 2.2, radius = 9, damage = 32, count = 3, intervalMin = 20, intervalMax = 32 }),
	pilgrim_stair = hazard({ id = "rockfall", zoneId = "pilgrim_stair", name = "Rockfall of the Stair", line = "The mountain tests every pilgrim.", telegraph = 1.8, radius = 8, damage = 40, count = 3, intervalMin = 20, intervalMax = 32 }),
	meghaloka = hazard({ id = "stray_bolt", zoneId = "meghaloka", name = "Indra's Stray Bolt", line = "The storm-king's aim wanders.", telegraph = 1.6, radius = 7, damage = 55, count = 2, intervalMin = 18, intervalMax = 30 }),
	svarga = hazard({ id = "sun_shard", zoneId = "svarga", name = "Sun-Shard", line = "Even the shining world burns.", telegraph = 1.8, radius = 9, damage = 62, count = 3, intervalMin = 18, intervalMax = 30 }),
	kailasa = hazard({ id = "mountain_breath", zoneId = "kailasa", name = "The Mountain's Breath", line = "Kailasa suffers no careless step.", telegraph = 2.0, radius = 10, damage = 75, count = 4, intervalMin = 16, intervalMax = 28 }),
} :: { [string]: HazardDef }

function Hazards.forZone(zoneId: string): HazardDef?
	return Hazards.Defs[zoneId]
end

-- Where in [intervalMin, intervalMax] this pause lands (r in [0, 1)).
function Hazards.rollInterval(def: HazardDef, r: number): number
	return def.intervalMin + r * (def.intervalMax - def.intervalMin)
end

-- Depth past the zone's gate sharpens the hazard — gently, and never past 2×.
function Hazards.scaledDamage(def: HazardDef, wavesDeep: number): number
	return math.floor(def.damage * math.min(1 + math.max(wavesDeep, 0) * 0.01, 2))
end

return Hazards
