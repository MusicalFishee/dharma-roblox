--!strict
-- The Mantra Altar, server-side: spends Vajra Shards to inscribe a random mantra onto
-- the player's weapon (replacing any previous one — the gamble is the point), then
-- rebuilds the weapon so mythic auras appear instantly.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Net = require(ReplicatedStorage.Shared.Net)
local Enchants = require(ReplicatedStorage.Shared.Enchants)
local Weapons = require(ReplicatedStorage.Shared.Weapons)
local PlayerRegistry = require(script.Parent.PlayerRegistry)
local WeaponService = require(script.Parent.WeaponService)

local function altarSnapshot(player: Player): { [string]: any }
	local state = PlayerRegistry.get(player)
	local current = Enchants.get(state.enchant)
	return {
		altar = true,
		shards = state.shards,
		cost = Enchants.Cost,
		enchant = if current
			then { id = current.id, name = current.name, desc = current.desc, rarity = current.rarity }
			else nil,
	}
end

Net.EnchantRequest.OnServerEvent:Connect(function(player: Player, data: any)
	if typeof(data) ~= "table" then
		return
	end

	if data.action == "info" then
		Net.CombatFeedback:FireClient(player, altarSnapshot(player))
		return
	end

	if data.action == "inscribe" then
		local state = PlayerRegistry.get(player)
		if not Weapons.isValidId(state.weapon.id) then
			Net.CombatFeedback:FireClient(player, { altarDenied = true, reason = "noweapon" })
			Net.CombatFeedback:FireClient(player, altarSnapshot(player))
			return
		end

		local result = Enchants.tryInscribe(state.shards)
		if not result.ok then
			Net.CombatFeedback:FireClient(player, { altarDenied = true, reason = result.reason })
			Net.CombatFeedback:FireClient(player, altarSnapshot(player))
			return
		end

		state.shards = result.shardsAfter
		local id = Enchants.roll()
		state.enchant = id
		WeaponService.refresh(player, false) -- re-arm so a mythic aura shows immediately

		local e = Enchants.get(id) :: Enchants.Enchant
		Net.CombatFeedback:FireClient(player, {
			enchantResult = true,
			name = e.name,
			desc = e.desc,
			rarity = e.rarity,
			mythic = e.rarity == "mythic",
		})
		Net.CombatFeedback:FireClient(player, altarSnapshot(player))
	end
end)

print("[Dharma] EnchantService ready — the Mantra Altar hums.")
