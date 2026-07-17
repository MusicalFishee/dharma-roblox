--!strict
-- The Astra kit, server-side. Since Astra Paths, the Z/X/C/V slots resolve
-- through the player's sworn path (Paths.kitFor) into the ability Catalog;
-- every ability is one of six primitives steered by its def:
--   projectile — a flying bolt (Agni Astra, Vayu Blade, Tide Lash, Vajra Bolt)
--   dash       — an impulse with i-frames (Vayu Dash, Ember Rush, Gale Step, ...)
--   heal       — mend a fraction of max HP, optionally cleansing (Varuna's Grace, Deep Mending)
--   ward       — a timed buff: shield (damage taken down) or empower (damage dealt up)
--   nova       — a self-centered blast with knockback (Pyre Nova, Tempest, Pralaya Flame)
--   smite      — sky-strikes on every enemy in a radius (Indra's Wrath, The Deluge)
-- Gating (Tejas cost, cooldown, level unlock) is validated server-side.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local Debris = game:GetService("Debris")
local TweenService = game:GetService("TweenService")

local Net = require(ReplicatedStorage.Shared.Net)
local Abilities = require(ReplicatedStorage.Shared.Abilities)
local Paths = require(ReplicatedStorage.Shared.Paths)
local Siddhis = require(ReplicatedStorage.Shared.Siddhis)
local Vara = require(ReplicatedStorage.Shared.Vara)
local Reactions = require(ReplicatedStorage.Shared.Reactions)
local Progression = require(ReplicatedStorage.Shared.Progression)
local StatusEffects = require(ReplicatedStorage.Shared.StatusEffects)
local PvP = require(ReplicatedStorage.Shared.PvP)
local PlayerRegistry = require(script.Parent.PlayerRegistry)
local QuestService = require(script.Parent.QuestService)
local PvPService = require(script.Parent.PvPService)
local EnemyService = require(script.Parent.EnemyService)
local RitesService = require(script.Parent.RitesService)

local ENEMY_TAG = "DharmaEnemy"

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

local function toColor3(rgb: { number }): Color3
	return Color3.fromRGB(rgb[1], rgb[2], rgb[3])
end

-- Path passive + active empower ward, applied to all ability damage.
local function damageMultFor(state: any): number
	local varaFx = Vara.totalEffects(state.vara)
	local mult = Paths.passiveOf(state.path).damageMult * varaFx.damageMult * varaFx.abilityDamageMult * RitesService.mults().damageMult
	if os.clock() < state.empowerUntil then
		mult *= state.empowerMult
	end
	return mult
end

-- ---------------------------------------------------------------------------
-- Astra Reactions: a damaging Astra marks its victim with its element; a
-- different element on a live mark detonates. Marks live on the ENEMY, so
-- two players can combo each other's casts.
-- ---------------------------------------------------------------------------
local function applyElement(player: Player, model: Model, humanoid: Humanoid, abilityId: string)
	local element = Reactions.elementOf(abilityId)
	if not element then
		return
	end
	local now = os.clock()
	local mark = model:GetAttribute("ElemMark")
	local markUntil = model:GetAttribute("ElemMarkUntil")
	if typeof(mark) == "string" and typeof(markUntil) == "number" then
		local def = Reactions.tryReact(mark, markUntil, now, element)
		if def then
			model:SetAttribute("ElemMark", nil)
			model:SetAttribute("ElemMarkUntil", nil)
			model:SetAttribute("LastAttacker", player.UserId)
			humanoid:TakeDamage(def.bonusDamage)

			local eroot = model:FindFirstChild("HumanoidRootPart")
			if eroot and eroot:IsA("BasePart") then
				-- The detonation flash.
				local burst = Instance.new("Part")
				burst.Shape = Enum.PartType.Ball
				burst.Size = Vector3.new(3, 3, 3)
				burst.Position = eroot.Position
				burst.Color = Color3.fromRGB(255, 240, 200)
				burst.Material = Enum.Material.Neon
				burst.Transparency = 0.2
				burst.Anchored = true
				burst.CanCollide = false
				burst.CanQuery = false
				burst.Parent = workspace
				TweenService:Create(burst, TweenInfo.new(0.4), { Size = Vector3.new(9, 9, 9), Transparency = 1 }):Play()
				Debris:AddItem(burst, 0.45)
			end

			if def.flourish == "ignite" then
				if model:GetAttribute("Burning") ~= true then
					model:SetAttribute("Burning", true)
					if eroot and eroot:IsA("BasePart") then
						local flame = Instance.new("Fire")
						flame.Size = 5
						flame.Heat = 9
						flame.Color = Color3.fromRGB(255, 120, 30)
						flame.Parent = eroot
						Debris:AddItem(flame, 4)
					end
					task.spawn(function()
						for _ = 1, 4 do
							task.wait(1)
							if humanoid.Health <= 0 or not model.Parent then
								break
							end
							humanoid:TakeDamage(def.magnitude / 4)
						end
						model:SetAttribute("Burning", nil)
					end)
				end
			elseif def.flourish == "slow" then
				if model:GetAttribute("ElemSlowed") ~= true then
					model:SetAttribute("ElemSlowed", true)
					local prior = humanoid.WalkSpeed
					humanoid.WalkSpeed = prior * def.magnitude
					task.delay(4, function()
						if humanoid.Parent and humanoid.Health > 0 then
							humanoid.WalkSpeed = prior
						end
						model:SetAttribute("ElemSlowed", nil)
					end)
				end
			elseif def.flourish == "knockback" then
				if eroot and eroot:IsA("BasePart") then
					eroot.AssemblyLinearVelocity = Vector3.new(0, def.magnitude * 0.6, 0)
						+ eroot.CFrame.LookVector * -def.magnitude
				end
			elseif def.flourish == "tejas" then
				local state = PlayerRegistry.get(player)
				state.tejas = math.min(state.tejas + def.magnitude, 999)
			elseif def.flourish == "chain" then
				if eroot and eroot:IsA("BasePart") then
					for _, other in CollectionService:GetTagged(ENEMY_TAG) do
						if other:IsA("Model") and other ~= model then
							local oh = other:FindFirstChildOfClass("Humanoid")
							local orx = other:FindFirstChild("HumanoidRootPart")
							if oh and oh.Health > 0 and orx and orx:IsA("BasePart") and (orx.Position - eroot.Position).Magnitude <= 12 then
								other:SetAttribute("LastAttacker", player.UserId)
								oh:TakeDamage(def.magnitude)
							end
						end
					end
				end
			end

			Net.CombatFeedback:FireClient(player, { reaction = true, name = def.name, damage = def.bonusDamage })
			return
		end
	end
	model:SetAttribute("ElemMark", element)
	model:SetAttribute("ElemMarkUntil", now + Reactions.Window)
end

-- ---------------------------------------------------------------------------
-- projectile
-- ---------------------------------------------------------------------------
local function castProjectile(player: Player, character: Model, root: BasePart, def: Abilities.AbilityDef, mult: number, pierceExtra: number, forkExtra: number)
	local color = toColor3(def.color)

	-- One bolt. Siddhi-pierced bolts survive (pierceLimit - 1) extra enemies;
	-- forked twins fly at an angle with softened damage and no further forking.
	local function fire(aim: Vector3, damage: number, pierceLimit: number)
		local spawnPos = root.Position + aim * 3 + Vector3.new(0, 1, 0)

		local bolt = Instance.new("Part")
		bolt.Name = "AstraBolt"
		bolt.Shape = Enum.PartType.Ball
		bolt.Size = Vector3.new(2, 2, 2)
		bolt.Color = color
		bolt.Material = Enum.Material.Neon
		bolt.CanCollide = false
		bolt.Massless = true
		bolt.CFrame = CFrame.new(spawnPos, spawnPos + aim)
		bolt.Parent = workspace

		if def.flame then
			local fire2 = Instance.new("Fire")
			fire2.Size = 5
			fire2.Heat = 10
			fire2.Color = color
			fire2.Parent = bolt
		else
			local light = Instance.new("PointLight")
			light.Color = color
			light.Range = 12
			light.Brightness = 2
			light.Parent = bolt
		end

		local att = Instance.new("Attachment")
		att.Parent = bolt
		local lv = Instance.new("LinearVelocity")
		lv.Attachment0 = att
		lv.MaxForce = math.huge
		lv.VectorVelocity = aim * (def.speed or 90)
		lv.Parent = bolt

		Debris:AddItem(bolt, 3)

		local pierceLeft = pierceLimit
		local struck: { [Model]: boolean } = {}
		local spent = false
		local conn: RBXScriptConnection
		conn = bolt.Touched:Connect(function(other: BasePart)
			if spent then
				return
			end
			local model = other:FindFirstAncestorOfClass("Model")
			if not model or model == character then
				return
			end

			-- Enemies eat the bolt; a pierced bolt keeps flying through them.
			if CollectionService:HasTag(model, ENEMY_TAG) then
				if struck[model] then
					return
				end
				local humanoid = model:FindFirstChildOfClass("Humanoid")
				if not humanoid or humanoid.Health <= 0 then
					return
				end
				struck[model] = true
				model:SetAttribute("LastAttacker", player.UserId)
				humanoid:TakeDamage(damage)
				applyElement(player, model, humanoid, def.id)
				pierceLeft -= 1
				if pierceLeft <= 0 then
					spent = true
					conn:Disconnect()
					bolt:Destroy()
				end
				return
			end

			-- A live duel foe can eat it too (softened, dodgeable, blockable).
			local foe = PvPService.duelOpponentOf(player)
			if foe and foe.Character == model then
				local hum = model:FindFirstChildOfClass("Humanoid")
				local froot = model:FindFirstChild("HumanoidRootPart")
				if hum and hum.Health > 0 and froot and froot:IsA("BasePart") then
					spent = true
					conn:Disconnect()
					EnemyService.resolveHitOnPlayer(foe, froot, hum, damage * PvP.Config.DamageMult, bolt.Position, nil)
					bolt:Destroy()
				end
			end
		end)
	end

	local aim = root.CFrame.LookVector
	local damage = def.power * mult
	fire(aim, damage, 1 + pierceExtra)
	for i = 1, forkExtra do
		-- Twins alternate sides: +14°, -14°, +28°, ...
		local side = if i % 2 == 1 then 1 else -1
		local angle = math.rad(14 * math.ceil(i / 2) * side)
		local rotated = CFrame.fromAxisAngle(Vector3.yAxis, angle) * aim
		fire(rotated, damage * 0.6, 1 + pierceExtra)
	end
end

-- ---------------------------------------------------------------------------
-- dash
-- ---------------------------------------------------------------------------
local function castDash(player: Player, root: BasePart, hum: Humanoid, def: Abilities.AbilityDef)
	-- Dash along the current move direction (or facing if standing still).
	local dir = hum.MoveDirection
	if dir.Magnitude < 0.1 then
		dir = root.CFrame.LookVector
	end
	dir = Vector3.new(dir.X, 0, dir.Z).Unit

	root.AssemblyLinearVelocity = dir * def.power + Vector3.new(0, 12, 0)

	local state = PlayerRegistry.get(player)
	state.dodgeUntil = os.clock() + (def.iFrames or 0.5)

	local streak = Instance.new("Part")
	streak.Size = Vector3.new(1.2, 1.2, 7)
	streak.CFrame = CFrame.new(root.Position - dir * 3, root.Position + dir * 4)
	streak.Color = toColor3(def.color)
	streak.Material = Enum.Material.Neon
	streak.Transparency = 0.35
	streak.Anchored = true
	streak.CanCollide = false
	streak.CanQuery = false
	streak.Parent = workspace
	if def.flame then
		local fire = Instance.new("Fire")
		fire.Size = 4
		fire.Color = toColor3(def.color)
		fire.Parent = streak
	end
	TweenService:Create(streak, TweenInfo.new(0.35), { Transparency = 1 }):Play()
	Debris:AddItem(streak, 0.4)
end

-- ---------------------------------------------------------------------------
-- heal
-- ---------------------------------------------------------------------------
local function castHeal(player: Player, root: BasePart, hum: Humanoid, def: Abilities.AbilityDef, bonusFraction: number)
	local state = PlayerRegistry.get(player)
	if def.cleanse then
		-- Deep Mending washes afflictions away BEFORE the heal, so it's never thinned.
		state.venomUntil = 0
		state.curseUntil = 0
	end
	-- A curse thins even Varuna's waters (unless just cleansed); Sthira deepens them.
	local heal = StatusEffects.effectiveHeal(hum.MaxHealth * (def.power + bonusFraction) * Vara.totalEffects(state.vara).healMult, os.clock() < state.curseUntil)
	hum.Health = math.min(hum.MaxHealth, hum.Health + heal)

	-- Rising glow in the ability's color.
	local glow = Instance.new("Part")
	glow.Shape = Enum.PartType.Ball
	glow.Size = Vector3.new(8, 8, 8)
	glow.Position = root.Position
	glow.Color = toColor3(def.color)
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
-- ward
-- ---------------------------------------------------------------------------
local function castWard(player: Player, root: BasePart, def: Abilities.AbilityDef, bonusSeconds: number)
	local state = PlayerRegistry.get(player)
	local duration = (def.duration or 4) + bonusSeconds
	local until_ = os.clock() + duration
	if def.wardKind == "empower" then
		state.empowerUntil = until_
		state.empowerMult = def.power
	else
		state.wardUntil = until_
		state.wardMult = def.power
	end

	-- A swirling shell that clings to the player for the duration.
	local shell = Instance.new("Part")
	shell.Shape = Enum.PartType.Ball
	shell.Size = Vector3.new(9, 9, 9)
	shell.Color = toColor3(def.color)
	shell.Material = Enum.Material.ForceField
	shell.Transparency = 0.5
	shell.CanCollide = false
	shell.CanQuery = false
	shell.Massless = true
	shell.CFrame = root.CFrame
	shell.Parent = workspace
	local weld = Instance.new("WeldConstraint")
	weld.Part0 = shell
	weld.Part1 = root
	weld.Parent = shell
	Debris:AddItem(shell, duration)
end

-- ---------------------------------------------------------------------------
-- nova
-- ---------------------------------------------------------------------------
local function castNova(player: Player, root: BasePart, def: Abilities.AbilityDef, mult: number, radiusMult: number, ultIFrames: number): number
	local radius = (def.radius or 14) * radiusMult
	local damage = def.power * mult
	local knockback = def.knockback or 0
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
		local offset = eroot.Position - root.Position
		if Vector3.new(offset.X, 0, offset.Z).Magnitude > radius then
			continue
		end

		struck += 1
		enemy:SetAttribute("LastAttacker", player.UserId)
		humanoid:TakeDamage(damage)
		applyElement(player, enemy, humanoid, def.id)

		if knockback > 0 then
			local flat = Vector3.new(offset.X, 0, offset.Z)
			local dir = if flat.Magnitude > 0.01 then flat.Unit else root.CFrame.LookVector
			eroot.AssemblyLinearVelocity = dir * knockback + Vector3.new(0, knockback * 0.4, 0)
		end
	end

	-- The blast ring races outward and fades.
	local ring = Instance.new("Part")
	ring.Shape = Enum.PartType.Cylinder
	ring.Size = Vector3.new(0.6, 4, 4)
	ring.CFrame = CFrame.new(root.Position) * CFrame.Angles(0, 0, math.rad(90))
	ring.Color = toColor3(def.color)
	ring.Material = Enum.Material.Neon
	ring.Transparency = 0.2
	ring.Anchored = true
	ring.CanCollide = false
	ring.CanQuery = false
	ring.Parent = workspace
	TweenService:Create(ring, TweenInfo.new(0.45, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		Size = Vector3.new(0.6, radius * 2, radius * 2),
		Transparency = 1,
	}):Play()
	Debris:AddItem(ring, 0.5)

	-- Eye of the Tempest: the ultimate's aftermath leaves its caster untouchable.
	if ultIFrames > 0 then
		local state = PlayerRegistry.get(player)
		state.dodgeUntil = math.max(state.dodgeUntil, os.clock() + ultIFrames)
	end

	return struck
end

-- ---------------------------------------------------------------------------
-- smite
-- ---------------------------------------------------------------------------
local function castSmite(player: Player, root: BasePart, hum: Humanoid, def: Abilities.AbilityDef, mult: number, radiusMult: number, selfHealMult: number): number
	local radius = (def.radius or 60) * radiusMult
	local damage = def.power * mult
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
		humanoid:TakeDamage(damage)
		applyElement(player, enemy, humanoid, def.id)

		-- A bolt from the sky onto the enemy, in the ability's color.
		local top = eroot.Position + Vector3.new(0, 60, 0)
		local bolt = Instance.new("Part")
		bolt.Size = Vector3.new(1.4, (top - eroot.Position).Magnitude, 1.4)
		bolt.CFrame = CFrame.new((top + eroot.Position) / 2, eroot.Position) * CFrame.Angles(math.rad(90), 0, 0)
		bolt.Color = toColor3(def.color)
		bolt.Material = Enum.Material.Neon
		bolt.Transparency = 0.1
		bolt.Anchored = true
		bolt.CanCollide = false
		bolt.CanQuery = false
		bolt.Parent = workspace
		TweenService:Create(bolt, TweenInfo.new(0.4), { Transparency = 1 }):Play()
		Debris:AddItem(bolt, 0.45)
	end

	-- The Deluge gives back: the storm mends its caster.
	if def.selfHeal and struck > 0 then
		local state = PlayerRegistry.get(player)
		local heal = StatusEffects.effectiveHeal(hum.MaxHealth * def.selfHeal * selfHealMult, os.clock() < state.curseUntil)
		hum.Health = math.min(hum.MaxHealth, hum.Health + heal)
	end

	return struck
end

-- ---------------------------------------------------------------------------
-- Dispatch
-- ---------------------------------------------------------------------------
Net.AbilityRequest.OnServerEvent:Connect(function(player: Player, slotArg: any)
	local slot = tostring(slotArg)
	if slot ~= "Z" and slot ~= "X" and slot ~= "C" and slot ~= "V" then
		return
	end

	local state = PlayerRegistry.get(player)
	local kit = Paths.kitFor(state.path)
	local abilityId = (kit :: any)[slot] :: string
	local def = Abilities.Catalog[abilityId]
	if not def then
		return
	end

	local level = Progression.resolve(state.totalXp).level

	-- Level gate (slot-based: Z@1, X@4, C@8, V@12 regardless of path).
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
	-- Mastery: what this path's ledger has already earned.
	local masteryLevel = Siddhis.resolve((state.mastery :: any)[state.path] or 0).level
	local eff = Siddhis.effectsFor(state.path, masteryLevel)
	local gateCheck = Abilities.tryCastAbility(abilityId, state.tejas, casts[slot] or -math.huge, now, eff.cooldownMult)
	if not gateCheck.ok then
		Net.CombatFeedback:FireClient(player, {
			outcome = if gateCheck.reason == "tejas" then "NoTejas" else "AbilityCooldown",
			ability = slot,
			abilityName = def.name,
			tejas = state.tejas,
		})
		return
	end

	local character, root, hum = getCharacterParts(player)
	if not character or not root or not hum or hum.Health <= 0 then
		return
	end
	if character:GetAttribute("DharmaDowned") == true or character:GetAttribute("DharmaBhoota") == true or character:GetAttribute("DharmaDhyana") == true then
		return -- the downed crawl; they do not cast
	end

	-- Commit the cast.
	state.tejas = gateCheck.tejasAfter
	casts[slot] = now
	QuestService.onAbility(player)

	-- Every cast feeds the sworn path's siddhi ledger (XP = the Tejas it burned).
	if Paths.isValid(state.path) then
		local ledger = state.mastery :: any
		local before = masteryLevel
		ledger[state.path] += def.tejasCost
		local after = Siddhis.resolve(ledger[state.path]).level
		if after > before then
			Net.CombatFeedback:FireClient(player, {
				masteryUp = true,
				level = after,
				pathName = Paths.Defs[state.path].name,
			})
			for lvl = before + 1, after do
				local unlock = Siddhis.unlockAt(state.path, lvl)
				if unlock then
					Net.CombatFeedback:FireClient(player, { siddhiUnlocked = true, name = unlock.name, line = unlock.line })
				end
			end
		end
	end

	local extra: { [string]: any } = {}
	local animBySlot = { Z = "throw", X = "dash", C = "heal", V = "ult" }
	Net.AnimEvent:FireAllClients(character, animBySlot[slot])

	local mult = damageMultFor(state) * eff.damageMult
	if def.kind == "projectile" then
		castProjectile(player, character, root, def, mult, eff.pierce[abilityId] or 0, eff.fork[abilityId] or 0)
	elseif def.kind == "dash" then
		castDash(player, root, hum, def)
	elseif def.kind == "heal" then
		castHeal(player, root, hum, def, eff.healBonusFraction)
	elseif def.kind == "ward" then
		castWard(player, root, def, eff.wardBonusSeconds)
	elseif def.kind == "nova" then
		extra.struck = castNova(player, root, def, mult, eff.radiusMult, if def.tejasCost >= 100 then eff.ultIFrames else 0)
	elseif def.kind == "smite" then
		extra.struck = castSmite(player, root, hum, def, mult, eff.radiusMult, eff.selfHealMult)
	end

	Net.CombatFeedback:FireClient(player, {
		outcome = "AbilityCast",
		ability = slot,
		abilityName = def.name,
		tejas = state.tejas,
		struck = extra.struck,
	})
end)

print("[Dharma] AbilityService ready — Astra Paths dispatch online.")
