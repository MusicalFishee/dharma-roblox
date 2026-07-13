--!strict
-- Headless tests for the LMB auto-combo chain.

local process = require("@lune/process")
local ComboChain = require("../src/shared/ComboChain")

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

local cfg = { length = 4, hitInterval = 0.28, finisherLockout = 0.7, resetWindow = 1.5 }

print("ComboChain")

-- A clean 4-hit chain: Light, Light, Light, Heavy(finisher).
local c = ComboChain.new(cfg)
local r1 = c:tryAdvance(0.0)
local r2 = c:tryAdvance(0.3)
local r3 = c:tryAdvance(0.6)
local r4 = c:tryAdvance(0.9)
check("hit 1 is Light", r1.accepted and r1.kind == "Light" and r1.index == 1)
check("hit 2 is Light", r2.accepted and r2.kind == "Light" and r2.index == 2)
check("hit 3 is Light", r3.accepted and r3.kind == "Light" and r3.index == 3)
check("hit 4 is Heavy finisher", r4.accepted and r4.kind == "Heavy" and r4.isFinisher)

-- Immediately after the finisher: locked out (recovery).
local rLocked = c:tryAdvance(1.0)
check("swing during recovery is rejected", (not rLocked.accepted) and rLocked.reason == "recovery")

-- After the lockout passes, the chain restarts at hit 1 (Light).
local rAfter = c:tryAdvance(0.9 + cfg.finisherLockout + 0.01)
check("first swing after recovery is Light hit 1", rAfter.accepted and rAfter.kind == "Light" and rAfter.index == 1)

-- Cadence gate: swinging too fast is rejected.
local c2 = ComboChain.new(cfg)
c2:tryAdvance(0.0)
local rFast = c2:tryAdvance(0.1) -- only 0.1s later, < 0.28 interval
check("too-fast swing is rejected", (not rFast.accepted) and rFast.reason == "cooldown")

-- Reset window: a long pause restarts the chain at 1.
local c3 = ComboChain.new(cfg)
c3:tryAdvance(0.0)
c3:tryAdvance(0.3) -- index 2
local rPause = c3:tryAdvance(0.3 + cfg.resetWindow + 0.5) -- long pause
check("chain resets to hit 1 after a long pause", rPause.accepted and rPause.index == 1)

print(string.format("\n%d passed, %d failed", passed, failed))
if failed > 0 then
	print("FAILURES: " .. table.concat(failures, ", "))
	process.exit(1)
end
