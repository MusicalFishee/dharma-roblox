--!strict
-- Headless tests for the progression system.

local process = require("@lune/process")
local Progression = require("../src/shared/Progression")

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

print("Progression")

-- XP curve rises with level.
check("xpToNext(1) = 50", Progression.xpToNext(1) == 50)
check("xpToNext rises", Progression.xpToNext(5) > Progression.xpToNext(1))

-- Level resolution.
check("0 xp -> level 1", Progression.resolve(0).level == 1)
check("49 xp -> still level 1", Progression.resolve(49).level == 1)
check("50 xp -> level 2", Progression.resolve(50).level == 2)
local info = Progression.resolve(60)
check("60 xp -> level 2 with 10 into level", info.level == 2 and info.xpIntoLevel == 10)

-- Total XP for a level matches the sum of the curve.
check("totalXpForLevel(2) = 50", Progression.totalXpForLevel(2) == 50)
check("resolve(totalXpForLevel(5)) = level 5", Progression.resolve(Progression.totalXpForLevel(5)).level == 5)

-- Max level clamps.
local maxInfo = Progression.resolve(999999999)
check("huge xp clamps to MaxLevel", maxInfo.level == Progression.MaxLevel and maxInfo.isMax)

-- Stat scaling.
check("level 1 health = 100", Progression.maxHealthForLevel(1) == 100)
check("level 10 health = 280", Progression.maxHealthForLevel(10) == 280)
check("damage mult scales", Progression.damageMultiplierForLevel(1) == 1 and Progression.damageMultiplierForLevel(11) > 1.4)

-- Ability unlocks.
check("Z unlocked at level 1", Progression.isAbilityUnlocked("Z", 1))
check("X locked at level 1", not Progression.isAbilityUnlocked("X", 1))
check("X unlocked at level 4", Progression.isAbilityUnlocked("X", 4))
check("V (ultimate) locked before 12", not Progression.isAbilityUnlocked("V", 11) and Progression.isAbilityUnlocked("V", 12))


-- The tejas ladder agrees with the combat base and only ever climbs.
check("level 1 tejas equals the combat base cap", Progression.maxTejasForLevel(1) == 100)
local tejasClimbs = true
for l = 2, Progression.MaxLevel do
	if Progression.maxTejasForLevel(l) <= Progression.maxTejasForLevel(l - 1) then
		tejasClimbs = false
	end
end
check("max tejas climbs every level to the cap", tejasClimbs)

print(string.format("\n%d passed, %d failed", passed, failed))
if failed > 0 then
	print("FAILURES: " .. table.concat(failures, ", "))
	process.exit(1)
end
