--!strict
-- Survival-run rules: what happens when the party falls. Pure logic (Lune-testable);
-- the wave director owns the live state and just asks these questions.
--
-- Design: dying doesn't wipe your character — XP, level, gold and upgrades all persist.
-- What you lose is your WAVE STREAK. A total party wipe drops the run back to the
-- wave after your deepest cleared boss, so boss waves are the checkpoints worth reaching.

local Survival = {}

-- Seconds the "the line has broken" banner holds before the run reforms.
Survival.RestartDelay = 6

-- Party wipe = players are present and none of them are still standing.
function Survival.isPartyWipe(totalPlayers: number, downedPlayers: number): boolean
	return totalPlayers > 0 and downedPlayers >= totalPlayers
end

-- The checkpoint banked when a wave clears: boss waves bank a checkpoint, ordinary
-- waves leave it untouched. Never regresses (deeper clears only raise it).
function Survival.checkpointFor(clearedWave: number, previousCheckpoint: number, bossInterval: number): number
	if bossInterval > 0 and clearedWave > 0 and clearedWave % bossInterval == 0 then
		return math.max(previousCheckpoint, clearedWave)
	end
	return previousCheckpoint
end

-- The wave a wiped run resumes from: the wave AFTER your deepest cleared boss, so
-- you don't re-fight the boss you already beat. No boss cleared yet -> back to wave 1.
function Survival.restartWave(deepestBossCleared: number, bossInterval: number): number
	if bossInterval <= 0 or deepestBossCleared < bossInterval then
		return 1
	end
	-- Snap to the boss-milestone boundary, then step one past it.
	local milestone = math.floor(deepestBossCleared / bossInterval) * bossInterval
	return milestone + 1
end

return Survival
