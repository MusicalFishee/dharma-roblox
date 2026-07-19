--!strict
-- Stats page, server-side: assembles the player's full legend — level, wealth,
-- armament, and lifetime records — into one snapshot for the P-key panel.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Net = require(ReplicatedStorage.Shared.Net)
local Progression = require(ReplicatedStorage.Shared.Progression)
local Weapons = require(ReplicatedStorage.Shared.Weapons)
local Shastra = require(ReplicatedStorage.Shared.Shastra)
local Enchants = require(ReplicatedStorage.Shared.Enchants)
local PlayerRegistry = require(script.Parent.PlayerRegistry)

Net.StatsRequest.OnServerEvent:Connect(function(player: Player, data: any)
	if typeof(data) ~= "table" or data.action ~= "info" then
		return
	end
	local state = PlayerRegistry.get(player)
	local info = Progression.resolve(state.totalXp)
	local mantra = Enchants.get(state.enchant)

	-- Live playtime = banked total + time since the last bank.
	local playtime = state.stats.playtimeSeconds + math.max(0, math.floor(os.clock() - state.playtimeMark))

	Net.CombatFeedback:FireClient(player, {
		statsPage = true,
		level = info.level,
		totalXp = state.totalXp,
		gold = state.gold,
		shards = state.shards,
		weaponId = state.weapon.id,
		weaponName = Weapons.tierName(state.weapon.id, state.weapon.tier),
		weaponTier = state.weapon.tier,
		weaponMax = Weapons.MaxTier,
		hasWeapon = Weapons.isValidId(state.weapon.id),
		weaponRank = Shastra.Ranks[Shastra.rankFor(state.shastra[state.weapon.id] or 0)].name,
		mantraName = if mantra then mantra.name else nil,
		mantraRarity = if mantra then mantra.rarity else nil,
		kills = state.stats.kills,
		bossKills = state.stats.bossKills,
		deaths = state.stats.deaths,
		deerKills = state.stats.deerKills,
		trialsPassed = state.stats.trialsPassed,
		duelWins = state.stats.duelWins,
		raidClears = state.stats.raidClears,
		revives = state.stats.revives,
		bestWave = state.bestWave,
		playtimeSeconds = playtime,
	})
end)

print("[Dharma] StatsService ready — your legend is being written.")
