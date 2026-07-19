--!strict
-- ShastraService: the blade remembers. Every landed blow and every kill
-- feeds the WORN weapon's own ledger; a turned rank announces itself.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Net = require(ReplicatedStorage.Shared.Net)
local Shastra = require(ReplicatedStorage.Shared.Shastra)
local Weapons = require(ReplicatedStorage.Shared.Weapons)
local PlayerRegistry = require(script.Parent.PlayerRegistry)

local ShastraService = {}

function ShastraService.feed(player: Player, amount: number)
	local state = PlayerRegistry.tryGet(player)
	if not state or not state.dataReady or #state.weapon.id == 0 then
		return -- no blade, no ledger; no save, no ink
	end
	local before = Shastra.rankFor(state.shastra[state.weapon.id] or 0)
	local xp = (state.shastra[state.weapon.id] or 0) + amount
	state.shastra[state.weapon.id] = xp
	local after = Shastra.rankFor(xp)
	if after > before then
		local def = Shastra.Ranks[after]
		local weapon = Weapons.get(state.weapon.id)
		Net.CombatFeedback:FireClient(player, {
			shastraRank = true,
			weaponName = if weapon then weapon.displayName else state.weapon.id,
			rankName = def.name,
			line = def.line,
		})
	end
end

print("[Dharma] ShastraService ready — every blade keeps its ledger.")

return ShastraService
