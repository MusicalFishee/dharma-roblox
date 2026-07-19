--!strict
-- Headless tests for the Chakravyuha: wave claims that touch no other
-- spectacle, the spiral's geometry, the bound ranks, and the axis.

local process = require("@lune/process")
local Chakravyuha = require("../src/shared/Chakravyuha")
local Waves = require("../src/shared/Waves")
local Trial = require("../src/shared/Trial")
local Ravana = require("../src/shared/Ravana")
local Tarakasura = require("../src/shared/Tarakasura")
local Doshas = require("../src/shared/Doshas")

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

print("Chakravyuha")

-- Wave claims.
check("the wheel first turns at 13", Chakravyuha.isVyuhaWave(13) and not Chakravyuha.isVyuhaWave(3))
check("and on every 3 after", Chakravyuha.isVyuhaWave(23) and Chakravyuha.isVyuhaWave(103))
check("other nights are not the wheel's", not Chakravyuha.isVyuhaWave(12) and not Chakravyuha.isVyuhaWave(25))

local disjoint = true
for wave = 1, 1000 do
	if Chakravyuha.isVyuhaWave(wave) then
		if Waves.isBossWave(wave) or Trial.isTrialWave(wave) or Ravana.isRaidWave(wave) or Tarakasura.isWarMoonWave(wave) or Doshas.isDoshaWave(wave) then
			disjoint = false
		end
	end
end
check("the wheel turns only on ordinary ground", disjoint)

-- The spiral.
local spots = Chakravyuha.spiralPositions(12, 2.2, 40)
check("the coil holds every rank", #spots == 12)
local outward = true
local prev = 0
for _, s in spots do
	local r = math.sqrt(s.x * s.x + s.z * s.z)
	if r <= prev then
		outward = false
	end
	prev = r
end
check("the coil winds strictly outward", outward)
local first = math.sqrt(spots[1].x ^ 2 + spots[1].z ^ 2)
local last = math.sqrt(spots[12].x ^ 2 + spots[12].z ^ 2)
check("it starts near the heart and ends near the rim", first < 12 and last > 35 and last <= 40)

-- The bound ranks.
local base = { displayName = "Asura", maxHealth = 100, walkSpeed = 11, attackDamage = 8, xpReward = 25, scale = 1 }
local bound = Chakravyuha.bindToVyuha(base)
check("bound ranks borrow fury", bound.attackDamage == 10 and bound.walkSpeed > base.walkSpeed and bound.vyuhaBound == true)
check("the roster is never touched", base.attackDamage == 8 and (base :: any).vyuhaBound == nil)

-- The axis.
local axis = Chakravyuha.axisOf(base)
check("the axis is thrice the soldier", axis.maxHealth == 300 and axis.xpReward == 75)
check("the axis bears the commander's name", axis.displayName == "Vyuha-Pati Asura" and axis.isElite == true)
check("the axis never borrows fury", (axis :: any).vyuhaBound == nil)

-- The collapse.
check("the stagger is a real feast", Chakravyuha.Config.StaggerSeconds >= 2 and Chakravyuha.Config.StaggerSeconds <= 6)
check("breaking deeper wheels pays more", Chakravyuha.collapseBounty(53) > Chakravyuha.collapseBounty(13))

print(string.format("\n%d passed, %d failed", passed, failed))
if failed > 0 then
	print("FAILURES: " .. table.concat(failures, ", "))
	process.exit(1)
end
