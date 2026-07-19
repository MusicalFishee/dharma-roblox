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

-- Mastery (added with Astra Siddhis, v14).
local md = PlayerData.default().mastery
check("default mastery all zero", md.agni == 0 and md.vayu == 0 and md.varuna == 0 and md.indra == 0)
local mv = PlayerData.validate({ mastery = { agni = 1200, vayu = -5, varuna = "lots", indra = 88.9 } })
check("mastery validated per-path", mv.mastery.agni == 1200 and mv.mastery.vayu == 0 and mv.mastery.varuna == 0 and mv.mastery.indra == 88)
check("non-table mastery -> zeros", PlayerData.validate({ mastery = "maxed" }).mastery.agni == 0)
local mrt = PlayerData.validate(PlayerData.serialize(0, 0, nil, 0, nil, nil, 0, "", nil, nil, "", "", nil, 0, { agni = 777, vayu = 0, varuna = 3, indra = 0 }))
check("mastery round-trips through serialize", mrt.mastery.agni == 777 and mrt.mastery.varuna == 3)
check("serialize without mastery -> zeros", PlayerData.serialize(1, 1).mastery.indra == 0)

-- Agnihotra streak (added with the Bazaar, v15).
check("default streak unlit", PlayerData.default().streak.stamp == 0 and PlayerData.default().streak.count == 0)
local stv = PlayerData.validate({ streak = { stamp = 20651, count = 4 } })
check("valid streak preserved", stv.streak.stamp == 20651 and stv.streak.count == 4)
check("junk streak cleaned", PlayerData.validate({ streak = { stamp = -3, count = "forever" } }).streak.stamp == 0 and PlayerData.validate({ streak = "eternal" }).streak.count == 0)
local strt = PlayerData.validate(PlayerData.serialize(0, 0, nil, 0, nil, nil, 0, "", nil, nil, "", "", nil, 0, nil, { stamp = 20000, count = 7 }))
check("streak round-trips through serialize", strt.streak.stamp == 20000 and strt.streak.count == 7)

-- Adhyaya 0 flag (v16).
check("default lesson unlearned", PlayerData.default().tutorialDone == false)
check("finished lesson preserved", PlayerData.validate({ tutorialDone = true }).tutorialDone == true)
check("junk lesson flag -> unlearned", PlayerData.validate({ tutorialDone = "yes" }).tutorialDone == false and PlayerData.validate({ tutorialDone = 1 }).tutorialDone == false)
local turt = PlayerData.validate(PlayerData.serialize(0, 0, nil, 0, nil, nil, 0, "", nil, nil, "", "", nil, 0, nil, nil, true))
check("lesson flag round-trips through serialize", turt.tutorialDone == true)
check("serialize without the flag -> unlearned", PlayerData.serialize(1, 1).tutorialDone == false)

-- Vibhuti marks (v17).
check("default brow and air are bare", PlayerData.default().vibhuti.tilak == "" and PlayerData.default().vibhuti.aura == "")
local vbv = PlayerData.validate({ vibhuti = { tilak = "tilak_tripundra", aura = 42 } })
check("worn marks validate per-slot", vbv.vibhuti.tilak == "tilak_tripundra" and vbv.vibhuti.aura == "")
check("oversized marks are bared", PlayerData.validate({ vibhuti = { tilak = string.rep("m", 41) } }).vibhuti.tilak == "")
local vbrt = PlayerData.validate(PlayerData.serialize(0, 0, nil, 0, nil, nil, 0, "", nil, nil, "", "", nil, 0, nil, nil, false, { tilak = "tilak_bhasma", aura = "aura_ember" }))
check("marks round-trip through serialize", vbrt.vibhuti.tilak == "tilak_bhasma" and vbrt.vibhuti.aura == "aura_ember")

-- The weekly vow (v18).
check("default vow is unstamped and unkept", PlayerData.default().vrata.stamp == 0 and PlayerData.default().vrata.progress == 0 and PlayerData.default().vrata.kept == false)
local vrv = PlayerData.validate({ vrata = { stamp = 2951, progress = 120, kept = "yes" } })
check("vow validates per-field", vrv.vrata.stamp == 2951 and vrv.vrata.progress == 120 and vrv.vrata.kept == false)
local vrrt = PlayerData.validate(PlayerData.serialize(0, 0, nil, 0, nil, nil, 0, "", nil, nil, "", "", nil, 0, nil, nil, false, nil, { stamp = 2951, progress = 45, kept = true }))
check("vow round-trips through serialize", vrrt.vrata.stamp == 2951 and vrrt.vrata.progress == 45 and vrrt.vrata.kept == true)

-- The weekly deepest (v19).
check("default weekly is unstamped", PlayerData.default().weekly.stamp == 0 and PlayerData.default().weekly.wave == 0)
check("weekly validates per-field", PlayerData.validate({ weekly = { stamp = 2951, wave = 34 } }).weekly.wave == 34 and PlayerData.validate({ weekly = { stamp = -1, wave = "deep" } }).weekly.wave == 0)
local wkrt = PlayerData.validate(PlayerData.serialize(0, 0, nil, 0, nil, nil, 0, "", nil, nil, "", "", nil, 0, nil, nil, false, nil, nil, { stamp = 2951, wave = 61 }))
check("weekly round-trips through serialize", wkrt.weekly.stamp == 2951 and wkrt.weekly.wave == 61)

-- Kirti claims (v20).
check("default ledger has no claims", next(PlayerData.default().kirti) == nil)
local kcv = PlayerData.validate({ kirti = { slayer = 2, lord_breaker = 99, [42] = 1 } })
check("claims validate and clamp per-deed", kcv.kirti.slayer == 2 and kcv.kirti.lord_breaker == 3)
local kcrt = PlayerData.validate(PlayerData.serialize(0, 0, nil, 0, nil, nil, 0, "", nil, nil, "", "", nil, 0, nil, nil, false, nil, nil, nil, { slayer = 3 }))
check("claims round-trip through serialize", kcrt.kirti.slayer == 3)

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

-- Loadouts (added with the gear sets, v21).
check("default has no loadouts", next(PlayerData.default().loadouts) == nil)
local lval = PlayerData.validate({ loadouts = {
	["1"] = { name = string.rep("x", 99), weapon = "talwar", crown = "baka_crown", kavacha = 7, charm = "" },
	["7"] = { name = "junk", weapon = "talwar" },
	["2"] = "junk",
	["3"] = { name = "no weapon", crown = "baka_crown" },
} })
check("a real slot survives with junk scrubbed", lval.loadouts["1"] ~= nil and lval.loadouts["1"].weapon == "talwar" and lval.loadouts["1"].kavacha == "" and lval.loadouts["1"].crown == "baka_crown")
check("vault names are capped", #lval.loadouts["1"].name <= 24)
check("only slots 1-3 exist", lval.loadouts["7"] == nil)
check("junk slots are refused", lval.loadouts["2"] == nil)
check("a loadout without a weapon is no loadout", lval.loadouts["3"] == nil)
local lrt = PlayerData.validate(PlayerData.serialize(0, 0, nil, 0, nil, nil, 0, "", nil, nil, "", "", nil, 0, nil, nil, false, nil, nil, nil, nil, { ["2"] = { name = "Boss Night", weapon = "chakram", crown = "", kavacha = "", charm = "" } }))
check("loadouts round-trip through serialize", lrt.loadouts["2"] ~= nil and lrt.loadouts["2"].weapon == "chakram" and lrt.loadouts["2"].name == "Boss Night")

-- The deer ledger (v22 — Maricha is counting).
check("default deer ledger empty", PlayerData.default().stats.deerKills == 0)
check("deerKills validated", PlayerData.validate({ stats = { deerKills = 7 } }).stats.deerKills == 7 and PlayerData.validate({ stats = { deerKills = -3 } }).stats.deerKills == 0)
local hunt = PlayerData.validate(PlayerData.serialize(0, 0, nil, 0, nil, nil, 0, "", { kills = 0, bossKills = 0, deaths = 0, playtimeSeconds = 0, trialsPassed = 0, duelWins = 0, raidClears = 0, revives = 0, deerKills = 12 }))
check("the deer ledger round-trips", hunt.stats.deerKills == 12)

-- The banner and the road (v23).
check("defaults march alone with an unwalked road", PlayerData.default().gana == "" and PlayerData.default().yatra == 0)
check("banner and road validate", PlayerData.validate({ gana = "Vira Sena", yatra = 4 }).gana == "Vira Sena" and PlayerData.validate({ yatra = -2 }).yatra == 0)
check("long banners are cut in the vault", #PlayerData.validate({ gana = string.rep("g", 99) }).gana == 20)
local road = PlayerData.validate(PlayerData.serialize(0, 0, nil, 0, nil, nil, 0, "", nil, nil, "", "", nil, 0, nil, nil, false, nil, nil, nil, nil, nil, "Nandi", 6))
check("banner and road round-trip", road.gana == "Nandi" and road.yatra == 6)

-- The book of foes (v24).
check("default book unread", next(PlayerData.default().granthaKills) == nil and next(PlayerData.default().granthaClaims) == nil)
local gval = PlayerData.validate({ granthaKills = { naga = 42 }, granthaClaims = { naga = 99, hima = -2 } })
check("kill ink validates", gval.granthaKills.naga == 42)
check("claims clamp to the three pages", gval.granthaClaims.naga == 3 and gval.granthaClaims.hima == 0)
local grt = PlayerData.validate(PlayerData.serialize(0, 0, nil, 0, nil, nil, 0, "", nil, nil, "", "", nil, 0, nil, nil, false, nil, nil, nil, nil, nil, "", 0, { lords = 7 }, { lords = 1 }))
check("the book round-trips", grt.granthaKills.lords == 7 and grt.granthaClaims.lords == 1)

-- The blade's ledger (v25).
check("default blades unlearned", next(PlayerData.default().shastra) == nil)
check("blade ink validates", PlayerData.validate({ shastra = { talwar = 500 } }).shastra.talwar == 500 and PlayerData.validate({ shastra = { talwar = -5 } }).shastra.talwar == 0)
local brt = PlayerData.validate(PlayerData.serialize(0, 0, nil, 0, nil, nil, 0, "", nil, nil, "", "", nil, 0, nil, nil, false, nil, nil, nil, nil, nil, "", 0, nil, nil, { chakram = 321 }))
check("the blade ledger round-trips", brt.shastra.chakram == 321)

-- The grudge ledger (v26).
check("default holds no grudge", PlayerData.default().vairi.id == "" and PlayerData.default().vairi.count == 0)
check("a grudge validates and clamps", PlayerData.validate({ vairi = { id = "Vetala", count = 99 } }).vairi.count == 20 and PlayerData.validate({ vairi = { id = "Vetala", count = 3 } }).vairi.id == "Vetala")
check("a bodiless grudge is no grudge", PlayerData.validate({ vairi = { id = "", count = 5 } }).vairi.count == 0)
local vrt2 = PlayerData.validate(PlayerData.serialize(0, 0, nil, 0, nil, nil, 0, "", nil, nil, "", "", nil, 0, nil, nil, false, nil, nil, nil, nil, nil, "", 0, nil, nil, nil, { id = "Pisacha", count = 2 }))
check("the grudge crosses the dark (round-trips)", vrt2.vairi.id == "Pisacha" and vrt2.vairi.count == 2)

-- The nemesis ledger (v27).
check("default nemesis ledger empty", PlayerData.default().stats.vairisFelled == 0)
check("vairisFelled validated", PlayerData.validate({ stats = { vairisFelled = 7 } }).stats.vairisFelled == 7 and PlayerData.validate({ stats = { vairisFelled = -3 } }).stats.vairisFelled == 0)
local grudged = PlayerData.validate(PlayerData.serialize(0, 0, nil, 0, nil, nil, 0, "", { kills = 0, bossKills = 0, deaths = 0, playtimeSeconds = 0, trialsPassed = 0, duelWins = 0, raidClears = 0, revives = 0, deerKills = 0, vairisFelled = 4 }))
check("the nemesis ledger round-trips", grudged.stats.vairisFelled == 4)

print(string.format("\n%d passed, %d failed", passed, failed))
if failed > 0 then
	print("FAILURES: " .. table.concat(failures, ", "))
	process.exit(1)
end
