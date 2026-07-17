--!strict
-- Headless tests for input badges: classification, validity, glyphs.

local process = require("@lune/process")
local InputBadge = require("../src/shared/InputBadge")

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

print("InputBadge")

-- Classification.
check("every gamepad slot is a pad", InputBadge.classify("Gamepad1") == "gamepad" and InputBadge.classify("Gamepad8") == "gamepad")
check("touch is thumbs", InputBadge.classify("Touch") == "touch")
check("keys are keys", InputBadge.classify("Keyboard") == "keyboard")
check("every mouse is keys too", InputBadge.classify("MouseButton1") == "keyboard" and InputBadge.classify("MouseMovement") == "keyboard" and InputBadge.classify("MouseWheel") == "keyboard")
check("noise classifies to nothing", InputBadge.classify("Focus") == "" and InputBadge.classify("TextInput") == "" and InputBadge.classify("Accelerometer") == "")

-- Validity (the server's gate against junk reports).
check("all three methods are valid", InputBadge.valid("keyboard") and InputBadge.valid("gamepad") and InputBadge.valid("touch"))
check("junk methods are not", not InputBadge.valid("telepathy") and not InputBadge.valid(""))

-- Glyphs: one each, all distinct, unknown shows nothing.
local seen: { [string]: boolean } = {}
local glyphsOk = true
for _, m in InputBadge.Methods do
	local g = InputBadge.glyphFor(m)
	if #g == 0 or seen[g] then
		glyphsOk = false
	end
	seen[g] = true
end
check("three distinct glyphs", glyphsOk)
check("the unknown wears no badge", InputBadge.glyphFor("telepathy") == "")

print(string.format("\n%d passed, %d failed", passed, failed))
if failed > 0 then
	print("FAILURES: " .. table.concat(failures, ", "))
	process.exit(1)
end
