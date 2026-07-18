--!strict
-- Gana panel (R key): declare a warband banner. Matching banners march as
-- one host; the chip rides above every head. No treasury, no officers.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")

local Net = require(ReplicatedStorage.Shared.Net)
local Gana = require(ReplicatedStorage.Shared.Gana)

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local GOLD = Color3.fromRGB(255, 200, 40)
local PANEL_BG = Color3.fromRGB(18, 15, 22)
local DIM = Color3.fromRGB(120, 115, 130)

local screenGui = Instance.new("ScreenGui")
screenGui.Name = "DharmaGana"
screenGui.ResetOnSpawn = false
screenGui.DisplayOrder = 15
screenGui.Enabled = false
screenGui.Parent = playerGui

local panel = Instance.new("Frame")
panel.AnchorPoint = Vector2.new(0.5, 0.5)
panel.Position = UDim2.fromScale(0.5, 0.5)
panel.Size = UDim2.fromOffset(380, 300)
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
title.Text = "GANA — THE WARBAND"
title.Parent = panel

local sub = Instance.new("TextLabel")
sub.Size = UDim2.new(1, -30, 0, 30)
sub.Position = UDim2.fromOffset(15, 44)
sub.BackgroundTransparency = 1
sub.Font = Enum.Font.Gotham
sub.TextSize = 12
sub.TextColor3 = DIM
sub.TextWrapped = true
sub.Text = "Declare a banner; match your friends' and march as one host. The bond is the banner."
sub.Parent = panel

local nameBox = Instance.new("TextBox")
nameBox.Size = UDim2.new(1, -30, 0, 34)
nameBox.Position = UDim2.fromOffset(15, 84)
nameBox.BackgroundColor3 = Color3.fromRGB(22, 18, 28)
nameBox.Font = Enum.Font.GothamBold
nameBox.TextSize = 15
nameBox.TextColor3 = Color3.fromRGB(245, 245, 245)
nameBox.PlaceholderText = "Banner name (e.g. Vira Sena)"
nameBox.PlaceholderColor3 = DIM
nameBox.ClearTextOnFocus = false
nameBox.Text = ""
nameBox.Parent = panel
local nc = Instance.new("UICorner")
nc.CornerRadius = UDim.new(0, 8)
nc.Parent = nameBox

local raiseBtn = Instance.new("TextButton")
raiseBtn.Size = UDim2.fromOffset(160, 34)
raiseBtn.Position = UDim2.fromOffset(15, 128)
raiseBtn.Font = Enum.Font.GothamBold
raiseBtn.TextSize = 13
raiseBtn.BackgroundColor3 = GOLD
raiseBtn.TextColor3 = Color3.fromRGB(20, 16, 24)
raiseBtn.Text = "RAISE THE BANNER"
raiseBtn.Parent = panel
local rbc = Instance.new("UICorner")
rbc.CornerRadius = UDim.new(0, 8)
rbc.Parent = raiseBtn

local lowerBtn = Instance.new("TextButton")
lowerBtn.Size = UDim2.fromOffset(150, 34)
lowerBtn.Position = UDim2.fromOffset(185, 128)
lowerBtn.Font = Enum.Font.GothamBold
lowerBtn.TextSize = 13
lowerBtn.BackgroundColor3 = Color3.fromRGB(60, 30, 34)
lowerBtn.TextColor3 = Color3.fromRGB(220, 150, 150)
lowerBtn.Text = "MARCH ALONE"
lowerBtn.Parent = panel
local lbc = Instance.new("UICorner")
lbc.CornerRadius = UDim.new(0, 8)
lbc.Parent = lowerBtn

local muster = Instance.new("TextLabel")
muster.Size = UDim2.new(1, -30, 0, 110)
muster.Position = UDim2.fromOffset(15, 174)
muster.BackgroundTransparency = 1
muster.Font = Enum.Font.Gotham
muster.TextSize = 13
muster.TextColor3 = DIM
muster.TextWrapped = true
muster.TextXAlignment = Enum.TextXAlignment.Left
muster.TextYAlignment = Enum.TextYAlignment.Top
muster.Text = ""
muster.Parent = panel

raiseBtn.Activated:Connect(function()
	if #Gana.cleanName(nameBox.Text) > 0 then
		Net.GanaRequest:FireServer({ action = "set", name = nameBox.Text })
	end
end)
lowerBtn.Activated:Connect(function()
	Net.GanaRequest:FireServer({ action = "set", name = "" })
end)

Net.CombatFeedback.OnClientEvent:Connect(function(data: any)
	if typeof(data) ~= "table" or not data.ganaInfo then
		return
	end
	local banner = tostring(data.banner or "")
	if #banner == 0 then
		muster.Text = "You march alone. Raise a banner and your kin will find you."
		return
	end
	nameBox.Text = banner
	local kin = if typeof(data.kin) == "table" then data.kin else {}
	if #kin == 0 then
		muster.Text = string.format("⚔ %s — none of your host stand here yet.", banner)
	else
		muster.Text = string.format("⚔ %s — marching with: %s", banner, table.concat(kin, ", "))
	end
end)

screenGui:GetPropertyChangedSignal("Enabled"):Connect(function()
	if screenGui.Enabled then
		Net.GanaRequest:FireServer({ action = "info" })
	end
end)

UserInputService.InputBegan:Connect(function(input, gameProcessed)
	if gameProcessed then
		return
	end
	if input.KeyCode == Enum.KeyCode.R then
		screenGui.Enabled = not screenGui.Enabled
		if screenGui.Enabled then
			Net.GanaRequest:FireServer({ action = "info" })
		end
	end
end)

print("[Dharma] GanaUI ready (R).")
