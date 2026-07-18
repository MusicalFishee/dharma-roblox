--!strict
-- YatraService: the free pilgrimage road. Claims recompute what is owed from
-- the REAL level and the stored sequential count — the panel is a window,
-- never a wallet.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Net = require(ReplicatedStorage.Shared.Net)
local Yatra = require(ReplicatedStorage.Shared.Yatra)
local Progression = require(ReplicatedStorage.Shared.Progression)
local Loot = require(ReplicatedStorage.Shared.Loot)
local PlayerRegistry = require(script.Parent.PlayerRegistry)

local YatraService = {}

local function snapshot(player: Player)
	local state = PlayerRegistry.get(player)
	local level = Progression.resolve(state.totalXp).level
	local owed = Yatra.owedFor(level, state.yatra)
	Net.CombatFeedback:FireClient(player, {
		yatraInfo = true,
		level = level,
		claimed = state.yatra,
		total = #Yatra.Milestones,
		owedCount = owed.count,
		owedGold = owed.gold,
		owedShards = owed.shards,
	})
end

Net.YatraRequest.OnServerEvent:Connect(function(player: Player, data: any)
	if typeof(data) ~= "table" then
		return
	end
	local state = PlayerRegistry.get(player)
	if not state.dataReady then
		return
	end

	if data.action == "info" then
		snapshot(player)
		return
	end

	if data.action == "claim" then
		local level = Progression.resolve(state.totalXp).level
		local owed = Yatra.owedFor(level, state.yatra)
		if owed.count == 0 then
			snapshot(player)
			return
		end
		state.yatra = math.clamp(state.yatra + owed.count, 0, #Yatra.Milestones)
		state.gold = Loot.clampGold(state.gold + owed.gold)
		state.shards += owed.shards
		Net.CombatFeedback:FireClient(player, { goldUpdate = true, gained = owed.gold, gold = state.gold })
		if owed.shards > 0 then
			Net.CombatFeedback:FireClient(player, { shardUpdate = true, gained = owed.shards, shards = state.shards })
		end
		Net.CombatFeedback:FireClient(player, { yatraClaimed = true, count = owed.count, gold = owed.gold, shards = owed.shards })
		snapshot(player)
	end
end)

print("[Dharma] YatraService ready — the road pays its walkers (F).")

return YatraService
