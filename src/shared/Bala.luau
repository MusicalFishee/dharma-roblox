--!strict
-- Bala: the strength of the sangha. When warriors fight shoulder to shoulder,
-- a shared meter fills — and at its brim it breaks into a SANGHA RALLY: every
-- ally cleansed of affliction, healed, and flooded with Tejas. It is purely a
-- gift of support (no damage multiplier), so it never touches the Stack Law —
-- the reward for fighting together is endurance, not raw force. A lone warrior
-- never fills it; the bond is the whole point. Pure meter math (Lune-tested);
-- BalaService tends the cluster and fires the rally.

local Bala = {}

Bala.Config = {
	Max = 100,
	FillPerAllyTick = 6, -- per extra ally in the cluster, each tick
	MaxAllyFactor = 3, -- fill is capped as if the cluster were this many deep
	TickSeconds = 2,
	Radius = 40, -- studs: how close is "shoulder to shoulder"
	MinCluster = 2, -- it takes two to make a sangha
	RallyHealFraction = 0.4, -- of max health, restored to each ally
	RallyTejas = 60,
}

function Bala.add(current: number, amount: number): number
	return math.clamp(current + amount, 0, Bala.Config.Max)
end

function Bala.isFull(current: number): boolean
	return current >= Bala.Config.Max
end

-- How much the meter gains this tick for a cluster of `size` fighters. A lone
-- fighter (below the minimum) gains nothing; deeper clusters gain more, capped.
function Bala.fillFor(clusterSize: number): number
	if clusterSize < Bala.Config.MinCluster then
		return 0
	end
	local extra = math.min(clusterSize - 1, Bala.Config.MaxAllyFactor)
	return Bala.Config.FillPerAllyTick * extra
end

-- The fraction filled, for the meter bar [0, 1].
function Bala.fraction(current: number): number
	return math.clamp(current / Bala.Config.Max, 0, 1)
end

return Bala
