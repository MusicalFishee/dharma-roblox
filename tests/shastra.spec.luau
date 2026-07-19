--!strict
-- Headless tests for Shastra-Vidya: the blade's ladder and its honest kicker.

local process = require("@lune/process")
local Shastra = require("../src/shared/Shastra")

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

print("Shastra")

-- The ladder is well-built.
local ascending = true
for i = 2, #Shastra.Ranks do
	if Shastra.Ranks[i].xp <= Shastra.Ranks[i - 1].xp then
		ascending = false
	end
end
check("the ladder climbs, never dips", ascending)
check("every rung is named and spoken", (function()
	for _, def in Shastra.Ranks do
		if #def.name == 0 or #def.line == 0 then
			return false
		end
	end
	return true
end)())
check("the first day costs nothing", Shastra.Ranks[1].xp == 0)

-- Rank math.
check("a fresh blade is Shishya", Shastra.rankFor(0) == 1)
check("the threshold turns the rank", Shastra.rankFor(Shastra.Ranks[2].xp) == 2 and Shastra.rankFor(Shastra.Ranks[2].xp - 1) == 1)
check("the summit holds", Shastra.rankFor(999999) == #Shastra.Ranks)
check("junk xp stays a student", Shastra.rankFor(-50) == 1 and Shastra.rankFor(0 / 0) == 1)

-- Standing.
local mid = Shastra.resolve(Shastra.Ranks[3].xp)
check("standing names the rung and the next", mid.rank == 3 and mid.nextAt == Shastra.Ranks[4].xp)
check("the summit has no next", Shastra.resolve(Shastra.Ranks[#Shastra.Ranks].xp).nextAt == nil)

-- The kicker: small, honest, capped.
check("the first day kicks nothing", Shastra.damageMult(1) == 1)
check("each rung deepens the hand", Shastra.damageMult(3) > Shastra.damageMult(2))
check("the summit caps the kicker", Shastra.damageMult(#Shastra.Ranks) <= 1.1 and Shastra.damageMult(99) == Shastra.damageMult(#Shastra.Ranks))

-- The feed constants earn slow (mastery is a road, not a weekend).
check("hits feed drops, kills feed sips", Shastra.XpPerHit < Shastra.XpPerKill and Shastra.XpPerHit > 0)

print(string.format("\n%d passed, %d failed", passed, failed))
if failed > 0 then
	print("FAILURES: " .. table.concat(failures, ", "))
	process.exit(1)
end
