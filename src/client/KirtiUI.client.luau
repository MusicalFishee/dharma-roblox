--!strict
-- Kirti, the glory ledger (H key): ten lifetime deeds in three tiers —
-- Kansya, Rajata, Svarna — every one derived from stats already earned.
-- Reads the same snapshot the stats page uses; entirely code-built.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")

local Net = require(ReplicatedStorage.Shared.Net)
local Deeds = require(ReplicatedStorage.Shared.Deeds)

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local GOLD = Color3.fromRGB(255, 200, 40)
local PANEL_BG = Color3.fromRGB(18, 15, 22)
local ROW_BG = Color3.fromRGB(30, 25, 38)
local MUTED = Color3.fromRGB(200, 195, 205)
local DIM = Color3.fromRGB(120, 115, 130)

local screenGui = Instance.new("ScreenGui")
screenGui.Name = "DharmaKirti"
screenGui.ResetOnSpawn = false
screenGui.DisplayOrder = 15
screenGui.Enabled = false
screenGui.Parent = playerGui

local panel = Instance.new("Frame")
panel.AnchorPoint = Vector2.new(0.5, 0.5)
panel.Position = UDim2.fromScale(0.5, 0.5)
panel.Size = UDim2.fromOffset(460, 560)
panel.BackgroundColor3 = PANEL_BG
panel.BorderSizePixel = 0
panel.Parent = screenGui
local pc = Instance.new("UICorner")
pc.CornerRadius = UDim.new(0, 14)
pc.Parent = panel

local title = Instance.new("TextLabel")
title.Size = UDim2.new(1, 0, 0, 36)
title.Position = UDim2.fromOffset(0, 12)
title.BackgroundTransparency = 1
title.Font = Enum.Font.GothamBlack
title.TextSize = 24
title.TextColor3 = GOLD
title.Text = "KIRTI — THE GLORY LEDGER"
title.Parent = panel

local headline = Instance.new("TextLabel")
headline.Size = UDim2.new(1, -30, 0, 18)
headline.Position = UDim2.fromOffset(15, 46)
headline.BackgroundTransparency = 1
headline.Font = Enum.Font.GothamMedium
headline.TextSize = 13
headline.TextColor3 = DIM
headline.Text = ""
headline.Parent = panel

type Row = { dots: TextLabel, value: TextLabel, claim: TextButton }
local rows: { [string]: Row } = {}
local claims: { [string]: number } = {}
local lastSnap: Deeds.Snapshot? = nil

for i, def in Deeds.List do
	local row = Instance.new("Frame")
	row.Size = UDim2.new(1, -30, 0, 44)
	row.Position = UDim2.fromOffset(15, 70 + (i - 1) * 48)
	row.BackgroundColor3 = ROW_BG
	row.BorderSizePixel = 0
	row.Parent = panel
	local rc = Instance.new("UICorner")
	rc.CornerRadius = UDim.new(0, 8)
	rc.Parent = row

	local name = Instance.new("TextLabel")
	name.Size = UDim2.new(1, -160, 0, 20)
	name.Position = UDim2.fromOffset(12, 4)
	name.BackgroundTransparency = 1
	name.Font = Enum.Font.GothamBold
	name.TextSize = 14
	name.TextColor3 = Color3.fromRGB(245, 245, 245)
	name.TextXAlignment = Enum.TextXAlignment.Left
	name.Text = def.name
	name.Parent = row

	local value = Instance.new("TextLabel")
	value.Size = UDim2.new(1, -160, 0, 16)
	value.Position = UDim2.fromOffset(12, 24)
	value.BackgroundTransparency = 1
	value.Font = Enum.Font.Gotham
	value.TextSize = 11
	value.TextColor3 = DIM
	value.TextXAlignment = Enum.TextXAlignment.Left
	value.Text = def.line
	value.Parent = row

	local claimBtn = Instance.new("TextButton")
	claimBtn.Size = UDim2.fromOffset(84, 24)
	claimBtn.Position = UDim2.new(1, -96, 0, 10)
	claimBtn.Font = Enum.Font.GothamBold
	claimBtn.TextSize = 10
	claimBtn.Visible = false
	claimBtn.BackgroundColor3 = GOLD
	claimBtn.TextColor3 = Color3.fromRGB(20, 16, 24)
	claimBtn.Text = ""
	claimBtn.Parent = row
	local cbc = Instance.new("UICorner")
	cbc.CornerRadius = UDim.new(0, 6)
	cbc.Parent = claimBtn
	claimBtn.Activated:Connect(function()
		Net.KirtiRequest:FireServer({ action = "claim", id = def.id })
	end)

	local dots = Instance.new("TextLabel")
	dots.Size = UDim2.fromOffset(130, 44)
	dots.Position = UDim2.new(1, -230, 0, 0)
	dots.BackgroundTransparency = 1
	dots.Font = Enum.Font.GothamBold
	dots.TextSize = 20
	dots.TextXAlignment = Enum.TextXAlignment.Right
	dots.TextColor3 = MUTED
	dots.RichText = true
	dots.Text = "○ ○ ○"
	dots.Parent = row

	rows[def.id] = { dots = dots, value = value, claim = claimBtn }
end

local function hex(c: { number }): string
	return string.format("%02x%02x%02x", c[1], c[2], c[3])
end

local function refresh(snap: Deeds.Snapshot)
	lastSnap = snap
	for _, def in Deeds.List do
		local row = rows[def.id]
		local progress = Deeds.progress(def, snap)
		local owed = Deeds.owedFor(def, progress.value, claims[def.id] or 0)
		if owed.gold > 0 then
			row.claim.Visible = true
			row.claim.Text = string.format("CLAIM %d ◈", owed.gold)
		else
			row.claim.Visible = false
		end
		local marks = {}
		for tier = 1, 3 do
			if progress.tier >= tier then
				table.insert(marks, string.format('<font color="#%s">●</font>', hex(Deeds.TierColor[tier])))
			else
				table.insert(marks, "○")
			end
		end
		row.dots.Text = table.concat(marks, " ")
		if progress.nextThreshold then
			local shown = if def.kind == "playtime"
				then string.format("%s — %dh / %dh", def.line, math.floor(progress.value / 3600), math.floor(progress.nextThreshold / 3600))
				else string.format("%s — %d / %d", def.line, progress.value, progress.nextThreshold)
			row.value.Text = shown
		else
			row.value.Text = def.line .. " — SVARNA, complete"
		end
	end
	headline.Text = string.format("Tiers earned: %d of %d  ·  Kansya, Rajata, Svarna", Deeds.totalTiers(snap), Deeds.MaxTiers)
end

Net.CombatFeedback.OnClientEvent:Connect(function(data: any)
	if typeof(data) ~= "table" then
		return
	end
	if data.kirtiInfo then
		claims = {}
		if typeof(data.claims) == "table" then
			for id, tier in data.claims do
				claims[tostring(id)] = tonumber(tier) or 0
			end
		end
		if lastSnap then
			refresh(lastSnap :: Deeds.Snapshot)
		end
		return
	end
	if not data.statsPage then
		return
	end
	refresh({
		kills = tonumber(data.kills) or 0,
		bossKills = tonumber(data.bossKills) or 0,
		bestWave = tonumber(data.bestWave) or 0,
		duelWins = tonumber(data.duelWins) or 0,
		raidClears = tonumber(data.raidClears) or 0,
		revives = tonumber(data.revives) or 0,
		trials = tonumber(data.trialsPassed) or 0,
		level = tonumber(data.level) or 1,
		playtimeSeconds = tonumber(data.playtimeSeconds) or 0,
		deaths = tonumber(data.deaths) or 0,
	})
end)

-- Any opener (key, touch drawer, gamepad drawer) lands here: refresh both feeds.
screenGui:GetPropertyChangedSignal("Enabled"):Connect(function()
	if screenGui.Enabled then
		Net.StatsRequest:FireServer({ action = "info" })
		Net.KirtiRequest:FireServer({ action = "info" })
	end
end)

UserInputService.InputBegan:Connect(function(input, gameProcessed)
	if gameProcessed then
		return
	end
	if input.KeyCode == Enum.KeyCode.H then
		screenGui.Enabled = not screenGui.Enabled
		if screenGui.Enabled then
			Net.StatsRequest:FireServer({ action = "info" })
			Net.KirtiRequest:FireServer({ action = "info" })
		end
	end
end)

print("[Dharma] KirtiUI ready (H).")
