--!strict
-- Adhyaya 0's checklist: a small card under the gold counter that carries
-- Agastya's current instruction and its progress. Appears only while the
-- First Lesson runs; vanishes forever once it's done.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local Net = require(ReplicatedStorage.Shared.Net)

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local screenGui = Instance.new("ScreenGui")
screenGui.Name = "DharmaTutorial"
screenGui.ResetOnSpawn = false
screenGui.Parent = playerGui

local card = Instance.new("Frame")
card.Size = UDim2.fromOffset(320, 86)
card.Position = UDim2.new(0, 28, 1, -206)
card.BackgroundColor3 = Color3.fromRGB(24, 20, 30)
card.BackgroundTransparency = 0.15
card.Visible = false
card.Parent = screenGui
local cc = Instance.new("UICorner")
cc.CornerRadius = UDim.new(0, 10)
cc.Parent = card

local header = Instance.new("TextLabel")
header.Size = UDim2.new(1, -20, 0, 18)
header.Position = UDim2.fromOffset(10, 6)
header.BackgroundTransparency = 1
header.Font = Enum.Font.GothamBold
header.TextSize = 12
header.TextColor3 = Color3.fromRGB(255, 200, 40)
header.TextXAlignment = Enum.TextXAlignment.Left
header.Text = "ADHYAYA 0 — THE FIRST LESSON"
header.Parent = card

local instruction = Instance.new("TextLabel")
instruction.Size = UDim2.new(1, -20, 0, 40)
instruction.Position = UDim2.fromOffset(10, 24)
instruction.BackgroundTransparency = 1
instruction.Font = Enum.Font.Gotham
instruction.TextSize = 12
instruction.TextColor3 = Color3.fromRGB(230, 226, 235)
instruction.TextXAlignment = Enum.TextXAlignment.Left
instruction.TextYAlignment = Enum.TextYAlignment.Top
instruction.TextWrapped = true
instruction.Text = ""
instruction.Parent = card

local progress = Instance.new("TextLabel")
progress.Size = UDim2.new(1, -20, 0, 14)
progress.Position = UDim2.new(0, 10, 1, -20)
progress.BackgroundTransparency = 1
progress.Font = Enum.Font.GothamMedium
progress.TextSize = 11
progress.TextColor3 = Color3.fromRGB(150, 200, 255)
progress.TextXAlignment = Enum.TextXAlignment.Left
progress.Text = ""
progress.Parent = card

Net.CombatFeedback.OnClientEvent:Connect(function(data: any)
	if typeof(data) ~= "table" then
		return
	end
	if data.tutorial then
		card.Visible = true
		instruction.Text = "Agastya: “" .. tostring(data.text) .. "”"
		progress.Text = string.format("Step %d of %d   ·   %d / %d", data.step, data.total, data.progress, data.count)
		return
	end
	if data.tutorialDone then
		card.Visible = false
		return
	end
end)

print("[Dharma] TutorialUI ready.")
