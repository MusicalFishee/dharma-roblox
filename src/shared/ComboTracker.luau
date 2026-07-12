--!strict
-- Tracks a Flow combo chain: consecutive connecting hits within a reset window.
-- Pure logic (time is always passed in), so it runs identically in Roblox and Lune.

local ComboTracker = {}
ComboTracker.__index = ComboTracker

export type ComboTracker = typeof(setmetatable(
	{} :: {
		resetWindow: number,
		count: number,
		lastHitAt: number,
	},
	ComboTracker
))

function ComboTracker.new(resetWindow: number): ComboTracker
	return setmetatable({
		resetWindow = resetWindow,
		count = 0,
		lastHitAt = -math.huge,
	}, ComboTracker)
end

-- Registers a connecting hit at time `now`; returns the new combo count.
-- The chain resets first if too long has passed since the last hit.
function ComboTracker.registerHit(self: ComboTracker, now: number): number
	if now - self.lastHitAt > self.resetWindow then
		self.count = 0
	end
	self.count += 1
	self.lastHitAt = now
	return self.count
end

-- The live combo count, treating an expired chain as 0 (without mutating).
function ComboTracker.current(self: ComboTracker, now: number): number
	if now - self.lastHitAt > self.resetWindow then
		return 0
	end
	return self.count
end

function ComboTracker.reset(self: ComboTracker)
	self.count = 0
	self.lastHitAt = -math.huge
end

return ComboTracker
