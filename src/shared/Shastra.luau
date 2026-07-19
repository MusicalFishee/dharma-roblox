--!strict
-- Shastra-Vidya: weapon mastery. The blade remembers every landed blow and
-- every kill made in its grip — each weapon keeps its OWN ledger, and rank
-- deepens that one weapon's hand-feel with a small, honest damage kicker
-- (never a new identity; the one-identity law stands). Pure rank math
-- (Lune-tested); ShastraService inks the ledgers.

local Shastra = {}

Shastra.XpPerHit = 1
Shastra.XpPerKill = 8
Shastra.DamagePerRank = 0.02 -- +2% per rank past Shishya; +8% at the summit

export type RankDef = {
	xp: number,
	name: string,
	line: string,
}

-- Ascending; rank 1 is every blade's first day.
Shastra.Ranks = {
	{ xp = 0, name = "Shishya", line = "The blade tolerates you." },
	{ xp = 100, name = "Abhyasi", line = "The blade expects you." },
	{ xp = 300, name = "Kushala", line = "The blade answers early." },
	{ xp = 800, name = "Acharya", line = "The blade teaches others through you." },
	{ xp = 2000, name = "Shastra-Atma", line = "The blade and the hand disagree on which is which." },
} :: { RankDef }

function Shastra.rankFor(xp: number): number
	if xp ~= xp or xp < 0 then
		return 1
	end
	local rank = 1
	for i, def in Shastra.Ranks do
		if xp >= def.xp then
			rank = i
		end
	end
	return rank
end

export type Standing = {
	rank: number,
	def: RankDef,
	nextAt: number?, -- xp of the next rank (nil at the summit)
}

function Shastra.resolve(xp: number): Standing
	local rank = Shastra.rankFor(xp)
	local nextDef = Shastra.Ranks[rank + 1]
	return {
		rank = rank,
		def = Shastra.Ranks[rank],
		nextAt = if nextDef then nextDef.xp else nil,
	}
end

-- The kicker: small, per-weapon, capped at the summit.
function Shastra.damageMult(rank: number): number
	rank = math.clamp(rank, 1, #Shastra.Ranks)
	return 1 + (rank - 1) * Shastra.DamagePerRank
end

return Shastra
