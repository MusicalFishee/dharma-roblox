--!strict
-- Varna ranks: the level ladder, named. Every band of levels carries a rank
-- worn beside your level — Shishya the student up through Chakravartin, the
-- wheel-turning sovereign at the very cap. Each rank confers a permanent boon
-- (max health + gold find) that never resets: purely additive, by law.
-- Pure ladder + boon math (Lune-tested); ProgressionService applies it.

local Ranks = {}

export type RankDef = {
	level: number, -- first level of the band
	name: string,
	line: string,
}

local function rank(def: RankDef): RankDef
	return def
end

Ranks.List = {
	rank({ level = 1, name = "Shishya", line = "the student" }),
	rank({ level = 10, name = "Sainika", line = "the soldier" }),
	rank({ level = 25, name = "Yodha", line = "the warrior" }),
	rank({ level = 40, name = "Kshatriya", line = "the highborn blade" }),
	rank({ level = 60, name = "Senapati", line = "the commander" }),
	rank({ level = 80, name = "Mahāsena", line = "the great army incarnate" }),
	rank({ level = 100, name = "Chakravartin", line = "the wheel-turning sovereign" }),
} :: { RankDef }

-- Per rank held above Shishya: flat health and a gold-find multiplier.
Ranks.HealthPerRank = 15
Ranks.GoldPerRank = 0.02

-- The rank an account level holds. Returns (index, def).
function Ranks.rankFor(level: number): (number, RankDef)
	if level < 1 then
		level = 1
	end
	local index = 1
	for i, def in Ranks.List do
		if level >= def.level then
			index = i
		end
	end
	return index, Ranks.List[index]
end

export type Boon = {
	healthBonus: number,
	goldMult: number,
}

-- The permanent boon a rank index confers (Shishya confers nothing yet).
function Ranks.boonFor(index: number): Boon
	local steps = math.max(0, index - 1)
	return {
		healthBonus = steps * Ranks.HealthPerRank,
		goldMult = 1 + steps * Ranks.GoldPerRank,
	}
end

-- The next rank still ahead of this level — for "what am I climbing toward".
function Ranks.nextRank(level: number): RankDef?
	for _, def in Ranks.List do
		if def.level > level then
			return def
		end
	end
	return nil
end

return Ranks
