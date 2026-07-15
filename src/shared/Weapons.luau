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
	bladeColor: { number }, -- {r, g, b}
	glowColor: { number }, -- {r, g, b} used once the blade goes neon
}

Weapons.Shapes = { blade = true, trident = true, mace = true, discus = true } :: { [string]: boolean }

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

return Weapons
