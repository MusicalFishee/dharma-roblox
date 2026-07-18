--!strict
-- Code-built combat HUD: Tejas bar, Flow combo counter, outcome toasts.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")

local Net = require(ReplicatedStorage.Shared.Net)
local Combat = require(ReplicatedStorage.Shared.Combat)
local Bhoota = require(ReplicatedStorage.Shared.Bhoota)
local Ranks = require(ReplicatedStorage.Shared.Ranks)
local Progression = require(ReplicatedStorage.Shared.Progression)

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

-- Level + XP bar (just above the Tejas bar).
local xpBg = Instance.new("Frame")
xpBg.Size = UDim2.fromOffset(320, 18)
xpBg.Position = UDim2.new(0, 28, 1, -80)
xpBg.BackgroundColor3 = Color3.fromRGB(20, 18, 24)
xpBg.BorderSizePixel = 0
xpBg.Parent = screenGui

local xpFill = Instance.new("Frame")
xpFill.Size = UDim2.new(0, 0, 1, 0)
xpFill.BackgroundColor3 = Color3.fromRGB(120, 210, 255)
xpFill.BorderSizePixel = 0
xpFill.Parent = xpBg

local levelLabel = Instance.new("TextLabel")
levelLabel.Size = UDim2.fromScale(1, 1)
levelLabel.BackgroundTransparency = 1
levelLabel.Font = Enum.Font.GothamBold
levelLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
levelLabel.TextSize = 13
levelLabel.Text = "Lv 1"
levelLabel.Parent = xpBg

-- Gold counter (above the XP bar).
local goldLabel = Instance.new("TextLabel")
goldLabel.Size = UDim2.fromOffset(320, 20)
goldLabel.Position = UDim2.new(0, 28, 1, -104)
goldLabel.BackgroundTransparency = 1
goldLabel.Font = Enum.Font.GothamBold
goldLabel.TextXAlignment = Enum.TextXAlignment.Left
goldLabel.TextSize = 16
goldLabel.TextColor3 = Color3.fromRGB(255, 200, 40)
goldLabel.TextStrokeTransparency = 0.6
goldLabel.Text = "◈ 0 gold"
goldLabel.Parent = screenGui

-- Wave banner (top-centre).
local waveLabel = Instance.new("TextLabel")
waveLabel.Size = UDim2.fromOffset(360, 28)
waveLabel.AnchorPoint = Vector2.new(0.5, 0)
waveLabel.Position = UDim2.new(0.5, 0, 0, 8)
waveLabel.BackgroundTransparency = 1
waveLabel.Font = Enum.Font.GothamBold
waveLabel.TextSize = 20
waveLabel.TextColor3 = Color3.fromRGB(255, 180, 90)
waveLabel.TextStrokeTransparency = 0.5
waveLabel.Text = ""
waveLabel.Parent = screenGui

-- Boss health bar (top-centre, hidden until a boss spawns).
local bossFrame = Instance.new("Frame")
bossFrame.Size = UDim2.fromOffset(520, 44)
bossFrame.AnchorPoint = Vector2.new(0.5, 0)
bossFrame.Position = UDim2.new(0.5, 0, 0, 46)
bossFrame.BackgroundTransparency = 1
bossFrame.Visible = false
bossFrame.Parent = screenGui

local bossName = Instance.new("TextLabel")
bossName.Size = UDim2.fromOffset(520, 20)
bossName.BackgroundTransparency = 1
bossName.Font = Enum.Font.GothamBlack
bossName.TextSize = 18
bossName.TextColor3 = Color3.fromRGB(255, 90, 80)
bossName.TextStrokeTransparency = 0.4
bossName.Text = ""
bossName.Parent = bossFrame

local bossBarBg = Instance.new("Frame")
bossBarBg.Size = UDim2.fromOffset(520, 16)
bossBarBg.Position = UDim2.fromOffset(0, 24)
bossBarBg.BackgroundColor3 = Color3.fromRGB(25, 10, 12)
bossBarBg.BorderSizePixel = 0
bossBarBg.Parent = bossFrame

local bossBarFill = Instance.new("Frame")
bossBarFill.Size = UDim2.fromScale(1, 1)
bossBarFill.BackgroundColor3 = Color3.fromRGB(210, 40, 40)
bossBarFill.BorderSizePixel = 0
bossBarFill.Parent = bossBarBg

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

-- Boss speech: scripted lines delivered cold, held long enough to read.
local speechSpeaker = Instance.new("TextLabel")
speechSpeaker.Size = UDim2.fromOffset(700, 22)
speechSpeaker.AnchorPoint = Vector2.new(0.5, 0)
speechSpeaker.Position = UDim2.new(0.5, 0, 0.62, 0)
speechSpeaker.BackgroundTransparency = 1
speechSpeaker.Font = Enum.Font.GothamBold
speechSpeaker.TextSize = 15
speechSpeaker.TextColor3 = Color3.fromRGB(255, 170, 50)
speechSpeaker.TextTransparency = 1
speechSpeaker.Text = ""
speechSpeaker.Parent = screenGui

local speechLine = Instance.new("TextLabel")
speechLine.Size = UDim2.fromOffset(760, 40)
speechLine.AnchorPoint = Vector2.new(0.5, 0)
speechLine.Position = UDim2.new(0.5, 0, 0.62, 24)
speechLine.BackgroundTransparency = 1
speechLine.Font = Enum.Font.Garamond
speechLine.TextSize = 30
speechLine.TextColor3 = Color3.fromRGB(240, 235, 225)
speechLine.TextStrokeTransparency = 0.4
speechLine.TextTransparency = 1
speechLine.TextWrapped = true
speechLine.Text = ""
speechLine.Parent = screenGui

local speechToken = 0
local function showSpeech(speaker: string, text: string)
	speechToken += 1
	local token = speechToken
	speechSpeaker.Text = string.upper(speaker)
	speechLine.Text = "“" .. text .. "”"
	speechSpeaker.TextTransparency = 0
	speechLine.TextTransparency = 0
	task.delay(3.6, function()
		if token == speechToken then
			TweenService:Create(speechSpeaker, TweenInfo.new(0.8), { TextTransparency = 1 }):Play()
			TweenService:Create(speechLine, TweenInfo.new(0.8), { TextTransparency = 1 }):Play()
		end
	end)
end

-- Party-wipe overlay (full-screen, hidden until the line breaks).
local wipeOverlay = Instance.new("Frame")
wipeOverlay.Size = UDim2.fromScale(1, 1)
wipeOverlay.BackgroundColor3 = Color3.fromRGB(30, 6, 8)
wipeOverlay.BackgroundTransparency = 1
wipeOverlay.Visible = false
wipeOverlay.ZIndex = 50
wipeOverlay.Parent = screenGui

local wipeTitle = Instance.new("TextLabel")
wipeTitle.Size = UDim2.fromOffset(700, 60)
wipeTitle.AnchorPoint = Vector2.new(0.5, 1)
wipeTitle.Position = UDim2.new(0.5, 0, 0.5, -6)
wipeTitle.BackgroundTransparency = 1
wipeTitle.Font = Enum.Font.GothamBlack
wipeTitle.TextSize = 46
wipeTitle.TextColor3 = Color3.fromRGB(240, 70, 60)
wipeTitle.TextStrokeTransparency = 0.4
wipeTitle.TextTransparency = 1
wipeTitle.ZIndex = 51
wipeTitle.Text = "THE LINE HAS BROKEN"
wipeTitle.Parent = wipeOverlay

local wipeSub = Instance.new("TextLabel")
wipeSub.Size = UDim2.fromOffset(700, 40)
wipeSub.AnchorPoint = Vector2.new(0.5, 0)
wipeSub.Position = UDim2.new(0.5, 0, 0.5, 10)
wipeSub.BackgroundTransparency = 1
wipeSub.Font = Enum.Font.GothamMedium
wipeSub.TextSize = 22
wipeSub.TextColor3 = Color3.fromRGB(235, 200, 180)
wipeSub.TextStrokeTransparency = 0.5
wipeSub.TextTransparency = 1
wipeSub.ZIndex = 51
wipeSub.Text = ""
wipeSub.Parent = wipeOverlay

-- Uddhāra banner (bottom-center, shown while YOU are down).
local downFrame = Instance.new("Frame")
downFrame.Size = UDim2.fromOffset(460, 64)
downFrame.AnchorPoint = Vector2.new(0.5, 1)
downFrame.Position = UDim2.new(0.5, 0, 1, -110)
downFrame.BackgroundColor3 = Color3.fromRGB(40, 8, 10)
downFrame.BackgroundTransparency = 0.25
downFrame.Visible = false
downFrame.ZIndex = 40
downFrame.Parent = screenGui
local downCorner = Instance.new("UICorner")
downCorner.CornerRadius = UDim.new(0, 12)
downCorner.Parent = downFrame

local downTitle = Instance.new("TextLabel")
downTitle.Size = UDim2.new(1, -20, 0, 30)
downTitle.Position = UDim2.fromOffset(10, 6)
downTitle.BackgroundTransparency = 1
downTitle.Font = Enum.Font.GothamBlack
downTitle.TextSize = 20
downTitle.TextColor3 = Color3.fromRGB(240, 90, 80)
downTitle.ZIndex = 41
downTitle.Text = Bhoota.Lines.downedTitle
downTitle.Parent = downFrame

local downSub = Instance.new("TextLabel")
downSub.Size = UDim2.new(1, -20, 0, 20)
downSub.Position = UDim2.fromOffset(10, 36)
downSub.BackgroundTransparency = 1
downSub.Font = Enum.Font.GothamMedium
downSub.TextSize = 14
downSub.TextColor3 = Color3.fromRGB(235, 200, 180)
downSub.ZIndex = 41
downSub.Text = ""
downSub.Parent = downFrame

local downToken = 0
local function showDowned(seconds: number)
	downToken += 1
	local token = downToken
	downFrame.Visible = true
	task.spawn(function()
		local left = seconds
		while left > 0 and token == downToken do
			downSub.Text = string.format(Bhoota.Lines.downedSub, math.ceil(left))
			task.wait(0.25)
			left -= 0.25
		end
		if token == downToken then
			downFrame.Visible = false
		end
	end)
end
local function hideDowned()
	downToken += 1
	downFrame.Visible = false
end

-- Bhoota banner (shown while you wander; Punarjanma clears it).
local bhootaFrame = Instance.new("Frame")
bhootaFrame.Size = UDim2.fromOffset(460, 64)
bhootaFrame.AnchorPoint = Vector2.new(0.5, 1)
bhootaFrame.Position = UDim2.new(0.5, 0, 1, -110)
bhootaFrame.BackgroundColor3 = Color3.fromRGB(14, 20, 34)
bhootaFrame.BackgroundTransparency = 0.25
bhootaFrame.Visible = false
bhootaFrame.ZIndex = 40
bhootaFrame.Parent = screenGui
local bhootaCorner = Instance.new("UICorner")
bhootaCorner.CornerRadius = UDim.new(0, 12)
bhootaCorner.Parent = bhootaFrame

local bhootaTitle = Instance.new("TextLabel")
bhootaTitle.Size = UDim2.new(1, -20, 0, 30)
bhootaTitle.Position = UDim2.fromOffset(10, 6)
bhootaTitle.BackgroundTransparency = 1
bhootaTitle.Font = Enum.Font.GothamBlack
bhootaTitle.TextSize = 20
bhootaTitle.TextColor3 = Color3.fromRGB(170, 210, 255)
bhootaTitle.ZIndex = 41
bhootaTitle.Text = Bhoota.Lines.ghostTitle
bhootaTitle.Parent = bhootaFrame

local bhootaSub = Instance.new("TextLabel")
bhootaSub.Size = UDim2.new(1, -20, 0, 20)
bhootaSub.Position = UDim2.fromOffset(10, 36)
bhootaSub.BackgroundTransparency = 1
bhootaSub.Font = Enum.Font.GothamMedium
bhootaSub.TextSize = 13
bhootaSub.TextColor3 = Color3.fromRGB(200, 215, 235)
bhootaSub.ZIndex = 41
bhootaSub.Text = Bhoota.Lines.ghostSub
bhootaSub.Parent = bhootaFrame

local wipeToken = 0
local function showWipe(failedWave: number, restartWave: number, delay: number)
	wipeToken += 1
	local token = wipeToken
	bossFrame.Visible = false
	comboLabel.Text = ""
	wipeOverlay.Visible = true
	TweenService:Create(wipeOverlay, TweenInfo.new(0.5), { BackgroundTransparency = 0.25 }):Play()
	TweenService:Create(wipeTitle, TweenInfo.new(0.5), { TextTransparency = 0 }):Play()
	TweenService:Create(wipeSub, TweenInfo.new(0.5), { TextTransparency = 0 }):Play()
	task.spawn(function()
		for remaining = math.ceil(delay), 1, -1 do
			if token ~= wipeToken then
				return
			end
			wipeSub.Text = string.format(
				"Wave %d lost.  Reforming at Wave %d  —  %ds",
				failedWave, restartWave, remaining
			)
			task.wait(1)
		end
		if token ~= wipeToken then
			return
		end
		TweenService:Create(wipeOverlay, TweenInfo.new(0.4), { BackgroundTransparency = 1 }):Play()
		TweenService:Create(wipeTitle, TweenInfo.new(0.4), { TextTransparency = 1 }):Play()
		TweenService:Create(wipeSub, TweenInfo.new(0.4), { TextTransparency = 1 }):Play()
		task.wait(0.4)
		if token == wipeToken then
			wipeOverlay.Visible = false
		end
	end)
end

local function updateCombo(combo: number)
	if combo >= 2 then
		comboLabel.Text = string.format("FLOW  x%d", combo)
		comboLabel.TextColor3 = combo >= 5 and MAGENTA or GREEN
	else
		comboLabel.Text = ""
	end
end

local knownLevel = 1

local function updateTejas(tejas: number)
	local maxTejas = Progression.maxTejasForLevel(knownLevel)
	local pct = math.clamp(tejas / maxTejas, 0, 1)
	TweenService:Create(tejasFill, TweenInfo.new(0.2), { Size = UDim2.new(pct, 0, 1, 0) }):Play()
	tejasLabel.Text = string.format("Tejas %d / %d", math.floor(tejas + 0.5), maxTejas)
end

local function updateProgress(level: number, xpInto: number, xpForNext: number, isMax: boolean)
	knownLevel = level
	local pct = if isMax then 1 elseif xpForNext > 0 then math.clamp(xpInto / xpForNext, 0, 1) else 0
	TweenService:Create(xpFill, TweenInfo.new(0.25), { Size = UDim2.new(pct, 0, 1, 0) }):Play()
	if isMax then
		local _, maxRank = Ranks.rankFor(level)
		levelLabel.Text = string.format("Lv %d · %s  (MAX)", level, maxRank.name)
	else
		local _, curRank = Ranks.rankFor(level)
		levelLabel.Text = string.format("Lv %d · %s    %d / %d XP", level, curRank.name, math.floor(xpInto), math.floor(xpForNext))
	end
end

Net.CombatFeedback.OnClientEvent:Connect(function(data: any)
	if typeof(data) ~= "table" then
		return
	end

	if data.tejas ~= nil then
		updateTejas(data.tejas)
	end

	-- Loot pickups.
	if data.goldUpdate then
		goldLabel.Text = string.format("◈ %d gold", data.gold)
		if data.gained and data.gained > 0 then
			showToast(string.format("+%d gold", data.gained), Color3.fromRGB(255, 200, 40))
		end
		return
	end
	if data.amrit then
		showToast(string.format("Amrit!  +%d HP", data.heal), Color3.fromRGB(90, 255, 140))
		return
	end
	if data.questComplete then
		local reward = if data.rewardGold and data.rewardGold > 0
			then string.format("+%d gold", data.rewardGold)
			else string.format("+%d XP", data.rewardXp or 0)
		showToast(string.format("QUEST COMPLETE:  %s  (%s)", tostring(data.title), reward), GREEN)
		return
	end
	if data.dailyComplete then
		local bits = {}
		if data.rewardGold and data.rewardGold > 0 then
			table.insert(bits, string.format("+%d gold", data.rewardGold))
		end
		if data.rewardShards and data.rewardShards > 0 then
			table.insert(bits, string.format("+%d ◆", data.rewardShards))
		end
		if data.rewardXp and data.rewardXp > 0 then
			table.insert(bits, string.format("+%d XP", data.rewardXp))
		end
		showToast(string.format("DAILY COMPLETE:  %s  (%s)", tostring(data.title), table.concat(bits, "  ")), YELLOW)
		return
	end
	if data.dailyReset then
		showToast("A new day — fresh daily trials await", Color3.fromRGB(150, 120, 255))
		return
	end
	if data.shopBought then
		showToast(string.format("%s  →  Tier %d", tostring(data.itemName), data.tier), Color3.fromRGB(255, 200, 40))
		return
	end
	if data.milestone then
		showToast(
			string.format("WAVE %d MILESTONE!   « %s »   +%d gold", data.wave, tostring(data.title), data.gold),
			YELLOW
		)
		return
	end
	if data.weaponChosen then
		showToast(string.format("You take up the %s — %s!", tostring(data.name), tostring(data.title)), YELLOW)
		return
	end
	if data.pathChosen then
		local pathColor = if typeof(data.color) == "table"
			then Color3.fromRGB(data.color[1], data.color[2], data.color[3])
			else YELLOW
		showToast(string.format("You walk the %s — %s!", tostring(data.name), tostring(data.epithet)), pathColor)
		return
	end
	if data.pathDenied then
		local why = if data.reason == "gold" then "Not enough gold to change paths" else "The path refuses you"
		showToast(why, Color3.fromRGB(200, 120, 120))
		return
	end
	if data.relicDrop then
		if data.dupe then
			showToast(string.format("%s dissolves into gold  (+%d)", tostring(data.name), data.gold), YELLOW)
		else
			local rarityColor = if typeof(data.color) == "table"
				then Color3.fromRGB(data.color[1], data.color[2], data.color[3])
				else YELLOW
			showToast(string.format("RELIC:  %s!   (I to equip)", tostring(data.name)), rarityColor)
		end
		return
	end
	-- The Ten-Headed King.
	if data.headFall then
		showToast(
			string.format("%s — %s — IS SEVERED   (%d heads remain)", string.upper(tostring(data.headName)), string.upper(tostring(data.vice)), data.remaining),
			Color3.fromRGB(255, 200, 60)
		)
		return
	end
	if data.raidEnrage then
		showToast("ONLY THE EGO REMAINS — RAVANA ENRAGES", RED)
		return
	end
	if data.raidVictory then
		showToast(tostring(data.message), YELLOW)
		return
	end
	-- Agastya's story.
	if data.storyChapter then
		showToast(
			string.format("ADHYAYA %s COMPLETE — %s   (+%d gold, +%d XP)", tostring(data.numeral), tostring(data.title), data.gold, data.xp),
			Color3.fromRGB(230, 200, 140)
		)
		return
	end
	if data.storyCatchup then
		showToast(
			string.format("Your legend already speaks — Adhyaya %s   (+%d gold, +%d XP)", tostring(data.numeral), data.gold, data.xp),
			Color3.fromRGB(230, 200, 140)
		)
		return
	end
	-- Honor duels.
	if data.pvp then
		local PINK = Color3.fromRGB(255, 110, 140)
		if data.pvp == "sent" then
			showToast(string.format("Challenge sent to %s", tostring(data.toName)), PINK)
		elseif data.pvp == "declined" then
			showToast(string.format("%s declined your challenge", tostring(data.byName)), Color3.fromRGB(170, 170, 170))
		elseif data.pvp == "expired" then
			showToast(string.format("Your challenge to %s expired", tostring(data.toName)), Color3.fromRGB(170, 170, 170))
		elseif data.pvp == "denied" then
			local why = if data.reason == "targetBusy" then "They're already spoken for" else "You're already spoken for"
			showToast(why, Color3.fromRGB(200, 120, 120))
		elseif data.pvp == "countdown" then
			showToast(string.format("DUEL BEGINS IN %d…", data.n), PINK)
		elseif data.pvp == "begin" then
			showToast(string.format("⚔  FIGHT!  %s awaits your blade", tostring(data.foeName)), PINK)
		elseif data.pvp == "won" then
			showToast(string.format("VICTORY!  You bested %s", tostring(data.foeName)), YELLOW)
		elseif data.pvp == "lost" then
			showToast(string.format("Defeated by %s — honor them", tostring(data.foeName)), RED)
		elseif data.pvp == "draw" then
			showToast("The duel ends in a draw", Color3.fromRGB(170, 170, 170))
		elseif data.pvp == "announce" then
			showToast(string.format("⚔  %s has bested %s in a duel!", tostring(data.winner), tostring(data.loser)), PINK)
		end
		return
	end

	if data.titleEquipped then
		if data.name ~= "" then
			showToast(string.format("You now bear the title  « %s »", tostring(data.name)), YELLOW)
		else
			showToast("Title removed", Color3.fromRGB(170, 170, 170))
		end
		return
	end

	-- Vajra Shards (boss-kill mantra currency).
	if data.shardUpdate then
		showToast(string.format("◆ +%d Vajra Shard%s", data.gained, if data.gained == 1 then "" else "s"), Color3.fromRGB(150, 120, 255))
		return
	end

	-- Mantra inscriptions: mythics get the full fireworks.
	if data.enchantResult then
		if data.mythic then
			showToast(string.format("✦ MYTHIC ✦   %s", tostring(data.name)), Color3.fromRGB(255, 170, 50))
		else
			showToast(string.format("Inscribed:  %s", tostring(data.name)), Color3.fromRGB(150, 120, 255))
		end
		return
	end
	if data.altarDenied then
		if data.reason == "shards" then
			showToast("Not enough Vajra Shards — slay bosses", Color3.fromRGB(200, 120, 120))
		elseif data.reason == "noweapon" then
			showToast("Choose a weapon first", Color3.fromRGB(200, 120, 120))
		end
		return
	end
	if data.shopDenied then
		if data.reason == "gold" then
			showToast("Not enough gold", Color3.fromRGB(200, 120, 120))
		elseif data.reason == "max" then
			showToast("Already at max tier", Color3.fromRGB(170, 170, 170))
		end
		return
	end

	-- Progression updates.
	if data.progress then
		updateProgress(data.level, data.xpIntoLevel, data.xpForNext, data.isMax == true)
		return
	end
	if data.levelUp then
		showToast(string.format("LEVEL UP!   Lv %d", data.level), YELLOW)
		return
	end
	if data.outcome == "AbilityLocked" then
		showToast(string.format("%s unlocks at Lv %s", tostring(data.ability), tostring(data.unlockLevel)), Color3.fromRGB(170, 170, 170))
		return
	end

	-- Zone transitions.
	if data.zoneChange then
		showToast(string.format("— %s —", tostring(data.name)), Color3.fromRGB(170, 255, 190))
		return
	end

	-- You personally fell (in co-op, teammates may still stand).
	if data.youFell then
		showToast(Bhoota.Lines.fell, Color3.fromRGB(200, 190, 230))
		return
	end
	if data.bhoota then
		hideDowned()
		bhootaFrame.Visible = true
		showToast(Bhoota.Lines.ghostToast, Color3.fromRGB(170, 210, 255))
		return
	end
	if data.punarjanma then
		bhootaFrame.Visible = false
		showToast(Bhoota.Lines.reborn, Color3.fromRGB(130, 255, 180))
		return
	end
	if data.agnihotra then
		local bits = string.format("+%d gold", data.gold)
		if data.shards and data.shards > 0 then
			bits ..= string.format("  +%d ◆", data.shards)
		end
		showToast(string.format("AGNIHOTRA — day %d of devotion   (%s)", data.day, bits), SAFFRON)
		return
	end
	if data.vrataKept then
		showToast(string.format("THE VOW IS KEPT — %s  (+%d gold, +%d ◆)", tostring(data.name), data.gold, data.shards), Color3.fromRGB(200, 110, 255))
		return
	end
	if data.vrataReset then
		showToast(string.format("A new week — the world swears the %s", tostring(data.name)), Color3.fromRGB(200, 110, 255))
		return
	end
	if data.perfectParry then
		showToast("PERFECT PARRY — RIPOSTE!", CYAN)
		return
	end
	if data.dhyanaEnter then
		showToast("DHYANA — the grove holds you. Jump to rise.", Color3.fromRGB(200, 220, 255))
		return
	end
	if data.dhyanaTick then
		local sangha = if (data.friends or 0) > 0 then string.format("  ·  sangha ×%d", data.friends) else ""
		local shard = if (data.shards or 0) > 0 then "  ·  +1 ◆" else ""
		showToast(string.format("Dhyana — minute %d  (+%d gold%s%s)", data.minutes, data.gold, sangha, shard), Color3.fromRGB(200, 220, 255))
		return
	end
	if data.dhyanaExit then
		showToast(string.format("You rise — %d minutes of stillness kept.", data.minutes or 0), Color3.fromRGB(200, 220, 255))
		return
	end
	if data.yajnaLit then
		showToast(string.format("%s feeds the flame:  %s", tostring(data.byName), tostring(data.line)), SAFFRON)
		return
	end
	if data.yajnaExtinguished then
		showToast("The sacred fire goes out with the line…", Color3.fromRGB(170, 170, 170))
		return
	end
	if data.oathSworn then
		showToast(string.format("%s swears the %s!  %s", tostring(data.byName), tostring(data.name), tostring(data.line)), RED)
		return
	end
	if data.oathBegins then
		showToast(string.format("THE %s BINDS THIS WAVE", string.upper(tostring(data.name))), RED)
		return
	end
	if data.oathBounty then
		showToast(string.format("The oath is kept:  +%d gold  +%d XP", data.gold, data.xp), YELLOW)
		return
	end
	if data.ritesDenied then
		local why = if data.reason == "gold" then "The flame refuses an empty hand"
			elseif data.reason == "lit" then "That flame already burns"
			elseif data.reason == "battle" then "Oaths are sworn between waves, not during"
			elseif data.reason == "sworn" then "An oath already binds the next wave"
			else "The rite refuses you"
		showToast(why, Color3.fromRGB(200, 120, 120))
		return
	end
	if data.reaction then
		showToast(string.format("%s!   +%d", tostring(data.name), data.damage or 0), MAGENTA)
		return
	end
	if data.weaponLocked then
		showToast(string.format("%s is not yet earned — %s", tostring(data.name), tostring(data.label)), Color3.fromRGB(200, 120, 120))
		return
	end
	if data.varaPicked then
		showToast(string.format("VARA:  %s — %s   (%d held)", tostring(data.name), tostring(data.line), data.held or 0), Color3.fromRGB(130, 255, 180))
		return
	end
	if data.varaScattered then
		showToast("The boons scatter with the broken line…", Color3.fromRGB(170, 170, 170))
		return
	end
	if data.rankUp then
		showToast(string.format("VARNA ASCENDED —  %s, %s", tostring(data.name), tostring(data.line)), YELLOW)
		return
	end
	if data.tutorialDone then
		showToast(string.format("THE FIRST LESSON IS LEARNED   (+%d gold)", data.gold or 0), YELLOW)
		return
	end
	if data.vira then
		showToast(string.format("%s!   %d-kill streak  (+Tejas)", tostring(data.name), data.count), MAGENTA)
		return
	end
	if data.waveGrade then
		local c = if typeof(data.gradeColor) == "table"
			then Color3.fromRGB(data.gradeColor[1], data.gradeColor[2], data.gradeColor[3])
			else YELLOW
		showToast(string.format("RANK %s   (%d slain · %d parried)", tostring(data.waveGrade), data.kills or 0, data.parries or 0), c)
		return
	end
	if data.dosha then
		showToast(string.format("%s — %s", tostring(data.name), tostring(data.announce)), Color3.fromRGB(190, 120, 255))
		return
	end
	if data.doshaBounty then
		showToast(string.format("The dosha lifts:  +%d gold  +%d XP", data.gold, data.xp), Color3.fromRGB(190, 120, 255))
		return
	end
	if data.bazaarGranted then
		local what = if data.kind == "gold" then string.format("◈ %d gold", data.amount) else string.format("◆ %d shards", data.amount)
		showToast(string.format("The Bazaar delivers:  %s — %s", tostring(data.name), what), YELLOW)
		return
	end
	if data.downed then
		showDowned(tonumber(data.seconds) or 20)
		return
	end
	if data.revived then
		hideDowned()
		if data.byName then
			showToast(string.format("%s lifted you — fight on!", tostring(data.byName)), Color3.fromRGB(130, 255, 180))
		else
			showToast("You rise — the nectar holds you up!", Color3.fromRGB(130, 255, 180))
		end
		return
	end
	if data.allyDown then
		showToast(string.format("%s IS DOWN — get to them!", tostring(data.name)), RED)
		return
	end
	if data.liftedAlly then
		showToast(string.format("You lifted %s — Uddhāra!", tostring(data.name)), Color3.fromRGB(130, 255, 180))
		return
	end
	if data.masteryUp then
		showToast(string.format("MASTERY — %s reaches Lv %d", tostring(data.pathName), data.level), CYAN)
		return
	end
	if data.siddhiUnlocked then
		showToast(string.format("SIDDHI UNLOCKED:  %s — %s", tostring(data.name), tostring(data.line)), YELLOW)
		return
	end
	if data.utsava then
		if data.utsava == "begin" then
			showToast(string.format("UTSAVA!  %s", tostring(data.announce)), YELLOW)
		elseif data.utsava == "deerSlain" then
			showToast(string.format("%s felled the golden deer!  (+%d gold, +%d ◆)", tostring(data.byName), data.gold, data.shards), YELLOW)
		elseif data.utsava == "deerFled" then
			showToast("The golden illusion laughs — and fades.", Color3.fromRGB(170, 170, 170))
		elseif data.utsava == "merchantSold" then
			showToast(string.format("The vaidya bows — %d ◆ for %d gold.", data.shards, data.price), YELLOW)
		elseif data.utsava == "merchantDenied" then
			local why = if data.reason == "served" then "The vaidya has already served you" else "The vaidya eyes your empty purse"
			showToast(why, Color3.fromRGB(200, 120, 120))
		elseif data.utsava == "merchantLeft" then
			showToast("The vaidya rolls up his mat and walks on.", Color3.fromRGB(170, 170, 170))
		elseif data.utsava == "rishiBlessed" then
			showToast(string.format("The rishi touches your brow — cleansed, +%d XP", data.xp or 0), Color3.fromRGB(255, 240, 190))
		elseif data.utsava == "rishiGone" then
			showToast("The rishi walks on, needing nothing.", Color3.fromRGB(170, 170, 170))
		elseif data.utsava == "peddlerSold" then
			if data.cursed then
				showToast(string.format("%d ◆ for %d gold… and the peddler LAUGHS. Cursed!", data.shards, data.price), Color3.fromRGB(200, 110, 255))
			else
				showToast(string.format("%d ◆ for %d gold — a clean deal, somehow.", data.shards, data.price), Color3.fromRGB(200, 110, 255))
			end
		end
		return
	end

	-- Afflictions the horde puts on you.
	if data.statusEffect == "venom" then
		showToast(string.format("VENOM!  poisoned for %ds", data.seconds or 0), Color3.fromRGB(110, 255, 110))
		return
	end
	if data.statusEffect == "curse" then
		showToast(string.format("CURSED — healing halved for %ds", data.seconds or 0), Color3.fromRGB(190, 110, 255))
		return
	end

	-- Wave director updates.
	if data.waveState then
		local ORANGE = Color3.fromRGB(255, 180, 90)
		if data.waveState == "start" then
			waveLabel.Text = string.format("WAVE %d    —    %d enemies", data.wave, data.enemiesLeft)
			showToast(string.format("WAVE %d", data.wave), ORANGE)
		elseif data.waveState == "progress" then
			waveLabel.Text = string.format("WAVE %d    —    %d left", data.wave, data.enemiesLeft)
		elseif data.waveState == "clear" then
			waveLabel.Text = string.format("WAVE %d CLEARED", data.wave)
			showToast(string.format("WAVE %d CLEARED!    +%d XP", data.wave, data.bonusXp), YELLOW)
		elseif data.waveState == "boss" then
			waveLabel.Text = string.format("WAVE %d   —   BOSS", data.wave)
		elseif data.waveState == "wipe" then
			waveLabel.Text = string.format("WAVE %d LOST", data.failedWave)
			showWipe(data.failedWave, data.restartWave, data.delay or 6)
		end
		return
	end

	-- Boss speech lines.
	if data.bossLine then
		showSpeech(tostring(data.speaker), tostring(data.text))
		return
	end

	-- Boss health bar.
	if data.bossState then
		if data.bossState == "spawn" then
			bossFrame.Visible = true
			bossName.Text = string.format("%s  —  %s", tostring(data.bossName), tostring(data.bossTitle))
			local pct = if data.bossMaxHealth and data.bossMaxHealth > 0
				then math.clamp((data.bossHealth or data.bossMaxHealth) / data.bossMaxHealth, 0, 1)
				else 1
			bossBarFill.Size = UDim2.fromScale(pct, 1)
			showToast(string.format("BOSS:  %s", tostring(data.bossName)), Color3.fromRGB(255, 90, 80))
		elseif data.bossState == "health" then
			local pct = if data.bossMaxHealth > 0 then math.clamp(data.bossHealth / data.bossMaxHealth, 0, 1) else 0
			TweenService:Create(bossBarFill, TweenInfo.new(0.15), { Size = UDim2.fromScale(pct, 1) }):Play()
		elseif data.bossState == "defeated" then
			bossFrame.Visible = false
			showToast(string.format("%s  DEFEATED!", tostring(data.bossName)), YELLOW)
		elseif data.bossState == "passed" then
			-- The trial's ending: he was never going to fall.
			bossFrame.Visible = false
			showToast(tostring(data.message or "THE TRIAL IS PASSED"), Color3.fromRGB(255, 220, 130))
		end
		return
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
		-- Our own offense / abilities.
		if data.combo ~= nil then
			updateCombo(data.combo)
		end
		if data.outcome == "NoTejas" then
			showToast("Not enough Tejas", MAGENTA)
		elseif data.outcome == "AbilityCooldown" then
			showToast(tostring(data.abilityName) .. " — recharging", Color3.fromRGB(170, 170, 170))
		elseif data.outcome == "AbilityCast" then
			if data.ability == "V" then
				showToast(string.format("INDRA'S WRATH!   %d struck", data.struck or 0), Color3.fromRGB(180, 220, 255))
			else
				showToast(string.upper(tostring(data.abilityName)) .. "!", SAFFRON)
			end
		elseif data.outcome == "Hit" and data.executed then
			showToast("YAMA'S LEDGER CLOSES", Color3.fromRGB(200, 60, 255))
		elseif data.outcome == "Hit" and data.isCrit then
			showToast(string.format("CRIT!   %d", math.floor((data.damage or 0) + 0.5)), Color3.fromRGB(255, 120, 40))
		elseif data.outcome == "Hit" and data.isFinisher then
			showToast("FINISHER!", MAGENTA)
		elseif data.outcome == "Hit" and data.combo and data.combo >= 5 then
			showToast(string.format("FLOW x%d!", data.combo), MAGENTA)
		end
	end
end)

print("[Dharma] HUD ready.")
