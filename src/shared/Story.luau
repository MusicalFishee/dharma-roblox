--!strict
-- The Adhyayas: seven story chapters narrated by Rishi Agastya — the sage who
-- armed Rama with the Astras in this very forest. Chapters complete IN ORDER,
-- each gated on a stat the save already records, so every step is retroactive
-- and wipe-proof. The arc is deliberate: you fell the Ten-Headed King in
-- Adhyaya VI — and the FINALE is learning how small that victory was. The last
-- chapter, like the last word, belongs to Mahadeva. Pure data + advance math
-- (Lune-tested); StoryService speaks, pays, and persists.

local Story = {}

Story.Narrator = "Rishi Agastya"

export type Trigger = {
	kind: string, -- "wave" | "bossKills" | "trials" | "raids"
	value: number,
}

export type ChapterDef = {
	id: string,
	numeral: string,
	title: string,
	requirement: string, -- human-readable, shown in the journal while active
	trigger: Trigger,
	beginLines: { string }, -- Agastya, when the chapter becomes your road
	closeLine: string, -- Agastya, the moment it completes
	reward: { gold: number, xp: number },
}

-- What the story reads from a player's persistent record.
export type Snapshot = {
	bestWave: number,
	bossKills: number,
	trialsPassed: number,
	raidClears: number,
}

Story.Chapters = {
	{
		id = "ashram_burns",
		numeral = "I",
		title = "The Ashram Burns",
		requirement = "Clear wave 5",
		trigger = { kind = "wave", value = 5 },
		beginLines = {
			"I am Agastya. A thousand years I have kept this ashram, and tonight the asuras come to burn it.",
			"The Astras answer you — do you feel it? Then stand, child of dharma. The first wave is already howling.",
		},
		closeLine = "The fires gutter and the ashram stands. You may yet be more than a student.",
		reward = { gold = 150, xp = 300 },
	},
	{
		id = "buffalo_king",
		numeral = "II",
		title = "The Buffalo King",
		requirement = "Fell your first asura lord",
		trigger = { kind = "bossKills", value = 1 },
		beginLines = {
			"The rabble serve lords, and the lords are older than kingdoms. Mahishasura comes first — the Buffalo King, who once drove the devas from heaven.",
			"A goddess needed ten days to break him. Show me what you need.",
		},
		closeLine = "An asura lord, felled. The forest itself held its breath. Take your due.",
		reward = { gold = 250, xp = 500 },
	},
	{
		id = "into_dandakaranya",
		numeral = "III",
		title = "Into Dandakaranya",
		requirement = "Clear wave 15",
		trigger = { kind = "wave", value = 15 },
		beginLines = {
			"Beyond the ashram lies Dandakaranya — the forest of punishment. Rama walked it. So did worse things.",
			"The green flames you'll see are not fireflies. Keep your blade wet.",
		},
		closeLine = "You walk the dark forest and the dark forest moves aside. Rama would smile.",
		reward = { gold = 350, xp = 700 },
	},
	{
		id = "hunter_woods",
		numeral = "IV",
		title = "The Hunter in the Woods",
		requirement = "Pass the Kirata Trial",
		trigger = { kind = "trials", value = 1 },
		beginLines = {
			"Listen well, for this matters more than all the rest: a hunter waits at the forest's heart, and he is not what he seems.",
			"Arjuna fought him once and lost the fight — but won the trial. Do not fight to win, child. Fight to be WORTHY.",
		},
		closeLine = "You knelt before the hunter and rose blessed. Few living souls carry what you now carry.",
		reward = { gold = 500, xp = 1000 },
	},
	{
		id = "drowned_deep",
		numeral = "V",
		title = "The Drowned Deep",
		requirement = "Clear wave 30",
		trigger = { kind = "wave", value = 30 },
		beginLines = {
			"The war goes down now — into Sagara Tala, the drowned dark, where sound arrives late and mercy not at all.",
			"I once drank the ocean dry to bare the asuras hiding in it. I have not the stomach for a second draught. Go in my stead.",
		},
		closeLine = "Even the deep places know your name now. That is not always a comfort.",
		reward = { gold = 600, xp = 1200 },
	},
	{
		id = "ten_headed_king",
		numeral = "VI",
		title = "The Ten-Headed King",
		requirement = "Fell Ravana",
		trigger = { kind = "raids", value = 1 },
		beginLines = {
			"So. He has finally noticed you. Ravana — Dashanana — the Ten-Headed King, who lifted Kailasa itself and sang under its weight.",
			"Each head is a vice, and each vice must fall. It took Rama an army, a bridge over the sea, and the grace of the gods. You have your friends and your Astras. Make them enough.",
		},
		closeLine = "The Ten-Headed King lies fallen. Songs will argue about this day for a thousand years.",
		reward = { gold = 900, xp = 1800 },
	},
	{
		id = "the_tandava",
		numeral = "VII",
		title = "The Tandava",
		requirement = "Pass the Trial a second time",
		trigger = { kind = "trials", value = 2 },
		beginLines = {
			"You have slain the king of ten heads, and you are proud. Good. Now go and learn how small that victory is.",
			"Return to the hunter, deeper in the endless waves. This time the disguise will not merely burn away — this time he will DANCE. No one defeats the Tandava, child. One only survives it, and is remade.",
		},
		closeLine = "You stood inside the dance at the end of time, and you are still here. There is nothing more I can teach you. There is nothing more anyone can.",
		reward = { gold = 1500, xp = 3000 },
	},
} :: { ChapterDef }

local VALID_KINDS = { wave = true, bossKills = true, trials = true, raids = true }

function Story.chapterCount(): number
	return #Story.Chapters
end

function Story.chapterAt(index: number): ChapterDef?
	return Story.Chapters[index]
end

-- Does the record satisfy one chapter's trigger?
function Story.isSatisfied(def: ChapterDef, snap: Snapshot): boolean
	local kind = def.trigger.kind
	if not VALID_KINDS[kind] then
		return false
	end
	local stat = 0
	if kind == "wave" then
		stat = snap.bestWave
	elseif kind == "bossKills" then
		stat = snap.bossKills
	elseif kind == "trials" then
		stat = snap.trialsPassed
	elseif kind == "raids" then
		stat = snap.raidClears
	end
	return stat >= def.trigger.value
end

-- Cascade from `done` chapters completed: keep completing while the next
-- chapter's trigger is already satisfied. Returns the new done count.
function Story.advance(done: number, snap: Snapshot): number
	done = math.clamp(math.floor(done), 0, #Story.Chapters)
	while done < #Story.Chapters do
		local nextChapter = Story.Chapters[done + 1]
		if not Story.isSatisfied(nextChapter, snap) then
			break
		end
		done += 1
	end
	return done
end

return Story
