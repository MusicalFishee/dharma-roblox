--!strict
-- Dharma combat resolution — pure logic, no Roblox dependencies.
-- This module is required by both the Roblox server (via Rojo) and the headless
-- Lune test suite, so it must stay free of engine globals.

local Combat = {}

-- ------------------------------------------------------------------
-- Tuning
-- ------------------------------------------------------------------
Combat.Config = {
	LightDamage = 10,
	HeavyDamage = 25,

	-- Each hit in the Flow chain adds this fraction to damage.
	ComboDamageStep = 0.08,
	-- Seconds after a connecting hit before the Flow chain resets.
	ComboResetWindow = 1.5,

	-- ---- LMB auto-combo (Blox-Fruits-style M1 chain) ----
	-- Every Nth swing is the heavy finisher.
	ComboChainLength = 4,
	-- Minimum seconds between swings (attack cadence; blocks click-spam).
	ComboHitInterval = 0.28,
	-- Recovery lockout after the heavy finisher lands.
	ComboFinisherLockout = 0.7,

	-- Critical hits: a chance for a swing to land for extra.
	CritChance = 0.15,
	CritMultiplier = 2.0,

	-- Defensive resolution.
	ParryWindowSeconds = 0.30,
	BlockDamageMultiplier = 0.25,

	-- Tejas (sacred energy) economy.
	TejasPerHitLanded = 8,
	TejasPerParry = 20,
	TejasMax = 100,

	-- Astra cost.
	AgniAstraCost = 35,
	AgniAstraDamage = 30,

	-- Enemy tuning (distances in Roblox studs).
	EnemyMaxHealth = 100,
	EnemyAttackDamage = 8,
	EnemyAttackInterval = 1.6,
	EnemyAggroRange = 90,
	EnemyAttackRange = 9,
	EnemyWalkSpeed = 11,
}

export type AttackKind = "Light" | "Heavy"

export type DefenderState = {
	isDodging: boolean,
	isBlocking: boolean,
	-- Seconds since the block began (only meaningful when isBlocking).
	blockAgeSeconds: number,
	-- True when the defender is facing the attacker.
	facingAttacker: boolean,
}

export type Outcome = "Dodge" | "Parry" | "Block" | "Hit"

export type Resolution = {
	outcome: Outcome,
	damage: number,
	-- Tejas the DEFENDER gains from this exchange (parry reward).
	defenderTejasGain: number,
	-- Whether the attacker gets staggered (a successful parry).
	attackerStaggered: boolean,
}

-- ------------------------------------------------------------------
-- Offense
-- ------------------------------------------------------------------

-- Base damage for an attack kind.
function Combat.baseDamage(kind: AttackKind): number
	if kind == "Heavy" then
		return Combat.Config.HeavyDamage
	end
	return Combat.Config.LightDamage
end

-- Damage after the Flow combo bonus. comboCount is the number of prior
-- consecutive connecting hits (0 for the first swing).
function Combat.computeAttackDamage(kind: AttackKind, comboCount: number): number
	local base = Combat.baseDamage(kind)
	local multiplier = 1 + (math.max(comboCount, 0) * Combat.Config.ComboDamageStep)
	return base * multiplier
end

-- Rolls a critical hit. `rng` returns [0, 1) (defaults to math.random); injectable for tests.
function Combat.rollCrit(rng: (() -> number)?): boolean
	local roll: () -> number = rng or function(): number
		return math.random()
	end
	return roll() < Combat.Config.CritChance
end

-- Applies the crit multiplier when isCrit, otherwise returns the damage unchanged.
function Combat.critDamage(damage: number, isCrit: boolean): number
	if isCrit then
		return damage * Combat.Config.CritMultiplier
	end
	return damage
end

-- ------------------------------------------------------------------
-- Defense
-- ------------------------------------------------------------------

-- Resolves an incoming attack against a defender's current state.
function Combat.resolveIncomingAttack(incomingDamage: number, state: DefenderState): Resolution
	-- Dodge i-frames beat everything.
	if state.isDodging then
		return {
			outcome = "Dodge",
			damage = 0,
			defenderTejasGain = 0,
			attackerStaggered = false,
		}
	end

	if state.isBlocking and state.facingAttacker then
		if state.blockAgeSeconds <= Combat.Config.ParryWindowSeconds then
			-- Perfect parry.
			return {
				outcome = "Parry",
				damage = 0,
				defenderTejasGain = Combat.Config.TejasPerParry,
				attackerStaggered = true,
			}
		end
		-- Ordinary block soaks most of the blow.
		return {
			outcome = "Block",
			damage = incomingDamage * Combat.Config.BlockDamageMultiplier,
			defenderTejasGain = 0,
			attackerStaggered = false,
		}
	end

	-- Unguarded.
	return {
		outcome = "Hit",
		damage = incomingDamage,
		defenderTejasGain = 0,
		attackerStaggered = false,
	}
end

-- ------------------------------------------------------------------
-- Resources
-- ------------------------------------------------------------------

function Combat.clampTejas(value: number): number
	return math.clamp(value, 0, Combat.Config.TejasMax)
end

-- Returns the new Tejas total and whether the spend succeeded.
function Combat.trySpendTejas(current: number, cost: number): (number, boolean)
	if cost <= 0 or current < cost then
		return current, false
	end
	return current - cost, true
end

return Combat
