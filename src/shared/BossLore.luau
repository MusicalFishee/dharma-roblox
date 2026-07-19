--!strict
-- The Asura Lords speak. Each of the seven boss-lords carries a taunt for
-- his arrival and a line for his fall — every one grounded in the myth that
-- made him. Ravana and the god get their own scripted encounters; these are
-- the lords who claim the ordinary boss waves, so that none of them arrives
-- a nameless slab of health. Pure data (Lune-tested); WaveService speaks it
-- through the same bossLine channel the raids use.

local BossLore = {}

export type Lore = {
	spawn: string, -- delivered as he arrives
	fall: string, -- delivered as he dies
}

BossLore.Lines = {
	-- The Buffalo Demon: shape-shifter who emptied heaven of its gods; only
	-- Durga could break him, and only after ten days of war.
	Mahishasura = {
		spawn = "I emptied heaven of its gods once. You are not even a warm-up.",
		fall = "A goddess needed ten days. You needed an afternoon. The insult wounds deeper than the blade.",
	},
	-- Ravana's colossal brother, cursed to sleep half the year and wake only
	-- to devour.
	Kumbhakarna = {
		spawn = "You woke me. Do you know how few live long enough to regret that?",
		fall = "Back to sleep, then. Wake me when there is a REAL war.",
	},
	-- Boon-locked against man and beast, day and night, indoors and out —
	-- undone at a threshold, at twilight, by something that was neither.
	Hiranyakashipu = {
		spawn = "No man may slay me. No beast. Not by day, not by night. Which are you, little thing?",
		fall = "The old loophole... twilight, and a threshold, and something that is neither...",
	},
	-- The glutton who demanded a cartload of food and the one who brought it,
	-- until Bhima fed him his own greed.
	Bakasura = {
		spawn = "A whole village fed me daily. You will be a light snack.",
		fall = "Still... hungry... it was never... enough...",
	},
	-- The drought-serpent who coiled round the mountains and held the world's
	-- waters hostage, until Indra's vajra split him open.
	Vritra = {
		spawn = "I held the world's rivers in my coils. I will hold your breath the same way.",
		fall = "Let the waters go, then... let them drown someone worthier...",
	},
	-- Ravana's uncle, the sorcerer — a weaver of illusions who fought with
	-- borrowed faces.
	Kalanemi = {
		spawn = "Everything you see, I chose for you to see. Even your courage. Especially that.",
		fall = "An illusion loses nothing by ending. I will simply be dreamt again...",
	},
	-- The boon-demon slain only by Shiva's son. His full War-Moon reckoning
	-- comes at the raid; when he claims an ordinary boss wave he still wears
	-- the same certainty that no mortal hand can end him.
	Tarakasura = {
		spawn = "Creation itself swore no mortal hand could end me. Raise yours anyway. Amuse me.",
		fall = "Only a god's child was meant to fell me. Where... is he hiding YOU?",
	},
	-- Ravana's own name kept here too, so the raid's lord is never lore-less
	-- should a caller reach for it.
	Ravana = {
		spawn = "Ten heads look down on you, little warrior.",
		fall = "So falls Dashanana... remember... even the gods needed an army...",
	},
} :: { [string]: Lore }

function BossLore.forBoss(bossId: string): Lore?
	return BossLore.Lines[bossId]
end

return BossLore
