--!strict
-- Astra Paths, server-side: the oath (first pick, free) and the respec (gold).
-- Gating lives in the pure Paths module; this applies the outcome — sets the
-- path, charges gold, and re-applies stats (health bonus + stride) in place.
-- The first-time prompt waits for the weapon oath so the pickers never stack.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local Net = require(ReplicatedStorage.Shared.Net)
local Paths = require(ReplicatedStorage.Shared.Paths)
local PlayerRegistry = require(script.Parent.PlayerRegistry)
local ProgressionService = require(script.Parent.ProgressionService)

local PathService = {}

local prompted: { [Player]: boolean } = {}

Players.PlayerRemoving:Connect(function(player)
	prompted[player] = nil
end)

local function snapshot(player: Player)
	local state = PlayerRegistry.get(player)
	Net.CombatFeedback:FireClient(player, {
		pathInfo = true,
		path = state.path,
		gold = state.gold,
		respecCost = Paths.RespecCost,
	})
end

-- Once per session: after data lands AND a weapon is wielded, invite the unsworn.
local function maybePrompt(player: Player)
	if prompted[player] then
		return
	end
	prompted[player] = true
	task.spawn(function()
		local state = PlayerRegistry.get(player)
		local waited = 0
		while not state.dataReady and waited < 30 and player.Parent do
			task.wait(0.5)
			waited += 0.5
		end
		if state.path ~= "" then
			return
		end
		-- The weapon picker owns the screen first.
		waited = 0
		while state.weapon.id == "" and waited < 600 and player.Parent do
			task.wait(1)
			waited += 1
		end
		if state.path == "" and player.Parent then
			task.wait(2.5) -- let the weapon toast breathe
			Net.CombatFeedback:FireClient(player, { pathPrompt = true })
		end
	end)
end

Net.PathRequest.OnServerEvent:Connect(function(player: Player, data: any)
	if typeof(data) ~= "table" then
		return
	end
	local state = PlayerRegistry.get(player)

	if data.action == "info" then
		snapshot(player)
		return
	end

	if data.action == "choose" then
		if not state.dataReady then
			return -- never let an oath race the save load
		end
		local id = tostring(data.id)
		local wasSworn = state.path ~= ""
		local checkResult = Paths.tryChoose(state.path, id, state.gold)
		if not checkResult.ok then
			Net.CombatFeedback:FireClient(player, { pathDenied = true, reason = checkResult.reason })
			snapshot(player)
			return
		end

		local goldChanged = checkResult.goldAfter ~= state.gold
		state.gold = checkResult.goldAfter
		state.path = id
		-- New passive applies in place: max health / stride refresh, no free heal.
		ProgressionService.refreshStats(player)

		if goldChanged then
			Net.CombatFeedback:FireClient(player, { goldUpdate = true, gained = 0, gold = state.gold })
		end
		local def = Paths.Defs[id]
		Net.CombatFeedback:FireClient(player, {
			pathChosen = true,
			path = id,
			name = def.name,
			epithet = def.epithet,
			color = def.color,
			respec = wasSworn,
		})
		snapshot(player)
	end
end)

Players.PlayerAdded:Connect(maybePrompt)
for _, p in Players:GetPlayers() do
	maybePrompt(p)
end

print("[Dharma] PathService ready — the four Paths lie open.")

return PathService
