--!strict
-- Vrata: the weekly vow. One contract per week, THE SAME for every player in
-- the world (deterministic rotation by week number) — the community grinds
-- the same vow and compares notes. Kept vows pay fat shard prizes on the
-- spot; the week turning discards unfinished progress without mercy.
-- Pure week math + catalog + advance (Lune-tested); VrataService runs it.

local Vrata = {}

-- UTC week number (days since epoch / 7 — consistent worldwide).
function Vrata.weekStamp(unixTime: number): number
	return math.floor(unixTime / (86400 * 7))
end

export type VrataDef = {
	id: string,
	name: string,
	line: string,
	kind: string, -- "kill" | "bossKill" | "parry" | "waveClear" | "ability" | "gold"
	target: number,
	rewardGold: number,
	rewardShards: number,
}

local function vow(def: VrataDef): VrataDef
	return def
end

Vrata.List = {
	vow({ id = "vrata_slayer", name = "Vow of the Slayer", line = "Slay 300 demons this week", kind = "kill", target = 300, rewardGold = 3000, rewardShards = 15 }),
	vow({ id = "vrata_lordbane", name = "Vow of the Lord-Bane", line = "Fell 12 asura lords this week", kind = "bossKill", target = 12, rewardGold = 3500, rewardShards = 18 }),
	vow({ id = "vrata_wall", name = "Vow of the Wall", line = "Parry 100 blows this week", kind = "parry", target = 100, rewardGold = 3000, rewardShards = 15 }),
	vow({ id = "vrata_strider", name = "Vow of the Strider", line = "Clear 60 waves this week", kind = "waveClear", target = 60, rewardGold = 3200, rewardShards = 16 }),
	vow({ id = "vrata_stormhand", name = "Vow of the Storm-Hand", line = "Loose 200 Astras this week", kind = "ability", target = 200, rewardGold = 2800, rewardShards = 14 }),
	vow({ id = "vrata_hoarder", name = "Vow of the Hoard", line = "Gather 5000 gold this week", kind = "gold", target = 5000, rewardGold = 2000, rewardShards = 20 }),
} :: { VrataDef }

-- This week's vow, the same for everyone alive.
function Vrata.forWeek(stamp: number): VrataDef
	return Vrata.List[(stamp % #Vrata.List) + 1]
end

export type Advance = {
	progress: number,
	kept: boolean, -- this event completed the vow
}

-- Feed one event into the vow. `amount` matters only for gold-kind vows.
function Vrata.advance(def: VrataDef, progress: number, eventKind: string, amount: number?): Advance
	if progress >= def.target or eventKind ~= def.kind then
		return { progress = progress, kept = false }
	end
	local step = if def.kind == "gold" then math.max(0, amount or 0) else 1
	local newProgress = math.min(def.target, progress + step)
	return { progress = newProgress, kept = newProgress >= def.target and progress < def.target }
end

return Vrata
