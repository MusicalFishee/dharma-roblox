--!strict
-- Relics, server-side: rolls drops when bosses and elites fall, keeps the
-- satchel, and applies equips (stat math lives in the pure Relics module —
-- combat/loot services read Relics.totalBonus straight off the equipped ids).

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local Net = require(ReplicatedStorage.Shared.Net)
local Relics = require(ReplicatedStorage.Shared.Relics)
local Loot = require(ReplicatedStorage.Shared.Loot)
local PlayerRegistry = require(script.Parent.PlayerRegistry)
local ProgressionService = require(script.Parent.ProgressionService)

local RelicService = {}

local function snapshot(player: Player)
	local state = PlayerRegistry.get(player)
	Net.CombatFeedback:FireClient(player, {
		relicInfo = true,
		owned = state.relics.owned,
		equipped = state.relics.equipped,
	})
end

-- Land one rolled drop on a player: a fresh relic into the satchel, or gold
-- when it's a duplicate (or the satchel is somehow full).
local function grant(player: Player, roll: Relics.DropRoll)
	local state = PlayerRegistry.get(player)
	local def = Relics.get(roll.id)
	if not def then
		return
	end

	if roll.dupe or not Relics.canAddOwned(state.relics.owned, roll.id) then
		state.gold = Loot.clampGold(state.gold + Relics.DupeGold)
		Net.CombatFeedback:FireClient(player, { goldUpdate = true, gained = 0, gold = state.gold })
		Net.CombatFeedback:FireClient(player, {
			relicDrop = true,
			dupe = true,
			name = def.name,
			gold = Relics.DupeGold,
		})
		return
	end

	table.insert(state.relics.owned, roll.id)
	Net.CombatFeedback:FireClient(player, {
		relicDrop = true,
		name = def.name,
		rarity = def.rarity,
		color = Relics.RarityColor[def.rarity],
		mythic = def.rarity == "mythic",
	})
	snapshot(player)
end

-- A boss fell: every player in the server rolls independently.
function RelicService.onBossDefeated(bossId: string)
	local candidates = Relics.dropsFor(bossId)
	if #candidates == 0 then
		return
	end
	for _, player in Players:GetPlayers() do
		local state = PlayerRegistry.tryGet(player)
		if not state or not state.dataLoaded then
			continue -- never grant into a save we can't keep
		end
		local roll = Relics.rollDrop(candidates, state.relics.owned, Relics.BossDropChance, function()
			return math.random()
		end)
		if roll then
			grant(player, roll)
		end
	end
end

-- An elite fell: its killer alone rolls for a charm.
function RelicService.onEliteKilled(killer: Player)
	local state = PlayerRegistry.tryGet(killer)
	if not state or not state.dataLoaded then
		return
	end
	local roll = Relics.rollDrop(Relics.CharmDrops, state.relics.owned, Relics.EliteDropChance, function()
		return math.random()
	end)
	if roll then
		grant(killer, roll)
	end
end

-- The raid's guaranteed reward: one unowned Ravana piece each (gold when complete).
function RelicService.grantRaidTrophy(player: Player)
	local state = PlayerRegistry.tryGet(player)
	if not state or not state.dataLoaded then
		return
	end
	local roll = Relics.rollDrop(Relics.dropsFor("Ravana"), state.relics.owned, 1, function()
		return math.random()
	end)
	if roll then
		grant(player, roll)
	end
end

Net.RelicRequest.OnServerEvent:Connect(function(player: Player, data: any)
	if typeof(data) ~= "table" then
		return
	end
	local state = PlayerRegistry.get(player)

	if data.action == "info" then
		snapshot(player)
		return
	end

	if data.action == "equip" then
		local slot = tostring(data.slot)
		local id = tostring(data.id)
		local checkResult = Relics.tryEquip(state.relics.owned, slot, id)
		if checkResult.ok then
			(state.relics.equipped :: any)[slot] = id
			-- Health bonuses land immediately (no free heal).
			ProgressionService.refreshStats(player)
		end
		snapshot(player)
	end
end)

print("[Dharma] RelicService ready — the satchel is open.")

return RelicService
