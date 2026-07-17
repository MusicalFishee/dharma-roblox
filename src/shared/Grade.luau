--!strict
-- Wave grades: when the wave breaks, every warrior's conduct is judged —
-- kills and parries raise the mark, eaten blows and falls stain it.
-- S-rank pays half again the clear XP; C pays the plain bounty.
-- Pure scoring (Lune-tested); WaveService tallies and pays.

local Grade = {}

-- The judgement weights.
Grade.KillPoints = 10
Grade.ParryPoints = 15
Grade.HitPenalty = 5
Grade.DownPenalty = 40

export type Tally = {
	kills: number,
	parries: number,
	timesHit: number,
	downs: number,
}

function Grade.score(tally: Tally): number
	local s = tally.kills * Grade.KillPoints
		+ tally.parries * Grade.ParryPoints
		- tally.timesHit * Grade.HitPenalty
		- tally.downs * Grade.DownPenalty
	return math.max(0, s)
end

-- Grade against the wave's size, so wave 40 isn't judged like wave 4.
-- ratio = score / (enemyCount * KillPoints): 1.0 = "killed your share cleanly".
function Grade.gradeFor(score: number, enemyCount: number): string
	if enemyCount <= 0 then
		return "C"
	end
	local ratio = score / (enemyCount * Grade.KillPoints)
	if ratio >= 1.15 then
		return "S"
	elseif ratio >= 0.85 then
		return "A"
	elseif ratio >= 0.5 then
		return "B"
	end
	return "C"
end

Grade.XpMult = {
	S = 1.5,
	A = 1.25,
	B = 1.1,
	C = 1.0,
} :: { [string]: number }

Grade.Color = {
	S = { 255, 215, 70 },
	A = { 130, 255, 180 },
	B = { 120, 200, 255 },
	C = { 170, 170, 170 },
} :: { [string]: { number } }

function Grade.xpMult(grade: string): number
	return Grade.XpMult[grade] or 1.0
end

return Grade
