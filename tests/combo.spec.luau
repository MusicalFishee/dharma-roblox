--!strict
-- Headless tests for the Flow combo tracker.

local process = require("@lune/process")
local ComboTracker = require("../src/shared/ComboTracker")

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

print("ComboTracker")

local t = ComboTracker.new(1.5)
check("starts at 0", t:current(0) == 0)
check("first hit -> 1", t:registerHit(0) == 1)
check("chained hit within window -> 2", t:registerHit(1.0) == 2)
check("another chained hit -> 3", t:registerHit(2.0) == 3)
check("hit after the window resets to 1", t:registerHit(4.0) == 1) -- 4.0 - 2.0 = 2.0 > 1.5

local t2 = ComboTracker.new(1.0)
t2:registerHit(0)
t2:registerHit(0.5)
check("current sees live chain", t2:current(1.0) == 2)
check("current reports 0 once expired", t2:current(2.0) == 0)
t2:reset()
check("reset clears count", t2:current(0) == 0)

print(string.format("\n%d passed, %d failed", passed, failed))
if failed > 0 then
	print("FAILURES: " .. table.concat(failures, ", "))
	process.exit(1)
end
