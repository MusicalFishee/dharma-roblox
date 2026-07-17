--!strict
-- The one-time weapon choice, shown at the start of the game. Reads the shared Weapons
-- catalog to build a card per weapon; clicking one sends the pick to the server. Closes
-- as soon as the server confirms a weapon is equipped. Entirely code-built (no assets).

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local Net = require(ReplicatedStorage.Shared.Net)
local Weapons = require(ReplicatedStorage.Shared.Weapons)

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local GOLD = Color3.fromRGB(255, 200, 40)
local PANEL_BG = Color3.fromRGB(18, 15, 22)
local CARD_BG = Color3.fromRGB(30, 25, 38)
local CARD_HOVER = Color3.fromRGB(44, 37, 55)

local screenGui = Instance.new("ScreenGui")
screenGui.Name = "DharmaWeaponSelect"
screenGui.ResetOnSpawn = false
screenGui.IgnoreGuiInset = true
screenGui.DisplayOrder = 20
screenGui.Enabled = false
screenGui.Parent = playerGui

local dim = Instance.new("Frame")
dim.Size = UDim2.fromScale(1, 1)
dim.BackgroundColor3 = Color3.fromRGB(6, 4, 8)
dim.BackgroundTransparency = 0.35
dim.BorderSizePixel = 0
dim.Parent = screenGui

local panel = Instance.new("Frame")
panel.AnchorPoint = Vector2.new(0.5, 0.5)
panel.Position = UDim2.fromScale(0.5, 0.5)
panel.Size = UDim2.fromOffset(820, 380)
panel.BackgroundColor3 = PANEL_BG
panel.BorderSizePixel = 0
panel.Parent = screenGui
local pc = Instance.new("UICorner")
pc.CornerRadius = UDim.new(0, 14)
pc.Parent = panel

local title = Instance.new("TextLabel")
title.Size = UDim2.new(1, 0, 0, 44)
title.Position = UDim2.fromOffset(0, 16)
title.BackgroundTransparency = 1
title.Font = Enum.Font.GothamBlack
title.TextSize = 30
title.TextColor3 = GOLD
title.Text = "CHOOSE YOUR WEAPON"
title.Parent = panel

local subtitle = Instance.new("TextLabel")
subtitle.Size = UDim2.new(1, -40, 0, 22)
subtitle.Position = UDim2.fromOffset(20, 58)
subtitle.BackgroundTransparency = 1
subtitle.Font = Enum.Font.Gotham
subtitle.TextSize = 14
subtitle.TextColor3 = Color3.fromRGB(200, 195, 205)
subtitle.Text = "This choice is permanent. Every weapon is equally strong — pick your style, then upgrade it in the Shop."
subtitle.TextWrapped = true
subtitle.Parent = panel

local CARD_W = 180
local CARD_H = 250
local GAP = 16
local count = #Weapons.List
local totalW = count * CARD_W + (count - 1) * GAP
local startX = math.floor((820 - totalW) / 2)

local chosen = false

local function makeCard(weapon: any, index: number)
	local card = Instance.new("Frame")
	card.Size = UDim2.fromOffset(CARD_W, CARD_H)
	card.Position = UDim2.fromOffset(startX + (index - 1) * (CARD_W + GAP), 96)
	card.BackgroundColor3 = CARD_BG
	card.BorderSizePixel = 0
	card.Parent = panel
	local cc = Instance.new("UICorner")
	cc.CornerRadius = UDim.new(0, 10)
	cc.Parent = card

	local accent = Instance.new("Frame")
	accent.Size = UDim2.new(1, 0, 0, 4)
	accent.BackgroundColor3 = Color3.fromRGB(weapon.glowColor[1], weapon.glowColor[2], weapon.glowColor[3])
	accent.BorderSizePixel = 0
	accent.Parent = card
	local ac = Instance.new("UICorner")
	ac.CornerRadius = UDim.new(0, 10)
	ac.Parent = accent

	local name = Instance.new("TextLabel")
	name.Size = UDim2.new(1, -16, 0, 26)
	name.Position = UDim2.fromOffset(8, 16)
	name.BackgroundTransparency = 1
	name.Font = Enum.Font.GothamBold
	name.TextSize = 20
	name.TextColor3 = Color3.fromRGB(245, 245, 245)
	name.Text = weapon.displayName
	name.Parent = card

	local flavour = Instance.new("TextLabel")
	flavour.Size = UDim2.new(1, -16, 0, 18)
	flavour.Position = UDim2.fromOffset(8, 42)
	flavour.BackgroundTransparency = 1
	flavour.Font = Enum.Font.GothamMedium
	flavour.TextSize = 13
	flavour.TextColor3 = GOLD
	flavour.Text = weapon.title
	flavour.TextWrapped = true
	flavour.Parent = card

	local sigLine = Instance.new("TextLabel")
	sigLine.Size = UDim2.new(1, -20, 0, 30)
	sigLine.Position = UDim2.fromOffset(10, 166)
	sigLine.BackgroundTransparency = 1
	sigLine.Font = Enum.Font.GothamMedium
	sigLine.TextSize = 11
	sigLine.TextColor3 = Color3.fromRGB(150, 200, 255)
	sigLine.Text = Weapons.signatureOf(weapon.id).line
	sigLine.TextWrapped = true
	sigLine.TextYAlignment = Enum.TextYAlignment.Top
	sigLine.Parent = card

	local desc = Instance.new("TextLabel")
	desc.Size = UDim2.new(1, -20, 0, 96)
	desc.Position = UDim2.fromOffset(10, 68)
	desc.BackgroundTransparency = 1
	desc.Font = Enum.Font.Gotham
	desc.TextSize = 13
	desc.TextColor3 = Color3.fromRGB(200, 198, 205)
	desc.Text = weapon.description
	desc.TextWrapped = true
	desc.TextYAlignment = Enum.TextYAlignment.Top
	desc.Parent = card

	local button = Instance.new("TextButton")
	button.Size = UDim2.new(1, -20, 0, 40)
	button.Position = UDim2.new(0, 10, 1, -50)
	button.Font = Enum.Font.GothamBold
	button.TextSize = 15
	button.TextColor3 = Color3.fromRGB(20, 16, 24)
	button.BackgroundColor3 = GOLD
	button.Text = "Wield"
	button.Parent = card
	local bc = Instance.new("UICorner")
	bc.CornerRadius = UDim.new(0, 8)
	bc.Parent = button

	button.MouseEnter:Connect(function()
		if not chosen then
			card.BackgroundColor3 = CARD_HOVER
		end
	end)
	button.MouseLeave:Connect(function()
		card.BackgroundColor3 = CARD_BG
	end)

	button.Activated:Connect(function()
		if chosen then
			return
		end
		chosen = true
		button.Text = "…"
		Net.WeaponRequest:FireServer({ action = "select", id = weapon.id })
	end)
end

for i, weapon in Weapons.List do
	makeCard(weapon, i)
end

Net.CombatFeedback.OnClientEvent:Connect(function(data: any)
	if typeof(data) ~= "table" then
		return
	end
	if data.weaponPrompt then
		chosen = false
		screenGui.Enabled = true
	elseif data.weaponChosen or data.weaponEquipped then
		screenGui.Enabled = false
	end
end)

print("[Dharma] WeaponSelect ready.")
