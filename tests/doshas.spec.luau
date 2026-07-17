--!strict
-- Headless tests for Doshas: cadence, collisions, rolls, scaling, bounties.

local process = require("@lune/process")
local Doshas = require("../src/shared/Doshas")
local Waves = require("../src/shared/Waves")
local Trial = require("../src/shared/Trial")
local Ravana = require("../src/shared/Ravana")
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

local function seq(values: { number }): () -> number
	local i = 0
	return function()
		i += 1
		return values[math.min(i, #values)]
	end
end

print("Doshas")

-- Def integrity.
local defsOk = true
local seen: { [string]: boolean } = {}
for _, id in Doshas.Order do
	local def = Doshas.Defs[id]
	if not def or def.id ~= id or seen[id] or #def.name == 0 or #def.announce == 0 or def.weight <= 0 then
		defsOk = false
	end
	seen[id] = true
	if def.enemyHealthMult < 1 or def.enemyDamageMult < 1 or def.enemySpeedMult < 1 then
		defsOk = false -- a dosha never makes the horde WEAKER
	end
	if def.enemyHealthMult > 1.5 or def.enemyDamageMult > 1.35 or def.enemySpeedMult > 1.3 then
		defsOk = false -- and never unfairly cruel
	end
	if def.bonusGoldPerWave <= 0 or def.bonusXpPerWave <= 0 then
		defsOk = false -- every marked wave pays
	end
end
check("doshas are well-formed, harder-but-fair, always paying", defsOk)
local defCount = 0
for _ in Doshas.Defs do
	defCount += 1
end
check("order covers every dosha", defCount == #Doshas.Order)

-- Cadence: waves ending in 7, clashing with nothing.
check("wave 7 is marked", Doshas.isDoshaWave(7) and Doshas.isDoshaWave(17) and Doshas.isDoshaWave(107))
check("neighbours are not", not Doshas.isDoshaWave(6) and not Doshas.isDoshaWave(8) and not Doshas.isDoshaWave(70))
local noClash = true
for wave = 7, 507, 10 do
	if Waves.isBossWave(wave) or Trial.isTrialWave(wave) or Ravana.isRaidWave(wave) then
		noClash = false
	end
end
check("marked waves never clash with boss, trial, or raid", noClash)

-- Rolls.
check("unmarked waves roll nothing", Doshas.roll(8, seq({ 0 })) == nil)
local firstDosha = Doshas.roll(7, seq({ 0 }))
check("low roll marks with the first dosha", firstDosha ~= nil and firstDosha.id == "amavasya")
local lastDosha = Doshas.roll(7, seq({ 0.999 }))
check("high roll marks with the last", lastDosha ~= nil and lastDosha.id == "maya")

-- Archetype scaling: immutable copy, floored numbers.
local base = EnemyTypes.get("Asura")
local marked = Doshas.applyToArchetype(Doshas.Defs.grahana, base)
check("scaling copies, never mutates", base.maxHealth == EnemyTypes.get("Asura").maxHealth and marked ~= base)
check("grahana deepens health", marked.maxHealth == math.floor(base.maxHealth * 1.4))
check("grahana leaves damage alone", marked.attackDamage == base.attackDamage)
local fevered = Doshas.applyToArchetype(Doshas.Defs.jvara, base)
check("jvara quickens the horde", fevered.walkSpeed > base.walkSpeed)

-- Bounties deepen with the wave.
local shallow = Doshas.bountyFor(Doshas.Defs.amavasya, 7)
local deep = Doshas.bountyFor(Doshas.Defs.amavasya, 47)
check("bounty pays gold and xp", shallow.gold > 0 and shallow.xp > 0)
check("deeper marks pay more", deep.gold > shallow.gold and deep.xp > shallow.xp)


-- The veil must not strip an archetype of its nature.
local archer = EnemyTypes.get("Maricha")
local veiled = Doshas.applyToArchetype(Doshas.Defs.maya, archer)
check("a scaled archer keeps its bow", veiled.ranged == archer.ranged and veiled.id == archer.id)
check("a scaled foe keeps its bounty", veiled.xpReward == archer.xpReward)
local rollA = Doshas.roll(17, seq({ 0.4 }))
local rollB = Doshas.roll(17, seq({ 0.4 }))
check("the same fate falls twice alike", rollA ~= nil and rollB ~= nil and rollA.id == rollB.id)
check("scaled health always floors to whole points", Doshas.applyToArchetype(Doshas.Defs.maya, EnemyTypes.get("Asura")).maxHealth % 1 == 0)

print(string.format("\n%d passed, %d failed", passed, failed))
if failed > 0 then
	print("FAILURES: " .. table.concat(failures, ", "))
	process.exit(1)
end
