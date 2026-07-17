--!strict
-- Quietly tells the server what this hand is holding — keys, pad, or thumbs —
-- whenever the answer changes. The server can't sense devices; this is the
-- only honest source. One tiny report per change, nothing more.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local Net = require(ReplicatedStorage.Shared.Net)
local InputBadge = require(ReplicatedStorage.Shared.InputBadge)

local reported = ""

local function report(inputType: Enum.UserInputType)
	local method = InputBadge.classify(inputType.Name)
	if #method > 0 and method ~= reported then
		reported = method
		Net.InputReport:FireServer({ method = method })
	end
end

UserInputService.LastInputTypeChanged:Connect(report)
task.delay(1, function()
	report(UserInputService:GetLastInputType())
end)

print("[Dharma] InputReporter ready.")
