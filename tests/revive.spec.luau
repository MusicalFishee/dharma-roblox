--!strict
-- Headless tests for Uddhāra: config sanity, bleed-out clock, lift gating,
-- and the health math for standing back up.

local process = require("@lune/process")
local Revive = require("../src/shared/Revive")

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

print("Revive")

-- Config sanity.
local cfg = Revive.Config
check("bleed-out lasts long enough to be saved", cfg.BleedOutSeconds >= 10)
check("the lift is a held commitment", cfg.HoldSeconds >= 1 and cfg.HoldSeconds < cfg.BleedOutSeconds)
check("lift range is close-quarters", cfg.Range > 0 and cfg.Range <= 20)
check("you stand up wounded, not fresh", cfg.RevivedHealthFraction > 0 and cfg.RevivedHealthFraction < 1)
check("crawling is slower than walking", cfg.CrawlSpeed > 0 and cfg.CrawlSpeed < 16)

-- Revived health math.
check("revived health takes the fraction", Revive.revivedHealth(200) == math.floor(200 * cfg.RevivedHealthFraction))
check("revived health floors at 1", Revive.revivedHealth(1) == 1 and Revive.revivedHealth(0) == 1)

-- The bleed-out clock.
check("full clock at the moment of falling", Revive.remainingSeconds(100, 100) == cfg.BleedOutSeconds)
check("clock counts down", Revive.remainingSeconds(100, 105) == cfg.BleedOutSeconds - 5)
check("clock never goes negative", Revive.remainingSeconds(100, 1000) == 0)
check("not bled out mid-clock", Revive.isBledOut(100, 100 + cfg.BleedOutSeconds - 0.5) == false)
check("bled out when the clock dies", Revive.isBledOut(100, 100 + cfg.BleedOutSeconds) == true)

-- Lift gating.
check("a standing ally can lift the fallen", Revive.canLift(true, false, true).ok)
check("cannot lift someone who is not down", Revive.canLift(true, false, false).reason == "target")
check("the fallen cannot lift each other", Revive.canLift(true, true, true).reason == "lifter")
check("the dead cannot lift anyone", Revive.canLift(false, false, true).reason == "lifter")

-- External heals.
check("a real heal stands you up", Revive.healLifts(Revive.Config.AutoLiftAbove + 1))
check("the clamp trickle does not", Revive.healLifts(1) == false)

print(string.format("\n%d passed, %d failed", passed, failed))
if failed > 0 then
	print("FAILURES: " .. table.concat(failures, ", "))
	process.exit(1)
end
