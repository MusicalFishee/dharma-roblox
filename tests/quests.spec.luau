--!strict
-- Headless tests for the quest brain.

local process = require("@lune/process")
local Quests = require("../src/shared/Quests")

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

print("Quests")

-- Catalog well-formed; Order covers exactly the catalog.
local catalogCount = 0
local allValid = true
for id, q in Quests.Catalog do
	catalogCount += 1
	if q.id ~= id or q.goal <= 0 or (q.rewardGold <= 0 and q.rewardXp <= 0) or #q.title == 0 or #q.desc == 0 then
		allValid = false
	end
end
check("catalog has 10 quests", catalogCount == 10)
check("all quests well-formed with rewards", allValid)
check("Order matches catalog size", #Quests.Order == catalogCount)
local orderValid = true
for _, id in Quests.Order do
	if not Quests.Catalog[id] then
		orderValid = false
	end
end
check("every Order id exists in catalog", orderValid)

-- Kill matching.
local asuraKill: Quests.Event = { type = "kill", enemyId = "Asura", isBoss = false }
local bossKill: Quests.Event = { type = "kill", enemyId = "Mahishasura", isBoss = true }
check("Asura kill advances slay_asura", Quests.increment(Quests.Catalog.slay_asura, asuraKill) == 1)
check("Asura kill does not advance slay_vetala", Quests.increment(Quests.Catalog.slay_vetala, asuraKill) == 0)
check("any kill advances slay_any", Quests.increment(Quests.Catalog.slay_any, asuraKill) == 1 and Quests.increment(Quests.Catalog.slay_any, bossKill) == 1)
check("only boss kills advance boss_slayer", Quests.increment(Quests.Catalog.boss_slayer, asuraKill) == 0 and Quests.increment(Quests.Catalog.boss_slayer, bossKill) == 1)

-- Other kinds.
check("parry advances parry_master only", Quests.increment(Quests.Catalog.parry_master, { type = "parry" }) == 1 and Quests.increment(Quests.Catalog.parry_master, asuraKill) == 0)
check("waveClear advances wave_warden", Quests.increment(Quests.Catalog.wave_warden, { type = "waveClear" }) == 1)
check("gold advances by amount", Quests.increment(Quests.Catalog.gold_hoard, { type = "gold", amount = 45 }) == 45)
check("ability advances astra_adept", Quests.increment(Quests.Catalog.astra_adept, { type = "ability" }) == 1)

-- Completion + clamping.
check("complete at goal", Quests.isComplete(Quests.Catalog.slay_rakshasa, 3))
check("not complete below goal", not Quests.isComplete(Quests.Catalog.slay_rakshasa, 2))
check("clampProgress caps at goal", Quests.clampProgress(Quests.Catalog.slay_asura, 999) == 8)
check("clampProgress rejects junk", Quests.clampProgress(Quests.Catalog.slay_asura, "lots") == 0 and Quests.clampProgress(Quests.Catalog.slay_asura, -5) == 0)

-- Drawing.
local drawn = Quests.draw({}, function(n)
	return 1
end)
check("draw returns first available deterministically", drawn == "slay_asura")
local drawn2 = Quests.draw({ "slay_asura" }, function(n)
	return 1
end)
check("draw excludes active ids", drawn2 == "slay_pisacha")
local all: { string } = {}
for _, id in Quests.Order do
	table.insert(all, id)
end
check("draw returns nil when pool exhausted", Quests.draw(all) == nil)

print(string.format("\n%d passed, %d failed", passed, failed))
if failed > 0 then
	print("FAILURES: " .. table.concat(failures, ", "))
	process.exit(1)
end
