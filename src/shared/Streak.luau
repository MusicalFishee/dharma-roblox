--!strict
-- Agnihotra: the daily fire offering. Return each day and the flame grows —
-- escalating gold, then shards; miss a day and it must be lit anew.
-- Pure day math + reward ladder (Lune-tested); DataService grants it on load.

local Streak = {}

Streak.Cap = 7 -- the flame's reward stops growing here (the streak still counts)

-- UTC day number (same clock the dailies use).
function Streak.dayStamp(unixTime: number): number
	return math.floor(unixTime / 86400)
end

export type Advance = {
	count: number, -- the streak after today
	claimed: boolean, -- false = already offered today (no reward)
}

-- Advance the streak for today's visit. Same day = already counted;
-- yesterday = the flame grows; any gap = it starts anew at 1.
function Streak.advance(lastStamp: number, lastCount: number, todayStamp: number): Advance
	if lastStamp == todayStamp and lastCount > 0 then
		return { count = lastCount, claimed = false }
	end
	if lastStamp == todayStamp - 1 and lastCount > 0 then
		return { count = lastCount + 1, claimed = true }
	end
	return { count = 1, claimed = true }
end

export type Offering = {
	gold: number,
	shards: number,
}

-- What today's offering pays: gold every day, shards as devotion deepens.
function Streak.rewardFor(count: number): Offering
	local capped = math.clamp(count, 1, Streak.Cap)
	local shards = 0
	if capped >= 7 then
		shards = 3
	elseif capped >= 5 then
		shards = 2
	elseif capped >= 3 then
		shards = 1
	end
	return {
		gold = 100 * capped,
		shards = shards,
	}
end

return Streak
