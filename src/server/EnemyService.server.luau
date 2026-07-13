--!strict
-- Spawns varied rigged enemies (data-driven archetypes) and drives them with the
-- tested EnemyAI logic. Landing the kill grants that player XP.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CollectionService = game:GetService("CollectionService")
local RunService = game:GetService("RunService")
local Players = game:GetService("Players")

local Net = require(ReplicatedStorage.Shared.Net)
local Combat = require(ReplicatedStorage.Shared.Combat)
local EnemyAI = require(ReplicatedStorage.Shared.EnemyAI)
local EnemyTypes = require(ReplicatedStorage.Shared.EnemyTypes)
local PlayerRegistry = require(script.Parent.PlayerRegistry)
local ProgressionService = require(script.Parent.ProgressionService)

local ENEMY_TAG = "DharmaEnemy"
local NUM_ENEMIES = 5
local SPAWN_RADIUS = 42
local RESPAWN_DELAY = 5

type EnemyState = {
	model: Model,
	humanoid: Humanoid,
	root: BasePart,
	archetype: EnemyTypes.EnemyArchetype,
	nextAttackAt: number,
	staggeredUntil: number,
}

local enemies: { [Model]: EnemyState } = {}

local function getRoot(model: Model): BasePart?
	local root = model:FindFirstChild("HumanoidRootPart")
	if root and root:IsA("BasePart") then
		return root
	end
	return model.PrimaryPart
end

local function nearestPlayer(pos: Vector3): (Player?, BasePart?, Humanoid?, number)
	local bestPlayer: Player? = nil
	local bestRoot: BasePart? = nil
	local bestHum: Humanoid? = nil
	local bestDist = math.huge

	for _, player in Players:GetPlayers() do
		local char = player.Character
		if not char then
			continue
		end
		local root = getRoot(char)
		local hum = char:FindFirstChildOfClass("Humanoid")
		if not root or not hum or hum.Health <= 0 then
			continue
		end
		local d = (root.Position - pos).Magnitude
		if d < bestDist then
			bestDist = d
			bestPlayer = player
			bestRoot = root
			bestHum = hum
		end
	end

	return bestPlayer, bestRoot, bestHum, bestDist
end

local function facingDot(fromRoot: BasePart, targetPos: Vector3): number
	local offset = targetPos - fromRoot.Position
	if offset.Magnitude < 0.01 then
		return 1
	end
	return fromRoot.CFrame.LookVector:Dot(offset.Unit)
end

local function enemyStrikes(enemy: EnemyState, player: Player, playerRoot: BasePart, playerHum: Humanoid)
	local pstate = PlayerRegistry.get(player)
	local now = os.clock()

	local state = {
		isDodging = now < pstate.dodgeUntil,
		isBlocking = pstate.isBlocking,
		blockAgeSeconds = now - pstate.blockStartedAt,
		facingAttacker = facingDot(playerRoot, enemy.root.Position) > 0.1,
	}

	local resolution = Combat.resolveIncomingAttack(enemy.archetype.attackDamage, state)

	if resolution.damage > 0 then
		playerHum:TakeDamage(resolution.damage)
	end
	if resolution.defenderTejasGain > 0 then
		pstate.tejas = Combat.clampTejas(pstate.tejas + resolution.defenderTejasGain)
	end
	if resolution.attackerStaggered then
		enemy.staggeredUntil = now + 1.0
		enemy.humanoid:MoveTo(enemy.root.Position)
	end

	Net.CombatFeedback:FireClient(player, {
		outcome = resolution.outcome,
		incoming = true,
		tejas = pstate.tejas,
	})
end

local function stepEnemy(enemy: EnemyState)
	local now = os.clock()
	if now < enemy.staggeredUntil then
		return
	end

	local player, playerRoot, playerHum, dist = nearestPlayer(enemy.root.Position)
	local a = enemy.archetype

	local action = EnemyAI.decide({
		distance = dist,
		aggroRange = a.aggroRange,
		attackRange = a.attackRange,
		attackReady = now >= enemy.nextAttackAt,
		targetAlive = player ~= nil,
	})

	if action == "Chase" and playerRoot then
		enemy.humanoid:MoveTo(playerRoot.Position)
	elseif action == "Attack" and player and playerRoot and playerHum then
		enemy.nextAttackAt = now + a.attackInterval
		enemyStrikes(enemy, player, playerRoot, playerHum)
	end
end

local function spawnEnemy(index: number)
	local archetype = EnemyTypes.pick()
	local skin = Color3.fromRGB(archetype.skin[1], archetype.skin[2], archetype.skin[3])

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
		warn("[Dharma] Failed to create enemy rig: " .. tostring(model))
		return
	end

	local humanoid = model:FindFirstChildOfClass("Humanoid")
	local root = getRoot(model)
	if not humanoid or not root then
		model:Destroy()
		return
	end

	humanoid.MaxHealth = archetype.maxHealth
	humanoid.Health = archetype.maxHealth
	humanoid.WalkSpeed = archetype.walkSpeed
	humanoid.DisplayName = archetype.displayName

	pcall(function()
		model:ScaleTo(archetype.scale)
	end)

	local angle = (2 * math.pi * index) / NUM_ENEMIES + math.random() * 0.6
	local pos = Vector3.new(math.cos(angle) * SPAWN_RADIUS, 6, math.sin(angle) * SPAWN_RADIUS)
	model:PivotTo(CFrame.new(pos))
	model.Name = archetype.displayName
	model.Parent = workspace

	CollectionService:AddTag(model, ENEMY_TAG)

	enemies[model] = {
		model = model,
		humanoid = humanoid,
		root = root,
		archetype = archetype,
		nextAttackAt = 0,
		staggeredUntil = 0,
	}

	humanoid.Died:Connect(function()
		enemies[model] = nil
		CollectionService:RemoveTag(model, ENEMY_TAG)

		-- Award XP to whoever landed the last hit.
		local killerId = model:GetAttribute("LastAttacker")
		if typeof(killerId) == "number" then
			local killer = Players:GetPlayerByUserId(killerId)
			if killer then
				ProgressionService.awardXp(killer, archetype.xpReward)
			end
		end

		task.delay(4, function()
			model:Destroy()
		end)
		task.delay(RESPAWN_DELAY, function()
			spawnEnemy(index)
		end)
	end)
end

for i = 1, NUM_ENEMIES do
	task.spawn(spawnEnemy, i)
end

RunService.Heartbeat:Connect(function()
	for _, enemy in enemies do
		stepEnemy(enemy)
	end
end)

print("[Dharma] EnemyService ready — spawning " .. NUM_ENEMIES .. " varied enemies.")
