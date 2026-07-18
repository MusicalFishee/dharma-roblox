--!strict
-- Headless tests for gamepad bindings + the shared panel directory.

local process = require("@lune/process")
local Gamepad = require("../src/shared/Gamepad")
local PanelDirectory = require("../src/shared/PanelDirectory")

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

print("Gamepad")

-- One button, one job — no chords, no doubles.
local buttonsSeen: { [string]: boolean } = {}
local bindsOk = true
local actions = { attack = 0, block = 0, dodge = 0, ability = 0, menu = 0 }
for _, bind in Gamepad.Binds do
	if buttonsSeen[bind.button] then
		bindsOk = false -- a button may serve only one master
	end
	buttonsSeen[bind.button] = true
	if actions[bind.action] == nil or #bind.label == 0 then
		bindsOk = false
	else
		actions[bind.action] += 1
	end
	if not (string.find(bind.button, "^Button") or string.find(bind.button, "^DPad")) then
		bindsOk = false -- gamepad buttons only
	end
	if bind.action == "ability" and (bind.slot ~= "Z" and bind.slot ~= "X" and bind.slot ~= "C" and bind.slot ~= "V") then
		bindsOk = false
	end
end
check("every button serves exactly one action", bindsOk)
check("the whole kit is reachable", actions.attack == 1 and actions.block == 1 and actions.dodge == 1 and actions.ability == 4 and actions.menu == 1)
check("no bind claims the jump button (A belongs to Roblox)", buttonsSeen.ButtonA == nil)

-- Ability slots cover Z/X/C/V exactly once each.
local slots: { [string]: boolean } = {}
for _, bind in Gamepad.Binds do
	if bind.action == "ability" then
		slots[bind.slot :: string] = true
	end
end
check("all four astra slots are on the pad", slots.Z and slots.X and slots.C and slots.V)

print("PanelDirectory")

-- The directory: unique labels and guis, well-formed open requests.
local labels: { [string]: boolean } = {}
local guis: { [string]: boolean } = {}
local dirOk = true
for _, entry in PanelDirectory.Entries do
	if labels[entry.label] or guis[entry.gui] or #entry.label == 0 then
		dirOk = false
	end
	labels[entry.label] = true
	guis[entry.gui] = true
	if not string.find(entry.gui, "^Dharma") then
		dirOk = false -- every panel gui carries the Dharma prefix
	end
	if entry.remote ~= nil and (entry.payloadAction == nil or #entry.payloadAction == 0) then
		dirOk = false -- a remote without an action is a misfire
	end
end
check("panels are unique and well-formed", dirOk)
check("the directory is sixteen panels deep", #PanelDirectory.Entries == 16)

print(string.format("\n%d passed, %d failed", passed, failed))
if failed > 0 then
	print("FAILURES: " .. table.concat(failures, ", "))
	process.exit(1)
end
