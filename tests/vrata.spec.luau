--!strict
-- Headless tests for the weekly vow: week math, rotation, advance, rewards.

local process = require("@lune/process")
local Vrata = require("../src/shared/Vrata")
local Dailies = require("../src/shared/Dailies")

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

print("Vrata")

-- Week math.
check("a week is seven days", Vrata.weekStamp(86400 * 7) == 1 and Vrata.weekStamp(86400 * 7 - 1) == 0)
check("weeks march forward", Vrata.weekStamp(86400 * 70) == 10)

-- Catalog.
local kinds = { kill = true, bossKill = true, parry = true, waveClear = true, ability = true, gold = true }
local defsOk = true
local ids: { [string]: boolean } = {}
for _, def in Vrata.List do
	if ids[def.id] or not kinds[def.kind] or def.target <= 0 or #def.name == 0 or #def.line == 0 then
		defsOk = false
	end
	ids[def.id] = true
	if def.rewardGold <= 0 or def.rewardShards <= 0 then
		defsOk = false
	end
	-- The weekly prize must dwarf a daily's — it's a WEEK of devotion.
	if def.rewardShards < 10 then
		defsOk = false
	end
end
check("six vows, well-formed, weekly-sized prizes", defsOk and #Vrata.List == 6)

-- A vow is a WEEK of work, not an afternoon (rough sanity per kind).
check("the slayer vow outweighs a daily horde", Vrata.List[1].target > 100)

-- Rotation: deterministic, worldwide, and it cycles.
check("the same week names the same vow", Vrata.forWeek(2951).id == Vrata.forWeek(2951).id)
check("the rotation walks the list", Vrata.forWeek(0).id ~= Vrata.forWeek(1).id)
check("the rotation wraps", Vrata.forWeek(0).id == Vrata.forWeek(#Vrata.List).id)

-- Advance.
local slayer = Vrata.List[1]
local one = Vrata.advance(slayer, 0, "kill")
check("a matching event steps once", one.progress == 1 and not one.kept)
check("a foreign event steps nothing", Vrata.advance(slayer, 5, "parry").progress == 5)
local keptAt = Vrata.advance(slayer, slayer.target - 1, "kill")
check("the last step keeps the vow, exactly once", keptAt.kept and keptAt.progress == slayer.target)
check("a kept vow never re-keeps", not Vrata.advance(slayer, slayer.target, "kill").kept)

-- Gold vows count amounts, others count events.
local hoard = Vrata.List[6]
check("the hoard vow counts coins, not pickups", Vrata.advance(hoard, 0, "gold", 250).progress == 250)
check("negative coin never regresses", Vrata.advance(hoard, 100, "gold", -50).progress == 100)
check("the hoard clamps at its target", Vrata.advance(hoard, hoard.target - 10, "gold", 9999).progress == hoard.target)

-- The weekly stamp and the daily stamp share an epoch view (both UTC floors).
check("week 0 begins when day 0 begins", Vrata.weekStamp(0) == 0 and Dailies.dayStamp(0) == 0)

print(string.format("\n%d passed, %d failed", passed, failed))
if failed > 0 then
	print("FAILURES: " .. table.concat(failures, ", "))
	process.exit(1)
end
