--!strict
-- Headless tests for Astra Paths: defs, kits, passives, choose/respec gating,
-- and the ability Catalog the kits point into (cross-checked so ids never drift).

local process = require("@lune/process")
local Paths = require("../src/shared/Paths")
local Abilities = require("../src/shared/Abilities")

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

print("Paths")

-- Roster shape.
local orderSeen: { [string]: boolean } = {}
local orderValid = true
for _, id in Paths.Order do
	if orderSeen[id] or not Paths.Defs[id] then
		orderValid = false
	end
	orderSeen[id] = true
end
check("order lists 4 unique valid paths", #Paths.Order == 4 and orderValid)

local defCount = 0
for _ in Paths.Defs do
	defCount += 1
end
check("every def is in the order", defCount == #Paths.Order)

local idsMatch = true
for id, def in Paths.Defs do
	if def.id ~= id then
		idsMatch = false
	end
end
check("def ids match their keys", idsMatch)

-- Kits point at real catalog abilities, with the right shapes per slot.
local kitsValid = true
local ultsCostFullBar = true
local dashesHaveIFrames = true
local zAreProjectiles = true
for _, id in Paths.Order do
	local kit = Paths.Defs[id].kit
	for _, slot in { "Z", "X", "C", "V" } do
		local def = Abilities.Catalog[(kit :: any)[slot]]
		if not def then
			kitsValid = false
		end
	end
	local z = Abilities.Catalog[kit.Z]
	local x = Abilities.Catalog[kit.X]
	local v = Abilities.Catalog[kit.V]
	if z and z.kind ~= "projectile" then
		zAreProjectiles = false
	end
	if x and (x.kind ~= "dash" or (x.iFrames or 0) <= 0) then
		dashesHaveIFrames = false
	end
	if v and v.tejasCost ~= 100 then
		ultsCostFullBar = false
	end
end
check("every kit slot resolves in the catalog", kitsValid)
check("every Z is a projectile", zAreProjectiles)
check("every X is a dash with i-frames", dashesHaveIFrames)
check("every ultimate costs a full bar", ultsCostFullBar)

-- The unsworn default kit is the classic mix and resolves too.
check("default kit resolves in the catalog", Abilities.Catalog[Paths.DefaultKit.Z] ~= nil and Abilities.Catalog[Paths.DefaultKit.X] ~= nil and Abilities.Catalog[Paths.DefaultKit.C] ~= nil and Abilities.Catalog[Paths.DefaultKit.V] ~= nil)
check("kitFor falls back to the classic mix", Paths.kitFor("").Z == "agni_astra" and Paths.kitFor("junk").V == "indra_wrath")
check("kitFor returns the sworn kit", Paths.kitFor("vayu").X == "gale_step")

-- The classic slot Config and the catalog originals must not drift.
check("Z config mirrors agni_astra", Abilities.Config.Z.power == Abilities.Catalog.agni_astra.power and Abilities.Config.Z.tejasCost == Abilities.Catalog.agni_astra.tejasCost and Abilities.Config.Z.cooldown == Abilities.Catalog.agni_astra.cooldown)
check("X config mirrors vayu_dash", Abilities.Config.X.power == Abilities.Catalog.vayu_dash.power and Abilities.Config.X.tejasCost == Abilities.Catalog.vayu_dash.tejasCost)
check("C config mirrors varuna_grace", Abilities.Config.C.power == Abilities.Catalog.varuna_grace.power and Abilities.Config.C.tejasCost == Abilities.Catalog.varuna_grace.tejasCost)
check("V config mirrors indra_wrath", Abilities.Config.V.power == Abilities.Catalog.indra_wrath.power and Abilities.Config.V.radius == Abilities.Catalog.indra_wrath.radius)

-- Catalog integrity.
local kinds = { projectile = true, dash = true, heal = true, ward = true, nova = true, smite = true }
local catalogValid = true
local colorsValid = true
for id, def in Abilities.Catalog do
	if def.id ~= id or not kinds[def.kind] or def.tejasCost <= 0 or def.cooldown <= 0 or def.power <= 0 or #def.line == 0 then
		catalogValid = false
	end
	if def.kind == "projectile" and (def.speed or 0) <= 0 then
		catalogValid = false
	end
	if def.kind == "ward" and ((def.duration or 0) <= 0 or (def.wardKind ~= "shield" and def.wardKind ~= "empower")) then
		catalogValid = false
	end
	if (def.kind == "nova" or def.kind == "smite") and (def.radius or 0) <= 0 then
		catalogValid = false
	end
	if #def.color ~= 3 then
		colorsValid = false
	else
		for _, c in def.color do
			if type(c) ~= "number" or c < 0 or c > 255 then
				colorsValid = false
			end
		end
	end
end
check("catalog defs are well-formed", catalogValid)
check("catalog colors are {r,g,b} 0..255", colorsValid)

-- Passives: neutral fallback + sane bounds.
local neutral = Paths.passiveOf("")
check("unsworn passive is neutral", neutral.damageMult == 1 and neutral.healthBonus == 0 and neutral.speedMult == 1 and neutral.tejasMult == 1 and neutral.dodgeBonusSeconds == 0)

local boundsOk = true
for _, id in Paths.Order do
	local p = Paths.Defs[id].passive
	if p.damageMult < 1 or p.damageMult > 1.25 then
		boundsOk = false
	end
	if p.speedMult < 1 or p.speedMult > 1.25 then
		boundsOk = false
	end
	if p.healthBonus < 0 or p.healthBonus > 100 then
		boundsOk = false
	end
	if p.tejasMult < 1 or p.tejasMult > 1.5 then
		boundsOk = false
	end
	if p.dodgeBonusSeconds < 0 or p.dodgeBonusSeconds > 0.3 then
		boundsOk = false
	end
end
check("passive magnitudes stay in bounds", boundsOk)

-- Choose / respec gating.
local unknown = Paths.tryChoose("", "zeus", 9999)
check("unknown path rejected", not unknown.ok and unknown.reason == "unknown")

local same = Paths.tryChoose("agni", "agni", 9999)
check("re-choosing your own path rejected", not same.ok and same.reason == "same")

local first = Paths.tryChoose("", "agni", 0)
check("first oath is free", first.ok and first.goldAfter == 0)

local poor = Paths.tryChoose("agni", "vayu", Paths.RespecCost - 1)
check("respec blocked without gold", not poor.ok and poor.reason == "gold" and poor.goldAfter == Paths.RespecCost - 1)

local respec = Paths.tryChoose("agni", "vayu", Paths.RespecCost + 100)
check("respec deducts the cost", respec.ok and respec.goldAfter == 100)

-- Catalog cast gating (id-keyed twin of tryCast).
local ok = Abilities.tryCastAbility("gale_step", 50, -100, 0)
check("catalog cast succeeds off cooldown", ok.ok and ok.tejasAfter == 50 - Abilities.Catalog.gale_step.tejasCost)

local cd = Abilities.tryCastAbility("gale_step", 50, 0, 1.0)
check("catalog cast blocked on cooldown", not cd.ok and cd.reason == "cooldown")

local brokeCheck = Abilities.tryCastAbility("tempest", 60, -100, 0)
check("catalog cast blocked without tejas", not brokeCheck.ok and brokeCheck.reason == "tejas")

local unknownAbility = Abilities.tryCastAbility("meteor", 100, -100, 0)
check("unknown catalog id rejected", not unknownAbility.ok and unknownAbility.reason == "unknown")

print(string.format("\n%d passed, %d failed", passed, failed))
if failed > 0 then
	print("FAILURES: " .. table.concat(failures, ", "))
	process.exit(1)
end
