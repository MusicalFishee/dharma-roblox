--!strict
-- The progression backbone: XP -> levels -> stronger stats -> unlocked abilities.
-- Pure logic (Lune-testable); the heart of the "just one more level" loop.

local Progression = {}

Progression.MaxLevel = 100

-- XP needed to go FROM `level` to `level + 1`. Rises smoothly so early levels
-- are fast (hook the player) and later levels are a real grind.
function Progression.xpToNext(level: number): number
	if level < 1 then
		level = 1
	end
	return math.floor(50 * (level ^ 1.5))
end

-- Total XP needed to have REACHED `level` from level 1.
function Progression.totalXpForLevel(level: number): number
	local sum = 0
	for l = 1, level - 1 do
		sum += Progression.xpToNext(l)
	end
	return sum
end

export type LevelInfo = {
	level: number,
	xpIntoLevel: number, -- XP earned within the current level
	xpForNext: number, -- XP needed to finish the current level
	isMax: boolean,
}

-- Resolve a total XP amount into level + progress within that level.
function Progression.resolve(totalXp: number): LevelInfo
	if totalXp < 0 then
		totalXp = 0
	end
	local level = 1
	local remaining = totalXp
	while level < Progression.MaxLevel do
		local need = Progression.xpToNext(level)
		if remaining < need then
			break
		end
		remaining -= need
		level += 1
	end

	local isMax = level >= Progression.MaxLevel
	return {
		level = level,
		xpIntoLevel = isMax and 0 or remaining,
		xpForNext = isMax and 0 or Progression.xpToNext(level),
		isMax = isMax,
	}
end

-- ---- Stat scaling ----

function Progression.maxHealthForLevel(level: number): number
	return 100 + (level - 1) * 20
end

-- Multiplier applied to the player's attack damage.
function Progression.damageMultiplierForLevel(level: number): number
	return 1 + (level - 1) * 0.05
end

-- Max Tejas grows a little each level too.
function Progression.maxTejasForLevel(level: number): number
	return 100 + (level - 1) * 5
end

-- ---- Ability unlocks (the Z/X/C/V slots) ----

Progression.AbilityUnlockLevel = {
	Z = 1, -- Agni Astra from the start
	X = 4,
	C = 8,
	V = 12, -- ultimate
} :: { [string]: number }

function Progression.isAbilityUnlocked(slot: string, level: number): boolean
	local req = Progression.AbilityUnlockLevel[slot]
	if not req then
		return false
	end
	return level >= req
end

return Progression
