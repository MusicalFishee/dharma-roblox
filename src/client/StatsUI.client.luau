--!strict
-- The stats page ("Parakram" — your deeds of valor). Press P to open/close; shows
-- level, wealth, armament, and lifetime records. Entirely code-built.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")

local Net = require(ReplicatedStorage.Shared.Net)
local Enchants = require(ReplicatedStorage.Shared.Enchants)

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local SAFFRON = Color3.fromRGB(255, 160, 40)
local PANEL_BG = Color3.fromRGB(19, 16, 24)
local VALUE = Color3.fromRGB(240, 238, 245)
local LABEL = Color3.fromRGB(165, 160, 175)

local screenGui = Instance.new("ScreenGui")
screenGui.Name = "DharmaStats"
screenGui.ResetOnSpawn = false
screenGui.Parent = playerGui

local panel = Instance.new("Frame")
panel.Size = UDim2.fromOffset(360, 492)
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
title.Size = UDim2.new(1, 0, 0, 42)
title.BackgroundTransparency = 1
title.Font = Enum.Font.GothamBlack
title.TextSize = 22
title.TextColor3 = SAFFRON
title.Text = "PARAKRAM — YOUR LEGEND"
title.Parent = panel

type Row = { label: TextLabel, value: TextLabel }
local rows: { [string]: Row } = {}

local ROW_ORDER = {
	{ key = "level", label = "Level" },
	{ key = "gold", label = "Gold" },
	{ key = "shards", label = "Vajra Shards" },
	{ key = "weapon", label = "Weapon" },
	{ key = "mantra", label = "Mantra" },
	{ key = "kills", label = "Foes slain" },
	{ key = "bossKills", label = "Bosses felled" },
	{ key = "bestWave", label = "Deepest wave" },
	{ key = "duelWins", label = "Duels won" },
	{ key = "raidClears", label = "Ravanas felled" },
	{ key = "revives", label = "Allies lifted" },
	{ key = "deerKills", label = "Golden deer felled" },
	{ key = "vairisFelled", label = "Nemeses ended" },
	{ key = "weaponRank", label = "Blade mastery" },
	{ key = "deaths", label = "Times fallen" },
	{ key = "playtime", label = "Time at war" },
}

for i, def in ROW_ORDER do
	local y = 46 + (i - 1) * 32
	local label = Instance.new("TextLabel")
	label.Size = UDim2.new(0.5, -18, 0, 28)
	label.Position = UDim2.fromOffset(14, y)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.GothamMedium
	label.TextSize = 14
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.TextColor3 = LABEL
	label.Text = def.label
	label.Parent = panel

	local value = Instance.new("TextLabel")
	value.Size = UDim2.new(0.5, -18, 0, 28)
	value.AnchorPoint = Vector2.new(1, 0)
	value.Position = UDim2.new(1, -14, 0, y)
	value.BackgroundTransparency = 1
	value.Font = Enum.Font.GothamBold
	value.TextSize = 14
	value.TextXAlignment = Enum.TextXAlignment.Right
	value.TextColor3 = VALUE
	value.Text = "—"
	value.Parent = panel

	rows[def.key] = { label = label, value = value }
end

local hint = Instance.new("TextLabel")
hint.Size = UDim2.new(1, 0, 0, 18)
hint.Position = UDim2.new(0, 0, 1, -24)
hint.BackgroundTransparency = 1
hint.Font = Enum.Font.Gotham
hint.TextSize = 12
hint.TextColor3 = Color3.fromRGB(150, 150, 160)
hint.Text = "Press P to close"
hint.Parent = panel

local function fmtTime(seconds: number): string
	local h = math.floor(seconds / 3600)
	local m = math.floor((seconds % 3600) / 60)
	if h > 0 then
		return string.format("%dh %02dm", h, m)
	end
	return string.format("%dm", m)
end

local function rarityColor(rarity: string): Color3
	local c = Enchants.RarityColor[rarity]
	if c then
		return Color3.fromRGB(c[1], c[2], c[3])
	end
	return VALUE
end

UserInputService.InputBegan:Connect(function(input: InputObject, gameProcessed: boolean)
	if gameProcessed then
		return
	end
	if input.KeyCode == Enum.KeyCode.P then
		panel.Visible = not panel.Visible
		if panel.Visible then
			Net.StatsRequest:FireServer({ action = "info" })
		end
	end
end)

Net.CombatFeedback.OnClientEvent:Connect(function(data: any)
	if typeof(data) ~= "table" or not data.statsPage then
		return
	end
	rows.level.value.Text = string.format("Lv %d", data.level)
	rows.gold.value.Text = string.format("◈ %d", data.gold)
	rows.shards.value.Text = string.format("◆ %d", data.shards)
	rows.weapon.value.Text = if data.hasWeapon
		then string.format("%s (T%d/%d)", tostring(data.weaponName), data.weaponTier, data.weaponMax)
		else "none chosen"
	if data.mantraName then
		rows.mantra.value.Text = tostring(data.mantraName)
		rows.mantra.value.TextColor3 = rarityColor(tostring(data.mantraRarity))
	else
		rows.mantra.value.Text = "unmarked"
		rows.mantra.value.TextColor3 = LABEL
	end
	rows.kills.value.Text = tostring(data.kills)
	rows.bossKills.value.Text = tostring(data.bossKills)
	rows.bestWave.value.Text = if data.bestWave > 0 then string.format("Wave %d", data.bestWave) else "—"
	rows.duelWins.value.Text = tostring(data.duelWins)
	rows.raidClears.value.Text = tostring(data.raidClears)
	rows.revives.value.Text = tostring(data.revives)
	rows.deerKills.value.Text = tostring(data.deerKills)
	rows.vairisFelled.value.Text = tostring(data.vairisFelled)
	rows.weaponRank.value.Text = tostring(data.weaponRank)
	rows.deaths.value.Text = tostring(data.deaths)
	rows.playtime.value.Text = fmtTime(data.playtimeSeconds)
end)

print("[Dharma] Stats page ready — press P.")
