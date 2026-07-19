--!strict
-- The Akhada, live: the full training yard across from the grove.
--   * An unkillable dummy takes every blade and Astra; its billboard reads
--     the last striker's 10s damage, DPS, and live combo string.
--   * Broken strings (5+ hits) are reported back to their owner — the
--     combo lab's verdict: hits, total, biggest blow, duration.
--   * A yard bell rings in a Sparring Rakshasa: it fights with the REAL
--     defense rules (via EnemyService.resolveHitOnPlayer — parries stagger
--     it, perfect parries arm ripostes) but pulls its punches, and its
--     death pays nothing. No XP, no kill, no loot: practice, pure.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")

local Net = require(ReplicatedStorage.Shared.Net)
local Akhada = require(ReplicatedStorage.Shared.Akhada)
local EnemyService = require(script.Parent.EnemyService)

local ENEMY_TAG = "DharmaEnemy"
local YARD_POS = Vector3.new(34, 4, -34)
local SPAR_HOME = YARD_POS + Vector3.new(6, 0, 8)

local AkhadaService = {}

local windows: { [number]: { Akhada.HitEvent } } = {} -- userId → rolling 10s read
local sessionBest: { [number]: Akhada.BestEntry } = {} -- userId → best 10s reading
local runs: { [number]: Akhada.Run } = {} -- userId → live combo string
local lastStrikerId = 0

local function buildRig(skin: Color3): (Model?, Humanoid?, BasePart?)
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
		warn("[Dharma] Failed to raise an akhada rig: " .. tostring(model))
		return nil, nil, nil
	end
	local rig = model :: Model
	local humanoid = rig:FindFirstChildOfClass("Humanoid")
	local root = rig:FindFirstChild("HumanoidRootPart")
	if not humanoid or not root or not root:IsA("BasePart") then
		rig:Destroy()
		return nil, nil, nil
	end
	return rig, humanoid, root
end

-- Close a string and, if it was worth reading, hand its owner the verdict.
local function reportRun(userId: number, run: Akhada.Run)
	if not Akhada.isNotable(run, Akhada.Config.MinReportHits) then
		return
	end
	local player = Players:GetPlayerByUserId(userId)
	if player then
		Net.CombatFeedback:FireClient(player, {
			akhadaString = true,
			hits = run.hits,
			total = math.floor(run.total),
			maxHit = math.floor(run.maxHit),
			seconds = math.max(run.lastAt - run.startedAt, 0.1),
		})
	end
end

-- Trainees only: the standing, the living, the present.
local function nearestTrainee(pos: Vector3): (Player?, BasePart?, Humanoid?, number)
	local bestPlayer: Player? = nil
	local bestRoot: BasePart? = nil
	local bestHum: Humanoid? = nil
	local bestDist = math.huge
	for _, player in Players:GetPlayers() do
		local char = player.Character
		if not char then
			continue
		end
		local root = char:FindFirstChild("HumanoidRootPart")
		local hum = char:FindFirstChildOfClass("Humanoid")
		if not root or not root:IsA("BasePart") or not hum or hum.Health <= 0 then
			continue
		end
		if char:GetAttribute("DharmaDowned") == true or char:GetAttribute("DharmaBhoota") == true or char:GetAttribute("DharmaDhyana") == true then
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

-- ── The sparring partner ────────────────────────────────────────────────────
local sparOut = false

local function raiseSparringPartner(bell: ProximityPrompt)
	local spar = Akhada.Spar
	local rig, humanoid, root = buildRig(Color3.fromRGB(120, 45, 40))
	if not rig or not humanoid or not root then
		sparOut = false
		bell.Enabled = true
		return
	end

	humanoid.MaxHealth = spar.Health
	humanoid.Health = spar.Health
	humanoid.WalkSpeed = spar.WalkSpeed
	humanoid.DisplayName = spar.DisplayName
	rig.Name = "SparringRakshasa"
	rig:SetAttribute("IsBoss", true) -- executes never claim sparring partners
	rig:PivotTo(CFrame.new(SPAR_HOME))
	rig.Parent = workspace
	CollectionService:AddTag(rig, ENEMY_TAG)

	local hum = humanoid :: Humanoid
	local rootPart = root :: BasePart

	hum.Died:Connect(function()
		CollectionService:RemoveTag(rig, ENEMY_TAG)
		task.delay(2, function()
			rig:Destroy()
		end)
		task.delay(3, function()
			sparOut = false
			bell.Enabled = true
		end)
	end)

	task.spawn(function()
		local nextAttackAt = 0
		local staggeredUntil = 0
		local lonelySince: number? = nil
		while rig.Parent and hum.Health > 0 do
			task.wait(0.25)
			local now = os.clock()
			if now < staggeredUntil then
				continue -- a parry rang its skull; let the trainee savor it
			end

			local player, proot, phum, dist = nearestTrainee(rootPart.Position)
			if not player or not proot or not phum or dist > spar.AggroRadius then
				hum:MoveTo(SPAR_HOME)
				local since = lonelySince or now
				lonelySince = since
				if now - since > spar.LonelySeconds then
					break -- bows out; nobody came to train
				end
				continue
			end
			lonelySince = nil

			if (rootPart.Position - SPAR_HOME).Magnitude > spar.LeashRadius then
				hum:MoveTo(SPAR_HOME) -- the yard's fight stays in the yard
				continue
			end

			if dist > spar.AttackRange then
				hum:MoveTo(proot.Position)
			elseif now >= nextAttackAt then
				nextAttackAt = now + spar.AttackInterval
				Net.AnimEvent:FireAllClients(rig, "enemySwing")
				local res = EnemyService.resolveHitOnPlayer(player, proot, phum, spar.Damage, rootPart.Position, nil)
				if res.attackerStaggered then
					staggeredUntil = now + 1.0
				end
			end
		end
		if rig.Parent and hum.Health > 0 then
			rig:Destroy()
			sparOut = false
			bell.Enabled = true
		end
	end)
end

-- ── The yard itself ─────────────────────────────────────────────────────────
local function buildYard(): (Humanoid?, TextLabel?, TextLabel?)
	local mat = Instance.new("Part")
	mat.Name = "AkhadaMat"
	mat.Size = Vector3.new(14, 0.4, 14)
	mat.Position = YARD_POS - Vector3.new(0, 3.2, 0)
	mat.Color = Color3.fromRGB(140, 100, 60)
	mat.Material = Enum.Material.WoodPlanks
	mat.Anchored = true
	mat.Parent = workspace

	-- The bell: ring for a sparring partner.
	local post = Instance.new("Part")
	post.Name = "AkhadaBell"
	post.Size = Vector3.new(1, 4, 1)
	post.Position = YARD_POS + Vector3.new(9, -1, 0)
	post.Color = Color3.fromRGB(90, 65, 40)
	post.Material = Enum.Material.Wood
	post.Anchored = true
	post.Parent = workspace
	local bellTop = Instance.new("Part")
	bellTop.Shape = Enum.PartType.Ball
	bellTop.Size = Vector3.new(1.4, 1.4, 1.4)
	bellTop.Position = post.Position + Vector3.new(0, 2.6, 0)
	bellTop.Color = Color3.fromRGB(230, 190, 90)
	bellTop.Material = Enum.Material.Metal
	bellTop.Anchored = true
	bellTop.Parent = workspace
	local bell = Instance.new("ProximityPrompt")
	bell.ActionText = "Ring the bell"
	bell.ObjectText = "Call a sparring partner"
	bell.HoldDuration = 0.5
	bell.RequiresLineOfSight = false
	bell.Parent = post
	bell.Triggered:Connect(function()
		if sparOut then
			return
		end
		sparOut = true
		bell.Enabled = false
		raiseSparringPartner(bell)
	end)

	-- Today's Fiercest: a plank of session records beside the mat.
	local recordPost = Instance.new("Part")
	recordPost.Name = "AkhadaRecords"
	recordPost.Size = Vector3.new(1, 5, 1)
	recordPost.Position = YARD_POS + Vector3.new(-9, -0.5, 0)
	recordPost.Color = Color3.fromRGB(90, 65, 40)
	recordPost.Material = Enum.Material.Wood
	recordPost.Anchored = true
	recordPost.Parent = workspace
	local recordBillboard = Instance.new("BillboardGui")
	recordBillboard.Size = UDim2.fromOffset(220, 110)
	recordBillboard.StudsOffset = Vector3.new(0, 4.6, 0)
	recordBillboard.AlwaysOnTop = true
	recordBillboard.Parent = recordPost
	local recordLabel = Instance.new("TextLabel")
	recordLabel.Size = UDim2.fromScale(1, 1)
	recordLabel.BackgroundTransparency = 1
	recordLabel.Font = Enum.Font.GothamBold
	recordLabel.TextSize = 13
	recordLabel.TextColor3 = Color3.fromRGB(255, 210, 130)
	recordLabel.TextStrokeTransparency = 0.5
	recordLabel.TextYAlignment = Enum.TextYAlignment.Top
	recordLabel.Text = "TODAY'S FIERCEST\n— the straw remembers —"
	recordLabel.Parent = recordBillboard

	local rig, humanoid, root = buildRig(Color3.fromRGB(150, 150, 155))
	if not rig or not humanoid or not root then
		return nil, nil, nil
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
	billboard.Size = UDim2.fromOffset(260, 72)
	billboard.StudsOffset = Vector3.new(0, 4.4, 0)
	billboard.AlwaysOnTop = true
	billboard.Parent = rig:FindFirstChild("Head") or root
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.GothamBold
	label.TextSize = 15
	label.TextColor3 = Color3.fromRGB(235, 230, 220)
	label.TextStrokeTransparency = 0.5
	label.TextWrapped = true
	label.Text = "AKHADA\nStrike freely — the straw keeps score."
	label.Parent = billboard

	return humanoid, label, recordLabel
end

local humanoid, label, fiercest = buildYard()
if humanoid and label then
	local hum = humanoid :: Humanoid
	local readout = label :: TextLabel
	local lastHealth = hum.Health

	hum.HealthChanged:Connect(function(health: number)
		local dealt = lastHealth - health
		lastHealth = health
		if dealt <= 0 then
			return
		end
		local attackerId = (hum.Parent :: Model):GetAttribute("LastAttacker")
		if typeof(attackerId) ~= "number" then
			return
		end
		local now = os.clock()
		lastStrikerId = attackerId
		local w = windows[attackerId] or {}
		table.insert(w, { at = now, amount = dealt })
		windows[attackerId] = w
		local live, finished = Akhada.advance(runs[attackerId], now, dealt, Akhada.Config.ComboGapSeconds)
		runs[attackerId] = live
		if finished then
			reportRun(attackerId, finished)
		end
	end)

	task.spawn(function()
		while hum.Parent do
			task.wait(0.5)
			local now = os.clock()

			-- Close strings that have gone quiet; their verdicts go home.
			for userId, run in runs do
				if Akhada.isStale(run, now, Akhada.Config.ComboGapSeconds) then
					runs[userId] = nil
					reportRun(userId, run)
				end
			end
			for userId, w in windows do
				local kept = Akhada.prune(w, now, Akhada.Config.WindowSeconds)
				if #kept == 0 then
					windows[userId] = nil
				else
					windows[userId] = kept
				end
			end

			-- Session records: every live window may set a personal best.
			for userId, uw in windows do
				local _t, udps = Akhada.readOver(uw, now, Akhada.Config.WindowSeconds)
				local who = Players:GetPlayerByUserId(userId)
				if who and udps > 0 and (not sessionBest[userId] or udps > sessionBest[userId].dps) then
					sessionBest[userId] = { name = who.DisplayName, dps = udps }
				end
			end
			if fiercest then
				local ranked = Akhada.rankBest(sessionBest, 5)
				local rows = { "TODAY'S FIERCEST" }
				for i, entry in ranked do
					table.insert(rows, string.format("%d. %s — %.0f DPS", i, entry.name, entry.dps))
				end
				if #ranked == 0 then
					table.insert(rows, "— the straw remembers —")
				end
				(fiercest :: TextLabel).Text = table.concat(rows, "\n")
			end

			local striker = if lastStrikerId ~= 0 then Players:GetPlayerByUserId(lastStrikerId) else nil
			local w = windows[lastStrikerId]
			if striker and w then
				local total, dps = Akhada.readOver(w, now, Akhada.Config.WindowSeconds)
				local run = runs[lastStrikerId]
				local stringLine = if run
					then string.format("string: %d hits · best %d", run.hits, math.floor(run.maxHit))
					else "string over"
				readout.Text = string.format(
					"AKHADA — %s\n%d dmg · %.0f DPS (last %ds)\n%s",
					striker.DisplayName,
					math.floor(total),
					dps,
					Akhada.Config.WindowSeconds,
					stringLine
				)
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

print("[Dharma] AkhadaService ready — the straw awaits your worst; the bell awaits your nerve.")

return AkhadaService
