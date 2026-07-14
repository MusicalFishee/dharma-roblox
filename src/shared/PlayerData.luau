--!strict
-- The saved-data schema + validation. Pure logic so it's Lune-testable; the actual
-- DataStore I/O lives in the server DataService. `validate` is the safety net:
-- any loaded value (nil, corrupt, old schema) becomes a clean, valid Data table.

local PlayerData = {}

PlayerData.Version = 1

export type Data = {
	version: number,
	totalXp: number,
}

function PlayerData.default(): Data
	return {
		version = PlayerData.Version,
		totalXp = 0,
	}
end

-- Coerce arbitrary loaded data into valid Data: fill missing fields, clamp bad ones,
-- ignore junk. Never trusts the stored blob blindly.
function PlayerData.validate(raw: any): Data
	local d = PlayerData.default()
	if type(raw) == "table" then
		if type(raw.totalXp) == "number" and raw.totalXp >= 0 and raw.totalXp == raw.totalXp then
			d.totalXp = math.floor(raw.totalXp)
		end
	end
	return d
end

-- Snapshot of the runtime state to persist.
function PlayerData.serialize(totalXp: number): Data
	return {
		version = PlayerData.Version,
		totalXp = math.max(0, math.floor(totalXp)),
	}
end

return PlayerData
