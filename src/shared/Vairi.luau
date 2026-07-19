--!strict
-- The Vairi: the grudge that walks. The demon whose blow BESTS you does not
-- forget — it crosses the dark between sessions wearing your name as a
-- title ("Vetala, Bane of Adi"), stalks your ordinary waves, and only YOUR
-- hand can pay the debt. Another player's kill merely delays it; your own
-- death to it feeds it, and it returns crueler. Lords are never grudge-peers
-- (a god's lesson is not a rivalry). Pure grudge math (Lune-tested);
-- VairiService keeps the ledger and springs the hunts.

local Vairi = {}

Vairi.Config = {
	Chance = 0.25, -- per ordinary wave that a held grudge comes hunting
	MaxCount = 10, -- a grudge can only grow so monstrous
}

Vairi.Lines = {
	marked = "will remember this",
	stalks = "has crossed the dark to find you",
	felled = "THE DEBT IS PAID",
	stolen = "Another hand took your debt. The grudge stands.",
}

-- The grudge made flesh: the base demon, swollen by every time it has
-- bested you, wearing the hunted's name. Returns a COPY; the roster is
-- never touched, and bloodline curfews mean nothing to a grudge.
function Vairi.of(archetype: any, count: number, huntedName: string): any
	count = math.clamp(count, 1, Vairi.Config.MaxCount)
	local grudge = table.clone(archetype)
	grudge.displayName = string.format("%s, Bane of %s", tostring(archetype.displayName), huntedName)
	grudge.maxHealth = math.floor(archetype.maxHealth * (2 + 0.5 * (count - 1)))
	grudge.attackDamage = math.floor(archetype.attackDamage * (1.15 + 0.05 * count))
	grudge.xpReward = math.floor(archetype.xpReward * 2.5)
	grudge.walkSpeed = archetype.walkSpeed + 1
	grudge.scale = archetype.scale * 1.2
	grudge.isElite = true
	grudge.minWave = nil
	return grudge
end

export type Bounty = {
	gold: number,
	shards: number,
}

-- Paying the debt: worth more the longer the grudge has fed.
function Vairi.bountyFor(count: number): Bounty
	count = math.clamp(count, 1, Vairi.Config.MaxCount)
	return {
		gold = 250 + 150 * (count - 1),
		shards = 2,
	}
end

return Vairi
