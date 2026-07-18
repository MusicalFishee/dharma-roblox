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

return Akhada
