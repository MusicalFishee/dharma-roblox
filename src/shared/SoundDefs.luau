--!strict
-- Sound design as data: every combat event mapped to a built-in rbxasset:// sound
-- with volume + a pitch range (random pitch per play = variety from few sources).
-- Built-ins ship inside the Roblox client, so nothing needs uploading/publishing.
-- Pure data + lookups; Lune tests validate every def and mapping.

local SoundDefs = {}

export type Sfx = {
	path: string,
	volume: number,
	pitchMin: number,
	pitchMax: number,
}

local function sfx(path: string, volume: number, pitchMin: number, pitchMax: number): Sfx
	return { path = path, volume = volume, pitchMin = pitchMin, pitchMax = pitchMax }
end

SoundDefs.Sfx = {
	-- Melee
	swingLight = sfx("rbxasset://sounds/swordslash.wav", 0.5, 0.95, 1.25),
	swingHeavy = sfx("rbxasset://sounds/swordlunge.wav", 0.7, 0.8, 0.95),
	punchLand = sfx("rbxasset://sounds/snap.mp3", 0.6, 0.85, 1.15),
	finisherLand = sfx("rbxasset://sounds/collide.wav", 0.8, 0.7, 0.9),

	-- Defense
	guardUp = sfx("rbxasset://sounds/unsheath.wav", 0.5, 0.9, 1.0),
	parry = sfx("rbxasset://sounds/electronicpingshort.wav", 0.8, 1.1, 1.3),
	blocked = sfx("rbxasset://sounds/metal.mp3", 0.6, 0.8, 1.0),
	hurt = sfx("rbxasset://sounds/snap.mp3", 0.7, 0.6, 0.75),

	-- Abilities
	astraThrow = sfx("rbxasset://sounds/Rocket whoosh 01.wav", 0.6, 1.1, 1.3),
	dashWhoosh = sfx("rbxasset://sounds/swordslash.wav", 0.55, 0.55, 0.7),
	healSurge = sfx("rbxasset://sounds/impact_water.mp3", 0.7, 0.9, 1.1),
	thunderCrack = sfx("rbxasset://sounds/glassbreak.wav", 0.9, 0.45, 0.6),

	-- Enemies
	enemySwing = sfx("rbxasset://sounds/swordslash.wav", 0.45, 0.65, 0.8),

	-- Rewards / flow
	goldPickup = sfx("rbxasset://sounds/button.wav", 0.6, 1.15, 1.35),
	amritPickup = sfx("rbxasset://sounds/impact_water.mp3", 0.7, 1.2, 1.4),
	levelUp = sfx("rbxasset://sounds/electronicpingshort.wav", 0.9, 0.95, 1.05),
	shopBuy = sfx("rbxasset://sounds/button.wav", 0.7, 0.9, 1.0),
	questDone = sfx("rbxasset://sounds/electronicpingshort.wav", 0.85, 1.25, 1.35),

	-- Waves / bosses
	waveStart = sfx("rbxasset://sounds/bass.wav", 0.8, 0.55, 0.65),
	waveClear = sfx("rbxasset://sounds/victory.wav", 0.6, 1.0, 1.0),
	bossSpawn = sfx("rbxasset://sounds/bass.wav", 1.0, 0.35, 0.45),
	bossDefeated = sfx("rbxasset://sounds/victory.wav", 0.8, 0.9, 0.9),
	playerDown = sfx("rbxasset://sounds/bass.wav", 0.9, 0.3, 0.35),
} :: { [string]: Sfx }

-- Animation broadcast (AnimEvent track name) -> sfx name. 3D, at the actor.
SoundDefs.AnimSounds = {
	combo1 = "swingLight",
	combo2 = "swingLight",
	combo3 = "swingLight",
	combo4 = "swingHeavy",
	throw = "astraThrow",
	dash = "dashWhoosh",
	heal = "healSurge",
	ult = "thunderCrack",
	enemySwing = "enemySwing",
	flinch = "punchLand",
	blockstart = "guardUp",
} :: { [string]: string }

-- HUD feedback (CombatFeedback outcome / flags) -> sfx name. 2D, local.
SoundDefs.FeedbackSounds = {
	Parry = "parry",
	Block = "blocked",
	Hit = "hurt",
} :: { [string]: string }

-- Boss war-drums: a rhythmic pattern looped while a boss lives.
-- Beats are offsets (seconds) into each cycle; pitch/volume shape the pulse.
SoundDefs.BossDrums = {
	sfxPath = "rbxasset://sounds/bass.wav",
	cycleSeconds = 2.0,
	beats = {
		{ t = 0.0, pitch = 0.5, volume = 0.7 },
		{ t = 0.5, pitch = 0.5, volume = 0.45 },
		{ t = 0.75, pitch = 0.72, volume = 0.55 },
		{ t = 1.25, pitch = 0.5, volume = 0.45 },
		{ t = 1.5, pitch = 0.6, volume = 0.6 },
	},
}

return SoundDefs
