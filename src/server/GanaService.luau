--!strict
-- GanaService: warbands-lite. A declared banner rides above the head on a
-- small chip; matching banners march as one host. No treasury, no officers —
-- the bond IS the banner.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local DataStoreService = game:GetService("DataStoreService")

local Net = require(ReplicatedStorage.Shared.Net)
local Gana = require(ReplicatedStorage.Shared.Gana)
local Leaderboard = require(ReplicatedStorage.Shared.Leaderboard)
local Vrata = require(ReplicatedStorage.Shared.Vrata)
local PlayerRegistry = require(script.Parent.PlayerRegistry)

local GanaService = {}

-- The war tally: kills per banner this server hasn't flushed yet. Flushed
-- to the week-stamped ledger in batches — never one write per kill.
local warTally: { [string]: number } = {}

local function ganaBoard(): Leaderboard.BoardDef?
	for _, def in Leaderboard.Boards do
		if def.kind == "gana" then
			return def
		end
	end
	return nil
end

-- A kill under a banner inks the warband's weekly ledger.
function GanaService.onKill(killer: Player)
	local state = PlayerRegistry.tryGet(killer)
	if not state or #state.gana == 0 then
		return
	end
	local key = Gana.storeKey(state.gana)
	if #key == 0 then
		return
	end
	warTally[key] = (warTally[key] or 0) + 1
end

task.spawn(function()
	while true do
		task.wait(60)
		local def = ganaBoard()
		if not def or next(warTally) == nil then
			continue
		end
		local flushing = warTally
		warTally = {}
		local ok, store = pcall(function()
			return DataStoreService:GetOrderedDataStore(Leaderboard.storeNameFor(def, Vrata.weekStamp(os.time())))
		end)
		if not ok then
			-- The ledger is unreachable; the tally rides to the next flush.
			for key, n in flushing do
				warTally[key] = (warTally[key] or 0) + n
			end
			continue
		end
		for key, n in flushing do
			pcall(function()
				store:IncrementAsync(key, n)
			end)
		end
	end
end)

local function wearBanner(player: Player)
	local char = player.Character
	if not char then
		return
	end
	local head = char:FindFirstChild("Head")
	if not head or not head:IsA("BasePart") then
		return
	end
	local existing = head:FindFirstChild("GanaBanner")
	if existing then
		existing:Destroy()
	end
	local state = PlayerRegistry.get(player)
	if #state.gana == 0 then
		return
	end

	local billboard = Instance.new("BillboardGui")
	billboard.Name = "GanaBanner"
	billboard.Size = UDim2.fromOffset(120, 18)
	billboard.StudsOffset = Vector3.new(0, 2.6, 0)
	billboard.AlwaysOnTop = false
	billboard.MaxDistance = 90
	billboard.Parent = head
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.GothamBold
	label.TextSize = 12
	label.TextColor3 = Color3.fromRGB(255, 200, 40)
	label.TextStrokeTransparency = 0.5
	label.Text = "⚔ " .. state.gana
	label.Parent = billboard
end

local function snapshot(player: Player)
	local state = PlayerRegistry.get(player)
	-- The muster: who marches under the same banner right now.
	local kin: { string } = {}
	for _, other in Players:GetPlayers() do
		local ostate = PlayerRegistry.tryGet(other)
		if ostate and other ~= player and Gana.sameBanner(state.gana, ostate.gana) then
			table.insert(kin, other.DisplayName)
		end
	end
	Net.CombatFeedback:FireClient(player, {
		ganaInfo = true,
		banner = state.gana,
		kin = kin,
	})
end

Net.GanaRequest.OnServerEvent:Connect(function(player: Player, data: any)
	if typeof(data) ~= "table" then
		return
	end
	local state = PlayerRegistry.get(player)
	if not state.dataReady then
		return
	end

	if data.action == "info" then
		snapshot(player)
		return
	end

	if data.action == "set" then
		local banner = Gana.cleanName(tostring(data.name or ""))
		state.gana = banner
		wearBanner(player)
		Net.CombatFeedback:FireClient(player, if #banner > 0 then { ganaSet = true, banner = banner } else { ganaLeft = true })
		snapshot(player)
	end
end)

-- Banners re-hoist on every spawn.
local function hookPlayer(player: Player)
	player.CharacterAdded:Connect(function()
		task.wait(0.5)
		wearBanner(player)
	end)
	if player.Character then
		task.delay(1, function()
			wearBanner(player)
		end)
	end
end

Players.PlayerAdded:Connect(hookPlayer)
for _, p in Players:GetPlayers() do
	hookPlayer(p)
end

print("[Dharma] GanaService ready — banners over heads (R).")

return GanaService
