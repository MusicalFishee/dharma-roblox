--!strict
-- The Akhada, live: an unkillable practice dummy across from the grove.
-- Tagged like any foe so every blade, Astra, and reaction lands true; its
-- billboard reads the last 10 seconds of punishment back in plain numbers.
-- It never dies (topped up before half), so it pollutes no kill ledger.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")

local Akhada = require(ReplicatedStorage.Shared.Akhada)

local ENEMY_TAG = "DharmaEnemy"
local YARD_POS = Vector3.new(34, 4, -34)

local AkhadaService = {}

local events: { Akhada.HitEvent } = {}
local lastAttackerName = ""

local function buildYard(): (Humanoid?, TextLabel?)
	local mat = Instance.new("Part")
	mat.Name = "AkhadaMat"
	mat.Size = Vector3.new(14, 0.4, 14)
	mat.Position = YARD_POS - Vector3.new(0, 3.2, 0)
	mat.Color = Color3.fromRGB(140, 100, 60)
	mat.Material = Enum.Material.WoodPlanks
	mat.Anchored = true
	mat.Parent = workspace

	local skin = Color3.fromRGB(150, 150, 155)
	local ok, model = pcall(function()
		local desc = Instance.new("HumanoidDescription")
		desc.HeadColor = skin
		desc.TorsoColor = skin
		desc.LeftArmColor = skin
		desc.RightArmColor = skin
		desc.LeftLegColor = skin
		desc.RightLegColor = skin
		return Players:CreateHumanoidModelFromDescription(desc, Enum.HumanoidRigType.R15)
	end)
	if not ok or typeof(model) ~= "Instance" or not model:IsA("Model") then
		warn("[Dharma] Failed to raise the akhada dummy: " .. tostring(model))
		return nil, nil
	end
	local rig = model :: Model
	local humanoid = rig:FindFirstChildOfClass("Humanoid")
	local root = rig:FindFirstChild("HumanoidRootPart")
	if not humanoid or not root then
		rig:Destroy()
		return nil, nil
	end

	humanoid.MaxHealth = Akhada.Config.DummyHealth
	humanoid.Health = Akhada.Config.DummyHealth
	humanoid.WalkSpeed = 0
	humanoid.JumpHeight = 0
	humanoid.DisplayName = "Abhyasa Dummy"
	pcall(function()
		humanoid:SetStateEnabled(Enum.HumanoidStateType.Dead, false)
	end)
	pcall(function()
		rig:ScaleTo(1.4)
	end)
	rig.Name = "AkhadaDummy"
	rig:PivotTo(CFrame.new(YARD_POS, Vector3.new(0, YARD_POS.Y, 0)))
	rig:SetAttribute("IsBoss", true) -- Yama's Ledger has no claim on straw
	rig.Parent = workspace
	CollectionService:AddTag(rig, ENEMY_TAG)

	local billboard = Instance.new("BillboardGui")
	billboard.Size = UDim2.fromOffset(240, 60)
	billboard.StudsOffset = Vector3.new(0, 4.4, 0)
	billboard.AlwaysOnTop = true
	billboard.Parent = rig:FindFirstChild("Head") or root
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.GothamBold
	label.TextSize = 16
	label.TextColor3 = Color3.fromRGB(235, 230, 220)
	label.TextStrokeTransparency = 0.5
	label.TextWrapped = true
	label.Text = "AKHADA\nStrike freely — the straw keeps score."
	label.Parent = billboard

	return humanoid, label
end

local humanoid, label = buildYard()
if humanoid and label then
	local hum = humanoid :: Humanoid
	local readout = label :: TextLabel
	local lastHealth = hum.Health

	hum.HealthChanged:Connect(function(health: number)
		local dealt = lastHealth - health
		lastHealth = health
		if dealt > 0 then
			table.insert(events, { at = os.clock(), amount = dealt })
			local attackerId = (hum.Parent :: Model):GetAttribute("LastAttacker")
			if typeof(attackerId) == "number" then
				local attacker = Players:GetPlayerByUserId(attackerId)
				if attacker then
					lastAttackerName = attacker.DisplayName
				end
			end
		end
	end)

	task.spawn(function()
		while hum.Parent do
			task.wait(0.5)
			local now = os.clock()
			events = Akhada.prune(events, now, Akhada.Config.WindowSeconds)
			local total, dps = Akhada.readOver(events, now, Akhada.Config.WindowSeconds)
			if total > 0 then
				readout.Text = string.format("AKHADA — last %ds\n%d damage  ·  %.0f DPS\n%s", Akhada.Config.WindowSeconds, total, dps, lastAttackerName)
			else
				readout.Text = "AKHADA\nStrike freely — the straw keeps score."
			end
			if hum.Health < hum.MaxHealth * Akhada.Config.ResetBelowFraction then
				lastHealth = hum.MaxHealth
				hum.Health = hum.MaxHealth
			end
		end
	end)
end

print("[Dharma] AkhadaService ready — the straw awaits your worst.")

return AkhadaService
