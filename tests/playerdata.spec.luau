--!strict
-- Headless tests for the saved-data schema + validation (corruption safety).

local process = require("@lune/process")
local PlayerData = require("../src/shared/PlayerData")

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

print("PlayerData")

check("default starts at 0 XP", PlayerData.default().totalXp == 0)
check("default has version", PlayerData.default().version == PlayerData.Version)

-- Validation is the corruption net.
check("nil -> default", PlayerData.validate(nil).totalXp == 0)
check("string junk -> default", PlayerData.validate("hacked").totalXp == 0)
check("valid xp preserved", PlayerData.validate({ totalXp = 1234 }).totalXp == 1234)
check("negative xp rejected", PlayerData.validate({ totalXp = -50 }).totalXp == 0)
check("non-number xp rejected", PlayerData.validate({ totalXp = "9999" }).totalXp == 0)
check("float xp floored", PlayerData.validate({ totalXp = 500.9 }).totalXp == 500)
check("missing field filled", PlayerData.validate({}).totalXp == 0)
check("extra fields ignored", PlayerData.validate({ totalXp = 10, hacked = true }).totalXp == 10)

-- Serialize snapshots cleanly.
check("serialize floors + clamps", PlayerData.serialize(-3).totalXp == 0 and PlayerData.serialize(42.7).totalXp == 42)
check("serialize round-trips through validate", PlayerData.validate(PlayerData.serialize(777)).totalXp == 777)

print(string.format("\n%d passed, %d failed", passed, failed))
if failed > 0 then
	print("FAILURES: " .. table.concat(failures, ", "))
	process.exit(1)
end
