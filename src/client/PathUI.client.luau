--!strict
-- The Astra Path picker: four deva cards built from the shared Paths + Abilities
-- catalogs. Auto-opens once for the unsworn (after the weapon oath); K toggles it
-- any time after — sworn players see respec pricing. Entirely code-built.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")

local Net = require(ReplicatedStorage.Shared.Net)
local Paths = require(ReplicatedStorage.Shared.Paths)
local Abilities = require(ReplicatedStorage.Shared.Abilities)

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local GOLD = Color3.fromRGB(255, 200, 40)
local PANEL_BG = Color3.fromRGB(18, 15, 22)
local CARD_BG = Color3.fromRGB(30, 25, 38)
local CARD_HOVER = Color3.fromRGB(44, 37, 55)
local MUTED = Color3.fromRGB(200, 195, 205)

local currentPath = ""
local gold = 0
local respecCost = Paths.RespecCost

local screenGui = Instance.new("ScreenGui")
screenGui.Name = "DharmaPathSelect"
screenGui.ResetOnSpawn = false
screenGui.IgnoreGuiInset = true
screenGui.DisplayOrder = 19 -- under the weapon picker, above the HUD
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
panel.Size = UDim2.fromOffset(860, 470)
panel.BackgroundColor3 = PANEL_BG
panel.BorderSizePixel = 0
panel.Parent = screenGui
local pc = Instance.new("UICorner")
pc.CornerRadius = UDim.new(0, 14)
pc.Parent = panel

local title = Instance.new("TextLabel")
title.Size = UDim2.new(1, 0, 0, 44)
title.Position = UDim2.fromOffset(0, 14)
title.BackgroundTransparency = 1
title.Font = Enum.Font.GothamBlack
title.TextSize = 30
title.TextColor3 = GOLD
title.Text = "SWEAR YOUR ASTRA PATH"
title.Parent = panel

local subtitle = Instance.new("TextLabel")
subtitle.Size = UDim2.new(1, -40, 0, 22)
subtitle.Position = UDim2.fromOffset(20, 56)
subtitle.BackgroundTransparency = 1
subtitle.Font = Enum.Font.Gotham
subtitle.TextSize = 14
subtitle.TextColor3 = MUTED
subtitle.Text = "Your first oath is free and remakes your Z/X/C/V kit. Walking a different path later costs gold. Press K to return here."
subtitle.TextWrapped = true
subtitle.Parent = panel

local closeButton = Instance.new("TextButton")
closeButton.Size = UDim2.fromOffset(34, 34)
closeButton.Position = UDim2.new(1, -44, 0, 12)
closeButton.BackgroundColor3 = CARD_BG
closeButton.Font = Enum.Font.GothamBold
closeButton.TextSize = 16
closeButton.TextColor3 = MUTED
closeButton.Text = "✕"
closeButton.Parent = panel
local xc = Instance.new("UICorner")
xc.CornerRadius = UDim.new(0, 8)
xc.Parent = closeButton
closeButton.Activated:Connect(function()
	screenGui.Enabled = false
end)

local CARD_W = 196
local CARD_H = 344
local GAP = 14
local count = #Paths.Order
local totalW = count * CARD_W + (count - 1) * GAP
local startX = math.floor((860 - totalW) / 2)

local buttons: { [string]: TextButton } = {}

local function refreshButtons()
	for id, button in buttons do
		if id == currentPath then
			button.Text = "Your Path"
			button.BackgroundColor3 = Color3.fromRGB(80, 70, 95)
			button.TextColor3 = Color3.fromRGB(230, 225, 240)
			button.AutoButtonColor = false
		elseif currentPath == "" then
			button.Text = "Swear the Oath"
			button.BackgroundColor3 = GOLD
			button.TextColor3 = Color3.fromRGB(20, 16, 24)
			button.AutoButtonColor = true
		else
			button.Text = string.format("Walk this Path — %d gold", respecCost)
			button.BackgroundColor3 = if gold >= respecCost then GOLD else Color3.fromRGB(90, 80, 60)
			button.TextColor3 = Color3.fromRGB(20, 16, 24)
			button.AutoButtonColor = true
		end
	end
end

local function makeCard(def: Paths.PathDef, index: number)
	local accent3 = Color3.fromRGB(def.color[1], def.color[2], def.color[3])

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
	accent.BackgroundColor3 = accent3
	accent.BorderSizePixel = 0
	accent.Parent = card
	local ac = Instance.new("UICorner")
	ac.CornerRadius = UDim.new(0, 10)
	ac.Parent = accent

	local name = Instance.new("TextLabel")
	name.Size = UDim2.new(1, -16, 0, 24)
	name.Position = UDim2.fromOffset(8, 14)
	name.BackgroundTransparency = 1
	name.Font = Enum.Font.GothamBold
	name.TextSize = 18
	name.TextColor3 = Color3.fromRGB(245, 245, 245)
	name.Text = def.name
	name.Parent = card

	local epithet = Instance.new("TextLabel")
	epithet.Size = UDim2.new(1, -16, 0, 16)
	epithet.Position = UDim2.fromOffset(8, 38)
	epithet.BackgroundTransparency = 1
	epithet.Font = Enum.Font.GothamMedium
	epithet.TextSize = 13
	epithet.TextColor3 = accent3
	epithet.Text = def.epithet
	epithet.Parent = card

	local desc = Instance.new("TextLabel")
	desc.Size = UDim2.new(1, -20, 0, 46)
	desc.Position = UDim2.fromOffset(10, 60)
	desc.BackgroundTransparency = 1
	desc.Font = Enum.Font.Gotham
	desc.TextSize = 12
	desc.TextColor3 = MUTED
	desc.Text = def.description
	desc.TextWrapped = true
	desc.TextYAlignment = Enum.TextYAlignment.Top
	desc.Parent = card

	local passive = Instance.new("TextLabel")
	passive.Size = UDim2.new(1, -20, 0, 30)
	passive.Position = UDim2.fromOffset(10, 106)
	passive.BackgroundTransparency = 1
	passive.Font = Enum.Font.GothamBold
	passive.TextSize = 12
	passive.TextColor3 = GOLD
	passive.Text = "PASSIVE: " .. def.passiveLine
	passive.TextWrapped = true
	passive.TextYAlignment = Enum.TextYAlignment.Top
	passive.Parent = card

	-- The kit, slot by slot.
	local slots = { "Z", "X", "C", "V" }
	for i, slot in slots do
		local abilityId = (def.kit :: any)[slot] :: string
		local ability = Abilities.Catalog[abilityId]
		local row = Instance.new("TextLabel")
		row.Size = UDim2.new(1, -20, 0, 34)
		row.Position = UDim2.fromOffset(10, 138 + (i - 1) * 36)
		row.BackgroundTransparency = 1
		row.Font = Enum.Font.Gotham
		row.TextSize = 11
		row.TextColor3 = MUTED
		row.RichText = true
		row.Text = string.format(
			"<font color=\"#FFC828\"><b>%s</b></font>  <b>%s</b>\n%s",
			slot,
			if ability then ability.name else abilityId,
			if ability then ability.line else ""
		)
		row.TextWrapped = true
		row.TextXAlignment = Enum.TextXAlignment.Left
		row.TextYAlignment = Enum.TextYAlignment.Top
		row.Parent = card
	end

	local button = Instance.new("TextButton")
	button.Size = UDim2.new(1, -20, 0, 36)
	button.Position = UDim2.new(0, 10, 1, -46)
	button.Font = Enum.Font.GothamBold
	button.TextSize = 13
	button.Text = "Swear the Oath"
	button.BackgroundColor3 = GOLD
	button.TextColor3 = Color3.fromRGB(20, 16, 24)
	button.Parent = card
	local bc = Instance.new("UICorner")
	bc.CornerRadius = UDim.new(0, 8)
	bc.Parent = button
	buttons[def.id] = button

	button.MouseEnter:Connect(function()
		card.BackgroundColor3 = CARD_HOVER
	end)
	button.MouseLeave:Connect(function()
		card.BackgroundColor3 = CARD_BG
	end)

	button.Activated:Connect(function()
		if def.id ~= currentPath then
			Net.PathRequest:FireServer({ action = "choose", id = def.id })
		end
	end)
end

for i, id in Paths.Order do
	makeCard(Paths.Defs[id], i)
end

Net.CombatFeedback.OnClientEvent:Connect(function(data: any)
	if typeof(data) ~= "table" then
		return
	end
	if data.pathPrompt then
		Net.PathRequest:FireServer({ action = "info" })
		screenGui.Enabled = true
		return
	end
	if data.pathInfo then
		currentPath = tostring(data.path)
		gold = tonumber(data.gold) or 0
		respecCost = tonumber(data.respecCost) or respecCost
		refreshButtons()
		return
	end
	if data.pathChosen then
		currentPath = tostring(data.path)
		refreshButtons()
		task.wait(0.6)
		screenGui.Enabled = false
		return
	end
	if data.goldUpdate then
		gold = tonumber(data.gold) or gold
		refreshButtons()
		return
	end
end)

UserInputService.InputBegan:Connect(function(input, gameProcessed)
	if gameProcessed then
		return
	end
	if input.KeyCode == Enum.KeyCode.K then
		screenGui.Enabled = not screenGui.Enabled
		if screenGui.Enabled then
			Net.PathRequest:FireServer({ action = "info" })
		end
	end
end)

print("[Dharma] PathUI ready (K).")
