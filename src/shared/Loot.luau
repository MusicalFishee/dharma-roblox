--!strict
-- Loot rolls: how much gold an enemy drops, and the chance of a healing Amrit orb.
-- Pure logic (rng injectable) so drop rates are Lune-tested, not vibes.

local Loot = {}

-- Chance that a kill also drops an Amrit orb (heals on pickup).
Loot.AmritChance = 0.12
Loot.AmritHeal = 30

-- Gold scales off the enemy's XP reward (tougher = richer), bosses pay a premium.
-- `rng` returns [0, 1); injectable for deterministic tests.
function Loot.goldFor(xpReward: number, isBoss: boolean, rng: (() -> number)?): number
	local roll: () -> number = rng or function(): number
		return math.random()
	end
	local base = math.max(1, math.floor(xpReward * 0.6))
	-- ±25% variance so drops feel alive.
	local variance = 0.75 + roll() * 0.5
	local gold = base * variance
	if isBoss then
		gold *= 3
	end
	return math.max(1, math.floor(gold))
end

-- Whether this kill also drops an Amrit heal orb.
function Loot.rollAmrit(rng: (() -> number)?): boolean
	local roll: () -> number = rng or function(): number
		return math.random()
	end
	return roll() < Loot.AmritChance
end

-- Clamp for the persisted gold total.
Loot.GoldMax = 1e9

function Loot.clampGold(value: number): number
	if value ~= value or value < 0 then -- NaN or negative
		return 0
	end
	return math.min(math.floor(value), Loot.GoldMax)
end

return Loot
