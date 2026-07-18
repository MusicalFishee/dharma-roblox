--!strict
-- HazardService: throws each zone's hazard on ordinary waves. Bursts target
-- standing fighters' feet, telegraph through the SAME danger-zone channel the
-- boss specials use (the client already knows how to draw dread), and resolve
-- with the same escape rules: a dash slips it, a raised guard halves it.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local Debris = game:GetService("Debris")

local Net = require(ReplicatedStorage.Shared.Net)
local Hazards = require(ReplicatedStorage.Shared.Hazards)
local Zones = require(ReplicatedStorage.Shared.Zones)
local BossSpecials = require(ReplicatedStorage.Shared.BossSpecials)
local Enchants = require(ReplicatedStorage.Shared.Enchants)
local Relics = require(ReplicatedStorage.Shared.Relics)
local Vara = require(ReplicatedStorage.Shared.Vara)
local Weapons = require(ReplicatedStorage.Shared.Weapons)
local Bhava = require(ReplicatedStorage.Shared.Bhava)
local PlayerRegistry = require(script.Parent.PlayerRegistry)

local HazardService = {}

local gen = 0 -- bumps on rage/calm; strands every stale burst loop

local function broadcastAll(data: { [string]: any })
	for _, p in Players:GetPlayers() do
		Net.CombatFeedback:FireClient(p, data)
	end
end

type Fighter = { player: Player, root: BasePart }

-- The standing and the present; the fallen, the ghostly, and the still are
-- beneath the world's notice too.
local function standingFighters(): { Fighter }
	local out: { Fighter } = {}
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
		table.insert(out, { player = player, root = root })
	end
	return out
end

local function burst(def: Hazards.HazardDef, wavesDeep: number, myGen: number)
	local fighters = standingFighters()
	if #fighters == 0 then
		return
	end

	-- Up to `count` distinct marks, drawn at random fighters' feet.
	for i = #fighters, 2, -1 do
		local j = math.random(i)
		fighters[i], fighters[j] = fighters[j], fighters[i]
	end
	local centers: { { x: number, y: number, z: number } } = {}
	for i = 1, math.min(def.count, #fighters) do
		local pos = fighters[i].root.Position
		table.insert(centers, { x = pos.X, y = pos.Y - 2.5, z = pos.Z })
	end

	for _, c in centers do
		broadcastAll({
			bossSpecial = "telegraph",
			name = def.name,
			x = c.x,
			y = c.y,
			z = c.z,
			radius = def.radius,
			duration = def.telegraph,
		})
	end

	task.wait(def.telegraph)
	if gen ~= myGen then
		return -- the wave broke mid-warning; the sky forgets
	end

	local damage = Hazards.scaledDamage(def, wavesDeep)
	for _, c in centers do
		broadcastAll({ bossSpecial = "impact", x = c.x, y = c.y, z = c.z, radius = def.radius })

		local boom = Instance.new("Part")
		boom.Anchored = true
		boom.CanCollide = false
		boom.CanQuery = false
		boom.Transparency = 1
		boom.Size = Vector3.new(1, 1, 1)
		boom.Position = Vector3.new(c.x, c.y + 2, c.z)
		boom.Parent = workspace
		local boomSound = Instance.new("Sound")
		boomSound.SoundId = "rbxasset://sounds/bass.wav"
		boomSound.Volume = 0.8
		boomSound.PlaybackSpeed = 0.55
		boomSound.RollOffMaxDistance = 200
		boomSound.Parent = boom
		boomSound:Play()
		Debris:AddItem(boom, 3)

		local targets: { BossSpecials.Target } = {}
		for _, plr in Players:GetPlayers() do
			local char = plr.Character
			local hrp = char and char:FindFirstChild("HumanoidRootPart")
			if hrp and hrp:IsA("BasePart") then
				table.insert(targets, { key = plr, x = hrp.Position.X, z = hrp.Position.Z })
			end
		end
		for _, key in BossSpecials.hitTargets({ x = c.x, z = c.z }, targets, def.radius) do
			local victim = key :: Player
			local char = victim.Character
			local hum = char and char:FindFirstChildOfClass("Humanoid")
			local hrp = char and char:FindFirstChild("HumanoidRootPart")
			if not char or not hum or hum.Health <= 0 or char:GetAttribute("DharmaDowned") == true or char:GetAttribute("DharmaBhoota") == true or char:GetAttribute("DharmaDhyana") == true then
				continue
			end

			local vstate = PlayerRegistry.get(victim)
			local res = BossSpecials.resolveBlast(damage, os.clock() < vstate.dodgeUntil, vstate.isBlocking)
			if res.damage > 0 then
				local vench = Enchants.effects(vstate.enchant)
				local vward = if os.clock() < vstate.wardUntil then vstate.wardMult else 1
				local vrelic = Relics.totalBonus(Relics.equippedList(vstate.relics.equipped))
				hum:TakeDamage(res.damage * (vench.damageTakenMult or 1) * vward * vrelic.damageTakenMult * Vara.totalEffects(vstate.vara).damageTakenMult * Weapons.signatureOf(vstate.weapon.id).damageTakenMult * Bhava.effectsOf(vstate.bhava).damageTakenMult)
				Net.AnimEvent:FireAllClients(char, "flinch")
				if hrp and hrp:IsA("BasePart") then
					local away = Vector3.new(hrp.Position.X - c.x, 0, hrp.Position.Z - c.z)
					away = if away.Magnitude > 0.01 then away.Unit else Vector3.new(0, 0, 1)
					hrp.AssemblyLinearVelocity = away * 40 + Vector3.new(0, 25, 0)
				end
			end
			Net.CombatFeedback:FireClient(victim, { outcome = res.outcome, incoming = true })
		end
	end
end

-- An ordinary wave begins: the zone's hazard (if any) starts its rhythm.
function HazardService.rage(wave: number)
	gen += 1
	local myGen = gen
	local zone = Zones.forWave(wave)
	local def = Hazards.forZone(zone.id)
	if not def then
		return -- sanctuary
	end
	local wavesDeep = wave - zone.threshold
	task.spawn(function()
		while gen == myGen do
			task.wait(Hazards.rollInterval(def, math.random()))
			if gen ~= myGen then
				break
			end
			burst(def, wavesDeep, myGen)
		end
	end)
end

-- Intermission, wipe, or a spectacle night: the sky holds its breath.
function HazardService.calm()
	gen += 1
end

return HazardService
