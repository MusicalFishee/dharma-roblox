--!strict
-- The Dvarapala: the door-keeper's greeting. When a warrior returns, the
-- door tells them — in at most three lines — what the war kept for them:
-- the grudge that waited, and the gold the ledgers owe. Pure line
-- composition (Lune-tested); WelcomeService speaks it after the save lands.

local Welcome = {}

export type Summary = {
	name: string,
	vairiName: string?, -- nil / "" = no grudge held
	vairiCount: number,
	owedYatraGold: number,
	owedKirtiGold: number,
	owedGranthaGold: number,
}

Welcome.MaxLines = 3

function Welcome.lines(s: Summary): { string }
	local out: { string } = { string.format("Welcome back to the war, %s.", s.name) }

	if s.vairiName and #s.vairiName > 0 then
		table.insert(out, string.format("Your vairi still waits — %s, grudge ×%d.", s.vairiName, math.max(s.vairiCount, 1)))
	end

	local owed = math.max(s.owedYatraGold, 0) + math.max(s.owedKirtiGold, 0) + math.max(s.owedGranthaGold, 0)
	if owed > 0 then
		local parts: { string } = {}
		if s.owedYatraGold > 0 then
			table.insert(parts, string.format("Yatra %d", s.owedYatraGold))
		end
		if s.owedKirtiGold > 0 then
			table.insert(parts, string.format("Kirti %d", s.owedKirtiGold))
		end
		if s.owedGranthaGold > 0 then
			table.insert(parts, string.format("Grantha %d", s.owedGranthaGold))
		end
		table.insert(out, string.format("The ledgers owe you %d gold (%s).", owed, table.concat(parts, ", ")))
	end

	while #out > Welcome.MaxLines do
		table.remove(out)
	end
	return out
end

return Welcome
