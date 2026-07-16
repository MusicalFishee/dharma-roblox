--!strict
-- Daily trials: catalog sanity, UTC day-stamp math, the deterministic everyone-gets-
-- the-same-three pick, and event matching through the shared quest brain.

local process = require("@lune/process")
local Dailies = require("../src/shared/Dailies")
local Quests = require("../src/shared/Quests")
local EnemyTypes = require("../src/shared/EnemyTypes")

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

print("Dailies")

-- Catalog shape.
check("there are more dailies than active slots (variety)", #Dailies.Order > Dailies.ActiveCount)
local orderMatchesCatalog = true
local kindsKnown = true
local rewardsOk = true
local enemyIdsReal = true
local knownKinds = { kill = true, waveClear = true, parry = true, gold = true, ability = true }
for _, id in Dailies.Order do
	local def = Dailies.Catalog[id]
	if not def or def.id ~= id then
		orderMatchesCatalog = false
		continue
	end
	if not knownKinds[def.kind] then
		kindsKnown = false
	end
	if def.goal <= 0 or (def.rewardGold + def.rewardXp + def.rewardShards) <= 0 or def.rewardShards < 0 then
		rewardsOk = false
	end
	if def.enemyId and not EnemyTypes.List[def.enemyId] then
		enemyIdsReal = false
	end
end
check("Order and Catalog agree", orderMatchesCatalog)
check("every kind is one the event system emits", kindsKnown)
check("every daily has a goal and pays something", rewardsOk)
check("every archetype-hunt targets a real enemy", enemyIdsReal)
local shardTotal = 0
for _, id in Dailies.Order do
	shardTotal += Dailies.Catalog[id].rewardShards
end
check("at least one daily pays Vajra Shards", shardTotal > 0)

-- Day-stamp math (UTC midnight boundaries).
check("epoch is day 0", Dailies.dayStamp(0) == 0)
check("23:59:59 is still day 0", Dailies.dayStamp(86399) == 0)
check("midnight rolls the day", Dailies.dayStamp(86400) == 1)
check("negative junk clamps to day 0", Dailies.dayStamp(-5) == 0)

-- The deterministic pick.
local a = Dailies.forDay(20000)
local b = Dailies.forDay(20000)
check("same day -> same trials", table.concat(a, ",") == table.concat(b, ","))
check("a day picks exactly ActiveCount trials", #a == Dailies.ActiveCount)
local distinct = a[1] ~= a[2] and a[2] ~= a[3] and a[1] ~= a[3]
check("a day's trials are distinct", distinct)
local allValid = Dailies.get(a[1]) ~= nil and Dailies.get(a[2]) ~= nil and Dailies.get(a[3]) ~= nil
check("every picked id is a real daily", allValid)
local variety = false
local first = table.concat(Dailies.forDay(1), ",")
for stamp = 2, 10 do
	if table.concat(Dailies.forDay(stamp), ",") ~= first then
		variety = true
		break
	end
end
check("different days vary the set", variety)

-- Event matching rides Quests.increment (shared def shape).
local lords = Dailies.Catalog.daily_lords
check("boss kill advances the lord hunt", Quests.increment(lords :: any, { type = "kill", enemyId = "Asura", isBoss = true }) == 1)
check("grunt kill does not", Quests.increment(lords :: any, { type = "kill", enemyId = "Asura", isBoss = false }) == 0)
local elites = Dailies.Catalog.daily_elites
check("elite kill advances the elite hunt", Quests.increment(elites :: any, { type = "kill", enemyId = "Pisacha", isElite = true }) == 1)
check("plain kill does not", Quests.increment(elites :: any, { type = "kill", enemyId = "Pisacha" }) == 0)
check("eliteOnly never blocks regular quests", Quests.increment(Quests.Catalog.slay_any, { type = "kill", enemyId = "Asura" }) == 1)

-- Progress helpers.
check("clampProgress caps at the goal", Dailies.clampProgress(lords, 99) == lords.goal)
check("clampProgress swallows junk", Dailies.clampProgress(lords, "many") == 0 and Dailies.clampProgress(lords, -2) == 0)
check("isComplete at the goal", Dailies.isComplete(lords, lords.goal) and not Dailies.isComplete(lords, lords.goal - 1))

print(string.format("\n%d passed, %d failed", passed, failed))
if failed > 0 then
	print("FAILURES: " .. table.concat(failures, ", "))
	process.exit(1)
end
