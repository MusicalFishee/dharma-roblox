--!strict
-- The quest system's brain: catalog, event matching, completion, and drawing new
-- quests. Pure (rng injectable) so every rule is Lune-tested.

local Quests = {}

Quests.ActiveCount = 3

export type QuestKind = "kill" | "waveClear" | "parry" | "gold" | "ability"

export type QuestDef = {
	id: string,
	title: string,
	desc: string,
	kind: QuestKind,
	-- kill-quests only: restrict to one archetype, to bosses, or to elites.
	enemyId: string?,
	bossOnly: boolean?,
	eliteOnly: boolean?,
	goal: number,
	rewardGold: number,
	rewardXp: number,
}

export type Event = {
	type: string,
	enemyId: string?,
	isBoss: boolean?,
	isElite: boolean?,
	amount: number?,
}

local function quest(def: QuestDef): QuestDef
	return def
end

Quests.Catalog = {
	slay_asura = quest({ id = "slay_asura", title = "Cull the Horde", desc = "Slay 8 Asuras", kind = "kill", enemyId = "Asura", goal = 8, rewardGold = 120, rewardXp = 60 }),
	slay_pisacha = quest({ id = "slay_pisacha", title = "Pest Control", desc = "Slay 10 Pisachas", kind = "kill", enemyId = "Pisacha", goal = 10, rewardGold = 120, rewardXp = 60 }),
	slay_vetala = quest({ id = "slay_vetala", title = "Shadow Hunter", desc = "Slay 5 Vetalas", kind = "kill", enemyId = "Vetala", goal = 5, rewardGold = 150, rewardXp = 80 }),
	slay_rakshasa = quest({ id = "slay_rakshasa", title = "Giant Feller", desc = "Slay 3 Rakshasas", kind = "kill", enemyId = "Rakshasa", goal = 3, rewardGold = 200, rewardXp = 100 }),
	slay_any = quest({ id = "slay_any", title = "Demon's Bane", desc = "Slay 25 demons", kind = "kill", goal = 25, rewardGold = 180, rewardXp = 90 }),
	boss_slayer = quest({ id = "boss_slayer", title = "Lord Breaker", desc = "Defeat 2 asura lords", kind = "kill", bossOnly = true, goal = 2, rewardGold = 350, rewardXp = 200 }),
	parry_master = quest({ id = "parry_master", title = "Perfect Guard", desc = "Parry 5 attacks", kind = "parry", goal = 5, rewardGold = 200, rewardXp = 120 }),
	wave_warden = quest({ id = "wave_warden", title = "Wave Warden", desc = "Clear 10 waves", kind = "waveClear", goal = 10, rewardGold = 250, rewardXp = 150 }),
	gold_hoard = quest({ id = "gold_hoard", title = "Treasure Seeker", desc = "Collect 300 gold", kind = "gold", goal = 300, rewardGold = 0, rewardXp = 180 }),
	astra_adept = quest({ id = "astra_adept", title = "Astra Adept", desc = "Cast 10 Astras", kind = "ability", goal = 10, rewardGold = 150, rewardXp = 100 }),
} :: { [string]: QuestDef }

-- Stable draw order (Lua table iteration order isn't deterministic).
Quests.Order = {
	"slay_asura",
	"slay_pisacha",
	"slay_vetala",
	"slay_rakshasa",
	"slay_any",
	"boss_slayer",
	"parry_master",
	"wave_warden",
	"gold_hoard",
	"astra_adept",
}

-- How much an event advances a quest (0 = no match).
function Quests.increment(def: QuestDef, event: Event): number
	if def.kind == "kill" then
		if event.type ~= "kill" then
			return 0
		end
		if def.bossOnly and not event.isBoss then
			return 0
		end
		if def.eliteOnly and not event.isElite then
			return 0
		end
		if def.enemyId and event.enemyId ~= def.enemyId then
			return 0
		end
		return 1
	elseif def.kind == "waveClear" then
		return if event.type == "waveClear" then 1 else 0
	elseif def.kind == "parry" then
		return if event.type == "parry" then 1 else 0
	elseif def.kind == "ability" then
		return if event.type == "ability" then 1 else 0
	elseif def.kind == "gold" then
		return if event.type == "gold" then math.max(0, math.floor(event.amount or 0)) else 0
	end
	return 0
end

function Quests.clampProgress(def: QuestDef, value: any): number
	if type(value) ~= "number" or value ~= value or value < 0 then
		return 0
	end
	return math.min(math.floor(value), def.goal)
end

function Quests.isComplete(def: QuestDef, progress: number): boolean
	return progress >= def.goal
end

-- Draw a quest id not in `excludeIds`. `rng(n)` returns 1..n (injectable).
function Quests.draw(excludeIds: { string }, rng: ((number) -> number)?): string?
	local roll: (number) -> number = rng or function(n: number): number
		return math.random(1, n)
	end

	local excluded: { [string]: boolean } = {}
	for _, id in excludeIds do
		excluded[id] = true
	end

	local pool: { string } = {}
	for _, id in Quests.Order do
		if not excluded[id] then
			table.insert(pool, id)
		end
	end
	if #pool == 0 then
		return nil
	end
	return pool[roll(#pool)]
end

return Quests
