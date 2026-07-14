--!strict
-- Headless tests for the Astra kit configs + cast gating.

local process = require("@lune/process")
local Abilities = require("../src/shared/Abilities")

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

print("Abilities")

-- Config sanity.
check("all four slots configured", Abilities.Config.Z ~= nil and Abilities.Config.X ~= nil and Abilities.Config.C ~= nil and Abilities.Config.V ~= nil)
check("ultimate costs a full bar", Abilities.Config.V.tejasCost == 100)
check("ultimate has the longest cooldown", Abilities.Config.V.cooldown > Abilities.Config.C.cooldown and Abilities.Config.C.cooldown > Abilities.Config.X.cooldown)
check("ultimate has an AoE radius", (Abilities.Config.V.radius or 0) > 0)

-- Cast gating.
local ok = Abilities.tryCast("X", 50, -100, 0)
check("cast succeeds with tejas + off cooldown", ok.ok and ok.reason == "ok")
check("cast spends the cost", ok.tejasAfter == 30)

local cd = Abilities.tryCast("X", 50, 0, 1.0) -- used 1s ago, cooldown 3s
check("cast blocked on cooldown", not cd.ok and cd.reason == "cooldown")
check("cooldown block spends nothing", cd.tejasAfter == 50)

local broke = Abilities.tryCast("V", 60, -100, 0) -- ult needs 100
check("cast blocked without tejas", not broke.ok and broke.reason == "tejas")

local unknown = Abilities.tryCast("Q", 100, -100, 0)
check("unknown slot rejected", not unknown.ok and unknown.reason == "unknown")

local exact = Abilities.tryCast("Z", 35, -100, 0)
check("exact tejas is enough", exact.ok and exact.tejasAfter == 0)

local afterCd = Abilities.tryCast("X", 50, 0, 3.01)
check("cast allowed once cooldown elapses", afterCd.ok)

print(string.format("\n%d passed, %d failed", passed, failed))
if failed > 0 then
	print("FAILURES: " .. table.concat(failures, ", "))
	process.exit(1)
end
