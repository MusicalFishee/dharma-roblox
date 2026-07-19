--!strict
-- The Armory (O key): every weapon in the game — the four starters and the
-- five earned by deed. Unlocked blades wield freely (your smith's tier travels
-- with you); locked ones show the deed that opens them. The server re-checks
-- every unlock, so this panel is a window, not a gate.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")

local Net = require(ReplicatedStorage.Shared.Net)
local Weapons = require(ReplicatedStorage.Shared.Weapons)
local Shastra = require(ReplicatedStorage.Shared.Shastra)

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local GOLD = Color3.fromRGB(255, 200, 40)
local PANEL_BG = Color3.fromRGB(18, 15, 22)
local ROW_BG = Color3.fromRGB(30, 25, 38)
local _MUTED = Color3.fromRGB(200, 195, 205)
local DIM = Color3.fromRGB(120, 115, 130)
local SIGNATURE = Color3.fromRGB(150, 200, 255)

local currentWeaponId = ""
local snap: Weapons.UnlockSnapshot = { kills = 0, bossKills = 0, trials = 0, revives = 0, raidClears = 0 }

local screenGui = Instance.new("ScreenGui")
screenGui.Name = "DharmaArmory"
screenGui.ResetOnSpawn = false
screenGui.DisplayOrder = 15
screenGui.Enabled = false
screenGui.Parent = playerGui

local panel = Instance.new("Frame")
panel.AnchorPoint = Vector2.new(0.5, 0.5)
panel.Position = UDim2.fromScale(0.5, 0.5)
panel.Size = UDim2.fromOffset(520, 596)
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
title.Text = "THE ARMORY"
title.Parent = panel

local subtitle = Instance.new("TextLabel")
subtitle.Size = UDim2.new(1, -30, 0, 16)
subtitle.Position = UDim2.fromOffset(15, 42)
subtitle.BackgroundTransparency = 1
subtitle.Font = Enum.Font.Gotham
subtitle.TextSize = 12
subtitle.TextColor3 = DIM
subtitle.Text = "Your tier travels with you — the craft is yours, not the blade's."
subtitle.Parent = panel

type Row = { button: TextButton, name: TextLabel, sig: TextLabel }
local rows: { [string]: Row } = {}

for i, def in Weapons.List do
	local row = Instance.new("Frame")
	row.Size = UDim2.new(1, -30, 0, 52)
	row.Position = UDim2.fromOffset(15, 64 + (i - 1) * 58)
	row.BackgroundColor3 = ROW_BG
	row.BorderSizePixel = 0
	row.Parent = panel
	local rc = Instance.new("UICorner")
	rc.CornerRadius = UDim.new(0, 8)
	rc.Parent = row

	local name = Instance.new("TextLabel")
	name.Size = UDim2.new(1, -150, 0, 22)
	name.Position = UDim2.fromOffset(12, 4)
	name.BackgroundTransparency = 1
	name.Font = Enum.Font.GothamBold
	name.TextSize = 14
	name.TextColor3 = Color3.fromRGB(245, 245, 245)
	name.TextXAlignment = Enum.TextXAlignment.Left
	name.Text = string.format("%s — %s", def.displayName, def.title)
	name.Parent = row

	local sigLine = Instance.new("TextLabel")
	sigLine.Size = UDim2.new(1, -150, 0, 20)
	sigLine.Position = UDim2.fromOffset(12, 26)
	sigLine.BackgroundTransparency = 1
	sigLine.Font = Enum.Font.Gotham
	sigLine.TextSize = 11
	sigLine.TextColor3 = SIGNATURE
	sigLine.TextXAlignment = Enum.TextXAlignment.Left
	sigLine.TextWrapped = true
	sigLine.Text = Weapons.signatureOf(def.id).line
	sigLine.Parent = row

	local button = Instance.new("TextButton")
	button.Size = UDim2.fromOffset(120, 34)
	button.Position = UDim2.new(1, -132, 0.5, -17)
	button.Font = Enum.Font.GothamBold
	button.TextSize = 12
	button.TextWrapped = true
	button.Parent = row
	local bc = Instance.new("UICorner")
	bc.CornerRadius = UDim.new(0, 8)
	bc.Parent = button

	button.Activated:Connect(function()
		if def.id ~= currentWeaponId and Weapons.isUnlocked(def.id, snap) then
			Net.WeaponRequest:FireServer({ action = "select", id = def.id })
		end
	end)

	rows[def.id] = { button = button, name = name, sig = sigLine, sigBase = sigLine.Text }
end

local shastraXp: { [string]: number } = {}

local function refresh()
	for _, def in Weapons.List do
		local row = rows[def.id]
		local xp = shastraXp[def.id] or 0
		local standing = Shastra.resolve(xp)
		local rankBit = if standing.nextAt
			then string.format("%s (%d / %d)", standing.def.name, xp, standing.nextAt)
			else standing.def.name .. " ✦"
		row.sig.Text = string.format("%s   ·   %s", (row :: any).sigBase, rankBit)
		if def.id == currentWeaponId then
			row.button.Text = "WIELDING"
			row.button.BackgroundColor3 = Color3.fromRGB(80, 70, 95)
			row.button.TextColor3 = Color3.fromRGB(230, 225, 240)
			row.button.AutoButtonColor = false
		elseif Weapons.isUnlocked(def.id, snap) then
			row.button.Text = "Wield"
			row.button.BackgroundColor3 = GOLD
			row.button.TextColor3 = Color3.fromRGB(20, 16, 24)
			row.button.AutoButtonColor = true
		else
			row.button.Text = if def.unlock then def.unlock.label else "Locked"
			row.button.BackgroundColor3 = Color3.fromRGB(60, 54, 70)
			row.button.TextColor3 = DIM
			row.button.AutoButtonColor = false
		end
	end
end

Net.CombatFeedback.OnClientEvent:Connect(function(data: any)
	if typeof(data) ~= "table" then
		return
	end
	if data.statsPage then
		currentWeaponId = tostring(data.weaponId or currentWeaponId)
		if typeof(data.shastra) == "table" then
			shastraXp = data.shastra
		end
		snap = {
			kills = tonumber(data.kills) or 0,
			bossKills = tonumber(data.bossKills) or 0,
			trials = tonumber(data.trialsPassed) or 0,
			revives = tonumber(data.revives) or 0,
			raidClears = tonumber(data.raidClears) or 0,
		}
		refresh()
		return
	end
	if data.weaponChosen and data.id then
		currentWeaponId = tostring(data.id)
		refresh()
		return
	end
end)

UserInputService.InputBegan:Connect(function(input, gameProcessed)
	if gameProcessed then
		return
	end
	if input.KeyCode == Enum.KeyCode.O then
		screenGui.Enabled = not screenGui.Enabled
		if screenGui.Enabled then
			Net.StatsRequest:FireServer({ action = "info" })
		end
	end
end)

print("[Dharma] ArmoryUI ready (O).")
