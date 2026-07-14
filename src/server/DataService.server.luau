--!strict
-- Persistence: loads a player's progress on join, saves on leave / autosave / shutdown.
-- Retries with backoff, and never saves over real progress after a failed load.
-- (DataStores only work in published games or Studio with "API Services" enabled;
--  on failure it degrades gracefully — the player just starts fresh and nothing saves.)

local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local PlayerData = require(ReplicatedStorage.Shared.PlayerData)
local PlayerRegistry = require(script.Parent.PlayerRegistry)
local ProgressionService = require(script.Parent.ProgressionService)

local store = DataStoreService:GetDataStore("DharmaPlayerData_v1")
local AUTOSAVE_INTERVAL = 90

local function keyFor(player: Player): string
	return "player_" .. player.UserId
end

-- Runs fn with up to `tries` attempts and capped backoff. Returns (ok, result).
local function retry(fn: () -> any, tries: number): (boolean, any)
	for i = 1, tries do
		local ok, res = pcall(fn)
		if ok then
			return true, res
		end
		warn(string.format("[Dharma] DataStore attempt %d/%d failed: %s", i, tries, tostring(res)))
		if i < tries then
			task.wait(math.min(2 ^ (i - 1), 4))
		end
	end
	return false, nil
end

local function loadPlayer(player: Player)
	local ok, raw = retry(function()
		return store:GetAsync(keyFor(player))
	end, 4)

	local data = PlayerData.validate(if ok then raw else nil)
	local state = PlayerRegistry.get(player)
	state.totalXp = data.totalXp
	state.dataLoaded = ok

	if not ok then
		warn("[Dharma] Load failed for " .. player.Name .. " — will NOT save (protecting progress).")
	end

	-- Reflect the loaded level immediately (stats + HUD).
	ProgressionService.onCharacterSpawn(player)
end

local function savePlayer(player: Player)
	local state = PlayerRegistry.tryGet(player)
	if not state or not state.dataLoaded then
		return -- never write when we didn't successfully load
	end
	local xp = state.totalXp

	retry(function()
		return store:UpdateAsync(keyFor(player), function(old: any)
			local payload = PlayerData.serialize(xp)
			-- Never roll back: if stored progress is somehow higher, keep it.
			if type(old) == "table" and type(old.totalXp) == "number" and old.totalXp > payload.totalXp then
				payload.totalXp = old.totalXp
			end
			return payload
		end)
	end, 4)
end

Players.PlayerAdded:Connect(function(player)
	task.spawn(loadPlayer, player)
end)

Players.PlayerRemoving:Connect(function(player)
	savePlayer(player) -- save first…
	PlayerRegistry.remove(player) -- …then drop the state
end)

for _, p in Players:GetPlayers() do
	task.spawn(loadPlayer, p)
end

task.spawn(function()
	while true do
		task.wait(AUTOSAVE_INTERVAL)
		for _, p in Players:GetPlayers() do
			task.spawn(savePlayer, p)
		end
	end
end)

game:BindToClose(function()
	for _, p in Players:GetPlayers() do
		task.spawn(savePlayer, p)
	end
	task.wait(3) -- give the final saves a moment to land
end)

print("[Dharma] DataService ready (persistence online).")
