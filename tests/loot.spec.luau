--!strict
-- Headless tests for loot rolls.

local process = require("@lune/process")
local Loot = require("../src/shared/Loot")

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

local function rngOf(v: number): () -> number
	return function()
		return v
	end
end

print("Loot")

-- Gold scales with XP and rolls within the variance band.
local lowRoll = Loot.goldFor(25, false, rngOf(0)) -- 25*0.6*0.75 = 11.25 -> 11
local highRoll = Loot.goldFor(25, false, rngOf(0.999)) -- ~25*0.6*1.25 -> 18
check("low roll floors correctly", lowRoll == 11)
check("high roll within +25%", highRoll >= 17 and highRoll <= 18)
check("tougher enemies drop more", Loot.goldFor(70, false, rngOf(0.5)) > Loot.goldFor(15, false, rngOf(0.5)))
check("bosses pay 3x", Loot.goldFor(100, true, rngOf(0.5)) == Loot.goldFor(100, false, rngOf(0.5)) * 3)
check("gold is never below 1", Loot.goldFor(1, false, rngOf(0)) >= 1)

-- Amrit chance.
check("roll under chance drops Amrit", Loot.rollAmrit(rngOf(0.05)) == true)
check("roll over chance drops nothing", Loot.rollAmrit(rngOf(0.5)) == false)

-- Persistence clamp.
check("clamp negative -> 0", Loot.clampGold(-5) == 0)
check("clamp NaN -> 0", Loot.clampGold(0 / 0) == 0)
check("clamp floors", Loot.clampGold(99.9) == 99)
check("clamp caps at GoldMax", Loot.clampGold(1e12) == Loot.GoldMax)

print(string.format("\n%d passed, %d failed", passed, failed))
if failed > 0 then
	print("FAILURES: " .. table.concat(failures, ", "))
	process.exit(1)
end
