--!strict
-- Titles, server-side: validates equips against earned deeds, floats the equipped
-- title over the wearer's head (server-built billboard, visible to all), and mirrors
-- it into replicated Player attributes so every client can tag chat messages.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local Net = require(ReplicatedStorage.Shared.Net)
local Titles = require(ReplicatedStorage.Shared.Titles)
local Progression = require(ReplicatedStorage.Shared.Progression)
local Shastra = require(ReplicatedStorage.Shared.Shastra)
local Grantha = require(ReplicatedStorage.Shared.Grantha)
local HeraldService = require(script.Parent.HeraldService)
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
		revives = state.stats.revives,
		deerKills = state.stats.deerKills,
		bladeMastery = (function(): number
			local best = 1
			for _, xp in state.shastra do
				best = math.max(best, Shastra.rankFor(xp))
			end
			return best
		end)(),
		loreTurned = Grantha.totalTurned(state.granthaKills),
		playtimeSeconds = state.stats.playtimeSeconds + math.max(0, math.floor(os.clock() - state.playtimeMark)),
		deaths = state.stats.deaths,
		bladesMastered = (function(): number
			local n = 0
			for _, xp in state.shastra do
				if Shastra.rankFor(xp) >= #Shastra.Ranks then
					n += 1
				end
			end
			return n
		end)(),
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
	-- The instant a warrior first qualifies for Moksha, the whole server hears.
	local mokshaDef = Titles.get("moksha")
	if mokshaDef and Titles.isUnlocked(mokshaDef, snap) then
		HeraldService.proclaim(player, "moksha")
	end
	local earned, total = Titles.earnedCount(snap)
	local view = {}
	for _, def in Titles.List do
		-- The capstone wears its progress: "Earn every other title (18 / 21)".
		local requirement = def.requirement
		if def.kind == "capstone" then
			requirement = string.format("%s  (%d / %d)", def.requirement, earned, total)
		end
		table.insert(view, {
			id = def.id,
			name = def.name,
			requirement = requirement,
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
