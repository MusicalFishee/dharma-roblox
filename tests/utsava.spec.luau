--!strict
-- Headless tests for Utsava world events: def integrity and roll gating.

local process = require("@lune/process")
local Utsava = require("../src/shared/Utsava")

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

-- Replays a fixed rng sequence (roll consumes: chance, then weighted pick).
local function seq(values: { number }): () -> number
	local i = 0
	return function()
		i += 1
		return values[math.min(i, #values)]
	end
end

print("Utsava")

-- Def integrity.
local defsOk = true
local orderSeen: { [string]: boolean } = {}
for _, id in Utsava.Order do
	local def = Utsava.Events[id]
	if not def or def.id ~= id or orderSeen[id] or def.duration <= 0 or def.weight <= 0 or #def.name == 0 or #def.announce == 0 then
		defsOk = false
	end
	orderSeen[id] = true
end
local defCount = 0
for _ in Utsava.Events do
	defCount += 1
end
check("events are well-formed", defsOk)
check("order covers every event once", defCount == #Utsava.Order)

check("five festivals on the calendar", #Utsava.Order == 5)
check("the rishi blesses with real xp", Utsava.Rishi.xp > 0)
check("the peddler undercuts the vaidya per shard", Utsava.Peddler.price / Utsava.Peddler.shards < Utsava.Merchant.price / Utsava.Merchant.shards)
check("the peddler's gamble is real but survivable", Utsava.Peddler.curseChance > 0 and Utsava.Peddler.curseChance < 0.5 and Utsava.Peddler.curseSeconds > 0)
check("deer pays a real bounty", Utsava.Deer.gold > 0 and Utsava.Deer.xp > 0 and Utsava.Deer.shards > 0 and Utsava.Deer.health > 0 and Utsava.Deer.walkSpeed > 16)
check("storm rains on a beat", Utsava.Storm.orbCount > 0 and Utsava.Storm.interval > 0 and Utsava.Storm.shardsPerOrb > 0)
check("storm fits inside its duration", Utsava.Storm.orbCount * Utsava.Storm.interval <= Utsava.Events.shard_storm.duration)
check("vaidya charges real gold", Utsava.Merchant.price > 0 and Utsava.Merchant.shards > 0)

-- Roll gating.
check("special waves never roll", Utsava.roll(10, 0, true, seq({ 0, 0 })) == nil)
check("early waves never roll", Utsava.roll(Utsava.Config.MinWave - 1, -10, false, seq({ 0, 0 })) == nil)
check("cooldown holds between events", Utsava.roll(10, 10 - Utsava.Config.MinGap + 1, false, seq({ 0, 0 })) == nil)
check("cooldown releases at the gap", Utsava.roll(10, 10 - Utsava.Config.MinGap, false, seq({ 0, 0 })) ~= nil)
check("losing the chance roll yields nothing", Utsava.roll(10, 0, false, seq({ 0.99 })) == nil)

-- Weighted pick walks the order.
local first = Utsava.roll(10, 0, false, seq({ 0, 0 }))
check("low roll picks the first event", first ~= nil and first.id == "golden_deer")
local last = Utsava.roll(10, 0, false, seq({ 0, 0.999 }))
check("high roll picks the last event", last ~= nil and last.id == "cursed_merchant")
local mid = Utsava.roll(10, 0, false, seq({ 0, 0.45 }))
check("mid roll lands between", mid ~= nil and mid.id == "shard_storm")

print(string.format("\n%d passed, %d failed", passed, failed))
if failed > 0 then
	print("FAILURES: " .. table.concat(failures, ", "))
	process.exit(1)
end
