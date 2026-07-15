--!strict
-- The Astra kit, server-side:
--   Z  Agni Astra     — fire projectile
--   X  Vayu Dash      — wind dash with brief i-frames
--   C  Varuna's Grace — healing surge
--   V  Indra's Wrath  — lightning storm on every enemy near the caster
-- Gating (Tejas cost, cooldown, level unlock) is validated server-side.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local Debris = game:GetService("Debris")
local TweenService = game:GetService("TweenService")

local Net = require(ReplicatedStorage.Shared.Net)
local Abilities = require(ReplicatedStorage.Shared.Abilities)
local Progression = require(ReplicatedStorage.Shared.Progression)
local StatusEffects = require(ReplicatedStorage.Shared.StatusEffects)
local PlayerRegistry = require(script.Parent.PlayerRegistry)
local QuestService = require(script.Parent.QuestService)

local ENEMY_TAG = "DharmaEnemy"
local ASTRA_SPEED = 90

-- Per-player, per-slot last-cast times (cooldowns).
local lastCast: { [Player]: { [string]: number } } = {}

Players.PlayerRemoving:Connect(function(player)
	lastCast[player] = nil
end)

local function getCharacterParts(player: Player): (Model?, BasePart?, Humanoid?)
	local char = player.Character
	if not char then
		return nil, nil, nil
	end
	local root = char:FindFirstChild("HumanoidRootPart")
	local hum = char:FindFirstChildOfClass("Humanoid")
	if root and root:IsA("BasePart") and hum then
		return char, root, hum
	end
	return char, nil, hum
end

-- ---------------------------------------------------------------------------
-- Z — Agni Astra
-- ---------------------------------------------------------------------------
local function castAgniAstra(player: Player, character: Model, root: BasePart)
	local cfg = Abilities.Config.Z
	local aim = root.CFrame.LookVector
	local spawnPos = root.Position + aim * 3 + Vector3.new(0, 1, 0)

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
		model:SetAttribute("LastAttacker", player.UserId)
		humanoid:TakeDamage(cfg.power)
		bolt:Destroy()
	end)
end

-- ---------------------------------------------------------------------------
-- X — Vayu Dash
-- ---------------------------------------------------------------------------
local function castVayuDash(player: Player, root: BasePart, hum: Humanoid)
	local cfg = Abilities.Config.X

	-- Dash along the current move direction (or facing if standing still).
	local dir = hum.MoveDirection
	if dir.Magnitude < 0.1 then
		dir = root.CFrame.LookVector
	end
	dir = Vector3.new(dir.X, 0, dir.Z).Unit

	root.AssemblyLinearVelocity = dir * cfg.power + Vector3.new(0, 12, 0)

	-- Brief wind i-frames (reuses the dodge window).
	local state = PlayerRegistry.get(player)
	state.dodgeUntil = os.clock() + 0.5

	-- Wind streak.
	local streak = Instance.new("Part")
	streak.Size = Vector3.new(1.2, 1.2, 7)
	streak.CFrame = CFrame.new(root.Position - dir * 3, root.Position + dir * 4)
	streak.Color = Color3.fromRGB(210, 240, 255)
	streak.Material = Enum.Material.Neon
	streak.Transparency = 0.35
	streak.Anchored = true
	streak.CanCollide = false
	streak.CanQuery = false
	streak.Parent = workspace
	TweenService:Create(streak, TweenInfo.new(0.35), { Transparency = 1 }):Play()
	Debris:AddItem(streak, 0.4)
end

-- ---------------------------------------------------------------------------
-- C — Varuna's Grace
-- ---------------------------------------------------------------------------
local function castVarunaHeal(player: Player, root: BasePart, hum: Humanoid)
	local cfg = Abilities.Config.C
	local state = PlayerRegistry.get(player)
	-- A curse thins even Varuna's waters.
	local heal = StatusEffects.effectiveHeal(hum.MaxHealth * cfg.power, os.clock() < state.curseUntil)
	hum.Health = math.min(hum.MaxHealth, hum.Health + heal)

	-- Rising water glow.
	local glow = Instance.new("Part")
	glow.Shape = Enum.PartType.Ball
	glow.Size = Vector3.new(8, 8, 8)
	glow.Position = root.Position
	glow.Color = Color3.fromRGB(80, 170, 255)
	glow.Material = Enum.Material.Neon
	glow.Transparency = 0.45
	glow.Anchored = true
	glow.CanCollide = false
	glow.CanQuery = false
	glow.Parent = workspace
	TweenService:Create(glow, TweenInfo.new(0.7), {
		Size = Vector3.new(14, 14, 14),
		Position = root.Position + Vector3.new(0, 4, 0),
		Transparency = 1,
	}):Play()
	Debris:AddItem(glow, 0.8)
end

-- ---------------------------------------------------------------------------
-- V — Indra's Wrath
-- ---------------------------------------------------------------------------
local function castIndraWrath(player: Player, root: BasePart): number
	local cfg = Abilities.Config.V
	local radius = cfg.radius or 60
	local struck = 0

	for _, enemy in CollectionService:GetTagged(ENEMY_TAG) do
		if not enemy:IsA("Model") then
			continue
		end
		local humanoid = enemy:FindFirstChildOfClass("Humanoid")
		local eroot = enemy:FindFirstChild("HumanoidRootPart")
		if not humanoid or humanoid.Health <= 0 or not eroot or not eroot:IsA("BasePart") then
			continue
		end
		if (eroot.Position - root.Position).Magnitude > radius then
			continue
		end

		struck += 1
		enemy:SetAttribute("LastAttacker", player.UserId)
		humanoid:TakeDamage(cfg.power)

		-- Lightning bolt from the sky onto the enemy.
		local top = eroot.Position + Vector3.new(0, 60, 0)
		local bolt = Instance.new("Part")
		bolt.Size = Vector3.new(1.4, (top - eroot.Position).Magnitude, 1.4)
		bolt.CFrame = CFrame.new((top + eroot.Position) / 2, eroot.Position) * CFrame.Angles(math.rad(90), 0, 0)
		bolt.Color = Color3.fromRGB(180, 220, 255)
		bolt.Material = Enum.Material.Neon
		bolt.Transparency = 0.1
		bolt.Anchored = true
		bolt.CanCollide = false
		bolt.CanQuery = false
		bolt.Parent = workspace
		TweenService:Create(bolt, TweenInfo.new(0.4), { Transparency = 1 }):Play()
		Debris:AddItem(bolt, 0.45)
	end

	return struck
end

-- ---------------------------------------------------------------------------
-- Dispatch
-- ---------------------------------------------------------------------------
Net.AbilityRequest.OnServerEvent:Connect(function(player: Player, slotArg: any)
	local slot = tostring(slotArg)
	local cfg = Abilities.Config[slot]
	if not cfg then
		return
	end

	local state = PlayerRegistry.get(player)
	local level = Progression.resolve(state.totalXp).level

	-- Level gate.
	if not Progression.isAbilityUnlocked(slot, level) then
		Net.CombatFeedback:FireClient(player, {
			outcome = "AbilityLocked",
			ability = slot,
			unlockLevel = Progression.AbilityUnlockLevel[slot],
		})
		return
	end

	-- Cost + cooldown gate.
	local casts = lastCast[player]
	if not casts then
		casts = {}
		lastCast[player] = casts
	end
	local now = os.clock()
	local gate = Abilities.tryCast(slot, state.tejas, casts[slot] or -math.huge, now)
	if not gate.ok then
		Net.CombatFeedback:FireClient(player, {
			outcome = if gate.reason == "tejas" then "NoTejas" else "AbilityCooldown",
			ability = slot,
			abilityName = cfg.name,
			tejas = state.tejas,
		})
		return
	end

	local character, root, hum = getCharacterParts(player)
	if not character or not root or not hum or hum.Health <= 0 then
		return
	end

	-- Commit the cast.
	state.tejas = gate.tejasAfter
	casts[slot] = now
	QuestService.onAbility(player)

	local extra: { [string]: any } = {}
	local animBySlot = { Z = "throw", X = "dash", C = "heal", V = "ult" }
	Net.AnimEvent:FireAllClients(character, animBySlot[slot])

	if slot == "Z" then
		castAgniAstra(player, character, root)
	elseif slot == "X" then
		castVayuDash(player, root, hum)
	elseif slot == "C" then
		castVarunaHeal(player, root, hum)
	elseif slot == "V" then
		extra.struck = castIndraWrath(player, root)
	end

	Net.CombatFeedback:FireClient(player, {
		outcome = "AbilityCast",
		ability = slot,
		abilityName = cfg.name,
		tejas = state.tejas,
		struck = extra.struck,
	})
end)

print("[Dharma] AbilityService ready — Z Agni, X Vayu, C Varuna, V Indra.")
