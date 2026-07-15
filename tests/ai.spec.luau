--!strict
-- Headless tests for enemy decision logic.

local process = require("@lune/process")
local EnemyAI = require("../src/shared/EnemyAI")

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

local function perceive(over: { [string]: any }): EnemyAI.Perception
	local p: EnemyAI.Perception = {
		distance = 100,
		aggroRange = 120,
		attackRange = 16,
		attackReady = true,
		targetAlive = true,
	}
	for k, v in over do
		(p :: any)[k] = v
	end
	return p
end

print("EnemyAI")

check("far away -> Idle", EnemyAI.decide(perceive({ distance = 200 })) == "Idle")
check("dead target -> Idle", EnemyAI.decide(perceive({ targetAlive = false })) == "Idle")
check("in aggro, out of reach -> Chase", EnemyAI.decide(perceive({ distance = 80 })) == "Chase")
check("in reach + ready -> Attack", EnemyAI.decide(perceive({ distance = 10, attackReady = true })) == "Attack")
check("in reach but on cooldown -> Chase", EnemyAI.decide(perceive({ distance = 10, attackReady = false })) == "Chase")
check("exactly at attackRange counts as in reach", EnemyAI.decide(perceive({ distance = 16, attackReady = true })) == "Attack")

-- Kiting (ranged archetypes with a retreatRange).
local kite = { attackRange = 55, retreatRange = 20 }
check("kiter crowded + on cooldown -> Retreat", EnemyAI.decide(perceive({ distance = 10, attackReady = false, attackRange = kite.attackRange, retreatRange = kite.retreatRange })) == "Retreat")
check("kiter crowded but ready snaps a point-blank shot", EnemyAI.decide(perceive({ distance = 10, attackReady = true, attackRange = kite.attackRange, retreatRange = kite.retreatRange })) == "Attack")
check("kiter in the sweet spot on cooldown holds ground", EnemyAI.decide(perceive({ distance = 35, attackReady = false, attackRange = kite.attackRange, retreatRange = kite.retreatRange })) == "Idle")
check("kiter beyond range still chases", EnemyAI.decide(perceive({ distance = 80, attackReady = false, attackRange = kite.attackRange, retreatRange = kite.retreatRange, aggroRange = 130 })) == "Chase")
check("melee (no retreatRange) still pressures on cooldown", EnemyAI.decide(perceive({ distance = 10, attackReady = false })) == "Chase")

print(string.format("\n%d passed, %d failed", passed, failed))
if failed > 0 then
	print("FAILURES: " .. table.concat(failures, ", "))
	process.exit(1)
end
