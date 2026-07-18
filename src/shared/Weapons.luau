--!strict
-- Weapons: the armament you choose once at the start and then pour gold into. Each
-- weapon shares one upgrade ladder (5 tiers); every tier hits harder AND looks cooler
-- (iron -> tempered -> blessed gold -> celestial neon -> divine blaze). Pure data +
-- math so prices, damage and tier names are Lune-tested; WeaponService builds the model.

local Weapons = {}

-- Per-tier LOOK + feel, shared across every weapon. The weapon supplies its own
-- colours and silhouette; the tier supplies material, size and glow. Index = tier.
export type TierLook = {
	name: string,
	material: string,
	scale: number,
	glow: number, -- 0 = dull metal, 1 = blazing neon (drives Neon + PointLight)
}

Weapons.TierTemplate = {
	{ name = "Iron", material = "Metal", scale = 1.00, glow = 0.0 },
	{ name = "Tempered", material = "Metal", scale = 1.08, glow = 0.0 },
	{ name = "Blessed", material = "Foil", scale = 1.16, glow = 0.4 },
	{ name = "Celestial", material = "Neon", scale = 1.27, glow = 0.75 },
	{ name = "Divine", material = "Neon", scale = 1.42, glow = 1.0 },
} :: { TierLook }

Weapons.MaxTier = #Weapons.TierTemplate
Weapons.MinTier = 1

-- +10% damage per tier, on top of the weapon's own identity multiplier.
Weapons.TierStep = 0.10
-- Upgrade pricing (gold to buy the NEXT tier).
Weapons.UpgradeBasePrice = 150
Weapons.PriceGrowth = 1.8

export type Weapon = {
	id: string,
	displayName: string,
	title: string,
	description: string,
	shape: string, -- "blade" | "trident" | "mace" | "discus"
	baseDamageMult: number, -- weapon identity (heavy hits harder, swift a touch less)
	unlock: UnlockDef?, -- nil = starter (offered at the first choice)
	bladeColor: { number }, -- {r, g, b}
	glowColor: { number }, -- {r, g, b} used once the blade goes neon
}

Weapons.Shapes = { blade = true, trident = true, mace = true, discus = true,
	axe = true, -- Parashu
	staff = true, -- Danda
} :: { [string]: boolean }

export type UnlockDef = {
	kind: string, -- "kills" | "bossKills" | "trials" | "revives" | "raidClears"
	threshold: number,
	label: string, -- shown on the locked armory row
}

Weapons.List = {
	{
		id = "khanda",
		displayName = "Khanda",
		title = "the Righteous Blade",
		description = "A temple broadsword — balanced, steady, sure in any hand.",
		shape = "blade",
		baseDamageMult = 1.0,
		bladeColor = { 210, 216, 226 },
		glowColor = { 120, 200, 255 },
	},
	{
		id = "trishula",
		displayName = "Trishula",
		title = "Shiva's Reach",
		description = "A three-pronged trident — the longest reach on the field.",
		shape = "trident",
		baseDamageMult = 1.0,
		bladeColor = { 226, 220, 190 },
		glowColor = { 255, 180, 90 },
	},
	{
		id = "gada",
		displayName = "Gada",
		title = "Bhima's Ruin",
		description = "A colossal mace — slow to raise, catastrophic to meet.",
		shape = "mace",
		baseDamageMult = 1.12,
		bladeColor = { 182, 176, 170 },
		glowColor = { 255, 120, 60 },
	},
	{
		id = "chakram",
		displayName = "Chakram",
		title = "Sudarshana's Edge",
		description = "A whirling war-discus — swift, weaving, merciless.",
		shape = "discus",
		baseDamageMult = 0.95,
		bladeColor = { 200, 236, 255 },
		glowColor = { 90, 230, 255 },
	},
	{
		id = "katar",
		displayName = "Katar",
		title = "the Twin Fangs",
		description = "A punch-dagger for those who fight inside the storm.",
		shape = "blade",
		baseDamageMult = 0.98,
		bladeColor = { 200, 190, 170 },
		glowColor = { 255, 120, 90 },
		unlock = { kind = "kills", threshold = 500, label = "Slay 500 demons" },
	},
	{
		id = "parashu",
		displayName = "Parashu",
		title = "the World-Cleaver Axe",
		description = "Parashurama's answer to every argument.",
		shape = "axe",
		baseDamageMult = 1.08,
		bladeColor = { 170, 165, 160 },
		glowColor = { 255, 160, 40 },
		unlock = { kind = "bossKills", threshold = 25, label = "Fell 25 asura lords" },
	},
	{
		id = "urumi",
		displayName = "Urumi",
		title = "the Coiled Serpent",
		description = "The whip-blade of Kalaripayattu — it flows, and so do you.",
		shape = "blade",
		baseDamageMult = 0.95,
		bladeColor = { 216, 210, 200 },
		glowColor = { 130, 255, 180 },
		unlock = { kind = "trials", threshold = 1, label = "Pass the Kirata Trial" },
	},
	{
		id = "danda",
		displayName = "Danda",
		title = "the Staff of the Law",
		description = "The rod that upholds — carried by those who carry others.",
		shape = "staff",
		baseDamageMult = 1.0,
		bladeColor = { 150, 120, 80 },
		glowColor = { 255, 235, 160 },
		unlock = { kind = "revives", threshold = 10, label = "Lift 10 fallen allies" },
	},
	{
		id = "chandrahasa",
		displayName = "Chandrahasa",
		title = "the Moon-Blade of Lanka",
		description = "Ravana's own sword, wrested from his tenth hand.",
		shape = "blade",
		baseDamageMult = 1.02,
		bladeColor = { 190, 205, 230 },
		glowColor = { 170, 210, 255 },
		unlock = { kind = "raidClears", threshold = 1, label = "Fell the Ten-Headed King" },
	},
} :: { Weapon }

local byId: { [string]: Weapon } = {}
for _, w in Weapons.List do
	byId[w.id] = w
end

function Weapons.get(id: string): Weapon?
	return byId[id]
end

function Weapons.isValidId(id: any): boolean
	return type(id) == "string" and byId[id] ~= nil
end

-- Clamp a persisted tier into the valid range.
function Weapons.clampTier(value: any): number
	if type(value) ~= "number" or value ~= value then
		return Weapons.MinTier
	end
	return math.clamp(math.floor(value), Weapons.MinTier, Weapons.MaxTier)
end

-- Damage multiplier for a weapon at a tier. Unknown weapon (e.g. not yet chosen)
-- deals plain damage, so the game is fully playable before you pick.
function Weapons.damageMult(id: string, tier: number): number
	local w = byId[id]
	if not w then
		return 1.0
	end
	local t = Weapons.clampTier(tier)
	return w.baseDamageMult + (t - Weapons.MinTier) * Weapons.TierStep
end

-- Gold to upgrade FROM this tier to the next. huge when already maxed.
function Weapons.price(tier: number): number
	local t = Weapons.clampTier(tier)
	if t >= Weapons.MaxTier then
		return math.huge
	end
	return math.floor(Weapons.UpgradeBasePrice * (Weapons.PriceGrowth ^ (t - Weapons.MinTier)))
end

export type UpgradeResult = {
	ok: boolean,
	reason: string, -- "ok" | "max" | "gold"
	goldAfter: number,
}

function Weapons.tryUpgrade(gold: number, tier: number): UpgradeResult
	local t = Weapons.clampTier(tier)
	if t >= Weapons.MaxTier then
		return { ok = false, reason = "max", goldAfter = gold }
	end
	local cost = Weapons.price(t)
	if gold < cost then
		return { ok = false, reason = "gold", goldAfter = gold }
	end
	return { ok = true, reason = "ok", goldAfter = gold - cost }
end

-- Display name for a weapon at a tier, e.g. "Blessed Khanda".
function Weapons.tierName(id: string, tier: number): string
	local w = byId[id]
	if not w then
		return "Unarmed"
	end
	local t = Weapons.clampTier(tier)
	return Weapons.TierTemplate[t].name .. " " .. w.displayName
end

export type Visual = {
	shape: string,
	bladeColor: { number },
	glowColor: { number },
	material: string,
	scale: number,
	glow: number,
}

-- The full spec WeaponService needs to build the held model at a given tier.
function Weapons.visual(id: string, tier: number): Visual?
	local w = byId[id]
	if not w then
		return nil
	end
	local look = Weapons.TierTemplate[Weapons.clampTier(tier)]
	return {
		shape = w.shape,
		bladeColor = w.bladeColor,
		glowColor = w.glowColor,
		material = look.material,
		scale = look.scale,
		glow = look.glow,
	}
end

-- ---------------------------------------------------------------------------
-- Signatures: what a weapon DOES, beyond what it shows. One identity each.
-- ---------------------------------------------------------------------------

export type Signature = {
	critDamageBonus: number, -- added to the crit multiplier
	reachBonus: number, -- studs added to melee reach
	finisherKnockbackMult: number, -- scales the heavy finisher's shove
	tejasPerHitBonus: number, -- extra Tejas per landed blow
	critChanceBonus: number, -- added to the crit roll
	finisherDamageMult: number, -- scales the heavy finisher's damage
	dodgeBonusSeconds: number, -- added to the dodge i-frame window
	damageTakenMult: number, -- scales damage taken (<1 = warding)
	lifesteal: number, -- fraction of melee damage returned as health
	line: string, -- shown on the weapon card
}

local function sig(over: { [string]: any }): Signature
	local base = {
		critDamageBonus = 0,
		reachBonus = 0,
		finisherKnockbackMult = 1,
		tejasPerHitBonus = 0,
		critChanceBonus = 0,
		finisherDamageMult = 1,
		dodgeBonusSeconds = 0,
		damageTakenMult = 1,
		lifesteal = 0,
		line = "",
	}
	for k, v in over do
		base[k] = v
	end
	return base :: any
end

local SIGNATURES: { [string]: Signature } = {
	khanda = sig({ critDamageBonus = 0.25, line = "Righteous edge: critical strikes cut 25% deeper." }),
	trishula = sig({ reachBonus = 3, line = "Three points: strikes reach 3 studs further." }),
	gada = sig({ finisherKnockbackMult = 1.6, line = "Mountain's weight: finishers hurl foes 60% harder." }),
	chakram = sig({ tejasPerHitBonus = 1, line = "The spinning wheel: +1 Tejas on every landed blow." }),
	katar = sig({ critChanceBonus = 0.04, line = "Twin fangs: +4% critical chance." }),
	parashu = sig({ finisherDamageMult = 1.3, line = "The world-cleaver: finishers strike 30% harder." }),
	urumi = sig({ dodgeBonusSeconds = 0.08, line = "The serpent flows: dodge windows last 0.08s longer." }),
	danda = sig({ damageTakenMult = 0.95, line = "The law upholds: 5% less damage taken." }),
	chandrahasa = sig({ lifesteal = 0.02, line = "The moon-blade drinks: 2% of melee damage returns as health." }),
}

local BARE: Signature = sig({})

-- The signature for a weapon id; empty hands carry none.
function Weapons.signatureOf(id: string): Signature
	return SIGNATURES[id] or BARE
end

-- ---------------------------------------------------------------------------
-- Unlocks: starters are offered at the first choice; the rest are EARNED.
-- ---------------------------------------------------------------------------

export type UnlockSnapshot = {
	kills: number,
	bossKills: number,
	trials: number,
	revives: number,
	raidClears: number,
}

function Weapons.isStarter(id: string): boolean
	local def = Weapons.get(id)
	return def ~= nil and def.unlock == nil
end

-- The four offered at the very first choice.
function Weapons.starters(): { Weapon }
	local out = {}
	for _, def in Weapons.List do
		if def.unlock == nil then
			table.insert(out, def)
		end
	end
	return out
end

local function statFor(kind: string, snap: UnlockSnapshot): number
	if kind == "kills" then
		return snap.kills
	elseif kind == "bossKills" then
		return snap.bossKills
	elseif kind == "trials" then
		return snap.trials
	elseif kind == "revives" then
		return snap.revives
	elseif kind == "raidClears" then
		return snap.raidClears
	end
	return 0
end

-- The kata each weapon signs on its finisher (visual only; signatures own
-- the mechanics). One style per silhouette family.
local KATA_STYLES: { [string]: string } = {
	khanda = "arc",
	trishula = "fan",
	gada = "quake",
	chakram = "orbit",
	katar = "cleave",
	parashu = "cleave",
	urumi = "arc",
	danda = "pillar",
	chandrahasa = "arc",
}

function Weapons.kataStyleOf(id: string): string
	return KATA_STYLES[id] or "arc"
end

-- May this account wield this weapon? Starters always; the rest by deed.
function Weapons.isUnlocked(id: string, snap: UnlockSnapshot): boolean
	local def = Weapons.get(id)
	if not def then
		return false
	end
	if not def.unlock then
		return true
	end
	return statFor(def.unlock.kind, snap) >= def.unlock.threshold
end

return Weapons
