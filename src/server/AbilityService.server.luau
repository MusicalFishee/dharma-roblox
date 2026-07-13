--!strict
-- Handles the Z / X / C / V ability slots.
-- Z = Agni Astra (a Tejas-fuelled fire projectile). X / C / V are wired but not
-- yet learned (stubs) so the framework and inputs are ready to fill in.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CollectionService = game:GetService("CollectionService")
local Debris = game:GetService("Debris")

local Net = require(ReplicatedStorage.Shared.Net)
local Combat = require(ReplicatedStorage.Shared.Combat)
local PlayerRegistry = require(script.Parent.PlayerRegistry)

local ENEMY_TAG = "DharmaEnemy"
local ASTRA_SPEED = 90

local function getRoot(model: Model): BasePart?
	local root = model:FindFirstChild("HumanoidRootPart")
	if root and root:IsA("BasePart") then
		return root
	end
	return model.PrimaryPart
end

local function castAgniAstra(player: Player)
	local character = player.Character
	if not character then
		return
	end
	local root = getRoot(character)
	if not root then
		return
	end

	local state = PlayerRegistry.get(player)
	local newTejas, ok = Combat.trySpendTejas(state.tejas, Combat.Config.AgniAstraCost)
	if not ok then
		Net.CombatFeedback:FireClient(player, { outcome = "NoTejas", ability = "Z", tejas = state.tejas })
		return
	end
	state.tejas = newTejas

	local aim = root.CFrame.LookVector
	local spawnPos = root.Position + aim * 3 + Vector3.new(0, 1, 0)

	-- The bolt of sacred fire.
	local bolt = Instance.new("Part")
	bolt.Name = "AgniAstra"
	bolt.Shape = Enum.PartType.Ball
	bolt.Size = Vector3.new(2, 2, 2)
	bolt.Color = Color3.fromRGB(255, 120, 30)
	bolt.Material = Enum.Material.Neon
	bolt.CanCollide = false
	bolt.Massless = true
	bolt.CFrame = CFrame.new(spawnPos, spawnPos + aim)
	bolt.Parent = workspace

	local fire = Instance.new("Fire")
	fire.Size = 5
	fire.Heat = 10
	fire.Color = Color3.fromRGB(255, 150, 40)
	fire.Parent = bolt

	-- Straight, gravity-free flight.
	local att = Instance.new("Attachment")
	att.Parent = bolt
	local lv = Instance.new("LinearVelocity")
	lv.Attachment0 = att
	lv.MaxForce = math.huge
	lv.VectorVelocity = aim * ASTRA_SPEED
	lv.Parent = bolt

	Debris:AddItem(bolt, 3)

	local spent = false
	local conn: RBXScriptConnection
	conn = bolt.Touched:Connect(function(other: BasePart)
		if spent then
			return
		end
		local model = other:FindFirstAncestorOfClass("Model")
		if not model or model == character or not CollectionService:HasTag(model, ENEMY_TAG) then
			return
		end
		local humanoid = model:FindFirstChildOfClass("Humanoid")
		if not humanoid or humanoid.Health <= 0 then
			return
		end
		spent = true
		conn:Disconnect()
		humanoid:TakeDamage(Combat.Config.AgniAstraDamage)
		Net.CombatFeedback:FireClient(player, { outcome = "Astra", ability = "Z", tejas = state.tejas })
		bolt:Destroy()
	end)

	Net.CombatFeedback:FireClient(player, { outcome = "AstraCast", ability = "Z", tejas = state.tejas })
end

Net.AbilityRequest.OnServerEvent:Connect(function(player: Player, slotArg: any)
	local slot = tostring(slotArg)
	if slot == "Z" then
		castAgniAstra(player)
	else
		-- X / C / V: reserved for future Astras.
		Net.CombatFeedback:FireClient(player, { outcome = "Locked", ability = slot })
	end
end)

print("[Dharma] AbilityService ready — Z: Agni Astra (X/C/V reserved).")
