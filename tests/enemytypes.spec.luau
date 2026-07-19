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

-- The archer (ranged kiter).
local maricha = EnemyTypes.get("Maricha")
check("Maricha exists and is ranged", maricha.id == "Maricha" and maricha.ranged == true)
check("Maricha outranges every melee reach", maricha.attackRange >= 40)
check("Maricha retreats inside a sane band", (maricha.retreatRange or 0) > 0 and (maricha.retreatRange or 0) < maricha.attackRange)
check("Maricha arrows actually fly", (maricha.projectileSpeed or 0) > 0)

-- The Naga family: serpent-folk of the deep, one identity — venom.
local familyOk = true
for _, id in { "Naga", "NagaCharmer", "NagaRaja" } do
	local def = EnemyTypes.get(id)
	if def.id ~= id or def.inflicts ~= "venom" or (def.minWave or 0) < 30 then
		familyOk = false
	end
end
check("every naga's bite carries venom", familyOk)
check("the serpents sleep until the deep", (EnemyTypes.get("Naga").minWave or 0) == 30)
local charmer = EnemyTypes.get("NagaCharmer")
check("the charmer spits from afar", charmer.ranged == true and charmer.attackRange >= 40 and (charmer.projectileSpeed or 0) > 0)
check("the raja pools where he falls", EnemyTypes.get("NagaRaja").leavesPool == true)
check("the raja is the family's mountain", EnemyTypes.get("NagaRaja").maxHealth > EnemyTypes.get("Naga").maxHealth and EnemyTypes.get("NagaRaja").xpReward > EnemyTypes.get("Naga").xpReward)
check("the king wakes last", (EnemyTypes.get("NagaRaja").minWave or 0) > (EnemyTypes.get("NagaCharmer").minWave or 0) and (EnemyTypes.get("NagaCharmer").minWave or 0) > (EnemyTypes.get("Naga").minWave or 0))

-- The Hima family: frost-folk of the roof of the world, one identity — chill.
local himaOk = true
for _, id in { "Himabhuta", "Tushara", "Himapala" } do
	local def = EnemyTypes.get(id)
	if def.id ~= id or def.inflicts ~= "chill" or (def.minWave or 0) < 60 then
		himaOk = false
	end
end
check("every hima touch carries the cold", himaOk)
check("the frost wakes with the roof of the world", (EnemyTypes.get("Himabhuta").minWave or 0) == 60)
local tushara = EnemyTypes.get("Tushara")
check("the sleet-archer looses from afar", tushara.ranged == true and tushara.attackRange >= 40 and (tushara.projectileSpeed or 0) > 0)
check("the warden is the family's glacier", EnemyTypes.get("Himapala").maxHealth > EnemyTypes.get("Himabhuta").maxHealth and EnemyTypes.get("Himapala").walkSpeed < EnemyTypes.get("Himabhuta").walkSpeed)
check("the cold deepens in order", (EnemyTypes.get("Himapala").minWave or 0) > (EnemyTypes.get("Tushara").minWave or 0) and (EnemyTypes.get("Tushara").minWave or 0) > (EnemyTypes.get("Himabhuta").minWave or 0))
local meleeUnaffected = true
for _, a in EnemyTypes.List do
	if not a.ranged and (a.retreatRange or a.projectileSpeed) then
		meleeUnaffected = false
	end
end
check("melee archetypes carry no ranged fields", meleeUnaffected)

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
