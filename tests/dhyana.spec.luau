--!strict
-- Headless tests for the Dhyana grove: the scarcity law, the sangha gates,
-- and the tick math. Idling must NEVER compete with fighting.

local process = require("@lune/process")
local Dhyana = require("../src/shared/Dhyana")
local Waves = require("../src/shared/Waves")
local Streak = require("../src/shared/Streak")

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

print("Dhyana")

local cfg = Dhyana.Config

-- Shape.
check("the grove is close quarters", cfg.GroveRadius > 0 and cfg.GroveRadius <= 20)
check("stillness is required before the grove takes you", cfg.EnterStillSeconds > 0)
check("a tick is a real breath", cfg.TickSeconds >= 30)

-- THE SCARCITY LAW: doing nothing pays like doing nothing.
check("the trickle is a trickle", cfg.GoldPerTick <= 10)
local hourlyGold = math.floor(3600 / cfg.TickSeconds) * cfg.GoldPerTick
check("an hour of stillness pays less than a wave-10 clear's XP number", hourlyGold < Waves.bonusXp(10) * 10)
check("a NIGHT of dhyana pays less than one daily devotion week", hourlyGold * 8 * 2 < Streak.rewardFor(7).gold * 7 * 2 + 4000)
check("shards come slower than hourly", cfg.ShardEveryTicks * cfg.TickSeconds >= 3600)

-- The sangha gates (the alt-killer).
check("the level gate is a real grind for an alt", cfg.SanghaMinLevel >= 10)
check("level 14 counts for nothing", not Dhyana.qualifies(cfg.SanghaMinLevel - 1))
check("level 15 stands in the circle", Dhyana.qualifies(cfg.SanghaMinLevel))

-- Multiplier math.
check("alone is plain", Dhyana.multiplierFor(0) == 1)
check("one friend deepens it", Dhyana.multiplierFor(1) == 1.25)
check("four friends reach the cap", Dhyana.multiplierFor(4) == 2)
check("a crowd cannot pass the cap", Dhyana.multiplierFor(40) == 2)
check("negatives never weaken it", Dhyana.multiplierFor(-3) == 1)

-- Tick math.
local plain = Dhyana.rewardForTick(1, 1)
check("a plain tick pays the trickle", plain.gold == cfg.GoldPerTick and plain.shards == 0)
local blessed = Dhyana.rewardForTick(1, 2)
check("the sangha deepens the gold", blessed.gold == cfg.GoldPerTick * 2)
local shardTick = Dhyana.rewardForTick(cfg.ShardEveryTicks, 2)
check("the shard arrives on its cadence, UNmultiplied", shardTick.shards == 1)
check("the next tick carries no shard", Dhyana.rewardForTick(cfg.ShardEveryTicks + 1, 2).shards == 0)
check("tick zero pays no shard", Dhyana.rewardForTick(0, 1).shards == 0)

print(string.format("\n%d passed, %d failed", passed, failed))
if failed > 0 then
	print("FAILURES: " .. table.concat(failures, ", "))
	process.exit(1)
end
