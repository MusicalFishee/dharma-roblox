--!strict
-- The bhoota state, live: ReviveService marks the fallen, and when their fresh
-- body spawns while the battle still rages, this service unmakes it — fading
-- every part, hanging a pale light on them, and holding them out of the war
-- (no swings, no casts, no gold, no lifts; the horde's targeting skips the
-- DharmaBhoota attribute). WaveService flips the battle flag at wave start /
-- clear / wipe, and releaseAll() performs the Punarjanma: flesh, full health,
-- full stats, back in the fight.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local Net = require(ReplicatedStorage.Shared.Net)
local Bhoota = require(ReplicatedStorage.Shared.Bhoota)
local ProgressionService = require(script.Parent.ProgressionService)
local GhatService = require(script.Parent.GhatService)

local BHOOTA_ATTR = "DharmaBhoota"

local BhootaService = {}

type GhostState = {
	character: Model,
	light: PointLight?,
	-- Original per-part transparencies, restored at Punarjanma.
	savedTransparency: { [BasePart]: number },
}

local battleActive = false
local fallenInBattle: { [Player]: boolean } = {}
local ghosts: { [Player]: GhostState } = {}

function BhootaService.isGhost(player: Player): boolean
	return ghosts[player] ~= nil
end

-- Will this player's NEXT spawn be a wander? (WaveService reads this before
-- our own CharacterAdded handler has run, so it must not depend on ghost state.)
function BhootaService.shouldGhost(player: Player): boolean
	return Bhoota.shouldGhost(battleActive, fallenInBattle[player] == true)
end

-- ReviveService calls this on every true death (bleed-out, duel, all-down).
function BhootaService.markFallen(player: Player)
	fallenInBattle[player] = true
	-- A ghat flame is set where the warrior fell; the session remembers.
	local char = player.Character
	local root = char and char:FindFirstChild("HumanoidRootPart")
	if root and root:IsA("BasePart") then
		GhatService.onFallen(player.DisplayName, root.Position)
	end
end

local function makeGhost(player: Player, character: Model)
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if not humanoid then
		return
	end

	local st: GhostState = {
		character = character,
		light = nil,
		savedTransparency = {},
	}
	ghosts[player] = st
	character:SetAttribute(BHOOTA_ATTR, true)

	for _, part in character:GetDescendants() do
		if part:IsA("BasePart") then
			st.savedTransparency[part] = part.Transparency
			if part.Transparency < Bhoota.Config.Transparency then
				part.Transparency = Bhoota.Config.Transparency
			end
		end
	end

	local root = character:FindFirstChild("HumanoidRootPart")
	if root and root:IsA("BasePart") then
		local light = Instance.new("PointLight")
		light.Color = Color3.fromRGB(Bhoota.Config.LightColor[1], Bhoota.Config.LightColor[2], Bhoota.Config.LightColor[3])
		light.Range = Bhoota.Config.LightRange
		light.Brightness = 2
		light.Parent = root
		st.light = light
	end

	humanoid.WalkSpeed = Bhoota.Config.WalkSpeed
	humanoid.DisplayName = player.DisplayName .. " (bhoota)"

	Net.CombatFeedback:FireClient(player, { bhoota = true })
end

-- Punarjanma: restore every wandering spirit to flesh. Returns who was restored
-- (WaveService marks them alive again for the next wave's wipe accounting).
function BhootaService.releaseAll(): { Player }
	local released: { Player } = {}
	for player, st in ghosts do
		ghosts[player] = nil
		fallenInBattle[player] = nil
		table.insert(released, player)

		local character = st.character
		if character.Parent then
			character:SetAttribute(BHOOTA_ATTR, nil)
			for part, transparency in st.savedTransparency do
				if part.Parent then
					part.Transparency = transparency
				end
			end
			if st.light then
				st.light:Destroy()
			end
			local humanoid = character:FindFirstChildOfClass("Humanoid")
			if humanoid then
				humanoid.DisplayName = player.DisplayName
			end
			-- Full stats, full heal, HUD sync — the wheel turns.
			ProgressionService.onCharacterSpawn(player)
		end
		Net.CombatFeedback:FireClient(player, { punarjanma = true })
	end
	return released
end

-- WaveService flips this: true at wave start, false on clear/wipe.
function BhootaService.setBattleActive(active: boolean)
	battleActive = active
	if not active then
		-- Deaths from the ended battle are spent; fresh spawns come back clean.
		for player in fallenInBattle do
			if not ghosts[player] then
				fallenInBattle[player] = nil
			end
		end
	end
end

local function onPlayer(player: Player)
	player.CharacterAdded:Connect(function(character)
		ghosts[player] = nil -- the old ghost's body is gone with the old character
		if BhootaService.shouldGhost(player) then
			fallenInBattle[player] = nil
			task.wait(0.1) -- let the rig finish assembling before fading it
			if character.Parent and battleActive then
				makeGhost(player, character)
			end
		else
			fallenInBattle[player] = nil
		end
	end)
end

Players.PlayerAdded:Connect(onPlayer)
for _, p in Players:GetPlayers() do
	onPlayer(p)
end

Players.PlayerRemoving:Connect(function(player)
	ghosts[player] = nil
	fallenInBattle[player] = nil
end)

print("[Dharma] BhootaService ready — the fallen walk unseen.")

return BhootaService
