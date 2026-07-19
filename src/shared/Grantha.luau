--!strict
-- The Ripu-Grantha: Agastya's book of foes. Every family of the horde has a
-- page; every kill inks it. Pages turn at kill tiers — each tier reveals a
-- line of the sage's field notes and owes a one-time bounty (recomputed
-- server-side from the REAL ledger; the book is a window, never a wallet).
-- A COVERAGE LAW keeps it honest: every archetype in the roster must belong
-- to exactly one family, so no future bloodline ships unwritten.
-- Pure catalog + tier/owed math (Lune-tested); GranthaService inks it.

local Grantha = {}

export type FamilyDef = {
	id: string,
	name: string,
	members: { string }, -- archetype ids
	tiers: { number }, -- kill thresholds, ascending, three deep
	lore: { string }, -- one field note revealed per tier
}

local function family(def: FamilyDef): FamilyDef
	return def
end

Grantha.Families = {
	family({
		id = "asura",
		name = "The Asura Rabble",
		members = { "Asura" },
		tiers = { 50, 300, 1000 },
		lore = {
			"The backbone of every horde. They die easily and arrive endlessly — note which one you tire of first.",
			"I have counted their war-cries: they have four, and all of them are lies.",
			"A thousand felled. Child, you have not thinned them — you have merely kept the world's pace.",
		},
	}),
	family({
		id = "pisacha",
		name = "The Pisacha Packs",
		members = { "Pisacha" },
		tiers = { 40, 250, 800 },
		lore = {
			"Flesh-eaters that hunt in packs and punish greed. The bite carries rot; the corpse carries worse.",
			"Their pools have taught more warriors footwork than I ever did.",
			"You now know their secret: the pack is brave, the last one never is.",
		},
	}),
	family({
		id = "vetala",
		name = "The Vetala Shades",
		members = { "Vetala" },
		tiers = { 25, 150, 500 },
		lore = {
			"Corpse-riders. What you fight is the glove, not the hand — and the glove carries a curse.",
			"They strike hardest at the undefended back. So did every empire.",
			"Five hundred shades unseated. Somewhere, the hands are running out of gloves.",
		},
	}),
	family({
		id = "maricha",
		name = "The Line of Maricha",
		members = { "Maricha", "MarichaRevealed" },
		tiers = { 25, 150, 500 },
		lore = {
			"The golden archer kites like his ancestor fled: beautifully, and never quite far enough.",
			"You have seen the deer, yes? Count your arrows, hunter. Someone else is.",
			"Illusion is a family trade, and you have bankrupted the shop.",
		},
	}),
	family({
		id = "rakshasa",
		name = "The Rakshasa Brutes",
		members = { "Rakshasa" },
		tiers = { 15, 100, 350 },
		lore = {
			"Towers of muscle that mistake slowness for patience. Neither will save them.",
			"When one falls angry, its kin catch the anger. Fell them out of earshot.",
			"Three hundred and fifty towers down. The horde's architecture grows nervous.",
		},
	}),
	family({
		id = "yaksha",
		name = "The Yaksha Wardens",
		members = { "Yaksha" },
		tiers = { 15, 100, 350 },
		lore = {
			"Treasure-guards from the mountain courts. They pay like vaults because they ARE vaults.",
			"A yaksha never runs. It was paid to stand there, and it stays bought.",
			"The mountain courts have posted your description. They spelled your name wrong.",
		},
	}),
	family({
		id = "naga",
		name = "The Naga Bloodline",
		members = { "Naga", "NagaCharmer", "NagaRaja" },
		tiers = { 25, 150, 500 },
		lore = {
			"Serpent-folk of the drowned deep. Every bite carries venom; every scale remembers.",
			"The charmers spit what the soldiers whisper. The king pools what he cannot keep.",
			"The deep now tells stories about YOU, child. They are not bedtime stories.",
		},
	}),
	family({
		id = "hima",
		name = "The Hima-folk",
		members = { "Himabhuta", "Tushara", "Himapala" },
		tiers = { 25, 150, 500 },
		lore = {
			"Frost given intention. The cold in their touch is not temperature — it is opinion.",
			"The sleet-archers loose winter itself. Parry it; the sound is worth the risk.",
			"Even the glacier-warden bends now. The snow has chosen a warmer master.",
		},
	}),
	family({
		id = "lords",
		name = "The Asura Lords",
		members = { "Mahishasura", "Tarakasura", "Kumbhakarna", "Hiranyakashipu", "Bakasura", "Vritra", "Kalanemi" },
		tiers = { 3, 15, 60 },
		lore = {
			"The rabble serve lords, and the lords are older than kingdoms. You have begun collecting them.",
			"Fifteen crowns broken. The old courts convene about you now; attendance is poor and getting poorer.",
			"Sixty lords. Child — when the histories of this age are sung, I fear you will be the CHORUS.",
		},
	}),
} :: { FamilyDef }

-- One-time bounty per tier turned (paid on claim, like the Kirti ledger).
Grantha.TierReward = { 150, 400, 1000 }

-- Reverse lookup, built once: archetype id -> family id.
local familyByMember: { [string]: string } = {}
for _, def in Grantha.Families do
	for _, member in def.members do
		familyByMember[member] = def.id
	end
end

-- Total pages turned across every family, from a per-family kill map.
function Grantha.totalTurned(killsByFamily: { [string]: number }): number
	local total = 0
	for _, def in Grantha.Families do
		total += Grantha.tierFor(def, killsByFamily[def.id] or 0)
	end
	return total
end

-- The most pages the book can hold (families x three tiers).
Grantha.MaxTurned = #Grantha.Families * 3

function Grantha.familyOf(archetypeId: string): string?
	return familyByMember[archetypeId]
end

function Grantha.get(familyId: string): FamilyDef?
	for _, def in Grantha.Families do
		if def.id == familyId then
			return def
		end
	end
	return nil
end

-- How many pages a kill count has turned (0..3).
function Grantha.tierFor(def: FamilyDef, kills: number): number
	local tier = 0
	for i, threshold in def.tiers do
		if kills >= threshold then
			tier = i
		end
	end
	return tier
end

export type Owed = {
	tiers: number,
	gold: number,
}

-- What the ledger owes: every earned tier above what was already claimed.
function Grantha.owedFor(def: FamilyDef, kills: number, claimedTier: number): Owed
	local earned = Grantha.tierFor(def, kills)
	claimedTier = math.clamp(math.floor(claimedTier), 0, #def.tiers)
	local owed: Owed = { tiers = 0, gold = 0 }
	for tier = claimedTier + 1, earned do
		owed.tiers += 1
		owed.gold += Grantha.TierReward[tier] or 0
	end
	return owed
end

return Grantha
