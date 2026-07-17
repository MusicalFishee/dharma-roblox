--!strict
-- Headless tests for the animation keyframes + sampler.

local process = require("@lune/process")
local AnimationDefs = require("../src/shared/AnimationDefs")

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

local function near(a: number, b: number): boolean
	return math.abs(a - b) < 1e-6
end

print("Animations")

-- Every track is well-formed: sorted keyframes within [0, duration], valid angles.
local trackCount = 0
local allValid = true
for name, t in AnimationDefs.Tracks do
	trackCount += 1
	if t.duration <= 0 or #t.keyframes < 2 or t.name ~= name then
		allValid = false
	end
	local prev = -1
	for _, kf in t.keyframes do
		if kf.time < prev or kf.time > t.duration + 1e-9 then
			allValid = false
		end
		prev = kf.time
		for _, angles in kf.pose do
			if #angles ~= 3 then
				allValid = false
			end
		end
	end
end
check("has all 14 tracks (11 combat + 3 emotes)", trackCount == 14)
check("every track well-formed (sorted, in-range, 3-angle poses)", allValid)

-- Combat coverage: one track per combo hit + abilities + reactions.
for _, name in { "combo1", "combo2", "combo3", "combo4", "throw", "dash", "heal", "ult", "enemySwing", "flinch", "block" } do
	if not AnimationDefs.Tracks[name] then
		check("track exists: " .. name, false)
	end
end
check("block is a held pose", AnimationDefs.Tracks.block.hold == true)
check("finisher is the longest combo hit", AnimationDefs.Tracks.combo4.duration > AnimationDefs.Tracks.combo1.duration)

-- Sampler math on a synthetic track.
local synth: AnimationDefs.Track = {
	name = "synth",
	duration = 1,
	keyframes = {
		{ time = 0, pose = { J = { 0, 0, 0 } } },
		{ time = 1, pose = { J = { 90, -30, 10 } } },
	},
}
local mid = AnimationDefs.sample(synth, 0.5)
check("midpoint lerps angles", near(mid.J[1], 45) and near(mid.J[2], -15) and near(mid.J[3], 5))
local startP = AnimationDefs.sample(synth, 0)
check("t=0 gives first keyframe", near(startP.J[1], 0))
local endP = AnimationDefs.sample(synth, 1)
check("t=duration gives last keyframe", near(endP.J[1], 90))
local over = AnimationDefs.sample(synth, 99)
check("t past duration clamps", near(over.J[1], 90))

-- Joints absent from one keyframe blend toward zero.
local fade: AnimationDefs.Track = {
	name = "fade",
	duration = 1,
	keyframes = {
		{ time = 0, pose = { J = { 100, 0, 0 } } },
		{ time = 1, pose = {} },
	},
}
local fmid = AnimationDefs.sample(fade, 0.5)
check("missing joint blends home to 0", near(fmid.J[1], 50))

-- Real track sanity: combo1 peaks its punch at the strike keyframe.
local strike = AnimationDefs.sample(AnimationDefs.Tracks.combo1, 0.08)
check("combo1 strike pose has the right arm extended", near(strike.RightShoulder[1], 85))
local recovered = AnimationDefs.sample(AnimationDefs.Tracks.combo1, 0.25)
check("combo1 fully recovers to neutral", near(recovered.RightShoulder and recovered.RightShoulder[1] or 0, 0))

print(string.format("\n%d passed, %d failed", passed, failed))
if failed > 0 then
	print("FAILURES: " .. table.concat(failures, ", "))
	process.exit(1)
end
