--!strict
-- Headless tests for boss special attacks.

local process = require("@lune/process")
local BossSpecials = require("../src/shared/BossSpecials")
local Bosses = require("../src/shared/Bosses")

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

print("BossSpecials")

-- Configs.
check("known boss has its special", BossSpecials.forBoss("Kumbhakarna").name == "Earthshatter")
check("unknown boss falls back to default", BossSpecials.forBoss("???").name == "Ground Slam")
check("bigger boss = bigger radius", BossSpecials.forBoss("Kumbhakarna").radius > BossSpecials.forBoss("Tarakasura").radius)
check("the hunter targets players, slammers self-center", BossSpecials.forBoss("Tarakasura").targetPlayer and not BossSpecials.forBoss("Mahishasura").targetPlayer)
check("telegraph gives a real escape window (>= 1s)", BossSpecials.forBoss("Mahishasura").telegraph >= 1 and BossSpecials.forBoss("Tarakasura").telegraph >= 1 and BossSpecials.forBoss("Kumbhakarna").telegraph >= 1)

-- Every roster boss resolves to a sane special.
local rosterOk = true
for _, wave in { 5, 10, 15 } do
	local boss = Bosses.forWave(wave, 5)
	local sp = BossSpecials.forBoss(boss.id)
	if sp.telegraph < 0.5 or sp.radius <= 0 or sp.damage <= 0 or sp.cooldown <= sp.telegraph then
		rosterOk = false
	end
end
check("all roster bosses have sane specials (cooldown > telegraph)", rosterOk)

-- Hit detection: 2D radius around the slam centre.
local center = { x = 0, z = 0 }
local targets = {
	{ key = "inside", x = 5, z = 5 }, -- dist ~7.07
	{ key = "edge", x = 10, z = 0 }, -- dist 10 (on boundary)
	{ key = "outside", x = 30, z = 0 }, -- dist 30
}
local hit = BossSpecials.hitTargets(center, targets, 10)
local hitSet: { [any]: boolean } = {}
for _, k in hit do
	hitSet[k] = true
end
check("target inside radius is hit", hitSet["inside"] == true)
check("target on the boundary is hit", hitSet["edge"] == true)
check("target outside radius is safe", hitSet["outside"] ~= true)
check("moving out of the zone avoids it", #BossSpecials.hitTargets(center, { { key = "moved", x = 25, z = 25 } }, 12) == 0)

-- Blast resolution.
local dodge = BossSpecials.resolveBlast(60, true, false)
check("i-frames negate the blast", dodge.outcome == "Dodge" and dodge.damage == 0)
local block = BossSpecials.resolveBlast(60, false, true)
check("block soaks half", block.outcome == "Block" and block.damage == 30)
local hitRes = BossSpecials.resolveBlast(60, false, false)
check("unguarded takes full", hitRes.outcome == "Hit" and hitRes.damage == 60)
check("dodge beats block when both", BossSpecials.resolveBlast(60, true, true).outcome == "Dodge")

print(string.format("\n%d passed, %d failed", passed, failed))
if failed > 0 then
	print("FAILURES: " .. table.concat(failures, ", "))
	process.exit(1)
end
