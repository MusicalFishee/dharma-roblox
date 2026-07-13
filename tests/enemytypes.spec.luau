--!strict
-- Headless tests for the enemy roster.

local process = require("@lune/process")
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

print("EnemyTypes")

-- Every archetype is well-formed.
local allValid = true
local count = 0
for id, a in EnemyTypes.List do
	count += 1
	if a.id ~= id or a.maxHealth <= 0 or a.xpReward <= 0 or a.weight <= 0 or #a.skin ~= 3 then
		allValid = false
	end
end
check("has multiple archetypes", count >= 4)
check("all archetypes well-formed", allValid)

-- Roster sanity: the tank is tankier, the swarm is faster.
check("Rakshasa tankier than Asura", EnemyTypes.get("Rakshasa").maxHealth > EnemyTypes.get("Asura").maxHealth)
check("Pisacha faster than Rakshasa", EnemyTypes.get("Pisacha").walkSpeed > EnemyTypes.get("Rakshasa").walkSpeed)
check("tougher enemies reward more XP", EnemyTypes.get("Rakshasa").xpReward > EnemyTypes.get("Pisacha").xpReward)

-- get() falls back safely.
check("unknown id falls back to Asura", EnemyTypes.get("Nonexistent").id == "Asura")

-- pick() with a forced roll returns a valid archetype.
local forced = EnemyTypes.pick(function(_lo, _hi)
	return 1 -- lowest roll -> first bucket
end)
check("pick returns a valid archetype", forced ~= nil and forced.maxHealth > 0)

print(string.format("\n%d passed, %d failed", passed, failed))
if failed > 0 then
	print("FAILURES: " .. table.concat(failures, ", "))
	process.exit(1)
end
