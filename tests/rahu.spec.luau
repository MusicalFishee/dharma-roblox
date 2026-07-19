--!strict
-- Headless tests for Rahu's Eclipse: the rare shadow and the gilded horde.

local process = require("@lune/process")
local Rahu = require("../src/shared/Rahu")

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

print("Rahu")

check("the sun is safe while you learn", not Rahu.rolls(19, 0) and Rahu.rolls(20, 0))
check("the shadow obeys its chance", Rahu.rolls(50, Rahu.Config.Chance - 0.001) and not Rahu.rolls(50, Rahu.Config.Chance))
check("an eclipse is rare by law", Rahu.Config.Chance > 0 and Rahu.Config.Chance <= 0.15)
check("the spoils truly double", Rahu.Config.RewardMult == 2)

local base = { displayName = "Asura", maxHealth = 100, walkSpeed = 11, attackDamage = 8, xpReward = 25, scale = 1 }
local gilded = Rahu.gild(base)
check("the gilded are crueler and faster", gilded.attackDamage > base.attackDamage and gilded.walkSpeed > base.walkSpeed)
check("the gilded pay double", gilded.xpReward == base.xpReward * 2 and gilded.rahuGilded == true)
check("the roster is never touched", base.xpReward == 25 and (base :: any).rahuGilded == nil)
check("both lines are written", #Rahu.Lines.begin > 0 and #Rahu.Lines.detail > 0)

print(string.format("\n%d passed, %d failed", passed, failed))
if failed > 0 then
	print("FAILURES: " .. table.concat(failures, ", "))
	process.exit(1)
end
