--!strict
-- The saved-data schema + validation. Pure logic so it's Lune-testable; the actual
-- DataStore I/O lives in the server DataService. `validate` is the safety net:
-- any loaded value (nil, corrupt, old schema) becomes a clean, valid Data table.

local PlayerData = {}

PlayerData.Version = 2

-- Mirrors Shop.MaxTier (kept dependency-free for Lune; a test guards against drift).
local MAX_TIER = 10

local function clampTier(value: any): number
	if type(value) ~= "number" or value ~= value or value < 0 then
		return 0
	end
	return math.min(math.floor(value), MAX_TIER)
end

export type Upgrades = {
	damage: number,
	health: number,
}

export type Data = {
	version: number,
	totalXp: number,
	gold: number,
	upgrades: Upgrades,
}

function PlayerData.default(): Data
	return {
		version = PlayerData.Version,
		totalXp = 0,
		gold = 0,
		upgrades = { damage = 0, health = 0 },
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
		if type(raw.gold) == "number" and raw.gold >= 0 and raw.gold == raw.gold then
			d.gold = math.floor(raw.gold)
		end
		if type(raw.upgrades) == "table" then
			d.upgrades.damage = clampTier(raw.upgrades.damage)
			d.upgrades.health = clampTier(raw.upgrades.health)
		end
	end
	return d
end

-- Snapshot of the runtime state to persist.
function PlayerData.serialize(totalXp: number, gold: number, upgrades: Upgrades?): Data
	return {
		version = PlayerData.Version,
		totalXp = math.max(0, math.floor(totalXp)),
		gold = math.max(0, math.floor(gold)),
		upgrades = {
			damage = clampTier(if upgrades then upgrades.damage else 0),
			health = clampTier(if upgrades then upgrades.health else 0),
		},
	}
end

return PlayerData
