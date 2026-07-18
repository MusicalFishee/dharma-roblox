--!strict
-- Headless tests for the rites: Yajna offerings (the gold sink) and
-- Shapatha oaths (the double-or-nothing lever).

local process = require("@lune/process")
local Yajna = require("../src/shared/Yajna")
local Shapatha = require("../src/shared/Shapatha")
local EnemyTypes = require("../src/shared/EnemyTypes")

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

print("Yajna")

-- Catalog: one effect per offering, all paying kinds real.
local yajnaOk = true
local count = 0
for _, id in Yajna.Order do
	local def = Yajna.Catalog[id]
	count += 1
	if not def or def.id ~= id or def.baseCost <= 0 or #def.name == 0 or #def.line == 0 then
		yajnaOk = false
	end
	local keys = 0
	for _ in def.effect do
		keys += 1
	end
	if keys ~= 1 then
		yajnaOk = false
	end
end
check("offerings are well-formed, one blessing each", yajnaOk and count == 3)

-- Costs escalate: the fire is a sink, not a subscription.
check("first offering costs the base", Yajna.costFor("ghrta", 0) == 600)
check("repeat offerings cost half again more", Yajna.costFor("ghrta", 1) == 900 and Yajna.costFor("ghrta", 2) == 1350)
check("unknown offerings cost nothing (and give nothing)", Yajna.costFor("cola", 3) == 0)

-- Offer gating.
check("a funded, unlit offering passes", Yajna.tryOffer("soma", 600, false, 0).ok)
check("an offering deducts its price", Yajna.tryOffer("soma", 1000, false, 0).goldAfter == 400)
check("a lit flame refuses more fuel", Yajna.tryOffer("soma", 9999, true, 1).reason == "lit")
check("empty purses feed no fire", Yajna.tryOffer("bilva", 799, false, 0).reason == "gold")
check("unknown rites are refused", Yajna.tryOffer("cola", 9999, false, 0).reason == "unknown")

-- Blessings merge.
local none = Yajna.blessingsFor({})
check("a cold altar blesses nothing", none.xpMult == 1 and none.goldMult == 1 and none.damageMult == 1)
local all = Yajna.blessingsFor({ ghrta = true, soma = true, bilva = true })
check("three flames stack their lanes", math.abs(all.xpMult - 1.1) < 1e-9 and math.abs(all.goldMult - 1.1) < 1e-9 and math.abs(all.damageMult - 1.05) < 1e-9)
check("junk flames are ignored", Yajna.blessingsFor({ cola = true }).xpMult == 1)

print("Shapatha")

-- Oaths: crueler always pays fatter, and cruelty is bounded.
local prev = 0
local oathsOk = true
for _, id in Shapatha.Order do
	local def = Shapatha.Catalog[id]
	if not def or def.id ~= id or #def.name == 0 or #def.line == 0 then
		oathsOk = false
	end
	if def.rewardMult <= prev then
		oathsOk = false -- the order must ascend in pay
	end
	prev = def.rewardMult
	if def.enemyHealthMult < 1 or def.enemyDamageMult < 1 or def.enemyHealthMult > 1.75 or def.enemyDamageMult > 1.75 then
		oathsOk = false
	end
	if def.rewardMult <= 1 then
		oathsOk = false -- every oath must pay MORE than the plain wave
	end
end
check("oaths ascend in cruelty and in pay, within bounds", oathsOk)

-- The cruelest oath pays the most.
check("the great vow pays triple", Shapatha.Catalog.maha.rewardMult == 3)

-- Gating.
check("a fresh oath between waves passes", Shapatha.tryOath("raudra", false, false).ok)
check("no oaths mid-battle", Shapatha.tryOath("raudra", true, false).reason == "battle")
check("one oath per wave", Shapatha.tryOath("ghora", false, true).reason == "sworn")
check("unknown oaths are refused", Shapatha.tryOath("pinky_promise", false, false).reason == "unknown")

-- Archetype cruelty: immutable copy.
local base = EnemyTypes.get("Asura")
local sworn = Shapatha.applyToArchetype(Shapatha.Catalog.ghora, base)
check("the vow copies, never mutates", base.maxHealth == EnemyTypes.get("Asura").maxHealth and sworn ~= base)
check("ghora deepens and sharpens", sworn.maxHealth == math.floor(base.maxHealth * 1.4) and sworn.attackDamage == math.floor(base.attackDamage * 1.2))

-- Bounties scale with wave and vow.
local shallow = Shapatha.bountyFor(Shapatha.Catalog.raudra, 8)
local deepMaha = Shapatha.bountyFor(Shapatha.Catalog.maha, 40)
check("bounties pay gold and xp", shallow.gold > 0 and shallow.xp > 0)
check("deeper waves and crueler vows pay more", deepMaha.gold > shallow.gold and deepMaha.xp > shallow.xp)
check("the same vow pays more on deeper waves", Shapatha.bountyFor(Shapatha.Catalog.raudra, 20).gold > shallow.gold)


-- Dosha and oath compose: a marked wave under a vow is scaled by BOTH.
local Doshas = require("../src/shared/Doshas")
local doubly = Shapatha.applyToArchetype(Shapatha.Catalog.raudra, Doshas.applyToArchetype(Doshas.Defs.grahana, base))
check("a vowed, marked wave stacks both scalings", doubly.maxHealth == math.floor(math.floor(base.maxHealth * 1.4) * 1) and doubly.attackDamage == math.floor(math.floor(base.attackDamage * 1) * 1.5))

print(string.format("\n%d passed, %d failed", passed, failed))
if failed > 0 then
	print("FAILURES: " .. table.concat(failures, ", "))
	process.exit(1)
end
