--!strict
-- Headless tests for Bhava stances: the balance, the trades, and the law
-- that no posture dominates.

local process = require("@lune/process")
local Bhava = require("../src/shared/Bhava")

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

print("Bhava")

local sama = Bhava.effectsOf("sama")
check("sama is perfect balance", sama.damageMult == 1 and sama.damageTakenMult == 1 and sama.tejasMult == 1)

-- THE LAW: every stance pays for what it grants.
local lawHolds = true
for id, def in Bhava.Defs do
	if id == "sama" then
		continue
	end
	local fx = def.effects
	local grants = fx.damageMult > 1 or fx.damageTakenMult < 1 or fx.tejasMult > 1
	local pays = fx.damageMult < 1 or fx.damageTakenMult > 1
	if not (grants and pays) then
		lawHolds = false
		print("    !! stance dominates or does nothing: " .. id)
	end
end
check("no posture dominates — every gift has a price", lawHolds)

-- The wheel.
check("the wheel starts at balance", Bhava.Order[1] == "sama")
check("the wheel turns in order", Bhava.next("sama") == "raudra" and Bhava.next("raudra") == "sthira" and Bhava.next("sthira") == "pravaha")
check("the wheel comes home", Bhava.next("pravaha") == "sama")
check("the unknown returns home", Bhava.next("junk") == "sama" and Bhava.get("junk").id == "sama")

-- Well-formedness.
local wellFormed = true
local seen = 0
for _, id in Bhava.Order do
	local def = Bhava.Defs[id]
	if not def or def.id ~= id or #def.name == 0 or #def.line == 0 or #def.glyph == 0 or #def.color ~= 3 then
		wellFormed = false
	end
	seen += 1
end
local total = 0
for _ in Bhava.Defs do
	total += 1
end
check("the wheel covers every posture once", wellFormed and seen == total)

-- Identity reads.
check("raudra is the glass hammer", Bhava.effectsOf("raudra").damageMult > 1 and Bhava.effectsOf("raudra").damageTakenMult > 1)
check("sthira is the patient stone", Bhava.effectsOf("sthira").damageTakenMult < 1 and Bhava.effectsOf("sthira").damageMult < 1)
check("pravaha floods the bar", Bhava.effectsOf("pravaha").tejasMult > 1 and Bhava.effectsOf("pravaha").damageTakenMult > 1)

print(string.format("\n%d passed, %d failed", passed, failed))
if failed > 0 then
	print("FAILURES: " .. table.concat(failures, ", "))
	process.exit(1)
end
