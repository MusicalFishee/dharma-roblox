--!strict
-- Dhyana: the meditation grove. Sit still inside the circle and the grove
-- holds you in the pose; time in stillness pays a trickle — deliberately
-- MONK-SCARCE (a night of dhyana must never out-earn an hour of war), but
-- steady enough to leave a phone burning overnight.
--
-- The Sangha bonus: every OTHER meditator in the grove raises your gold,
-- but ONLY if they are (a) your actual Roblox friend and (b) at least
-- SanghaMinLevel. Both gates together kill the alt farm: a fresh alt costs
-- real hours to qualify, and strangers never count at all.
-- Pure config + multiplier + tick math (Lune-tested); DhyanaService runs it.

local Dhyana = {}

Dhyana.Config = {
	GroveRadius = 12, -- studs from the grove's heart
	EnterStillSeconds = 2, -- stand still this long before the grove takes you
	TickSeconds = 60, -- one breath of dhyana
	GoldPerTick = 5, -- the trickle (scarcity law: test-enforced)
	ShardEveryTicks = 90, -- one Vajra Shard per hour and a half of stillness
	SanghaMinLevel = 15, -- a co-meditator below this level counts for nothing
	SanghaPerFriend = 0.25, -- gold bonus per qualifying friend
	SanghaCap = 1.0, -- at most +100% (four true friends)
}

-- Does a co-meditator's level qualify them to strengthen the sangha?
function Dhyana.qualifies(level: number): boolean
	return level >= Dhyana.Config.SanghaMinLevel
end

-- The gold multiplier for N qualifying friends in the circle.
function Dhyana.multiplierFor(qualifyingFriends: number): number
	local bonus = math.min(Dhyana.Config.SanghaCap, math.max(0, qualifyingFriends) * Dhyana.Config.SanghaPerFriend)
	return 1 + bonus
end

export type Tick = {
	gold: number,
	shards: number,
}

-- What the Nth unbroken tick pays at a given multiplier. The sangha deepens
-- the GOLD only — shards stay scarce no matter how many friends you bring.
function Dhyana.rewardForTick(tickIndex: number, multiplier: number): Tick
	return {
		gold = math.floor(Dhyana.Config.GoldPerTick * multiplier),
		shards = if tickIndex > 0 and tickIndex % Dhyana.Config.ShardEveryTicks == 0 then 1 else 0,
	}
end

return Dhyana
