--!strict
-- Weapon visuals + authority (server module). Builds the held weapon from primitives
-- (no imported assets — same code-built approach as the arena), welds it into the
-- player's right hand, and rebuilds it whenever the tier changes so every upgrade
-- visibly transforms the weapon. Also owns the one-time weapon choice.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local Net = require(ReplicatedStorage.Shared.Net)
local Weapons = require(ReplicatedStorage.Shared.Weapons)
local Enchants = require(ReplicatedStorage.Shared.Enchants)
local PlayerRegistry = require(script.Parent.PlayerRegistry)

local WeaponService = {}

local WEAPON_NAME = "DharmaWeapon"
local HANDLE_COLOR = Color3.fromRGB(58, 42, 30) -- dark wrapped grip, constant across tiers
-- Where the grip sits relative to the right hand (blade points up out of the fist).
local HAND_C0 = CFrame.new(0, -0.55, -0.15)

-- The grip part, across rig types (R15 hand or R6 arm).
local function rightHandOf(char: Model): BasePart?
	local hand = char:FindFirstChild("RightHand") or char:FindFirstChild("Right Arm")
	if hand and hand:IsA("BasePart") then
		return hand
	end
	return nil
end

local function materialEnum(name: string): Enum.Material
	local ok, mat = pcall(function()
		return (Enum.Material :: any)[name]
	end)
	if ok and typeof(mat) == "EnumItem" then
		return mat :: any
	end
	return Enum.Material.Metal
end

local function rgb(c: { number }): Color3
	return Color3.fromRGB(c[1], c[2], c[3])
end

local function mkPart(name: string, size: Vector3, cf: CFrame, color: Color3, material: Enum.Material): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Size = size
	p.CFrame = cf
	p.Color = color
	p.Material = material
	p.Anchored = false
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.Massless = true
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	return p
end

-- Weld a decorative part rigidly to the grip. Grip is at the origin during the build,
-- so the part's build CFrame IS its offset from the grip.
local function weldToGrip(grip: BasePart, part: BasePart)
	local weld = Instance.new("Weld")
	weld.Part0 = grip
	weld.Part1 = part
	weld.C0 = grip.CFrame:Inverse() * part.CFrame
	weld.Parent = grip
end

local function addGlow(part: BasePart, glow: number, color: Color3)
	if glow <= 0 then
		return
	end
	local light = Instance.new("PointLight")
	light.Brightness = glow * 3
	light.Range = 8 + glow * 6
	light.Color = color
	light.Parent = part
end

-- Build the weapon model in local space with the grip at the origin. Returns the model
-- (PrimaryPart = grip) or nil for an unknown weapon.
local function buildWeapon(id: string, tier: number): Model?
	local v = Weapons.visual(id, tier)
	if not v then
		return nil
	end
	local mat = materialEnum(v.material)
	local isNeon = v.material == "Neon"
	-- Neon blades glow in their accent colour; otherwise they wear the blade colour.
	local bladeColor = if isNeon then rgb(v.glowColor) else rgb(v.bladeColor)
	local glowColor = rgb(v.glowColor)
	local s = v.scale

	local model = Instance.new("Model")
	model.Name = WEAPON_NAME

	local grip = mkPart("Grip", Vector3.new(0.32, 1.2, 0.32), CFrame.new(), HANDLE_COLOR, Enum.Material.Wood)
	grip.Parent = model
	model.PrimaryPart = grip

	local function decor(name: string, size: Vector3, cf: CFrame, color: Color3, material: Enum.Material): Part
		local p = mkPart(name, size, cf, color, material)
		weldToGrip(grip, p)
		p.Parent = model
		return p
	end

	if v.shape == "blade" then
		decor("Guard", Vector3.new(1.1 * s, 0.22, 0.36), CFrame.new(0, 0.7, 0), bladeColor, mat)
		local blade = decor("Blade", Vector3.new(0.28 * s, 3.2 * s, 0.14), CFrame.new(0, 2.35 * s + 0.6, 0), bladeColor, mat)
		addGlow(blade, v.glow, glowColor)
	elseif v.shape == "trident" then
		decor("Shaft", Vector3.new(0.26, 3.2 * s, 0.26), CFrame.new(0, 1.4 * s, 0), HANDLE_COLOR, Enum.Material.Wood)
		decor("Cross", Vector3.new(1.0 * s, 0.16, 0.14), CFrame.new(0, 2.7 * s, 0), bladeColor, mat)
		local mid = decor("Prong", Vector3.new(0.18 * s, 1.2 * s, 0.14), CFrame.new(0, 3.4 * s, 0), bladeColor, mat)
		decor("ProngL", Vector3.new(0.16 * s, 1.0 * s, 0.14), CFrame.new(-0.42 * s, 3.3 * s, 0), bladeColor, mat)
		decor("ProngR", Vector3.new(0.16 * s, 1.0 * s, 0.14), CFrame.new(0.42 * s, 3.3 * s, 0), bladeColor, mat)
		addGlow(mid, v.glow, glowColor)
	elseif v.shape == "mace" then
		decor("Shaft", Vector3.new(0.34, 2.6 * s, 0.34), CFrame.new(0, 1.1 * s, 0), HANDLE_COLOR, Enum.Material.Wood)
		local head = decor("Head", Vector3.new(1.15 * s, 1.15 * s, 1.15 * s), CFrame.new(0, 2.5 * s, 0), bladeColor, mat)
		head.Shape = Enum.PartType.Ball
		addGlow(head, v.glow, glowColor)
	elseif v.shape == "discus" then
		decor("Grommet", Vector3.new(0.3, 0.5, 0.3), CFrame.new(0, 0.5, 0), HANDLE_COLOR, Enum.Material.Metal)
		local disc = decor("Disc", Vector3.new(0.16, 2.5 * s, 2.5 * s), CFrame.new(0, 1.7 * s, 0), bladeColor, mat)
		disc.Shape = Enum.PartType.Cylinder
		addGlow(disc, v.glow, glowColor)
	elseif v.shape == "axe" then
		decor("Shaft", Vector3.new(0.3, 3.0 * s, 0.3), CFrame.new(0, 1.3 * s, 0), HANDLE_COLOR, Enum.Material.Wood)
		local head = decor("Head", Vector3.new(1.4 * s, 1.0 * s, 0.2), CFrame.new(0.55 * s, 2.6 * s, 0), bladeColor, mat)
		decor("Beard", Vector3.new(0.5 * s, 0.5 * s, 0.18), CFrame.new(0.95 * s, 2.1 * s, 0), bladeColor, mat)
		addGlow(head, v.glow, glowColor)
	elseif v.shape == "staff" then
		local shaft = decor("Shaft", Vector3.new(0.28, 4.4 * s, 0.28), CFrame.new(0, 1.6 * s, 0), bladeColor, mat)
		decor("CapTop", Vector3.new(0.45 * s, 0.45 * s, 0.45 * s), CFrame.new(0, 3.85 * s, 0), bladeColor, mat)
		decor("CapLow", Vector3.new(0.4 * s, 0.4 * s, 0.4 * s), CFrame.new(0, -0.6, 0), bladeColor, mat)
		addGlow(shaft, v.glow, glowColor)
	end

	return model
end

-- (Re)build and attach the player's weapon from their current state. Idempotent:
-- destroys any existing weapon first. Prompts a weaponless player to choose only when
-- allowPrompt (i.e. their save has resolved), never mid-load.
function WeaponService.refresh(player: Player, allowPrompt: boolean?)
	local char = player.Character
	if not char then
		return
	end
	local existing = char:FindFirstChild(WEAPON_NAME)
	if existing then
		existing:Destroy()
	end

	local state = PlayerRegistry.get(player)
	if not Weapons.isValidId(state.weapon.id) then
		-- Unarmed (or a corrupt id): offer the choice once the save has resolved.
		if allowPrompt then
			Net.CombatFeedback:FireClient(player, { weaponPrompt = true })
		end
		return
	end

	local hand = rightHandOf(char)
	if not hand then
		return
	end

	local model = buildWeapon(state.weapon.id, state.weapon.tier)
	if not model then
		return
	end
	local grip = model.PrimaryPart :: BasePart
	local weld = Instance.new("Weld")
	weld.Part0 = hand
	weld.Part1 = grip
	weld.C0 = HAND_C0
	weld.Parent = grip
	model.Parent = char

	-- A mythic mantra wraps the weapon in its own aura — the sub-1% flex.
	local eff = Enchants.effects(state.enchant)
	if eff.aura then
		local focus: BasePart? = nil
		for _, partName in { "Blade", "Prong", "Head", "Disc" } do
			local part = model:FindFirstChild(partName)
			if part and part:IsA("BasePart") then
				focus = part
				break
			end
		end
		local color = if eff.auraColor
			then Color3.fromRGB(eff.auraColor[1], eff.auraColor[2], eff.auraColor[3])
			else Color3.fromRGB(255, 255, 255)
		if focus then
			if eff.aura == "fire" then
				local flame = Instance.new("Fire")
				flame.Size = 5
				flame.Heat = 9
				flame.Color = color
				flame.SecondaryColor = Color3.fromRGB(120, 30, 10)
				flame.Parent = focus
			elseif eff.aura == "sparkles" then
				local sparkles = Instance.new("Sparkles")
				sparkles.SparkleColor = color
				sparkles.Parent = focus
			end
			local light = Instance.new("PointLight")
			light.Brightness = 4
			light.Range = 14
			light.Color = color
			light.Parent = focus
		end
	end

	Net.CombatFeedback:FireClient(player, {
		weaponEquipped = true,
		id = state.weapon.id,
		tier = state.weapon.tier,
		name = Weapons.tierName(state.weapon.id, state.weapon.tier),
	})
end

-- Choose or SWITCH a weapon. The first oath is a starter's choice; earned
-- weapons can be wielded any time after (the smith's tier travels with you —
-- the craft is yours, not the blade's). The server re-checks every unlock.
Net.WeaponRequest.OnServerEvent:Connect(function(player: Player, data: any)
	if typeof(data) ~= "table" or data.action ~= "select" then
		return
	end
	local state = PlayerRegistry.get(player)
	if not state.dataReady then
		return -- never race the save
	end
	local id = tostring(data.id)
	local weapon = Weapons.get(id)
	if not weapon or id == state.weapon.id then
		return
	end
	local snap: Weapons.UnlockSnapshot = {
		kills = state.stats.kills,
		bossKills = state.stats.bossKills,
		trials = state.stats.trialsPassed,
		revives = state.stats.revives,
		raidClears = state.stats.raidClears,
	}
	if not Weapons.isUnlocked(id, snap) then
		Net.CombatFeedback:FireClient(player, { weaponLocked = true, name = weapon.displayName, label = if weapon.unlock then weapon.unlock.label else "" })
		return
	end
	local hadWeapon = Weapons.isValidId(state.weapon.id)
	state.weapon = { id = id, tier = if hadWeapon then state.weapon.tier else Weapons.MinTier }
	WeaponService.refresh(player, false)
	Net.CombatFeedback:FireClient(player, {
		weaponChosen = true,
		id = id,
		name = weapon.displayName,
		title = weapon.title,
	})
end)

-- Re-attach on every spawn, but wait for the save to resolve so we prompt exactly once
-- (and never ask a returning player to re-choose).
local function onCharacter(player: Player, char: Model)
	task.spawn(function()
		char:WaitForChild("HumanoidRootPart", 10) -- present on both R15 and R6
		task.wait(0.3) -- let the limbs stream in
		local state = PlayerRegistry.get(player)
		local t0 = os.clock()
		while not state.dataReady and os.clock() - t0 < 8 do
			task.wait(0.1)
		end
		WeaponService.refresh(player, true)
	end)
end

local function hookPlayer(player: Player)
	player.CharacterAdded:Connect(function(char)
		onCharacter(player, char)
	end)
	if player.Character then
		onCharacter(player, player.Character)
	end
end

Players.PlayerAdded:Connect(hookPlayer)
for _, p in Players:GetPlayers() do
	hookPlayer(p)
end

print("[Dharma] WeaponService ready — armory online.")

return WeaponService
