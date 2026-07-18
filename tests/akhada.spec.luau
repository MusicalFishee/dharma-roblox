--!strict
-- Headless tests for the Akhada's rolling damage window.

local process = require("@lune/process")
local Akhada = require("../src/shared/Akhada")

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

print("Akhada")

local cfg = Akhada.Config
check("the dummy is a mountain", cfg.DummyHealth >= 10000)
check("the window is a real read", cfg.WindowSeconds >= 5)
check("the dummy tops up before half", cfg.ResetBelowFraction > 0 and cfg.ResetBelowFraction < 1)

local events = { { at = 100, amount = 50 }, { at = 105, amount = 30 }, { at = 109, amount = 20 } }
local total, dps = Akhada.readOver(events, 110, 10)
check("the window sums what it holds", total == 100)
check("the rate divides by the window", math.abs(dps - 10) < 1e-9)

local total2 = Akhada.readOver(events, 112, 10)
check("old blows fall out of the read", total2 == 50)
check("an empty yard reads zero", (Akhada.readOver({}, 100, 10)) == 0)
check("negative junk never counts", (Akhada.readOver({ { at = 100, amount = -50 } }, 100, 10)) == 0)

local pruned = Akhada.prune(events, 112, 10)
check("pruning keeps only the window", #pruned == 2 and pruned[1].at == 105)
check("pruning an empty list is calm", #Akhada.prune({}, 100, 10) == 0)

print(string.format("\n%d passed, %d failed", passed, failed))
if failed > 0 then
	print("FAILURES: " .. table.concat(failures, ", "))
	process.exit(1)
end
