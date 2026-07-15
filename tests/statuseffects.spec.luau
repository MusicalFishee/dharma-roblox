--!strict
-- Status effects: venom/pool/curse tuning, the heal-curse math, and roster wiring.

local process = require("@lune/process")
local StatusEffects = require("../src/shared/StatusEffects")
local EnemyTypes = require("../src/shared/EnemyTypes")
local Elites = require("../src/shared/Elites")

local passed, failed = 0, 0
local failures: { string } = {}
local function check(name: string, cond: boolean)
	if cond then
		passed += 1
		print("  ok   " .. name)
	else
		failed += 1
		table.insert(failures, name)
		print("  FAIL " .. name)
	end
end

local function near(a: number, b: number): boolean
	return math.abs(a - b) < 1e-6
end

print("StatusEffects")

-- Tuning sanity.
check("venom deals real damage over real time", StatusEffects.Venom.totalDamage > 0 and StatusEffects.Venom.seconds > 0)
check("venom is a nuisance, not a death sentence", StatusEffects.Venom.totalDamage <= 30)
check("pool has area, bite, and a fuse", StatusEffects.Pool.radius > 0 and StatusEffects.Pool.dps > 0 and StatusEffects.Pool.lifetime > 0 and StatusEffects.Pool.tick > 0)
check("curse halves-ish but never voids healing", StatusEffects.Curse.healMult > 0 and StatusEffects.Curse.healMult < 1)
check("curse eventually lifts", StatusEffects.Curse.seconds > 0)

-- The math.
check("isActive true before expiry", StatusEffects.isActive(10, 12) == true)
check("isActive false at expiry", StatusEffects.isActive(12, 12) == false)
check("cursed heal is reduced", near(StatusEffects.effectiveHeal(40, true), 40 * StatusEffects.Curse.healMult))
check("clean heal untouched", near(StatusEffects.effectiveHeal(40, false), 40))
check("heal never goes negative", StatusEffects.effectiveHeal(-10, true) == 0)
check("venom tick sums to the total", near(StatusEffects.venomTick() * StatusEffects.Venom.seconds, StatusEffects.Venom.totalDamage))
check("pool bites inside the radius", StatusEffects.poolTickDamage(StatusEffects.Pool.radius - 1) == StatusEffects.Pool.dps * StatusEffects.Pool.tick)
check("pool spares outside the radius", StatusEffects.poolTickDamage(StatusEffects.Pool.radius + 0.1) == 0)
check("pool edge still counts", StatusEffects.poolTickDamage(StatusEffects.Pool.radius) > 0)

-- Roster wiring: the ghoul envenoms and melts; the shade curses; others are clean.
local pisacha = EnemyTypes.get("Pisacha")
local vetala = EnemyTypes.get("Vetala")
check("Pisacha envenoms and leaves a pool", pisacha.inflicts == "venom" and pisacha.leavesPool == true)
check("Vetala curses", vetala.inflicts == "curse" and not vetala.leavesPool)
check("Asura stays clean", EnemyTypes.get("Asura").inflicts == nil)
local knownInflicts = { venom = true, curse = true }
local allKnown = true
for _, a in EnemyTypes.List do
	if a.inflicts and not knownInflicts[a.inflicts] then
		allKnown = false
	end
end
check("every inflicts value is a known status", allKnown)

-- Elites keep their afflictions.
local eliteGhoul = Elites.makeElite(pisacha :: any)
check("elite ghoul still envenoms and melts", eliteGhoul.inflicts == "venom" and eliteGhoul.leavesPool == true)

print(string.format("\n%d passed, %d failed", passed, failed))
if failed > 0 then
	print("FAILURES: " .. table.concat(failures, ", "))
	process.exit(1)
end
