--!strict
-- Tarakasura, the War-Moon: the second raid, at wave 150 and every 150th.
-- The demon who wrung a boon from creation: NO MORTAL HAND MAY SLAY HIM —
-- only Shiva's son. So the fight honors the myth: players shatter the three
-- moon-anchors that hold him above their reach, drag him down, batter him
-- to his knees — and then the Vel of Karttikeya falls from the sky to end
-- what mortals may only break. Even this victory belongs to Shiva's house.
-- THE HIERARCHY, BY LAW: Trial > War-Moon > Ravana in every tested number,
-- at every visitation, forever. The tarakasura.spec holds the line.
-- Pure config + stage math (Lune-tested); WarMoonRaid runs the live fight.

local Tarakasura = {}

-- Claims wave 150 and every 150th. Every War-Moon night is also a Ravana
-- night (150 % 50 == 0) — the wave director checks the Moon FIRST, so the
-- greater raid rises over the king's. It can never touch a Trial night
-- (trials fall on 25 + 50k, always odd multiples of 25).
Tarakasura.FirstWave = 150
Tarakasura.RepeatEvery = 150

function Tarakasura.isWarMoonWave(wave: number): boolean
	return wave >= Tarakasura.FirstWave and (wave - Tarakasura.FirstWave) % Tarakasura.RepeatEvery == 0
end

function Tarakasura.encounterIndex(wave: number): number
	if not Tarakasura.isWarMoonWave(wave) then
		return 0
	end
	return math.floor((wave - Tarakasura.FirstWave) / Tarakasura.RepeatEvery) + 1
end

-- Between the king and the god, always (Trial 6000 > this > Ravana 5000).
Tarakasura.MaxHealth = 5600
Tarakasura.HealthGrowth = 0.35

function Tarakasura.healthFor(encounter: number): number
	if encounter < 1 then
		encounter = 1
	end
	return math.floor(Tarakasura.MaxHealth * (1 + Tarakasura.HealthGrowth * (encounter - 1)))
end

-- Phase 1: the three moon-anchors that hold him above mortal reach.
Tarakasura.AnchorCount = 3

function Tarakasura.anchorHealthFor(encounter: number): number
	if encounter < 1 then
		encounter = 1
	end
	return math.floor(500 * (1 + 0.5 * (encounter - 1)))
end

-- Each felled anchor bleeds guards out of the moonlight.
Tarakasura.GuardsPerAnchor = 2
Tarakasura.GuardArchetype = "Vetala"

-- Phase 2 stages, read off his health fraction: 0 calm, 1 wounded,
-- 2 furious, 3 the moon's last light (enrage).
function Tarakasura.stageFor(healthFraction: number): number
	if healthFraction ~= healthFraction or healthFraction > 0.66 then
		return 0
	elseif healthFraction > 0.33 then
		return 1
	elseif healthFraction > 0.15 then
		return 2
	end
	return 3
end

export type StageStats = {
	walkSpeed: number,
	meleeDamage: number,
	meleeRange: number,
	meleeCooldown: number,
	volleyCount: number,
	volleyDamage: number,
	volleyCooldown: number,
	projectileSpeed: number,
	enraged: boolean,
}

-- Fiercer as the moon wanes — his cruelest blow stays between Ravana's
-- worst and the Trial's third phase, by tested law.
function Tarakasura.statsForStage(stage: number): StageStats
	stage = math.clamp(stage, 0, 3)
	return {
		walkSpeed = 11 + stage * 1.2,
		meleeDamage = 32 + stage * 4,
		meleeRange = 14,
		meleeCooldown = 2.0 - stage * 0.15,
		volleyCount = 2 + stage,
		volleyDamage = 18,
		volleyCooldown = 4.6 - stage * 0.3,
		projectileSpeed = 90,
		enraged = stage >= 3,
	}
end

-- Moonfall: the War-Moon itself hammers a telegraphed ring.
Tarakasura.Slam = {
	radius = 24,
	damage = 58,
	telegraph = 1.6,
	cooldown = 10.0,
}

-- Stage transitions tear reinforcements out of the moonlight.
Tarakasura.SummonAtStage = { [1] = 2, [2] = 3 } :: { [number]: number }
Tarakasura.SummonArchetype = "Rakshasa"

-- The boon: mortals may BREAK him, never end him. At this fraction he
-- kneels, unkillable — and the Vel of Karttikeya falls to finish it.
Tarakasura.BrokenFraction = 0.08
Tarakasura.VelSeconds = 2.5

Tarakasura.Lines = {
	spawn = "I asked creation for one gift: that no mortal hand may end me. Look up, little warriors. The Moon is mine, and you are BENEATH it.",
	anchorDown = "You broke a chain. I have two more, and you have so little blood.",
	descend = "FINE. The Moon sets. Let me show you why the devas hid behind a CHILD.",
	wounded = "You scratch deeper than armies did. It will not matter.",
	furious = "ENOUGH. I have burned heavens for less insolence.",
	enrage = "The moon's last light! Come die inside it!",
	broken = "Ha... HA! Broken — yes. But my boon holds, little ones. No mortal hand may end me. NONE.",
	vel = "...no. Not the boy. NOT THE BOY—",
	defeated = "So it was never you... it was always... his son...",
	victory = "THE WAR-MOON HAS SET",
}

export type Spoils = {
	xp: number,
	shards: number,
	gold: number,
}

-- Pays above the king, beneath the god — at every visitation, by law.
function Tarakasura.rewardFor(encounter: number): Spoils
	if encounter < 1 then
		encounter = 1
	end
	return {
		xp = 2300 + 1100 * (encounter - 1),
		shards = 7 + 2 * (encounter - 1),
		gold = 800 + 300 * (encounter - 1),
	}
end

return Tarakasura
