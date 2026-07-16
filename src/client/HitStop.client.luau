--!strict
-- Hit-stop triggers: the frame-freeze that makes big hits FEEL big. Crits freeze
-- longest, finishers next; eating a boss slam freezes you too (impact cuts both ways).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Net = require(ReplicatedStorage.Shared.Net)
local Animator = require(script.Parent.Animator)

local CRIT_FREEZE = 0.12
local FINISHER_FREEZE = 0.09
local SLAM_FREEZE = 0.10

Net.CombatFeedback.OnClientEvent:Connect(function(data: any)
	if typeof(data) ~= "table" then
		return
	end

	-- Own offense connecting.
	if not data.incoming and data.outcome == "Hit" then
		if data.isCrit then
			Animator.freeze(CRIT_FREEZE)
		elseif data.isFinisher then
			Animator.freeze(FINISHER_FREEZE)
		end
		return
	end

	-- Eating a clean hit from a boss blast.
	if data.incoming and data.outcome == "Hit" then
		Animator.freeze(SLAM_FREEZE * 0.6)
	end
end)

print("[Dharma] HitStop ready — impacts have weight.")
