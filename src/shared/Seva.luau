--!strict
-- Seva: communal service. The whole server shares one standing goal — a
-- thousand small hands moving one stone. Progress comes from everyone,
-- the payout lands on everyone online when it breaks, and the next goal
-- takes its place. Session-scoped: each server carries its own stone.
-- Pure goal/milestone math (Lune-tested); SevaService keeps the tally.

local Seva = {}

export type GoalDef = {
	id: string,
	kind: string, -- "kills" | "bossKills" | "parries" | "revives"
	target: number,
	name: string,
	line: string,
	gold: number, -- paid to every soul online when the stone moves
	shards: number,
}

local function goal(def: GoalDef): GoalDef
	return def
end

Seva.Goals = {
	goal({ id = "horde", kind = "kills", target = 300, name = "Turn the Horde", line = "Together, fell three hundred demons.", gold = 300, shards = 1 }),
	goal({ id = "lords", kind = "bossKills", target = 8, name = "Humble the Lords", line = "Together, fell eight asura lords.", gold = 400, shards = 2 }),
	goal({ id = "wall", kind = "parries", target = 120, name = "Be the Wall", line = "Together, turn aside one hundred twenty blows.", gold = 300, shards = 1 }),
	goal({ id = "lifters", kind = "revives", target = 10, name = "Lift the Fallen", line = "Together, lift ten allies from the dust.", gold = 350, shards = 2 }),
} :: { GoalDef }

function Seva.goalAt(index: number): GoalDef
	return Seva.Goals[((index - 1) % #Seva.Goals) + 1]
end

-- Milestone toasts fire at each quarter of the stone — never spam.
function Seva.isMilestone(progress: number, target: number): boolean
	if progress <= 0 or progress > target then
		return false
	end
	local quarter = math.floor(target / 4)
	if quarter <= 0 then
		return false
	end
	return progress % quarter == 0 and progress < target
end

return Seva
