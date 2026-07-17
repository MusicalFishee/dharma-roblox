--!strict
-- Vīra streaks: chain kills without pause and the war itself starts chanting
-- your rank — Vīra, then the chariot-warrior ladder: Rathi, Atirathi, Mahārathi.
-- Each rank announced pays a surge of Tejas. Let the streak cool and it's gone.
-- Pure streak math (Lune-tested); EnemyService feeds it per killing blow.

local Vira = {}

Vira.Window = 6 -- seconds between kills before the streak cools

export type Rank = {
	count: number,
	name: string,
	tejas: number, -- the surge paid when the rank is reached
}

Vira.Ranks = {
	{ count = 5, name = "VĪRA", tejas = 10 },
	{ count = 10, name = "RATHI", tejas = 15 },
	{ count = 20, name = "ATIRATHI", tejas = 25 },
	{ count = 35, name = "MAHĀRATHI", tejas = 40 },
} :: { Rank }

export type Register = {
	count: number,
	cooled: boolean, -- the old streak expired and this kill started a new one
}

-- Register a killing blow at `now`, given the previous streak.
function Vira.register(count: number, lastKillAt: number, now: number): Register
	if count <= 0 or now - lastKillAt > Vira.Window then
		return { count = 1, cooled = count > 0 }
	end
	return { count = count + 1, cooled = false }
end

-- The rank reached EXACTLY at this count (announcements fire once per rank).
function Vira.rankAt(count: number): Rank?
	for _, rank in Vira.Ranks do
		if rank.count == count then
			return rank
		end
	end
	return nil
end

return Vira
