--!strict
-- Server-wide leaderboards: physical golden boards at the arena edge showing the
-- top 10 by level and by deepest wave, backed by OrderedDataStores.
-- (Like all DataStores: live only in a published game / Studio with API access.)

local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Leaderboard = require(ReplicatedStorage.Shared.Leaderboard)
local Vrata = require(ReplicatedStorage.Shared.Vrata)
local Progression = require(ReplicatedStorage.Shared.Progression)
local PlayerRegistry = require(script.Parent.PlayerRegistry)

local PUSH_INTERVAL = 120
local PULL_INTERVAL = 90
local BOARD_DISTANCE = 78

local SANDSTONE = Color3.fromRGB(196, 164, 110)
local GOLD = Color3.fromRGB(255, 200, 40)
local DARK = Color3.fromRGB(18, 15, 22)

-- ---------------------------------------------------------------------------
-- Physical boards
-- ---------------------------------------------------------------------------
type BoardUI = {
	def: Leaderboard.BoardDef,
	rows: { TextLabel },
}

local boards: { BoardUI } = {}

local function buildBoard(def: Leaderboard.BoardDef, index: number): BoardUI
	-- A stone slab facing the spawn, angled at the arena edge.
	local angle = math.rad(if index == 1 then -35 elseif index == 2 then 35 else 0)
	local pos = Vector3.new(math.sin(angle) * BOARD_DISTANCE, 14, -math.cos(angle) * BOARD_DISTANCE)

	local slab = Instance.new("Part")
	slab.Name = "Leaderboard_" .. def.id
	slab.Size = Vector3.new(16, 20, 2)
	slab.CFrame = CFrame.lookAt(pos, Vector3.new(0, 10, 0))
	slab.Anchored = true
	slab.Color = SANDSTONE
	slab.Material = Enum.Material.Sandstone
	slab.Parent = workspace

	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Back
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 30
	gui.Parent = slab

	local bg = Instance.new("Frame")
	bg.Size = UDim2.fromScale(1, 1)
	bg.BackgroundColor3 = DARK
	bg.BackgroundTransparency = 0.15
	bg.BorderSizePixel = 0
	bg.Parent = gui

	local title = Instance.new("TextLabel")
	title.Size = UDim2.new(1, 0, 0, 56)
	title.BackgroundTransparency = 1
	title.Font = Enum.Font.GothamBlack
	title.TextSize = 34
	title.TextColor3 = GOLD
	title.Text = def.title
	title.Parent = bg

	local rows: { TextLabel } = {}
	for i = 1, Leaderboard.TopN do
		local row = Instance.new("TextLabel")
		row.Size = UDim2.new(1, -24, 0, 44)
		row.Position = UDim2.fromOffset(12, 56 + (i - 1) * 48)
		row.BackgroundTransparency = 1
		row.Font = Enum.Font.GothamMedium
		row.TextSize = 24
		row.TextXAlignment = Enum.TextXAlignment.Left
		row.TextColor3 = if i <= 3 then GOLD else Color3.fromRGB(225, 225, 225)
		row.Text = string.format("%d.  —", i)
		row.Parent = bg
		rows[i] = row
	end

	return { def = def, rows = rows }
end

for i, def in Leaderboard.Boards do
	table.insert(boards, buildBoard(def, i))
end

-- ---------------------------------------------------------------------------
-- OrderedDataStore sync
-- ---------------------------------------------------------------------------
local nameCache: { [number]: string } = {}

local function nameFor(userId: number): string
	if nameCache[userId] then
		return nameCache[userId]
	end
	local ok, name = pcall(function()
		return Players:GetNameFromUserIdAsync(userId)
	end)
	local resolved = if ok then name else "???"
	nameCache[userId] = resolved
	return resolved
end

local function scoreFor(player: Player, boardId: string): number
	local state = PlayerRegistry.tryGet(player)
	if not state or not state.dataLoaded then
		return -1 -- unloaded data must never overwrite a real score
	end
	if boardId == "level" then
		return Progression.resolve(state.totalXp).level
	elseif boardId == "wave" then
		return state.bestWave
	elseif boardId == "weeklyWave" then
		-- A stale week's depth is last season's ghost; it scores nothing now.
		if state.weeklyBest.stamp ~= Vrata.weekStamp(os.time()) then
			return 0
		end
		return state.weeklyBest.wave
	end
	return -1
end

local function pushScores()
	for _, def in Leaderboard.Boards do
		local ok, store = pcall(function()
			return DataStoreService:GetOrderedDataStore(Leaderboard.storeNameFor(def, Vrata.weekStamp(os.time())))
		end)
		if not ok then
			continue
		end
		for _, player in Players:GetPlayers() do
			local score = scoreFor(player, def.id)
			if score > 0 then
				pcall(function()
					store:SetAsync(tostring(player.UserId), Leaderboard.sanitizeScore(score))
				end)
			end
		end
	end
end

local function pullAndDisplay()
	for _, ui in boards do
		local ok, page = pcall(function()
			local store = DataStoreService:GetOrderedDataStore(ui.def.storeName)
			return store:GetSortedAsync(false, Leaderboard.TopN):GetCurrentPage()
		end)
		if not ok or typeof(page) ~= "table" then
			continue
		end
		for i = 1, Leaderboard.TopN do
			local entry = page[i]
			if entry then
				local userId = tonumber(entry.key)
				local display = if userId then nameFor(userId) else "???"
				ui.rows[i].Text = Leaderboard.formatRow(ui.def, i, display, entry.value)
			else
				ui.rows[i].Text = string.format("%d.  —", i)
			end
		end
	end
end

-- Push on leave so a session's gains always land.
Players.PlayerRemoving:Connect(function(player)
	for _, def in Leaderboard.Boards do
		local score = scoreFor(player, def.id)
		if score > 0 then
			pcall(function()
				DataStoreService:GetOrderedDataStore(def.storeName)
					:SetAsync(tostring(player.UserId), Leaderboard.sanitizeScore(score))
			end)
		end
	end
end)

task.spawn(function()
	while true do
		task.wait(PUSH_INTERVAL)
		pushScores()
	end
end)

task.spawn(function()
	task.wait(5) -- initial display shortly after boot
	while true do
		pullAndDisplay()
		task.wait(PULL_INTERVAL)
	end
end)

print("[Dharma] LeaderboardService ready — the boards stand at the arena's edge.")
