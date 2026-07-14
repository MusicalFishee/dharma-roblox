--!strict
-- Headless tests for the sound design data.

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

print("SoundDefs")

-- Every SFX def is well-formed and uses guaranteed built-in assets.
local count = 0
local allValid = true
for _, s in SoundDefs.Sfx do
	count += 1
	if not string.match(s.path, "^rbxasset://sounds/") then
		allValid = false
	end
	if s.volume <= 0 or s.volume > 1.5 then
		allValid = false
	end
	if s.pitchMin <= 0 or s.pitchMax < s.pitchMin then
		allValid = false
	end
end
check("has a full palette (>= 18 sfx)", count >= 18)
check("all sfx well-formed + built-in rbxasset paths", allValid)

-- Every mapping points at a real def.
local mapsValid = true
for _, name in SoundDefs.AnimSounds do
	if not SoundDefs.Sfx[name] then
		mapsValid = false
	end
end
for _, name in SoundDefs.FeedbackSounds do
	if not SoundDefs.Sfx[name] then
		mapsValid = false
	end
end
check("all event mappings resolve to defined sfx", mapsValid)

-- Coverage: every animation track we broadcast has a sound.
for _, trackName in { "combo1", "combo2", "combo3", "combo4", "throw", "dash", "heal", "ult", "enemySwing", "flinch", "blockstart" } do
	if not SoundDefs.AnimSounds[trackName] then
		check("anim sound coverage: " .. trackName, false)
	end
end
check("defense outcomes covered (Parry/Block/Hit)", SoundDefs.FeedbackSounds.Parry ~= nil and SoundDefs.FeedbackSounds.Block ~= nil and SoundDefs.FeedbackSounds.Hit ~= nil)

-- Boss drums: sorted beats inside the cycle, sane pulse values.
local drums = SoundDefs.BossDrums
check("drum cycle positive", drums.cycleSeconds > 0)
local prev = -1
local beatsValid = #drums.beats >= 3
for _, b in drums.beats do
	if b.t < prev or b.t >= drums.cycleSeconds then
		beatsValid = false
	end
	prev = b.t
	if b.pitch <= 0 or b.volume <= 0 or b.volume > 1 then
		beatsValid = false
	end
end
check("drum beats sorted, in-cycle, sane", beatsValid)
check("drums use a built-in asset", string.match(drums.sfxPath, "^rbxasset://sounds/") ~= nil)

print(string.format("\n%d passed, %d failed", passed, failed))
if failed > 0 then
	print("FAILURES: " .. table.concat(failures, ", "))
	process.exit(1)
end
