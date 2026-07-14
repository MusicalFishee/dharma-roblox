--!strict
-- The quest tracker: a slim always-on panel (right edge) showing your 3 active
-- quests with progress bars. Updates live from server questUpdate events.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")

local Net = require(ReplicatedStorage.Shared.Net)

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local GOLD = Color3.fromRGB(255, 200, 40)
local PANEL_BG = Color3.fromRGB(20, 17, 24)
local BAR_BG = Color3.fromRGB(38, 32, 44)
local BAR_FILL = Color3.fromRGB(120, 210, 255)
local DONE = Color3.fromRGB(90, 230, 120)

local screenGui = Instance.new("ScreenGui")
screenGui.Name = "DharmaQuests"
screenGui.ResetOnSpawn = false
screenGui.Parent = playerGui

local panel = Instance.new("Frame")
panel.Size = UDim2.fromOffset(230, 210)
panel.AnchorPoint = Vector2.new(1, 0.5)
panel.Position = UDim2.new(1, -12, 0.5, 0)
panel.BackgroundColor3 = PANEL_BG
panel.BackgroundTransparency = 0.25
panel.BorderSizePixel = 0
panel.Parent = screenGui

local corner = Instance.new("UICorner")
corner.CornerRadius = UDim.new(0, 8)
corner.Parent = panel

local header = Instance.new("TextLabel")
header.Size = UDim2.new(1, 0, 0, 30)
header.BackgroundTransparency = 1
header.Font = Enum.Font.GothamBlack
header.TextSize = 16
header.TextColor3 = GOLD
header.Text = "QUESTS"
header.Parent = panel

type Row = {
	title: TextLabel,
	progressText: TextLabel,
	barFill: Frame,
}

local rows: { Row } = {}
for i = 1, 3 do
	local y = 34 + (i - 1) * 58

	local title = Instance.new("TextLabel")
	title.Size = UDim2.new(1, -20, 0, 18)
	title.Position = UDim2.fromOffset(10, y)
	title.BackgroundTransparency = 1
	title.Font = Enum.Font.GothamBold
	title.TextSize = 13
	title.TextXAlignment = Enum.TextXAlignment.Left
	title.TextColor3 = Color3.fromRGB(235, 235, 235)
	title.Text = ""
	title.Parent = panel

	local progressText = Instance.new("TextLabel")
	progressText.Size = UDim2.new(1, -20, 0, 14)
	progressText.Position = UDim2.fromOffset(10, y + 17)
	progressText.BackgroundTransparency = 1
	progressText.Font = Enum.Font.Gotham
	progressText.TextSize = 12
	progressText.TextXAlignment = Enum.TextXAlignment.Left
	progressText.TextColor3 = Color3.fromRGB(180, 180, 190)
	progressText.Text = ""
	progressText.Parent = panel

	local barBg = Instance.new("Frame")
	barBg.Size = UDim2.new(1, -20, 0, 6)
	barBg.Position = UDim2.fromOffset(10, y + 35)
	barBg.BackgroundColor3 = BAR_BG
	barBg.BorderSizePixel = 0
	barBg.Parent = panel
	local bc = Instance.new("UICorner")
	bc.CornerRadius = UDim.new(0, 3)
	bc.Parent = barBg

	local barFill = Instance.new("Frame")
	barFill.Size = UDim2.new(0, 0, 1, 0)
	barFill.BackgroundColor3 = BAR_FILL
	barFill.BorderSizePixel = 0
	barFill.Parent = barBg
	local fc = Instance.new("UICorner")
	fc.CornerRadius = UDim.new(0, 3)
	fc.Parent = barFill

	rows[i] = { title = title, progressText = progressText, barFill = barFill }
end

Net.CombatFeedback.OnClientEvent:Connect(function(data: any)
	if typeof(data) ~= "table" or not data.questUpdate then
		return
	end

	for i = 1, 3 do
		local row = rows[i]
		local q = data.quests and data.quests[i]
		if q then
			row.title.Text = q.title
			local reward = if q.rewardGold > 0 then string.format("%d ◈", q.rewardGold) else string.format("%d XP", q.rewardXp)
			row.progressText.Text = string.format("%s   %d/%d   (%s)", q.desc, q.progress, q.goal, reward)
			local pct = math.clamp(q.progress / math.max(1, q.goal), 0, 1)
			TweenService:Create(row.barFill, TweenInfo.new(0.25), { Size = UDim2.new(pct, 0, 1, 0) }):Play()
			row.barFill.BackgroundColor3 = if pct >= 1 then DONE else BAR_FILL
		else
			row.title.Text = ""
			row.progressText.Text = ""
			row.barFill.Size = UDim2.new(0, 0, 1, 0)
		end
	end
end)

print("[Dharma] Quest tracker ready.")
