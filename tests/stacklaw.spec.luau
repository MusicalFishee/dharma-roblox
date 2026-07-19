--!strict
-- THE STACK LAW: thirty-plus systems now multiply damage — shop, smithing,
-- paths, relics, boons, rites, stances, mastery, siddhis, empowerments, the
-- drawn bow. Each is modest alone; the STACK is the thing that breaks games.
-- This spec computes the worst-case full stack FROM THE LIVE DEFS (it
-- self-updates as content grows) and pins ceilings no future feature can
-- silently cross. If a new multiplier lands and the stack passes the wall,
-- the suite fails and the balance conversation happens BEFORE players do it.

local process = require("@lune/process")
local Shop = require("../src/shared/Shop")
local Weapons = require("../src/shared/Weapons")
local Paths = require("../src/shared/Paths")
local Relics = require("../src/shared/Relics")
local Vara = require("../src/shared/Vara")
local Yajna = require("../src/shared/Yajna")
local Bhava = require("../src/shared/Bhava")
local Shastra = require("../src/shared/Shastra")
local Siddhis = require("../src/shared/Siddhis")
local Abilities = require("../src/shared/Abilities")
local Enchants = require("../src/shared/Enchants")
local Tirtha = require("../src/shared/Tirtha")

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

print("StackLaw")

-- ── Gather every outgoing source at its worst ──
local shopMax = Shop.damageMult(Shop.MaxTier)

local weaponMax = 1
local sigTakenFloor = 1
local sigFinisherMax = 1
for _, w in Weapons.List do
	weaponMax = math.max(weaponMax, Weapons.damageMult((w :: any).id, Weapons.MaxTier))
	local sig = Weapons.signatureOf((w :: any).id)
	sigTakenFloor = math.min(sigTakenFloor, sig.damageTakenMult)
	sigFinisherMax = math.max(sigFinisherMax, sig.finisherDamageMult)
end

local passiveMax = 1
local siddhiMax = 1
for pathId, def in Paths.Defs do
	passiveMax = math.max(passiveMax, (def :: any).passive.damageMult)
	siddhiMax = math.max(siddhiMax, Siddhis.effectsFor(pathId, Siddhis.MaxLevel).damageMult or 1)
end

local slotBestDamage = { crown = 1, kavacha = 1, charm = 1 }
local slotFloorTaken = { crown = 1, kavacha = 1, charm = 1 }
for _, def in Relics.Defs do
	local slot = (def :: any).slot
	local dm = ((def :: any).bonus.damageMult :: number?) or 1
	local tm = ((def :: any).bonus.damageTakenMult :: number?) or 1
	if slotBestDamage[slot] and dm > slotBestDamage[slot] then
		slotBestDamage[slot] = dm
	end
	if slotFloorTaken[slot] and tm < slotFloorTaken[slot] then
		slotFloorTaken[slot] = tm
	end
end
local relicWorst = slotBestDamage.crown * slotBestDamage.kavacha * slotBestDamage.charm
local relicTakenFloor = slotFloorTaken.crown * slotFloorTaken.kavacha * slotFloorTaken.charm

local varaDamage, varaAbility, varaTakenFloor = 1, 1, 1
for _, boon in Vara.Pool do
	varaDamage *= ((boon :: any).effect.damageMult :: number?) or 1
	varaAbility *= ((boon :: any).effect.abilityDamageMult :: number?) or 1
	varaTakenFloor *= ((boon :: any).effect.damageTakenMult :: number?) or 1
end

local yajnaWorst = 1
for _, def in Yajna.Catalog do
	yajnaWorst *= ((def :: any).effect.damageMult :: number?) or 1
end

local bhavaMax, bhavaTakenFloor = 1, 1
for _, def in Bhava.Defs do
	bhavaMax = math.max(bhavaMax, def.effects.damageMult)
	bhavaTakenFloor = math.min(bhavaTakenFloor, def.effects.damageTakenMult)
end

local shastraMax = Shastra.damageMult(#Shastra.Ranks)

local empowerMax = 1
local shieldFloor = 1
for _, def in Abilities.Catalog do
	if (def :: any).kind == "ward" then
		if (def :: any).wardKind == "empower" then
			empowerMax = math.max(empowerMax, (def :: any).power)
		elseif (def :: any).wardKind == "shield" then
			shieldFloor = math.min(shieldFloor, (def :: any).power)
		end
	end
end
for _, def in Tirtha.Defs do
	if def.kind == "empower" then
		empowerMax = math.max(empowerMax, def.amount)
	elseif def.kind == "ward" then
		shieldFloor = math.min(shieldFloor, def.amount)
	end
end

local enchFloor = 1
for _, def in Enchants.List do
	local fx = Enchants.effects((def :: any).id)
	enchFloor = math.min(enchFloor, (fx.damageTakenMult :: number?) or 1)
end

-- ── The walls ──
local meleeWorst = shopMax * weaponMax * passiveMax * relicWorst * varaDamage * yajnaWorst * bhavaMax * shastraMax
print(string.format("    the full melee stack, worst case: x%.2f", meleeWorst))
check("the melee stack stays mortal", meleeWorst < 6)

local abilityWorst = passiveMax * varaDamage * varaAbility * yajnaWorst * bhavaMax * siddhiMax * empowerMax * Abilities.Charge.MaxMult
print(string.format("    the full Astra stack, worst case: x%.2f (drawn to the full)", abilityWorst))
check("the Astra stack stays mortal", abilityWorst < 9)

local incomingFloor = enchFloor * shieldFloor * relicTakenFloor * varaTakenFloor * sigTakenFloor * bhavaTakenFloor
print(string.format("    the deepest turtle takes: x%.2f of every blow", incomingFloor))
check("no build approaches invulnerability", incomingFloor > 0.2)

-- ── Per-source caps: each voice in the choir stays a voice ──
-- The gada's max-tier smithing (x1.52) is the tallest single voice by
-- design — the wall sits just above its crown, so any NEW source that
-- tries to sing louder fails the suite.
check("no single outgoing source out-sings the gada's crown", shopMax <= 1.55 and weaponMax <= 1.55 and passiveMax <= 1.55 and bhavaMax <= 1.55 and shastraMax <= 1.55 and siddhiMax <= 1.55 and empowerMax <= 1.55)
check("no stacked CATEGORY exceeds 1.6x", relicWorst <= 1.6 and varaDamage * varaAbility <= 1.6 and yajnaWorst <= 1.6)
check("only the drawn bow may double", Abilities.Charge.MaxMult <= 2)
check("finishers stay finishers", sigFinisherMax <= 2)
check("no single guard passes half", shieldFloor >= 0.5 and bhavaTakenFloor >= 0.5 and enchFloor >= 0.5 and sigTakenFloor >= 0.9 and relicTakenFloor >= 0.8)

print(string.format("\n%d passed, %d failed", passed, failed))
if failed > 0 then
	print("FAILURES: " .. table.concat(failures, ", "))
	process.exit(1)
end
