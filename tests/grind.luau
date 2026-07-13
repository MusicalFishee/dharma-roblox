--!strict
-- Simulated grind through the REAL progression + enemy modules:
-- a hero clears a horde, earns XP, levels up, and unlocks abilities.
--   run with:  lune run tests/grind

local Progression = require("../src/shared/Progression")
local EnemyTypes = require("../src/shared/EnemyTypes")

print("=== Dharma grind: clearing the horde, leveling up ===\n")

math.randomseed(7)
local totalXp = 0
local kills = 0
local level = 1

local function unlockedAt(lvl: number): string?
	for slot, req in Progression.AbilityUnlockLevel do
		if req == lvl then
			return slot
		end
	end
	return nil
end

for _ = 1, 50 do
	local enemy = EnemyTypes.pick()
	kills += 1
	totalXp += enemy.xpReward
	local info = Progression.resolve(totalXp)
	if info.level > level then
		level = info.level
		local unlock = unlockedAt(level)
		local extra = if unlock then "   ★ UNLOCKED ability [" .. unlock .. "]!" else ""
		print(string.format(
			"[kill %2d] slew %-9s (+%2d XP)  ==>  LEVEL %d!   HP %d, dmg x%.2f%s",
			kills, enemy.displayName, enemy.xpReward, level,
			Progression.maxHealthForLevel(level),
			Progression.damageMultiplierForLevel(level),
			extra
		))
	end
end

local f = Progression.resolve(totalXp)
print(string.format(
	"\n%d kills -> Level %d  |  %d HP  |  +%.0f%% damage vs level 1.",
	kills,
	f.level,
	Progression.maxHealthForLevel(f.level),
	(Progression.damageMultiplierForLevel(f.level) - 1) * 100
))
