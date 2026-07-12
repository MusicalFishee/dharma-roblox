--!strict
-- Code-built combat HUD: Tejas bar, Flow combo counter, outcome toasts.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")

local Net = require(ReplicatedStorage.Shared.Net)
local Combat = require(ReplicatedStorage.Shared.Combat)

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local SAFFRON = Color3.fromRGB(255, 160, 40)
local GREEN = Color3.fromRGB(90, 230, 120)
local MAGENTA = Color3.fromRGB(240, 90, 220)
local CYAN = Color3.fromRGB(120, 200, 255)
local RED = Color3.fromRGB(235, 80, 70)
local YELLOW = Color3.fromRGB(255, 215, 70)

local screenGui = Instance.new("ScreenGui")
screenGui.Name = "DharmaHUD"
screenGui.ResetOnSpawn = false
screenGui.IgnoreGuiInset = true
screenGui.Parent = playerGui

-- Tejas bar (bottom-left).
local tejasBg = Instance.new("Frame")
tejasBg.Size = UDim2.fromOffset(320, 26)
tejasBg.Position = UDim2.new(0, 28, 1, -54)
tejasBg.BackgroundColor3 = Color3.fromRGB(20, 18, 24)
tejasBg.BorderSizePixel = 0
tejasBg.Parent = screenGui

local tejasFill = Instance.new("Frame")
tejasFill.Size = UDim2.new(0, 0, 1, 0)
tejasFill.BackgroundColor3 = SAFFRON
tejasFill.BorderSizePixel = 0
tejasFill.Parent = tejasBg

local tejasLabel = Instance.new("TextLabel")
tejasLabel.Size = UDim2.fromScale(1, 1)
tejasLabel.BackgroundTransparency = 1
tejasLabel.Font = Enum.Font.GothamMedium
tejasLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
tejasLabel.TextSize = 16
tejasLabel.Text = "Tejas 0 / " .. Combat.Config.TejasMax
tejasLabel.Parent = tejasBg

-- Combo counter (top-centre).
local comboLabel = Instance.new("TextLabel")
comboLabel.Size = UDim2.fromOffset(400, 70)
comboLabel.AnchorPoint = Vector2.new(0.5, 0)
comboLabel.Position = UDim2.new(0.5, 0, 0, 40)
comboLabel.BackgroundTransparency = 1
comboLabel.Font = Enum.Font.GothamBlack
comboLabel.TextSize = 46
comboLabel.TextStrokeTransparency = 0.5
comboLabel.Text = ""
comboLabel.Parent = screenGui

-- Outcome toast (centre).
local toast = Instance.new("TextLabel")
toast.Size = UDim2.fromOffset(500, 60)
toast.AnchorPoint = Vector2.new(0.5, 0.5)
toast.Position = UDim2.new(0.5, 0, 0.4, 0)
toast.BackgroundTransparency = 1
toast.Font = Enum.Font.GothamBold
toast.TextSize = 34
toast.TextStrokeTransparency = 0.6
toast.TextTransparency = 1
toast.Text = ""
toast.Parent = screenGui

local function showToast(text: string, color: Color3)
	toast.Text = text
	toast.TextColor3 = color
	toast.TextTransparency = 0
	TweenService:Create(toast, TweenInfo.new(0.9, Enum.EasingStyle.Quad), { TextTransparency = 1 }):Play()
end

local function updateCombo(combo: number)
	if combo >= 2 then
		comboLabel.Text = string.format("FLOW  x%d", combo)
		comboLabel.TextColor3 = combo >= 5 and MAGENTA or GREEN
	else
		comboLabel.Text = ""
	end
end

local function updateTejas(tejas: number)
	local pct = math.clamp(tejas / Combat.Config.TejasMax, 0, 1)
	TweenService:Create(tejasFill, TweenInfo.new(0.2), { Size = UDim2.new(pct, 0, 1, 0) }):Play()
	tejasLabel.Text = string.format("Tejas %d / %d", math.floor(tejas + 0.5), Combat.Config.TejasMax)
end

Net.CombatFeedback.OnClientEvent:Connect(function(data: any)
	if typeof(data) ~= "table" then
		return
	end

	if data.tejas ~= nil then
		updateTejas(data.tejas)
	end

	if data.incoming then
		-- Damage we received (or defended).
		if data.outcome == "Parry" then
			showToast("PARRY!", YELLOW)
		elseif data.outcome == "Block" then
			showToast("Blocked", CYAN)
		elseif data.outcome == "Dodge" then
			showToast("Dodged!", CYAN)
		elseif data.outcome == "Hit" then
			showToast("Hit!", RED)
		end
	else
		-- Our own offense.
		if data.combo ~= nil then
			updateCombo(data.combo)
		end
		if data.outcome == "Hit" and data.combo and data.combo >= 5 then
			showToast(string.format("FLOW x%d!", data.combo), MAGENTA)
		end
	end
end)

print("[Dharma] HUD ready.")
