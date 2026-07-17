--!strict
-- The Vajra Bazaar (M key): Robux bundles for gold and Vajra Shards — and
-- nothing else, ever. Rows come from shared Products; live Robux prices are
-- fetched per product, and unregistered products (id 0) show AT LAUNCH.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")

local Products = require(ReplicatedStorage.Shared.Products)

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local GOLD = Color3.fromRGB(255, 200, 40)
local SHARD = Color3.fromRGB(180, 120, 255)
local PANEL_BG = Color3.fromRGB(18, 15, 22)
local ROW_BG = Color3.fromRGB(30, 25, 38)
local _MUTED = Color3.fromRGB(200, 195, 205)
local DIM = Color3.fromRGB(120, 115, 130)

local screenGui = Instance.new("ScreenGui")
screenGui.Name = "DharmaBazaar"
screenGui.ResetOnSpawn = false
screenGui.DisplayOrder = 15
screenGui.Enabled = false
screenGui.Parent = playerGui

local panel = Instance.new("Frame")
panel.AnchorPoint = Vector2.new(0.5, 0.5)
panel.Position = UDim2.fromScale(0.5, 0.5)
panel.Size = UDim2.fromOffset(420, 468)
panel.BackgroundColor3 = PANEL_BG
panel.BorderSizePixel = 0
panel.Parent = screenGui
local pc = Instance.new("UICorner")
pc.CornerRadius = UDim.new(0, 14)
pc.Parent = panel

local title = Instance.new("TextLabel")
title.Size = UDim2.new(1, 0, 0, 38)
title.Position = UDim2.fromOffset(0, 12)
title.BackgroundTransparency = 1
title.Font = Enum.Font.GothamBlack
title.TextSize = 24
title.TextColor3 = GOLD
title.Text = "VAJRA BAZAAR"
title.Parent = panel

local ethos = Instance.new("TextLabel")
ethos.Size = UDim2.new(1, -30, 0, 18)
ethos.Position = UDim2.fromOffset(15, 48)
ethos.BackgroundTransparency = 1
ethos.Font = Enum.Font.GothamMedium
ethos.TextSize = 12
ethos.TextColor3 = DIM
ethos.Text = "Gold and shards only — power is earned, never bought."
ethos.Parent = panel

for i, def in Products.List do
	local row = Instance.new("Frame")
	row.Size = UDim2.new(1, -30, 0, 56)
	row.Position = UDim2.fromOffset(15, 74 + (i - 1) * 62)
	row.BackgroundColor3 = ROW_BG
	row.BorderSizePixel = 0
	row.Parent = panel
	local rc = Instance.new("UICorner")
	rc.CornerRadius = UDim.new(0, 10)
	rc.Parent = row

	local name = Instance.new("TextLabel")
	name.Size = UDim2.new(1, -140, 0, 24)
	name.Position = UDim2.fromOffset(12, 6)
	name.BackgroundTransparency = 1
	name.Font = Enum.Font.GothamBold
	name.TextSize = 15
	name.TextColor3 = Color3.fromRGB(245, 245, 245)
	name.TextXAlignment = Enum.TextXAlignment.Left
	name.Text = def.name
	name.Parent = row

	local contents = Instance.new("TextLabel")
	contents.Size = UDim2.new(1, -140, 0, 18)
	contents.Position = UDim2.fromOffset(12, 30)
	contents.BackgroundTransparency = 1
	contents.Font = Enum.Font.Gotham
	contents.TextSize = 13
	contents.TextColor3 = if def.kind == "gold" then GOLD else SHARD
	contents.TextXAlignment = Enum.TextXAlignment.Left
	contents.Text = if def.kind == "gold" then string.format("◈ %d gold", def.amount) else string.format("◆ %d Vajra Shards", def.amount)
	contents.Parent = row

	local buy = Instance.new("TextButton")
	buy.Size = UDim2.fromOffset(110, 36)
	buy.Position = UDim2.new(1, -122, 0.5, -18)
	buy.Font = Enum.Font.GothamBold
	buy.TextSize = 14
	buy.Parent = row
	local bc = Instance.new("UICorner")
	bc.CornerRadius = UDim.new(0, 8)
	bc.Parent = buy

	if def.productId == 0 then
		buy.Text = "AT LAUNCH"
		buy.BackgroundColor3 = Color3.fromRGB(60, 54, 70)
		buy.TextColor3 = DIM
		buy.AutoButtonColor = false
	else
		buy.Text = "…"
		buy.BackgroundColor3 = Color3.fromRGB(70, 200, 120)
		buy.TextColor3 = Color3.fromRGB(12, 24, 16)
		task.spawn(function()
			local ok, info = pcall(function()
				return MarketplaceService:GetProductInfo(def.productId, Enum.InfoType.Product)
			end)
			buy.Text = if ok and info and info.PriceInRobux then string.format("R$ %d", info.PriceInRobux) else "BUY"
		end)
		buy.Activated:Connect(function()
			MarketplaceService:PromptProductPurchase(player, def.productId)
		end)
	end
end

local footer = Instance.new("TextLabel")
footer.Size = UDim2.new(1, -30, 0, 16)
footer.Position = UDim2.new(0, 15, 1, -26)
footer.BackgroundTransparency = 1
footer.Font = Enum.Font.Gotham
footer.TextSize = 11
footer.TextColor3 = DIM
footer.Text = "Press M to close"
footer.Parent = panel

UserInputService.InputBegan:Connect(function(input, gameProcessed)
	if gameProcessed then
		return
	end
	if input.KeyCode == Enum.KeyCode.M then
		screenGui.Enabled = not screenGui.Enabled
	end
end)

print("[Dharma] BazaarUI ready (M).")
