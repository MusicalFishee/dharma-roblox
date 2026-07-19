--!strict
-- Headless tests for the Vairi: the grudge's growth, its name, and its debt.

local process = require("@lune/process")
local Vairi = require("../src/shared/Vairi")

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

print("Vairi")

check("a haunting, not a schedule", Vairi.Config.Chance > 0 and Vairi.Config.Chance <= 0.5)
check("a grudge can only grow so monstrous", Vairi.Config.MaxCount >= 5 and Vairi.Config.MaxCount <= 20)

local base = { displayName = "Vetala", maxHealth = 80, walkSpeed = 16, attackDamage = 12, xpReward = 40, scale = 1, minWave = 30 }
local first = Vairi.of(base, 1, "Adi")
check("the grudge wears both names", first.displayName == "Vetala, Bane of Adi")
check("a first grudge is twice the demon", first.maxHealth == 160)
check("the grudge is elite by right", first.isElite == true and first.xpReward == 100)
check("the grudge outruns its old self", first.walkSpeed > base.walkSpeed and first.scale > base.scale)
check("curfews mean nothing to a grudge", first.minWave == nil)
check("the roster is never touched", base.maxHealth == 80 and base.minWave == 30 and base.displayName == "Vetala")

local fed = Vairi.of(base, 4, "Adi")
check("a fed grudge is crueler", fed.maxHealth > first.maxHealth and fed.attackDamage > first.attackDamage)
check("growth is clamped at the ceiling", Vairi.of(base, 99, "Adi").maxHealth == Vairi.of(base, Vairi.Config.MaxCount, "Adi").maxHealth)

check("the debt deepens as it feeds", Vairi.bountyFor(4).gold > Vairi.bountyFor(1).gold)
check("the debt always pays shards", Vairi.bountyFor(1).shards > 0)
check("junk counts are clamped", Vairi.bountyFor(-3).gold == Vairi.bountyFor(1).gold)
check("every line is written", #Vairi.Lines.marked > 0 and #Vairi.Lines.stalks > 0 and #Vairi.Lines.felled > 0 and #Vairi.Lines.stolen > 0)

print(string.format("\n%d passed, %d failed", passed, failed))
if failed > 0 then
	print("FAILURES: " .. table.concat(failures, ", "))
	process.exit(1)
end
