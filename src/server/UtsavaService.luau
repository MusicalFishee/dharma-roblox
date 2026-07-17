--!strict
-- Utsava events, live: the golden deer that flees and pays, the Vajra storm
-- that rains shard orbs, the wandering vaidya trading shards for gold.
-- WaveService rolls at wave start (never on boss/trial/raid nights); one event
-- runs at a time and cleans up after itself.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CollectionService = game:GetService("CollectionService")
local TweenService = game:GetService("TweenService")
local Players = game:GetService("Players")
local Debris = game:GetService("Debris")

local Net = require(ReplicatedStorage.Shared.Net)
local Utsava = require(ReplicatedStorage.Shared.Utsava)
local Loot = require(ReplicatedStorage.Shared.Loot)
local PlayerRegistry = require(script.Parent.PlayerRegistry)
local ProgressionService = require(script.Parent.ProgressionService)

local ENEMY_TAG = "DharmaEnemy"
local ARENA_RADIUS = 45 -- mirrors WaveService's arena

local UtsavaService = {}

local lastEventWave = -math.huge
local eventRunning = false

local function broadcastAll(data: { [string]: any })
	for _, p in Players:GetPlayers() do
		Net.CombatFeedback:FireClient(p, data)
	end
end

local function announce(def: Utsava.EventDef)
	broadcastAll({ utsava = "begin", eventId = def.id, name = def.name, announce = def.announce })
end

local function randomFieldSpot(maxRadius: number): Vector3
	local angle = math.random() * 2 * math.pi
	local r = math.sqrt(math.random()) * maxRadius
	return Vector3.new(math.cos(angle) * r, 3, math.sin(angle) * r)
end

-- ---------------------------------------------------------------------------
-- The Golden Deer — Maricha's old trick. Flees, never fights, pays its slayer.
-- ---------------------------------------------------------------------------
local function runGoldenDeer(def: Utsava.EventDef)
	local skin = Color3.fromRGB(255, 200, 60)
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
		warn("[Dharma] Failed to conjure the golden deer: " .. tostring(model))
		return
	end
	local rig = model :: Model
	local humanoid = rig:FindFirstChildOfClass("Humanoid")
	local root = rig:FindFirstChild("HumanoidRootPart")
	if not humanoid or not root or not root:IsA("BasePart") then
		rig:Destroy()
		return
	end

	humanoid.MaxHealth = Utsava.Deer.health
	humanoid.Health = Utsava.Deer.health
	humanoid.WalkSpeed = Utsava.Deer.walkSpeed
	humanoid.DisplayName = "Golden Deer"
	pcall(function()
		rig:ScaleTo(0.85)
	end)
	rig.Name = "GoldenDeer"
	rig:PivotTo(CFrame.new(randomFieldSpot(ARENA_RADIUS - 8) + Vector3.new(0, 4, 0)))
	rig.Parent = workspace
	CollectionService:AddTag(rig, ENEMY_TAG) -- blades and Astras can find it

	local glow = Instance.new("Highlight")
	glow.FillColor = skin
	glow.FillTransparency = 0.55
	glow.OutlineColor = Color3.fromRGB(255, 235, 150)
	glow.Parent = rig
	local sparkle = Instance.new("Sparkles")
	sparkle.SparkleColor = skin
	sparkle.Parent = root

	local finished = false

	-- The bounty, if anyone brings it down.
	humanoid.Died:Connect(function()
		if finished then
			return
		end
		finished = true
		local killerId = rig:GetAttribute("LastAttacker")
		local killer = if typeof(killerId) == "number" then Players:GetPlayerByUserId(killerId) else nil
		if killer then
			local state = PlayerRegistry.get(killer)
			state.gold = Loot.clampGold(state.gold + Utsava.Deer.gold)
			state.shards += Utsava.Deer.shards
			Net.CombatFeedback:FireClient(killer, { goldUpdate = true, gained = Utsava.Deer.gold, gold = state.gold })
			Net.CombatFeedback:FireClient(killer, { shardUpdate = true, gained = Utsava.Deer.shards, shards = state.shards })
			ProgressionService.awardXp(killer, Utsava.Deer.xp)
			broadcastAll({ utsava = "deerSlain", byName = killer.Name, gold = Utsava.Deer.gold, shards = Utsava.Deer.shards })
		end
		CollectionService:RemoveTag(rig, ENEMY_TAG)
		Debris:AddItem(rig, 1.5)
	end)

	-- Flee AI: always away from the nearest hunter, never out of the arena.
	task.spawn(function()
		while not finished and rig.Parent and humanoid.Health > 0 do
			task.wait(0.3)
			local nearest: BasePart? = nil
			local bestDist = math.huge
			for _, p in Players:GetPlayers() do
				local char = p.Character
				if char and (char:GetAttribute("DharmaBhoota") == true or char:GetAttribute("DharmaDowned") == true or char:GetAttribute("DharmaDhyana") == true) then
					continue -- the deer fears neither spirits nor the fallen
				end
				local hrp = char and char:FindFirstChild("HumanoidRootPart")
				if hrp and hrp:IsA("BasePart") then
					local d = (hrp.Position - root.Position).Magnitude
					if d < bestDist then
						bestDist = d
						nearest = hrp
					end
				end
			end
			if not nearest then
				continue
			end
			local away = root.Position - nearest.Position
			away = Vector3.new(away.X, 0, away.Z)
			away = if away.Magnitude > 0.01 then away.Unit else Vector3.new(0, 0, 1)
			local target = root.Position + away * 18
			-- If the flight path leaves the field, curve back toward the middle.
			if Vector3.new(target.X, 0, target.Z).Magnitude > ARENA_RADIUS - 5 then
				target = Vector3.new(target.X, target.Y, target.Z) * 0.4
			end
			humanoid:MoveTo(target)
		end
	end)

	-- The illusion doesn't wait forever.
	task.delay(def.duration, function()
		if finished then
			return
		end
		finished = true
		CollectionService:RemoveTag(rig, ENEMY_TAG)
		broadcastAll({ utsava = "deerFled" })
		for _, part in rig:GetDescendants() do
			if part:IsA("BasePart") then
				TweenService:Create(part, TweenInfo.new(1.2), { Transparency = 1 }):Play()
			end
		end
		Debris:AddItem(rig, 1.3)
	end)
end

-- ---------------------------------------------------------------------------
-- Vajra Storm — shard orbs fall on a beat; first touch claims each.
-- ---------------------------------------------------------------------------
local function runShardStorm(_def: Utsava.EventDef)
	task.spawn(function()
		for _ = 1, Utsava.Storm.orbCount do
			task.wait(Utsava.Storm.interval)
			local spot = randomFieldSpot(ARENA_RADIUS - 10)

			local orb = Instance.new("Part")
			orb.Shape = Enum.PartType.Ball
			orb.Size = Vector3.new(1.8, 1.8, 1.8)
			orb.Position = spot + Vector3.new(0, 2, 0)
			orb.Color = Color3.fromRGB(180, 120, 255)
			orb.Material = Enum.Material.Neon
			orb.Anchored = true
			orb.CanCollide = false
			orb.CanQuery = false
			orb.Parent = workspace
			-- The falling bolt that heralds it.
			local herald = Instance.new("Part")
			herald.Size = Vector3.new(0.7, 30, 0.7)
			herald.CFrame = CFrame.new(spot + Vector3.new(0, 17, 0))
			herald.Color = Color3.fromRGB(200, 160, 255)
			herald.Material = Enum.Material.Neon
			herald.Anchored = true
			herald.CanCollide = false
			herald.CanQuery = false
			herald.Parent = workspace
			TweenService:Create(herald, TweenInfo.new(0.35), { Transparency = 1 }):Play()
			Debris:AddItem(herald, 0.4)

			TweenService:Create(
				orb,
				TweenInfo.new(0.8, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true),
				{ Position = orb.Position + Vector3.new(0, 1.2, 0) }
			):Play()
			Debris:AddItem(orb, 12)

			local taken = false
			orb.Touched:Connect(function(other: BasePart)
				if taken then
					return
				end
				local char = other:FindFirstAncestorOfClass("Model")
				local player = char and Players:GetPlayerFromCharacter(char)
				if not player then
					return
				end
				if char and char:GetAttribute("DharmaBhoota") == true then
					return -- shards slip through spirit hands
				end
				taken = true
				local state = PlayerRegistry.get(player)
				state.shards += Utsava.Storm.shardsPerOrb
				Net.CombatFeedback:FireClient(player, { shardUpdate = true, gained = Utsava.Storm.shardsPerOrb, shards = state.shards })
				orb:Destroy()
			end)
			-- CanQuery false blocks Touched on anchored parts unless CanTouch holds; be explicit.
			orb.CanTouch = true
		end
	end)
end

-- ---------------------------------------------------------------------------
-- The Wandering Vaidya — one deal per visitor: shards for gold.
-- ---------------------------------------------------------------------------
local function runMerchant(def: Utsava.EventDef)
	local mat = Instance.new("Part")
	mat.Size = Vector3.new(8, 0.4, 6)
	mat.Position = Vector3.new(ARENA_RADIUS - 9, 0.7, ARENA_RADIUS - 9)
	mat.Color = Color3.fromRGB(140, 60, 40)
	mat.Material = Enum.Material.Fabric
	mat.Anchored = true
	mat.Parent = workspace

	local chest = Instance.new("Part")
	chest.Size = Vector3.new(2.4, 1.8, 1.6)
	chest.Position = mat.Position + Vector3.new(0, 1.2, 0)
	chest.Color = Color3.fromRGB(90, 60, 30)
	chest.Material = Enum.Material.Wood
	chest.Anchored = true
	chest.Parent = workspace

	local billboard = Instance.new("BillboardGui")
	billboard.Size = UDim2.fromOffset(220, 50)
	billboard.StudsOffset = Vector3.new(0, 3.4, 0)
	billboard.AlwaysOnTop = true
	billboard.Parent = chest
	local sign = Instance.new("TextLabel")
	sign.Size = UDim2.fromScale(1, 1)
	sign.BackgroundTransparency = 1
	sign.Font = Enum.Font.GothamBold
	sign.TextSize = 18
	sign.TextColor3 = Color3.fromRGB(255, 220, 120)
	sign.TextStrokeTransparency = 0.4
	sign.Text = string.format("THE VAIDYA\n%d ◆ for %d gold", Utsava.Merchant.shards, Utsava.Merchant.price)
	sign.Parent = billboard

	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = "Trade"
	prompt.ObjectText = "Wandering Vaidya"
	prompt.HoldDuration = 0.5
	prompt.MaxActivationDistance = 12
	prompt.RequiresLineOfSight = false
	prompt.Parent = chest

	local served: { [Player]: boolean } = {}
	prompt.Triggered:Connect(function(buyer: Player)
		local bchar = buyer.Character
		if bchar and bchar:GetAttribute("DharmaBhoota") == true then
			return -- the vaidya trades with the living
		end
		if served[buyer] then
			Net.CombatFeedback:FireClient(buyer, { utsava = "merchantDenied", reason = "served" })
			return
		end
		local state = PlayerRegistry.get(buyer)
		if state.gold < Utsava.Merchant.price then
			Net.CombatFeedback:FireClient(buyer, { utsava = "merchantDenied", reason = "gold" })
			return
		end
		served[buyer] = true
		state.gold -= Utsava.Merchant.price
		state.shards += Utsava.Merchant.shards
		Net.CombatFeedback:FireClient(buyer, { goldUpdate = true, gained = 0, gold = state.gold })
		Net.CombatFeedback:FireClient(buyer, { shardUpdate = true, gained = Utsava.Merchant.shards, shards = state.shards })
		Net.CombatFeedback:FireClient(buyer, { utsava = "merchantSold", shards = Utsava.Merchant.shards, price = Utsava.Merchant.price })
	end)

	task.delay(def.duration, function()
		broadcastAll({ utsava = "merchantLeft" })
		for _, part in { mat, chest } do
			TweenService:Create(part, TweenInfo.new(1.2), { Transparency = 1 }):Play()
		end
		Debris:AddItem(mat, 1.3)
		Debris:AddItem(chest, 1.3)
	end)
end

-- Called by WaveService at every wave start. Rolls, announces, runs.
function UtsavaService.onWaveStart(wave: number, isSpecialWave: boolean)
	if eventRunning then
		return
	end
	local def = Utsava.roll(wave, lastEventWave, isSpecialWave, function()
		return math.random()
	end)
	if not def then
		return
	end
	lastEventWave = wave
	eventRunning = true
	announce(def)

	task.spawn(function()
		if def.id == "golden_deer" then
			runGoldenDeer(def)
		elseif def.id == "shard_storm" then
			runShardStorm(def)
		elseif def.id == "merchant" then
			runMerchant(def)
		end
	end)
	task.delay(def.duration + 3, function()
		eventRunning = false
	end)
end

print("[Dharma] UtsavaService ready — the festival waits for no one.")

return UtsavaService
