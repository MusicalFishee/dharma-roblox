--!strict
-- Mantras (enchants): catalog sanity, the sub-1% mythic promise, weighted rolling,
-- shard economy, and effect-value sanity.

local process = require("@lune/process")
local Enchants = require("../src/shared/Enchants")

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

print("Enchants")

local list = Enchants.List
check("there are mantras to roll", #list >= 5)

-- Catalog shape.
local ids: { [string]: boolean } = {}
local unique, named, raritiesOk, weightsOk = true, true, true, true
local total = 0
local allowedRarity = { common = true, rare = true, mythic = true }
for _, e in list do
	if ids[e.id] then
		unique = false
	end
	ids[e.id] = true
	if e.name == "" or e.desc == "" then
		named = false
	end
	if not allowedRarity[e.rarity] then
		raritiesOk = false
	end
	if e.weight <= 0 then
		weightsOk = false
	end
	total += e.weight
end
check("mantra ids are unique", unique)
check("every mantra has a name and a description", named)
check("every rarity is known", raritiesOk)
check("every weight is positive", weightsOk)
check("every rarity has a display colour", Enchants.RarityColor.common ~= nil and Enchants.RarityColor.rare ~= nil and Enchants.RarityColor.mythic ~= nil)

-- The <1% promise, and mythic exclusives.
local mythicCount = 0
local mythicUnderOnePercent = true
local aurasOnlyOnMythics = true
local mythicsHaveAuras = true
local allowedAura = { fire = true, sparkles = true }
for _, e in list do
	if e.rarity == "mythic" then
		mythicCount += 1
		if e.weight / total >= 0.01 then
			mythicUnderOnePercent = false
		end
		if not (e.effect.aura and allowedAura[e.effect.aura] and e.effect.auraColor and #e.effect.auraColor == 3) then
			mythicsHaveAuras = false
		end
	else
		if e.effect.aura ~= nil then
			aurasOnlyOnMythics = false
		end
	end
end
check("there are mythic mantras to dream about", mythicCount >= 2)
check("every mythic sits under 1%", mythicUnderOnePercent)
check("every mythic wears a custom aura (known type + rgb)", mythicsHaveAuras)
check("auras are mythic-exclusive", aurasOnlyOnMythics)

-- Lookups.
local first = list[1]
check("get() finds a real mantra", Enchants.get(first.id) ~= nil)
check("get() misses junk", Enchants.get("frost_walker") == nil)
check("effects('') is inert", next(Enchants.effects("")) == nil)
check("effects(junk) is inert", next(Enchants.effects("frost_walker")) == nil)
check("effects(real) carries the payload", Enchants.effects(first.id) == first.effect)

-- Weighted rolling with injected rng: 0 lands on the first entry, ~1 on the last.
check("roll at rng=0 returns the first mantra", Enchants.roll(function() return 0 end) == list[1].id)
check("roll near rng=1 returns the last mantra", Enchants.roll(function() return 0.9999 end) == list[#list].id)

-- Determinism across the weight table: walk each entry's cumulative midpoint.
local acc = 0
local boundariesOk = true
for _, e in list do
	local mid = (acc + e.weight / 2) / total
	if Enchants.roll(function() return mid end) ~= e.id then
		boundariesOk = false
	end
	acc += e.weight
end
check("roll maps every weight band to its mantra", boundariesOk)

-- Shard economy.
check("bosses pay shards", Enchants.ShardsPerBossKill > 0)
check("inscription costs shards", Enchants.Cost > 0)
check("a roll is affordable within two boss kills", Enchants.Cost <= Enchants.ShardsPerBossKill * 2)
local ok = Enchants.tryInscribe(Enchants.Cost)
check("exact shards can inscribe", ok.ok and ok.shardsAfter == 0)
check("short shards are refused", Enchants.tryInscribe(Enchants.Cost - 1).reason == "shards")
check("clampShards handles junk", Enchants.clampShards(-5) == 0 and Enchants.clampShards("many") == 0 and Enchants.clampShards(7.9) == 7)

-- Effect values stay sane (a bad tuning here silently breaks combat).
local valuesSane = true
for _, e in list do
	local f = e.effect
	if f.lifesteal and (f.lifesteal <= 0 or f.lifesteal >= 1) then
		valuesSane = false
	end
	if f.damageTakenMult and (f.damageTakenMult <= 0 or f.damageTakenMult >= 1) then
		valuesSane = false
	end
	if f.executeThreshold and (f.executeThreshold <= 0 or f.executeThreshold > 0.5) then
		valuesSane = false
	end
	if f.tejasMult and f.tejasMult <= 1 then
		valuesSane = false
	end
	if f.dodgeBonus and f.dodgeBonus <= 0 then
		valuesSane = false
	end
	if f.critMultiplier and f.critMultiplier <= 2 then
		valuesSane = false -- must beat the default crit, or the mythic is a downgrade
	end
	if f.procChance and (f.procChance <= 0 or f.procChance >= 1) then
		valuesSane = false
	end
	if f.burnDamage and (f.burnDamage <= 0 or not f.burnSeconds or f.burnSeconds <= 0) then
		valuesSane = false
	end
	if f.bonusGoldPerKill and f.bonusGoldPerKill <= 0 then
		valuesSane = false
	end
end
check("every effect value is in a sane band", valuesSane)

print(string.format("\n%d passed, %d failed", passed, failed))
if failed > 0 then
	print("FAILURES: " .. table.concat(failures, ", "))
	process.exit(1)
end
