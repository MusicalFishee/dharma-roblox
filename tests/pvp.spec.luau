--!strict
-- Honor duels: tuning sanity and the consent rules.

local process = require("@lune/process")
local PvP = require("../src/shared/PvP")

local passed, failed = 0, 0
local failures: { string } = {}
local function check(name: string, cond: boolean)
	if cond then
		passed += 1
		print("  ok   " .. name)
	else
		failed += 1
		table.insert(failures, name)
		print("  FAIL " .. name)
	end
end

print("PvP")

-- Tuning.
check("pvp damage is softened but real", PvP.Config.DamageMult > 0 and PvP.Config.DamageMult < 1)
check("challenges expire", PvP.Config.ChallengeExpiry > 0)
check("duels cannot run forever", PvP.Config.DuelDuration > 0)
check("there is a standoff before blades are live", PvP.Config.CountdownSeconds >= 1)

-- Consent rules.
check("cannot duel yourself", PvP.canChallenge(true, false, false).reason == "self")
check("cannot challenge while busy", PvP.canChallenge(false, true, false).reason == "busy")
check("cannot challenge the spoken-for", PvP.canChallenge(false, false, true).reason == "targetBusy")
check("free warriors may clash", PvP.canChallenge(false, false, false).ok == true)
check("self check outranks busy checks", PvP.canChallenge(true, true, true).reason == "self")

-- Expiry math.
check("not expired before the deadline", PvP.isExpired(10, 11) == false)
check("expired exactly at the deadline", PvP.isExpired(11, 11) == true)

print(string.format("\n%d passed, %d failed", passed, failed))
if failed > 0 then
	print("FAILURES: " .. table.concat(failures, ", "))
	process.exit(1)
end
