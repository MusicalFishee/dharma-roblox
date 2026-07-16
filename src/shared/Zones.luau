--!strict
-- The world's zones: as waves deepen, the arena itself transforms. Pure data
-- (colors as {r,g,b}, materials as strings) so thresholds/palettes are Lune-tested;
-- ZoneService applies them to parts + Lighting.

local Zones = {}

export type Rgb = { number }

export type ZoneDef = {
	id: string,
	name: string,
	-- First wave at which this zone takes over.
	threshold: number,
	ground: Rgb,
	groundMaterial: string,
	pillar: Rgb,
	pillarMaterial: string,
	cap: Rgb,
	flame: Rgb,
	-- Lighting.
	ambient: Rgb,
	fogColor: Rgb,
	fogEnd: number,
	clockTime: number,
}

Zones.List = {
	{
		id = "ashram",
		name = "The Ashram Grounds",
		threshold = 1,
		ground = { 48, 44, 52 },
		groundMaterial = "Slate",
		pillar = { 196, 164, 110 },
		pillarMaterial = "Sandstone",
		cap = { 48, 44, 52 },
		flame = { 255, 140, 40 },
		ambient = { 110, 100, 120 },
		fogColor = { 190, 190, 200 },
		fogEnd = 1000,
		clockTime = 14.5,
	},
	{
		id = "dandakaranya",
		name = "Dandakaranya, the Haunted Forest",
		threshold = 15,
		ground = { 26, 38, 24 },
		groundMaterial = "Slate",
		pillar = { 52, 44, 34 },
		pillarMaterial = "Wood",
		cap = { 30, 40, 28 },
		flame = { 110, 255, 140 },
		ambient = { 40, 60, 45 },
		fogColor = { 30, 50, 35 },
		fogEnd = 280,
		clockTime = 18.2,
	},
	{
		id = "sagara",
		name = "Sagara Tala, the Drowned Deep",
		threshold = 30,
		ground = { 18, 26, 44 },
		groundMaterial = "Slate",
		pillar = { 40, 60, 90 },
		pillarMaterial = "Marble",
		cap = { 20, 30, 50 },
		flame = { 90, 200, 255 },
		ambient = { 30, 45, 80 },
		fogColor = { 15, 30, 60 },
		fogEnd = 220,
		clockTime = 20.5,
	},
	{
		id = "himavat",
		name = "Himavat, the Roof of the World",
		threshold = 60,
		ground = { 225, 230, 240 },
		groundMaterial = "Snow",
		pillar = { 170, 200, 225 },
		pillarMaterial = "Ice",
		cap = { 235, 240, 248 },
		flame = { 150, 200, 255 },
		ambient = { 150, 165, 190 },
		fogColor = { 205, 215, 232 },
		fogEnd = 190,
		clockTime = 7.5,
	},
} :: { ZoneDef }

-- The zone in effect for a given wave (the deepest threshold reached).
function Zones.forWave(wave: number): ZoneDef
	local current = Zones.List[1]
	for _, zone in Zones.List do
		if wave >= zone.threshold then
			current = zone
		end
	end
	return current
end

return Zones
