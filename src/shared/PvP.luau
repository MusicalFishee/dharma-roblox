--!strict
-- Honor duels: consent-only PvP. Challenge -> accept -> countdown -> first one down
-- loses. No griefing surface: nobody can touch you without your yes. Pure rules +
-- tuning (Lune-tested); PvPService runs the live duels.

local PvP = {}

PvP.Config = {
	-- PvP damage is softened so a duel is a fight, not two crits and a corpse.
	DamageMult = 0.6,
	-- Seconds a challenge waits for an answer before it evaporates.
	ChallengeExpiry = 30,
	-- Seconds a duel may run before it's called a draw.
	DuelDuration = 180,
	-- The standoff before blades are live.
	CountdownSeconds = 3,
}

export type ChallengeCheck = {
	ok: boolean,
	reason: string, -- "ok" | "self" | "busy" | "targetBusy"
}

-- May `challenger` challenge `target`? Busy = already dueling or awaiting an answer.
function PvP.canChallenge(isSelf: boolean, challengerBusy: boolean, targetBusy: boolean): ChallengeCheck
	if isSelf then
		return { ok = false, reason = "self" }
	end
	if challengerBusy then
		return { ok = false, reason = "busy" }
	end
	if targetBusy then
		return { ok = false, reason = "targetBusy" }
	end
	return { ok = true, reason = "ok" }
end

function PvP.isExpired(now: number, expiresAt: number): boolean
	return now >= expiresAt
end

return PvP
