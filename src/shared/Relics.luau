--!strict
-- Relics: boss-dropped armor in three slots (crown / kavacha / charm) with set
-- bonuses. Pure data + drop/equip/merge logic so it's all Lune-tested; the server
-- RelicService applies drops and the services read totalBonus off equipped ids.
-- Dependency-free: boss ids are strings, cross-checked against Bosses in a test.

local Relics = {}

Relics.DupeGold = 250 -- a duplicate dissolves into gold
Relics.BossDropChance = 0.25 -- every player rolls when a boss falls
Relics.EliteDropChance = 0.05 -- the killer rolls when an elite falls
Relics.MaxOwned = 40

Relics.Slots = { "crown", "kavacha", "charm" }

Relics.RarityColor = {
	common = { 200, 200, 200 },
	rare = { 80, 170, 255 },
	epic = { 190, 100, 255 },
	mythic = { 255, 160, 30 },
} :: { [string]: { number } }

-- Per-piece / per-set stat block. Multipliers default 1, flats default 0.
export type PartialBonus = {
	damageMult: number?,
	healthBonus: number?,
	goldMult: number?,
	critChance: number?,
	tejasMult: number?,
	damageTakenMult: number?,
}

export type Bonus = {
	damageMult: number,
	healthBonus: number,
	goldMult: number,
	critChance: number,
	tejasMult: number,
	damageTakenMult: number,
}

export type RelicDef = {
	id: string,
	name: string,
	slot: string, -- "crown" | "kavacha" | "charm"
	rarity: string, -- "common" | "rare" | "epic" | "mythic"
	setId: string?, -- nil for loose charms
	line: string,
	bonus: PartialBonus,
}

export type SetDef = {
	id: string,
	name: string,
	pieces: { string },
	bonus2: PartialBonus, -- wearing 2+ pieces
	bonus3: PartialBonus?, -- wearing all 3 (Ravana only)
}

Relics.Defs = {
	-- Mahishasura — the Buffalo King's wrath.
	mahisha_crown = { id = "mahisha_crown", name = "Horned Crown of the Buffalo King", slot = "crown", rarity = "epic", setId = "mahisha", line = "The horns still remember goring.", bonus = { damageMult = 1.04 } },
	mahisha_kavacha = { id = "mahisha_kavacha", name = "Buffalo-Hide Kavacha", slot = "kavacha", rarity = "epic", setId = "mahisha", line = "Hide that turned a goddess's spear — once.", bonus = { healthBonus = 20 } },
	-- Tarakasura — the hunting comet.
	taraka_crown = { id = "taraka_crown", name = "Comet-Iron Circlet", slot = "crown", rarity = "epic", setId = "taraka", line = "Forged from a fallen star's heart.", bonus = { critChance = 0.03 } },
	taraka_kavacha = { id = "taraka_kavacha", name = "Kavacha of the Unconquered", slot = "kavacha", rarity = "epic", setId = "taraka", line = "Worn through a thousand won sieges.", bonus = { damageMult = 1.03 } },
	-- Kumbhakarna — the sleeping mountain.
	kumbha_crown = { id = "kumbha_crown", name = "Crown of the Sleeping Mountain", slot = "crown", rarity = "epic", setId = "kumbha", line = "Heavy as six months of sleep.", bonus = { healthBonus = 25 } },
	kumbha_kavacha = { id = "kumbha_kavacha", name = "Mountainhide Kavacha", slot = "kavacha", rarity = "epic", setId = "kumbha", line = "Blows land on it like rain on rock.", bonus = { damageTakenMult = 0.95 } },
	-- Hiranyakashipu — the tyrant's regalia.
	hiranya_crown = { id = "hiranya_crown", name = "The Tyrant's Diadem", slot = "crown", rarity = "epic", setId = "hiranya", line = "Gold hoarded from a hundred conquered courts.", bonus = { goldMult = 1.10 } },
	hiranya_kavacha = { id = "hiranya_kavacha", name = "Gold-Wrought Kavacha", slot = "kavacha", rarity = "epic", setId = "hiranya", line = "Vanity, hammered into armor.", bonus = { tejasMult = 1.10 } },
	-- Bakasura — the glutton's feast.
	baka_crown = { id = "baka_crown", name = "The Glutton's Toothy Crown", slot = "crown", rarity = "rare", setId = "baka", line = "Every tooth a finished meal.", bonus = { healthBonus = 18 } },
	baka_kavacha = { id = "baka_kavacha", name = "Feast-Hardened Kavacha", slot = "kavacha", rarity = "rare", setId = "baka", line = "Fat turned to iron.", bonus = { goldMult = 1.08 } },
	-- Ravana — Dashanana's dominion (raid-only).
	ravana_crown = { id = "ravana_crown", name = "Dashanana's Crown", slot = "crown", rarity = "mythic", setId = "ravana", line = "Ten heads wore it. None kept it.", bonus = { damageMult = 1.08 } },
	ravana_kavacha = { id = "ravana_kavacha", name = "Kavacha of Ten Heads", slot = "kavacha", rarity = "mythic", setId = "ravana", line = "Shiva himself once weighed this chest down.", bonus = { damageTakenMult = 0.90 } },
	ravana_charm = { id = "ravana_charm", name = "The Tenth Head's Eye", slot = "charm", rarity = "mythic", setId = "ravana", line = "It still watches for Rama.", bonus = { critChance = 0.05 } },
	-- Loose charms — elite spoils.
	charm_vetala = { id = "charm_vetala", name = "Vetala's Eye", slot = "charm", rarity = "common", line = "It sees the gap in every guard.", bonus = { critChance = 0.03 } },
	charm_pisacha = { id = "charm_pisacha", name = "Pisacha Fang", slot = "charm", rarity = "common", line = "Still hungry.", bonus = { damageMult = 1.04 } },
	charm_rakshasa = { id = "charm_rakshasa", name = "Rakshasa Braid", slot = "charm", rarity = "rare", line = "Woven from a warlord's topknot.", bonus = { healthBonus = 15 } },
	charm_asura = { id = "charm_asura", name = "Asura Ember", slot = "charm", rarity = "rare", line = "A coal from the first sacrificial fire they stole.", bonus = { tejasMult = 1.10 } },
} :: { [string]: RelicDef }

Relics.Sets = {
	mahisha = { id = "mahisha", name = "Wrath of the Buffalo King", pieces = { "mahisha_crown", "mahisha_kavacha" }, bonus2 = { damageMult = 1.08 } },
	taraka = { id = "taraka", name = "The Hunting Comet", pieces = { "taraka_crown", "taraka_kavacha" }, bonus2 = { critChance = 0.05 } },
	kumbha = { id = "kumbha", name = "The Mountain Asleep", pieces = { "kumbha_crown", "kumbha_kavacha" }, bonus2 = { damageTakenMult = 0.92 } },
	hiranya = { id = "hiranya", name = "The Tyrant's Regalia", pieces = { "hiranya_crown", "hiranya_kavacha" }, bonus2 = { goldMult = 1.15 } },
	baka = { id = "baka", name = "The Glutton's Feast", pieces = { "baka_crown", "baka_kavacha" }, bonus2 = { healthBonus = 25 } },
	ravana = { id = "ravana", name = "Dashanana's Dominion", pieces = { "ravana_crown", "ravana_kavacha", "ravana_charm" }, bonus2 = { damageMult = 1.10 }, bonus3 = { damageMult = 1.05, damageTakenMult = 0.95, critChance = 0.03 } },
} :: { [string]: SetDef }

-- What each boss can leave behind (ids match Bosses roster ids; Ravana is the raid).
Relics.BossDrops = {
	Mahishasura = { "mahisha_crown", "mahisha_kavacha" },
	Tarakasura = { "taraka_crown", "taraka_kavacha" },
	Kumbhakarna = { "kumbha_crown", "kumbha_kavacha" },
	Hiranyakashipu = { "hiranya_crown", "hiranya_kavacha" },
	Bakasura = { "baka_crown", "baka_kavacha" },
	Ravana = { "ravana_crown", "ravana_kavacha", "ravana_charm" },
} :: { [string]: { string } }

Relics.CharmDrops = { "charm_vetala", "charm_pisacha", "charm_rakshasa", "charm_asura" }

function Relics.get(id: string): RelicDef?
	return Relics.Defs[id]
end

function Relics.isValidId(id: string): boolean
	return Relics.Defs[id] ~= nil
end

function Relics.slotOf(id: string): string?
	local def = Relics.Defs[id]
	return if def then def.slot else nil
end

function Relics.dropsFor(bossId: string): { string }
	return Relics.BossDrops[bossId] or {}
end

local function has(list: { string }, id: string): boolean
	for _, v in list do
		if v == id then
			return true
		end
	end
	return false
end

Relics.ownedHas = has

-- Room in the satchel and not already owned?
function Relics.canAddOwned(owned: { string }, id: string): boolean
	return Relics.isValidId(id) and not has(owned, id) and #owned < Relics.MaxOwned
end

export type DropRoll = {
	id: string,
	dupe: boolean, -- already owned: dissolves into DupeGold instead
}

-- One drop roll. Prefers pieces the player doesn't own yet; only when the whole
-- pool is owned does it come up a duplicate. rng defaults to math.random.
function Relics.rollDrop(candidates: { string }, owned: { string }, chance: number, rng: (() -> number)?): DropRoll?
	if #candidates == 0 then
		return nil
	end
	-- (luau-lsp can't call an if-expression union of function types — branch inside.)
	local function roll(): number
		if rng then
			return rng()
		end
		return math.random()
	end
	if roll() >= chance then
		return nil
	end

	local unowned: { string } = {}
	for _, id in candidates do
		if not has(owned, id) then
			table.insert(unowned, id)
		end
	end

	local pool = if #unowned > 0 then unowned else candidates
	local index = math.clamp(math.floor(roll() * #pool) + 1, 1, #pool)
	return { id = pool[index], dupe = #unowned == 0 }
end

-- The non-empty ids out of an equipped table, ready for totalBonus.
function Relics.equippedList(equipped: { crown: string, kavacha: string, charm: string }): { string }
	local out: { string } = {}
	for _, slot in Relics.Slots do
		local id = (equipped :: any)[slot]
		if type(id) == "string" and id ~= "" then
			table.insert(out, id)
		end
	end
	return out
end

local function applyBonus(total: Bonus, part: PartialBonus)
	total.damageMult *= part.damageMult or 1
	total.healthBonus += part.healthBonus or 0
	total.goldMult *= part.goldMult or 1
	total.critChance += part.critChance or 0
	total.tejasMult *= part.tejasMult or 1
	total.damageTakenMult *= part.damageTakenMult or 1
end

-- Merge worn pieces + any earned set bonuses into one stat block.
-- Multipliers multiply, flats add; unknown ids are skipped, dupes count once.
function Relics.totalBonus(ids: { string }): Bonus
	local total: Bonus = {
		damageMult = 1,
		healthBonus = 0,
		goldMult = 1,
		critChance = 0,
		tejasMult = 1,
		damageTakenMult = 1,
	}

	local seen: { [string]: boolean } = {}
	local setCounts: { [string]: number } = {}
	for _, id in ids do
		local def = Relics.Defs[id]
		if not def or seen[id] then
			continue
		end
		seen[id] = true
		applyBonus(total, def.bonus)
		if def.setId then
			setCounts[def.setId] = (setCounts[def.setId] or 0) + 1
		end
	end

	for setId, count in setCounts do
		local set = Relics.Sets[setId]
		if set and count >= 2 then
			applyBonus(total, set.bonus2)
			if set.bonus3 and count >= 3 then
				applyBonus(total, set.bonus3)
			end
		end
	end

	return total
end

export type EquipCheck = {
	ok: boolean,
	reason: string, -- "ok" | "unknown" | "slot" | "unowned"
}

-- Gate an equip: id must be a real relic the player owns, going into its own slot.
-- An empty id is a bare slot (unequip) and always fine.
function Relics.tryEquip(owned: { string }, slot: string, id: string): EquipCheck
	local slotValid = false
	for _, s in Relics.Slots do
		if s == slot then
			slotValid = true
		end
	end
	if not slotValid then
		return { ok = false, reason = "slot" }
	end
	if id == "" then
		return { ok = true, reason = "ok" }
	end
	local def = Relics.Defs[id]
	if not def then
		return { ok = false, reason = "unknown" }
	end
	if def.slot ~= slot then
		return { ok = false, reason = "slot" }
	end
	if not has(owned, id) then
		return { ok = false, reason = "unowned" }
	end
	return { ok = true, reason = "ok" }
end

return Relics
