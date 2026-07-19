--!strict
-- Headless tests for the Ghats: the flame cap and the tribute.

local process = require("@lune/process")
local Ghat = require("../src/shared/Ghat")

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

print("Ghat")

check("the arena keeps a few memories", Ghat.Config.MaxFlames >= 4 and Ghat.Config.MaxFlames <= 16)
check("the tribute is a breath, not a meal", Ghat.Config.TributeTejas > 0 and Ghat.Config.TributeTejas <= 25)

local flames: { string } = {}
check("a flame under the cap stays", Ghat.push(flames, "a", 3) == nil and #flames == 1)
Ghat.push(flames, "b", 3)
Ghat.push(flames, "c", 3)
check("the cap holds three", #flames == 3)
check("the oldest is released past the cap", Ghat.push(flames, "d", 3) == "a" and #flames == 3 and flames[1] == "b")
check("a cap of junk still keeps one", (function()
	local l: { string } = {}
	Ghat.push(l, "x", 0)
	local released = Ghat.push(l, "y", 0)
	return released == "x" and #l == 1
end)())

print(string.format("\n%d passed, %d failed", passed, failed))
if failed > 0 then
	print("FAILURES: " .. table.concat(failures, ", "))
	process.exit(1)
end
