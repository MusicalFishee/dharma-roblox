--!strict
-- Elite enemies: randomly empowered variants — tougher, meaner, worth far more.
-- Pure + dependency-free (rng injectable, structural archetype type so it works on
-- anything EnemyTypes-shaped); EnemyService adds the golden glow.

local Elites = {}

Elites.Chance = 0.12
Elites.HealthMult = 2.2
Elites.DamageMult = 1.6
Elites.XpMult = 2.5
Elites.ScaleMult = 1.12
Elites.SpeedBonus = 1.5

-- Structurally identical to EnemyTypes.EnemyArchetype (kept require-free for Lune).
export type Archetype = {
	id: string,
	displayName: string,
	maxHealth: number,
	walkSpeed: number,
	attackDamage: number,
	attackInterval: number,
	aggroRange: number,
	attackRange: number,
	xpReward: number,
	scale: number,
	skin: { number },
	weight: number,
	isBoss: boolean?,
	title: string?,
	isElite: boolean?,
}

-- Does this spawn roll elite? `rng` returns [0,1) (injectable for tests).
function Elites.roll(rng: (() -> number)?): boolean
	local r: () -> number = rng or function(): number
		return math.random()
	end
	return r() < Elites.Chance
end

-- Returns an empowered COPY of the archetype (the original is never mutated).
function Elites.makeElite(base: Archetype): Archetype
	return {
		id = base.id,
		displayName = "Elite " .. base.displayName,
		maxHealth = math.floor(base.maxHealth * Elites.HealthMult),
		walkSpeed = base.walkSpeed + Elites.SpeedBonus,
		attackDamage = math.floor(base.attackDamage * Elites.DamageMult),
		attackInterval = base.attackInterval,
		aggroRange = base.aggroRange,
		attackRange = base.attackRange,
		xpReward = math.floor(base.xpReward * Elites.XpMult),
		scale = base.scale * Elites.ScaleMult,
		skin = base.skin,
		weight = base.weight,
		isBoss = false,
		isElite = true,
	}
end

return Elites
