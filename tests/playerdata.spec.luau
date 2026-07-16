--!strict
-- Headless tests for the saved-data schema + validation (corruption safety).

local process = require("@lune/process")
local PlayerData = require("../src/shared/PlayerData")
local Shop = require("../src/shared/Shop")
local Weapons = require("../src/shared/Weapons")

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

print("PlayerData")

check("default starts at 0 XP", PlayerData.default().totalXp == 0)
check("default has version", PlayerData.default().version == PlayerData.Version)

-- Validation is the corruption net.
check("nil -> default", PlayerData.validate(nil).totalXp == 0)
check("string junk -> default", PlayerData.validate("hacked").totalXp == 0)
check("valid xp preserved", PlayerData.validate({ totalXp = 1234 }).totalXp == 1234)
check("negative xp rejected", PlayerData.validate({ totalXp = -50 }).totalXp == 0)
check("non-number xp rejected", PlayerData.validate({ totalXp = "9999" }).totalXp == 0)
check("float xp floored", PlayerData.validate({ totalXp = 500.9 }).totalXp == 500)
check("missing field filled", PlayerData.validate({}).totalXp == 0)
check("extra fields ignored", PlayerData.validate({ totalXp = 10, hacked = true }).totalXp == 10)

-- Gold field (added with the loot system).
check("default gold is 0", PlayerData.default().gold == 0)
check("valid gold preserved", PlayerData.validate({ gold = 550 }).gold == 550)
check("negative gold rejected", PlayerData.validate({ gold = -10 }).gold == 0)
check("junk gold rejected", PlayerData.validate({ gold = "rich" }).gold == 0)

-- Upgrades (added with the shop).
check("default upgrades are 0", PlayerData.default().upgrades.damage == 0 and PlayerData.default().upgrades.health == 0)
check("valid upgrades preserved", PlayerData.validate({ upgrades = { damage = 3, health = 5 } }).upgrades.damage == 3)
check("junk upgrades rejected", PlayerData.validate({ upgrades = { damage = "max", health = -2 } }).upgrades.damage == 0)
check("upgrade tiers cap at Shop.MaxTier", PlayerData.validate({ upgrades = { damage = 99, health = 0 } }).upgrades.damage == Shop.MaxTier)
check("missing upgrades table -> defaults", PlayerData.validate({ totalXp = 5 }).upgrades.health == 0)

-- Serialize snapshots cleanly.
check("serialize floors + clamps", PlayerData.serialize(-3, 0).totalXp == 0 and PlayerData.serialize(42.7, 0).totalXp == 42)
check("serialize gold floors + clamps", PlayerData.serialize(0, -9).gold == 0 and PlayerData.serialize(0, 12.9).gold == 12)
local rt = PlayerData.validate(PlayerData.serialize(777, 321, { damage = 2, health = 7 }, 14))
check("serialize round-trips through validate", rt.totalXp == 777 and rt.gold == 321 and rt.upgrades.health == 7 and rt.bestWave == 14)
check("serialize without upgrades defaults them", PlayerData.serialize(1, 1).upgrades.damage == 0)

-- Best wave (added with leaderboards).
check("default bestWave is 0", PlayerData.default().bestWave == 0)
check("valid bestWave preserved", PlayerData.validate({ bestWave = 23 }).bestWave == 23)
check("junk bestWave rejected", PlayerData.validate({ bestWave = -4 }).bestWave == 0 and PlayerData.validate({ bestWave = "deep" }).bestWave == 0)
check("serialize without bestWave defaults 0", PlayerData.serialize(1, 1).bestWave == 0)

-- Quests (added with the quest system).
check("default quests empty", #PlayerData.default().quests == 0)
local qv = PlayerData.validate({ quests = { { id = "slay_asura", progress = 4 }, { id = "gold_hoard", progress = "junk" } } })
check("valid quest slots preserved", #qv.quests == 2 and qv.quests[1].id == "slay_asura" and qv.quests[1].progress == 4)
check("junk quest progress -> 0", qv.quests[2].progress == 0)
check("non-table quests rejected", #PlayerData.validate({ quests = "all" }).quests == 0)
local qrt = PlayerData.validate(PlayerData.serialize(0, 0, nil, 0, { { id = "parry_master", progress = 2 } }))
check("quests round-trip through serialize", #qrt.quests == 1 and qrt.quests[1].id == "parry_master" and qrt.quests[1].progress == 2)

-- Weapon (added with the weapon system).
check("default weapon is unchosen at tier 1", PlayerData.default().weapon.id == "" and PlayerData.default().weapon.tier == 1)
local wv = PlayerData.validate({ weapon = { id = "khanda", tier = 3 } })
check("valid weapon preserved", wv.weapon.id == "khanda" and wv.weapon.tier == 3)
check("non-table weapon -> unchosen", PlayerData.validate({ weapon = "sword" }).weapon.id == "")
check("weapon without string id -> unchosen", PlayerData.validate({ weapon = { tier = 2 } }).weapon.id == "")
check("weapon tier clamps to Weapons.MaxTier", PlayerData.validate({ weapon = { id = "gada", tier = 999 } }).weapon.tier == Weapons.MaxTier)
check("weapon tier floors up to MinTier", PlayerData.validate({ weapon = { id = "gada", tier = 0 } }).weapon.tier == 1)
check("junk weapon tier -> MinTier", PlayerData.validate({ weapon = { id = "gada", tier = "sharp" } }).weapon.tier == 1)
local wrt = PlayerData.validate(PlayerData.serialize(0, 0, nil, 0, nil, { id = "chakram", tier = 4 }))
check("weapon round-trips through serialize", wrt.weapon.id == "chakram" and wrt.weapon.tier == 4)
check("serialize without weapon -> unchosen tier 1", PlayerData.serialize(1, 1).weapon.id == "" and PlayerData.serialize(1, 1).weapon.tier == 1)

-- Shards + enchant (added with the mantra system).
check("default shards 0, no mantra", PlayerData.default().shards == 0 and PlayerData.default().enchant == "")
check("valid shards preserved", PlayerData.validate({ shards = 12 }).shards == 12)
check("negative/junk shards rejected", PlayerData.validate({ shards = -3 }).shards == 0 and PlayerData.validate({ shards = "lots" }).shards == 0)
check("float shards floored", PlayerData.validate({ shards = 5.9 }).shards == 5)
check("valid enchant preserved", PlayerData.validate({ enchant = "yama_ledger" }).enchant == "yama_ledger")
check("non-string enchant rejected", PlayerData.validate({ enchant = 7 }).enchant == "")
check("oversized enchant rejected", PlayerData.validate({ enchant = string.rep("x", 41) }).enchant == "")
local ert = PlayerData.validate(PlayerData.serialize(0, 0, nil, 0, nil, nil, 9, "trinetra"))
check("shards + enchant round-trip through serialize", ert.shards == 9 and ert.enchant == "trinetra")
check("serialize without them defaults 0 + empty", PlayerData.serialize(1, 1).shards == 0 and PlayerData.serialize(1, 1).enchant == "")

-- Lifetime stats (added with the stats page).
local sd = PlayerData.default().stats
check("default stats all zero", sd.kills == 0 and sd.bossKills == 0 and sd.deaths == 0 and sd.playtimeSeconds == 0)
local sv = PlayerData.validate({ stats = { kills = 250, bossKills = 12, deaths = 9, playtimeSeconds = 7300 } })
check("valid stats preserved", sv.stats.kills == 250 and sv.stats.bossKills == 12 and sv.stats.deaths == 9 and sv.stats.playtimeSeconds == 7300)
local sj = PlayerData.validate({ stats = { kills = -5, bossKills = "many", deaths = 2.9, playtimeSeconds = 0 / 0 } })
check("junk stats cleaned per-field", sj.stats.kills == 0 and sj.stats.bossKills == 0 and sj.stats.deaths == 2 and sj.stats.playtimeSeconds == 0)
check("non-table stats -> defaults", PlayerData.validate({ stats = "grinding" }).stats.kills == 0)
local srt = PlayerData.validate(PlayerData.serialize(0, 0, nil, 0, nil, nil, 0, "", { kills = 42, bossKills = 3, deaths = 1, playtimeSeconds = 999 }))
check("stats round-trip through serialize", srt.stats.kills == 42 and srt.stats.bossKills == 3 and srt.stats.deaths == 1 and srt.stats.playtimeSeconds == 999)
check("serialize without stats -> zeros", PlayerData.serialize(1, 1).stats.kills == 0 and PlayerData.serialize(1, 1).stats.playtimeSeconds == 0)

-- Dailies (added with daily trials).
check("default dailies are stale and empty", PlayerData.default().dailies.stamp == 0 and #PlayerData.default().dailies.slots == 0)
local dv = PlayerData.validate({ dailies = { stamp = 20650, slots = { { id = "daily_lords", progress = 2, done = false }, { id = "daily_gold", progress = 600, done = true } } } })
check("valid dailies preserved", dv.dailies.stamp == 20650 and #dv.dailies.slots == 2 and dv.dailies.slots[1].id == "daily_lords" and dv.dailies.slots[1].progress == 2)
check("done flag survives", dv.dailies.slots[2].done == true and dv.dailies.slots[1].done == false)
local dj = PlayerData.validate({ dailies = { stamp = "today", slots = { { id = 42, progress = 1 }, { id = "x", progress = "some", done = "yes" } } } })
check("junk dailies cleaned per-field", dj.dailies.stamp == 0 and #dj.dailies.slots == 1 and dj.dailies.slots[1].progress == 0 and dj.dailies.slots[1].done == false)
check("non-table dailies -> defaults", PlayerData.validate({ dailies = "reset" }).dailies.stamp == 0)
local drt = PlayerData.validate(PlayerData.serialize(0, 0, nil, 0, nil, nil, 0, "", nil, { stamp = 7, slots = { { id = "daily_parry", progress = 5, done = false } } }))
check("dailies round-trip through serialize", drt.dailies.stamp == 7 and drt.dailies.slots[1].id == "daily_parry" and drt.dailies.slots[1].progress == 5)
check("serialize without dailies -> stale empty", PlayerData.serialize(1, 1).dailies.stamp == 0 and #PlayerData.serialize(1, 1).dailies.slots == 0)

-- Title + trialsPassed (added with the title system).
check("default title empty, no trials", PlayerData.default().title == "" and PlayerData.default().stats.trialsPassed == 0)
check("valid title preserved", PlayerData.validate({ title = "dharmapala" }).title == "dharmapala")
check("junk title rejected", PlayerData.validate({ title = 42 }).title == "" and PlayerData.validate({ title = string.rep("t", 41) }).title == "")
check("trialsPassed validated", PlayerData.validate({ stats = { trialsPassed = 3 } }).stats.trialsPassed == 3 and PlayerData.validate({ stats = { trialsPassed = -1 } }).stats.trialsPassed == 0)
check("duelWins validated + defaulted", PlayerData.validate({ stats = { duelWins = 7 } }).stats.duelWins == 7 and PlayerData.default().stats.duelWins == 0 and PlayerData.validate({ stats = { duelWins = "lots" } }).stats.duelWins == 0)
check("revives validated + defaulted", PlayerData.validate({ stats = { revives = 4 } }).stats.revives == 4 and PlayerData.default().stats.revives == 0 and PlayerData.validate({ stats = { revives = -2 } }).stats.revives == 0)
local trt = PlayerData.validate(PlayerData.serialize(0, 0, nil, 0, nil, nil, 0, "", { kills = 0, bossKills = 0, deaths = 0, playtimeSeconds = 0, trialsPassed = 2 }, nil, "blessed_mahadeva"))
check("title + trials round-trip through serialize", trt.title == "blessed_mahadeva" and trt.stats.trialsPassed == 2)

-- Astra Path (added with the path system, v9).
check("default path empty", PlayerData.default().path == "")
check("valid path preserved", PlayerData.validate({ path = "agni" }).path == "agni")
check("junk path rejected", PlayerData.validate({ path = 42 }).path == "" and PlayerData.validate({ path = string.rep("p", 21) }).path == "")
local prt = PlayerData.validate(PlayerData.serialize(0, 0, nil, 0, nil, nil, 0, "", nil, nil, "", "varuna"))
check("path round-trips through serialize", prt.path == "varuna")
check("serialize without path -> unsworn", PlayerData.serialize(1, 1).path == "")

-- Relics (added with the relic system, v10).
local rdef = PlayerData.default().relics
check("default satchel empty + bare", #rdef.owned == 0 and rdef.equipped.crown == "" and rdef.equipped.kavacha == "" and rdef.equipped.charm == "")
local rval = PlayerData.validate({ relics = { owned = { "baka_crown", "baka_crown", 42, "charm_vetala" }, equipped = { crown = "baka_crown", kavacha = 7 } } })
check("owned dedupes + drops junk", #rval.relics.owned == 2 and rval.relics.owned[1] == "baka_crown" and rval.relics.owned[2] == "charm_vetala")
check("equipped keeps strings, clears junk", rval.relics.equipped.crown == "baka_crown" and rval.relics.equipped.kavacha == "")
local overfull = {}
for i = 1, 60 do
	table.insert(overfull, "relic" .. i)
end
check("owned capped at 40", #PlayerData.validate({ relics = { owned = overfull } }).relics.owned == 40)
local rrt = PlayerData.validate(PlayerData.serialize(0, 0, nil, 0, nil, nil, 0, "", nil, nil, "", "", { owned = { "mahisha_crown" }, equipped = { crown = "mahisha_crown", kavacha = "", charm = "" } }))
check("relics round-trip through serialize", #rrt.relics.owned == 1 and rrt.relics.equipped.crown == "mahisha_crown")

-- Story (added with the Adhyayas, v12).
check("default story untold", PlayerData.default().story == 0)
check("story validated", PlayerData.validate({ story = 4 }).story == 4 and PlayerData.validate({ story = -2 }).story == 0 and PlayerData.validate({ story = 999 }).story == 50)
check("raidClears validated", PlayerData.validate({ stats = { raidClears = 2 } }).stats.raidClears == 2 and PlayerData.default().stats.raidClears == 0)
local srt = PlayerData.validate(PlayerData.serialize(0, 0, nil, 0, nil, nil, 0, "", nil, nil, "", "", nil, 6))
check("story round-trips through serialize", srt.story == 6)

print(string.format("\n%d passed, %d failed", passed, failed))
if failed > 0 then
	print("FAILURES: " .. table.concat(failures, ", "))
	process.exit(1)
end
