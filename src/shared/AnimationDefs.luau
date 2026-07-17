--!strict
-- Procedural combat animations: keyframed joint rotations (degrees) sampled over time.
-- Pure data + math (Lune-testable); the client Animator applies poses to Motor6Ds.
--
-- Joint names are R15 Motor6Ds: Waist, Neck, RightShoulder, LeftShoulder,
-- RightElbow, LeftElbow, RightHip, LeftHip. Angles are {pitch, yaw, roll}.

local AnimationDefs = {}

export type Pose = { [string]: { number } }
export type Keyframe = { time: number, pose: Pose }
export type Track = {
	name: string,
	duration: number,
	-- Held tracks clamp on their final pose until stopped (e.g. blocking).
	hold: boolean?,
	keyframes: { Keyframe },
}

local ZERO: Pose = {}

local function track(name: string, duration: number, keyframes: { Keyframe }, hold: boolean?): Track
	return { name = name, duration = duration, hold = hold, keyframes = keyframes }
end

AnimationDefs.Tracks = {
	-- ---- LMB combo chain ----
	-- 1: right jab
	combo1 = track("combo1", 0.25, {
		{ time = 0, pose = ZERO },
		{ time = 0.08, pose = {
			Waist = { 0, -25, 0 },
			RightShoulder = { 85, 0, -8 },
			RightElbow = { 12, 0, 0 },
			Neck = { 0, 12, 0 },
		} },
		{ time = 0.25, pose = ZERO },
	}),
	-- 2: left cross
	combo2 = track("combo2", 0.25, {
		{ time = 0, pose = ZERO },
		{ time = 0.08, pose = {
			Waist = { 0, 25, 0 },
			LeftShoulder = { 85, 0, 8 },
			LeftElbow = { 12, 0, 0 },
			Neck = { 0, -12, 0 },
		} },
		{ time = 0.25, pose = ZERO },
	}),
	-- 3: right hook
	combo3 = track("combo3", 0.3, {
		{ time = 0, pose = ZERO },
		{ time = 0.1, pose = {
			Waist = { 0, 35, 0 },
			RightShoulder = { 45, 35, 0 },
		} },
		{ time = 0.18, pose = {
			Waist = { 0, -40, 0 },
			RightShoulder = { 80, -25, -10 },
			RightElbow = { 40, 0, 0 },
		} },
		{ time = 0.3, pose = ZERO },
	}),
	-- 4: two-hand overhead FINISHER
	combo4 = track("combo4", 0.45, {
		{ time = 0, pose = ZERO },
		{ time = 0.15, pose = {
			Waist = { -12, 0, 0 },
			RightShoulder = { 170, 0, -10 },
			LeftShoulder = { 170, 0, 10 },
			Neck = { -10, 0, 0 },
		} },
		{ time = 0.28, pose = {
			Waist = { 28, 0, 0 },
			RightShoulder = { 55, 0, -8 },
			LeftShoulder = { 55, 0, 8 },
			RightElbow = { 15, 0, 0 },
			LeftElbow = { 15, 0, 0 },
			Neck = { 15, 0, 0 },
		} },
		{ time = 0.45, pose = ZERO },
	}),

	-- ---- Abilities ----
	-- Z: hurl the Agni Astra
	throw = track("throw", 0.35, {
		{ time = 0, pose = ZERO },
		{ time = 0.1, pose = {
			Waist = { 0, 30, 0 },
			RightShoulder = { 150, 20, 0 },
		} },
		{ time = 0.2, pose = {
			Waist = { 8, -30, 0 },
			RightShoulder = { 95, -10, -10 },
			RightElbow = { 10, 0, 0 },
		} },
		{ time = 0.35, pose = ZERO },
	}),
	-- X: dash lean (also used for Q dodge)
	dash = track("dash", 0.35, {
		{ time = 0, pose = ZERO },
		{ time = 0.08, pose = {
			Waist = { 22, 0, 0 },
			RightShoulder = { -35, 0, 12 },
			LeftShoulder = { -35, 0, -12 },
			Neck = { -12, 0, 0 },
		} },
		{ time = 0.35, pose = ZERO },
	}),
	-- C: raise arms to the heavens, gentle
	heal = track("heal", 0.6, {
		{ time = 0, pose = ZERO },
		{ time = 0.22, pose = {
			RightShoulder = { 150, 0, 25 },
			LeftShoulder = { 150, 0, -25 },
			Neck = { -18, 0, 0 },
		} },
		{ time = 0.42, pose = {
			RightShoulder = { 150, 0, 25 },
			LeftShoulder = { 150, 0, -25 },
			Neck = { -18, 0, 0 },
		} },
		{ time = 0.6, pose = ZERO },
	}),
	-- V: crouch, then arch skyward as the storm answers
	ult = track("ult", 0.8, {
		{ time = 0, pose = ZERO },
		{ time = 0.12, pose = {
			Waist = { 18, 0, 0 },
			RightShoulder = { -20, 0, 10 },
			LeftShoulder = { -20, 0, -10 },
			RightHip = { 12, 0, 0 },
			LeftHip = { 12, 0, 0 },
		} },
		{ time = 0.32, pose = {
			Waist = { -18, 0, 0 },
			RightShoulder = { 178, 0, 6 },
			LeftShoulder = { 178, 0, -6 },
			Neck = { -25, 0, 0 },
		} },
		{ time = 0.62, pose = {
			Waist = { -18, 0, 0 },
			RightShoulder = { 178, 0, 6 },
			LeftShoulder = { 178, 0, -6 },
			Neck = { -25, 0, 0 },
		} },
		{ time = 0.8, pose = ZERO },
	}),

	-- ---- Reactions / enemies ----
	-- Wide haymaker for enemy strikes.
	enemySwing = track("enemySwing", 0.4, {
		{ time = 0, pose = ZERO },
		{ time = 0.14, pose = {
			Waist = { 0, 40, 0 },
			RightShoulder = { 50, 45, 0 },
		} },
		{ time = 0.26, pose = {
			Waist = { 6, -35, 0 },
			RightShoulder = { 90, -25, -12 },
			RightElbow = { 20, 0, 0 },
		} },
		{ time = 0.4, pose = ZERO },
	}),
	-- Quick recoil when struck.
	flinch = track("flinch", 0.25, {
		{ time = 0, pose = ZERO },
		{ time = 0.07, pose = {
			Waist = { -14, 0, 0 },
			Neck = { -16, 0, 4 },
			RightShoulder = { 15, 0, -10 },
			LeftShoulder = { 15, 0, 10 },
		} },
		{ time = 0.25, pose = ZERO },
	}),
	-- Guard: forearms crossed, HELD until block ends.
	block = track("block", 0.15, {
		{ time = 0, pose = ZERO },
		{ time = 0.15, pose = {
			RightShoulder = { 75, 0, -40 },
			LeftShoulder = { 75, 0, 40 },
			RightElbow = { 50, 0, 0 },
			LeftElbow = { 50, 0, 0 },
			Waist = { 6, 0, 0 },
		} },
	}, true),
	-- ---- Emotes ----
	emote_namaste = track("emote_namaste", 2.2, {
		{ time = 0, pose = {} },
		{ time = 0.4, pose = {
			RightShoulder = { 95, 0, -60 },
			LeftShoulder = { 95, 0, 60 },
			RightElbow = { 70, 0, 0 },
			LeftElbow = { 70, 0, 0 },
			Neck = { 18, 0, 0 },
		} },
		{ time = 1.8, pose = {
			RightShoulder = { 95, 0, -60 },
			LeftShoulder = { 95, 0, 60 },
			RightElbow = { 70, 0, 0 },
			LeftElbow = { 70, 0, 0 },
			Neck = { 18, 0, 0 },
		} },
		{ time = 2.2, pose = {} },
	}),
	emote_warcry = track("emote_warcry", 1.6, {
		{ time = 0, pose = {} },
		{ time = 0.25, pose = {
			Waist = { -12, 0, 0 },
			RightShoulder = { 170, 0, -15 },
			LeftShoulder = { 170, 0, 15 },
			Neck = { -20, 0, 0 },
		} },
		{ time = 1.2, pose = {
			Waist = { -12, 0, 0 },
			RightShoulder = { 170, 0, -15 },
			LeftShoulder = { 170, 0, 15 },
			Neck = { -20, 0, 0 },
		} },
		{ time = 1.6, pose = {} },
	}),
	emote_meditate = track("emote_meditate", 1.0, {
		{ time = 0, pose = {} },
		{ time = 0.6, pose = {
			RightHip = { 80, 0, 25 },
			LeftHip = { 80, 0, -25 },
			RightShoulder = { 40, 0, -30 },
			LeftShoulder = { 40, 0, 30 },
			Neck = { 15, 0, 0 },
			Waist = { 8, 0, 0 },
		} },
	}, true),
} :: { [string]: Track }

-- Interpolates the track's pose at time `t` (clamped to [0, duration]).
-- Joints missing from a keyframe are treated as {0,0,0} so they blend home.
function AnimationDefs.sample(trackDef: Track, t: number): Pose
	local kfs = trackDef.keyframes
	if #kfs == 0 then
		return {}
	end

	t = math.clamp(t, 0, trackDef.duration)

	-- Find the bracketing keyframes.
	local before = kfs[1]
	local after = kfs[#kfs]
	for i = 1, #kfs - 1 do
		if t >= kfs[i].time and t <= kfs[i + 1].time then
			before = kfs[i]
			after = kfs[i + 1]
			break
		end
	end

	local span = after.time - before.time
	local alpha = if span > 0 then (t - before.time) / span else 1

	-- Union of joints present in either keyframe.
	local joints: { [string]: boolean } = {}
	for j in before.pose do
		joints[j] = true
	end
	for j in after.pose do
		joints[j] = true
	end

	local out: Pose = {}
	for j in joints do
		local a = before.pose[j] or { 0, 0, 0 }
		local b = after.pose[j] or { 0, 0, 0 }
		out[j] = {
			a[1] + (b[1] - a[1]) * alpha,
			a[2] + (b[2] - a[2]) * alpha,
			a[3] + (b[3] - a[3]) * alpha,
		}
	end
	return out
end

return AnimationDefs
