--!strict
-- The Chakravyuha: the wheel-formation of the Mahabharata, as a wave. On
-- waves ending in 3 the horde arrives COILED — a spiral wound around a
-- Vyuha-Pati, the axis commander. While the axis stands, the bound ranks
-- fight with borrowed fury (harder, faster); break the axis and the whole
-- formation SHATTERS — staggered, calmed, and a bounty paid to every
-- standing fighter. Abhimanyu knew: the way in is through the center.
-- Pure formation math (Lune-tested); WaveService coils it, EnemyService
-- shatters it.

local Chakravyuha = {}

Chakravyuha.Config = {
	FirstWave = 13, -- the horde learns the drill once the war is real
	StaggerSeconds = 4,
	FuryDamageMult = 1.25,
	FurySpeedMult = 1.3,
	AxisHealthMult = 3,
	AxisXpMult = 3,
	SpiralTurns = 2.2,
}

-- Waves ending in 3: never a boss (%5), dosha (7s), trial (5s), or raid (0s)
-- night — the wheel turns only on ordinary ground.
function Chakravyuha.isVyuhaWave(wave: number): boolean
	return wave >= Chakravyuha.Config.FirstWave and wave % 10 == 3
end

export type Spot = { x: number, z: number }

-- Positions along an Archimedean spiral, innermost first: the coil the
-- formation spawns into. Radius grows strictly outward.
function Chakravyuha.spiralPositions(count: number, turns: number, maxRadius: number): { Spot }
	local out: { Spot } = {}
	for i = 1, count do
		local t = i / math.max(count, 1)
		local angle = t * turns * 2 * math.pi
		local radius = 6 + t * math.max(maxRadius - 6, 0)
		table.insert(out, { x = math.cos(angle) * radius, z = math.sin(angle) * radius })
	end
	return out
end

-- A rank bound into the wheel: borrowed fury while the axis stands.
-- Returns a COPY; the roster archetype is never touched.
function Chakravyuha.bindToVyuha(archetype: any): any
	local bound = table.clone(archetype)
	bound.attackDamage = math.floor(archetype.attackDamage * Chakravyuha.Config.FuryDamageMult)
	bound.walkSpeed = archetype.walkSpeed * Chakravyuha.Config.FurySpeedMult
	bound.vyuhaBound = true
	return bound
end

-- The Vyuha-Pati: the axis commander at the wheel's heart. Elite by right.
function Chakravyuha.axisOf(archetype: any): any
	local axis = table.clone(archetype)
	axis.displayName = "Vyuha-Pati " .. tostring(archetype.displayName)
	axis.maxHealth = math.floor(archetype.maxHealth * Chakravyuha.Config.AxisHealthMult)
	axis.xpReward = math.floor(archetype.xpReward * Chakravyuha.Config.AxisXpMult)
	axis.scale = archetype.scale * 1.25
	axis.walkSpeed = archetype.walkSpeed * 0.9
	axis.isElite = true
	return axis
end

-- What breaking the wheel pays every standing fighter.
function Chakravyuha.collapseBounty(wave: number): number
	return 100 + math.max(wave, 1) * 5
end

return Chakravyuha
