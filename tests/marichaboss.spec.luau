--!strict
-- Headless tests for Maricha Revealed: the trigger rhythm, the revealed form,
-- and the spoils of tearing the illusion.

local process = require("@lune/process")
local MarichaBoss = require("../src/shared/MarichaBoss")

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

print("MarichaBoss")

check("the hunt has a rhythm", MarichaBoss.RevealEvery == 10)
check("an untouched ledger springs nothing", not MarichaBoss.isRevealing(0))
check("nine hunts stay a secret", not MarichaBoss.isRevealing(9))
check("the tenth hunt tears the veil", MarichaBoss.isRevealing(10))
check("the fifteenth stays quiet", not MarichaBoss.isRevealing(15))
check("every tenth after tears again", MarichaBoss.isRevealing(20) and MarichaBoss.isRevealing(30))

local a30 = MarichaBoss.archetypeFor(30)
check("the revealed demon is a true boss", a30.isBoss == true and #(a30.title :: string) > 0)
check("he keeps the bow", a30.ranged == true and (a30.projectileSpeed :: number) > 0)
check("he still runs", (a30.retreatRange :: number) > 0)
check("the composer can never roll him", a30.weight == 0)
local a50 = MarichaBoss.archetypeFor(50)
check("deeper nights tear a harder demon", a50.maxHealth > a30.maxHealth and a50.attackDamage > a30.attackDamage)
check("deeper nights pay more XP", a50.xpReward > a30.xpReward)

local s30 = MarichaBoss.spoilsFor(30)
check("the spoils are worth ten hunts", s30.gold > 400 and s30.shards > 0)
check("deeper spoils outshine", MarichaBoss.spoilsFor(60).gold > s30.gold)
check("both lines are written", #MarichaBoss.Lines.reveal > 0 and #MarichaBoss.Lines.fall > 0)

print(string.format("\n%d passed, %d failed", passed, failed))
if failed > 0 then
	print("FAILURES: " .. table.concat(failures, ", "))
	process.exit(1)
end
