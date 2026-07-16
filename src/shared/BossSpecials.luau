--!strict
-- Boss special attacks: telegraphed AoE blasts. Each asura lord has his own —
-- radius, damage, telegraph window (your time to escape), and cooldown.
-- Pure math (no Roblox types) so the rules are Lune-tested; the telegraph/damage
-- glue lives server-side in EnemyService.

local BossSpecials = {}

export type Special = {
	name: string,
	-- Seconds the danger ring shows before detonation (the escape window).
	telegraph: number,
	radius: number, -- studs
	damage: number,
	cooldown: number, -- seconds between uses
	-- true = blast lands at the target player's feet; false = centered on the boss.
	targetPlayer: boolean,
}

local CONFIGS: { [string]: Special } = {
	Mahishasura = { name = "Gore Slam", telegraph = 1.4, radius = 20, damage = 35, cooldown = 8.0, targetPlayer = false },
	Tarakasura = { name = "Hunting Comet", telegraph = 1.2, radius = 14, damage = 45, cooldown = 7.0, targetPlayer = true },
	Kumbhakarna = { name = "Earthshatter", telegraph = 2.0, radius = 30, damage = 60, cooldown = 11.0, targetPlayer = false },
	Hiranyakashipu = { name = "Tyrant's Decree", telegraph = 1.2, radius = 15, damage = 50, cooldown = 6.5, targetPlayer = true },
	Bakasura = { name = "Hungering Maw", telegraph = 1.8, radius = 26, damage = 55, cooldown = 10.0, targetPlayer = false },
	Vritra = { name = "Coiling Drought", telegraph = 1.7, radius = 24, damage = 52, cooldown = 9.0, targetPlayer = false },
	Kalanemi = { name = "Mountain's Curse", telegraph = 1.2, radius = 16, damage = 55, cooldown = 6.8, targetPlayer = true },
}

local DEFAULT: Special = { name = "Ground Slam", telegraph = 1.4, radius = 20, damage = 35, cooldown = 8.0, targetPlayer = false }

function BossSpecials.forBoss(bossId: string): Special
	return CONFIGS[bossId] or DEFAULT
end

export type Point = { x: number, z: number }
export type Target = { key: any, x: number, z: number }

-- 2D radius check: which targets are caught in the blast (height ignored — ground slam).
function BossSpecials.hitTargets(center: Point, targets: { Target }, radius: number): { any }
	local hit: { any } = {}
	local r2 = radius * radius
	for _, t in targets do
		local dx = t.x - center.x
		local dz = t.z - center.z
		if (dx * dx + dz * dz) <= r2 then
			table.insert(hit, t.key)
		end
	end
	return hit
end

export type BlastResult = {
	outcome: string, -- "Dodge" | "Block" | "Hit"
	damage: number,
}

-- AoE resolution: i-frames negate entirely; blocking soaks only half (a slam is
-- heavier than a strike, and facing doesn't matter against a shockwave).
function BossSpecials.resolveBlast(damage: number, isDodging: boolean, isBlocking: boolean): BlastResult
	if isDodging then
		return { outcome = "Dodge", damage = 0 }
	end
	if isBlocking then
		return { outcome = "Block", damage = damage * 0.5 }
	end
	return { outcome = "Hit", damage = damage }
end

return BossSpecials
