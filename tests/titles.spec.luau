--!strict
-- Titles: catalog sanity, unlock math per requirement kind, equip validation,
-- and the chat-colour hex.

local process = require("@lune/process")
local Titles = require("../src/shared/Titles")
local Grantha = require("../src/shared/Grantha")

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

local function snap(over: { [string]: number }): Titles.Snapshot
	local s: Titles.Snapshot = { bestWave = 0, kills = 0, bossKills = 0, level = 1, trials = 0, duelWins = 0, raidClears = 0, revives = 0, deerKills = 0, bladeMastery = 1, loreTurned = 0, playtimeSeconds = 0, deaths = 0, bladesMastered = 0 }
	for k, v in over do
		(s :: any)[k] = v
	end
	return s
end

print("Titles")

-- Catalog shape.
check("there are titles worth chasing", #Titles.List >= 6)
local ids: { [string]: boolean } = {}
local unique, wellFormed = true, true
local knownKinds = { wave = true, kills = true, bossKills = true, level = true, trials = true, duelWins = true, raidClears = true, revives = true, deerKills = true, bladeMastery = true, loreTurned = true, playtime = true, deaths = true, bladesMastered = true, capstone = true }
for _, def in Titles.List do
	if ids[def.id] then
		unique = false
	end
	ids[def.id] = true
	if def.name == "" or def.requirement == "" or def.threshold <= 0 or #def.color ~= 3 or not knownKinds[def.kind] then
		wellFormed = false
	end
end
check("title ids are unique", unique)
check("every title is well-formed with a known kind", wellFormed)

-- Every kind is represented (each stat line has something to chase).
local kindsSeen: { [string]: boolean } = {}
for _, def in Titles.List do
	kindsSeen[def.kind] = true
end
check("every requirement kind is used", kindsSeen.wave == true and kindsSeen.kills == true and kindsSeen.bossKills == true and kindsSeen.level == true and kindsSeen.trials == true and kindsSeen.duelWins == true and kindsSeen.raidClears == true and kindsSeen.revives == true)
check("the new roads award titles too", kindsSeen.deerKills == true and kindsSeen.bladeMastery == true and kindsSeen.loreTurned == true)

-- The new titles unlock off their derived stats.
check("the golden hunter counts deer", Titles.isUnlocked(Titles.get("golden_hunter") :: any, snap({ deerKills = 25 })) and not Titles.isUnlocked(Titles.get("golden_hunter") :: any, snap({ deerKills = 24 })))
check("blade-soul needs the summit rank", Titles.isUnlocked(Titles.get("one_with_the_blade") :: any, snap({ bladeMastery = 5 })) and not Titles.isUnlocked(Titles.get("one_with_the_blade") :: any, snap({ bladeMastery = 4 })))
check("the loremaster turns every page", Titles.isUnlocked(Titles.get("loremaster") :: any, snap({ loreTurned = Grantha.MaxTurned })) and not Titles.isUnlocked(Titles.get("loremaster") :: any, snap({ loreTurned = Grantha.MaxTurned - 1 })))
-- If a family is ever added, this fails until the loremaster's bar is raised.
check("the loremaster's bar tracks the whole book", (Titles.get("loremaster") :: any).threshold == Grantha.MaxTurned)

-- THE CAPSTONE LAW: Moksha is the sum of every other title, and it must grow
-- on its own. This proves it reacts to each title individually — so any
-- title added anywhere is automatically one more thing the capstone demands,
-- and this test extends to cover it with zero edits.
local kindField = { wave = "bestWave", kills = "kills", bossKills = "bossKills", level = "level", trials = "trials", duelWins = "duelWins", raidClears = "raidClears", revives = "revives", deerKills = "deerKills", bladeMastery = "bladeMastery", loreTurned = "loreTurned", playtime = "playtimeSeconds", deaths = "deaths", bladesMastered = "bladesMastered" }
local function maxedSnap(): Titles.Snapshot
	return snap({ bestWave = 9999, kills = 9999999, bossKills = 9999, level = 9999, trials = 9999, duelWins = 9999, raidClears = 9999, revives = 9999, deerKills = 9999, bladeMastery = 99, loreTurned = 9999, playtimeSeconds = 99999999, deaths = 9999999, bladesMastered = 999 })
end
local moksha = Titles.get("moksha") :: any
check("Moksha exists and is the capstone", moksha ~= nil and moksha.kind == "capstone")
check("liberation comes only when every path is complete", Titles.isUnlocked(moksha, maxedSnap()))
check("a fresh soul is still bound to the wheel", not Titles.isUnlocked(moksha, snap({})))

local reactsToAll = true
local coveredKinds = true
for _, def in Titles.List do
	if def.kind == "capstone" then
		continue
	end
	local field = kindField[def.kind]
	if not field then
		coveredKinds = false
		continue
	end
	local s = maxedSnap();
	(s :: any)[field] = def.threshold - 1
	if Titles.isUnlocked(moksha, s) then
		reactsToAll = false
		print("    !! the capstone ignores: " .. def.id)
	end
end
check("the capstone knows every field its titles read", coveredKinds)
check("the capstone reacts to every single title (self-updating)", reactsToAll)

local earned, total = Titles.earnedCount(maxedSnap())
check("earnedCount sees all parts", earned == total and total == #Titles.List - 1)
check("earnedCount starts near zero", (select(1, Titles.earnedCount(snap({})))) == 0)

-- Unlock math, one per kind.
local dharmapala = Titles.get("dharmapala") :: Titles.TitleDef
check("wave title locked shallow", Titles.isUnlocked(dharmapala, snap({ bestWave = 49 })) == false)
check("wave title unlocks at the wall", Titles.isUnlocked(dharmapala, snap({ bestWave = 50 })) == true)
local blooded = Titles.get("blooded") :: Titles.TitleDef
check("kill title counts kills", Titles.isUnlocked(blooded, snap({ kills = 100 })) and not Titles.isUnlocked(blooded, snap({ kills = 99 })))
local lordFeller = Titles.get("lord_feller") :: Titles.TitleDef
check("boss title counts boss kills", Titles.isUnlocked(lordFeller, snap({ bossKills = 10 })) and not Titles.isUnlocked(lordFeller, snap({ kills = 999 })))
local maharathi = Titles.get("maharathi") :: Titles.TitleDef
check("level title reads level", Titles.isUnlocked(maharathi, snap({ level = 30 })) and not Titles.isUnlocked(maharathi, snap({ level = 29 })))
local blessed = Titles.get("blessed_mahadeva") :: Titles.TitleDef
check("trial title needs the trial", Titles.isUnlocked(blessed, snap({ trials = 1 })) and not Titles.isUnlocked(blessed, snap({ bestWave = 100 })))
local duelist = Titles.get("duelist") :: Titles.TitleDef
check("duelist counts duel wins", Titles.isUnlocked(duelist, snap({ duelWins = 10 })) and not Titles.isUnlocked(duelist, snap({ duelWins = 9, kills = 9999 })))
local ravanaBane = Titles.get("ravana_bane") :: Titles.TitleDef
check("raid title counts raid clears", Titles.isUnlocked(ravanaBane, snap({ raidClears = 1 })) and not Titles.isUnlocked(ravanaBane, snap({ bossKills = 999 })))
local uddharaHand = Titles.get("uddhara_hand") :: Titles.TitleDef
check("lift title counts revives", Titles.isUnlocked(uddharaHand, snap({ revives = 10 })) and not Titles.isUnlocked(uddharaHand, snap({ revives = 9 })))

-- Equip validation.
check("bare head is always allowed", Titles.canEquip("", snap({})))
check("earned title equips", Titles.canEquip("blooded", snap({ kills = 500 })))
check("unearned title is refused", Titles.canEquip("dharmapala", snap({ bestWave = 10 })) == false)
check("junk id is refused", Titles.canEquip("supreme_gamer", snap({ kills = 99999 })) == false)

-- Chat colour hex.
check("colorHex is 6 lowercase hex chars", string.match(Titles.colorHex(dharmapala), "^%x%x%x%x%x%x$") ~= nil)
check("colorHex encodes the rgb", Titles.colorHex(dharmapala) == string.format("%02x%02x%02x", dharmapala.color[1], dharmapala.color[2], dharmapala.color[3]))

print(string.format("\n%d passed, %d failed", passed, failed))
if failed > 0 then
	print("FAILURES: " .. table.concat(failures, ", "))
	process.exit(1)
end
