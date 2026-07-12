--!strict
-- Spawns rigged enemy NPCs and drives them with the tested EnemyAI decision logic.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CollectionService = game:GetService("CollectionService")
local RunService = game:GetService("RunService")
local Players = game:GetService("Players")

local Net = require(ReplicatedStorage.Shared.Net)
local Combat = require(ReplicatedStorage.Shared.Combat)
local EnemyAI = require(ReplicatedStorage.Shared.EnemyAI)
local PlayerRegistry = require(script.Parent.PlayerRegistry)

local ENEMY_TAG = "DharmaEnemy"
local NUM_ENEMIES = 4
local SPAWN_RADIUS = 40
local RESPAWN_DELAY = 5

type EnemyState = {
	model: Model,
	humanoid: Humanoid,
	root: BasePart,
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

-- Nearest living player character to a position.
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
		-- The player must be facing the enemy to block/parry it.
		facingAttacker = facingDot(playerRoot, enemy.root.Position) > 0.1,
	}

	local resolution = Combat.resolveIncomingAttack(Combat.Config.EnemyAttackDamage, state)

	if resolution.damage > 0 then
		playerHum:TakeDamage(resolution.damage)
	end
	if resolution.defenderTejasGain > 0 then
		pstate.tejas = Combat.clampTejas(pstate.tejas + resolution.defenderTejasGain)
	end
	if resolution.attackerStaggered then
		enemy.staggeredUntil = now + 1.0
		enemy.humanoid:MoveTo(enemy.root.Position) -- halt
	end

	Net.CombatFeedback:FireClient(player, {
		outcome = resolution.outcome,
		incoming = true,
		tejas = pstate.tejas,
	})
end

local function stepEnemy(enemy: EnemyState, dt: number)
	local now = os.clock()
	if now < enemy.staggeredUntil then
		return
	end

	local player, playerRoot, playerHum, dist = nearestPlayer(enemy.root.Position)

	local action = EnemyAI.decide({
		distance = dist,
		aggroRange = Combat.Config.EnemyAggroRange,
		attackRange = Combat.Config.EnemyAttackRange,
		attackReady = now >= enemy.nextAttackAt,
		targetAlive = player ~= nil,
	})

	if action == "Chase" and playerRoot then
		enemy.humanoid:MoveTo(playerRoot.Position)
	elseif action == "Attack" and player and playerRoot and playerHum then
		enemy.nextAttackAt = now + Combat.Config.EnemyAttackInterval
		enemyStrikes(enemy, player, playerRoot, playerHum)
	end
end

local function spawnEnemy(index: number)
	local ok, model = pcall(function()
		local desc = Instance.new("HumanoidDescription")
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

	humanoid.MaxHealth = Combat.Config.EnemyMaxHealth
	humanoid.Health = Combat.Config.EnemyMaxHealth
	humanoid.WalkSpeed = Combat.Config.EnemyWalkSpeed
	humanoid.DisplayName = "Asura"

	local angle = (2 * math.pi * index) / NUM_ENEMIES
	local pos = Vector3.new(math.cos(angle) * SPAWN_RADIUS, 6, math.sin(angle) * SPAWN_RADIUS)
	model:PivotTo(CFrame.new(pos))
	model.Name = "Asura"
	model.Parent = workspace

	CollectionService:AddTag(model, ENEMY_TAG)

	local state: EnemyState = {
		model = model,
		humanoid = humanoid,
		root = root,
		nextAttackAt = 0,
		staggeredUntil = 0,
	}
	enemies[model] = state

	humanoid.Died:Connect(function()
		enemies[model] = nil
		CollectionService:RemoveTag(model, ENEMY_TAG)
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

RunService.Heartbeat:Connect(function(dt: number)
	for _, enemy in enemies do
		stepEnemy(enemy, dt)
	end
end)

print("[Dharma] EnemyService ready — spawning " .. NUM_ENEMIES .. " asuras.")
