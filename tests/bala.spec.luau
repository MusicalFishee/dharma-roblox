--!strict
-- Headless tests for Bala: the sangha meter fills only for the bonded, caps
-- honestly, and rewards support — never raw force.

local process = require("@lune/process")
local Bala = require("../src/shared/Bala")

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

print("Bala")

check("it takes two to make a sangha", Bala.Config.MinCluster == 2)
check("the rally is support, not a heal to full", Bala.Config.RallyHealFraction > 0 and Bala.Config.RallyHealFraction < 1)
check("the rally floods real Tejas", Bala.Config.RallyTejas > 0)

check("a lone warrior fills nothing", Bala.fillFor(1) == 0)
check("two shoulders begin to fill it", Bala.fillFor(2) > 0)
check("deeper clusters fill faster", Bala.fillFor(3) > Bala.fillFor(2))
check("the crowd bonus is capped", Bala.fillFor(9) == Bala.fillFor(2 + Bala.Config.MaxAllyFactor - 1))

check("adding climbs toward the brim", Bala.add(0, Bala.fillFor(2)) == Bala.fillFor(2))
check("the meter never overflows", Bala.add(Bala.Config.Max, 50) == Bala.Config.Max)
check("the meter never drops below empty", Bala.add(0, -50) == 0)

check("a brimming meter is full", Bala.isFull(Bala.Config.Max) and not Bala.isFull(Bala.Config.Max - 1))
check("the fraction spans zero to one", Bala.fraction(0) == 0 and Bala.fraction(Bala.Config.Max) == 1 and Bala.fraction(Bala.Config.Max * 2) == 1)

print(string.format("\n%d passed, %d failed", passed, failed))
if failed > 0 then
	print("FAILURES: " .. table.concat(failures, ", "))
	process.exit(1)
end
