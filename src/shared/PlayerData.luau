--!strict
-- The saved-data schema + validation. Pure logic so it's Lune-testable; the actual
-- DataStore I/O lives in the server DataService. `validate` is the safety net:
-- any loaded value (nil, corrupt, old schema) becomes a clean, valid Data table.

local PlayerData = {}

PlayerData.Version = 19

-- Mirrors Relics.MaxOwned (dependency-free; a test guards against drift).
local RELICS_MAX_OWNED = 40

-- Mirrors Shop.MaxTier (kept dependency-free for Lune; a test guards against drift).
local MAX_TIER = 10

-- Mirrors Weapons.MaxTier / MinTier (dependency-free; a test guards against drift).
local WEAPON_MAX_TIER = 5
local WEAPON_MIN_TIER = 1

local function clampTier(value: any): number
	if type(value) ~= "number" or value ~= value or value < 0 then
		return 0
	end
	return math.min(math.floor(value), MAX_TIER)
end

local function clampWeaponTier(value: any): number
	if type(value) ~= "number" or value ~= value then
		return WEAPON_MIN_TIER
	end
	return math.clamp(math.floor(value), WEAPON_MIN_TIER, WEAPON_MAX_TIER)
end

export type Upgrades = {
	damage: number,
	health: number,
}

export type WeaponSave = {
	id: string, -- "" until the player chooses at the start
	tier: number,
}

export type StatsSave = {
	kills: number,
	bossKills: number,
	deaths: number,
	playtimeSeconds: number,
	trialsPassed: number,
	duelWins: number,
	raidClears: number,
	revives: number,
}

export type DailySlot = {
	id: string,
	progress: number,
	done: boolean,
}

export type DailiesSave = {
	stamp: number, -- day number the slots belong to; a new day rerolls them
	slots: { DailySlot },
}

local function cleanCount(value: any): number
	if type(value) ~= "number" or value ~= value or value < 0 then
		return 0
	end
	return math.floor(value)
end

export type QuestSlot = {
	id: string,
	progress: number,
}

export type Data = {
	version: number,
	totalXp: number,
	gold: number,
	upgrades: Upgrades,
	bestWave: number,
	quests: { QuestSlot },
	weapon: WeaponSave,
	shards: number, -- Vajra Shards (boss-kill currency for mantras)
	enchant: string, -- inscribed mantra id, "" when the weapon is unmarked
	stats: StatsSave, -- lifetime records (kills, bosses, deaths, playtime)
	dailies: DailiesSave, -- today's trials + progress (reset when stamp goes stale)
	title: string, -- equipped title id, "" for a bare head
	path: string, -- sworn Astra Path id, "" while unsworn
	relics: RelicsSave, -- the satchel + what's worn in each slot
	story: number, -- Adhyayas completed (0 = the tale hasn't begun)
	mastery: MasterySave, -- per-path siddhi mastery XP (never decreases)
	streak: StreakSave, -- Agnihotra login streak (day stamp + consecutive count)
	tutorialDone: boolean, -- Adhyaya 0 finished (the lesson never repeats)
	vibhuti: VibhutiSave, -- worn sacred marks (tilak + aura ids, "" = bare)
	vrata: VrataSave, -- the weekly vow (stamp + progress; stale weeks reset)
	weekly: WeeklySave, -- this week's deepest wave (stale weeks reset)
}

export type WeeklySave = {
	stamp: number,
	wave: number,
}

export type VrataSave = {
	stamp: number,
	progress: number,
	kept: boolean,
}

export type VibhutiSave = {
	tilak: string,
	aura: string,
}

export type StreakSave = {
	stamp: number,
	count: number,
}

export type MasterySave = {
	agni: number,
	vayu: number,
	varuna: number,
	indra: number,
}

local function cleanMastery(raw: any): MasterySave
	local out: MasterySave = { agni = 0, vayu = 0, varuna = 0, indra = 0 }
	if type(raw) == "table" then
		for _, pathId in { "agni", "vayu", "varuna", "indra" } do
			local v = raw[pathId]
			if type(v) == "number" and v == v and v > 0 then
				(out :: any)[pathId] = math.floor(v)
			end
		end
	end
	return out
end

export type RelicsSave = {
	owned: { string },
	equipped: { crown: string, kavacha: string, charm: string },
}

local function cleanRelics(raw: any): RelicsSave
	local out: RelicsSave = { owned = {}, equipped = { crown = "", kavacha = "", charm = "" } }
	if type(raw) ~= "table" then
		return out
	end
	if type(raw.owned) == "table" then
		local seen: { [string]: boolean } = {}
		for _, id in raw.owned do
			if type(id) == "string" and #id > 0 and #id <= 40 and not seen[id] and #out.owned < RELICS_MAX_OWNED then
				seen[id] = true
				table.insert(out.owned, id)
			end
		end
	end
	if type(raw.equipped) == "table" then
		for _, slot in { "crown", "kavacha", "charm" } do
			local id = raw.equipped[slot]
			if type(id) == "string" and #id <= 40 then
				(out.equipped :: any)[slot] = id
			end
		end
	end
	return out
end

function PlayerData.default(): Data
	return {
		version = PlayerData.Version,
		totalXp = 0,
		gold = 0,
		upgrades = { damage = 0, health = 0 },
		bestWave = 0,
		quests = {},
		weapon = { id = "", tier = WEAPON_MIN_TIER },
		shards = 0,
		enchant = "",
		stats = { kills = 0, bossKills = 0, deaths = 0, playtimeSeconds = 0, trialsPassed = 0, duelWins = 0, raidClears = 0, revives = 0 },
		dailies = { stamp = 0, slots = {} }, -- stamp 0 = stale, forces a fresh roll
		title = "",
		path = "",
		relics = { owned = {}, equipped = { crown = "", kavacha = "", charm = "" } },
		story = 0,
		mastery = { agni = 0, vayu = 0, varuna = 0, indra = 0 },
		streak = { stamp = 0, count = 0 },
		tutorialDone = false,
		vibhuti = { tilak = "", aura = "" },
		vrata = { stamp = 0, progress = 0, kept = false },
		weekly = { stamp = 0, wave = 0 },
	}
end

-- Coerce arbitrary loaded data into valid Data: fill missing fields, clamp bad ones,
-- ignore junk. Never trusts the stored blob blindly.
function PlayerData.validate(raw: any): Data
	local d = PlayerData.default()
	if type(raw) == "table" then
		if type(raw.totalXp) == "number" and raw.totalXp >= 0 and raw.totalXp == raw.totalXp then
			d.totalXp = math.floor(raw.totalXp)
		end
		if type(raw.gold) == "number" and raw.gold >= 0 and raw.gold == raw.gold then
			d.gold = math.floor(raw.gold)
		end
		if type(raw.upgrades) == "table" then
			d.upgrades.damage = clampTier(raw.upgrades.damage)
			d.upgrades.health = clampTier(raw.upgrades.health)
		end
		if type(raw.bestWave) == "number" and raw.bestWave >= 0 and raw.bestWave == raw.bestWave then
			d.bestWave = math.floor(raw.bestWave)
		end
		if type(raw.quests) == "table" then
			for _, slot in raw.quests do
				if type(slot) == "table" and type(slot.id) == "string" and #d.quests < 8 then
					local progress = 0
					if type(slot.progress) == "number" and slot.progress >= 0 and slot.progress == slot.progress then
						progress = math.floor(slot.progress)
					end
					table.insert(d.quests, { id = slot.id, progress = progress })
				end
			end
		end
		if type(raw.weapon) == "table" and type(raw.weapon.id) == "string" then
			d.weapon.id = raw.weapon.id
			d.weapon.tier = clampWeaponTier(raw.weapon.tier)
		end
		if type(raw.shards) == "number" and raw.shards >= 0 and raw.shards == raw.shards then
			d.shards = math.floor(raw.shards)
		end
		if type(raw.enchant) == "string" and #raw.enchant <= 40 then
			d.enchant = raw.enchant
		end
		if type(raw.stats) == "table" then
			d.stats.kills = cleanCount(raw.stats.kills)
			d.stats.bossKills = cleanCount(raw.stats.bossKills)
			d.stats.deaths = cleanCount(raw.stats.deaths)
			d.stats.playtimeSeconds = cleanCount(raw.stats.playtimeSeconds)
			d.stats.trialsPassed = cleanCount(raw.stats.trialsPassed)
			d.stats.duelWins = cleanCount(raw.stats.duelWins)
			d.stats.raidClears = cleanCount(raw.stats.raidClears)
			d.stats.revives = cleanCount(raw.stats.revives)
		end
		if type(raw.title) == "string" and #raw.title <= 40 then
			d.title = raw.title
		end
		if type(raw.path) == "string" and #raw.path <= 20 then
			d.path = raw.path
		end
		d.relics = cleanRelics(raw.relics)
		d.mastery = cleanMastery(raw.mastery)
		if type(raw.streak) == "table" then
			d.streak.stamp = cleanCount(raw.streak.stamp)
			d.streak.count = cleanCount(raw.streak.count)
		end
		d.tutorialDone = raw.tutorialDone == true
		if type(raw.vibhuti) == "table" then
			if type(raw.vibhuti.tilak) == "string" and #raw.vibhuti.tilak <= 40 then
				d.vibhuti.tilak = raw.vibhuti.tilak
			end
			if type(raw.vibhuti.aura) == "string" and #raw.vibhuti.aura <= 40 then
				d.vibhuti.aura = raw.vibhuti.aura
			end
		end
		if type(raw.vrata) == "table" then
			d.vrata.stamp = cleanCount(raw.vrata.stamp)
			d.vrata.progress = cleanCount(raw.vrata.progress)
			d.vrata.kept = raw.vrata.kept == true
		end
		if type(raw.weekly) == "table" then
			d.weekly.stamp = cleanCount(raw.weekly.stamp)
			d.weekly.wave = cleanCount(raw.weekly.wave)
		end
		if type(raw.story) == "number" and raw.story == raw.story and raw.story > 0 then
			d.story = math.min(math.floor(raw.story), 50)
		end
		if type(raw.dailies) == "table" then
			d.dailies.stamp = cleanCount(raw.dailies.stamp)
			if type(raw.dailies.slots) == "table" then
				for _, slot in raw.dailies.slots do
					if type(slot) == "table" and type(slot.id) == "string" and #d.dailies.slots < 5 then
						table.insert(d.dailies.slots, {
							id = slot.id,
							progress = cleanCount(slot.progress),
							done = slot.done == true,
						})
					end
				end
			end
		end
	end
	return d
end

-- Snapshot of the runtime state to persist.
function PlayerData.serialize(
	totalXp: number,
	gold: number,
	upgrades: Upgrades?,
	bestWave: number?,
	quests: { QuestSlot }?,
	weapon: WeaponSave?,
	shards: number?,
	enchant: string?,
	stats: StatsSave?,
	dailies: DailiesSave?,
	title: string?,
	path: string?,
	relics: RelicsSave?,
	story: number?,
	mastery: MasterySave?,
	streak: StreakSave?,
	tutorialDone: boolean?,
	vibhuti: VibhutiSave?,
	vrata: VrataSave?,
	weekly: WeeklySave?
): Data
	local questsCopy: { QuestSlot } = {}
	if quests then
		for _, slot in quests do
			table.insert(questsCopy, {
				id = slot.id,
				progress = math.max(0, math.floor(slot.progress)),
			})
		end
	end
	return {
		version = PlayerData.Version,
		totalXp = math.max(0, math.floor(totalXp)),
		gold = math.max(0, math.floor(gold)),
		upgrades = {
			damage = clampTier(if upgrades then upgrades.damage else 0),
			health = clampTier(if upgrades then upgrades.health else 0),
		},
		bestWave = math.max(0, math.floor(bestWave or 0)),
		quests = questsCopy,
		weapon = {
			id = if weapon and type(weapon.id) == "string" then weapon.id else "",
			tier = clampWeaponTier(if weapon then weapon.tier else WEAPON_MIN_TIER),
		},
		shards = math.max(0, math.floor(shards or 0)),
		enchant = if type(enchant) == "string" and #enchant <= 40 then enchant else "",
		stats = {
			kills = cleanCount(if stats then stats.kills else 0),
			bossKills = cleanCount(if stats then stats.bossKills else 0),
			deaths = cleanCount(if stats then stats.deaths else 0),
			playtimeSeconds = cleanCount(if stats then stats.playtimeSeconds else 0),
			trialsPassed = cleanCount(if stats then stats.trialsPassed else 0),
			duelWins = cleanCount(if stats then stats.duelWins else 0),
			raidClears = cleanCount(if stats then stats.raidClears else 0),
			revives = cleanCount(if stats then stats.revives else 0),
		},
		dailies = {
			stamp = cleanCount(if dailies then dailies.stamp else 0),
			slots = (function(): { DailySlot }
				local out: { DailySlot } = {}
				if dailies then
					for _, slot in dailies.slots do
						if #out < 5 then
							table.insert(out, {
								id = slot.id,
								progress = cleanCount(slot.progress),
								done = slot.done == true,
							})
						end
					end
				end
				return out
			end)(),
		},
		title = if type(title) == "string" and #title <= 40 then title else "",
		path = if type(path) == "string" and #path <= 20 then path else "",
		relics = cleanRelics(relics),
		mastery = cleanMastery(mastery),
		streak = {
			stamp = cleanCount(if streak then streak.stamp else 0),
			count = cleanCount(if streak then streak.count else 0),
		},
		tutorialDone = tutorialDone == true,
		vibhuti = {
			tilak = if vibhuti and type(vibhuti.tilak) == "string" and #vibhuti.tilak <= 40 then vibhuti.tilak else "",
			aura = if vibhuti and type(vibhuti.aura) == "string" and #vibhuti.aura <= 40 then vibhuti.aura else "",
		},
		vrata = {
			stamp = cleanCount(if vrata then vrata.stamp else 0),
			progress = cleanCount(if vrata then vrata.progress else 0),
			kept = if vrata then vrata.kept == true else false,
		},
		weekly = {
			stamp = cleanCount(if weekly then weekly.stamp else 0),
			wave = cleanCount(if weekly then weekly.wave else 0),
		},
		story = if type(story) == "number" and story == story and story > 0 then math.min(math.floor(story), 50) else 0,
	}
end

return PlayerData
