--!strict
-- Headless tests for Ravana: raid gating, head/stage math, escalation, spoils —
-- and THE SUPREMACY LAW: the Kirata Trial outranks the raid in every number,
-- at every visitation, forever. Shiva is the Destroyer. Ravana was his devotee.

local process = require("@lune/process")
local Ravana = require("../src/shared/Ravana")
local Trial = require("../src/shared/Trial")
local Relics = require("../src/shared/Relics")
local Waves = require("../src/shared/Waves")

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

print("Ravana")

-- Raid gating: 50, then every 50 — and NEVER on a Trial wave.
check("wave 50 is the first raid", Ravana.isRaidWave(50) and Ravana.FirstWave == 50)
check("the raid returns every 50 waves", Ravana.isRaidWave(100) and Ravana.isRaidWave(150) and not Ravana.isRaidWave(75))
check("ordinary and boss waves are not raids", not Ravana.isRaidWave(5) and not Ravana.isRaidWave(45) and not Ravana.isRaidWave(49))
check("raid waves sit on the boss cadence", Ravana.FirstWave % Waves.BossInterval == 0 and Ravana.RepeatEvery % Waves.BossInterval == 0)

local neverCollides = true
for wave = 1, 500 do
	if Trial.isTrialWave(wave) and Ravana.isRaidWave(wave) then
		neverCollides = false
	end
end
check("the raid never collides with the Trial (checked to wave 500)", neverCollides)

check("encounter index counts visitations", Ravana.encounterIndex(50) == 1 and Ravana.encounterIndex(100) == 2 and Ravana.encounterIndex(25) == 0)

-- ============================================================================
-- THE SUPREMACY LAW. If this block ever fails, someone tried to raise Ravana
-- above Mahadeva. Do not fix the test. Fix the numbers.
-- ============================================================================
local shivaAlwaysDeeper = true
local shivaAlwaysRicher = true
for n = 1, 8 do
	if Ravana.healthFor(n) >= Trial.healthFor(n) then
		shivaAlwaysDeeper = false
	end
	if Ravana.rewardFor(n).xp >= Trial.rewardFor(n).xp then
		shivaAlwaysRicher = false
	end
end
check("SUPREMACY: the Trial's pool is always deeper than Ravana's", shivaAlwaysDeeper)
check("SUPREMACY: grace always pays more than loot", shivaAlwaysRicher)
local fiercestRavana = Ravana.statsForStage(Ravana.HeadCount - 1)
check("SUPREMACY: even the Ego strikes softer than the Tandava", fiercestRavana.meleeDamage < Trial.Phase3.meleeDamage)
check("SUPREMACY: Nataraja towers over the Ten-Headed King", Trial.Phase3.scale > 2.8)

-- The heads: ten, each with a vice and a dying taunt.
check("ten heads", #Ravana.Heads == Ravana.HeadCount and Ravana.HeadCount == 10)
local headsValid = true
local vicesSeen: { [string]: boolean } = {}
for _, head in Ravana.Heads do
	if #head.name == 0 or #head.vice == 0 or #head.line == 0 or vicesSeen[head.vice] then
		headsValid = false
	end
	vicesSeen[head.vice] = true
end
check("every head has a unique vice and a taunt", headsValid)
check("the Ego goes last", Ravana.Heads[10].vice == "Ego")

-- Stage math: full health = whole crown; the tenth head falls only in death.
check("full health severs nothing", Ravana.stageFor(1.0) == 0 and Ravana.stageFor(0.95) == 0)
check("each tenth takes a head", Ravana.stageFor(0.85) == 1 and Ravana.stageFor(0.55) == 4 and Ravana.stageFor(0.15) == 8)
check("the last head never falls to stage math", Ravana.stageFor(0.05) == 9 and Ravana.stageFor(0) == 9 and Ravana.stageFor(-1) == 9)
check("junk fractions sever nothing", Ravana.stageFor(0 / 0) == 0)

-- Escalation: fewer heads, fiercer king.
local escalates = true
for severed = 1, 9 do
	local prev = Ravana.statsForStage(severed - 1)
	local cur = Ravana.statsForStage(severed)
	if cur.walkSpeed <= prev.walkSpeed or cur.meleeDamage < prev.meleeDamage or cur.meleeCooldown > prev.meleeCooldown then
		escalates = false
	end
end
check("every severed head makes him fiercer", escalates)
check("the slam waits for wrath to be shed", not Ravana.statsForStage(1).slamEnabled and Ravana.statsForStage(2).slamEnabled)
check("only the Ego enrages", not Ravana.statsForStage(8).enraged and Ravana.statsForStage(9).enraged)
check("the slam is dodgeable", Ravana.Slam.telegraph >= 1.0 and Ravana.Slam.radius > 0 and Ravana.Slam.damage > 0)
check("reinforcements come at marked severances", Ravana.SummonAtSevered[3] ~= nil and Ravana.SummonAtSevered[6] ~= nil and Ravana.SummonAtSevered[9] ~= nil)
check("the stagger window is generous", Ravana.StaggerSeconds >= 2)

-- Lines + spoils.
local lineKeys = { "spawn", "halfway", "enrage", "defeated", "victory" }
local allLines = true
for _, key in lineKeys do
	local line = (Ravana.Lines :: any)[key]
	if type(line) ~= "string" or #line == 0 then
		allLines = false
	end
end
check("every scripted beat has its line", allLines)
check("spoils deepen each visitation", Ravana.rewardFor(2).xp > Ravana.rewardFor(1).xp and Ravana.rewardFor(2).shards > Ravana.rewardFor(1).shards)

-- The mythic set is wired: Ravana's drop table exists and is all-mythic.
local drops = Relics.dropsFor("Ravana")
local allMythic = #drops == 3
for _, id in drops do
	local def = Relics.get(id)
	if not def or def.rarity ~= "mythic" then
		allMythic = false
	end
end
check("Ravana drops the full mythic Dashanana set", allMythic)

print(string.format("\n%d passed, %d failed", passed, failed))
if failed > 0 then
	print("FAILURES: " .. table.concat(failures, ", "))
	process.exit(1)
end
