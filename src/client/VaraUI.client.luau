--!strict
-- The Vara draft: three boon cards after a boss falls. Pick one; it stands
-- until the party wipes. The panel waits patiently — the war doesn't.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local Net = require(ReplicatedStorage.Shared.Net)

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local GOLD = Color3.fromRGB(255, 200, 40)
local PANEL_BG = Color3.fromRGB(18, 15, 22)
local CARD_BG = Color3.fromRGB(30, 25, 38)
local CARD_HOVER = Color3.fromRGB(44, 37, 55)

local screenGui = Instance.new("ScreenGui")
screenGui.Name = "DharmaVara"
screenGui.ResetOnSpawn = false
screenGui.DisplayOrder = 18
screenGui.Enabled = false
screenGui.Parent = playerGui

local panel = Instance.new("Frame")
panel.AnchorPoint = Vector2.new(0.5, 1)
panel.Position = UDim2.new(0.5, 0, 1, -180)
panel.Size = UDim2.fromOffset(560, 150)
panel.BackgroundColor3 = PANEL_BG
panel.BackgroundTransparency = 0.1
panel.BorderSizePixel = 0
panel.Parent = screenGui
local pc = Instance.new("UICorner")
pc.CornerRadius = UDim.new(0, 12)
pc.Parent = panel

local title = Instance.new("TextLabel")
title.Size = UDim2.new(1, 0, 0, 26)
title.Position = UDim2.fromOffset(0, 8)
title.BackgroundTransparency = 1
title.Font = Enum.Font.GothamBlack
title.TextSize = 17
title.TextColor3 = GOLD
title.Text = "VARA — CHOOSE YOUR BOON"
title.Parent = panel

local cards: { TextButton } = {}
for i = 1, 3 do
	local card = Instance.new("TextButton")
	card.Size = UDim2.fromOffset(172, 96)
	card.Position = UDim2.fromOffset(12 + (i - 1) * 182, 42)
	card.BackgroundColor3 = CARD_BG
	card.Font = Enum.Font.Gotham
	card.TextSize = 12
	card.TextColor3 = Color3.fromRGB(230, 226, 235)
	card.TextWrapped = true
	card.RichText = true
	card.Text = ""
	card.Visible = false
	card.Parent = panel
	local cc = Instance.new("UICorner")
	cc.CornerRadius = UDim.new(0, 10)
	cc.Parent = card
	card.MouseEnter:Connect(function()
		card.BackgroundColor3 = CARD_HOVER
	end)
	card.MouseLeave:Connect(function()
		card.BackgroundColor3 = CARD_BG
	end)
	cards[i] = card
end

local currentOffer: { { id: string, name: string, line: string } } = {}

for i, card in cards do
	card.Activated:Connect(function()
		local option = currentOffer[i]
		if option then
			Net.VaraRequest:FireServer({ action = "pick", id = option.id })
		end
	end)
end

Net.CombatFeedback.OnClientEvent:Connect(function(data: any)
	if typeof(data) ~= "table" then
		return
	end
	if data.varaOffer and typeof(data.options) == "table" then
		currentOffer = {}
		for i, card in cards do
			local option = data.options[i]
			if option then
				currentOffer[i] = { id = tostring(option.id), name = tostring(option.name), line = tostring(option.line) }
				card.Text = string.format('<b><font color="#FFC828">%s</font></b>\n%s', tostring(option.name), tostring(option.line))
				card.Visible = true
			else
				card.Visible = false
			end
		end
		screenGui.Enabled = true
		return
	end
	if data.varaPicked or data.varaScattered then
		screenGui.Enabled = false
		currentOffer = {}
		return
	end
end)

print("[Dharma] VaraUI ready.")
