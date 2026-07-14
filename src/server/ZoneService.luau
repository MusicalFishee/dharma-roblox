--!strict
-- Transforms the arena when wave thresholds are crossed: ground, pillars, brazier
-- flames and the sky/fog all shift to the new zone's palette (smoothly tweened).

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")

local Net = require(ReplicatedStorage.Shared.Net)
local Zones = require(ReplicatedStorage.Shared.Zones)

local ZoneService = {}

local currentZoneId: string? = nil
local TWEEN = TweenInfo.new(2.5, Enum.EasingStyle.Quad, Enum.EasingDirection.InOut)

local function rgb(c: { number }): Color3
	return Color3.fromRGB(c[1], c[2], c[3])
end

local function material(name: string): Enum.Material
	local ok, mat = pcall(function()
		return (Enum.Material :: any)[name] :: Enum.Material
	end)
	return if ok then mat else Enum.Material.Slate
end

local function retheme(zone: Zones.ZoneDef)
	for _, inst in workspace:GetChildren() do
		if not inst:IsA("BasePart") then
			continue
		end
		if inst.Name == "Ground" or inst.Name == "DharmaSpawn" then
			TweenService:Create(inst, TWEEN, { Color = rgb(zone.ground) }):Play()
			inst.Material = material(zone.groundMaterial)
		elseif inst.Name == "PillarShaft" then
			TweenService:Create(inst, TWEEN, { Color = rgb(zone.pillar) }):Play()
			inst.Material = material(zone.pillarMaterial)
		elseif inst.Name == "PillarCap" or inst.Name == "BrazierBase" then
			TweenService:Create(inst, TWEEN, { Color = rgb(zone.cap) }):Play()
		elseif inst.Name == "BrazierBowl" then
			TweenService:Create(inst, TWEEN, { Color = rgb(zone.flame) }):Play()
			local fire = inst:FindFirstChildOfClass("Fire")
			if fire then
				fire.Color = rgb(zone.flame)
				fire.SecondaryColor = rgb(zone.flame):Lerp(Color3.new(0, 0, 0), 0.6)
			end
			local light = inst:FindFirstChildOfClass("PointLight")
			if light then
				TweenService:Create(light, TWEEN, { Color = rgb(zone.flame) }):Play()
			end
		end
	end

	TweenService:Create(Lighting, TWEEN, {
		Ambient = rgb(zone.ambient),
		OutdoorAmbient = rgb(zone.ambient),
		FogColor = rgb(zone.fogColor),
		FogEnd = zone.fogEnd,
		ClockTime = zone.clockTime,
	}):Play()
end

-- Called by the wave director on every wave start; re-themes only on zone change.
function ZoneService.applyForWave(wave: number)
	local zone = Zones.forWave(wave)
	if zone.id == currentZoneId then
		return
	end
	local isFirst = currentZoneId == nil
	currentZoneId = zone.id
	retheme(zone)

	-- Announce actual transitions (not the initial theme application).
	if not isFirst then
		for _, p in Players:GetPlayers() do
			Net.CombatFeedback:FireClient(p, { zoneChange = true, name = zone.name })
		end
	end
end

return ZoneService
