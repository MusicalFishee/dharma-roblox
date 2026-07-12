--!strict
-- Headless combat tests, run with:  lune run tests/combat.spec
-- No Roblox required — this is the verification loop for game logic.

local process = require("@lune/process")
local Combat = require("../src/shared/Combat")

local passed = 0
local failed = 0
local failures: { string } = {}

local function check(name: string, condition: boolean)
	if condition then
		passed += 1
		print(string.format("  ok   %s", name))
	else
		failed += 1
		table.insert(failures, name)
		print(string.format("  FAIL %s", name))
	end
end

local function near(a: number, b: number): boolean
	return math.abs(a - b) < 1e-4
end

print("Dharma combat logic")

-- Base damage
check("light base = 10", Combat.baseDamage("Light") == 10)
check("heavy base = 25", Combat.baseDamage("Heavy") == 25)

-- Flow combo scaling
check("light combo 0 = 10", near(Combat.computeAttackDamage("Light", 0), 10))
check("light combo 5 = 14", near(Combat.computeAttackDamage("Light", 5), 14))
check("heavy combo 3 = 31", near(Combat.computeAttackDamage("Heavy", 3), 31))

-- Defensive resolution
local function state(over: { [string]: any }): Combat.DefenderState
	local s: Combat.DefenderState = {
		isDodging = false,
		isBlocking = false,
		blockAgeSeconds = 0,
		facingAttacker = true,
	}
	for k, v in over do
		(s :: any)[k] = v
	end
	return s
end

local dodge = Combat.resolveIncomingAttack(20, state({ isDodging = true }))
check("dodge negates damage", dodge.outcome == "Dodge" and dodge.damage == 0)

local parry = Combat.resolveIncomingAttack(20, state({ isBlocking = true, blockAgeSeconds = 0.1 }))
check("parry: 0 dmg, +20 tejas, stagger", parry.outcome == "Parry" and parry.damage == 0 and parry.defenderTejasGain == 20 and parry.attackerStaggered)

local block = Combat.resolveIncomingAttack(20, state({ isBlocking = true, blockAgeSeconds = 0.5 }))
check("block soaks 75%", block.outcome == "Block" and near(block.damage, 5))

local blockedFromBehind = Combat.resolveIncomingAttack(20, state({ isBlocking = true, facingAttacker = false }))
check("block from behind fails", blockedFromBehind.outcome == "Hit" and near(blockedFromBehind.damage, 20))

local hit = Combat.resolveIncomingAttack(20, state({}))
check("unguarded takes full", hit.outcome == "Hit" and near(hit.damage, 20))

-- Tejas economy
local afterSpend, ok = Combat.trySpendTejas(100, Combat.Config.AgniAstraCost)
check("astra spend ok", ok and afterSpend == 65)

local afterFail, ok2 = Combat.trySpendTejas(10, Combat.Config.AgniAstraCost)
check("astra spend blocked when low", (not ok2) and afterFail == 10)

check("tejas clamps high", Combat.clampTejas(120) == 100)
check("tejas clamps low", Combat.clampTejas(-5) == 0)

print(string.format("\n%d passed, %d failed", passed, failed))
if failed > 0 then
	print("FAILURES: " .. table.concat(failures, ", "))
	process.exit(1)
end
