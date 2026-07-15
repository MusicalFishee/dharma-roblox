--!strict
-- Screen shake: a brief, decaying camera kick on the big combat moments — your
-- crits and finishers, a boss slam landing, or taking a solid hit. Rides on top of
-- the default camera via Humanoid.CameraOffset, so it never fights the camera scripts.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Players = game:GetService("Players")

local Net = require(ReplicatedStorage.Shared.Net)

local player = Players.LocalPlayer
local rng = Random.new()

local shakeStart = 0
local shakeUntil = 0
local shakeAmp = 0

local function currentHumanoid(): Humanoid?
	local char = player.Character
	if not char then
		return nil
	end
	return char:FindFirstChildOfClass("Humanoid")
end

-- Trigger a kick. Concurrent kicks take the strongest rather than stacking to nausea.
local function kick(amplitude: number, duration: number)
	local now = os.clock()
	if now < shakeUntil and shakeAmp >= amplitude then
		return
	end
	shakeStart = now
	shakeUntil = now + duration
	shakeAmp = amplitude
end

RunService.RenderStepped:Connect(function()
	local hum = currentHumanoid()
	if not hum then
		return
	end
	local now = os.clock()
	if now >= shakeUntil then
		-- Settle back to neutral (skip the writes once we're basically there).
		if hum.CameraOffset.Magnitude > 0.01 then
			hum.CameraOffset = hum.CameraOffset:Lerp(Vector3.zero, 0.25)
		end
		return
	end
	local span = math.max(shakeUntil - shakeStart, 0.0001)
	local falloff = (shakeUntil - now) / span
	local a = shakeAmp * falloff
	hum.CameraOffset = Vector3.new(
		(rng:NextNumber() * 2 - 1) * a,
		(rng:NextNumber() * 2 - 1) * a,
		(rng:NextNumber() * 2 - 1) * a * 0.5
	)
end)

Net.CombatFeedback.OnClientEvent:Connect(function(data: any)
	if typeof(data) ~= "table" then
		return
	end

	-- A boss slam landing shakes the whole arena.
	if data.bossSpecial == "impact" then
		kick(1.6, 0.5)
		return
	end

	if data.incoming then
		-- Taking a solid, unguarded hit.
		if data.outcome == "Hit" then
			kick(0.7, 0.25)
		end
		return
	end

	-- Your own offense: crits kick hardest, finishers a touch less.
	if data.outcome == "Hit" then
		if data.isCrit then
			kick(1.1, 0.32)
		elseif data.isFinisher then
			kick(0.9, 0.28)
		end
	end
end)

print("[Dharma] CameraShake ready.")
