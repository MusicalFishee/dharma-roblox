--!strict
-- Kirti, the glory ledger: ten lifetime deeds, each in three tiers —
-- Kansya (bronze), Rajata (silver), Svarna (gold). Every tier derives from
-- stats already written into the save, so the whole ledger is retroactive
-- and needs no persistence of its own. Pure defs + tier math (Lune-tested);
-- KirtiUI renders it from the stats snapshot.

local Deeds = {}

Deeds.TierNames = { "Kansya", "Rajata", "Svarna" } -- bronze, silver, gold
Deeds.TierColor = {
	{ 205, 130, 80 },
	{ 200, 205, 215 },
	{ 255, 200, 40 },
} :: { { number } }

export type DeedDef = {
	id: string,
	name: string,
	line: string,
	kind: string, -- which snapshot stat it reads
	thresholds: { number }, -- ascending, one per tier
}

export type Snapshot = {
	kills: number,
	bossKills: number,
	bestWave: number,
	duelWins: number,
	raidClears: number,
	revives: number,
	trials: number,
	level: number,
	playtimeSeconds: number,
	deaths: number,
}

local function deed(def: DeedDef): DeedDef
	return def
end

Deeds.List = {
	deed({ id = "slayer", name = "Slayer of the Horde", line = "Demons cut down", kind = "kills", thresholds = { 100, 1000, 5000 } }),
	deed({ id = "lord_breaker", name = "Breaker of Lords", line = "Asura lords felled", kind = "bossKills", thresholds = { 10, 50, 200 } }),
	deed({ id = "deep_strider", name = "Strider of the Deep", line = "Deepest wave held", kind = "bestWave", thresholds = { 10, 50, 100 } }),
	deed({ id = "honor_bound", name = "Honor-Bound", line = "Duels won", kind = "duelWins", thresholds = { 1, 10, 50 } }),
	deed({ id = "king_ender", name = "Ender of Kings", line = "Ravanas felled", kind = "raidClears", thresholds = { 1, 5, 25 } }),
	deed({ id = "brothers_hand", name = "The Brother's Hand", line = "Allies lifted", kind = "revives", thresholds = { 1, 10, 50 } }),
	deed({ id = "god_tested", name = "Tested by the God", line = "Trials passed", kind = "trials", thresholds = { 1, 3, 10 } }),
	deed({ id = "ascendant", name = "The Ascendant", line = "Level attained", kind = "level", thresholds = { 10, 30, 60 } }),
	deed({ id = "devoted", name = "The Devoted", line = "Hours at war", kind = "playtime", thresholds = { 3600, 18000, 72000 } }),
	deed({ id = "undying_will", name = "The Undying Will", line = "Deaths endured (the ātman remembers)", kind = "deaths", thresholds = { 10, 50, 200 } }),
} :: { DeedDef }

-- The stat a deed reads from the snapshot.
function Deeds.statFor(kind: string, snap: Snapshot): number
	if kind == "kills" then
		return snap.kills
	elseif kind == "bossKills" then
		return snap.bossKills
	elseif kind == "bestWave" then
		return snap.bestWave
	elseif kind == "duelWins" then
		return snap.duelWins
	elseif kind == "raidClears" then
		return snap.raidClears
	elseif kind == "revives" then
		return snap.revives
	elseif kind == "trials" then
		return snap.trials
	elseif kind == "level" then
		return snap.level
	elseif kind == "playtime" then
		return snap.playtimeSeconds
	elseif kind == "deaths" then
		return snap.deaths
	end
	return 0
end

-- The tier earned (0 = unmarked, 3 = Svarna).
function Deeds.tierFor(def: DeedDef, value: number): number
	local tier = 0
	for i, threshold in def.thresholds do
		if value >= threshold then
			tier = i
		end
	end
	return tier
end

export type Progress = {
	tier: number,
	value: number,
	nextThreshold: number?, -- nil at Svarna
}

function Deeds.progress(def: DeedDef, snap: Snapshot): Progress
	local value = Deeds.statFor(def.kind, snap)
	local tier = Deeds.tierFor(def, value)
	return {
		tier = tier,
		value = value,
		nextThreshold = if tier < #def.thresholds then def.thresholds[tier + 1] else nil,
	}
end

-- Each tier's one-time bounty when CLAIMED (kansya, rajata, svarna).
Deeds.TierReward = { 200, 500, 1200 }

export type Owed = {
	tiers: number, -- how many unclaimed earned tiers
	gold: number, -- their combined bounty
}

-- What a deed still owes: every earned tier above the claimed mark, summed.
function Deeds.owedFor(def: DeedDef, value: number, claimedTier: number): Owed
	local earned = Deeds.tierFor(def, value)
	local from = math.clamp(math.floor(claimedTier), 0, 3)
	local gold = 0
	local tiers = 0
	for t = from + 1, earned do
		gold += Deeds.TierReward[t]
		tiers += 1
	end
	return { tiers = tiers, gold = gold }
end

-- Total tiers earned across the ledger (the panel's headline number).
function Deeds.totalTiers(snap: Snapshot): number
	local total = 0
	for _, def in Deeds.List do
		total += Deeds.tierFor(def, Deeds.statFor(def.kind, snap))
	end
	return total
end

Deeds.MaxTiers = #Deeds.List * 3

return Deeds
