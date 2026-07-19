--!strict
-- Persistence: loads a player's progress on join, saves on leave / autosave / shutdown.
-- Retries with backoff, and never saves over real progress after a failed load.
-- (DataStores only work in published games or Studio with "API Services" enabled;
--  on failure it degrades gracefully — the player just starts fresh and nothing saves.)

local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local PlayerData = require(ReplicatedStorage.Shared.PlayerData)
local Streak = require(ReplicatedStorage.Shared.Streak)
local Loot = require(ReplicatedStorage.Shared.Loot)
local Net = require(ReplicatedStorage.Shared.Net)
local PlayerRegistry = require(script.Parent.PlayerRegistry)
local ProgressionService = require(script.Parent.ProgressionService)
local QuestService = require(script.Parent.QuestService)
local StoryService = require(script.Parent.StoryService)
local TutorialService = require(script.Parent.TutorialService)
local VrataService = require(script.Parent.VrataService)

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
	state.gold = data.gold
	state.upgrades = { damage = data.upgrades.damage, health = data.upgrades.health }
	state.weapon = { id = data.weapon.id, tier = data.weapon.tier }
	state.shards = data.shards
	state.enchant = data.enchant
	state.stats = {
		kills = data.stats.kills,
		bossKills = data.stats.bossKills,
		deaths = data.stats.deaths,
		playtimeSeconds = data.stats.playtimeSeconds,
		trialsPassed = data.stats.trialsPassed,
		duelWins = data.stats.duelWins,
		raidClears = data.stats.raidClears,
		revives = data.stats.revives,
		deerKills = data.stats.deerKills,
	}
	state.title = data.title
	state.path = data.path
	state.relics = data.relics
	state.storyChapter = data.story
	state.mastery = { agni = data.mastery.agni, vayu = data.mastery.vayu, varuna = data.mastery.varuna, indra = data.mastery.indra }
	state.streak = { stamp = data.streak.stamp, count = data.streak.count }
	state.tutorialDone = data.tutorialDone
	state.vibhuti = { tilak = data.vibhuti.tilak, aura = data.vibhuti.aura }
	state.vrata2 = { stamp = data.vrata.stamp, progress = data.vrata.progress, kept = data.vrata.kept }
	state.weeklyBest = { stamp = data.weekly.stamp, wave = data.weekly.wave }
	state.kirtiClaims = data.kirti
	state.loadouts = data.loadouts
	state.gana = data.gana
	state.yatra = data.yatra
	state.granthaKills = data.granthaKills
	state.granthaClaims = data.granthaClaims
	state.shastra = data.shastra
	state.playtimeMark = os.clock() -- playtime accrues from the moment the save lands
	state.bestWave = data.bestWave
	state.quests = data.quests
	state.dailies = data.dailies
	state.dataLoaded = ok
	state.dataReady = true -- load resolved (success or fail); the weapon hook may proceed

	if not ok then
		warn("[Dharma] Load failed for " .. player.Name .. " — will NOT save (protecting progress).")
	end

	-- Reflect the loaded level immediately (stats + HUD), show the saved gold,
	-- and stand up the quest board (fills empty slots + syncs the panel).
	ProgressionService.onCharacterSpawn(player)
	Net.CombatFeedback:FireClient(player, { goldUpdate = true, gained = 0, gold = state.gold })
	QuestService.ensureFilled(player)
	QuestService.ensureDailies(player)

	-- Agnihotra: the daily offering, granted once per UTC day (only on real loads —
	-- a failed load never mints rewards it can't keep).
	if ok then
		local today = Streak.dayStamp(os.time())
		local advance = Streak.advance(state.streak.stamp, state.streak.count, today)
		state.streak.stamp = today
		state.streak.count = advance.count
		if advance.claimed then
			local offering = Streak.rewardFor(advance.count)
			state.gold = Loot.clampGold(state.gold + offering.gold)
			state.shards += offering.shards
			Net.CombatFeedback:FireClient(player, { goldUpdate = true, gained = 0, gold = state.gold })
			if offering.shards > 0 then
				Net.CombatFeedback:FireClient(player, { shardUpdate = true, gained = offering.shards, shards = state.shards })
			end
			Net.CombatFeedback:FireClient(player, {
				agnihotra = true,
				day = advance.count,
				gold = offering.gold,
				shards = offering.shards,
			})
		end
	end
	StoryService.ensure(player)
	TutorialService.ensure(player)
	VrataService.ensure(player)
end

local function savePlayer(player: Player)
	local state = PlayerRegistry.tryGet(player)
	if not state or not state.dataLoaded then
		return -- never write when we didn't successfully load
	end
	local xp = state.totalXp
	local gold = state.gold
	local upgrades = { damage = state.upgrades.damage, health = state.upgrades.health }
	local bestWave = state.bestWave
	local quests = state.quests
	local weapon = { id = state.weapon.id, tier = state.weapon.tier }
	local shards = state.shards
	local enchant = state.enchant

	-- Bank playtime since the last save into the lifetime total.
	local now = os.clock()
	state.stats.playtimeSeconds += math.max(0, math.floor(now - state.playtimeMark))
	state.playtimeMark = now
	local stats = {
		kills = state.stats.kills,
		bossKills = state.stats.bossKills,
		deaths = state.stats.deaths,
		playtimeSeconds = state.stats.playtimeSeconds,
		trialsPassed = state.stats.trialsPassed,
		duelWins = state.stats.duelWins,
		raidClears = state.stats.raidClears,
		revives = state.stats.revives,
		deerKills = state.stats.deerKills,
	}
	local dailies = state.dailies
	local titleId = state.title
	local pathId = state.path
	local relics = state.relics
	local story = state.storyChapter
	local mastery = { agni = state.mastery.agni, vayu = state.mastery.vayu, varuna = state.mastery.varuna, indra = state.mastery.indra }
	local streak = { stamp = state.streak.stamp, count = state.streak.count }
	local tutorialDone = state.tutorialDone
	local vibhuti = { tilak = state.vibhuti.tilak, aura = state.vibhuti.aura }
	local vrataSave = { stamp = state.vrata2.stamp, progress = state.vrata2.progress, kept = state.vrata2.kept }
	local weeklySave = { stamp = state.weeklyBest.stamp, wave = state.weeklyBest.wave }
	local kirtiSave = state.kirtiClaims
	local loadoutSave = state.loadouts
	local ganaSave = state.gana
	local yatraSave = state.yatra
	local granthaKillsSave = state.granthaKills
	local granthaClaimsSave = state.granthaClaims
	local shastraSave = state.shastra

	retry(function()
		return store:UpdateAsync(keyFor(player), function(old: any)
			local payload = PlayerData.serialize(xp, gold, upgrades, bestWave, quests, weapon, shards, enchant, stats, dailies, titleId, pathId, relics, story, mastery, streak, tutorialDone, vibhuti, vrataSave, weeklySave, kirtiSave, loadoutSave, ganaSave, yatraSave, granthaKillsSave, granthaClaimsSave, shastraSave)
			-- Never roll back XP or bestWave: keep whichever is higher.
			-- (Gold is NOT anti-rollbacked — the shop legitimately spends it.)
			if type(old) == "table" then
				if type(old.totalXp) == "number" and old.totalXp > payload.totalXp then
					payload.totalXp = old.totalXp
				end
				if type(old.bestWave) == "number" and old.bestWave > payload.bestWave then
					payload.bestWave = old.bestWave
				end
				-- Mastery never decreases: keep the higher ledger per path.
				if type(old.mastery) == "table" then
					for _, pathId in { "agni", "vayu", "varuna", "indra" } do
						local prev = old.mastery[pathId]
						if type(prev) == "number" and prev > (payload.mastery :: any)[pathId] then
							(payload.mastery :: any)[pathId] = math.floor(prev)
						end
					end
				end
				-- The story never un-tells itself.
				if type(old.story) == "number" and old.story > payload.story then
					payload.story = old.story
				end
				-- Never lose a sworn Astra Path to a stale write.
				if payload.path == "" and type(old.path) == "string" and old.path ~= "" then
					payload.path = old.path
				end
				-- Nor a relic satchel (relics are never legitimately discarded).
				if #payload.relics.owned == 0 and type(old.relics) == "table" and type(old.relics.owned) == "table" and #old.relics.owned > 0 then
					payload.relics = old.relics
				end
				-- Never lose a chosen weapon or a bought upgrade tier to a stale write.
				if type(old.weapon) == "table" then
					if payload.weapon.id == "" and type(old.weapon.id) == "string" and old.weapon.id ~= "" then
						payload.weapon.id = old.weapon.id
						payload.weapon.tier = math.max(payload.weapon.tier, tonumber(old.weapon.tier) or payload.weapon.tier)
					elseif payload.weapon.id == old.weapon.id and type(old.weapon.tier) == "number" and old.weapon.tier > payload.weapon.tier then
						payload.weapon.tier = old.weapon.tier
					end
				end
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
