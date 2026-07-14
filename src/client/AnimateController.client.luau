--!strict
-- Receives animation broadcasts from the server and plays them on any character —
-- your own swings, other players' moves, and enemy attacks alike.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Net = require(ReplicatedStorage.Shared.Net)
local Animator = require(script.Parent.Animator)

Net.AnimEvent.OnClientEvent:Connect(function(model: any, trackName: any)
	if typeof(model) ~= "Instance" or not model:IsA("Model") then
		return
	end
	local name = tostring(trackName)

	if name == "blockstart" then
		Animator.play(model, "block")
	elseif name == "blockend" then
		Animator.stop(model)
	else
		Animator.play(model, name)
	end
end)

print("[Dharma] AnimateController ready — procedural combat animations online.")
