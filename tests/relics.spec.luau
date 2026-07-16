--!strict
-- Headless tests for relics: catalog + set integrity, boss drop tables, drop
-- rolls, equip gating, and the merged stat block the services read.

local process = require("@lune/process")
local Relics = require("../src/shared/Relics")
local Bosses = require("../src/shared/Bosses")
local Waves = require("../src/shared/Waves")

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

-- An rng that replays a fixed sequence (rollDrop consumes: chance, then index).
local function seq(values: { number }): () -> number
	local i = 0
	return function()
		i += 1
		return values[math.min(i, #values)]
	end
end

print("Relics")

-- Catalog integrity.
local slots = { crown = true, kavacha = true, charm = true }
local defsValid = true
local raritiesColored = true
for id, def in Relics.Defs do
	if def.id ~= id or not slots[def.slot] or #def.name == 0 or #def.line == 0 then
		defsValid = false
	end
	if not Relics.RarityColor[def.rarity] then
		raritiesColored = false
	end
	if def.setId and not Relics.Sets[def.setId] then
		defsValid = false
	end
end
check("defs are well-formed", defsValid)
check("every rarity has a color", raritiesColored)

-- Set integrity: pieces exist and point back at their set.
local setsValid = true
for setId, set in Relics.Sets do
	if set.id ~= setId or #set.pieces < 2 then
		setsValid = false
	end
	for _, pieceId in set.pieces do
		local def = Relics.Defs[pieceId]
		if not def or def.setId ~= setId then
			setsValid = false
		end
	end
end
check("sets are well-formed", setsValid)
check("ravana set has 3 pieces + a 3-piece bonus", #Relics.Sets.ravana.pieces == 3 and Relics.Sets.ravana.bonus3 ~= nil)

-- Every wave boss the roster can serve up has relics to drop.
local bossesCovered = true
local seenBossIds: { [string]: boolean } = {}
for encounter = 1, 8 do
	local boss = Bosses.forWave(encounter * Waves.BossInterval, Waves.BossInterval)
	if not seenBossIds[boss.id] then
		seenBossIds[boss.id] = true
		if #Relics.dropsFor(boss.id) == 0 then
			bossesCovered = false
		end
	end
end
check("every roster boss has a drop table", bossesCovered)
check("unknown boss drops nothing", #Relics.dropsFor("Shiva") == 0)

-- Drop-table pieces all exist; charms are charms.
local dropsValid = true
for _, list in Relics.BossDrops do
	for _, id in list do
		if not Relics.isValidId(id) then
			dropsValid = false
		end
	end
end
for _, id in Relics.CharmDrops do
	if Relics.slotOf(id) ~= "charm" then
		dropsValid = false
	end
end
check("drop tables reference real relics", dropsValid)

-- Drop rolls.
check("roll above chance drops nothing", Relics.rollDrop({ "baka_crown" }, {}, 0.25, seq({ 0.9 })) == nil)
check("empty candidate pool drops nothing", Relics.rollDrop({}, {}, 1, seq({ 0 })) == nil)

local fresh = Relics.rollDrop({ "baka_crown", "baka_kavacha" }, {}, 0.25, seq({ 0, 0 }))
check("winning roll yields a piece", fresh ~= nil and fresh.id == "baka_crown" and not fresh.dupe)

local prefers = Relics.rollDrop({ "baka_crown", "baka_kavacha" }, { "baka_crown" }, 0.25, seq({ 0, 0 }))
check("roll prefers unowned pieces", prefers ~= nil and prefers.id == "baka_kavacha" and not prefers.dupe)

local dupe = Relics.rollDrop({ "baka_crown", "baka_kavacha" }, { "baka_crown", "baka_kavacha" }, 0.25, seq({ 0, 0.99 }))
check("fully-owned pool comes up duplicate", dupe ~= nil and dupe.dupe and Relics.isValidId(dupe.id))

-- Satchel rules.
check("cannot own the same relic twice", not Relics.canAddOwned({ "baka_crown" }, "baka_crown"))
check("junk ids cannot be owned", not Relics.canAddOwned({}, "excalibur"))
local full: { string } = {}
for i = 1, Relics.MaxOwned do
	table.insert(full, "slot" .. i)
end
check("satchel caps at MaxOwned", not Relics.canAddOwned(full, "baka_crown"))

-- equippedList filters bare slots.
local worn = Relics.equippedList({ crown = "baka_crown", kavacha = "", charm = "charm_vetala" })
check("equippedList skips bare slots", #worn == 2 and worn[1] == "baka_crown" and worn[2] == "charm_vetala")

-- Merged bonuses.
local none = Relics.totalBonus({})
check("bare = identity bonus", none.damageMult == 1 and none.healthBonus == 0 and none.goldMult == 1 and none.critChance == 0 and none.tejasMult == 1 and none.damageTakenMult == 1)

local one = Relics.totalBonus({ "mahisha_crown" })
check("single piece applies", math.abs(one.damageMult - 1.04) < 1e-9)

local stacked = Relics.totalBonus({ "mahisha_crown", "taraka_kavacha" })
check("multipliers stack multiplicatively", math.abs(stacked.damageMult - 1.04 * 1.03) < 1e-9)

local pair = Relics.totalBonus({ "mahisha_crown", "mahisha_kavacha" })
check("2-piece set bonus triggers", math.abs(pair.damageMult - 1.04 * 1.08) < 1e-9 and pair.healthBonus == 20)

local dupes = Relics.totalBonus({ "mahisha_crown", "mahisha_crown" })
check("duplicate ids count once (no set from one piece)", math.abs(dupes.damageMult - 1.04) < 1e-9)

local dashanana = Relics.totalBonus({ "ravana_crown", "ravana_kavacha", "ravana_charm" })
check("ravana 3-piece stacks bonus2 + bonus3", math.abs(dashanana.damageMult - 1.08 * 1.10 * 1.05) < 1e-9 and math.abs(dashanana.damageTakenMult - 0.90 * 0.95) < 1e-9 and math.abs(dashanana.critChance - 0.08) < 1e-9)

check("junk ids are skipped", Relics.totalBonus({ "excalibur" }).damageMult == 1)

-- Equip gating.
check("equip needs a real slot", not Relics.tryEquip({}, "boots", "baka_crown").ok)
check("equip needs a real relic", Relics.tryEquip({}, "crown", "excalibur").reason == "unknown")
check("equip needs the right slot", Relics.tryEquip({ "baka_crown" }, "kavacha", "baka_crown").reason == "slot")
check("equip needs ownership", Relics.tryEquip({}, "crown", "baka_crown").reason == "unowned")
check("owned relic equips into its slot", Relics.tryEquip({ "baka_crown" }, "crown", "baka_crown").ok)
check("bare id unequips fine", Relics.tryEquip({}, "crown", "").ok)

print(string.format("\n%d passed, %d failed", passed, failed))
if failed > 0 then
	print("FAILURES: " .. table.concat(failures, ", "))
	process.exit(1)
end
