--!strict
-- Bandit-beater wave composition — how many enemies, which mix, and the clear reward.
-- Pure logic; the roster is injected (dependency-free) so it stays Lune-testable.

local Waves = {}

-- Minimal shape the composer needs from an enemy archetype.
export type RosterEntry = {
	weight: number,
	maxHealth: number,
}

-- Enemies in a given wave — grows steadily, capped so it never melts a phone.
function Waves.enemyCount(wave: number): number
	return math.min(3 + math.floor((wave - 1) * 1.2), 18)
end

-- Bonus XP awarded to everyone when a wave is cleared.
function Waves.bonusXp(wave: number): number
	return 40 + wave * 20
end

-- Seconds of breather between waves.
Waves.Intermission = 5

-- A boss shows up every Nth wave.
Waves.BossInterval = 5

function Waves.isBossWave(wave: number): boolean
	return wave > 0 and wave % Waves.BossInterval == 0
end

-- Picks the archetype ids for a wave. Tougher enemies get likelier the deeper you go.
-- `rng` returns [0, 1) (defaults to math.random); injectable for deterministic tests.
function Waves.compose(
	wave: number,
	roster: { [string]: RosterEntry },
	rng: (() -> number)?
): { string }
	local roll: () -> number = rng or function()
		return math.random()
	end

	-- Weighted table: base weight, boosted for high-health enemies at higher waves.
	local ids: { string } = {}
	local weights: { number } = {}
	local total = 0
	for id, a in roster do
		local toughness = a.maxHealth / 100
		local w: number
		if toughness > 1.2 then
			-- Heavy bruisers ramp in: absent the first couple of waves, common late.
			w = a.weight * math.clamp((wave - 2) * 0.25, 0, 3)
		else
			w = a.weight
		end
		if w > 0 then
			total += w
			table.insert(ids, id)
			table.insert(weights, w)
		end
	end

	local result: { string } = {}
	if #ids == 0 or total <= 0 then
		return result
	end

	local count = Waves.enemyCount(wave)
	for _ = 1, count do
		local r = roll() * total
		local acc = 0
		local chosen = ids[1]
		for i, id in ids do
			acc += weights[i]
			if r <= acc then
				chosen = id
				break
			end
		end
		table.insert(result, chosen)
	end
	return result
end

return Waves
