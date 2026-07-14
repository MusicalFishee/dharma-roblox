--!strict
-- Preview of how waves escalate, straight from the real Waves + EnemyTypes modules.
--   run with:  lune run tests/wavedemo

local Waves = require("../src/shared/Waves")
local EnemyTypes = require("../src/shared/EnemyTypes")

math.randomseed(3)
print("=== Dharma — bandit-beater wave escalation ===\n")

for wave = 1, 12 do
	local ids = Waves.compose(wave, EnemyTypes.List :: any)
	local tally: { [string]: number } = {}
	for _, id in ids do
		tally[id] = (tally[id] or 0) + 1
	end
	local parts: { string } = {}
	for id, n in tally do
		table.insert(parts, string.format("%dx %s", n, id))
	end
	print(string.format(
		"Wave %2d:  %2d enemies   [%s]   clear reward +%d XP",
		wave,
		#ids,
		table.concat(parts, ", "),
		Waves.bonusXp(wave)
	))
end
