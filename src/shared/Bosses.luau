--!strict
-- Boss roster — legendary asura lords. Each boss wave cycles the roster and scales
-- the boss up. Pure/self-contained so it's Lune-testable; returns an EnemyArchetype-
-- shaped table (with isBoss/title) that EnemyService can spawn directly.

local Bosses = {}

export type Boss = {
	id: string,
	displayName: string,
	title: string,
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
	isBoss: boolean,
}

local ROSTER = {
	{
		id = "Mahishasura",
		displayName = "Mahishasura",
		title = "the Buffalo Demon",
		maxHealth = 1200,
		walkSpeed = 9,
		attackDamage = 26,
		attackInterval = 2.0,
		aggroRange = 220,
		attackRange = 14,
		xpReward = 500,
		scale = 2.2,
		skin = { 90, 22, 22 },
	},
	{
		id = "Tarakasura",
		displayName = "Tarakasura",
		title = "the Unconquered",
		maxHealth = 1500,
		walkSpeed = 12,
		attackDamage = 30,
		attackInterval = 1.7,
		aggroRange = 240,
		attackRange = 13,
		xpReward = 650,
		scale = 2.3,
		skin = { 44, 30, 78 },
	},
	{
		id = "Kumbhakarna",
		displayName = "Kumbhakarna",
		title = "the Devourer",
		maxHealth = 2000,
		walkSpeed = 7,
		attackDamage = 40,
		attackInterval = 2.6,
		aggroRange = 220,
		attackRange = 17,
		xpReward = 800,
		scale = 2.9,
		skin = { 66, 54, 42 },
	},
}

-- Which boss (scaled) appears on a given boss wave. `interval` = waves between bosses.
function Bosses.forWave(wave: number, interval: number): Boss
	local tier = math.max(1, math.floor(wave / interval)) -- 1st boss encounter, 2nd, ...
	local base = ROSTER[((tier - 1) % #ROSTER) + 1]

	local healthMult = 1 + (tier - 1) * 0.6
	local dmgMult = 1 + (tier - 1) * 0.2
	local xpMult = 1 + (tier - 1) * 0.3

	return {
		id = base.id,
		displayName = base.displayName,
		title = base.title,
		maxHealth = math.floor(base.maxHealth * healthMult),
		walkSpeed = base.walkSpeed,
		attackDamage = math.floor(base.attackDamage * dmgMult),
		attackInterval = base.attackInterval,
		aggroRange = base.aggroRange,
		attackRange = base.attackRange,
		xpReward = math.floor(base.xpReward * xpMult),
		scale = base.scale,
		skin = base.skin,
		weight = 1,
		isBoss = true,
	}
end

return Bosses
