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
	revives: number, -- brothers lifted from the dust
	deerKills: number, -- golden deer felled (Maricha's ledger)
	bladeMastery: number, -- highest Shastra-Vidya rank across all weapons (1..5)
	loreTurned: number, -- Ripu-Grantha pages turned (0..27)
	playtimeSeconds: number, -- time at war
	deaths: number, -- deaths endured (the atman remembers)
	bladesMastered: number, -- weapons carried to the summit rank
	vairisFelled: number, -- nemeses hunted down and ended
}

export type TitleDef = {
	id: string,
	name: string,
	requirement: string, -- human-readable, shown while locked
	kind: string, -- wave|kills|bossKills|level|trials|duelWins|raidClears|revives|deerKills|bladeMastery|loreTurned
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
	title({ id = "uddhara_hand", name = "Hand of Uddh\u{0101}ra", requirement = "Lift 10 fallen allies", kind = "revives", threshold = 10, color = { 130, 255, 180 } }),
	title({ id = "world_cleaver", name = "World-Cleaver", requirement = "Slay 1000 demons", kind = "kills", threshold = 1000, color = { 240, 90, 220 } }),
	title({ id = "thrice_blessed", name = "Thrice-Blessed", requirement = "Pass the Kirata Trial 3 times", kind = "trials", threshold = 3, color = { 255, 235, 160 } }),
	title({ id = "avatar_of_age", name = "Avatar of the Age", requirement = "Clear wave 100", kind = "wave", threshold = 100, color = { 150, 120, 255 } }),
	-- The newer roads leave their marks too.
	title({ id = "golden_hunter", name = "The Golden Hunter", requirement = "Fell 25 golden deer", kind = "deerKills", threshold = 25, color = { 255, 210, 90 } }),
	title({ id = "one_with_the_blade", name = "One With the Blade", requirement = "Master a weapon to Shastra-Ātma", kind = "bladeMastery", threshold = 5, color = { 220, 235, 250 } }),
	title({ id = "grantha_keeper", name = "Keeper of the Grantha", requirement = "Turn 14 pages of the book of foes", kind = "loreTurned", threshold = 14, color = { 210, 180, 130 } }),
	title({ id = "loremaster", name = "Loremaster of the Ripu-Grantha", requirement = "Turn every page of the book of foes", kind = "loreTurned", threshold = 27, color = { 255, 235, 160 } }),
	title({ id = "threshold_walker", name = "Walker of the Threshold", requirement = "Stand at the door of Kailasa (wave 200)", kind = "wave", threshold = 200, color = { 190, 210, 255 } }),
	title({ id = "devoted", name = "The Devoted", requirement = "Five hours at war", kind = "playtime", threshold = 18000, color = { 255, 170, 80 } }),
	title({ id = "undying", name = "The Undying", requirement = "Endure 100 deaths (the atman remembers)", kind = "deaths", threshold = 100, color = { 180, 130, 200 } }),
	title({ id = "grandmaster", name = "Grandmaster of Arms", requirement = "Master three weapons to the summit", kind = "bladesMastered", threshold = 3, color = { 235, 240, 250 } }),
	title({ id = "grudge_ender", name = "The Grudge-Ender", requirement = "Hunt down and end 10 of your own nemeses", kind = "vairisFelled", threshold = 10, color = { 220, 90, 120 } }),
	-- The capstone: not a stat, but the SUM of every other title. To complete
	-- every path is to be released from the wheel entirely — liberation, union
	-- with Brahman. It grows on its own: a title added anywhere below is one
	-- more thing that must be finished before the self dissolves.
	title({ id = "moksha", name = "Attained Moksha", requirement = "Complete every path, and be one with Brahman", kind = "capstone", threshold = 1, color = { 255, 252, 245 } }),
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
	elseif kind == "revives" then
		return snap.revives
	elseif kind == "deerKills" then
		return snap.deerKills
	elseif kind == "bladeMastery" then
		return snap.bladeMastery
	elseif kind == "loreTurned" then
		return snap.loreTurned
	elseif kind == "playtime" then
		return snap.playtimeSeconds
	elseif kind == "deaths" then
		return snap.deaths
	elseif kind == "bladesMastered" then
		return snap.bladesMastered
	elseif kind == "vairisFelled" then
		return snap.vairisFelled
	end
	return 0
end

function Titles.isUnlocked(def: TitleDef, snap: Snapshot): boolean
	-- The capstone is earned only when every other title is. Iterating the
	-- live list is what makes it self-updating: a new title below is
	-- automatically one more requirement here.
	if def.kind == "capstone" then
		for _, other in Titles.List do
			if other.kind ~= "capstone" and not Titles.isUnlocked(other, snap) then
				return false
			end
		end
		return true
	end
	return statFor(def.kind, snap) >= def.threshold
end

-- How many of the (non-capstone) titles this snapshot has earned, and the
-- total available — for the capstone's live "n / total" progress line.
function Titles.earnedCount(snap: Snapshot): (number, number)
	local earned, total = 0, 0
	for _, def in Titles.List do
		if def.kind ~= "capstone" then
			total += 1
			if statFor(def.kind, snap) >= def.threshold then
				earned += 1
			end
		end
	end
	return earned, total
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
