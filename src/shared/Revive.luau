--!strict
-- Uddhāra ("the lifting up"): falling in battle doesn't kill you outright — you
-- bleed out, crawling, and a brother-in-arms can fight to your side and lift you.
-- Only when the clock runs dry (or nobody is left standing) does the fall become
-- a death, and the ordinary death/party-wipe rules take over from there.
-- Pure config + gating math (Lune-tested); ReviveService runs the live state.

local Revive = {}

Revive.Config = {
	BleedOutSeconds = 20, -- how long a downed warrior lasts unaided
	HoldSeconds = 3, -- how long the lifter holds the prompt
	Range = 10, -- studs within which the lift prompt reaches
	RevivedHealthFraction = 0.35, -- health you stand back up with
	CrawlSpeed = 4, -- WalkSpeed while down
	-- Any heal that lifts a downed player above this mark stands them up
	-- (Amrit orbs and Mahadeva's blessing can raise the fallen).
	AutoLiftAbove = 5,
}

-- Health granted on a lift: a real fighting chance, never less than 1.
function Revive.revivedHealth(maxHealth: number): number
	return math.max(1, math.floor(maxHealth * Revive.Config.RevivedHealthFraction))
end

-- Seconds left on the bleed-out clock (never negative).
function Revive.remainingSeconds(downedAt: number, now: number): number
	return math.max(0, Revive.Config.BleedOutSeconds - (now - downedAt))
end

function Revive.isBledOut(downedAt: number, now: number): boolean
	return Revive.remainingSeconds(downedAt, now) <= 0
end

export type LiftCheck = {
	ok: boolean,
	reason: string, -- "ok" | "lifter" | "target"
}

-- Gate a lift: the lifter must be standing (alive, not downed themselves) and
-- the target must actually be down.
function Revive.canLift(lifterAlive: boolean, lifterDowned: boolean, targetDowned: boolean): LiftCheck
	if not targetDowned then
		return { ok = false, reason = "target" }
	end
	if not lifterAlive or lifterDowned then
		return { ok = false, reason = "lifter" }
	end
	return { ok = true, reason = "ok" }
end

-- An external heal big enough to stand you back up?
function Revive.healLifts(health: number): boolean
	return health > Revive.Config.AutoLiftAbove
end

return Revive
