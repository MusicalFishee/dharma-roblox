--!strict
-- Server-only per-player combat state (lives in ServerScriptService, never replicated).
-- Shared between CombatService (offense) and EnemyService (incoming attacks).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Combat = require(ReplicatedStorage.Shared.Combat)
local ComboTracker = require(ReplicatedStorage.Shared.ComboTracker)

export type PlayerState = {
	combo: ComboTracker.ComboTracker,
	tejas: number,
	isBlocking: boolean,
	blockStartedAt: number,
	-- Wall-clock time (os.clock) until which dodge i-frames are active.
	dodgeUntil: number,
}

local PlayerRegistry = {}

local states: { [Player]: PlayerState } = {}

function PlayerRegistry.get(player: Player): PlayerState
	local existing = states[player]
	if existing then
		return existing
	end

	local state: PlayerState = {
		combo = ComboTracker.new(Combat.Config.ComboResetWindow),
		tejas = 0,
		isBlocking = false,
		blockStartedAt = 0,
		dodgeUntil = 0,
	}
	states[player] = state
	return state
end

function PlayerRegistry.remove(player: Player)
	states[player] = nil
end

return PlayerRegistry
