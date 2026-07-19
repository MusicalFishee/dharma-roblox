--!strict
-- GhatService: tends the memorial fires. When a warrior falls past saving,
-- a small ghat flame is set where they fell; living allies pay tribute once
-- per flame for a breath of Tejas. The arena keeps only so many flames —
-- the oldest are released quietly.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Debris = game:GetService("Debris")

local Net = require(ReplicatedStorage.Shared.Net)
local Ghat = require(ReplicatedStorage.Shared.Ghat)
local Combat = require(ReplicatedStorage.Shared.Combat)
local Progression = require(ReplicatedStorage.Shared.Progression)
local PlayerRegistry = require(script.Parent.PlayerRegistry)

local GhatService = {}

local flames: { Part } = {}

local function extinguish(stone: Part)
	if stone.Parent then
		TweenService:Create(stone, TweenInfo.new(1.4), { Transparency = 1 }):Play()
		Debris:AddItem(stone, 1.5)
	end
end

function GhatService.onFallen(fallenName: string, position: Vector3)
	local stone = Instance.new("Part")
	stone.Name = "GhatFlame"
	stone.Size = Vector3.new(1.6, 0.8, 1.6)
	stone.Position = position + Vector3.new(0, 0.4, 0)
	stone.Color = Color3.fromRGB(60, 55, 62)
	stone.Material = Enum.Material.Slate
	stone.Anchored = true
	stone.CanCollide = false
	stone.Parent = workspace

	local fire = Instance.new("Fire")
	fire.Size = 3
	fire.Heat = 4
	fire.Color = Color3.fromRGB(255, 170, 70)
	fire.SecondaryColor = Color3.fromRGB(120, 60, 20)
	fire.Parent = stone

	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = "Pay tribute"
	prompt.ObjectText = fallenName .. "'s ghat"
	prompt.HoldDuration = 0.8
	prompt.MaxActivationDistance = 8
	prompt.RequiresLineOfSight = false
	prompt.Parent = stone

	local served: { [Player]: boolean } = {}
	prompt.Triggered:Connect(function(mourner: Player)
		if served[mourner] then
			return
		end
		local char = mourner.Character
		if char and (char:GetAttribute("DharmaBhoota") == true or char:GetAttribute("DharmaDowned") == true) then
			return -- tribute is paid by the standing
		end
		served[mourner] = true
		local state = PlayerRegistry.get(mourner)
		local level = Progression.resolve(state.totalXp).level
		state.tejas = Combat.clampTejas(state.tejas + Ghat.Config.TributeTejas, Progression.maxTejasForLevel(level))
		Net.CombatFeedback:FireClient(mourner, { tejas = state.tejas })
		Net.CombatFeedback:FireClient(mourner, { ghatTribute = true, name = fallenName })
	end)

	local released = Ghat.push(flames, stone, Ghat.Config.MaxFlames)
	if released then
		extinguish(released)
	end
end

return GhatService
