--!strict
-- Boss special attacks: a telegraphed ground slam. Pure config + hit-detection so the
-- radius math is Lune-tested; the scheduling/telegraph/damage glue lives server-side.

local BossSpecials = {}

export type Special = {
	name: string,
	telegraph: number, -- seconds of wind-up (the danger zone shows this long)
	radius: number, -- studs
	damage: number,
	cooldown: number, -- seconds between uses
}

local CONFIGS: { [string]: Special } = {
	Mahishasura = { name = "Gore Slam", telegraph = 1.2, radius = 20, damage = 24, cooldown = 6.0 },
	Tarakasura = { name = "Whirl Strike", telegraph = 0.9, radius = 16, damage = 18, cooldown = 4.5 },
	Kumbhakarna = { name = "Earthshatter", telegraph = 1.6, radius = 28, damage = 40, cooldown = 8.0 },
}

local DEFAULT: Special = { name = "Ground Slam", telegraph = 1.2, radius = 20, damage = 22, cooldown = 6.0 }

function BossSpecials.forBoss(bossId: string): Special
	return CONFIGS[bossId] or DEFAULT
end

export type Point = { x: number, z: number }
export type Target = { key: any, x: number, z: number }

-- 2D radius check: which targets are within `radius` of `center` (i.e. caught in the slam).
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

return BossSpecials
