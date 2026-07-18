--!strict
-- LoadoutService: three saved gear sets — a weapon and the three relic slots,
-- captured from what's worn and swapped back in one press. Applying re-runs
-- EVERY gate: weapon unlocks through WeaponService.trySelect, relic ownership
-- through Relics.tryEquip — a stale or forged loadout can never wear what the
-- ledger doesn't own. Paths are excluded by law: oaths are sworn, not swapped.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Net = require(ReplicatedStorage.Shared.Net)
local Loadouts = require(ReplicatedStorage.Shared.Loadouts)
local Relics = require(ReplicatedStorage.Shared.Relics)
local PlayerRegistry = require(script.Parent.PlayerRegistry)
local ProgressionService = require(script.Parent.ProgressionService)
local WeaponService = require(script.Parent.WeaponService)

local LoadoutService = {}

local function snapshot(player: Player)
	local state = PlayerRegistry.get(player)
	Net.CombatFeedback:FireClient(player, {
		loadoutInfo = true,
		slots = state.loadouts,
		weapon = state.weapon.id,
		crown = state.relics.equipped.crown,
		kavacha = state.relics.equipped.kavacha,
		charm = state.relics.equipped.charm,
	})
end

Net.LoadoutRequest.OnServerEvent:Connect(function(player: Player, data: any)
	if typeof(data) ~= "table" then
		return
	end
	local state = PlayerRegistry.get(player)
	if not state.dataReady then
		return -- never race the save
	end

	if data.action == "info" then
		snapshot(player)
		return
	end

	local slot = tonumber(data.slot)
	if not slot or not Loadouts.isValidSlot(slot) then
		return
	end
	local key = tostring(slot)

	if data.action == "save" then
		if #state.weapon.id == 0 then
			return -- nothing worth saving before the first oath
		end
		local captured = Loadouts.capture(tostring(data.name or ""), state.weapon.id, state.relics.equipped, slot)
		state.loadouts[key] = captured
		Net.CombatFeedback:FireClient(player, { loadoutSaved = true, name = captured.name })
		snapshot(player)
		return
	end

	if data.action == "clear" then
		state.loadouts[key] = nil
		snapshot(player)
		return
	end

	if data.action == "apply" then
		local loadout = state.loadouts[key]
		if not loadout then
			return
		end
		WeaponService.trySelect(player, loadout.weapon)
		for _, relicSlot in Relics.Slots do
			local id = (loadout :: any)[relicSlot]
			if typeof(id) ~= "string" then
				continue
			end
			if id == "" or Relics.tryEquip(state.relics.owned, relicSlot, id).ok then
				(state.relics.equipped :: any)[relicSlot] = id
			end
		end
		ProgressionService.refreshStats(player) -- relic health lands, no free heal
		Net.CombatFeedback:FireClient(player, { loadoutApplied = true, name = loadout.name })
		snapshot(player)
		return
	end
end)

print("[Dharma] LoadoutService ready — gear sworn in one press (L).")

return LoadoutService
