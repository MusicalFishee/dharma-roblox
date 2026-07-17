--!strict
-- Headless tests for Vara: the boon pool, the draw, the merge, the gate.

local process = require("@lune/process")
local Vara = require("../src/shared/Vara")

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

local function seq(values: { number }): () -> number
	local i = 0
	return function()
		i += 1
		return values[math.min(i, #values)]
	end
end

print("Vara")

-- Pool integrity: one effect key per boon (boons, not stat soup).
check("the pool is twelve boons deep", #Vara.Pool == 12)
local poolOk = true
local ids: { [string]: boolean } = {}
for _, def in Vara.Pool do
	if ids[def.id] or #def.name == 0 or #def.line == 0 then
		poolOk = false
	end
	ids[def.id] = true
	local keys = 0
	for _ in def.effect do
		keys += 1
	end
	if keys ~= 1 then
		poolOk = false
	end
end
check("every boon carries exactly one effect", poolOk)
check("get finds and misses", Vara.get("tikshna") ~= nil and Vara.get("infinite_power") == nil)

-- The draw.
local fresh = Vara.draw({}, seq({ 0, 0, 0 }))
check("a fresh draw offers three", #fresh == 3)
local seen: { [string]: boolean } = {}
local distinct = true
for _, def in fresh do
	if seen[def.id] then
		distinct = false
	end
	seen[def.id] = true
end
check("the offer never repeats itself", distinct)

local owned = {}
for _, def in Vara.Pool do
	table.insert(owned, def.id)
end
check("an exhausted pool offers nothing", #Vara.draw(owned, seq({ 0 })) == 0)

local nearlyAll = {}
for i = 1, #Vara.Pool - 1 do
	table.insert(nearlyAll, Vara.Pool[i].id)
end
local lastOffer = Vara.draw(nearlyAll, seq({ 0 }))
check("a nearly-empty pool offers what remains", #lastOffer == 1 and lastOffer[1].id == Vara.Pool[#Vara.Pool].id)

local excludes = Vara.draw({ "tikshna" }, seq({ 0, 0, 0 }))
local excluded = true
for _, def in excludes do
	if def.id == "tikshna" then
		excluded = false
	end
end
check("held boons never reappear in the offer", excluded)

-- The merge.
local none = Vara.totalEffects({})
check("no boons = identity", none.damageMult == 1 and none.healthBonus == 0 and none.lifesteal == 0 and none.xpMult == 1 and none.damageTakenMult == 1)
local one = Vara.totalEffects({ "tikshna" })
check("one boon applies", math.abs(one.damageMult - 1.08) < 1e-9)
local pair = Vara.totalEffects({ "dhana", "jnana" })
check("flats and mults land in their own lanes", math.abs(pair.goldMult - 1.1) < 1e-9 and math.abs(pair.xpMult - 1.1) < 1e-9 and pair.damageMult == 1)
check("duplicates count once", Vara.totalEffects({ "drdha", "drdha" }).healthBonus == 40)
check("junk ids are skipped", Vara.totalEffects({ "hax" }).damageMult == 1)
local everything = {}
for _, def in Vara.Pool do
	table.insert(everything, def.id)
end
local full = Vara.totalEffects(everything)
check("a full draft is strong but sane", full.damageMult < 1.2 and full.damageTakenMult > 0.85 and full.healthBonus == 40 and full.lifesteal == 0.03)

-- The gate.
check("picks must come from the offer", not Vara.canPick({ "vega" }, {}, "tikshna"))
check("held boons cannot be picked twice", not Vara.canPick({ "vega" }, { "vega" }, "vega"))
check("a clean offered pick passes", Vara.canPick({ "vega", "urja" }, { "tikshna" }, "urja"))
check("junk ids never pass the gate", not Vara.canPick({ "hax" }, {}, "hax"))

print(string.format("\n%d passed, %d failed", passed, failed))
if failed > 0 then
	print("FAILURES: " .. table.concat(failures, ", "))
	process.exit(1)
end
