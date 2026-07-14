--!strict
-- Server-only per-player combat state (lives in ServerScriptService, never replicated).
-- Shared between CombatService (offense) and EnemyService (incoming attacks).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Combat = require(ReplicatedStorage.Shared.Combat)
local ComboTracker = require(ReplicatedStorage.Shared.ComboTracker)
local ComboChain = require(ReplicatedStorage.Shared.ComboChain)

export type PlayerState = {
	-- Flow damage combo (consecutive connecting hits).
	combo: ComboTracker.ComboTracker,
	-- LMB attack chain (light x3 -> heavy finisher -> lockout).
	chain: ComboChain.ComboChain,
	tejas: number,
	totalXp: number,
	gold: number,
	upgrades: { damage: number, health: number },
	-- True once persistent data has loaded; guards against saving over real progress.
	dataLoaded: boolean,
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
		chain = ComboChain.new({
			length = Combat.Config.ComboChainLength,
			hitInterval = Combat.Config.ComboHitInterval,
			finisherLockout = Combat.Config.ComboFinisherLockout,
			resetWindow = Combat.Config.ComboResetWindow,
		}),
		tejas = 0,
		totalXp = 0,
		gold = 0,
		upgrades = { damage = 0, health = 0 },
		dataLoaded = false,
		isBlocking = false,
		blockStartedAt = 0,
		dodgeUntil = 0,
	}
	states[player] = state
	return state
end

-- Returns the state only if it already exists (never creates one).
function PlayerRegistry.tryGet(player: Player): PlayerState?
	return states[player]
end

function PlayerRegistry.remove(player: Player)
	states[player] = nil
end

return PlayerRegistry
