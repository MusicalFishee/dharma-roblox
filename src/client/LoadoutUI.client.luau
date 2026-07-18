--!strict
-- Loadout panel (L key): three saved gear sets — weapon + relics, captured
-- from what's worn, applied in one press. The sworn path stays sworn.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")

local Net = require(ReplicatedStorage.Shared.Net)
local Loadouts = require(ReplicatedStorage.Shared.Loadouts)
local Weapons = require(ReplicatedStorage.Shared.Weapons)

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local GOLD = Color3.fromRGB(255, 200, 40)
local PANEL_BG = Color3.fromRGB(18, 15, 22)
local ROW_BG = Color3.fromRGB(30, 25, 38)
local DIM = Color3.fromRGB(120, 115, 130)

local screenGui = Instance.new("ScreenGui")
screenGui.Name = "DharmaLoadouts"
screenGui.ResetOnSpawn = false
screenGui.DisplayOrder = 15
screenGui.Enabled = false
screenGui.Parent = playerGui

local panel = Instance.new("Frame")
panel.AnchorPoint = Vector2.new(0.5, 0.5)
panel.Position = UDim2.fromScale(0.5, 0.5)
panel.Size = UDim2.fromOffset(470, 428)
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
title.Text = "LOADOUTS — GEAR IN ONE PRESS"
title.Parent = panel

local wearing = Instance.new("TextLabel")
wearing.Size = UDim2.new(1, -30, 0, 16)
wearing.Position = UDim2.fromOffset(15, 46)
wearing.BackgroundTransparency = 1
wearing.Font = Enum.Font.Gotham
wearing.TextSize = 12
wearing.TextColor3 = DIM
wearing.TextXAlignment = Enum.TextXAlignment.Left
wearing.Text = "Weapon + relics. Your sworn path stays sworn."
wearing.Parent = panel

type Row = { nameBox: TextBox, contents: TextLabel, apply: TextButton, clear: TextButton }
local rows: { Row } = {}
local slots: { [string]: any } = {}

local function relicTally(slot: any): number
	local n = 0
	for _, k in { "crown", "kavacha", "charm" } do
		local id = slot[k]
		if typeof(id) == "string" and #id > 0 then
			n += 1
		end
	end
	return n
end

for i = 1, Loadouts.MaxSlots do
	local row = Instance.new("Frame")
	row.Size = UDim2.new(1, -30, 0, 104)
	row.Position = UDim2.fromOffset(15, 70 + (i - 1) * 112)
	row.BackgroundColor3 = ROW_BG
	row.BorderSizePixel = 0
	row.Parent = panel
	local rc = Instance.new("UICorner")
	rc.CornerRadius = UDim.new(0, 8)
	rc.Parent = row

	local nameBox = Instance.new("TextBox")
	nameBox.Size = UDim2.fromOffset(200, 28)
	nameBox.Position = UDim2.fromOffset(12, 10)
	nameBox.BackgroundColor3 = Color3.fromRGB(22, 18, 28)
	nameBox.Font = Enum.Font.GothamBold
	nameBox.TextSize = 14
	nameBox.TextColor3 = Color3.fromRGB(245, 245, 245)
	nameBox.PlaceholderText = "Loadout " .. i
	nameBox.PlaceholderColor3 = DIM
	nameBox.ClearTextOnFocus = false
	nameBox.Text = ""
	nameBox.Parent = row
	local nc = Instance.new("UICorner")
	nc.CornerRadius = UDim.new(0, 6)
	nc.Parent = nameBox

	local contents = Instance.new("TextLabel")
	contents.Size = UDim2.new(1, -24, 0, 18)
	contents.Position = UDim2.fromOffset(12, 44)
	contents.BackgroundTransparency = 1
	contents.Font = Enum.Font.Gotham
	contents.TextSize = 12
	contents.TextColor3 = DIM
	contents.TextXAlignment = Enum.TextXAlignment.Left
	contents.Text = "— empty —"
	contents.Parent = row

	local function button(text: string, x: number, width: number, bg: Color3, fg: Color3): TextButton
		local b = Instance.new("TextButton")
		b.Size = UDim2.fromOffset(width, 28)
		b.Position = UDim2.fromOffset(x, 66)
		b.BackgroundColor3 = bg
		b.Font = Enum.Font.GothamBold
		b.TextSize = 12
		b.TextColor3 = fg
		b.Text = text
		b.Parent = row
		local bc = Instance.new("UICorner")
		bc.CornerRadius = UDim.new(0, 6)
		bc.Parent = b
		return b
	end

	local apply = button("APPLY", 12, 120, GOLD, Color3.fromRGB(20, 16, 24))
	local save = button("SAVE CURRENT", 142, 120, Color3.fromRGB(80, 70, 95), Color3.fromRGB(230, 225, 240))
	local clear = button("X", 272, 34, Color3.fromRGB(60, 30, 34), Color3.fromRGB(220, 150, 150))

	apply.Activated:Connect(function()
		Net.LoadoutRequest:FireServer({ action = "apply", slot = i })
	end)
	save.Activated:Connect(function()
		Net.LoadoutRequest:FireServer({ action = "save", slot = i, name = nameBox.Text })
	end)
	clear.Activated:Connect(function()
		Net.LoadoutRequest:FireServer({ action = "clear", slot = i })
	end)

	rows[i] = { nameBox = nameBox, contents = contents, apply = apply, clear = clear }
end

local function refresh()
	for i, row in rows do
		local slot = slots[tostring(i)]
		if typeof(slot) == "table" then
			local weapon = Weapons.get(tostring(slot.weapon))
			local weaponName = if weapon then weapon.displayName else "?"
			row.contents.Text = string.format("%s  ·  %d relics", weaponName, relicTally(slot))
			row.nameBox.Text = tostring(slot.name)
			row.apply.Visible = true
			row.clear.Visible = true
		else
			row.contents.Text = "— empty —"
			row.apply.Visible = false
			row.clear.Visible = false
		end
	end
end

Net.CombatFeedback.OnClientEvent:Connect(function(data: any)
	if typeof(data) ~= "table" or not data.loadoutInfo then
		return
	end
	slots = if typeof(data.slots) == "table" then data.slots else {}
	local weapon = Weapons.get(tostring(data.weapon))
	local worn = 0
	for _, k in { "crown", "kavacha", "charm" } do
		if typeof(data[k]) == "string" and #data[k] > 0 then
			worn += 1
		end
	end
	wearing.Text = string.format(
		"Wearing now: %s  ·  %d relics.  SAVE captures it; your sworn path stays sworn.",
		if weapon then weapon.displayName else "no weapon yet",
		worn
	)
	refresh()
end)

-- Any opener (key, touch drawer, gamepad drawer) lands here.
screenGui:GetPropertyChangedSignal("Enabled"):Connect(function()
	if screenGui.Enabled then
		Net.LoadoutRequest:FireServer({ action = "info" })
	end
end)

UserInputService.InputBegan:Connect(function(input, gameProcessed)
	if gameProcessed then
		return
	end
	if input.KeyCode == Enum.KeyCode.L then
		screenGui.Enabled = not screenGui.Enabled
		if screenGui.Enabled then
			Net.LoadoutRequest:FireServer({ action = "info" })
		end
	end
end)

print("[Dharma] LoadoutUI ready (L).")
