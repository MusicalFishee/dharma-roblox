--!strict
-- Headless tests for Astra Siddhis: the mastery curve, ladder integrity
-- (cross-checked against Paths + the ability Catalog), and effect merging.

local process = require("@lune/process")
local Siddhis = require("../src/shared/Siddhis")
local Paths = require("../src/shared/Paths")
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

print("Siddhis")

-- Mastery curve.
check("xp curve rises", Siddhis.xpToNext(2) > Siddhis.xpToNext(1) and Siddhis.xpToNext(9) > Siddhis.xpToNext(5))
check("fresh mastery is level 1", Siddhis.resolve(0).level == 1 and not Siddhis.resolve(0).isMax)
check("negative xp clamps", Siddhis.resolve(-50).level == 1)
local l2 = Siddhis.resolve(Siddhis.xpToNext(1))
check("first threshold reaches level 2", l2.level == 2 and l2.xpIntoLevel == 0)
local total = 0
for l = 1, Siddhis.MaxLevel - 1 do
	total += Siddhis.xpToNext(l)
end
check("full ladder reaches max", Siddhis.resolve(total).isMax and Siddhis.resolve(total).level == Siddhis.MaxLevel)
check("beyond max stays max", Siddhis.resolve(total * 10).level == Siddhis.MaxLevel)

-- Ladder integrity: every path has a full ladder, ids unique, levels rising,
-- and every pierce/fork target is a real catalog ability IN that path's kit.
local laddersOk = true
local idsSeen: { [string]: boolean } = {}
for _, pathId in Paths.Order do
	local ladder = Siddhis.Ladders[pathId]
	if not ladder or #ladder ~= 5 then
		laddersOk = false
		continue
	end
	local kit = Paths.Defs[pathId].kit
	local kitIds: { [string]: boolean } = { [kit.Z] = true, [kit.X] = true, [kit.C] = true, [kit.V] = true }
	local prevLevel = 0
	for _, def in ladder do
		if idsSeen[def.id] or def.level <= prevLevel or def.level > Siddhis.MaxLevel or #def.name == 0 or #def.line == 0 then
			laddersOk = false
		end
		idsSeen[def.id] = true
		prevLevel = def.level
		local target = def.effect.pierceAbility or def.effect.forkAbility
		if target and (not Abilities.Catalog[target] or not kitIds[target]) then
			laddersOk = false
		end
	end
end
check("every path has a well-formed 5-rung ladder", laddersOk)

local ladderCount = 0
for _ in Siddhis.Ladders do
	ladderCount += 1
end
check("no ladders for unknown paths", ladderCount == #Paths.Order)

-- Effect merging.
local none = Siddhis.effectsFor("agni", 1)
check("level 1 has earned nothing", none.damageMult == 1 and none.cooldownMult == 1 and next(none.pierce) == nil)
check("unknown path earns nothing", Siddhis.effectsFor("", 10).damageMult == 1)

local mid = Siddhis.effectsFor("agni", 4)
check("level 4 agni pierces + hits harder", (mid.pierce.agni_astra or 0) == 1 and math.abs(mid.damageMult - 1.08) < 1e-9)
check("level 4 agni hasn't widened yet", mid.radiusMult == 1)

local maxed = Siddhis.effectsFor("agni", 10)
check("maxed agni stacks damage multiplicatively", math.abs(maxed.damageMult - 1.08 * 1.10) < 1e-9)
check("maxed agni cooldowns fall", math.abs(maxed.cooldownMult - 0.85) < 1e-9)

local vayuMax = Siddhis.effectsFor("vayu", 10)
check("maxed vayu forks + gets ult i-frames", (vayuMax.fork.vayu_blade or 0) == 1 and vayuMax.ultIFrames == 1.5)
check("ward bonus adds seconds", vayuMax.wardBonusSeconds == 1.5)

local varunaMax = Siddhis.effectsFor("varuna", 10)
check("maxed varuna heals deeper + doubles rain", math.abs(varunaMax.healBonusFraction - 0.08) < 1e-9 and varunaMax.selfHealMult == 2)

-- Unlock lookups.
check("unlockAt finds the rung", (Siddhis.unlockAt("indra", 6) :: Siddhis.SiddhiDef).id == "storm_hunger")
check("unlockAt misses between rungs", Siddhis.unlockAt("indra", 5) == nil)
check("nextUnlock names the chase", (Siddhis.nextUnlock("indra", 5) :: Siddhis.SiddhiDef).id == "storm_hunger")
check("nothing left past the summit", Siddhis.nextUnlock("indra", 10) == nil)

-- Bounds: mastery must never make an ability spammable or absurd.
local boundsOk = true
for _, pathId in Paths.Order do
	local eff = Siddhis.effectsFor(pathId, 10)
	if eff.cooldownMult < 0.5 or eff.cooldownMult > 1 then
		boundsOk = false
	end
	if eff.damageMult > 1.35 then
		boundsOk = false
	end
end
check("maxed effects stay within sane bounds", boundsOk)

print(string.format("\n%d passed, %d failed", passed, failed))
if failed > 0 then
	print("FAILURES: " .. table.concat(failures, ", "))
	process.exit(1)
end
