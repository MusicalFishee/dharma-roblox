--!strict
-- Enemy decision logic: given what the enemy perceives, choose an action.
-- Pure — no Roblox instances — so it's fully testable in Lune.

local EnemyAI = {}

export type Action = "Idle" | "Chase" | "Attack" | "Retreat"

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
	-- Ranged kiters: closer than this, back away (nil/0 for melee).
	retreatRange: number?,
}

function EnemyAI.decide(p: Perception): Action
	if not p.targetAlive or p.distance > p.aggroRange then
		return "Idle"
	end

	if p.distance > p.attackRange then
		return "Chase"
	end

	-- In striking range: attack if ready (even a kiter snaps a point-blank shot).
	if p.attackReady then
		return "Attack"
	end

	local retreat = p.retreatRange or 0
	if retreat > 0 then
		-- A kiter on cooldown backs off when crowded, otherwise holds at range.
		if p.distance < retreat then
			return "Retreat"
		end
		return "Idle"
	end

	-- Melee keeps closing/pressuring while recharging.
	return "Chase"
end

return EnemyAI
