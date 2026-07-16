--!strict
-- Titles, server-side: validates equips against earned deeds, floats the equipped
-- title over the wearer's head (server-built billboard, visible to all), and mirrors
-- it into replicated Player attributes so every client can tag chat messages.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local Net = require(ReplicatedStorage.Shared.Net)
local Titles = require(ReplicatedStorage.Shared.Titles)
local Progression = require(ReplicatedStorage.Shared.Progression)
local PlayerRegistry = require(script.Parent.PlayerRegistry)

local TAG_NAME = "DharmaTitleTag"

local function snapshotOf(player: Player): Titles.Snapshot
	local state = PlayerRegistry.get(player)
	return {
		bestWave = state.bestWave,
		kills = state.stats.kills,
		bossKills = state.stats.bossKills,
		level = Progression.resolve(state.totalXp).level,
		trials = state.stats.trialsPassed,
		duelWins = state.stats.duelWins,
		raidClears = state.stats.raidClears,
	}
end

-- Rebuild the head billboard (and the chat attributes) from the current state.
local function render(player: Player)
	local state = PlayerRegistry.get(player)
	local def = Titles.get(state.title)

	-- Replicated attributes: every client reads these to prefix chat.
	player:SetAttribute("DharmaTitle", if def then def.name else "")
	player:SetAttribute("DharmaTitleHex", if def then Titles.colorHex(def) else "")

	local char = player.Character
	if not char then
		return
	end
	local old = char:FindFirstChild(TAG_NAME)
	if old then
		old:Destroy()
	end
	if not def then
		return
	end
	local head = char:FindFirstChild("Head")
	if not (head and head:IsA("BasePart")) then
		return
	end

	local gui = Instance.new("BillboardGui")
	gui.Name = TAG_NAME
	gui.Adornee = head
	gui.Size = UDim2.fromOffset(220, 26)
	gui.StudsOffset = Vector3.new(0, 2.1, 0)
	gui.MaxDistance = 120
	gui.Parent = char

	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.GothamBold
	label.TextSize = 16
	label.TextColor3 = Color3.fromRGB(def.color[1], def.color[2], def.color[3])
	label.TextStrokeTransparency = 0.4
	label.Text = "« " .. def.name .. " »"
	label.Parent = gui
end

local function fullList(player: Player): { [string]: any }
	local snap = snapshotOf(player)
	local state = PlayerRegistry.get(player)
	local view = {}
	for _, def in Titles.List do
		table.insert(view, {
			id = def.id,
			name = def.name,
			requirement = def.requirement,
			color = def.color,
			unlocked = Titles.isUnlocked(def, snap),
			equipped = state.title == def.id,
		})
	end
	return { titleList = true, titles = view, equipped = state.title }
end

Net.TitleRequest.OnServerEvent:Connect(function(player: Player, data: any)
	if typeof(data) ~= "table" then
		return
	end

	if data.action == "list" then
		Net.CombatFeedback:FireClient(player, fullList(player))
		return
	end

	if data.action == "equip" then
		local id = tostring(data.id)
		local state = PlayerRegistry.get(player)
		if not Titles.canEquip(id, snapshotOf(player)) then
			Net.CombatFeedback:FireClient(player, { titleDenied = true })
			Net.CombatFeedback:FireClient(player, fullList(player))
			return
		end
		state.title = id
		render(player)
		local def = Titles.get(id)
		Net.CombatFeedback:FireClient(player, {
			titleEquipped = true,
			name = if def then def.name else "",
		})
		Net.CombatFeedback:FireClient(player, fullList(player))
	end
end)

-- Wear it on every spawn (waits for the save so returning players keep their title).
local function hookPlayer(player: Player)
	player.CharacterAdded:Connect(function()
		task.spawn(function()
			local char = player.Character
			if char then
				char:WaitForChild("Head", 10)
			end
			local state = PlayerRegistry.get(player)
			local t0 = os.clock()
			while not state.dataReady and os.clock() - t0 < 8 do
				task.wait(0.1)
			end
			render(player)
		end)
	end)
	if player.Character then
		task.spawn(function()
			local state = PlayerRegistry.get(player)
			local t0 = os.clock()
			while not state.dataReady and os.clock() - t0 < 8 do
				task.wait(0.1)
			end
			render(player)
		end)
	end
end

Players.PlayerAdded:Connect(hookPlayer)
for _, p in Players:GetPlayers() do
	hookPlayer(p)
end

print("[Dharma] TitleService ready — wear your deeds.")
