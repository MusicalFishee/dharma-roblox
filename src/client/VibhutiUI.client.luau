--!strict
-- Vibhuti panel (U key): the eight sacred marks — tilaks and auras, every one
-- earned by deed — plus the three emotes. Cosmetic only; the flex layer.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")

local Net = require(ReplicatedStorage.Shared.Net)
local Vibhuti = require(ReplicatedStorage.Shared.Vibhuti)

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local GOLD = Color3.fromRGB(255, 200, 40)
local PANEL_BG = Color3.fromRGB(18, 15, 22)
local ROW_BG = Color3.fromRGB(30, 25, 38)
local DIM = Color3.fromRGB(120, 115, 130)

local worn = { tilak = "", aura = "" }
local snap: Vibhuti.UnlockSnapshot = { kills = 0, bossKills = 0, bestWave = 0, trials = 0, duelWins = 0, raidClears = 0, revives = 0 }

local screenGui = Instance.new("ScreenGui")
screenGui.Name = "DharmaVibhuti"
screenGui.ResetOnSpawn = false
screenGui.DisplayOrder = 15
screenGui.Enabled = false
screenGui.Parent = playerGui

local panel = Instance.new("Frame")
panel.AnchorPoint = Vector2.new(0.5, 0.5)
panel.Position = UDim2.fromScale(0.5, 0.5)
panel.Size = UDim2.fromOffset(480, 604)
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
title.Text = "VIBHUTI — THE SACRED MARKS"
title.Parent = panel

local subtitle = Instance.new("TextLabel")
subtitle.Size = UDim2.new(1, -30, 0, 16)
subtitle.Position = UDim2.fromOffset(15, 44)
subtitle.BackgroundTransparency = 1
subtitle.Font = Enum.Font.Gotham
subtitle.TextSize = 12
subtitle.TextColor3 = DIM
subtitle.Text = "Worn deeds, never bought. Click to wear; click again to bare."
subtitle.Parent = panel

type Row = { button: TextButton }
local rows: { [string]: Row } = {}

for i, id in Vibhuti.Order do
	local def = Vibhuti.Defs[id]
	local row = Instance.new("Frame")
	row.Size = UDim2.new(1, -30, 0, 50)
	row.Position = UDim2.fromOffset(15, 66 + (i - 1) * 56)
	row.BackgroundColor3 = ROW_BG
	row.BorderSizePixel = 0
	row.Parent = panel
	local rc = Instance.new("UICorner")
	rc.CornerRadius = UDim.new(0, 8)
	rc.Parent = row

	local swatch = Instance.new("Frame")
	swatch.Size = UDim2.fromOffset(10, 34)
	swatch.Position = UDim2.fromOffset(8, 8)
	swatch.BackgroundColor3 = Color3.fromRGB(def.color[1], def.color[2], def.color[3])
	swatch.BorderSizePixel = 0
	swatch.Parent = row
	local sc = Instance.new("UICorner")
	sc.CornerRadius = UDim.new(0, 4)
	sc.Parent = swatch

	local name = Instance.new("TextLabel")
	name.Size = UDim2.new(1, -170, 0, 22)
	name.Position = UDim2.fromOffset(26, 4)
	name.BackgroundTransparency = 1
	name.Font = Enum.Font.GothamBold
	name.TextSize = 14
	name.TextColor3 = Color3.fromRGB(245, 245, 245)
	name.TextXAlignment = Enum.TextXAlignment.Left
	name.Text = string.format("%s  ·  %s", def.name, if def.slot == "tilak" then "brow" else "air")
	name.Parent = row

	local line = Instance.new("TextLabel")
	line.Size = UDim2.new(1, -170, 0, 18)
	line.Position = UDim2.fromOffset(26, 26)
	line.BackgroundTransparency = 1
	line.Font = Enum.Font.Gotham
	line.TextSize = 11
	line.TextColor3 = DIM
	line.TextXAlignment = Enum.TextXAlignment.Left
	line.Text = def.line
	line.Parent = row

	local button = Instance.new("TextButton")
	button.Size = UDim2.fromOffset(126, 32)
	button.Position = UDim2.new(1, -138, 0.5, -16)
	button.Font = Enum.Font.GothamBold
	button.TextSize = 11
	button.TextWrapped = true
	button.Parent = row
	local bc = Instance.new("UICorner")
	bc.CornerRadius = UDim.new(0, 8)
	bc.Parent = button

	button.Activated:Connect(function()
		if (worn :: any)[def.slot] == id then
			Net.VibhutiRequest:FireServer({ action = "equip", slot = def.slot, id = "" })
		elseif Vibhuti.isUnlocked(id, snap) then
			Net.VibhutiRequest:FireServer({ action = "equip", slot = def.slot, id = id })
		end
	end)
	rows[id] = { button = button }
end

-- The emotes.
local emoteHeader = Instance.new("TextLabel")
emoteHeader.Size = UDim2.new(1, -30, 0, 20)
emoteHeader.Position = UDim2.fromOffset(15, 518)
emoteHeader.BackgroundTransparency = 1
emoteHeader.Font = Enum.Font.GothamBold
emoteHeader.TextSize = 14
emoteHeader.TextColor3 = GOLD
emoteHeader.TextXAlignment = Enum.TextXAlignment.Left
emoteHeader.Text = "EMOTES"
emoteHeader.Parent = panel

local emoteLabels = { emote_namaste = "Namaste", emote_warcry = "War Cry", emote_meditate = "Meditate" }
for i, id in Vibhuti.Emotes do
	local b = Instance.new("TextButton")
	b.Size = UDim2.fromOffset(140, 36)
	b.Position = UDim2.fromOffset(15 + (i - 1) * 150, 544)
	b.BackgroundColor3 = ROW_BG
	b.Font = Enum.Font.GothamBold
	b.TextSize = 13
	b.TextColor3 = Color3.fromRGB(230, 226, 235)
	b.Text = emoteLabels[id] or id
	b.Parent = panel
	local bc = Instance.new("UICorner")
	bc.CornerRadius = UDim.new(0, 8)
	bc.Parent = b
	b.Activated:Connect(function()
		Net.VibhutiRequest:FireServer({ action = "emote", id = id })
	end)
end

local function refresh()
	for id, row in rows do
		local def = Vibhuti.Defs[id]
		if (worn :: any)[def.slot] == id then
			row.button.Text = "WORN — click to bare"
			row.button.BackgroundColor3 = Color3.fromRGB(80, 70, 95)
			row.button.TextColor3 = Color3.fromRGB(230, 225, 240)
		elseif Vibhuti.isUnlocked(id, snap) then
			row.button.Text = "Wear"
			row.button.BackgroundColor3 = GOLD
			row.button.TextColor3 = Color3.fromRGB(20, 16, 24)
		else
			row.button.Text = def.unlock.label
			row.button.BackgroundColor3 = Color3.fromRGB(60, 54, 70)
			row.button.TextColor3 = DIM
		end
	end
end

Net.CombatFeedback.OnClientEvent:Connect(function(data: any)
	if typeof(data) ~= "table" then
		return
	end
	if data.vibhutiInfo then
		worn = { tilak = tostring(data.tilak or ""), aura = tostring(data.aura or "") }
		refresh()
		return
	end
	if data.statsPage then
		snap = {
			kills = tonumber(data.kills) or 0,
			bossKills = tonumber(data.bossKills) or 0,
			bestWave = tonumber(data.bestWave) or 0,
			trials = tonumber(data.trialsPassed) or 0,
			duelWins = tonumber(data.duelWins) or 0,
			raidClears = tonumber(data.raidClears) or 0,
			revives = tonumber(data.revives) or 0,
		}
		refresh()
		return
	end
end)

UserInputService.InputBegan:Connect(function(input, gameProcessed)
	if gameProcessed then
		return
	end
	if input.KeyCode == Enum.KeyCode.U then
		screenGui.Enabled = not screenGui.Enabled
		if screenGui.Enabled then
			Net.VibhutiRequest:FireServer({ action = "info" })
			Net.StatsRequest:FireServer({ action = "info" })
		end
	end
end)

print("[Dharma] VibhutiUI ready (U).")
