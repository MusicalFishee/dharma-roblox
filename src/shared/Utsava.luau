--!strict
-- Utsava ("festival"): rare mid-wave world events that make runs tell stories.
-- A golden deer bolts across the field (Maricha's old trick — rich bounty if
-- felled before it fades), a Vajra storm rains shard orbs, or a wandering
-- vaidya sets up his mat and trades shards for gold. Events never crash a
-- boss/trial/raid wave — those nights belong to the spectacle.
-- Pure defs + roll gating (Lune-tested); UtsavaService runs the live events.

local Utsava = {}

Utsava.Config = {
	Chance = 0.18, -- roll at the start of an eligible wave
	MinWave = 3, -- let new players learn the basics first
	MinGap = 3, -- waves between events (no clustering)
}

export type EventDef = {
	id: string,
	name: string,
	announce: string,
	duration: number, -- seconds the event lives
	weight: number,
}

Utsava.Events = {
	golden_deer = {
		id = "golden_deer",
		name = "The Golden Deer",
		announce = "A golden deer bolts across the field — bring it down before it fades!",
		duration = 25,
		weight = 45,
	},
	shard_storm = {
		id = "shard_storm",
		name = "Vajra Storm",
		announce = "The sky cracks — Vajra Shards rain down! Claim them!",
		duration = 30,
		weight = 30,
	},
	merchant = {
		id = "merchant",
		name = "The Wandering Vaidya",
		announce = "A wandering vaidya unrolls his mat at the field's edge…",
		duration = 40,
		weight = 25,
	},
} :: { [string]: EventDef }

-- Deterministic order for weighted picks (table iteration order isn't).
Utsava.Order = { "golden_deer", "shard_storm", "merchant" }

-- The golden deer: flees, never fights, pays a bounty to its slayer.
Utsava.Deer = {
	health = 120,
	walkSpeed = 22,
	gold = 400,
	xp = 250,
	shards = 1,
}

-- The Vajra storm: orbs fall on a beat; each is one shard, first-touch.
Utsava.Storm = {
	orbCount = 10,
	interval = 3,
	shardsPerOrb = 1,
}

-- The vaidya's one deal: shards for gold, once per player per visit.
Utsava.Merchant = {
	shards = 3,
	price = 900,
}

-- Roll for an event at wave start. Special waves (boss/trial/raid) never roll;
-- rng defaults to math.random. Returns the chosen event, or nil.
function Utsava.roll(wave: number, lastEventWave: number, isSpecialWave: boolean, rng: (() -> number)?): EventDef?
	if isSpecialWave or wave < Utsava.Config.MinWave or wave - lastEventWave < Utsava.Config.MinGap then
		return nil
	end
	local function roll(): number
		if rng then
			return rng()
		end
		return math.random()
	end
	if roll() >= Utsava.Config.Chance then
		return nil
	end

	local totalWeight = 0
	for _, id in Utsava.Order do
		totalWeight += Utsava.Events[id].weight
	end
	local r = roll() * totalWeight
	for _, id in Utsava.Order do
		local def = Utsava.Events[id]
		if r < def.weight then
			return def
		end
		r -= def.weight
	end
	return Utsava.Events[Utsava.Order[#Utsava.Order]]
end

return Utsava
