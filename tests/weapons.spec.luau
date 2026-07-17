--!strict
-- Weapon catalog: identity, tier ladder (damage + look), pricing, upgrade gating.

local process = require("@lune/process")
local Weapons = require("../src/shared/Weapons")

local passed, failed = 0, 0
local failures: { string } = {}
local function check(name: string, cond: boolean)
	if cond then
		passed += 1
		print("  ok   " .. name)
	else
		failed += 1
		table.insert(failures, name)
		print("  FAIL " .. name)
	end
end

local function near(a: number, b: number): boolean
	return math.abs(a - b) < 1e-6
end

print("Weapons")

-- Catalog shape.
check("there are weapons to choose", #Weapons.List >= 2)
check("MaxTier matches the tier template length", Weapons.MaxTier == #Weapons.TierTemplate)
check("MinTier is 1", Weapons.MinTier == 1)
check("tier step is a real boost", Weapons.TierStep > 0)

local ids: { [string]: boolean } = {}
local idsUnique, shapesKnown, coloursOk = true, true, true
for _, w in Weapons.List do
	if ids[w.id] then
		idsUnique = false
	end
	ids[w.id] = true
	if not Weapons.Shapes[w.shape] then
		shapesKnown = false
	end
	if #w.bladeColor ~= 3 or #w.glowColor ~= 3 then
		coloursOk = false
	end
	if w.displayName == "" or w.title == "" or w.description == "" then
		coloursOk = false
	end
end
check("weapon ids are unique", idsUnique)
check("every weapon has a known silhouette", shapesKnown)
check("every weapon has rgb colours + copy", coloursOk)

-- Tier template escalates (scale grows, glow never falls, names present).
local scaleGrows, glowNonDecreasing, tierNamed = true, true, true
for i, look in Weapons.TierTemplate do
	if look.name == "" then
		tierNamed = false
	end
	if i > 1 then
		if look.scale <= Weapons.TierTemplate[i - 1].scale then
			scaleGrows = false
		end
		if look.glow < Weapons.TierTemplate[i - 1].glow then
			glowNonDecreasing = false
		end
	end
end
check("weapon grows larger each tier", scaleGrows)
check("weapon glow never regresses", glowNonDecreasing)
check("every tier has a name", tierNamed)

-- Lookups.
local first = Weapons.List[1]
check("get() finds a real weapon", Weapons.get(first.id) ~= nil)
check("get() misses an unknown id", Weapons.get("spork") == nil)
check("isValidId agrees", Weapons.isValidId(first.id) and not Weapons.isValidId("spork") and not Weapons.isValidId(42))

-- Damage: rises with tier; unknown weapon deals plain damage (playable before choosing).
check("tier 1 damage = base identity", near(Weapons.damageMult(first.id, 1), first.baseDamageMult))
check(
	"max tier beats tier 1",
	Weapons.damageMult(first.id, Weapons.MaxTier) > Weapons.damageMult(first.id, 1)
)
check("unknown/unarmed deals plain damage", near(Weapons.damageMult("", 1), 1.0))
check("tier clamps high", near(Weapons.damageMult(first.id, 999), Weapons.damageMult(first.id, Weapons.MaxTier)))

-- Pricing + upgrade gating.
check("price rises with tier", Weapons.price(1) < Weapons.price(2))
check("no price past max", Weapons.price(Weapons.MaxTier) == math.huge)
local rich = Weapons.tryUpgrade(999999, 1)
check("rich player can upgrade", rich.ok and rich.goldAfter == 999999 - Weapons.price(1))
check("poor player is blocked on gold", Weapons.tryUpgrade(0, 1).reason == "gold")
check("maxed weapon is blocked", Weapons.tryUpgrade(999999, Weapons.MaxTier).reason == "max")

-- Tier names + visuals.
check("tierName reads « Iron <weapon> » at tier 1", Weapons.tierName(first.id, 1) == Weapons.TierTemplate[1].name .. " " .. first.displayName)
check("tierName for unknown is Unarmed", Weapons.tierName("spork", 1) == "Unarmed")
local vis = Weapons.visual(first.id, Weapons.MaxTier)
check("visual carries shape/material/scale/glow", vis ~= nil and vis.shape == first.shape and vis.material ~= "" and vis.scale > 0)
check("visual for unknown weapon is nil", Weapons.visual("spork", 1) == nil)

-- clampTier for persisted values.
check("clampTier floors into range", Weapons.clampTier(3.9) == 3 and Weapons.clampTier(0) == 1 and Weapons.clampTier(99) == Weapons.MaxTier)
check("clampTier tolerates junk", Weapons.clampTier("big") == 1 and Weapons.clampTier(0 / 0) == 1)


-- Signatures: every weapon plays differently, and no signature is empty.
local sigOk = true
local identityCount = 0
for _, weapon in Weapons.List do
	local sig = Weapons.signatureOf(weapon.id)
	if #sig.line == 0 then
		sigOk = false
	end
	local identities = 0
	if sig.critDamageBonus > 0 then identities += 1 end
	if sig.reachBonus > 0 then identities += 1 end
	if sig.finisherKnockbackMult > 1 then identities += 1 end
	if sig.tejasPerHitBonus > 0 then identities += 1 end
	if sig.critChanceBonus > 0 then identities += 1 end
	if sig.finisherDamageMult > 1 then identities += 1 end
	if sig.dodgeBonusSeconds > 0 then identities += 1 end
	if sig.damageTakenMult < 1 then identities += 1 end
	if sig.lifesteal > 0 then identities += 1 end
	if identities ~= 1 then
		sigOk = false -- exactly ONE identity each: signatures, not stat soup
	end
	identityCount += identities
end
check("every weapon carries exactly one signature", sigOk and identityCount == #Weapons.List)
local bare = Weapons.signatureOf("")
check("empty hands carry no signature", bare.critDamageBonus == 0 and bare.reachBonus == 0 and bare.finisherKnockbackMult == 1 and bare.tejasPerHitBonus == 0 and bare.critChanceBonus == 0 and bare.finisherDamageMult == 1 and bare.dodgeBonusSeconds == 0 and bare.damageTakenMult == 1 and bare.lifesteal == 0)

-- The armory: four starters, five earned by deed.
local function usnap(over: { [string]: number }): Weapons.UnlockSnapshot
	local out: Weapons.UnlockSnapshot = { kills = 0, bossKills = 0, trials = 0, revives = 0, raidClears = 0 }
	for k, v in over do
		(out :: any)[k] = v
	end
	return out
end
check("the roster is nine strong", #Weapons.List == 9)
check("exactly four starters", #Weapons.starters() == 4)
local unlockKinds = { kills = true, bossKills = true, trials = true, revives = true, raidClears = true }
local unlocksOk = true
for _, def in Weapons.List do
	if def.unlock then
		if not unlockKinds[def.unlock.kind] or def.unlock.threshold <= 0 or #def.unlock.label == 0 then
			unlocksOk = false
		end
	end
end
check("every earned weapon names a real deed", unlocksOk)
check("starters are always unlocked", Weapons.isUnlocked("khanda", usnap({})) and Weapons.isUnlocked("chakram", usnap({})))
check("the katar waits for its five hundred", not Weapons.isUnlocked("katar", usnap({ kills = 499 })) and Weapons.isUnlocked("katar", usnap({ kills = 500 })))
check("the parashu waits on the lords", not Weapons.isUnlocked("parashu", usnap({ bossKills = 24 })) and Weapons.isUnlocked("parashu", usnap({ bossKills = 25 })))
check("the urumi answers the trial", Weapons.isUnlocked("urumi", usnap({ trials = 1 })))
check("the danda honors the lifter", Weapons.isUnlocked("danda", usnap({ revives = 10 })) and not Weapons.isUnlocked("danda", usnap({ kills = 99999 })))
check("the moon-blade demands the king", not Weapons.isUnlocked("chandrahasa", usnap({})) and Weapons.isUnlocked("chandrahasa", usnap({ raidClears = 1 })))
check("junk ids are never unlocked", not Weapons.isUnlocked("excalibur", usnap({ kills = 999999 })))
check("earned blades climb the same tier ladder", Weapons.damageMult("parashu", 5) > Weapons.damageMult("parashu", 1))
check("khanda cuts deeper crits", Weapons.signatureOf("khanda").critDamageBonus == 0.25)
check("trishula outreaches the rest", Weapons.signatureOf("trishula").reachBonus > 0)
check("gada hurls hardest", Weapons.signatureOf("gada").finisherKnockbackMult > 1.5)
check("chakram spins tejas", Weapons.signatureOf("chakram").tejasPerHitBonus == 1)

print(string.format("\n%d passed, %d failed", passed, failed))
if failed > 0 then
	print("FAILURES: " .. table.concat(failures, ", "))
	process.exit(1)
end
