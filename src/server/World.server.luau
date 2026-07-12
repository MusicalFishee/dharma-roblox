--!strict
-- Builds the training arena from code (no imported assets needed).
-- Roblox primitives + materials + Fire read as a real place out of the box.

local Workspace = game:GetService("Workspace")

local SANDSTONE = Color3.fromRGB(196, 164, 110)
local DARK_STONE = Color3.fromRGB(48, 44, 52)
local EMBER = Color3.fromRGB(255, 120, 30)

local function makePart(name: string, size: Vector3, pos: Vector3, color: Color3, material: Enum.Material): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Size = size
	p.Position = pos
	p.Color = color
	p.Material = material
	p.Anchored = true
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Parent = Workspace
	return p
end

-- Floor.
makePart("Ground", Vector3.new(600, 4, 600), Vector3.new(0, 0, 0), DARK_STONE, Enum.Material.Slate)

-- Spawn pad at the centre.
local spawnPad = Instance.new("SpawnLocation")
spawnPad.Name = "DharmaSpawn"
spawnPad.Size = Vector3.new(14, 1, 14)
spawnPad.Position = Vector3.new(0, 2.5, 0)
spawnPad.Color = SANDSTONE
spawnPad.Material = Enum.Material.Sand
spawnPad.Anchored = true
spawnPad.Parent = Workspace

-- Ring of pillars.
local NUM_PILLARS = 10
local PILLAR_RADIUS = 90
for i = 0, NUM_PILLARS - 1 do
	local angle = (2 * math.pi * i) / NUM_PILLARS
	local x = math.cos(angle) * PILLAR_RADIUS
	local z = math.sin(angle) * PILLAR_RADIUS

	makePart("PillarShaft", Vector3.new(8, 44, 8), Vector3.new(x, 22, z), SANDSTONE, Enum.Material.Sandstone)
	makePart("PillarCap", Vector3.new(12, 4, 12), Vector3.new(x, 46, z), DARK_STONE, Enum.Material.Slate)
end

-- Braziers with real flame + warm light.
local NUM_BRAZIERS = 5
local BRAZIER_RADIUS = 52
for i = 0, NUM_BRAZIERS - 1 do
	local angle = (2 * math.pi * i) / NUM_BRAZIERS + 0.3
	local x = math.cos(angle) * BRAZIER_RADIUS
	local z = math.sin(angle) * BRAZIER_RADIUS

	makePart("BrazierBase", Vector3.new(4, 10, 4), Vector3.new(x, 5, z), DARK_STONE, Enum.Material.Slate)

	local bowl = makePart("BrazierBowl", Vector3.new(6, 3, 6), Vector3.new(x, 11, z), EMBER, Enum.Material.Neon)

	local fire = Instance.new("Fire")
	fire.Size = 8
	fire.Heat = 12
	fire.Color = Color3.fromRGB(255, 140, 40)
	fire.SecondaryColor = Color3.fromRGB(120, 40, 10)
	fire.Parent = bowl

	local light = Instance.new("PointLight")
	light.Brightness = 4
	light.Range = 40
	light.Color = Color3.fromRGB(255, 150, 70)
	light.Parent = bowl
end

print("[Dharma] Arena built — floor, spawn, 10 pillars, 5 braziers.")
