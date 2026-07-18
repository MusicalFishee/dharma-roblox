--!strict
-- The Adhyaya journal (J key): the story so far, chapter by chapter. Completed
-- chapters glow gold, the active one shows Agastya's requirement, and the road
-- ahead stays veiled. Entirely code-built from the shared Story module.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")

local Net = require(ReplicatedStorage.Shared.Net)
local Story = require(ReplicatedStorage.Shared.Story)

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local GOLD = Color3.fromRGB(255, 200, 40)
local PANEL_BG = Color3.fromRGB(18, 15, 22)
local ROW_BG = Color3.fromRGB(30, 25, 38)
local ACTIVE_BG = Color3.fromRGB(44, 37, 55)
local MUTED = Color3.fromRGB(200, 195, 205)
local DIM = Color3.fromRGB(110, 105, 122)

local chapter = 0 -- chapters completed, from the server

local screenGui = Instance.new("ScreenGui")
screenGui.Name = "DharmaStory"
screenGui.ResetOnSpawn = false
screenGui.DisplayOrder = 15
screenGui.Enabled = false
screenGui.Parent = playerGui

local panel = Instance.new("Frame")
panel.AnchorPoint = Vector2.new(0.5, 0.5)
panel.Position = UDim2.fromScale(0.5, 0.5)
panel.Size = UDim2.fromOffset(470, 500)
panel.BackgroundColor3 = PANEL_BG
panel.BorderSizePixel = 0
panel.Parent = screenGui
local pc = Instance.new("UICorner")
pc.CornerRadius = UDim.new(0, 14)
pc.Parent = panel

local title = Instance.new("TextLabel")
title.Size = UDim2.new(1, 0, 0, 38)
title.Position = UDim2.fromOffset(0, 12)
title.BackgroundTransparency = 1
title.Font = Enum.Font.Garamond
title.TextSize = 30
title.TextColor3 = GOLD
title.Text = "THE ADHYAYAS"
title.Parent = panel

local sub = Instance.new("TextLabel")
sub.Size = UDim2.new(1, -30, 0, 16)
sub.Position = UDim2.fromOffset(15, 48)
sub.BackgroundTransparency = 1
sub.Font = Enum.Font.Gotham
sub.TextSize = 12
sub.TextColor3 = DIM
sub.Text = "As told by Rishi Agastya, keeper of the ashram"
sub.Parent = panel

local list = Instance.new("ScrollingFrame")
list.Position = UDim2.fromOffset(0, 74)
list.Size = UDim2.new(1, 0, 1, -88)
list.BackgroundTransparency = 1
list.BorderSizePixel = 0
list.ScrollBarThickness = 6
list.CanvasSize = UDim2.fromOffset(0, #Story.Chapters * 60 + 6)
list.Parent = panel

type RowSet = { frame: Frame, numeral: TextLabel, name: TextLabel, detail: TextLabel }
local rowSets: { RowSet } = {}

for i, def in Story.Chapters do
	local row = Instance.new("Frame")
	row.Size = UDim2.new(1, -36, 0, 54)
	row.Position = UDim2.fromOffset(15, (i - 1) * 60)
	row.BackgroundColor3 = ROW_BG
	row.BorderSizePixel = 0
	row.Parent = list
	local rc = Instance.new("UICorner")
	rc.CornerRadius = UDim.new(0, 10)
	rc.Parent = row

	local numeral = Instance.new("TextLabel")
	numeral.Size = UDim2.fromOffset(52, 54)
	numeral.BackgroundTransparency = 1
	numeral.Font = Enum.Font.Garamond
	numeral.TextSize = 26
	numeral.TextColor3 = DIM
	numeral.Text = def.numeral
	numeral.Parent = row

	local name = Instance.new("TextLabel")
	name.Size = UDim2.new(1, -70, 0, 24)
	name.Position = UDim2.fromOffset(58, 6)
	name.BackgroundTransparency = 1
	name.Font = Enum.Font.GothamBold
	name.TextSize = 15
	name.TextXAlignment = Enum.TextXAlignment.Left
	name.TextColor3 = DIM
	name.Text = "?????"
	name.Parent = row

	local detail = Instance.new("TextLabel")
	detail.Size = UDim2.new(1, -70, 0, 18)
	detail.Position = UDim2.fromOffset(58, 30)
	detail.BackgroundTransparency = 1
	detail.Font = Enum.Font.Gotham
	detail.TextSize = 12
	detail.TextXAlignment = Enum.TextXAlignment.Left
	detail.TextColor3 = DIM
	detail.Text = ""
	detail.Parent = row

	rowSets[i] = { frame = row, numeral = numeral, name = name, detail = detail }
end

local function refresh()
	for i, def in Story.Chapters do
		local set = rowSets[i]
		if i <= chapter then
			-- Written into the legend.
			set.frame.BackgroundColor3 = ROW_BG
			set.numeral.TextColor3 = GOLD
			set.name.TextColor3 = GOLD
			set.name.Text = def.title .. "   ✓"
			set.detail.TextColor3 = MUTED
			set.detail.Text = def.closeLine
		elseif i == chapter + 1 then
			-- Your road now.
			set.frame.BackgroundColor3 = ACTIVE_BG
			set.numeral.TextColor3 = Color3.fromRGB(245, 245, 245)
			set.name.TextColor3 = Color3.fromRGB(245, 245, 245)
			set.name.Text = def.title
			set.detail.TextColor3 = GOLD
			set.detail.Text = "— " .. def.requirement .. " —"
		else
			-- The road ahead stays veiled.
			set.frame.BackgroundColor3 = ROW_BG
			set.numeral.TextColor3 = DIM
			set.name.TextColor3 = DIM
			set.name.Text = "?????"
			set.detail.Text = ""
		end
	end
end
refresh()

Net.CombatFeedback.OnClientEvent:Connect(function(data: any)
	if typeof(data) ~= "table" then
		return
	end
	if data.storyInfo or data.storyChapter or data.storyCatchup then
		local n = tonumber(data.chapter)
		if n then
			chapter = n
			refresh()
		end
	end
end)

UserInputService.InputBegan:Connect(function(input, gameProcessed)
	if gameProcessed then
		return
	end
	if input.KeyCode == Enum.KeyCode.J then
		screenGui.Enabled = not screenGui.Enabled
		if screenGui.Enabled then
			Net.StoryRequest:FireServer({ action = "info" })
		end
	end
end)

print("[Dharma] StoryUI ready (J).")
