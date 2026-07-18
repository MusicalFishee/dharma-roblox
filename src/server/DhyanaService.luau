--!strict
-- The Dhyana Grove, live: a stone circle at the arena's edge. Stand still
-- inside it and the grove takes you — held in the meditation pose, rooted,
-- beneath the horde's notice. Every unbroken minute pays the monk's trickle;
-- true friends (Roblox friends, level-gated) in the circle deepen the gold.
-- Jump to rise. Combat states (downed, bhoota, duels) can never meditate.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local Net = require(ReplicatedStorage.Shared.Net)
local Dhyana = require(ReplicatedStorage.Shared.Dhyana)
local Loot = require(ReplicatedStorage.Shared.Loot)
local Progression = require(ReplicatedStorage.Shared.Progression)
local PlayerRegistry = require(script.Parent.PlayerRegistry)
local ProgressionService = require(script.Parent.ProgressionService)
local PvPService = require(script.Parent.PvPService)

local GROVE_HEART = Vector3.new(-34, 2, -34)

local DhyanaService = {}

type Sitter = {
	ticks: number,
	secondsInTick: number,
	conns: { RBXScriptConnection },
}

local sitters: { [Player]: Sitter } = {}
local stillness: { [Player]: { at: Vector3, seconds: number } } = {}
-- Friendship cache per pair (IsFriendsWith can be slow; friendships don't
-- change mid-meditation in any way we need to honor live).
local friendCache: { [Player]: { [number]: boolean } } = {}

-- ---------------------------------------------------------------------------
-- The grove itself.
-- ---------------------------------------------------------------------------
local function buildGrove()
	local disc = Instance.new("Part")
	disc.Name = "DhyanaGrove"
	disc.Shape = Enum.PartType.Cylinder
	disc.Size = Vector3.new(0.6, Dhyana.Config.GroveRadius * 2, Dhyana.Config.GroveRadius * 2)
	disc.CFrame = CFrame.new(GROVE_HEART - Vector3.new(0, 1.6, 0)) * CFrame.Angles(0, 0, math.rad(90))
	disc.Color = Color3.fromRGB(120, 110, 130)
	disc.Material = Enum.Material.Slate
	disc.Anchored = true
	disc.Parent = workspace

	local stone = Instance.new("Part")
	stone.Name = "DhyanaStone"
	stone.Size = Vector3.new(1.6, 2.6, 1.6)
	stone.Position = GROVE_HEART + Vector3.new(0, 0.2, 0)
	stone.Color = Color3.fromRGB(150, 145, 160)
	stone.Material = Enum.Material.Granite
	stone.Anchored = true
	stone.Parent = workspace

	local glow = Instance.new("PointLight")
	glow.Color = Color3.fromRGB(200, 220, 255)
	glow.Range = Dhyana.Config.GroveRadius + 4
	glow.Brightness = 1.2
	glow.Parent = stone

	local billboard = Instance.new("BillboardGui")
	billboard.Size = UDim2.fromOffset(260, 70)
	billboard.StudsOffset = Vector3.new(0, 3.2, 0)
	billboard.AlwaysOnTop = true
	billboard.Parent = stone
	local sign = Instance.new("TextLabel")
	sign.Size = UDim2.fromScale(1, 1)
	sign.BackgroundTransparency = 1
	sign.Font = Enum.Font.Garamond
	sign.TextSize = 20
	sign.TextColor3 = Color3.fromRGB(220, 230, 250)
	sign.TextStrokeTransparency = 0.5
	sign.TextWrapped = true
	sign.Text = "DHYANA GROVE\nBe still, and the grove holds you. Jump to rise.\nSangha: friends of level 15+ deepen the gold."
	sign.Parent = billboard
end

-- ---------------------------------------------------------------------------
-- Entering, holding, leaving.
-- ---------------------------------------------------------------------------
local function isFriend(a: Player, b: Player): boolean
	local cache = friendCache[a]
	if not cache then
		cache = {}
		friendCache[a] = cache
	end
	local known = cache[b.UserId]
	if known ~= nil then
		return known
	end
	local ok, result = pcall(function()
		return a:IsFriendsWithAsync(b.UserId)
	end)
	local friends = ok and result == true
	cache[b.UserId] = friends
	return friends
end

local function levelOf(player: Player): number
	return Progression.resolve(PlayerRegistry.get(player).totalXp).level
end

local function exitDhyana(player: Player, silent: boolean?)
	local sitter = sitters[player]
	if not sitter then
		return
	end
	sitters[player] = nil
	for _, conn in sitter.conns do
		conn:Disconnect()
	end
	local char = player.Character
	if char then
		char:SetAttribute("DharmaDhyana", nil)
		-- Stop the held pose (the block-stop alias ends any held track).
		Net.AnimEvent:FireAllClients(char, "blockend")
	end
	ProgressionService.refreshStats(player) -- WalkSpeed returns with the flesh
	if not silent then
		Net.CombatFeedback:FireClient(player, { dhyanaExit = true, minutes = sitter.ticks })
	end
end

local function enterDhyana(player: Player, char: Model, hum: Humanoid)
	local sitter: Sitter = { ticks = 0, secondsInTick = 0, conns = {} }
	sitters[player] = sitter
	char:SetAttribute("DharmaDhyana", true)
	hum.WalkSpeed = 0
	Net.AnimEvent:FireAllClients(char, "emote_meditate")
	Net.CombatFeedback:FireClient(player, { dhyanaEnter = true })

	table.insert(sitter.conns, hum.Jumping:Connect(function()
		exitDhyana(player)
	end))
	table.insert(sitter.conns, hum.Died:Connect(function()
		exitDhyana(player, true)
	end))
end

local function eligible(player: Player): (Model?, Humanoid?)
	local state = PlayerRegistry.tryGet(player)
	if not state or not state.dataLoaded then
		return nil, nil
	end
	local char = player.Character
	if not char or char:GetAttribute("DharmaDowned") == true or char:GetAttribute("DharmaBhoota") == true then
		return nil, nil
	end
	if PvPService.duelOpponentOf(player) then
		return nil, nil -- a duelist's mind is not still
	end
	local hum = char:FindFirstChildOfClass("Humanoid")
	local root = char:FindFirstChild("HumanoidRootPart")
	if not hum or hum.Health <= 0 or not root or not root:IsA("BasePart") then
		return nil, nil
	end
	local flat = root.Position - GROVE_HEART
	if Vector3.new(flat.X, 0, flat.Z).Magnitude > Dhyana.Config.GroveRadius then
		return nil, nil
	end
	return char, hum
end

-- How many co-meditators strengthen THIS player's sangha: real friends only,
-- and only those past the level gate (the alt-killer, checked server-side).
local function sanghaFor(player: Player): number
	local qualifying = 0
	for other in sitters do
		if other ~= player and other.Parent and Dhyana.qualifies(levelOf(other)) and isFriend(player, other) then
			qualifying += 1
		end
	end
	return qualifying
end

task.spawn(function()
	while true do
		task.wait(1)
		for _, player in Players:GetPlayers() do
			local char, hum = eligible(player)
			local sitter = sitters[player]

			if sitter then
				if not char or not hum then
					exitDhyana(player) -- knocked out of the circle, downed, or gone
					continue
				end
				sitter.secondsInTick += 1
				if sitter.secondsInTick >= Dhyana.Config.TickSeconds then
					sitter.secondsInTick = 0
					sitter.ticks += 1
					local friends = sanghaFor(player)
					local reward = Dhyana.rewardForTick(sitter.ticks, Dhyana.multiplierFor(friends))
					local state = PlayerRegistry.get(player)
					state.gold = Loot.clampGold(state.gold + reward.gold)
					Net.CombatFeedback:FireClient(player, { goldUpdate = true, gained = reward.gold, gold = state.gold })
					if reward.shards > 0 then
						state.shards += reward.shards
						Net.CombatFeedback:FireClient(player, { shardUpdate = true, gained = reward.shards, shards = state.shards })
					end
					if sitter.ticks % 5 == 0 or reward.shards > 0 then
						Net.CombatFeedback:FireClient(player, {
							dhyanaTick = true,
							minutes = sitter.ticks,
							gold = reward.gold,
							friends = friends,
							shards = reward.shards,
						})
					end
				end
			elseif char and hum then
				-- Not yet held: count stillness inside the circle.
				local root = char:FindFirstChild("HumanoidRootPart") :: BasePart
				local still = stillness[player]
				if still and (root.Position - still.at).Magnitude < 1 then
					still.seconds += 1
					if still.seconds >= Dhyana.Config.EnterStillSeconds then
						stillness[player] = nil
						enterDhyana(player, char, hum)
					end
				else
					stillness[player] = { at = root.Position, seconds = 0 }
				end
			else
				stillness[player] = nil
			end
		end
	end
end)

Players.PlayerRemoving:Connect(function(player)
	exitDhyana(player, true)
	stillness[player] = nil
	friendCache[player] = nil
end)

buildGrove()

print("[Dharma] DhyanaService ready — the grove waits for the still.")

return DhyanaService
