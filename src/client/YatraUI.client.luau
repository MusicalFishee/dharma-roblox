--!strict
-- Yatra panel (F key): the free pilgrimage road. Fifteen milestones paid out
-- by level, claimed in order with one press. Never sold, by the founder's law.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")

local Net = require(ReplicatedStorage.Shared.Net)
local Yatra = require(ReplicatedStorage.Shared.Yatra)

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local GOLD = Color3.fromRGB(255, 200, 40)
local PANEL_BG = Color3.fromRGB(18, 15, 22)
local ROW_BG = Color3.fromRGB(30, 25, 38)
local DIM = Color3.fromRGB(120, 115, 130)
local WALKED = Color3.fromRGB(130, 220, 160)

local screenGui = Instance.new("ScreenGui")
screenGui.Name = "DharmaYatra"
screenGui.ResetOnSpawn = false
screenGui.DisplayOrder = 15
screenGui.Enabled = false
screenGui.Parent = playerGui

local panel = Instance.new("Frame")
panel.AnchorPoint = Vector2.new(0.5, 0.5)
panel.Position = UDim2.fromScale(0.5, 0.5)
panel.Size = UDim2.fromOffset(440, 520)
panel.BackgroundColor3 = PANEL_BG
panel.BorderSizePixel = 0
panel.Parent = screenGui
local pc = Instance.new("UICorner")
pc.CornerRadius = UDim.new(0, 14)
pc.Parent = panel

local title = Instance.new("TextLabel")
title.Size = UDim2.new(1, 0, 0, 34)
title.Position = UDim2.fromOffset(0, 10)
title.BackgroundTransparency = 1
title.Font = Enum.Font.GothamBlack
title.TextSize = 24
title.TextColor3 = GOLD
title.Text = "YATRA — THE PILGRIMAGE ROAD"
title.Parent = panel

local sub = Instance.new("TextLabel")
sub.Size = UDim2.new(1, -30, 0, 16)
sub.Position = UDim2.fromOffset(15, 44)
sub.BackgroundTransparency = 1
sub.Font = Enum.Font.Gotham
sub.TextSize = 12
sub.TextColor3 = DIM
sub.Text = "Free, forever. The road pays every walker by level."
sub.Parent = panel

local claimBtn = Instance.new("TextButton")
claimBtn.Size = UDim2.new(1, -30, 0, 40)
claimBtn.Position = UDim2.new(0, 15, 1, -52)
claimBtn.Font = Enum.Font.GothamBlack
claimBtn.TextSize = 16
claimBtn.BackgroundColor3 = Color3.fromRGB(60, 54, 70)
claimBtn.TextColor3 = DIM
claimBtn.Text = "The road waits uphill"
claimBtn.Parent = panel
local cbc = Instance.new("UICorner")
cbc.CornerRadius = UDim.new(0, 10)
cbc.Parent = claimBtn
claimBtn.Activated:Connect(function()
	Net.YatraRequest:FireServer({ action = "claim" })
end)

local list = Instance.new("ScrollingFrame")
list.Position = UDim2.fromOffset(0, 66)
list.Size = UDim2.new(1, 0, 1, -126)
list.BackgroundTransparency = 1
list.BorderSizePixel = 0
list.ScrollBarThickness = 6
list.CanvasSize = UDim2.fromOffset(0, #Yatra.Milestones * 40 + 6)
list.Parent = panel

type Row = { frame: Frame, name: TextLabel, pay: TextLabel }
local rows: { Row } = {}
for i, step in Yatra.Milestones do
	local row = Instance.new("Frame")
	row.Size = UDim2.new(1, -36, 0, 34)
	row.Position = UDim2.fromOffset(15, (i - 1) * 40)
	row.BackgroundColor3 = ROW_BG
	row.BorderSizePixel = 0
	row.Parent = list
	local rc = Instance.new("UICorner")
	rc.CornerRadius = UDim.new(0, 8)
	rc.Parent = row

	local name = Instance.new("TextLabel")
	name.Size = UDim2.new(1, -140, 1, 0)
	name.Position = UDim2.fromOffset(12, 0)
	name.BackgroundTransparency = 1
	name.Font = Enum.Font.GothamBold
	name.TextSize = 13
	name.TextColor3 = DIM
	name.TextXAlignment = Enum.TextXAlignment.Left
	name.Text = string.format("Lv %d — %s", step.level, step.name)
	name.Parent = row

	local pay = Instance.new("TextLabel")
	pay.Size = UDim2.fromOffset(120, 34)
	pay.Position = UDim2.new(1, -132, 0, 0)
	pay.BackgroundTransparency = 1
	pay.Font = Enum.Font.GothamBold
	pay.TextSize = 12
	pay.TextColor3 = DIM
	pay.TextXAlignment = Enum.TextXAlignment.Right
	pay.Text = if step.shards > 0 then string.format("%d g · %d ◆", step.gold, step.shards) else string.format("%d g", step.gold)
	pay.Parent = row

	rows[i] = { frame = row, name = name, pay = pay }
end

Net.CombatFeedback.OnClientEvent:Connect(function(data: any)
	if typeof(data) ~= "table" or not data.yatraInfo then
		return
	end
	local level = tonumber(data.level) or 1
	local claimed = tonumber(data.claimed) or 0
	for i, step in Yatra.Milestones do
		local row = rows[i]
		if i <= claimed then
			row.name.TextColor3 = WALKED
			row.pay.TextColor3 = WALKED
			row.pay.Text = "walked ✓"
		elseif level >= step.level then
			row.name.TextColor3 = GOLD
			row.pay.TextColor3 = GOLD
		else
			row.name.TextColor3 = DIM
			row.pay.TextColor3 = DIM
		end
	end
	local owedCount = tonumber(data.owedCount) or 0
	if owedCount > 0 then
		claimBtn.BackgroundColor3 = GOLD
		claimBtn.TextColor3 = Color3.fromRGB(20, 16, 24)
		local shardBit = if (tonumber(data.owedShards) or 0) > 0 then string.format("  +%d ◆", data.owedShards) else ""
		claimBtn.Text = string.format("CLAIM %d STEPS — +%d gold%s", owedCount, data.owedGold, shardBit)
	else
		claimBtn.BackgroundColor3 = Color3.fromRGB(60, 54, 70)
		claimBtn.TextColor3 = DIM
		claimBtn.Text = if claimed >= #Yatra.Milestones then "The road is walked. Well gone, pilgrim." else "The road waits uphill"
	end
end)

screenGui:GetPropertyChangedSignal("Enabled"):Connect(function()
	if screenGui.Enabled then
		Net.YatraRequest:FireServer({ action = "info" })
	end
end)

UserInputService.InputBegan:Connect(function(input, gameProcessed)
	if gameProcessed then
		return
	end
	if input.KeyCode == Enum.KeyCode.F then
		screenGui.Enabled = not screenGui.Enabled
		if screenGui.Enabled then
			Net.YatraRequest:FireServer({ action = "info" })
		end
	end
end)

print("[Dharma] YatraUI ready (F).")
