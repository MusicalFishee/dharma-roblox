--!strict
-- Headless tests for elite empowerment.

local process = require("@lune/process")
local Elites = require("../src/shared/Elites")
local EnemyTypes = require("../src/shared/EnemyTypes")

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

print("Elites")

-- Rolling.
check("roll under chance is elite", Elites.roll(function()
	return 0.05
end) == true)
check("roll over chance is normal", Elites.roll(function()
	return 0.5
end) == false)
check("chance is rare but real", Elites.Chance > 0 and Elites.Chance <= 0.25)

-- Empowerment (on a real archetype from the roster).
local base = EnemyTypes.get("Asura")
local elite = Elites.makeElite(base)
check("elite is flagged", elite.isElite == true)
check("elite is named", elite.displayName == "Elite Asura")
check("elite health multiplied", elite.maxHealth == math.floor(base.maxHealth * Elites.HealthMult))
check("elite damage multiplied", elite.attackDamage == math.floor(base.attackDamage * Elites.DamageMult))
check("elite pays 2.5x XP", elite.xpReward == math.floor(base.xpReward * Elites.XpMult))
check("elite is a little bigger and faster", elite.scale > base.scale and elite.walkSpeed > base.walkSpeed)
check("elite is never a boss", elite.isBoss == false)

-- Immutability: the roster must never be corrupted by empowerment.
check("original archetype untouched", base.maxHealth == EnemyTypes.get("Asura").maxHealth and base.displayName == "Asura")

-- An elite archer keeps its bow (ranged kit must survive empowerment).
local eliteArcher = Elites.makeElite(EnemyTypes.get("Maricha") :: any)
check("elite archer stays ranged", eliteArcher.ranged == true and (eliteArcher.projectileSpeed or 0) > 0 and (eliteArcher.retreatRange or 0) > 0)

print(string.format("\n%d passed, %d failed", passed, failed))
if failed > 0 then
	print("FAILURES: " .. table.concat(failures, ", "))
	process.exit(1)
end
