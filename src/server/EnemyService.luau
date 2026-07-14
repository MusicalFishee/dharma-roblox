--!strict
-- Enemy engine (module): the wave system asks it to spawn enemies; it runs their
-- AI, applies their strikes, grants XP on death, and reports deaths back.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CollectionService = game:GetService("CollectionService")
local RunService = game:GetService("RunService")
local Players = game:GetService("Players")

local Net = require(ReplicatedStorage.Shared.Net)
local Combat = require(ReplicatedStorage.Shared.Combat)
local EnemyAI = require(ReplicatedStorage.Shared.EnemyAI)
local EnemyTypes = require(ReplicatedStorage.Shared.EnemyTypes)
local BossSpecials = require(ReplicatedStorage.Shared.BossSpecials)
local PlayerRegistry = require(script.Parent.PlayerRegistry)
local ProgressionService = require(script.Parent.ProgressionService)
local LootService = require(script.Parent.LootService)

local ENEMY_TAG = "DharmaEnemy"

local EnemyService = {}

type EnemyState = {
	model: Model,
	humanoid: Humanoid,
	root: BasePart,
	archetype: EnemyTypes.EnemyArchetype,
	nextAttackAt: number,
	staggeredUntil: number,
	castingUntil: number,
	onDeath: ((Player?) -> ())?,
}

local enemies: { [Model]: EnemyState } = {}
local alive = 0

local function broadcastAll(data: { [string]: any })
	for _, p in Players:GetPlayers() do
		Net.CombatFeedback:FireClient(p, data)
	end
end

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
	if now < enemy.staggeredUntil or now < enemy.castingUntil then
		return -- staggered by a parry, or winding up a special
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

function EnemyService.aliveCount(): number
	return alive
end

function EnemyService.spawn(archetype: EnemyTypes.EnemyArchetype, position: Vector3, onDeath: ((Player?) -> ())?)
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
		if onDeath then
			onDeath(nil) -- don't stall the wave on a failed spawn
		end
		return
	end

	local humanoid = model:FindFirstChildOfClass("Humanoid")
	local root = getRoot(model)
	if not humanoid or not root then
		model:Destroy()
		if onDeath then
			onDeath(nil)
		end
		return
	end

	humanoid.MaxHealth = archetype.maxHealth
	humanoid.Health = archetype.maxHealth
	humanoid.WalkSpeed = archetype.walkSpeed
	humanoid.DisplayName = archetype.displayName

	pcall(function()
		model:ScaleTo(archetype.scale)
	end)

	model:PivotTo(CFrame.new(position))
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
		castingUntil = 0,
		onDeath = onDeath,
	}
	alive += 1

	-- Bosses drive the on-screen health bar.
	if archetype.isBoss then
		local maxHp = archetype.maxHealth
		broadcastAll({
			bossState = "spawn",
			bossName = archetype.displayName,
			bossTitle = archetype.title,
			bossHealth = maxHp,
			bossMaxHealth = maxHp,
		})
		humanoid.HealthChanged:Connect(function(health: number)
			broadcastAll({ bossState = "health", bossHealth = math.max(0, health), bossMaxHealth = maxHp })
		end)

		-- Telegraphed slam on a cooldown: wind up (boss halts), then AoE the danger zone.
		local special = BossSpecials.forBoss(archetype.id)
		task.spawn(function()
			while enemies[model] and humanoid.Health > 0 do
				task.wait(special.cooldown)
				local st = enemies[model]
				if not st or humanoid.Health <= 0 then
					break
				end

				local _p, _r, _h, dist = nearestPlayer(st.root.Position)
				if dist > special.radius + 45 then
					continue -- nobody close enough to bother slamming
				end

				local now = os.clock()
				st.castingUntil = now + special.telegraph
				local cx, cy, cz = st.root.Position.X, st.root.Position.Y - 2.5, st.root.Position.Z
				broadcastAll({
					bossSpecial = "telegraph",
					name = special.name,
					x = cx,
					y = cy,
					z = cz,
					radius = special.radius,
					duration = special.telegraph,
				})

				task.wait(special.telegraph)
				if humanoid.Health <= 0 then
					break
				end

				-- Impact: everyone still standing in the zone takes the hit.
				local targets: { BossSpecials.Target } = {}
				for _, plr in Players:GetPlayers() do
					local char = plr.Character
					if not char then
						continue
					end
					local hrp = char:FindFirstChild("HumanoidRootPart")
					if hrp and hrp:IsA("BasePart") then
						table.insert(targets, { key = plr, x = hrp.Position.X, z = hrp.Position.Z })
					end
				end
				for _, key in BossSpecials.hitTargets({ x = cx, z = cz }, targets, special.radius) do
					local victim = key :: Player
					local char = victim.Character
					local hum = char and char:FindFirstChildOfClass("Humanoid")
					if hum then
						hum:TakeDamage(special.damage)
					end
				end
				broadcastAll({ bossSpecial = "impact", x = cx, y = cy, z = cz, radius = special.radius })
			end
		end)
	end

	local handled = false
	humanoid.Died:Connect(function()
		if handled then
			return
		end
		handled = true
		enemies[model] = nil
		alive = math.max(0, alive - 1)
		CollectionService:RemoveTag(model, ENEMY_TAG)

		local killerId = model:GetAttribute("LastAttacker")
		local killer: Player? = nil
		if typeof(killerId) == "number" then
			killer = Players:GetPlayerByUserId(killerId)
			if killer then
				ProgressionService.awardXp(killer, archetype.xpReward)
			end
		end

		if archetype.isBoss then
			broadcastAll({ bossState = "defeated", bossName = archetype.displayName })
		end

		-- Burst into loot where it fell.
		LootService.dropAt(root.Position, archetype)

		if onDeath then
			onDeath(killer)
		end
		task.delay(3, function()
			model:Destroy()
		end)
	end)
end

function EnemyService.clearAll()
	for model in enemies do
		model:Destroy()
	end
	table.clear(enemies)
	alive = 0
end

RunService.Heartbeat:Connect(function()
	for _, enemy in enemies do
		stepEnemy(enemy)
	end
end)

return EnemyService
