--!strict
-- Plays procedural animation tracks on any R15 character by driving Motor6D C0s.
-- One active track per character; joints restore to their base pose on finish.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local AnimationDefs = require(ReplicatedStorage.Shared.AnimationDefs)

local Animator = {}

type JointInfo = {
	motor: Motor6D,
	baseC0: CFrame,
}

type ActiveTrack = {
	track: AnimationDefs.Track,
	startedAt: number,
	joints: { [string]: JointInfo },
	stopping: boolean,
}

local active: { [Model]: ActiveTrack } = {}

-- Collect the character's Motor6Ds by name (Waist, Neck, RightShoulder, ...).
local function collectJoints(model: Model): { [string]: JointInfo }
	local joints: { [string]: JointInfo } = {}
	for _, desc in model:GetDescendants() do
		if desc:IsA("Motor6D") then
			joints[desc.Name] = { motor = desc, baseC0 = desc.C0 }
		end
	end
	return joints
end

local function restore(state: ActiveTrack)
	for _, info in state.joints do
		if info.motor.Parent then
			info.motor.C0 = info.baseC0
		end
	end
end

-- Start (or replace) a track on a character.
function Animator.play(model: Model, trackName: string)
	local trackDef = AnimationDefs.Tracks[trackName]
	if not trackDef or not model or not model.Parent then
		return
	end

	-- Replacing a track: put its joints back first so offsets don't stack.
	local existing = active[model]
	if existing then
		restore(existing)
	end

	active[model] = {
		track = trackDef,
		startedAt = os.clock(),
		joints = collectJoints(model),
		stopping = false,
	}
end

-- End a held track (e.g. block released).
function Animator.stop(model: Model)
	local state = active[model]
	if state then
		state.stopping = true
	end
end

-- Hit-stop: freeze EVERY animation clock for a beat. The world catches its breath
-- on a big hit, then snaps back — pure impact feel, no physics touched.
local frozenUntil = 0

function Animator.freeze(duration: number)
	frozenUntil = math.max(frozenUntil, os.clock() + duration)
end

RunService.RenderStepped:Connect(function(dt: number)
	local now = os.clock()

	-- While frozen, push every clock forward by the frame so poses hold in place.
	if now < frozenUntil then
		for _, state in active do
			state.startedAt += dt
		end
		return
	end

	for model, state in active do
		local t = now - state.startedAt
		local trackDef = state.track
		local finished = state.stopping
			or (not trackDef.hold and t > trackDef.duration)
			or not model.Parent

		if finished then
			restore(state)
			active[model] = nil
			continue
		end

		local pose = AnimationDefs.sample(trackDef, t)
		for jointName, info in state.joints do
			if not info.motor.Parent then
				continue
			end
			local angles = pose[jointName]
			if angles then
				info.motor.C0 = info.baseC0
					* CFrame.Angles(math.rad(angles[1]), math.rad(angles[2]), math.rad(angles[3]))
			else
				info.motor.C0 = info.baseC0
			end
		end
	end
end)

return Animator
