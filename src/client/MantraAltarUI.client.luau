--!strict
-- The Mantra Altar panel. Press N to open/close; one button gambles Vajra Shards on a
-- random mantra for your weapon. Shows the currently inscribed mantra in its rarity
-- colour. Entirely code-built (no UI assets).

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")

local Net = require(ReplicatedStorage.Shared.Net)
local Enchants = require(ReplicatedStorage.Shared.Enchants)

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local SHARD = Color3.fromRGB(150, 120, 255)
local PANEL_BG = Color3.fromRGB(20, 16, 28)
local ROW_BG = Color3.fromRGB(32, 26, 44)

local function rarityColor(rarity: string): Color3
	local c = Enchants.RarityColor[rarity]
	if c then
		return Color3.fromRGB(c[1], c[2], c[3])
	end
	return Color3.fromRGB(235, 235, 235)
end

local screenGui = Instance.new("ScreenGui")
screenGui.Name = "DharmaAltar"
screenGui.ResetOnSpawn = false
screenGui.Parent = playerGui

local panel = Instance.new("Frame")
panel.Size = UDim2.fromOffset(400, 260)
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
title.Size = UDim2.new(1, 0, 0, 40)
title.BackgroundTransparency = 1
title.Font = Enum.Font.GothamBlack
title.TextSize = 22
title.TextColor3 = SHARD
title.Text = "THE MANTRA ALTAR"
title.Parent = panel

local shardText = Instance.new("TextLabel")
shardText.Size = UDim2.new(1, 0, 0, 20)
shardText.Position = UDim2.fromOffset(0, 38)
shardText.BackgroundTransparency = 1
shardText.Font = Enum.Font.GothamMedium
shardText.TextSize = 15
shardText.TextColor3 = Color3.fromRGB(230, 230, 230)
shardText.Text = "◆ 0 Vajra Shards"
shardText.Parent = panel

-- Current mantra display.
local mantraBox = Instance.new("Frame")
mantraBox.Size = UDim2.new(1, -24, 0, 84)
mantraBox.Position = UDim2.fromOffset(12, 66)
mantraBox.BackgroundColor3 = ROW_BG
mantraBox.BorderSizePixel = 0
mantraBox.Parent = panel
local mc = Instance.new("UICorner")
mc.CornerRadius = UDim.new(0, 8)
mc.Parent = mantraBox

local mantraName = Instance.new("TextLabel")
mantraName.Size = UDim2.new(1, -20, 0, 26)
mantraName.Position = UDim2.fromOffset(10, 8)
mantraName.BackgroundTransparency = 1
mantraName.Font = Enum.Font.GothamBold
mantraName.TextSize = 17
mantraName.TextXAlignment = Enum.TextXAlignment.Left
mantraName.TextColor3 = Color3.fromRGB(160, 160, 170)
mantraName.Text = "No mantra inscribed"
mantraName.Parent = mantraBox

local mantraDesc = Instance.new("TextLabel")
mantraDesc.Size = UDim2.new(1, -20, 0, 44)
mantraDesc.Position = UDim2.fromOffset(10, 34)
mantraDesc.BackgroundTransparency = 1
mantraDesc.Font = Enum.Font.Gotham
mantraDesc.TextSize = 13
mantraDesc.TextWrapped = true
mantraDesc.TextXAlignment = Enum.TextXAlignment.Left
mantraDesc.TextYAlignment = Enum.TextYAlignment.Top
mantraDesc.TextColor3 = Color3.fromRGB(200, 198, 208)
mantraDesc.Text = "Slay bosses for Vajra Shards, then inscribe your weapon with a random mantra. Inscribing again replaces it."
mantraDesc.Parent = mantraBox

local inscribeBtn = Instance.new("TextButton")
inscribeBtn.Size = UDim2.new(1, -24, 0, 46)
inscribeBtn.Position = UDim2.new(0, 12, 0, 162)
inscribeBtn.Font = Enum.Font.GothamBold
inscribeBtn.TextSize = 17
inscribeBtn.TextColor3 = Color3.fromRGB(240, 238, 250)
inscribeBtn.BackgroundColor3 = SHARD
inscribeBtn.Text = string.format("INSCRIBE  —  %d ◆", Enchants.Cost)
inscribeBtn.Parent = panel
local bc = Instance.new("UICorner")
bc.CornerRadius = UDim.new(0, 8)
bc.Parent = inscribeBtn

local hint = Instance.new("TextLabel")
hint.Size = UDim2.new(1, 0, 0, 18)
hint.Position = UDim2.new(0, 0, 1, -24)
hint.BackgroundTransparency = 1
hint.Font = Enum.Font.Gotham
hint.TextSize = 12
hint.TextColor3 = Color3.fromRGB(150, 150, 160)
hint.Text = "Press N to close"
hint.Parent = panel

inscribeBtn.Activated:Connect(function()
	Net.EnchantRequest:FireServer({ action = "inscribe" })
end)

UserInputService.InputBegan:Connect(function(input: InputObject, gameProcessed: boolean)
	if gameProcessed then
		return
	end
	if input.KeyCode == Enum.KeyCode.N then
		panel.Visible = not panel.Visible
		if panel.Visible then
			Net.EnchantRequest:FireServer({ action = "info" })
		end
	end
end)

Net.CombatFeedback.OnClientEvent:Connect(function(data: any)
	if typeof(data) ~= "table" then
		return
	end
	if data.altar then
		shardText.Text = string.format("◆ %d Vajra Shards", data.shards)
		local btnOk = data.shards >= data.cost
		inscribeBtn.BackgroundColor3 = if btnOk then SHARD else Color3.fromRGB(90, 84, 110)
		if data.enchant then
			mantraName.Text = string.format("%s   [%s]", tostring(data.enchant.name), string.upper(tostring(data.enchant.rarity)))
			mantraName.TextColor3 = rarityColor(tostring(data.enchant.rarity))
			mantraDesc.Text = tostring(data.enchant.desc)
		else
			mantraName.Text = "No mantra inscribed"
			mantraName.TextColor3 = Color3.fromRGB(160, 160, 170)
		end
	end
end)

print("[Dharma] MantraAltar ready — press N.")
