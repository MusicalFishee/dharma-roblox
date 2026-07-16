--!strict
-- Daily trials: 3 fat-reward quests that reset at UTC midnight. Everyone in the world
-- gets the SAME three each day (picked deterministically from the day number), which
-- costs nothing to store and gives players something shared to talk about. Defs share
-- the QuestDef shape so QuestService drives them through Quests.increment; pays gold,
-- XP, and — uniquely — Vajra Shards, so the mantra economy has a daily drip.
-- DEPENDENCY-FREE (repo rule: shared modules never require each other — Lune breaks).

local Dailies = {}

Dailies.ActiveCount = 3

export type DailyDef = {
	id: string,
	title: string,
	desc: string,
	kind: string, -- mirrors Quests.QuestKind
	enemyId: string?,
	bossOnly: boolean?,
	eliteOnly: boolean?,
	goal: number,
	rewardGold: number,
	rewardXp: number,
	rewardShards: number,
}

local function daily(def: DailyDef): DailyDef
	return def
end

Dailies.Catalog = {
	daily_horde = daily({ id = "daily_horde", title = "Daily: Horde Breaker", desc = "Slay 40 demons", kind = "kill", goal = 40, rewardGold = 400, rewardXp = 250, rewardShards = 0 }),
	daily_lords = daily({ id = "daily_lords", title = "Daily: Lord Hunter", desc = "Fell 3 asura lords", kind = "kill", bossOnly = true, goal = 3, rewardGold = 300, rewardXp = 300, rewardShards = 2 }),
	daily_elites = daily({ id = "daily_elites", title = "Daily: Gold-Blooded", desc = "Slay 4 elites", kind = "kill", eliteOnly = true, goal = 4, rewardGold = 350, rewardXp = 250, rewardShards = 1 }),
	daily_parry = daily({ id = "daily_parry", title = "Daily: Unbreakable", desc = "Parry 12 strikes", kind = "parry", goal = 12, rewardGold = 400, rewardXp = 200, rewardShards = 1 }),
	daily_waves = daily({ id = "daily_waves", title = "Daily: Tide Turner", desc = "Clear 12 waves", kind = "waveClear", goal = 12, rewardGold = 500, rewardXp = 300, rewardShards = 0 }),
	daily_gold = daily({ id = "daily_gold", title = "Daily: Kubera's Favor", desc = "Gather 600 gold", kind = "gold", goal = 600, rewardGold = 0, rewardXp = 450, rewardShards = 1 }),
	daily_astras = daily({ id = "daily_astras", title = "Daily: Divine Arsenal", desc = "Cast 15 Astras", kind = "ability", goal = 15, rewardGold = 350, rewardXp = 250, rewardShards = 0 }),
	daily_ghouls = daily({ id = "daily_ghouls", title = "Daily: Plague Ender", desc = "Slay 15 Pisachas", kind = "kill", enemyId = "Pisacha", goal = 15, rewardGold = 300, rewardXp = 200, rewardShards = 0 }),
} :: { [string]: DailyDef }

-- Stable order for the deterministic daily pick.
Dailies.Order = {
	"daily_horde",
	"daily_lords",
	"daily_elites",
	"daily_parry",
	"daily_waves",
	"daily_gold",
	"daily_astras",
	"daily_ghouls",
}

-- Days since the Unix epoch — the reset key. Rolls over at UTC midnight.
function Dailies.dayStamp(unixTime: number): number
	return math.floor(math.max(0, unixTime) / 86400)
end

-- Deterministic LCG so every server (and every player) agrees on the day's trials.
local function lcg(seed: number): () -> number
	local x = (seed * 2654435761 + 1013904223) % 2147483648
	return function(): number
		x = (x * 1103515245 + 12345) % 2147483648
		return x
	end
end

-- The day's three trials: same stamp -> same set, no storage needed.
function Dailies.forDay(stamp: number): { string }
	local roll = lcg(stamp)
	local pool = table.clone(Dailies.Order)
	local picked: { string } = {}
	for _ = 1, math.min(Dailies.ActiveCount, #pool) do
		local i = (roll() % #pool) + 1
		table.insert(picked, table.remove(pool, i) :: string)
	end
	return picked
end

function Dailies.get(id: string): DailyDef?
	return Dailies.Catalog[id]
end

function Dailies.clampProgress(def: DailyDef, value: any): number
	if type(value) ~= "number" or value ~= value or value < 0 then
		return 0
	end
	return math.min(math.floor(value), def.goal)
end

function Dailies.isComplete(def: DailyDef, progress: number): boolean
	return progress >= def.goal
end

return Dailies
