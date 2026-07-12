--!strict
-- Enemy decision logic: given what the enemy perceives, choose an action.
-- Pure — no Roblox instances — so it's fully testable in Lune.

local EnemyAI = {}

export type Action = "Idle" | "Chase" | "Attack"

export type Perception = {
	-- Distance from the enemy to its target (studs).
	distance: number,
	-- Beyond this the enemy ignores the target.
	aggroRange: number,
	-- Within this the enemy can strike.
	attackRange: number,
	-- Whether the attack cooldown has elapsed.
	attackReady: boolean,
	-- Whether the target is alive/valid.
	targetAlive: boolean,
}

function EnemyAI.decide(p: Perception): Action
	if not p.targetAlive or p.distance > p.aggroRange then
		return "Idle"
	end

	if p.distance > p.attackRange then
		return "Chase"
	end

	-- In striking range: attack if ready, otherwise keep closing/pressuring.
	if p.attackReady then
		return "Attack"
	end
	return "Chase"
end

return EnemyAI
