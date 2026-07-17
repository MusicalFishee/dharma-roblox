--!strict
-- Sacred marks + emotes, live. Tilaks are welded to the brow, auras ride the
-- torso; both rebuild on every spawn and equip. Emotes broadcast the shared
-- procedural tracks (rate-limited — devotion, not spam). Cosmetic only, by law.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local Net = require(ReplicatedStorage.Shared.Net)
local Vibhuti = require(ReplicatedStorage.Shared.Vibhuti)
local PlayerRegistry = require(script.Parent.PlayerRegistry)

local EMOTE_COOLDOWN = 2.5

local VibhutiService = {}

local lastEmoteAt: { [Player]: number } = {}

local function snapOf(state: any): Vibhuti.UnlockSnapshot
	return {
		kills = state.stats.kills,
		bossKills = state.stats.bossKills,
		bestWave = state.bestWave,
		trials = state.stats.trialsPassed,
		duelWins = state.stats.duelWins,
		raidClears = state.stats.raidClears,
		revives = state.stats.revives,
	}
end

local function rgb(c: { number }): Color3
	return Color3.fromRGB(c[1], c[2], c[3])
end

-- (Re)apply the worn marks to the character. Idempotent.
local function applyMarks(player: Player)
	local char = player.Character
	if not char then
		return
	end
	local state = PlayerRegistry.get(player)

	for _, name in { "VibhutiMark", "VibhutiAura" } do
		local old = char:FindFirstChild(name, true)
		while old do
			old:Destroy()
			old = char:FindFirstChild(name, true)
		end
	end

	local head = char:FindFirstChild("Head")
	local tilakDef = Vibhuti.get(state.vibhuti.tilak)
	if tilakDef and head and head:IsA("BasePart") then
		local function brow(size: Vector3, yOffset: number)
			local markPart = Instance.new("Part")
			markPart.Name = "VibhutiMark"
			markPart.Size = size
			markPart.Color = rgb(tilakDef.color)
			markPart.Material = Enum.Material.Neon
			markPart.CanCollide = false
			markPart.CanQuery = false
			markPart.Massless = true
			markPart.CFrame = head.CFrame * CFrame.new(0, 0.18 + yOffset, -head.Size.Z / 2 - 0.03)
			local weld = Instance.new("WeldConstraint")
			weld.Part0 = markPart
			weld.Part1 = head
			weld.Parent = markPart
			markPart.Parent = char
		end
		if tilakDef.style == "lines" then
			brow(Vector3.new(0.42, 0.05, 0.05), 0.12)
			brow(Vector3.new(0.42, 0.05, 0.05), 0)
			brow(Vector3.new(0.42, 0.05, 0.05), -0.12)
		else
			brow(Vector3.new(0.14, 0.18, 0.05), 0)
		end
	end

	local torso = char:FindFirstChild("UpperTorso") or char:FindFirstChild("Torso")
	local auraDef = Vibhuti.get(state.vibhuti.aura)
	if auraDef and torso and torso:IsA("BasePart") then
		local holder = Instance.new("Attachment")
		holder.Name = "VibhutiAura"
		holder.Parent = torso
		if auraDef.style == "fire" then
			local fire = Instance.new("Fire")
			fire.Name = "VibhutiAura"
			fire.Size = 3
			fire.Heat = 4
			fire.Color = rgb(auraDef.color)
			fire.Parent = torso
		elseif auraDef.style == "sparkles" then
			local sparkles = Instance.new("Sparkles")
			sparkles.Name = "VibhutiAura"
			sparkles.SparkleColor = rgb(auraDef.color)
			sparkles.Parent = torso
		else
			local light = Instance.new("PointLight")
			light.Name = "VibhutiAura"
			light.Color = rgb(auraDef.color)
			light.Range = 10
			light.Brightness = 1.6
			light.Parent = torso
		end
	end
end

local function sendInfo(player: Player)
	local state = PlayerRegistry.get(player)
	Net.CombatFeedback:FireClient(player, {
		vibhutiInfo = true,
		tilak = state.vibhuti.tilak,
		aura = state.vibhuti.aura,
	})
end

Net.VibhutiRequest.OnServerEvent:Connect(function(player: Player, data: any)
	if typeof(data) ~= "table" then
		return
	end
	local state = PlayerRegistry.get(player)

	if data.action == "info" then
		sendInfo(player)
		return
	end

	if data.action == "equip" then
		local slot = tostring(data.slot)
		local id = tostring(data.id)
		local checkResult = Vibhuti.tryEquip(slot, id, snapOf(state))
		if checkResult.ok then
			(state.vibhuti :: any)[slot] = id
			applyMarks(player)
		end
		sendInfo(player)
		return
	end

	if data.action == "emote" then
		local id = tostring(data.id)
		if not Vibhuti.isEmote(id) then
			return
		end
		local char = player.Character
		if not char or char:GetAttribute("DharmaDowned") == true then
			return -- the crawling do not dance (bhootas may — spirits are free)
		end
		local now = os.clock()
		if now - (lastEmoteAt[player] or -math.huge) < EMOTE_COOLDOWN then
			return
		end
		lastEmoteAt[player] = now
		Net.AnimEvent:FireAllClients(char, id)
		return
	end
end)

local function onPlayer(player: Player)
	player.CharacterAdded:Connect(function()
		task.wait(0.5) -- let the rig assemble (and the weapon weld first)
		applyMarks(player)
	end)
end

Players.PlayerAdded:Connect(onPlayer)
for _, p in Players:GetPlayers() do
	onPlayer(p)
end

Players.PlayerRemoving:Connect(function(player)
	lastEmoteAt[player] = nil
end)

print("[Dharma] VibhutiService ready — wear your deeds on your brow.")

return VibhutiService
