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
	weapon: { id: string, tier: number },
	-- Vajra Shards (boss-kill currency) and the mantra inscribed on the weapon.
	shards: number,
	enchant: string,
	bestWave: number,
	quests: { { id: string, progress: number } },
	-- Today's trials: stamp = day number, slots reroll when it goes stale.
	dailies: { stamp: number, slots: { { id: string, progress: number, done: boolean } } },
	-- True once persistent data has loaded; guards against saving over real progress.
	dataLoaded: boolean,
	-- True once a load has been ATTEMPTED (success or fail) — the weapon hook waits
	-- on this so it never prompts a returning player to re-choose before their save arrives.
	dataReady: boolean,
	isBlocking: boolean,
	blockStartedAt: number,
	-- Wall-clock time (os.clock) until which dodge i-frames are active.
	dodgeUntil: number,
	-- Status-effect expiries (os.clock): venom DoT active / healing cursed.
	venomUntil: number,
	curseUntil: number,
	-- Lifetime records; playtimeMark is the os.clock() of the last playtime bank.
	stats: { kills: number, bossKills: number, deaths: number, playtimeSeconds: number },
	playtimeMark: number,
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
		weapon = { id = "", tier = 1 },
		shards = 0,
		enchant = "",
		bestWave = 0,
		quests = {},
		dailies = { stamp = 0, slots = {} },
		dataLoaded = false,
		dataReady = false,
		isBlocking = false,
		blockStartedAt = 0,
		dodgeUntil = 0,
		venomUntil = 0,
		curseUntil = 0,
		stats = { kills = 0, bossKills = 0, deaths = 0, playtimeSeconds = 0 },
		playtimeMark = os.clock(),
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
