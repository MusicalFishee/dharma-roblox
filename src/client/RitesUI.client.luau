--!strict
-- The Rites (Y key). Top half: the Yajna fire — feed it gold, bless the whole
-- party until the line breaks. Bottom half: the Shapatha oaths — swear the next
-- wave crueler for a multiplied bounty (between waves only, one per wave).

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")

local Net = require(ReplicatedStorage.Shared.Net)
local Yajna = require(ReplicatedStorage.Shared.Yajna)
local Shapatha = require(ReplicatedStorage.Shared.Shapatha)

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local GOLD = Color3.fromRGB(255, 200, 40)
local SAFFRON = Color3.fromRGB(255, 160, 40)
local RED = Color3.fromRGB(235, 80, 70)
local PANEL_BG = Color3.fromRGB(18, 15, 22)
local ROW_BG = Color3.fromRGB(30, 25, 38)
local DIM = Color3.fromRGB(120, 115, 130)

local screenGui = Instance.new("ScreenGui")
screenGui.Name = "DharmaRites"
screenGui.ResetOnSpawn = false
screenGui.DisplayOrder = 15
screenGui.Enabled = false
screenGui.Parent = playerGui

local panel = Instance.new("Frame")
panel.AnchorPoint = Vector2.new(0.5, 0.5)
panel.Position = UDim2.fromScale(0.5, 0.5)
panel.Size = UDim2.fromOffset(500, 540)
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
title.Text = "THE RITES"
title.Parent = panel

local yajnaHeader = Instance.new("TextLabel")
yajnaHeader.Size = UDim2.new(1, -30, 0, 22)
yajnaHeader.Position = UDim2.fromOffset(15, 48)
yajnaHeader.BackgroundTransparency = 1
yajnaHeader.Font = Enum.Font.GothamBold
yajnaHeader.TextSize = 15
yajnaHeader.TextColor3 = SAFFRON
yajnaHeader.TextXAlignment = Enum.TextXAlignment.Left
yajnaHeader.Text = "YAJNA — feed the flame (party-wide, until the line breaks)"
yajnaHeader.Parent = panel

type OfferRow = { button: TextButton }
local offerRows: { [string]: OfferRow } = {}
local costs: { [string]: number } = {}
local litFlames: { [string]: boolean } = {}

for i, id in Yajna.Order do
	local def = Yajna.Catalog[id]
	local row = Instance.new("Frame")
	row.Size = UDim2.new(1, -30, 0, 54)
	row.Position = UDim2.fromOffset(15, 74 + (i - 1) * 60)
	row.BackgroundColor3 = ROW_BG
	row.BorderSizePixel = 0
	row.Parent = panel
	local rc = Instance.new("UICorner")
	rc.CornerRadius = UDim.new(0, 8)
	rc.Parent = row

	local name = Instance.new("TextLabel")
	name.Size = UDim2.new(1, -140, 0, 22)
	name.Position = UDim2.fromOffset(12, 5)
	name.BackgroundTransparency = 1
	name.Font = Enum.Font.GothamBold
	name.TextSize = 14
	name.TextColor3 = Color3.fromRGB(245, 245, 245)
	name.TextXAlignment = Enum.TextXAlignment.Left
	name.Text = def.name
	name.Parent = row

	local line = Instance.new("TextLabel")
	line.Size = UDim2.new(1, -140, 0, 18)
	line.Position = UDim2.fromOffset(12, 29)
	line.BackgroundTransparency = 1
	line.Font = Enum.Font.Gotham
	line.TextSize = 11
	line.TextColor3 = DIM
	line.TextXAlignment = Enum.TextXAlignment.Left
	line.Text = def.line
	line.Parent = row

	local button = Instance.new("TextButton")
	button.Size = UDim2.fromOffset(112, 34)
	button.Position = UDim2.new(1, -124, 0.5, -17)
	button.Font = Enum.Font.GothamBold
	button.TextSize = 12
	button.Text = string.format("Offer %d ◈", def.baseCost)
	button.BackgroundColor3 = SAFFRON
	button.TextColor3 = Color3.fromRGB(20, 16, 24)
	button.Parent = row
	local bc = Instance.new("UICorner")
	bc.CornerRadius = UDim.new(0, 8)
	bc.Parent = button
	button.Activated:Connect(function()
		if not litFlames[id] then
			Net.RitesRequest:FireServer({ action = "offer", id = id })
		end
	end)
	offerRows[id] = { button = button }
end

local oathHeader = Instance.new("TextLabel")
oathHeader.Size = UDim2.new(1, -30, 0, 22)
oathHeader.Position = UDim2.fromOffset(15, 262)
oathHeader.BackgroundTransparency = 1
oathHeader.Font = Enum.Font.GothamBold
oathHeader.TextSize = 15
oathHeader.TextColor3 = RED
oathHeader.TextXAlignment = Enum.TextXAlignment.Left
oathHeader.Text = "SHAPATHA — swear the next wave crueler (between waves)"
oathHeader.Parent = panel

local oathButtons: { [string]: TextButton } = {}
local oathPendingName: string? = nil
local battleActive = false

for i, id in Shapatha.Order do
	local def = Shapatha.Catalog[id]
	local row = Instance.new("Frame")
	row.Size = UDim2.new(1, -30, 0, 62)
	row.Position = UDim2.fromOffset(15, 288 + (i - 1) * 68)
	row.BackgroundColor3 = ROW_BG
	row.BorderSizePixel = 0
	row.Parent = panel
	local rc = Instance.new("UICorner")
	rc.CornerRadius = UDim.new(0, 8)
	rc.Parent = row

	local name = Instance.new("TextLabel")
	name.Size = UDim2.new(1, -140, 0, 22)
	name.Position = UDim2.fromOffset(12, 5)
	name.BackgroundTransparency = 1
	name.Font = Enum.Font.GothamBold
	name.TextSize = 14
	name.TextColor3 = Color3.fromRGB(245, 245, 245)
	name.TextXAlignment = Enum.TextXAlignment.Left
	name.Text = def.name
	name.Parent = row

	local line = Instance.new("TextLabel")
	line.Size = UDim2.new(1, -140, 0, 32)
	line.Position = UDim2.fromOffset(12, 27)
	line.BackgroundTransparency = 1
	line.Font = Enum.Font.Gotham
	line.TextSize = 11
	line.TextColor3 = DIM
	line.TextXAlignment = Enum.TextXAlignment.Left
	line.TextWrapped = true
	line.Text = def.line
	line.Parent = row

	local button = Instance.new("TextButton")
	button.Size = UDim2.fromOffset(112, 34)
	button.Position = UDim2.new(1, -124, 0.5, -17)
	button.Font = Enum.Font.GothamBold
	button.TextSize = 12
	button.Text = "Swear"
	button.BackgroundColor3 = RED
	button.TextColor3 = Color3.fromRGB(24, 12, 12)
	button.Parent = row
	local bc = Instance.new("UICorner")
	bc.CornerRadius = UDim.new(0, 8)
	bc.Parent = button
	button.Activated:Connect(function()
		if not battleActive and not oathPendingName then
			Net.RitesRequest:FireServer({ action = "swear", id = id })
		end
	end)
	oathButtons[id] = button
end

local function refresh()
	for id, row in offerRows do
		if litFlames[id] then
			row.button.Text = "BURNING"
			row.button.BackgroundColor3 = Color3.fromRGB(80, 70, 95)
			row.button.TextColor3 = Color3.fromRGB(230, 225, 240)
		else
			row.button.Text = string.format("Offer %d ◈", costs[id] or Yajna.Catalog[id].baseCost)
			row.button.BackgroundColor3 = SAFFRON
			row.button.TextColor3 = Color3.fromRGB(20, 16, 24)
		end
	end
	for _, button in oathButtons do
		if oathPendingName then
			button.Text = "SWORN"
			button.BackgroundColor3 = Color3.fromRGB(80, 70, 95)
			button.TextColor3 = Color3.fromRGB(230, 225, 240)
		elseif battleActive then
			button.Text = "MID-WAVE"
			button.BackgroundColor3 = Color3.fromRGB(60, 54, 70)
			button.TextColor3 = DIM
		else
			button.Text = "Swear"
			button.BackgroundColor3 = RED
			button.TextColor3 = Color3.fromRGB(24, 12, 12)
		end
	end
end

Net.CombatFeedback.OnClientEvent:Connect(function(data: any)
	if typeof(data) ~= "table" then
		return
	end
	if data.ritesInfo then
		litFlames = {}
		if typeof(data.lit) == "table" then
			for id in data.lit do
				litFlames[tostring(id)] = true
			end
		end
		costs = {}
		if typeof(data.costs) == "table" then
			for id, cost in data.costs do
				costs[tostring(id)] = tonumber(cost) or 0
			end
		end
		oathPendingName = if data.oathPending then tostring(data.oathPending) else nil
		battleActive = data.battle == true
		refresh()
		return
	end
	-- Live events keep the panel honest without a re-request.
	if data.yajnaExtinguished then
		litFlames = {}
		refresh()
		return
	end
	if data.oathBegins or data.oathBounty then
		oathPendingName = nil
		refresh()
		return
	end
end)

UserInputService.InputBegan:Connect(function(input, gameProcessed)
	if gameProcessed then
		return
	end
	if input.KeyCode == Enum.KeyCode.Y then
		screenGui.Enabled = not screenGui.Enabled
		if screenGui.Enabled then
			Net.RitesRequest:FireServer({ action = "info" })
		end
	end
end)

print("[Dharma] RitesUI ready (Y).")
