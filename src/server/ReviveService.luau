--!strict
-- Uddhāra, server-side: lethal damage doesn't kill — it DOWNS. The fallen crawl
-- at the horde's feet while a bleed-out clock runs; any standing ally can hold
-- the lift prompt to stand them back up (or a great heal — Amrit, a blessing —
-- can do it). The clock running dry, a live duel, or the whole party being down
-- converts the fall into a true death, and every existing death/party-wipe rule
-- takes over from there untouched.
--
-- Mechanism: the Dead humanoid state is disabled on spawn, so health can touch 0
-- without the character dying; we clamp it at 1 while down and only re-enable
-- Dead (then set health 0) when the fall becomes final. Enemies ignore the downed
-- via the DharmaDowned character attribute.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local Net = require(ReplicatedStorage.Shared.Net)
local Revive = require(ReplicatedStorage.Shared.Revive)
local PlayerRegistry = require(script.Parent.PlayerRegistry)
local ProgressionService = require(script.Parent.ProgressionService)
local PvPService = require(script.Parent.PvPService)

local DOWNED_ATTR = "DharmaDowned"

local ReviveService = {}

type DownedState = {
	gen: number, -- guards stale bleed-out timers across down/lift cycles
	downedAt: number,
	character: Model,
	humanoid: Humanoid,
	prompt: ProximityPrompt,
	prevWalkSpeed: number,
	prevJumpHeight: number,
	prevJumpPower: number,
}

local downed: { [Player]: DownedState } = {}
local downGen = 0

local function broadcastAll(data: { [string]: any })
	for _, p in Players:GetPlayers() do
		Net.CombatFeedback:FireClient(p, data)
	end
end

function ReviveService.isDowned(player: Player): boolean
	return downed[player] ~= nil
end

-- A player who can still fight: alive, spawned, and not down themselves.
local function isStanding(player: Player): boolean
	if downed[player] then
		return false
	end
	local char = player.Character
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	return hum ~= nil and hum.Health > 0
end

local function anyoneStanding(): boolean
	for _, p in Players:GetPlayers() do
		if p.Character and isStanding(p) then
			return true
		end
	end
	return false
end

-- The fall becomes final: re-enable death and let every existing rule fire.
local function finalDeath(player: Player)
	local st = downed[player]
	if not st then
		return
	end
	downed[player] = nil
	st.prompt:Destroy()
	st.character:SetAttribute(DOWNED_ATTR, nil)
	pcall(function()
		st.humanoid:SetStateEnabled(Enum.HumanoidStateType.Dead, true)
	end)
	st.humanoid.Health = 0
end

-- Stand a downed player back up. `lifter` is nil for heal-lifts (Amrit, blessings).
local function lift(player: Player, lifter: Player?, healthOverride: number?)
	local st = downed[player]
	if not st then
		return
	end
	downed[player] = nil
	st.prompt:Destroy()
	st.character:SetAttribute(DOWNED_ATTR, nil)

	st.humanoid.Health = healthOverride or Revive.revivedHealth(st.humanoid.MaxHealth)
	pcall(function()
		st.humanoid.JumpHeight = st.prevJumpHeight
		st.humanoid.JumpPower = st.prevJumpPower
	end)
	-- Restores WalkSpeed (with the path passive) alongside max health.
	ProgressionService.refreshStats(player)

	if lifter then
		local lstate = PlayerRegistry.get(lifter)
		lstate.stats.revives += 1
		Net.CombatFeedback:FireClient(lifter, { liftedAlly = true, name = player.Name })
		Net.CombatFeedback:FireClient(player, { revived = true, byName = lifter.Name })
	else
		Net.CombatFeedback:FireClient(player, { revived = true })
	end
end

local function goDown(player: Player, character: Model, humanoid: Humanoid)
	-- A live duel keeps its stakes: falling there is a real death, instantly.
	if PvPService.duelOpponentOf(player) then
		pcall(function()
			humanoid:SetStateEnabled(Enum.HumanoidStateType.Dead, true)
		end)
		humanoid.Health = 0
		return
	end

	downGen += 1
	local gen = downGen
	humanoid.Health = 1

	local root = character:FindFirstChild("HumanoidRootPart")
	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = "Lift"
	prompt.ObjectText = player.Name
	prompt.HoldDuration = Revive.Config.HoldSeconds
	prompt.MaxActivationDistance = Revive.Config.Range
	prompt.RequiresLineOfSight = false
	prompt.Parent = if root then root else character

	local st: DownedState = {
		gen = gen,
		downedAt = os.clock(),
		character = character,
		humanoid = humanoid,
		prompt = prompt,
		prevWalkSpeed = humanoid.WalkSpeed,
		prevJumpHeight = humanoid.JumpHeight,
		prevJumpPower = humanoid.JumpPower,
	}
	downed[player] = st

	character:SetAttribute(DOWNED_ATTR, true)
	humanoid.WalkSpeed = Revive.Config.CrawlSpeed
	pcall(function()
		humanoid.JumpHeight = 0
		humanoid.JumpPower = 0
	end)

	Net.AnimEvent:FireAllClients(character, "flinch")
	Net.CombatFeedback:FireClient(player, { downed = true, seconds = Revive.Config.BleedOutSeconds })
	for _, p in Players:GetPlayers() do
		if p ~= player then
			Net.CombatFeedback:FireClient(p, { allyDown = true, name = player.Name })
		end
	end

	prompt.Triggered:Connect(function(lifter: Player)
		local checkResult = Revive.canLift(isStanding(lifter), downed[lifter] ~= nil, downed[player] ~= nil)
		if checkResult.ok then
			lift(player, lifter)
		end
	end)

	-- The bleed-out clock (stale timers are voided by the generation counter).
	task.delay(Revive.Config.BleedOutSeconds, function()
		local cur = downed[player]
		if cur and cur.gen == gen then
			finalDeath(player)
		end
	end)

	-- Nobody left standing = nobody left to lift anyone. End every fall at once;
	-- the ordinary party-wipe flow takes it from there.
	if not anyoneStanding() then
		for p in downed do
			finalDeath(p)
		end
	end
end

local function watchCharacter(player: Player, character: Model)
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if not humanoid then
		humanoid = character:WaitForChild("Humanoid", 10) :: Humanoid?
	end
	if not humanoid then
		return
	end
	local hum = humanoid :: Humanoid

	pcall(function()
		hum:SetStateEnabled(Enum.HumanoidStateType.Dead, false)
	end)

	hum.HealthChanged:Connect(function(health: number)
		local st = downed[player]
		if st then
			if health <= 0 then
				hum.Health = 1 -- the floor holds; only the clock (or a wipe) kills
			elseif Revive.healLifts(health) then
				lift(player, nil, health) -- Amrit / a blessing stood them up
			end
			return
		end
		if health <= 0 and hum.Parent then
			goDown(player, character, hum)
		end
	end)
end

local function onPlayer(player: Player)
	player.CharacterAdded:Connect(function(character)
		downed[player] = nil -- a fresh body owes the old one nothing
		watchCharacter(player, character)
	end)
	if player.Character then
		watchCharacter(player, player.Character)
	end
end

Players.PlayerAdded:Connect(onPlayer)
for _, p in Players:GetPlayers() do
	onPlayer(p)
end

Players.PlayerRemoving:Connect(function(player)
	local st = downed[player]
	downed[player] = nil
	if st then
		st.prompt:Destroy()
	end
end)

print("[Dharma] ReviveService ready — no one gets left in the dust.")

return ReviveService
