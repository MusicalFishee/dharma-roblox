--!strict
-- VairiService: keeps every player's grudge ledger and springs the hunts.
-- The downing blow marks the vairi (EnemyService calls onBested); ordinary
-- waves roll the stalk; only the hunted's own hand pays the debt.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local Net = require(ReplicatedStorage.Shared.Net)
local Vairi = require(ReplicatedStorage.Shared.Vairi)
local EnemyTypes = require(ReplicatedStorage.Shared.EnemyTypes)
local Loot = require(ReplicatedStorage.Shared.Loot)
local PlayerRegistry = require(script.Parent.PlayerRegistry)

local VairiService = {}

-- The blow that bests you writes the grudge. Lords are never grudge-peers.
function VairiService.onBested(player: Player, archetype: any)
	if archetype.isBoss then
		return
	end
	local state = PlayerRegistry.tryGet(player)
	if not state or not state.dataReady then
		return
	end
	local baseId = tostring(archetype.id)
	if state.vairi.id == baseId then
		if state.vairi.count < Vairi.Config.MaxCount then
			state.vairi = { id = baseId, count = state.vairi.count + 1 }
		end
		Net.CombatFeedback:FireClient(player, { vairiGrown = true, name = tostring(archetype.displayName), count = state.vairi.count })
	else
		state.vairi = { id = baseId, count = 1 }
		Net.CombatFeedback:FireClient(player, { vairiMarked = true, name = tostring(archetype.displayName) })
	end
end

-- An ordinary wave begins: held grudges may come hunting.
function VairiService.stalk(wave: number)
	-- Lazy require: EnemyService requires us for onBested; the cycle only
	-- exists at load time, and by the first stalk everyone is long loaded.
	local EnemyService = require(script.Parent.EnemyService) :: any

	for _, player in Players:GetPlayers() do
		local state = PlayerRegistry.tryGet(player)
		if not state or not state.dataReady or #state.vairi.id == 0 then
			continue
		end
		local char = player.Character
		local hum = char and char:FindFirstChildOfClass("Humanoid")
		local root = char and char:FindFirstChild("HumanoidRootPart")
		if not char or not hum or not root or not root:IsA("BasePart") or hum.Health <= 0 then
			continue
		end
		if char:GetAttribute("DharmaDowned") == true or char:GetAttribute("DharmaBhoota") == true or char:GetAttribute("DharmaDhyana") == true then
			continue
		end
		if math.random() >= Vairi.Config.Chance then
			continue
		end

		local count = state.vairi.count
		local grudge = Vairi.of(EnemyTypes.get(state.vairi.id), count, player.DisplayName)
		local hunted = player
		local pos = root.Position + Vector3.new((math.random() - 0.5) * 40, 6, (math.random() - 0.5) * 40)
		Net.CombatFeedback:FireClient(player, { vairiStalks = true, name = grudge.displayName })

		EnemyService.spawn(grudge, pos, function(killer: Player?)
			local hstate = PlayerRegistry.tryGet(hunted)
			if killer == hunted and hstate then
				-- The debt is paid — by the one hand that could pay it.
				local bounty = Vairi.bountyFor(count)
				hstate.vairi = { id = "", count = 0 }
				hstate.gold = Loot.clampGold(hstate.gold + bounty.gold)
				hstate.shards += bounty.shards
				Net.CombatFeedback:FireClient(hunted, { goldUpdate = true, gained = bounty.gold, gold = hstate.gold })
				Net.CombatFeedback:FireClient(hunted, { shardUpdate = true, gained = bounty.shards, shards = hstate.shards })
				Net.CombatFeedback:FireClient(hunted, { vairiFelled = true, gold = bounty.gold, shards = bounty.shards })
			elseif hunted.Parent then
				Net.CombatFeedback:FireClient(hunted, { vairiStolen = true })
			end
		end)
	end
end

print("[Dharma] VairiService ready — the dark keeps its ledgers.")

return VairiService
