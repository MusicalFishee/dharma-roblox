--!strict
-- Maricha Revealed: the secret boss. The golden deer is Maricha's oldest
-- trick — and he has been counting every arrow you put in it. Every tenth
-- deer YOU fell tears the illusion open: the deer turns around, and the
-- demon who fooled Rama's own house draws his bow on you. A boss who RUNS —
-- he kites like his soldier-form and rains gold-fletched arrows.
-- Pure trigger/scaling math (Lune-tested); UtsavaService springs the trap.

local MarichaBoss = {}

MarichaBoss.RevealEvery = 10 -- every tenth felled deer turns

MarichaBoss.Lines = {
	reveal = "Ten hunts, hunter. Ten. The deer runs no more — see what you have been shooting.",
	fall = "Again I fall to an archer… and again, the forest will wear my gold.",
}

function MarichaBoss.isRevealing(deerKills: number): boolean
	return deerKills > 0 and deerKills % MarichaBoss.RevealEvery == 0
end

-- The revealed demon, scaled to the night the illusion tears.
function MarichaBoss.archetypeFor(wave: number)
	local w = math.max(wave, 1)
	return {
		id = "MarichaRevealed",
		displayName = "Maricha Revealed",
		title = "the Illusion Torn",
		maxHealth = 900 + w * 60,
		walkSpeed = 15,
		attackDamage = 14 + math.floor(w * 0.4),
		attackInterval = 1.9,
		aggroRange = 200,
		attackRange = 50,
		xpReward = 220 + w * 10,
		scale = 1.35,
		skin = { 255, 190, 60 },
		weight = 0, -- never rolled by the composer; only the hunt springs him
		isBoss = true,
		ranged = true,
		projectileSpeed = 85,
		retreatRange = 22,
	}
end

-- What the torn illusion pays beyond a boss's ordinary bounty.
function MarichaBoss.spoilsFor(wave: number): { gold: number, shards: number }
	return { gold = 400 + math.max(wave, 1) * 15, shards = 3 }
end

return MarichaBoss
