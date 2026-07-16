--!strict
-- The Kirata Trial: at wave 25, deep in the forest, a hunter blocks the path.
-- Fight him well and the disguise burns away — Mahadeva himself. Press him further
-- and the god begins to DANCE: Nataraja, the Tandava, the end of ages. He cannot
-- be slain (nobody slays Shiva); bring him to his last measure and the fight ends
-- in a blessing, never a death. Straight from the Mahabharata: Arjuna's trial.
-- THE DESIGN LAW: this is the summit. No boss, no raid, nothing slayable may ever
-- outrank the Trial — Shiva is the Destroyer, and a test guards the hierarchy.
-- Pure config + gating math (Lune-tested); TrialBoss runs the live fight.

local Trial = {}

-- The trial replaces the boss slot at wave 25, then again every 50 waves.
Trial.FirstWave = 25
Trial.RepeatEvery = 50

function Trial.isTrialWave(wave: number): boolean
	return wave >= Trial.FirstWave and (wave - Trial.FirstWave) % Trial.RepeatEvery == 0
end

-- Which visitation this wave is: 1 at wave 25, 2 at wave 75, ... (0 = not a trial).
function Trial.encounterIndex(wave: number): number
	if not Trial.isTrialWave(wave) then
		return 0
	end
	return math.floor((wave - Trial.FirstWave) / Trial.RepeatEvery) + 1
end

-- One shared health pool across all three phases (fractions of maxHealth).
-- The pool deepens each visitation — the god never stops being the summit.
Trial.MaxHealth = 6000
Trial.HealthGrowth = 0.35 -- +35% per return

function Trial.healthFor(encounter: number): number
	if encounter < 1 then
		encounter = 1
	end
	return math.floor(Trial.MaxHealth * (1 + Trial.HealthGrowth * (encounter - 1)))
end

Trial.Phase2At = 0.55 -- the disguise burns away
Trial.Phase3At = 0.25 -- the dance begins
Trial.BlessAt = 0.05 -- the fight ends in a blessing, never a death

export type PhaseConfig = {
	name: string,
	title: string,
	walkSpeed: number,
	scale: number,
	skin: { number },
	-- Arrow volleys (both phases; flame-arrows in phase 2).
	arrowDamage: number,
	volleyCount: number,
	volleyInterval: number, -- seconds between arrows in a burst
	volleyCooldown: number,
	projectileSpeed: number,
	-- Melee swipe when crowded.
	meleeDamage: number,
	meleeRange: number,
	meleeCooldown: number,
	-- Preferred fighting distance (kites like a hunter in phase 1, stalks in phase 2).
	preferredRange: number,
}

Trial.Phase1 = {
	name = "The Kirata",
	title = "the Hunter in the Woods",
	walkSpeed = 14,
	scale = 1.6,
	skin = { 86, 70, 48 },
	arrowDamage = 16,
	volleyCount = 3,
	volleyInterval = 0.22,
	volleyCooldown = 3.2,
	projectileSpeed = 85,
	meleeDamage = 22,
	meleeRange = 10,
	meleeCooldown = 1.6,
	preferredRange = 32,
} :: PhaseConfig

Trial.Phase2 = {
	name = "Mahadeva",
	title = "the Dance at the End of Time",
	walkSpeed = 11,
	scale = 2.4,
	skin = { 232, 228, 218 },
	arrowDamage = 24,
	volleyCount = 4,
	volleyInterval = 0.18,
	volleyCooldown = 4.0,
	projectileSpeed = 100,
	meleeDamage = 34,
	meleeRange = 13,
	meleeCooldown = 1.8,
	preferredRange = 20,
} :: PhaseConfig

Trial.Phase3 = {
	name = "Nataraja",
	title = "the Tandava Itself",
	walkSpeed = 16,
	scale = 3.2,
	skin = { 96, 120, 160 },
	arrowDamage = 30,
	volleyCount = 6,
	volleyInterval = 0.14,
	volleyCooldown = 3.4,
	projectileSpeed = 115,
	meleeDamage = 45,
	meleeRange = 14,
	meleeCooldown = 1.4,
	preferredRange = 16,
} :: PhaseConfig

-- The Tandava stomp (phase 2): a telegraphed ring of ruin.
Trial.Stomp = {
	radius = 24,
	damage = 55,
	telegraph = 1.6,
	cooldown = 8.0,
}

-- Phase 3: the dance itself — three chained stomps, each ring wider and crueler.
-- Each telegraph is shorter than the last; survive by reading the rhythm.
Trial.TandavaChain = {
	rings = {
		{ radius = 20, damage = 45, telegraph = 1.2 },
		{ radius = 26, damage = 55, telegraph = 1.0 },
		{ radius = 32, damage = 70, telegraph = 0.9 },
	},
	betweenRings = 0.5,
	cooldown = 10.0,
}

-- Words that land cold. Spoken at scripted beats via the bossLine broadcast.
Trial.Lines = {
	spawn = "A hunter walks these woods. Draw your weapon, little warrior.",
	fury = "Show me your fury.",
	transitionA = "Enough.",
	transitionB = "Behold — I am the dance at the end of time.",
	midPhase2 = "The forest burns with your courage. Good.",
	transition2A = "You have seen the dancer. Now witness the dance.",
	transition2B = "I am Nataraja. Worlds end where my foot falls.",
	midPhase3 = "Still standing? The ages themselves kneel.",
	blessing = "You fought without fear. Take my blessing, child of dharma.",
	passed = "THE TRIAL IS PASSED",
}

-- The boon: full heal + cleansed afflictions (applied live), plus these.
-- Richer than anything a slayable foe pays — grace outranks loot.
Trial.Reward = {
	xp = 2500,
	shards = 8,
	gold = 1000,
}

export type Boon = {
	xp: number,
	shards: number,
	gold: number,
}

-- The boon deepens each visitation, like the god himself.
function Trial.rewardFor(encounter: number): Boon
	if encounter < 1 then
		encounter = 1
	end
	return {
		xp = Trial.Reward.xp + 1500 * (encounter - 1),
		shards = Trial.Reward.shards + 2 * (encounter - 1),
		gold = Trial.Reward.gold + 500 * (encounter - 1),
	}
end

return Trial
