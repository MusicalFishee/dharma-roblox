--!strict
-- Titles: the flex layer. Earned by deeds already written into the save (deepest
-- wave, kills, boss kills, level, trials passed) so every unlock is retroactive.
-- The equipped one floats over your head and prefixes your chat messages.
-- Pure catalog + unlock math (Lune-tested); TitleService renders and enforces.

local Titles = {}

export type Snapshot = {
	bestWave: number,
	kills: number,
	bossKills: number,
	level: number,
	trials: number, -- Kirata Trials passed
	duelWins: number,
	raidClears: number, -- Ravanas felled
}

export type TitleDef = {
	id: string,
	name: string,
	requirement: string, -- human-readable, shown while locked
	kind: string, -- "wave" | "kills" | "bossKills" | "level" | "trials"
	threshold: number,
	color: { number }, -- {r,g,b} worn above the head and in chat
}

local function title(def: TitleDef): TitleDef
	return def
end

Titles.List = {
	title({ id = "blooded", name = "Blooded", requirement = "Slay 100 demons", kind = "kills", threshold = 100, color = { 200, 120, 110 } }),
	title({ id = "bandit_breaker", name = "Bandit-Breaker", requirement = "Clear wave 10", kind = "wave", threshold = 10, color = { 170, 190 , 160 } }),
	title({ id = "lord_feller", name = "Lord-Feller", requirement = "Fell 10 asura lords", kind = "bossKills", threshold = 10, color = { 235, 120, 90 } }),
	title({ id = "rakshasa_slayer", name = "Rakshasa-Slayer", requirement = "Clear wave 25", kind = "wave", threshold = 25, color = { 130, 170, 255 } }),
	title({ id = "blessed_mahadeva", name = "Blessed of Mahadeva", requirement = "Pass the Kirata Trial", kind = "trials", threshold = 1, color = { 255, 140, 50 } }),
	title({ id = "tandava_witness", name = "Witness of the Tandava", requirement = "Pass the Trial twice", kind = "trials", threshold = 2, color = { 150, 200, 255 } }),
	title({ id = "duelist", name = "Duelist", requirement = "Win 10 duels", kind = "duelWins", threshold = 10, color = { 255, 110, 140 } }),
	title({ id = "maharathi", name = "Maharathi", requirement = "Reach level 30", kind = "level", threshold = 30, color = { 220, 190, 255 } }),
	title({ id = "dharmapala", name = "Dharmapala", requirement = "Clear wave 50", kind = "wave", threshold = 50, color = { 255, 200, 40 } }),
	title({ id = "ravana_bane", name = "Ravana's Bane", requirement = "Fell the Ten-Headed King", kind = "raidClears", threshold = 1, color = { 255, 160, 30 } }),
	title({ id = "world_cleaver", name = "World-Cleaver", requirement = "Slay 1000 demons", kind = "kills", threshold = 1000, color = { 240, 90, 220 } }),
	title({ id = "thrice_blessed", name = "Thrice-Blessed", requirement = "Pass the Kirata Trial 3 times", kind = "trials", threshold = 3, color = { 255, 235, 160 } }),
	title({ id = "avatar_of_age", name = "Avatar of the Age", requirement = "Clear wave 100", kind = "wave", threshold = 100, color = { 150, 120, 255 } }),
} :: { TitleDef }

local byId: { [string]: TitleDef } = {}
for _, def in Titles.List do
	byId[def.id] = def
end

function Titles.get(id: string): TitleDef?
	return byId[id]
end

-- The stat a requirement kind reads from the snapshot.
local function statFor(kind: string, snap: Snapshot): number
	if kind == "wave" then
		return snap.bestWave
	elseif kind == "kills" then
		return snap.kills
	elseif kind == "bossKills" then
		return snap.bossKills
	elseif kind == "level" then
		return snap.level
	elseif kind == "trials" then
		return snap.trials
	elseif kind == "duelWins" then
		return snap.duelWins
	elseif kind == "raidClears" then
		return snap.raidClears
	end
	return 0
end

function Titles.isUnlocked(def: TitleDef, snap: Snapshot): boolean
	return statFor(def.kind, snap) >= def.threshold
end

-- Equip validation: "" (bare head) is always allowed; otherwise the title must
-- exist and be earned.
function Titles.canEquip(id: string, snap: Snapshot): boolean
	if id == "" then
		return true
	end
	local def = byId[id]
	if not def then
		return false
	end
	return Titles.isUnlocked(def, snap)
end

-- Hex string for rich-text chat colors, e.g. "ffc828".
function Titles.colorHex(def: TitleDef): string
	return string.format("%02x%02x%02x", def.color[1], def.color[2], def.color[3])
end

return Titles
