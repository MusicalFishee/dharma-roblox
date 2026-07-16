--!strict
-- The Kirata Trial: at wave 25, deep in the forest, a hunter blocks the path.
-- Fight him well and the disguise burns away — Mahadeva himself. He cannot be slain
-- (nobody slays Shiva); bring him to his last measure and he ends the fight with a
-- blessing instead of a death. Straight from the Mahabharata: Arjuna's trial.
-- Pure config + gating math (Lune-tested); TrialBoss runs the live fight.

local Trial = {}

-- The trial replaces the boss slot at wave 25, then again every 50 waves.
Trial.FirstWave = 25
Trial.RepeatEvery = 50

function Trial.isTrialWave(wave: number): boolean
	return wave >= Trial.FirstWave and (wave - Trial.FirstWave) % Trial.RepeatEvery == 0
end

-- One shared health pool across both phases (fractions of maxHealth).
Trial.MaxHealth = 3000
Trial.Phase2At = 0.5 -- the disguise burns away
Trial.BlessAt = 0.10 -- the fight ends in a blessing, never a death

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

-- The Tandava stomp (phase 2 only): a telegraphed ring of ruin.
Trial.Stomp = {
	radius = 24,
	damage = 55,
	telegraph = 1.6,
	cooldown = 8.0,
}

-- Words that land cold. Spoken at scripted beats via the bossLine broadcast.
Trial.Lines = {
	spawn = "A hunter walks these woods. Draw your weapon, little warrior.",
	fury = "Show me your fury.",
	transitionA = "Enough.",
	transitionB = "Behold — I am the dance at the end of time.",
	midPhase2 = "The forest burns with your courage. Good.",
	blessing = "You fought without fear. Take my blessing, child of dharma.",
	passed = "THE TRIAL IS PASSED",
}

-- The boon: full heal + cleansed afflictions (applied live), plus these.
Trial.Reward = {
	xp = 1200,
	shards = 5,
}

return Trial
