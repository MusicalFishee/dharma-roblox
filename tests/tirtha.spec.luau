--!strict
-- Headless tests for Tirthas: every realm keeps a ford.

local process = require("@lune/process")
local Tirtha = require("../src/shared/Tirtha")
local Zones = require("../src/shared/Zones")

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

print("Tirtha")

-- COVERAGE: every zone keeps a ford — even the sanctuary.
local covered = true
for _, zone in Zones.List do
	local def = Tirtha.forZone(zone.id)
	if not def or def.zoneId ~= zone.id then
		covered = false
		print("    !! fordless realm: " .. zone.id)
	end
end
check("every realm keeps a ford", covered)

-- Well-formedness + sane magnitudes per kind.
local sane = true
for zoneId, def in Tirtha.Defs do
	if not Tirtha.ValidKinds[def.kind] or #def.name == 0 or #def.line == 0 then
		sane = false
	end
	if def.kind == "ward" and not (def.amount > 0 and def.amount < 1 and def.seconds > 0) then
		sane = false -- a ward must soak, not amplify, and must expire
	end
	if def.kind == "empower" and not (def.amount > 1 and def.amount <= 1.25 and def.seconds > 0) then
		sane = false -- empowerment is a gift, not a doubling
	end
	if (def.kind == "tejas" or def.kind == "gold") and def.amount <= 0 then
		sane = false
	end
end
check("every blessing is sane for its kind", sane)
check("the fords speak with different tongues", Tirtha.Defs.ashram.kind ~= Tirtha.Defs.sagara.kind and Tirtha.Defs.sagara.kind ~= Tirtha.Defs.pilgrim_stair.kind)
check("unknown realms keep no ford", Tirtha.forZone("patala") == nil)
check("the summit gives the deepest breath", Tirtha.Defs.kailasa.amount > Tirtha.Defs.ashram.amount)

print(string.format("\n%d passed, %d failed", passed, failed))
if failed > 0 then
	print("FAILURES: " .. table.concat(failures, ", "))
	process.exit(1)
end
