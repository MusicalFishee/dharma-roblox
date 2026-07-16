--!strict
-- The Kirata Trial: wave gating, phase thresholds, both stat blocks, the lines,
-- and the boon. The one fight that must never be winnable by killing.

local process = require("@lune/process")
local Trial = require("../src/shared/Trial")
local Waves = require("../src/shared/Waves")
local Milestones = require("../src/shared/Milestones")

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

print("Trial")

-- Wave gating: 25, then every 50.
check("wave 25 is the first trial", Trial.isTrialWave(25) == true and Trial.FirstWave == 25)
check("ordinary waves are not trials", Trial.isTrialWave(1) == false and Trial.isTrialWave(24) == false and Trial.isTrialWave(26) == false)
check("regular boss waves are not trials", Trial.isTrialWave(5) == false and Trial.isTrialWave(20) == false and Trial.isTrialWave(50) == false)
check("the trial returns every 50 waves", Trial.isTrialWave(75) == true and Trial.isTrialWave(125) == true and Trial.isTrialWave(100) == false)
check("no trial before the first", Trial.isTrialWave(0) == false)
check("trial waves sit on the boss cadence (they replace a boss slot)", Trial.FirstWave % Waves.BossInterval == 0 and Trial.RepeatEvery % Waves.BossInterval == 0)
check("the first trial shares wave 25 with a milestone (epic on purpose)", Milestones.forWave(Trial.FirstWave) ~= nil)

-- Phase thresholds: bless < transform, both real fractions.
check("thresholds are ordered fractions", 0 < Trial.BlessAt and Trial.BlessAt < Trial.Phase2At and Trial.Phase2At < 1)
check("the pool is deep", Trial.MaxHealth > 0)

-- Both phases well-formed; the god outclasses the hunter.
local function phaseOk(p: Trial.PhaseConfig): boolean
	return p.name ~= ""
		and p.title ~= ""
		and p.walkSpeed > 0
		and p.scale > 0
		and #p.skin == 3
		and p.arrowDamage > 0
		and p.volleyCount > 0
		and p.volleyInterval > 0
		and p.volleyCooldown > 0
		and p.projectileSpeed > 0
		and p.meleeDamage > 0
		and p.meleeRange > 0
		and p.meleeCooldown > 0
		and p.preferredRange > 0
end
check("phase 1 (the Kirata) is well-formed", phaseOk(Trial.Phase1))
check("phase 2 (Mahadeva) is well-formed", phaseOk(Trial.Phase2))
check("the reveal hits harder", Trial.Phase2.arrowDamage > Trial.Phase1.arrowDamage and Trial.Phase2.meleeDamage > Trial.Phase1.meleeDamage)
check("the god is vaster than the hunter", Trial.Phase2.scale > Trial.Phase1.scale)
check("the god stalks closer", Trial.Phase2.preferredRange < Trial.Phase1.preferredRange)

-- The Tandava stomp.
check("stomp has area, bite, warning, and rhythm", Trial.Stomp.radius > 0 and Trial.Stomp.damage > 0 and Trial.Stomp.telegraph > 0 and Trial.Stomp.cooldown > 0)
check("stomp telegraph is long enough to dodge", Trial.Stomp.telegraph >= 1.0)

-- Every scripted line exists (a missing line = a silent beat).
local lineKeys = { "spawn", "fury", "transitionA", "transitionB", "midPhase2", "blessing", "passed" }
local allLines = true
for _, key in lineKeys do
	local line = (Trial.Lines :: any)[key]
	if type(line) ~= "string" or #line == 0 then
		allLines = false
		print("    !! missing line: " .. key)
	end
end
check("every scripted beat has its line", allLines)

-- The boon.
check("the blessing pays XP and shards", Trial.Reward.xp > 0 and Trial.Reward.shards > 0)

print(string.format("\n%d passed, %d failed", passed, failed))
if failed > 0 then
	print("FAILURES: " .. table.concat(failures, ", "))
	process.exit(1)
end
