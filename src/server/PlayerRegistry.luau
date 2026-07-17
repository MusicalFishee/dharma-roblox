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
	-- Sworn Astra Path id ("" = unsworn, classic mixed kit).
	path: string,
	-- Ward windows (os.clock expiry): shield scales damage TAKEN, empower scales damage DEALT.
	wardUntil: number,
	wardMult: number,
	empowerUntil: number,
	empowerMult: number,
	-- Status-effect expiries (os.clock): venom DoT active / healing cursed.
	venomUntil: number,
	curseUntil: number,
	-- Lifetime records; playtimeMark is the os.clock() of the last playtime bank.
	stats: { kills: number, bossKills: number, deaths: number, playtimeSeconds: number, trialsPassed: number, duelWins: number, raidClears: number, revives: number },
	playtimeMark: number,
	-- Equipped title id ("" = bare head).
	title: string,
	-- Relic satchel + worn pieces (bonuses read via Relics.totalBonus).
	relics: { owned: { string }, equipped: { crown: string, kavacha: string, charm: string } },
	-- Adhyayas completed (Agastya's story; advances via Story.advance).
	storyChapter: number,
	-- Per-path siddhi mastery XP (fed by AbilityService, never decreases).
	mastery: { agni: number, vayu: number, varuna: number, indra: number },
	-- Agnihotra login streak (granted once per UTC day on load).
	streak: { stamp: number, count: number },
	-- Vīra kill streak (count + os.clock of the last killing blow).
	viraCount: number,
	viraLastAt: number,
	-- This wave's conduct ledger (reset every wave start; graded on clear).
	waveKills: number,
	waveParries: number,
	waveTimesHit: number,
	waveDowns: number,
	-- Adhyaya 0 finished (persisted; the lesson never repeats).
	tutorialDone: boolean,
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
		path = "",
		wardUntil = 0,
		wardMult = 1,
		empowerUntil = 0,
		empowerMult = 1,
		venomUntil = 0,
		curseUntil = 0,
		stats = { kills = 0, bossKills = 0, deaths = 0, playtimeSeconds = 0, trialsPassed = 0, duelWins = 0, raidClears = 0, revives = 0 },
		playtimeMark = os.clock(),
		title = "",
		relics = { owned = {}, equipped = { crown = "", kavacha = "", charm = "" } },
		storyChapter = 0,
		mastery = { agni = 0, vayu = 0, varuna = 0, indra = 0 },
		streak = { stamp = 0, count = 0 },
		viraCount = 0,
		viraLastAt = 0,
		waveKills = 0,
		waveParries = 0,
		waveTimesHit = 0,
		waveDowns = 0,
		tutorialDone = false,
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
