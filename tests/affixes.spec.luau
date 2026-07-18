--!strict
-- Headless tests for affixes: the defs, the roll gates, the tag, the twins.

local process = require("@lune/process")
local Affixes = require("../src/shared/Affixes")
local EnemyTypes = require("../src/shared/EnemyTypes")

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

print("Affixes")

-- Defs.
local defsOk = true
local seen: { [string]: boolean } = {}
for _, id in Affixes.Order do
	local def = Affixes.Defs[id]
	if not def or def.id ~= id or seen[id] or #def.name == 0 or #def.line == 0 or #def.glow ~= 3 then
		defsOk = false
	end
	seen[id] = true
end
check("three affixes, well-formed", defsOk and #Affixes.Order == 3)
check("the ward has real charges", (Affixes.Defs.shielded.shieldCharges or 0) >= 2)
check("vengeance is fierce but bounded", (Affixes.Defs.vengeful.enrageDamageMult or 0) > 1 and (Affixes.Defs.vengeful.enrageDamageMult or 99) <= 1.5)

-- Roll gates.
check("bosses never carry an affix", Affixes.roll(50, true, seq({ 0, 0 })) == nil)
check("early waves stay clean", Affixes.roll(Affixes.Config.MinWave - 1, false, seq({ 0, 0 })) == nil)
check("losing the roll marks nothing", Affixes.roll(20, false, seq({ 0.99 })) == nil)
check("a won roll picks from the order", Affixes.roll(20, false, seq({ 0, 0 })) == "shielded")
check("a high pick lands the last", Affixes.roll(20, false, seq({ 0, 0.999 })) == "vengeful")

-- The tag: immutable, stats untouched, mark carried.
local base = EnemyTypes.get("Asura")
local marked = Affixes.tag(base, "shielded")
check("the tag copies, never mutates", base ~= marked and (base :: any).affix == nil)
check("the tag carries the mark, stats untouched", (marked :: any).affix == "shielded" and marked.maxHealth == base.maxHealth and marked.attackDamage == base.attackDamage)

-- The twins: lesser, unmarked, never wave-blocking piñatas.
local twin = Affixes.twinOf(marked)
check("twins are half the foe", twin.maxHealth == math.floor(base.maxHealth / 2))
check("twins pay a third the bounty", twin.xpReward == math.floor(base.xpReward / 3))
check("twins carry no affix of their own", (twin :: any).affix == nil and (twin :: any).isTwinChild == true)
check("twins shrink a little", twin.scale < base.scale)
check("even a sliver of foe twins to at least 1 hp", Affixes.twinOf({ maxHealth = 1, xpReward = 1, scale = 1 }).maxHealth >= 1)

print(string.format("\n%d passed, %d failed", passed, failed))
if failed > 0 then
	print("FAILURES: " .. table.concat(failures, ", "))
	process.exit(1)
end
