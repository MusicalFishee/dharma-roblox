--!strict
-- Headless tests for the event cue map: every epic speaks, and only in
-- voices the palette actually owns.

local process = require("@lune/process")
local SoundDefs = require("../src/shared/SoundDefs")

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

print("SoundCues")

-- Every cue points at a real voice.
local allReal = true
for key, sfxName in SoundDefs.EventCues do
	if not SoundDefs.Sfx[sfxName] then
		allReal = false
		print("    !! cue with no voice: " .. key .. " -> " .. sfxName)
	end
end
check("every cue points at a real voice", allReal)

-- THE LAW: every epic moment speaks. A new epic shipped without a cue
-- fails the suite (add it to this roll when you add its toast).
local epics = {
	"vairiStalks", "vairiFelled", "rahuEclipse", "velFalls", "vyuhaForms",
	"vyuhaCollapse", "moonAnchor", "ghatTribute", "tirthaBlessed",
	"shastraRank", "astraCrowned", "bhavaSet", "sevaComplete",
	"yatraClaimed", "granthaClaimed", "kirtiClaimed", "loadoutApplied", "perfectParry",
}
local allSpeak = true
for _, key in epics do
	if not SoundDefs.EventCues[key] then
		allSpeak = false
		print("    !! a silent epic: " .. key)
	end
end
check("every epic speaks", allSpeak)
check("the roll is not empty ceremony", #epics >= 15)

print(string.format("\n%d passed, %d failed", passed, failed))
if failed > 0 then
	print("FAILURES: " .. table.concat(failures, ", "))
	process.exit(1)
end
