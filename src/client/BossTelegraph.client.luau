--!strict
-- Renders the boss slam danger zone (red disc on the ground) during the wind-up,
-- then a bright flash on impact. "Get out of the red."

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Debris = game:GetService("Debris")
local TweenService = game:GetService("TweenService")

local Net = require(ReplicatedStorage.Shared.Net)

local function makeDisc(x: number, y: number, z: number, radius: number, color: Color3, transparency: number): Part
	local disc = Instance.new("Part")
	disc.Shape = Enum.PartType.Cylinder
	disc.Size = Vector3.new(0.4, radius * 2, radius * 2)
	-- Rotate so the cylinder's axis points up -> flat disc on the floor.
	disc.CFrame = CFrame.new(x, y, z) * CFrame.Angles(0, 0, math.rad(90))
	disc.Anchored = true
	disc.CanCollide = false
	disc.CanQuery = false
	disc.CanTouch = false
	disc.Material = Enum.Material.Neon
	disc.Color = color
	disc.Transparency = transparency
	disc.Parent = workspace
	return disc
end

Net.CombatFeedback.OnClientEvent:Connect(function(data: any)
	if typeof(data) ~= "table" or not data.bossSpecial then
		return
	end

	if data.bossSpecial == "telegraph" then
		local dur = tonumber(data.duration) or 1
		local disc = makeDisc(data.x, data.y, data.z, data.radius, Color3.fromRGB(255, 60, 40), 0.78)
		-- Redden/solidify as the slam approaches, so the danger reads clearly.
		TweenService:Create(disc, TweenInfo.new(dur, Enum.EasingStyle.Linear), { Transparency = 0.42 }):Play()
		Debris:AddItem(disc, dur + 0.15)
	elseif data.bossSpecial == "impact" then
		local flash = makeDisc(data.x, data.y, data.z, data.radius, Color3.fromRGB(255, 190, 70), 0.15)
		TweenService:Create(flash, TweenInfo.new(0.35), { Transparency = 1 }):Play()
		Debris:AddItem(flash, 0.4)
	end
end)
