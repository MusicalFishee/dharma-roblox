--!strict
-- The Siddhi Shop panel. Press B to open/close; click Buy to purchase upgrades.
-- Entirely code-built (no UI assets).

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")

local Net = require(ReplicatedStorage.Shared.Net)

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local GOLD = Color3.fromRGB(255, 200, 40)
local PANEL_BG = Color3.fromRGB(22, 18, 26)
local ROW_BG = Color3.fromRGB(34, 28, 40)

local screenGui = Instance.new("ScreenGui")
screenGui.Name = "DharmaShop"
screenGui.ResetOnSpawn = false
screenGui.Parent = playerGui

local panel = Instance.new("Frame")
panel.Size = UDim2.fromOffset(380, 250)
panel.AnchorPoint = Vector2.new(0.5, 0.5)
panel.Position = UDim2.fromScale(0.5, 0.5)
panel.BackgroundColor3 = PANEL_BG
panel.BorderSizePixel = 0
panel.Visible = false
panel.Parent = screenGui

local corner = Instance.new("UICorner")
corner.CornerRadius = UDim.new(0, 10)
corner.Parent = panel

local title = Instance.new("TextLabel")
title.Size = UDim2.new(1, 0, 0, 40)
title.BackgroundTransparency = 1
title.Font = Enum.Font.GothamBlack
title.TextSize = 22
title.TextColor3 = GOLD
title.Text = "THE SIDDHI SHOP"
title.Parent = panel

local goldText = Instance.new("TextLabel")
goldText.Size = UDim2.new(1, 0, 0, 20)
goldText.Position = UDim2.fromOffset(0, 38)
goldText.BackgroundTransparency = 1
goldText.Font = Enum.Font.GothamMedium
goldText.TextSize = 15
goldText.TextColor3 = Color3.fromRGB(230, 230, 230)
goldText.Text = "◈ 0 gold"
goldText.Parent = panel

local hint = Instance.new("TextLabel")
hint.Size = UDim2.new(1, 0, 0, 18)
hint.Position = UDim2.new(0, 0, 1, -22)
hint.BackgroundTransparency = 1
hint.Font = Enum.Font.Gotham
hint.TextSize = 12
hint.TextColor3 = Color3.fromRGB(150, 150, 160)
hint.Text = "Press B to close"
hint.Parent = panel

-- One row per upgrade.
type Row = {
	frame: Frame,
	label: TextLabel,
	button: TextButton,
	id: string,
}
local rows: { [string]: Row } = {}

local function makeRow(id: string, order: number): Row
	local frame = Instance.new("Frame")
	frame.Size = UDim2.new(1, -24, 0, 64)
	frame.Position = UDim2.fromOffset(12, 62 + (order - 1) * 72)
	frame.BackgroundColor3 = ROW_BG
	frame.BorderSizePixel = 0
	frame.Parent = panel
	local rc = Instance.new("UICorner")
	rc.CornerRadius = UDim.new(0, 8)
	rc.Parent = frame

	local label = Instance.new("TextLabel")
	label.Size = UDim2.new(1, -110, 1, 0)
	label.Position = UDim2.fromOffset(10, 0)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.GothamMedium
	label.TextSize = 14
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.TextColor3 = Color3.fromRGB(235, 235, 235)
	label.Text = ""
	label.Parent = frame

	local button = Instance.new("TextButton")
	button.Size = UDim2.fromOffset(90, 40)
	button.AnchorPoint = Vector2.new(1, 0.5)
	button.Position = UDim2.new(1, -10, 0.5, 0)
	button.Font = Enum.Font.GothamBold
	button.TextSize = 14
	button.TextColor3 = Color3.fromRGB(20, 16, 24)
	button.BackgroundColor3 = GOLD
	button.Text = "Buy"
	button.Parent = frame
	local bc = Instance.new("UICorner")
	bc.CornerRadius = UDim.new(0, 8)
	bc.Parent = button

	button.Activated:Connect(function()
		Net.ShopRequest:FireServer({ action = "buy", id = id })
	end)

	return { frame = frame, label = label, button = button, id = id }
end

rows.damage = makeRow("damage", 1)
rows.health = makeRow("health", 2)

local function updatePanel(data: any)
	goldText.Text = string.format("◈ %d gold", data.gold)
	for id, row in rows do
		local item = data.items and data.items[id]
		if not item then
			continue
		end
		row.label.Text = string.format("%s   (Tier %d/%d)\n%s", item.name, item.tier, item.maxTier, item.desc)
		if item.tier >= item.maxTier then
			row.button.Text = "MAX"
			row.button.BackgroundColor3 = Color3.fromRGB(110, 110, 110)
			row.button.Active = false
		else
			row.button.Text = string.format("%d ◈", item.price)
			row.button.BackgroundColor3 = GOLD
			row.button.Active = true
		end
	end
end

-- Toggle with B.
UserInputService.InputBegan:Connect(function(input: InputObject, gameProcessed: boolean)
	if gameProcessed then
		return
	end
	if input.KeyCode == Enum.KeyCode.B then
		panel.Visible = not panel.Visible
		if panel.Visible then
			Net.ShopRequest:FireServer({ action = "info" })
		end
	end
end)

Net.CombatFeedback.OnClientEvent:Connect(function(data: any)
	if typeof(data) ~= "table" then
		return
	end
	if data.shop then
		updatePanel(data)
	end
end)

print("[Dharma] Shop UI ready — press B.")
