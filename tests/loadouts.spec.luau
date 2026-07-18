--!strict
-- Headless tests for Loadouts: slots, names, and honest capture.

local process = require("@lune/process")
local Loadouts = require("../src/shared/Loadouts")

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

print("Loadouts")

check("three slots, no more", Loadouts.MaxSlots == 3)
check("names stay readable", Loadouts.MaxNameLength >= 8 and Loadouts.MaxNameLength <= 24)

check("real slots pass", Loadouts.isValidSlot(1) and Loadouts.isValidSlot(3))
check("slot zero is refused", not Loadouts.isValidSlot(0))
check("slot four is refused", not Loadouts.isValidSlot(4))
check("half slots are refused", not Loadouts.isValidSlot(1.5))

check("names are trimmed and collapsed", Loadouts.cleanName("  Boss   Night  ", 1) == "Boss Night")
check("long names are capped", #Loadouts.cleanName(string.rep("a", 99), 1) == Loadouts.MaxNameLength)
check("an empty name earns a plain one", Loadouts.cleanName("", 2) == "Loadout 2")
check("whitespace alone earns a plain one", Loadouts.cleanName("   ", 3) == "Loadout 3")

local equipped = { crown = "baka_crown", kavacha = "", charm = "charm_vetala" }
local cap = Loadouts.capture(" Horde ", "talwar", equipped, 1)
check("capture snapshots the weapon", cap.weapon == "talwar")
check("capture snapshots every relic slot", cap.crown == "baka_crown" and cap.kavacha == "" and cap.charm == "charm_vetala")
check("capture cleans the name", cap.name == "Horde")
equipped.crown = "changed_later"
check("capture copies, never references", cap.crown == "baka_crown")

check("relics are counted honestly", Loadouts.relicCount(cap) == 2)
check("a bare set counts zero", Loadouts.relicCount({ name = "x", weapon = "talwar", crown = "", kavacha = "", charm = "" }) == 0)

print(string.format("\n%d passed, %d failed", passed, failed))
if failed > 0 then
	print("FAILURES: " .. table.concat(failures, ", "))
	process.exit(1)
end
