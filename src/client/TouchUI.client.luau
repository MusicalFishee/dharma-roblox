--!strict
-- Touch controls: most of Roblox fights from a phone. Shows only when touch is
-- the device's story (touch enabled, no keyboard): a right-thumb combat cluster
-- (ATTACK, dodge, hold-to-block, Z/X/C/V Astra arc) and a left menu drawer that
-- opens every panel the keyboard reaches by letter. Fires the exact same
-- remotes as CombatController — the server can't tell thumb from key.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")

local Net = require(ReplicatedStorage.Shared.Net)

if not UserInputService.TouchEnabled or UserInputService.KeyboardEnabled then
	return -- keyboards keep their keys
end

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local GOLD = Color3.fromRGB(255, 200, 40)
local BTN_BG = Color3.fromRGB(24, 20, 30)
local DIM = Color3.fromRGB(200, 195, 205)

local screenGui = Instance.new("ScreenGui")
screenGui.Name = "DharmaTouch"
screenGui.ResetOnSpawn = false
screenGui.DisplayOrder = 12
screenGui.Parent = playerGui

local function roundButton(text: string, size: number, pos: UDim2, color: Color3?): TextButton
	local b = Instance.new("TextButton")
	b.Size = UDim2.fromOffset(size, size)
	b.Position = pos
	b.AnchorPoint = Vector2.new(1, 1)
	b.BackgroundColor3 = color or BTN_BG
	b.BackgroundTransparency = 0.25
	b.Font = Enum.Font.GothamBold
	b.TextSize = math.floor(size * 0.32)
	b.TextColor3 = if color then Color3.fromRGB(20, 16, 24) else DIM
	b.Text = text
	b.Parent = screenGui
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0.5, 0)
	c.Parent = b
	return b
end

-- The combat cluster (right thumb).
local attack = roundButton("STRIKE", 92, UDim2.new(1, -24, 1, -24), GOLD)
attack.Activated:Connect(function()
	Net.AttackRequest:FireServer()
end)

local dodge = roundButton("DODGE", 62, UDim2.new(1, -128, 1, -24))
dodge.Activated:Connect(function()
	Net.DefenseState:FireServer({ dodge = true })
end)

local block = roundButton("BLOCK", 62, UDim2.new(1, -24, 1, -128))
block.MouseButton1Down:Connect(function()
	Net.DefenseState:FireServer({ isBlocking = true })
end)
block.MouseButton1Up:Connect(function()
	Net.DefenseState:FireServer({ isBlocking = false })
end)

-- The Astra arc above the cluster.
local slots = { "Z", "X", "C", "V" }
for i, slot in slots do
	local b = roundButton(slot, 52, UDim2.new(1, -24 - (i - 1) * 58, 1, -200))
	b.Activated:Connect(function()
		Net.AbilityRequest:FireServer(slot)
	end)
end

-- The menu drawer (left edge): every letter-key panel, one thumb away.
-- Panels that refresh on open get their info remote fired alongside.
local drawerOpen = false
local drawerButtons: { TextButton } = {}

type Entry = { label: string, gui: string, open: (() -> ())? }
local entries: { Entry } = {
	{ label = "Shop", gui = "DharmaShop", open = function()
		Net.ShopRequest:FireServer({ action = "info" })
	end },
	{ label = "Altar", gui = "DharmaAltar", open = function()
		Net.EnchantRequest:FireServer({ action = "info" })
	end },
	{ label = "Paths", gui = "DharmaPathSelect", open = function()
		Net.PathRequest:FireServer({ action = "info" })
	end },
	{ label = "Relics", gui = "DharmaRelics", open = function()
		Net.RelicRequest:FireServer({ action = "info" })
	end },
	{ label = "Armory", gui = "DharmaArmory", open = function()
		Net.StatsRequest:FireServer({ action = "info" })
	end },
	{ label = "Stats", gui = "DharmaStats", open = function()
		Net.StatsRequest:FireServer({ action = "info" })
	end },
	{ label = "Kirti", gui = "DharmaKirti", open = function()
		Net.StatsRequest:FireServer({ action = "info" })
	end },
	{ label = "Titles", gui = "DharmaTitles", open = function()
		Net.TitleRequest:FireServer({ action = "list" })
	end },
	{ label = "Duels", gui = "DharmaPvP", open = function()
		Net.PvPRequest:FireServer({ action = "list" })
	end },
	{ label = "Story", gui = "DharmaStory", open = function()
		Net.StoryRequest:FireServer({ action = "info" })
	end },
	{ label = "Rites", gui = "DharmaRites", open = function()
		Net.RitesRequest:FireServer({ action = "info" })
	end },
	{ label = "Bazaar", gui = "DharmaBazaar" },
}

local menu = Instance.new("TextButton")
menu.Size = UDim2.fromOffset(52, 52)
menu.Position = UDim2.fromOffset(16, 120)
menu.BackgroundColor3 = BTN_BG
menu.BackgroundTransparency = 0.25
menu.Font = Enum.Font.GothamBold
menu.TextSize = 22
menu.TextColor3 = GOLD
menu.Text = "☰"
menu.Parent = screenGui
local mc = Instance.new("UICorner")
mc.CornerRadius = UDim.new(0, 12)
mc.Parent = menu

for i, entry in entries do
	local b = Instance.new("TextButton")
	b.Size = UDim2.fromOffset(96, 36)
	b.Position = UDim2.fromOffset(16, 180 + (i - 1) * 42)
	b.BackgroundColor3 = BTN_BG
	b.BackgroundTransparency = 0.2
	b.Font = Enum.Font.GothamBold
	b.TextSize = 13
	b.TextColor3 = DIM
	b.Text = entry.label
	b.Visible = false
	b.Parent = screenGui
	local bc = Instance.new("UICorner")
	bc.CornerRadius = UDim.new(0, 8)
	bc.Parent = b

	b.Activated:Connect(function()
		local gui = playerGui:FindFirstChild(entry.gui)
		if gui and gui:IsA("ScreenGui") then
			gui.Enabled = not gui.Enabled
			if gui.Enabled and entry.open then
				entry.open()
			end
		end
		drawerOpen = false
		for _, db in drawerButtons do
			db.Visible = false
		end
	end)
	table.insert(drawerButtons, b)
end

menu.Activated:Connect(function()
	drawerOpen = not drawerOpen
	for _, b in drawerButtons do
		b.Visible = drawerOpen
	end
end)

print("[Dharma] TouchUI ready — the war fits in one hand.")
