--!strict
-- The LMB auto-combo chain (Blox-Fruits M1 style): repeated clicks flow through
-- light hits, every Nth click is the heavy finisher, then a brief recovery lockout
-- so it can't be spammed. Pure logic — time is passed in — so it's Lune-testable.

local ComboChain = {}
ComboChain.__index = ComboChain

export type Config = {
	length: number, -- swings per chain; the last one is the finisher
	hitInterval: number, -- min seconds between accepted swings
	finisherLockout: number, -- recovery after the finisher
	resetWindow: number, -- pause longer than this and the chain restarts
}

export type Result = {
	accepted: boolean,
	reason: string, -- "ok" | "cooldown" | "recovery"
	index: number, -- 1..length on accepted swings, else 0
	kind: string, -- "Light" | "Heavy"
	isFinisher: boolean,
}

export type ComboChain = typeof(setmetatable(
	{} :: {
		cfg: Config,
		index: number,
		lastHitAt: number,
		lockedUntil: number,
	},
	ComboChain
))

function ComboChain.new(cfg: Config): ComboChain
	return setmetatable({
		cfg = cfg,
		index = 0,
		lastHitAt = -math.huge,
		lockedUntil = -math.huge,
	}, ComboChain)
end

local function reject(reason: string): Result
	return { accepted = false, reason = reason, index = 0, kind = "Light", isFinisher = false }
end

-- Attempts to advance the chain at time `now`. Returns whether the swing lands
-- and, if so, which hit it is and whether it's the heavy finisher.
function ComboChain.tryAdvance(self: ComboChain, now: number): Result
	-- Still recovering from the finisher.
	if now < self.lockedUntil then
		return reject("recovery")
	end
	-- Swinging faster than the cadence allows.
	if now - self.lastHitAt < self.cfg.hitInterval then
		return reject("cooldown")
	end
	-- Paused too long — start a fresh chain.
	if now - self.lastHitAt > self.cfg.resetWindow then
		self.index = 0
	end

	self.index += 1
	self.lastHitAt = now

	local isFinisher = self.index >= self.cfg.length
	local landedIndex = self.index
	local kind = if isFinisher then "Heavy" else "Light"

	if isFinisher then
		self.lockedUntil = now + self.cfg.finisherLockout
		self.index = 0
	end

	return { accepted = true, reason = "ok", index = landedIndex, kind = kind, isFinisher = isFinisher }
end

return ComboChain
