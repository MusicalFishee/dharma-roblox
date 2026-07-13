--!strict
-- Enemy roster, data-driven so variety = editing a table, not code.
-- Pure data (colours as {r,g,b} not Color3) so it stays Lune-testable and shared-safe.

export type EnemyArchetype = {
	id: string,
	displayName: string,
	maxHealth: number,
	walkSpeed: number,
	attackDamage: number,
	attackInterval: number,
	aggroRange: number,
	attackRange: number,
	xpReward: number,
	scale: number, -- body size multiplier
	skin: { number }, -- {r,g,b} 0-255
	weight: number, -- spawn rarity (higher = more common)
}

local EnemyTypes = {}

EnemyTypes.List = {
	-- Balanced demon grunt — the backbone enemy.
	Asura = {
		id = "Asura",
		displayName = "Asura",
		maxHealth = 100,
		walkSpeed = 11,
		attackDamage = 8,
		attackInterval = 1.6,
		aggroRange = 90,
		attackRange = 9,
		xpReward = 25,
		scale = 1.0,
		skin = { 74, 60, 84 },
		weight = 5,
	},
	-- Fast, fragile flesh-eater — comes in packs, punishes greed.
	Pisacha = {
		id = "Pisacha",
		displayName = "Pisacha",
		maxHealth = 55,
		walkSpeed = 18,
		attackDamage = 5,
		attackInterval = 1.1,
		aggroRange = 105,
		attackRange = 8,
		xpReward = 15,
		scale = 0.82,
		skin = { 150, 150, 128 },
		weight = 4,
	},
	-- Agile shadow assassin — high damage, thin health.
	Vetala = {
		id = "Vetala",
		displayName = "Vetala",
		maxHealth = 80,
		walkSpeed = 16,
		attackDamage = 12,
		attackInterval = 1.4,
		aggroRange = 115,
		attackRange = 9,
		xpReward = 40,
		scale = 1.0,
		skin = { 40, 42, 58 },
		weight = 2,
	},
	-- Towering brute — slow, tanky, hits like a truck. Rare.
	Rakshasa = {
		id = "Rakshasa",
		displayName = "Rakshasa",
		maxHealth = 260,
		walkSpeed = 8,
		attackDamage = 18,
		attackInterval = 2.2,
		aggroRange = 80,
		attackRange = 11,
		xpReward = 70,
		scale = 1.5,
		skin = { 122, 32, 30 },
		weight = 1,
	},
} :: { [string]: EnemyArchetype }

function EnemyTypes.get(id: string): EnemyArchetype
	return EnemyTypes.List[id] or EnemyTypes.List.Asura
end

-- Weighted random pick. `rng` lets tests inject determinism (defaults to math.random).
function EnemyTypes.pick(rng: ((number, number) -> number)?): EnemyArchetype
	local roll: (number, number) -> number = rng
		or function(lo: number, hi: number): number
			return math.random(lo, hi)
		end
	local total = 0
	for _, a in EnemyTypes.List do
		total += a.weight
	end
	local r = roll(1, total)
	local acc = 0
	for _, a in EnemyTypes.List do
		acc += a.weight
		if r <= acc then
			return a
		end
	end
	return EnemyTypes.List.Asura
end

return EnemyTypes
