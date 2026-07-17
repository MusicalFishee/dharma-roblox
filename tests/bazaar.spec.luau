--!strict
-- Headless tests for the Vajra Bazaar (products) + Agnihotra (login streak).

local process = require("@lune/process")
local Products = require("../src/shared/Products")
local Streak = require("../src/shared/Streak")

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

print("Bazaar")

-- Catalog integrity: currencies only, by law.
local kinds = { gold = true, shards = true }
local defsOk = true
local keysSeen: { [string]: boolean } = {}
local idsSeen: { [number]: boolean } = {}
for _, def in Products.List do
	if keysSeen[def.key] or not kinds[def.kind] or def.amount <= 0 or #def.name == 0 then
		defsOk = false
	end
	keysSeen[def.key] = true
	if def.productId ~= 0 then
		if idsSeen[def.productId] then
			defsOk = false -- two products sharing an id would double-grant
		end
		idsSeen[def.productId] = true
	end
end
check("products are well-formed, currencies only", defsOk)
check("both currencies are on the shelf", Products.byKey("gold_small") ~= nil and Products.byKey("shards_small") ~= nil)
check("bigger bundles hold more", (Products.byKey("gold_large") :: Products.ProductDef).amount > (Products.byKey("gold_small") :: Products.ProductDef).amount)

-- Lookup rules.
check("byKey finds and misses", Products.byKey("gold_medium") ~= nil and Products.byKey("robux_printer") == nil)
check("unregistered id 0 never matches a receipt", Products.byProductId(0) == nil)

print("Agnihotra")

-- Day math.
check("day stamp is UTC days", Streak.dayStamp(0) == 0 and Streak.dayStamp(86400) == 1 and Streak.dayStamp(86399) == 0)

-- The flame's rules.
local fresh = Streak.advance(0, 0, 100)
check("first visit lights the flame", fresh.count == 1 and fresh.claimed)

local again = Streak.advance(100, 3, 100)
check("same day offers nothing twice", again.count == 3 and not again.claimed)

local grows = Streak.advance(100, 3, 101)
check("consecutive days grow the flame", grows.count == 4 and grows.claimed)

local lapsed = Streak.advance(100, 6, 103)
check("a missed day starts anew", lapsed.count == 1 and lapsed.claimed)

-- The offering ladder.
check("day 1 pays gold, no shards", Streak.rewardFor(1).gold == 100 and Streak.rewardFor(1).shards == 0)
check("day 3 kindles shards", Streak.rewardFor(3).shards == 1)
check("day 5 deepens", Streak.rewardFor(5).shards == 2)
check("day 7 is full devotion", Streak.rewardFor(7).gold == 700 and Streak.rewardFor(7).shards == 3)
check("the reward caps but never shrinks", Streak.rewardFor(30).gold == Streak.rewardFor(Streak.Cap).gold and Streak.rewardFor(30).shards == 3)
check("rewards rise with devotion", Streak.rewardFor(2).gold > Streak.rewardFor(1).gold)

print(string.format("\n%d passed, %d failed", passed, failed))
if failed > 0 then
	print("FAILURES: " .. table.concat(failures, ", "))
	process.exit(1)
end
