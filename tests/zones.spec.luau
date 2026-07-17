--!strict
-- Headless tests for zone thresholds + palettes.

local process = require("@lune/process")
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

local function validRgb(c: { number }): boolean
	if #c ~= 3 then
		return false
	end
	for _, v in c do
		if v < 0 or v > 255 then
			return false
		end
	end
	return true
end

print("Zones")

-- Defs well-formed, thresholds strictly ascending starting at 1.
check("has 8 zones", #Zones.List == 8)
local prev = 0
local defsValid = true
local ids: { [string]: boolean } = {}
for _, z in Zones.List do
	if z.threshold <= prev or ids[z.id] then
		defsValid = false
	end
	prev = z.threshold
	ids[z.id] = true
	if not (validRgb(z.ground) and validRgb(z.pillar) and validRgb(z.cap) and validRgb(z.flame) and validRgb(z.ambient) and validRgb(z.fogColor)) then
		defsValid = false
	end
	if #z.groundMaterial == 0 or #z.pillarMaterial == 0 or z.fogEnd <= 0 or z.clockTime < 0 or z.clockTime > 24 then
		defsValid = false
	end
end
check("thresholds ascend, ids unique, palettes valid", defsValid)
check("first zone starts at wave 1", Zones.List[1].threshold == 1)

-- Wave -> zone resolution.
check("wave 1 is the Ashram", Zones.forWave(1).id == "ashram")
check("wave 14 still the Ashram", Zones.forWave(14).id == "ashram")
check("wave 15 enters Dandakaranya", Zones.forWave(15).id == "dandakaranya")
check("wave 29 still Dandakaranya", Zones.forWave(29).id == "dandakaranya")
check("wave 30 enters Sagara Tala", Zones.forWave(30).id == "sagara")
check("wave 59 still Sagara Tala", Zones.forWave(59).id == "sagara")
check("wave 60 climbs into Himavat", Zones.forWave(60).id == "himavat")
check("wave 89 still Himavat", Zones.forWave(89).id == "himavat")
check("wave 90 mounts the Pilgrim's Stair", Zones.forWave(90).id == "pilgrim_stair")
check("wave 120 breaks above the clouds", Zones.forWave(120).id == "meghaloka")
check("wave 160 enters Svarga", Zones.forWave(160).id == "svarga")
check("wave 200 reaches the Threshold of Kailasa", Zones.forWave(200).id == "kailasa")
check("wave 999 stays at the Threshold — no mortal passes it", Zones.forWave(999).id == "kailasa")

-- The forest closes in (fog tightens as you go deeper).
check("deeper zones have heavier fog", Zones.forWave(15).fogEnd < Zones.forWave(1).fogEnd)

print(string.format("\n%d passed, %d failed", passed, failed))
if failed > 0 then
	print("FAILURES: " .. table.concat(failures, ", "))
	process.exit(1)
end
