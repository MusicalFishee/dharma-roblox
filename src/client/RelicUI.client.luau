--!strict
-- The relic satchel (I key): three worn slots on the left, everything owned in a
-- scroll on the right. Click an owned relic to wear it; click a worn slot to bare
-- it. Set bonuses light up along the bottom. Entirely code-built from shared Relics.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")

local Net = require(ReplicatedStorage.Shared.Net)
local Relics = require(ReplicatedStorage.Shared.Relics)

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local GOLD = Color3.fromRGB(255, 200, 40)
local PANEL_BG = Color3.fromRGB(18, 15, 22)
local ROW_BG = Color3.fromRGB(30, 25, 38)
local ROW_HOVER = Color3.fromRGB(44, 37, 55)
local MUTED = Color3.fromRGB(200, 195, 205)
local DIM = Color3.fromRGB(120, 115, 130)

local owned: { string } = {}
local equipped = { crown = "", kavacha = "", charm = "" }

local function rarityColor(id: string): Color3
	local def = Relics.get(id)
	local rgb = if def then Relics.RarityColor[def.rarity] else nil
	return if rgb then Color3.fromRGB(rgb[1], rgb[2], rgb[3]) else MUTED
end

local screenGui = Instance.new("ScreenGui")
screenGui.Name = "DharmaRelics"
screenGui.ResetOnSpawn = false
screenGui.DisplayOrder = 15
screenGui.Enabled = false
screenGui.Parent = playerGui

local panel = Instance.new("Frame")
panel.AnchorPoint = Vector2.new(0.5, 0.5)
panel.Position = UDim2.fromScale(0.5, 0.5)
panel.Size = UDim2.fromOffset(620, 430)
panel.BackgroundColor3 = PANEL_BG
panel.BorderSizePixel = 0
panel.Parent = screenGui
local pc = Instance.new("UICorner")
pc.CornerRadius = UDim.new(0, 14)
pc.Parent = panel

local title = Instance.new("TextLabel")
title.Size = UDim2.new(1, 0, 0, 40)
title.Position = UDim2.fromOffset(0, 12)
title.BackgroundTransparency = 1
title.Font = Enum.Font.GothamBlack
title.TextSize = 24
title.TextColor3 = GOLD
title.Text = "RELIC SATCHEL"
title.Parent = panel

local hint = Instance.new("TextLabel")
hint.Size = UDim2.new(1, -30, 0, 16)
hint.Position = UDim2.fromOffset(15, 48)
hint.BackgroundTransparency = 1
hint.Font = Enum.Font.Gotham
hint.TextSize = 12
hint.TextColor3 = DIM
hint.Text = "Bosses drop set pieces for everyone — elites drop charms for their slayer. Wear one of each."
hint.TextWrapped = true
hint.Parent = panel

-- Left: the three worn slots.
local slotRows: { [string]: TextButton } = {}
local SLOT_LABEL = { crown = "CROWN", kavacha = "KAVACHA", charm = "CHARM" }
for i, slot in Relics.Slots do
	local row = Instance.new("TextButton")
	row.Size = UDim2.fromOffset(240, 74)
	row.Position = UDim2.fromOffset(15, 76 + (i - 1) * 82)
	row.BackgroundColor3 = ROW_BG
	row.Font = Enum.Font.Gotham
	row.TextSize = 13
	row.TextColor3 = MUTED
	row.TextWrapped = true
	row.Text = ""
	row.Parent = panel
	local rc = Instance.new("UICorner")
	rc.CornerRadius = UDim.new(0, 10)
	rc.Parent = row
	slotRows[slot] = row

	row.MouseEnter:Connect(function()
		row.BackgroundColor3 = ROW_HOVER
	end)
	row.MouseLeave:Connect(function()
		row.BackgroundColor3 = ROW_BG
	end)
	row.Activated:Connect(function()
		if (equipped :: any)[slot] ~= "" then
			Net.RelicRequest:FireServer({ action = "equip", slot = slot, id = "" })
		end
	end)
end

-- Bottom: active set bonuses.
local setLine = Instance.new("TextLabel")
setLine.Size = UDim2.new(0, 240, 0, 84)
setLine.Position = UDim2.fromOffset(15, 330)
setLine.BackgroundTransparency = 1
setLine.Font = Enum.Font.GothamMedium
setLine.TextSize = 12
setLine.TextColor3 = GOLD
setLine.TextWrapped = true
setLine.TextXAlignment = Enum.TextXAlignment.Left
setLine.TextYAlignment = Enum.TextYAlignment.Top
setLine.Text = ""
setLine.Parent = panel

-- Right: everything owned.
local scroll = Instance.new("ScrollingFrame")
scroll.Size = UDim2.fromOffset(330, 338)
scroll.Position = UDim2.fromOffset(272, 76)
scroll.BackgroundColor3 = Color3.fromRGB(14, 11, 17)
scroll.BorderSizePixel = 0
scroll.ScrollBarThickness = 6
scroll.CanvasSize = UDim2.fromOffset(0, 0)
scroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
scroll.Parent = panel
local sc = Instance.new("UICorner")
sc.CornerRadius = UDim.new(0, 10)
sc.Parent = scroll
local layout = Instance.new("UIListLayout")
layout.Padding = UDim.new(0, 6)
layout.SortOrder = Enum.SortOrder.LayoutOrder
layout.Parent = scroll
local pad = Instance.new("UIPadding")
pad.PaddingTop = UDim.new(0, 6)
pad.PaddingLeft = UDim.new(0, 6)
pad.PaddingRight = UDim.new(0, 6)
pad.Parent = scroll

local function refresh()
	-- Worn slots.
	for slot, row in slotRows do
		local id = (equipped :: any)[slot] :: string
		local def = if id ~= "" then Relics.get(id) else nil
		if def then
			row.TextColor3 = rarityColor(id)
			row.Text = string.format("%s\n%s\n(click to remove)", SLOT_LABEL[slot], def.name)
		else
			row.TextColor3 = DIM
			row.Text = string.format("%s\n— bare —", SLOT_LABEL[slot])
		end
	end

	-- Active set bonuses.
	local counts: { [string]: number } = {}
	for _, id in Relics.equippedList(equipped) do
		local def = Relics.get(id)
		if def and def.setId then
			counts[def.setId] = (counts[def.setId] or 0) + 1
		end
	end
	local lines: { string } = {}
	for setId, count in counts do
		local set = Relics.Sets[setId]
		if set and count >= 2 then
			table.insert(lines, string.format("SET:  %s  (%d pc)", set.name, count))
		end
	end
	setLine.Text = if #lines > 0 then table.concat(lines, "\n") else "No set bonus active — wear 2+ pieces of one set."

	-- Owned list.
	for _, child in scroll:GetChildren() do
		if child:IsA("TextButton") then
			child:Destroy()
		end
	end
	for order, id in owned do
		local def = Relics.get(id)
		if not def then
			continue
		end
		local isWorn = (equipped :: any)[def.slot] == id
		local row = Instance.new("TextButton")
		row.Size = UDim2.new(1, -6, 0, 58)
		row.LayoutOrder = order
		row.BackgroundColor3 = if isWorn then Color3.fromRGB(40, 34, 24) else ROW_BG
		row.Font = Enum.Font.Gotham
		row.TextSize = 12
		row.TextColor3 = rarityColor(id)
		row.TextWrapped = true
		row.TextXAlignment = Enum.TextXAlignment.Left
		local setName = if def.setId and Relics.Sets[def.setId] then "  ·  " .. Relics.Sets[def.setId].name else ""
		row.Text = string.format("  %s  [%s]%s\n  %s", def.name, SLOT_LABEL[def.slot], setName, if isWorn then "WORN" else def.line)
		row.Parent = scroll
		local rc2 = Instance.new("UICorner")
		rc2.CornerRadius = UDim.new(0, 8)
		rc2.Parent = row

		row.MouseEnter:Connect(function()
			row.BackgroundColor3 = ROW_HOVER
		end)
		row.MouseLeave:Connect(function()
			row.BackgroundColor3 = if isWorn then Color3.fromRGB(40, 34, 24) else ROW_BG
		end)
		row.Activated:Connect(function()
			if not isWorn then
				Net.RelicRequest:FireServer({ action = "equip", slot = def.slot, id = id })
			end
		end)
	end
end

Net.CombatFeedback.OnClientEvent:Connect(function(data: any)
	if typeof(data) ~= "table" or not data.relicInfo then
		return
	end
	owned = {}
	if typeof(data.owned) == "table" then
		for _, id in data.owned do
			table.insert(owned, tostring(id))
		end
	end
	if typeof(data.equipped) == "table" then
		equipped = {
			crown = tostring(data.equipped.crown or ""),
			kavacha = tostring(data.equipped.kavacha or ""),
			charm = tostring(data.equipped.charm or ""),
		}
	end
	refresh()
end)

UserInputService.InputBegan:Connect(function(input, gameProcessed)
	if gameProcessed then
		return
	end
	if input.KeyCode == Enum.KeyCode.I then
		screenGui.Enabled = not screenGui.Enabled
		if screenGui.Enabled then
			Net.RelicRequest:FireServer({ action = "info" })
		end
	end
end)

print("[Dharma] RelicUI ready (I).")
