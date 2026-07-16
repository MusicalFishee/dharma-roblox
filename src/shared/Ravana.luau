--!strict
-- Ravana, the Ten-Headed King: the raid at wave 50, and the mightiest thing in
-- the game THAT CAN DIE. Each head is one of the ten vices; every 10% of his
-- health severs one — a stagger, a darkened crown-orb, and a taunt (he is
-- arrogant to the very last). Each loss makes him faster and crueler; the final
-- head, Ahamkara (the Ego), is the enrage. Slay him and the mythic Dashanana
-- set is guaranteed to drop.
-- THE HIERARCHY: Ravana sits BELOW the Kirata Trial in every number, always —
-- Shiva is the Destroyer, and Ravana was his devotee. A test enforces this.
-- Pure config + stage math (Lune-tested); RavanaRaid runs the live fight.

local Ravana = {}

-- The raid claims wave 50, then every 50 waves (never collides with the Trial,
-- which claims 25, 75, 125, ... — offset by half the cycle).
Ravana.FirstWave = 50
Ravana.RepeatEvery = 50

function Ravana.isRaidWave(wave: number): boolean
	return wave >= Ravana.FirstWave and (wave - Ravana.FirstWave) % Ravana.RepeatEvery == 0
end

-- Which visitation this wave is: 1 at wave 50, 2 at wave 100, ... (0 = not a raid).
function Ravana.encounterIndex(wave: number): number
	if not Ravana.isRaidWave(wave) then
		return 0
	end
	return math.floor((wave - Ravana.FirstWave) / Ravana.RepeatEvery) + 1
end

-- Deep, and deeper each return — but ALWAYS beneath the Trial's pool.
Ravana.MaxHealth = 5000
Ravana.HealthGrowth = 0.35

function Ravana.healthFor(encounter: number): number
	if encounter < 1 then
		encounter = 1
	end
	return math.floor(Ravana.MaxHealth * (1 + Ravana.HealthGrowth * (encounter - 1)))
end

Ravana.HeadCount = 10

export type Head = {
	name: string,
	vice: string,
	-- What he says as THIS head is severed (spoken by the head itself).
	line: string,
}

-- Severed in this order, one per 10% of the pool. The Ego goes last.
Ravana.Heads = {
	{ name = "Kama", vice = "Desire", line = "Take it! I have nine more wants than you will ever know." },
	{ name = "Krodha", vice = "Wrath", line = "You think you have seen my anger? That head barely used it." },
	{ name = "Lobha", vice = "Greed", line = "Keep it. I own everything else in this world." },
	{ name = "Moha", vice = "Delusion", line = "An illusion! Perhaps. Perhaps every head is." },
	{ name = "Mada", vice = "Arrogance", line = "Even halved, I am more king than your gods." },
	{ name = "Matsarya", vice = "Envy", line = "I envied nothing — everything envied ME." },
	{ name = "Manas", vice = "Mind", line = "Thought slows a sword. I am better without it." },
	{ name = "Buddhi", vice = "Intellect", line = "I out-thought the devas once. I will simply do it again." },
	{ name = "Chitta", vice = "Will", line = "My will does not live in flesh, little warrior." },
	{ name = "Ahamkara", vice = "Ego", line = "I... am... RAVANA." },
} :: { Head }

-- How many heads are gone at a given health fraction (never 10 — losing the
-- tenth IS dying, which the Died signal owns).
function Ravana.stageFor(healthFraction: number): number
	if healthFraction ~= healthFraction or healthFraction >= 1 then
		return 0
	end
	if healthFraction <= 0 then
		return Ravana.HeadCount - 1
	end
	return math.clamp(math.floor((1 - healthFraction) * Ravana.HeadCount), 0, Ravana.HeadCount - 1)
end

export type StageStats = {
	walkSpeed: number,
	meleeDamage: number,
	meleeRange: number,
	meleeCooldown: number,
	volleyCount: number, -- Chandrahasa bolts per burst
	volleyDamage: number,
	volleyCooldown: number,
	projectileSpeed: number,
	slamEnabled: boolean, -- the Chandrahasa Arc unlocks once wrath is shed
	enraged: boolean, -- only the Ego remains
}

-- The fewer heads, the fiercer the king. Every number here must stay beneath
-- the Trial's phase 3 — the supremacy test holds the line.
function Ravana.statsForStage(severed: number): StageStats
	severed = math.clamp(severed, 0, Ravana.HeadCount - 1)
	local enraged = severed >= Ravana.HeadCount - 1
	return {
		walkSpeed = 10 + severed * 0.7 + (if enraged then 2 else 0),
		meleeDamage = math.floor(26 * (1 + severed * 0.07)),
		meleeRange = 15,
		meleeCooldown = math.max(1.1, 2.0 - severed * 0.08),
		volleyCount = 3 + math.floor(severed / 3),
		volleyDamage = 20,
		volleyCooldown = math.max(3.0, 4.5 - severed * 0.15),
		projectileSpeed = 95,
		slamEnabled = severed >= 2,
		enraged = enraged,
	}
end

-- The Chandrahasa Arc: his moon-blade carves a telegraphed ring.
Ravana.Slam = {
	radius = 22,
	damage = 60,
	telegraph = 1.4,
	cooldown = 9.0,
}

-- Severing these heads calls rakshasa reinforcements out of the dark.
Ravana.SummonAtSevered = { [3] = 2, [6] = 3, [9] = 4 } :: { [number]: number }
Ravana.SummonArchetype = "Rakshasa"

-- The stagger after each severance: he kneels, you feast.
Ravana.StaggerSeconds = 2.5

Ravana.Lines = {
	spawn = "TEN HEADS LOOK DOWN ON YOU, LITTLE WARRIOR. Which one shall I spare to watch you die?",
	halfway = "Five heads! HA! I have wagered more against Shiva and walked away.",
	enrage = "No more heads to spare. No more mercy to give. COME.",
	defeated = "So falls Dashanana... remember... even the gods needed... an army...",
	victory = "THE TEN-HEADED KING HAS FALLEN",
}

export type Spoils = {
	xp: number,
	shards: number,
}

-- The spoils grow each visitation — but grace outranks loot: the Trial's boon
-- always pays more XP than Ravana's corpse (tested, like everything sacred).
function Ravana.rewardFor(encounter: number): Spoils
	if encounter < 1 then
		encounter = 1
	end
	return {
		xp = 2000 + 800 * (encounter - 1),
		shards = 6 + 2 * (encounter - 1),
	}
end

return Ravana
