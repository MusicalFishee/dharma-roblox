--!strict
-- The Akhada: the practice yard. An unkillable dummy at the arena's edge
-- takes every blade and Astra you can land and reads your damage back over
-- a rolling window — the honest mirror every build tinkerer needs.
-- Pure window math (Lune-tested); AkhadaService owns the dummy.

local Akhada = {}

Akhada.Config = {
	DummyHealth = 100000,
	WindowSeconds = 10, -- the rolling read
	ResetBelowFraction = 0.5, -- topped back up before it can ever fall
	ComboGapSeconds = 3, -- a string of blows survives silences up to this
	MinReportHits = 5, -- shorter strings end without a report — no poke spam
}

-- The sparring partner: rung in by the yard bell. Fights with the REAL
-- defense rules (parry, dodge, block — all of it) but pulls its punches,
-- and its death pays nothing: no XP, no kill, no loot. Practice, pure.
Akhada.Spar = {
	DisplayName = "Sparring Rakshasa",
	Health = 1500,
	Damage = 8, -- pulled punches — cadence to read, not a beating
	AttackInterval = 2.4,
	WalkSpeed = 12,
	AggroRadius = 40,
	AttackRange = 6,
	LeashRadius = 50, -- never dragged off to gank the meditation grove
	LonelySeconds = 60, -- bows out when nobody trains with it
}

export type HitEvent = {
	at: number,
	amount: number,
}

-- Total damage inside the window ending at `now`, and its per-second rate.
function Akhada.readOver(events: { HitEvent }, now: number, window: number): (number, number)
	local total = 0
	for _, e in events do
		if now - e.at <= window and e.amount > 0 then
			total += e.amount
		end
	end
	return total, total / math.max(window, 1)
end

-- Drop events older than the window (the caller prunes in place).
function Akhada.prune(events: { HitEvent }, now: number, window: number): { HitEvent }
	local kept: { HitEvent } = {}
	for _, e in events do
		if now - e.at <= window then
			table.insert(kept, e)
		end
	end
	return kept
end

-- A string: one unbroken run of blows, tracked per striker. The combo lab.
export type Run = {
	startedAt: number,
	lastAt: number,
	hits: number,
	total: number,
	maxHit: number,
}

-- Fold a blow into a string: extends the live run if it lands within the
-- gap, otherwise closes it (returned second) and opens a fresh one.
function Akhada.advance(run: Run?, now: number, amount: number, gap: number): (Run, Run?)
	if run ~= nil and now - run.lastAt <= gap then
		return {
			startedAt = run.startedAt,
			lastAt = now,
			hits = run.hits + 1,
			total = run.total + amount,
			maxHit = math.max(run.maxHit, amount),
		}, nil
	end
	return { startedAt = now, lastAt = now, hits = 1, total = amount, maxHit = amount }, run
end

-- Has this string gone quiet past the gap? (The caller closes and reports.)
function Akhada.isStale(run: Run, now: number, gap: number): boolean
	return now - run.lastAt > gap
end

-- Only strings worth reading get read back.
function Akhada.isNotable(run: Run, minHits: number): boolean
	return run.hits >= minHits
end

-- Today's fiercest: the session's best 10-second readings, ranked.
export type BestEntry = {
	name: string,
	dps: number,
}

function Akhada.rankBest(best: { [number]: BestEntry }, n: number): { BestEntry }
	local out: { BestEntry } = {}
	for _, entry in best do
		table.insert(out, entry)
	end
	table.sort(out, function(a, b)
		return a.dps > b.dps
	end)
	while #out > math.max(n, 0) do
		table.remove(out)
	end
	return out
end

return Akhada
