--!strict
-- Headless tests for boss special configs + slam hit-detection.

local process = require("@lune/process")
local BossSpecials = require("../src/shared/BossSpecials")

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
check("specials do real damage", BossSpecials.forBoss("Mahishasura").damage > 0)
check("bigger boss = bigger radius", BossSpecials.forBoss("Kumbhakarna").radius > BossSpecials.forBoss("Tarakasura").radius)

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
check("dodging out of the zone avoids it", #BossSpecials.hitTargets(center, { { key = "moved", x = 25, z = 25 } }, 12) == 0)

print(string.format("\n%d passed, %d failed", passed, failed))
if failed > 0 then
	print("FAILURES: " .. table.concat(failures, ", "))
	process.exit(1)
end
