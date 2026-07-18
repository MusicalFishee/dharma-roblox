--!strict
-- The Yatra: the pilgrimage track. A FREE reward road that pays out as your
-- level climbs — no purchase, ever (monetization stays currencies-only, by
-- the founder's law; the road itself is never sold). Claims are recomputed
-- server-side from the real level, and stored as a single count: how many
-- milestones have been claimed, always in order.
-- Pure milestone/owed math (Lune-tested); YatraService pays.

local Yatra = {}

export type Milestone = {
	level: number,
	name: string,
	gold: number,
	shards: number,
}

local function m(level: number, name: string, gold: number, shards: number): Milestone
	return { level = level, name = name, gold = gold, shards = shards }
end

-- Steps on the road, strictly ascending by level. Level cap is 100.
Yatra.Milestones = {
	m(2, "The First Step", 100, 0),
	m(5, "The Ashram Gate", 200, 1),
	m(8, "The Forest Path", 300, 1),
	m(12, "The River Crossing", 450, 1),
	m(16, "The Old Shrine", 600, 2),
	m(20, "The Foothills", 800, 2),
	m(25, "The First Snows", 1000, 2),
	m(30, "The High Pass", 1300, 3),
	m(38, "The Cloud Line", 1700, 3),
	m(46, "The Silent Valley", 2100, 4),
	m(55, "The Pilgrim's Rest", 2600, 4),
	m(65, "The Star Bridge", 3200, 5),
	m(75, "The Last Village", 4000, 5),
	m(88, "The Windless Ridge", 5000, 6),
	m(100, "The Summit Shadow", 7000, 8),
} :: { Milestone }

export type Owed = {
	count: number,
	gold: number,
	shards: number,
}

-- What a player at `level` with `claimed` milestones already taken is owed.
-- Claims are strictly sequential — the road is walked in order.
function Yatra.owedFor(level: number, claimed: number): Owed
	claimed = math.clamp(math.floor(claimed), 0, #Yatra.Milestones)
	local owed: Owed = { count = 0, gold = 0, shards = 0 }
	for i = claimed + 1, #Yatra.Milestones do
		local step = Yatra.Milestones[i]
		if level < step.level then
			break
		end
		owed.count += 1
		owed.gold += step.gold
		owed.shards += step.shards
	end
	return owed
end

-- The next unreached step (nil once the road is walked).
function Yatra.nextFor(level: number, claimed: number): Milestone?
	claimed = math.clamp(math.floor(claimed), 0, #Yatra.Milestones)
	for i = claimed + 1, #Yatra.Milestones do
		local step = Yatra.Milestones[i]
		if level < step.level then
			return step
		end
	end
	return Yatra.Milestones[claimed + 1]
end

return Yatra
