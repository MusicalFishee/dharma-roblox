--!strict
-- Rahu's Eclipse: the severed head that swallows the sun. A RARE roll on
-- ordinary waves (never the wheel's nights): the sky goes out, every demon
-- in the wave arrives gilded and furious — and everything pays DOUBLE.
-- Terror and greed in one toast. Pure roll/gild math (Lune-tested);
-- WaveService darkens the sky and the zone's next breath restores it.

local Rahu = {}

Rahu.Config = {
	MinWave = 20, -- the sun is safe while you learn
	Chance = 0.07, -- rare by law: an eclipse that happens often is just weather
	DamageMult = 1.2,
	SpeedMult = 1.15,
	RewardMult = 2, -- kill XP and the clear bonus both double
}

Rahu.Lines = {
	begin = "RAHU SWALLOWS THE SUN",
	detail = "The horde is gilded — all spoils doubled while the sky is his.",
}

-- Does the shadow fall on this wave? `r` in [0, 1).
function Rahu.rolls(wave: number, r: number): boolean
	return wave >= Rahu.Config.MinWave and r < Rahu.Config.Chance
end

-- A demon gilded by the eclipse: crueler, faster, worth double.
-- Returns a COPY; the roster is never touched.
function Rahu.gild(archetype: any): any
	local gilded = table.clone(archetype)
	gilded.attackDamage = math.floor(archetype.attackDamage * Rahu.Config.DamageMult)
	gilded.walkSpeed = archetype.walkSpeed * Rahu.Config.SpeedMult
	gilded.xpReward = math.floor(archetype.xpReward * Rahu.Config.RewardMult)
	gilded.rahuGilded = true
	return gilded
end

return Rahu
