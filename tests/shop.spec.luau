--!strict
-- Headless tests for the shop economy.

local process = require("@lune/process")
local Shop = require("../src/shared/Shop")

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

print("Shop")

-- Prices.
check("tier 0 damage price = base", Shop.price("damage", 0) == 100)
check("prices grow per tier", Shop.price("damage", 3) > Shop.price("damage", 2))
check("unknown id is unbuyable", Shop.price("wings", 0) == math.huge)

-- Effects.
check("no tiers = no bonus", Shop.damageMult(0) == 1 and Shop.healthBonus(0) == 0)
check("damage scales 4%/tier", math.abs(Shop.damageMult(5) - 1.2) < 1e-9)
check("health scales 15/tier", Shop.healthBonus(4) == 60)
check("effects cap at MaxTier", Shop.damageMult(99) == Shop.damageMult(Shop.MaxTier))

-- Buying.
local ok = Shop.tryBuy("damage", 150, 0)
check("buy succeeds with enough gold", ok.ok and ok.goldAfter == 50)
local broke = Shop.tryBuy("damage", 99, 0)
check("buy fails when poor", not broke.ok and broke.reason == "gold" and broke.goldAfter == 99)
local maxed = Shop.tryBuy("damage", 1e9, Shop.MaxTier)
check("buy fails at max tier", not maxed.ok and maxed.reason == "max")
local unknown = Shop.tryBuy("wings", 1e9, 0)
check("buy fails on unknown id", not unknown.ok and unknown.reason == "unknown")

-- Persistence clamp.
check("clampTier junk -> 0", Shop.clampTier("ten") == 0 and Shop.clampTier(-3) == 0)
check("clampTier floors + caps", Shop.clampTier(4.9) == 4 and Shop.clampTier(99) == Shop.MaxTier)

print(string.format("\n%d passed, %d failed", passed, failed))
if failed > 0 then
	print("FAILURES: " .. table.concat(failures, ", "))
	process.exit(1)
end
