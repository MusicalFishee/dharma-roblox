--!strict
-- Ripu-Grantha panel (; key): Agastya's book of foes. Nine family pages,
-- kill counts inked live, field notes revealed per tier, bounties claimed
-- like the Kirti ledger. Entirely code-built.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")

local Net = require(ReplicatedStorage.Shared.Net)
local Grantha = require(ReplicatedStorage.Shared.Grantha)

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local GOLD = Color3.fromRGB(255, 200, 40)
local PANEL_BG = Color3.fromRGB(18, 15, 22)
local ROW_BG = Color3.fromRGB(30, 25, 38)
local DIM = Color3.fromRGB(120, 115, 130)
local INK = Color3.fromRGB(210, 200, 185)

local screenGui = Instance.new("ScreenGui")
screenGui.Name = "DharmaGrantha"
screenGui.ResetOnSpawn = false
screenGui.DisplayOrder = 15
screenGui.Enabled = false
screenGui.Parent = playerGui

local panel = Instance.new("Frame")
panel.AnchorPoint = Vector2.new(0.5, 0.5)
panel.Position = UDim2.fromScale(0.5, 0.5)
panel.Size = UDim2.fromOffset(500, 620)
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
title.Text = "RIPU-GRANTHA — THE BOOK OF FOES"
title.Parent = panel

local sub = Instance.new("TextLabel")
sub.Size = UDim2.new(1, -30, 0, 16)
sub.Position = UDim2.fromOffset(15, 44)
sub.BackgroundTransparency = 1
sub.Font = Enum.Font.Gotham
sub.TextSize = 12
sub.TextColor3 = DIM
sub.Text = "Agastya's field notes. Every kill inks a page; every tier pays."
sub.Parent = panel

local list = Instance.new("ScrollingFrame")
list.Position = UDim2.fromOffset(0, 66)
list.Size = UDim2.new(1, 0, 1, -80)
list.BackgroundTransparency = 1
list.BorderSizePixel = 0
list.ScrollBarThickness = 6
list.CanvasSize = UDim2.fromOffset(0, #Grantha.Families * 62 + 6)
list.Parent = panel

type Row = { count: TextLabel, dots: TextLabel, lore: TextLabel, claim: TextButton }
local rows: { [string]: Row } = {}

for i, def in Grantha.Families do
	local row = Instance.new("Frame")
	row.Size = UDim2.new(1, -36, 0, 56)
	row.Position = UDim2.fromOffset(15, (i - 1) * 62)
	row.BackgroundColor3 = ROW_BG
	row.BorderSizePixel = 0
	row.Parent = list
	local rc = Instance.new("UICorner")
	rc.CornerRadius = UDim.new(0, 8)
	rc.Parent = row

	local name = Instance.new("TextLabel")
	name.Size = UDim2.new(1, -220, 0, 20)
	name.Position = UDim2.fromOffset(12, 4)
	name.BackgroundTransparency = 1
	name.Font = Enum.Font.GothamBold
	name.TextSize = 14
	name.TextColor3 = Color3.fromRGB(245, 245, 245)
	name.TextXAlignment = Enum.TextXAlignment.Left
	name.Text = def.name
	name.Parent = row

	local count = Instance.new("TextLabel")
	count.Size = UDim2.fromOffset(90, 20)
	count.Position = UDim2.new(1, -206, 0, 4)
	count.BackgroundTransparency = 1
	count.Font = Enum.Font.GothamBold
	count.TextSize = 12
	count.TextColor3 = DIM
	count.TextXAlignment = Enum.TextXAlignment.Right
	count.Text = "0"
	count.Parent = row

	local dots = Instance.new("TextLabel")
	dots.Size = UDim2.fromOffset(64, 20)
	dots.Position = UDim2.new(1, -110, 0, 4)
	dots.BackgroundTransparency = 1
	dots.Font = Enum.Font.GothamBold
	dots.TextSize = 15
	dots.TextColor3 = GOLD
	dots.TextXAlignment = Enum.TextXAlignment.Right
	dots.Text = "○ ○ ○"
	dots.Parent = row

	local claim = Instance.new("TextButton")
	claim.Size = UDim2.fromOffset(92, 22)
	claim.Position = UDim2.new(1, -104, 0, 28)
	claim.Font = Enum.Font.GothamBold
	claim.TextSize = 10
	claim.Visible = false
	claim.BackgroundColor3 = GOLD
	claim.TextColor3 = Color3.fromRGB(20, 16, 24)
	claim.Text = ""
	claim.Parent = row
	local cc = Instance.new("UICorner")
	cc.CornerRadius = UDim.new(0, 6)
	cc.Parent = claim
	claim.Activated:Connect(function()
		Net.GranthaRequest:FireServer({ action = "claim", id = def.id })
	end)

	local lore = Instance.new("TextLabel")
	lore.Size = UDim2.new(1, -130, 0, 26)
	lore.Position = UDim2.fromOffset(12, 26)
	lore.BackgroundTransparency = 1
	lore.Font = Enum.Font.Gotham
	lore.TextSize = 11
	lore.TextColor3 = DIM
	lore.TextWrapped = true
	lore.TextXAlignment = Enum.TextXAlignment.Left
	lore.TextYAlignment = Enum.TextYAlignment.Top
	lore.Text = "The page is unturned."
	lore.Parent = row

	rows[def.id] = { count = count, dots = dots, lore = lore, claim = claim }
end

Net.CombatFeedback.OnClientEvent:Connect(function(data: any)
	if typeof(data) ~= "table" or not data.granthaInfo then
		return
	end
	local kills = if typeof(data.kills) == "table" then data.kills else {}
	local claims = if typeof(data.claims) == "table" then data.claims else {}
	for _, def in Grantha.Families do
		local row = rows[def.id]
		local n = tonumber(kills[def.id]) or 0
		local claimed = tonumber(claims[def.id]) or 0
		local tier = Grantha.tierFor(def, n)

		if tier >= #def.tiers then
			row.count.Text = string.format("%d ✦", n)
		else
			row.count.Text = string.format("%d / %d", n, def.tiers[tier + 1])
		end
		local marks = {}
		for t = 1, 3 do
			table.insert(marks, if tier >= t then "●" else "○")
		end
		row.dots.Text = table.concat(marks, " ")
		row.lore.Text = if tier > 0 then def.lore[tier] else "The page is unturned."
		row.lore.TextColor3 = if tier > 0 then INK else DIM

		local owed = Grantha.owedFor(def, n, claimed)
		if owed.gold > 0 then
			row.claim.Visible = true
			row.claim.Text = string.format("CLAIM %d ◈", owed.gold)
		else
			row.claim.Visible = false
		end
	end
end)

-- Any opener (key, touch drawer, gamepad drawer) lands here.
screenGui:GetPropertyChangedSignal("Enabled"):Connect(function()
	if screenGui.Enabled then
		Net.GranthaRequest:FireServer({ action = "info" })
	end
end)

UserInputService.InputBegan:Connect(function(input, gameProcessed)
	if gameProcessed then
		return
	end
	if input.KeyCode == Enum.KeyCode.Semicolon then
		screenGui.Enabled = not screenGui.Enabled
		if screenGui.Enabled then
			Net.GranthaRequest:FireServer({ action = "info" })
		end
	end
end)

print("[Dharma] GranthaUI ready (;).")
