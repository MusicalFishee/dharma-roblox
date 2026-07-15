--!strict
-- Milestone rewards: clearing a landmark wave pays a fat gold bounty and confers a
-- title to wear as bragging rights. Pure data + lookup (Lune-testable); the wave
-- director grants the payout on wave clear. Milestones land on boss waves so the
-- reward rides in on the spectacle you just earned.

local Milestones = {}

export type Milestone = {
	wave: number,
	title: string,
	gold: number,
}

Milestones.List = {
	{ wave = 10, title = "Bandit-Breaker", gold = 500 },
	{ wave = 25, title = "Rakshasa-Slayer", gold = 2500 },
	{ wave = 50, title = "Dharmapala", gold = 8000 },
	{ wave = 100, title = "Avatar of the Age", gold = 25000 },
} :: { Milestone }

-- The milestone sitting exactly at this wave, if any.
function Milestones.forWave(wave: number): Milestone?
	for _, m in Milestones.List do
		if m.wave == wave then
			return m
		end
	end
	return nil
end

return Milestones
