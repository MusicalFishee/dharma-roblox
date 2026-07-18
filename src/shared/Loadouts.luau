--!strict
-- Loadouts: named gear sets — a weapon and the three relic slots, captured
-- from what's worn and swapped back in one press. PATHS ARE EXCLUDED BY LAW:
-- an oath is sworn, not swapped (a loadout that switched paths would dodge
-- the respec price). Pure capture/name logic (Lune-tested); LoadoutService
-- owns the swap and re-runs every unlock gate on apply.

local Loadouts = {}

Loadouts.MaxSlots = 3
Loadouts.MaxNameLength = 16

export type Loadout = {
	name: string,
	weapon: string,
	crown: string,
	kavacha: string,
	charm: string,
}

function Loadouts.isValidSlot(slot: number): boolean
	return slot == math.floor(slot) and slot >= 1 and slot <= Loadouts.MaxSlots
end

-- Tidy a chosen name: collapse whitespace, cap the length, and fall back to
-- a plain slot name when nothing readable is left.
function Loadouts.cleanName(raw: string, slot: number): string
	local collapsed = string.gsub(raw, "%s+", " ")
	local name = string.match(collapsed, "^ ?(.-) ?$") or ""
	name = string.sub(name, 1, Loadouts.MaxNameLength)
	name = string.match(name, "^(.-) ?$") or ""
	if #name == 0 then
		return "Loadout " .. slot
	end
	return name
end

-- Snapshot what is worn RIGHT NOW into a loadout (a copy, never a reference).
function Loadouts.capture(name: string, weaponId: string, equipped: { crown: string, kavacha: string, charm: string }, slot: number): Loadout
	return {
		name = Loadouts.cleanName(name, slot),
		weapon = weaponId,
		crown = equipped.crown,
		kavacha = equipped.kavacha,
		charm = equipped.charm,
	}
end

-- How many relics this loadout wears.
function Loadouts.relicCount(loadout: Loadout): number
	local n = 0
	for _, id in { loadout.crown, loadout.kavacha, loadout.charm } do
		if #id > 0 then
			n += 1
		end
	end
	return n
end

return Loadouts
