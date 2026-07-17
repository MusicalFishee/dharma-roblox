--!strict
-- Headless tests for Astra Reactions: the element map (cross-checked against
-- the ability Catalog AND the path kits), the pair table, and the gating.

local process = require("@lune/process")
local Reactions = require("../src/shared/Reactions")
local Abilities = require("../src/shared/Abilities")
local Paths = require("../src/shared/Paths")

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

print("Reactions")

-- Every mapped ability is real; every catalog ability is mapped.
local mapOk = true
for abilityId in Reactions.ElementOf do
	if not Abilities.Catalog[abilityId] then
		mapOk = false
	end
end
for abilityId in Abilities.Catalog do
	if not Reactions.ElementOf[abilityId] then
		mapOk = false
		print("    !! unmapped ability: " .. abilityId)
	end
end
check("the element map covers the whole catalog, nothing more", mapOk)

-- Each path's kit is mono-element (a path IS its deva's element).
local pathElement = { agni = "fire", vayu = "wind", varuna = "water", indra = "storm" }
local kitsOk = true
for pathId, element in pathElement do
	local kit = Paths.Defs[pathId].kit
	for _, slot in { "Z", "X", "C", "V" } do
		if Reactions.elementOf((kit :: any)[slot]) ~= element then
			kitsOk = false
		end
	end
end
check("every path's kit carries its deva's element", kitsOk)

-- The unsworn classic kit spans all four elements (the sampler platter).
local classic: { [string]: boolean } = {}
for _, slot in { "Z", "X", "C", "V" } do
	classic[Reactions.elementOf((Paths.DefaultKit :: any)[slot]) :: string] = true
end
check("the unsworn kit tastes all four elements", classic.fire and classic.wind and classic.water and classic.storm)

-- The pair table: all six pairs, both directions, none for same-element.
local flourishes = { ignite = true, slow = true, none = true, knockback = true, tejas = true, chain = true }
local pairCount = 0
local pairsOk = true
local idsSeen: { [string]: boolean } = {}
for i, a in Reactions.Elements do
	for j, b in Reactions.Elements do
		local def = Reactions.reactionFor(a, b)
		if i == j then
			if def ~= nil then
				pairsOk = false
			end
		elseif not def then
			pairsOk = false
		else
			if def ~= Reactions.reactionFor(b, a) then
				pairsOk = false -- must be order-insensitive
			end
			if not flourishes[def.flourish] or def.bonusDamage <= 0 or #def.name == 0 then
				pairsOk = false
			end
			if i < j then
				pairCount += 1
				if idsSeen[def.id] then
					pairsOk = false
				end
				idsSeen[def.id] = true
			end
		end
	end
end
check("six distinct reactions cover every pair, both ways", pairsOk and pairCount == 6)

-- Bonus damage stays a garnish, not the meal.
local boundsOk = true
for _, a in Reactions.Elements do
	for _, b in Reactions.Elements do
		local def = Reactions.reactionFor(a, b)
		if def and (def.bonusDamage < 15 or def.bonusDamage > 60) then
			boundsOk = false
		end
	end
end
check("reaction damage stays in bounds", boundsOk)

-- Gating.
check("a live mark of another element reacts", Reactions.tryReact("fire", 100, 99, "wind") ~= nil)
check("a faded mark does not", Reactions.tryReact("fire", 100, 100.1, "wind") == nil)
check("the same element never reacts", Reactions.tryReact("fire", 100, 99, "fire") == nil)
check("the window's edge still reacts", Reactions.tryReact("fire", 100, 100, "storm") ~= nil)
check("firestorm ignites", (Reactions.reactionFor("fire", "wind") :: Reactions.ReactionDef).flourish == "ignite")
check("charged waters chain", (Reactions.reactionFor("water", "storm") :: Reactions.ReactionDef).flourish == "chain")

print(string.format("\n%d passed, %d failed", passed, failed))
if failed > 0 then
	print("FAILURES: " .. table.concat(failures, ", "))
	process.exit(1)
end
