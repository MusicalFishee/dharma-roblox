--!strict
-- WelcomeService: the Dvarapala speaks. After a returning warrior's save
-- lands, the door-keeper reads what the war kept — the waiting grudge, the
-- gold the ledgers owe — and greets them in a few unhurried lines.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Net = require(ReplicatedStorage.Shared.Net)
local Welcome = require(ReplicatedStorage.Shared.Welcome)
local Yatra = require(ReplicatedStorage.Shared.Yatra)
local Grantha = require(ReplicatedStorage.Shared.Grantha)
local Deeds = require(ReplicatedStorage.Shared.Deeds)
local EnemyTypes = require(ReplicatedStorage.Shared.EnemyTypes)
local Progression = require(ReplicatedStorage.Shared.Progression)
local PlayerRegistry = require(script.Parent.PlayerRegistry)

local WelcomeService = {}

function WelcomeService.greet(player: Player)
	if not player.Parent then
		return
	end
	local state = PlayerRegistry.tryGet(player)
	if not state or not state.dataReady then
		return
	end

	local level = Progression.resolve(state.totalXp).level

	local vairiName: string? = nil
	if #state.vairi.id > 0 then
		vairiName = EnemyTypes.get(state.vairi.id).displayName
	end

	local kirtiOwed = 0
	local snap: Deeds.Snapshot = {
		kills = state.stats.kills,
		bossKills = state.stats.bossKills,
		bestWave = state.bestWave,
		duelWins = state.stats.duelWins,
		raidClears = state.stats.raidClears,
		revives = state.stats.revives,
		trials = state.stats.trialsPassed,
		level = level,
		playtimeSeconds = state.stats.playtimeSeconds,
		deaths = state.stats.deaths,
		deerKills = state.stats.deerKills,
	}
	for _, def in Deeds.List do
		local progress = Deeds.progress(def, snap)
		kirtiOwed += Deeds.owedFor(def, progress.value, state.kirtiClaims[def.id] or 0).gold
	end

	local granthaOwed = 0
	for _, def in Grantha.Families do
		granthaOwed += Grantha.owedFor(def, state.granthaKills[def.id] or 0, state.granthaClaims[def.id] or 0).gold
	end

	local lines = Welcome.lines({
		name = player.DisplayName,
		vairiName = vairiName,
		vairiCount = state.vairi.count,
		owedYatraGold = Yatra.owedFor(level, state.yatra).gold,
		owedKirtiGold = kirtiOwed,
		owedGranthaGold = granthaOwed,
	})
	for i, line in lines do
		task.delay((i - 1) * 2.6, function()
			if player.Parent then
				Net.CombatFeedback:FireClient(player, { welcomeLine = line })
			end
		end)
	end
end

return WelcomeService
