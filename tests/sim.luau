--!strict
-- A full simulated combat encounter run through the REAL game modules.
-- This is the deepest test I can run headlessly: it exercises the enemy AI,
-- Flow combo scaling, parry/block/dodge resolution, the Tejas economy and the
-- Agni Astra — the actual systems the live game uses — and narrates every beat.
--   run with:  lune run tests/sim

local Combat = require("../src/shared/Combat")
local ComboTracker = require("../src/shared/ComboTracker")
local EnemyAI = require("../src/shared/EnemyAI")

local function log(t: number, msg: string)
	print(string.format("[%4.1fs] %s", t, msg))
end

-- Actors
local player = { hp = 100, maxHp = 100, tejas = 0, combo = ComboTracker.new(Combat.Config.ComboResetWindow) }
local enemy = { hp = Combat.Config.EnemyMaxHealth, distance = 30.0 }

-- A scripted player defense plan so every mechanic shows up, keyed by which
-- incoming enemy swing it is: parry the 1st, block the 2nd, dodge the 3rd, eat the 4th.
local incomingCount = 0
local function defenseFor(): Combat.DefenderState
	incomingCount += 1
	if incomingCount == 1 then
		return { isDodging = false, isBlocking = true, blockAgeSeconds = 0.1, facingAttacker = true } -- parry
	elseif incomingCount == 2 then
		return { isDodging = false, isBlocking = true, blockAgeSeconds = 0.9, facingAttacker = true } -- block
	elseif incomingCount == 3 then
		return { isDodging = true, isBlocking = false, blockAgeSeconds = 0, facingAttacker = true } -- dodge
	end
	return { isDodging = false, isBlocking = false, blockAgeSeconds = 0, facingAttacker = true } -- open
end

print("=== Dharma simulated encounter: 1 hero vs 1 Asura ===\n")

local t = 0.0
local dt = 0.6
local enemyNextAttack = 0.0
local swing = 0

while player.hp > 0 and enemy.hp > 0 and t < 30 do
	-- ---- Enemy brain ----
	local action = EnemyAI.decide({
		distance = enemy.distance,
		aggroRange = Combat.Config.EnemyAggroRange,
		attackRange = Combat.Config.EnemyAttackRange,
		attackReady = t >= enemyNextAttack,
		targetAlive = player.hp > 0,
	})

	if action == "Chase" then
		enemy.distance = math.max(0, enemy.distance - Combat.Config.EnemyWalkSpeed * dt)
		log(t, string.format("Asura advances (%.0f studs away)", enemy.distance))
	elseif action == "Attack" then
		enemyNextAttack = t + Combat.Config.EnemyAttackInterval
		local res = Combat.resolveIncomingAttack(Combat.Config.EnemyAttackDamage, defenseFor())
		if res.damage > 0 then
			player.hp -= res.damage
		end
		if res.defenderTejasGain > 0 then
			player.tejas = Combat.clampTejas(player.tejas + res.defenderTejasGain)
		end
		local extra = ""
		if res.outcome == "Parry" then extra = string.format(" (+%d Tejas, Asura staggered!)", res.defenderTejasGain)
		elseif res.outcome == "Block" then extra = string.format(" (chip %.0f)", res.damage) end
		log(t, string.format("Asura strikes -> %s%s  [hero HP %.0f, Tejas %.0f]", res.outcome, extra, player.hp, player.tejas))
	end

	-- ---- Hero offense (only when in reach) ----
	if enemy.distance <= Combat.Config.EnemyAttackRange and enemy.hp > 0 then
		-- Spend a full Tejas bar on the Agni Astra the moment it's available.
		local spent, ok = Combat.trySpendTejas(player.tejas, Combat.Config.AgniAstraCost)
		if ok then
			player.tejas = spent
			enemy.hp = math.max(0, enemy.hp - Combat.Config.AgniAstraDamage)
			log(t, string.format(">>> HERO casts AGNI ASTRA for %d! [Asura HP %.0f]", Combat.Config.AgniAstraDamage, enemy.hp))
		else
			swing += 1
			local kind: Combat.AttackKind = (swing % 4 == 0) and "Heavy" or "Light"
			local combo = player.combo:registerHit(t)
			local dmg = Combat.computeAttackDamage(kind, combo - 1)
			enemy.hp = math.max(0, enemy.hp - dmg)
			player.tejas = Combat.clampTejas(player.tejas + Combat.Config.TejasPerHitLanded)
			log(t, string.format("Hero %s hit: FLOW x%d for %.1f  [Asura HP %.0f, Tejas %.0f]", kind, combo, dmg, enemy.hp, player.tejas))
		end
	end

	t += dt
end

print("")
if enemy.hp <= 0 then
	log(t, string.format("ASURA DEFEATED. Hero survives with %.0f HP.", player.hp))
elseif player.hp <= 0 then
	log(t, "Hero has fallen.")
else
	log(t, "Encounter timed out.")
end
