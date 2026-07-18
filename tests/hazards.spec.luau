--!strict
-- Headless tests for zone hazards: coverage, fairness laws, and depth scaling.

local process = require("@lune/process")
local Hazards = require("../src/shared/Hazards")
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

print("Hazards")

-- The ashram is sanctuary; every deeper realm bites.
check("the ashram is sanctuary", Hazards.forZone("ashram") == nil)
local covered = true
for _, zone in Zones.List do
	if zone.id ~= "ashram" and not Hazards.forZone(zone.id) then
		covered = false
		print("    !! zone has no hazard: " .. zone.id)
	end
end
check("every deeper realm has its hazard", covered)

-- Fairness laws + well-formedness, one sweep.
local fair = true
local seenNames: { [string]: boolean } = {}
for zoneId, def in Hazards.Defs do
	if def.zoneId ~= zoneId or #def.name == 0 or #def.line == 0 or seenNames[def.name] then
		fair = false
	end
	seenNames[def.name] = true
	if def.telegraph < 1.5 or def.telegraph > 3 then
		fair = false -- always readable, never a cheap shot
	end
	if def.radius < 5 or def.radius > 12 or def.count < 1 or def.count > 4 or def.damage <= 0 then
		fair = false
	end
	if def.intervalMin < 15 or def.intervalMax <= def.intervalMin then
		fair = false -- the world strikes, it does not spam
	end
end
check("every hazard is announced and readable", fair)

-- Interval rolls stay inside their bounds.
local roots = Hazards.Defs.dandakaranya
check("a low roll lands at the floor", Hazards.rollInterval(roots, 0) == roots.intervalMin)
check("a high roll stays under the ceiling", Hazards.rollInterval(roots, 0.999) < roots.intervalMax)

-- Depth scaling: gentle, monotonic, capped at 2x.
check("at the gate, the base bite", Hazards.scaledDamage(roots, 0) == roots.damage)
check("depth sharpens the bite", Hazards.scaledDamage(roots, 50) > roots.damage)
check("the bite never passes double", Hazards.scaledDamage(roots, 5000) == roots.damage * 2)
check("negative depth is calm", Hazards.scaledDamage(roots, -10) == roots.damage)

-- The climb hurts more the higher you go.
check("kailasa outbites the forest", Hazards.Defs.kailasa.damage > Hazards.Defs.dandakaranya.damage)
check("the summit throws the widest net", Hazards.Defs.kailasa.count >= Hazards.Defs.dandakaranya.count)

print(string.format("\n%d passed, %d failed", passed, failed))
if failed > 0 then
	print("FAILURES: " .. table.concat(failures, ", "))
	process.exit(1)
end
