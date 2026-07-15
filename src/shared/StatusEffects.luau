--!strict
-- Status effects the horde inflicts on YOU: venom (damage over time), toxic pools
-- (ground you must not stand in), and curses (healing halved). Pure defs + math so
-- the numbers are Lune-tested; EnemyService/heal paths apply them.

local StatusEffects = {}

-- Venom: envenomed strikes tick damage over a few seconds. Doesn't stack — a fresh
-- bite while poisoned is wasted (dodge windows matter).
StatusEffects.Venom = {
	totalDamage = 10,
	seconds = 4,
}

-- Toxic pool: left on the ground when a venomous creature dies. Stand out of it.
StatusEffects.Pool = {
	radius = 7,
	dps = 6,
	lifetime = 6,
	tick = 0.5, -- seconds between damage ticks
}

-- Curse: your wounds resist mending — every heal is multiplied down while it lasts.
StatusEffects.Curse = {
	seconds = 8,
	healMult = 0.5,
}

-- A status is active while `now` is before its expiry.
function StatusEffects.isActive(now: number, activeUntil: number): boolean
	return now < activeUntil
end

-- Healing after the curse (identity when uncursed). Never negative.
function StatusEffects.effectiveHeal(amount: number, cursed: boolean): number
	local healed = if cursed then amount * StatusEffects.Curse.healMult else amount
	return math.max(0, healed)
end

-- Venom damage applied per one-second tick.
function StatusEffects.venomTick(): number
	return StatusEffects.Venom.totalDamage / StatusEffects.Venom.seconds
end

-- Damage a pool deals for one tick to someone at `distance` from its centre.
function StatusEffects.poolTickDamage(distance: number): number
	if distance > StatusEffects.Pool.radius then
		return 0
	end
	return StatusEffects.Pool.dps * StatusEffects.Pool.tick
end

return StatusEffects
