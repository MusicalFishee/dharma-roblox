--!strict
-- The title cabinet. Press T to browse every title — earned ones equip on click,
-- locked ones show what deed they demand. One equipped at a time (or none).

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")

local Net = require(ReplicatedStorage.Shared.Net)
local Titles = require(ReplicatedStorage.Shared.Titles)

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local GOLD = Color3.fromRGB(255, 200, 40)
local PANEL_BG = Color3.fromRGB(19, 16, 24)
local ROW_BG = Color3.fromRGB(30, 25, 38)
local LOCKED = Color3.fromRGB(120, 116, 128)

local screenGui = Instance.new("ScreenGui")
screenGui.Name = "DharmaTitles"
screenGui.ResetOnSpawn = false
screenGui.Parent = playerGui

local panel = Instance.new("Frame")
panel.Size = UDim2.fromOffset(400, 430)
panel.AnchorPoint = Vector2.new(0.5, 0.5)
panel.Position = UDim2.fromScale(0.5, 0.5)
panel.BackgroundColor3 = PANEL_BG
panel.BorderSizePixel = 0
panel.Visible = false
panel.Parent = screenGui
local pc = Instance.new("UICorner")
pc.CornerRadius = UDim.new(0, 10)
pc.Parent = panel

local title = Instance.new("TextLabel")
title.Size = UDim2.new(1, 0, 0, 38)
title.BackgroundTransparency = 1
title.Font = Enum.Font.GothamBlack
title.TextSize = 20
title.TextColor3 = GOLD
title.Text = "TITLES — WEAR YOUR DEEDS"
title.Parent = panel

local scroll = Instance.new("ScrollingFrame")
scroll.Size = UDim2.new(1, -20, 1, -74)
scroll.Position = UDim2.fromOffset(10, 42)
scroll.BackgroundTransparency = 1
scroll.BorderSizePixel = 0
scroll.ScrollBarThickness = 4
scroll.CanvasSize = UDim2.fromOffset(0, #Titles.List * 60)
scroll.Parent = panel

local hint = Instance.new("TextLabel")
hint.Size = UDim2.new(1, 0, 0, 18)
hint.Position = UDim2.new(0, 0, 1, -24)
hint.BackgroundTransparency = 1
hint.Font = Enum.Font.Gotham
hint.TextSize = 12
hint.TextColor3 = Color3.fromRGB(150, 150, 160)
hint.Text = "Press T to close — click an earned title to wear it, again to bare your head"
hint.Parent = panel

type Row = {
	frame: Frame,
	name: TextLabel,
	req: TextLabel,
	button: TextButton,
	id: string,
}
local rows: { [string]: Row } = {}
local equippedId = ""

for i, def in Titles.List do
	local frame = Instance.new("Frame")
	frame.Size = UDim2.new(1, -8, 0, 52)
	frame.Position = UDim2.fromOffset(0, (i - 1) * 60)
	frame.BackgroundColor3 = ROW_BG
	frame.BorderSizePixel = 0
	frame.Parent = scroll
	local rc = Instance.new("UICorner")
	rc.CornerRadius = UDim.new(0, 8)
	rc.Parent = frame

	local name = Instance.new("TextLabel")
	name.Size = UDim2.new(1, -110, 0, 22)
	name.Position = UDim2.fromOffset(10, 5)
	name.BackgroundTransparency = 1
	name.Font = Enum.Font.GothamBold
	name.TextSize = 15
	name.TextXAlignment = Enum.TextXAlignment.Left
	name.TextColor3 = LOCKED
	name.Text = def.name
	name.Parent = frame

	local req = Instance.new("TextLabel")
	req.Size = UDim2.new(1, -110, 0, 18)
	req.Position = UDim2.fromOffset(10, 27)
	req.BackgroundTransparency = 1
	req.Font = Enum.Font.Gotham
	req.TextSize = 12
	req.TextXAlignment = Enum.TextXAlignment.Left
	req.TextColor3 = Color3.fromRGB(170, 166, 178)
	req.Text = def.requirement
	req.Parent = frame

	local button = Instance.new("TextButton")
	button.Size = UDim2.fromOffset(86, 34)
	button.AnchorPoint = Vector2.new(1, 0.5)
	button.Position = UDim2.new(1, -8, 0.5, 0)
	button.Font = Enum.Font.GothamBold
	button.TextSize = 13
	button.TextColor3 = Color3.fromRGB(20, 16, 24)
	button.BackgroundColor3 = LOCKED
	button.Text = "Locked"
	button.Active = false
	button.Parent = frame
	local bc = Instance.new("UICorner")
	bc.CornerRadius = UDim.new(0, 8)
	bc.Parent = button

	button.Activated:Connect(function()
		if not button.Active then
			return
		end
		-- Clicking the worn title takes it off; anything else puts it on.
		local want = if equippedId == def.id then "" else def.id
		Net.TitleRequest:FireServer({ action = "equip", id = want })
	end)

	rows[def.id] = { frame = frame, name = name, req = req, button = button, id = def.id }
end

local function updateRows(data: any)
	equippedId = tostring(data.equipped or "")
	for _, t in data.titles do
		local row = rows[tostring(t.id)]
		if not row then
			continue
		end
		if t.unlocked then
			row.name.TextColor3 = Color3.fromRGB(t.color[1], t.color[2], t.color[3])
			row.button.Active = true
			if t.equipped then
				row.button.Text = "Wearing"
				row.button.BackgroundColor3 = Color3.fromRGB(90, 230, 120)
			else
				row.button.Text = "Wear"
				row.button.BackgroundColor3 = GOLD
			end
			row.req.Text = t.requirement .. "  ✓"
		else
			row.name.TextColor3 = LOCKED
			row.button.Active = false
			row.button.Text = "Locked"
			row.button.BackgroundColor3 = LOCKED
			row.req.Text = t.requirement
		end
	end
end

UserInputService.InputBegan:Connect(function(input: InputObject, gameProcessed: boolean)
	if gameProcessed then
		return
	end
	if input.KeyCode == Enum.KeyCode.T then
		panel.Visible = not panel.Visible
		if panel.Visible then
			Net.TitleRequest:FireServer({ action = "list" })
		end
	end
end)

Net.CombatFeedback.OnClientEvent:Connect(function(data: any)
	if typeof(data) ~= "table" then
		return
	end
	if data.titleList then
		updateRows(data)
	end
end)

print("[Dharma] Title cabinet ready — press T.")
