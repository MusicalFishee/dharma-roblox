--!strict
-- Tirthas: the sacred fords. One shrine stone rises somewhere in the arena
-- on every ordinary wave, and its blessing wears the REALM's face — the
-- ashram teaches, the forest cleanses, the deep wards, the heights empower,
-- the shining world pays. One touch per pilgrim per wave; the stone sinks
-- when the wave breaks. Pure per-zone catalog (Lune-tested); TirthaService
-- raises the stones.

local Tirtha = {}

export type TirthaDef = {
	zoneId: string,
	name: string,
	line: string,
	kind: string, -- "tejas" | "ward" | "empower" | "cleanse" | "gold"
	amount: number, -- tejas points, ward/empower mult, or gold
	seconds: number, -- for timed kinds; 0 otherwise
}

local function tirtha(def: TirthaDef): TirthaDef
	return def
end

-- Every zone keeps a ford — even the sanctuary. Kindness is a teaching too.
Tirtha.Defs = {
	ashram = tirtha({ zoneId = "ashram", name = "The Guru's Word", line = "A breath of the first teaching.", kind = "tejas", amount = 30, seconds = 0 }),
	dandakaranya = tirtha({ zoneId = "dandakaranya", name = "The Clean Spring", line = "The forest's one honest water.", kind = "cleanse", amount = 0, seconds = 0 }),
	sagara = tirtha({ zoneId = "sagara", name = "The Drowned Bell", line = "Its ring turns blades aside.", kind = "ward", amount = 0.85, seconds = 40 }),
	himavat = tirtha({ zoneId = "himavat", name = "The White Flame", line = "Cold that sharpens instead of slows.", kind = "empower", amount = 1.1, seconds = 40 }),
	pilgrim_stair = tirtha({ zoneId = "pilgrim_stair", name = "The Pilgrims' Alms", line = "Those who climbed before you left this.", kind = "gold", amount = 150, seconds = 0 }),
	meghaloka = tirtha({ zoneId = "meghaloka", name = "The Storm-Wind Stone", line = "Indra's breath in your arm.", kind = "empower", amount = 1.15, seconds = 30 }),
	svarga = tirtha({ zoneId = "svarga", name = "The Golden Tithe", line = "Heaven tips its walkers.", kind = "gold", amount = 250, seconds = 0 }),
	kailasa = tirtha({ zoneId = "kailasa", name = "The Mountain's Breath", line = "Given back, for once.", kind = "tejas", amount = 60, seconds = 0 }),
} :: { [string]: TirthaDef }

Tirtha.ValidKinds = { tejas = true, ward = true, empower = true, cleanse = true, gold = true }

function Tirtha.forZone(zoneId: string): TirthaDef?
	return Tirtha.Defs[zoneId]
end

return Tirtha
