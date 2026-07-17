--!strict
-- Honor duels panel. Press G: pick a warrior, send the challenge. When challenged,
-- the panel opens itself with ACCEPT / DECLINE. Everything else (countdowns, results)
-- lands as HUD toasts.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")

local Net = require(ReplicatedStorage.Shared.Net)
local InputBadge = require(ReplicatedStorage.Shared.InputBadge)

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local RED = Color3.fromRGB(255, 110, 140)
local PANEL_BG = Color3.fromRGB(22, 15, 20)
local ROW_BG = Color3.fromRGB(36, 26, 32)
local GREY = Color3.fromRGB(110, 110, 110)

local screenGui = Instance.new("ScreenGui")
screenGui.Name = "DharmaPvP"
screenGui.ResetOnSpawn = false
screenGui.Parent = playerGui

local panel = Instance.new("Frame")
panel.Size = UDim2.fromOffset(360, 340)
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
title.TextColor3 = RED
title.Text = "HONOR DUELS"
title.Parent = panel

local scroll = Instance.new("ScrollingFrame")
scroll.Size = UDim2.new(1, -20, 1, -140)
scroll.Position = UDim2.fromOffset(10, 42)
scroll.BackgroundTransparency = 1
scroll.BorderSizePixel = 0
scroll.ScrollBarThickness = 4
scroll.CanvasSize = UDim2.fromOffset(0, 0)
scroll.Parent = panel

-- Incoming-challenge strip (hidden until someone calls you out).
local incoming = Instance.new("Frame")
incoming.Size = UDim2.new(1, -20, 0, 64)
incoming.Position = UDim2.new(0, 10, 1, -96)
incoming.BackgroundColor3 = ROW_BG
incoming.BorderSizePixel = 0
incoming.Visible = false
incoming.Parent = panel
local ic = Instance.new("UICorner")
ic.CornerRadius = UDim.new(0, 8)
ic.Parent = incoming

local incomingText = Instance.new("TextLabel")
incomingText.Size = UDim2.new(1, -16, 0, 22)
incomingText.Position = UDim2.fromOffset(8, 4)
incomingText.BackgroundTransparency = 1
incomingText.Font = Enum.Font.GothamBold
incomingText.TextSize = 14
incomingText.TextColor3 = RED
incomingText.Text = ""
incomingText.Parent = incoming

local incomingFrom = 0

local acceptBtn = Instance.new("TextButton")
acceptBtn.Size = UDim2.fromOffset(120, 28)
acceptBtn.Position = UDim2.fromOffset(8, 30)
acceptBtn.Font = Enum.Font.GothamBold
acceptBtn.TextSize = 13
acceptBtn.TextColor3 = Color3.fromRGB(20, 16, 24)
acceptBtn.BackgroundColor3 = Color3.fromRGB(90, 230, 120)
acceptBtn.Text = "ACCEPT"
acceptBtn.Parent = incoming
local ac = Instance.new("UICorner")
ac.CornerRadius = UDim.new(0, 6)
ac.Parent = acceptBtn

local declineBtn = Instance.new("TextButton")
declineBtn.Size = UDim2.fromOffset(120, 28)
declineBtn.Position = UDim2.fromOffset(136, 30)
declineBtn.Font = Enum.Font.GothamBold
declineBtn.TextSize = 13
declineBtn.TextColor3 = Color3.fromRGB(235, 235, 235)
declineBtn.BackgroundColor3 = Color3.fromRGB(90, 60, 70)
declineBtn.Text = "DECLINE"
declineBtn.Parent = incoming
local dc = Instance.new("UICorner")
dc.CornerRadius = UDim.new(0, 6)
dc.Parent = declineBtn

local hint = Instance.new("TextLabel")
hint.Size = UDim2.new(1, 0, 0, 18)
hint.Position = UDim2.new(0, 0, 1, -24)
hint.BackgroundTransparency = 1
hint.Font = Enum.Font.Gotham
hint.TextSize = 12
hint.TextColor3 = Color3.fromRGB(150, 150, 160)
hint.Text = "Press G to close — duels are consent-only"
hint.Parent = panel

acceptBtn.Activated:Connect(function()
	if incomingFrom ~= 0 then
		Net.PvPRequest:FireServer({ action = "accept", userId = incomingFrom })
		incoming.Visible = false
		incomingFrom = 0
		panel.Visible = false
	end
end)
declineBtn.Activated:Connect(function()
	if incomingFrom ~= 0 then
		Net.PvPRequest:FireServer({ action = "decline", userId = incomingFrom })
		incoming.Visible = false
		incomingFrom = 0
	end
end)

local function rebuildRoster(data: any)
	for _, child in scroll:GetChildren() do
		child:Destroy()
	end
	local list = data.players or {}
	scroll.CanvasSize = UDim2.fromOffset(0, #list * 46)
	if #list == 0 then
		local empty = Instance.new("TextLabel")
		empty.Size = UDim2.new(1, -8, 0, 40)
		empty.BackgroundTransparency = 1
		empty.Font = Enum.Font.Gotham
		empty.TextSize = 13
		empty.TextColor3 = Color3.fromRGB(160, 156, 166)
		empty.Text = "No other warriors in this world yet."
		empty.Parent = scroll
		return
	end
	for i, p in list do
		local row = Instance.new("Frame")
		row.Size = UDim2.new(1, -8, 0, 40)
		row.Position = UDim2.fromOffset(0, (i - 1) * 46)
		row.BackgroundColor3 = ROW_BG
		row.BorderSizePixel = 0
		row.Parent = scroll
		local rc = Instance.new("UICorner")
		rc.CornerRadius = UDim.new(0, 8)
		rc.Parent = row

		local name = Instance.new("TextLabel")
		name.Size = UDim2.new(1, -120, 1, 0)
		name.Position = UDim2.fromOffset(10, 0)
		name.BackgroundTransparency = 1
		name.Font = Enum.Font.GothamBold
		name.TextSize = 14
		name.TextXAlignment = Enum.TextXAlignment.Left
		name.TextColor3 = Color3.fromRGB(235, 235, 235)
		local glyph = InputBadge.glyphFor(tostring(p.input or ""))
		name.Text = if #glyph > 0 then string.format("%s  %s", glyph, tostring(p.name)) else tostring(p.name)
		name.Parent = row

		local btn = Instance.new("TextButton")
		btn.Size = UDim2.fromOffset(96, 28)
		btn.AnchorPoint = Vector2.new(1, 0.5)
		btn.Position = UDim2.new(1, -8, 0.5, 0)
		btn.Font = Enum.Font.GothamBold
		btn.TextSize = 12
		btn.TextColor3 = Color3.fromRGB(20, 16, 24)
		btn.BackgroundColor3 = if p.busy or data.busy then GREY else RED
		btn.Text = if p.busy then "Busy" else "Challenge"
		btn.Active = not (p.busy or data.busy)
		btn.Parent = row
		local bc = Instance.new("UICorner")
		bc.CornerRadius = UDim.new(0, 6)
		bc.Parent = btn

		btn.Activated:Connect(function()
			if btn.Active then
				Net.PvPRequest:FireServer({ action = "challenge", userId = p.userId })
			end
		end)
	end
end

UserInputService.InputBegan:Connect(function(input: InputObject, gameProcessed: boolean)
	if gameProcessed then
		return
	end
	if input.KeyCode == Enum.KeyCode.G then
		panel.Visible = not panel.Visible
		if panel.Visible then
			Net.PvPRequest:FireServer({ action = "list" })
		end
	end
end)

Net.CombatFeedback.OnClientEvent:Connect(function(data: any)
	if typeof(data) ~= "table" then
		return
	end
	if data.pvp == "roster" then
		rebuildRoster(data)
	elseif data.pvp == "challenged" then
		incomingFrom = tonumber(data.fromUserId) or 0
		incomingText.Text = string.format("%s challenges you to a duel!", tostring(data.fromName))
		incoming.Visible = true
		panel.Visible = true
	elseif data.pvp == "sent" or data.pvp == "declined" or data.pvp == "expired" then
		-- Roster state changed under us; refresh if we're looking at it.
		if panel.Visible then
			Net.PvPRequest:FireServer({ action = "list" })
		end
	end
end)

print("[Dharma] Duel panel ready — press G.")
