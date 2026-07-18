--!strict
-- Bhoota spectate: a wandering spirit may ride the eyes of the living.
-- Pure cycling/eligibility math (Lune-tested); SpectateController drives
-- the camera client-side. Spirits watch FIGHTERS — the fallen, the ghostly,
-- and the meditating are not a show.

local Spectate = {}

-- Who a spirit may watch.
function Spectate.isWatchable(healthPositive: boolean, isBhoota: boolean, isDowned: boolean, isDhyana: boolean): boolean
	return healthPositive and not isBhoota and not isDowned and not isDhyana
end

-- Cycle an index through `count` entries in `dir` (+1 / -1), 1-based, wrapping.
-- An empty list has no index (0).
function Spectate.cycle(count: number, index: number, dir: number): number
	if count <= 0 then
		return 0
	end
	local step = if dir < 0 then -1 else 1
	return ((index - 1 + step) % count) + 1
end

-- Keep a held index sane after the watchable list changes size.
function Spectate.clampIndex(count: number, index: number): number
	if count <= 0 then
		return 0
	end
	return math.clamp(index, 1, count)
end

return Spectate
