--!strict
-- Bhoota spectate-cam: a wandering spirit may ride the eyes of the living.
-- While your character carries DharmaBhoota, ← / → cycle the camera through
-- the standing fighters; the chip names who you're watching. The camera
-- comes home the moment flesh does.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")

local Spectate = require(ReplicatedStorage.Shared.Spectate)

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local camera = workspace.CurrentCamera

local screenGui = Instance.new("ScreenGui")
screenGui.Name = "DharmaSpectate"
screenGui.ResetOnSpawn = false
screenGui.DisplayOrder = 18
screenGui.Enabled = false
screenGui.Parent = playerGui

local chip = Instance.new("TextLabel")
chip.AnchorPoint = Vector2.new(0.5, 1)
chip.Position = UDim2.new(0.5, 0, 1, -120)
chip.Size = UDim2.fromOffset(340, 30)
chip.BackgroundColor3 = Color3.fromRGB(18, 15, 22)
chip.BackgroundTransparency = 0.25
chip.Font = Enum.Font.GothamBold
chip.TextSize = 14
chip.TextColor3 = Color3.fromRGB(190, 205, 255)
chip.Text = ""
chip.Parent = screenGui
local cc = Instance.new("UICorner")
cc.CornerRadius = UDim.new(0, 8)
cc.Parent = chip

local watching = false
local index = 1

local function watchables(): { Player }
	local out: { Player } = {}
	for _, p in Players:GetPlayers() do
		if p == player then
			continue
		end
		local char = p.Character
		local hum = char and char:FindFirstChildOfClass("Humanoid")
		if not char or not hum then
			continue
		end
		local ok = Spectate.isWatchable(
			hum.Health > 0,
			char:GetAttribute("DharmaBhoota") == true,
			char:GetAttribute("DharmaDowned") == true,
			char:GetAttribute("DharmaDhyana") == true
		)
		if ok then
			table.insert(out, p)
		end
	end
	return out
end

local function comeHome()
	local char = player.Character
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	if hum then
		camera.CameraSubject = hum
	end
	screenGui.Enabled = false
end

local function look()
	local list = watchables()
	index = Spectate.clampIndex(#list, index)
	if index == 0 then
		chip.Text = "BHOOTA — no fighters stand to watch"
		return
	end
	local target = list[index]
	local char = target.Character
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	if hum then
		camera.CameraSubject = hum
		chip.Text = string.format("BHOOTA — watching %s   (← / → to wander)", target.DisplayName)
	end
end

local function step(dir: number)
	if not watching then
		return
	end
	local list = watchables()
	index = Spectate.cycle(#list, Spectate.clampIndex(#list, index), dir)
	look()
end

local function onCharacter(char: Model)
	char:GetAttributeChangedSignal("DharmaBhoota"):Connect(function()
		local ghost = char:GetAttribute("DharmaBhoota") == true
		if ghost and not watching then
			watching = true
			index = 1
			screenGui.Enabled = true
			look()
		elseif not ghost and watching then
			watching = false
			comeHome()
		end
	end)
end

player.CharacterAdded:Connect(function(char)
	if watching then
		watching = false
		comeHome()
	end
	onCharacter(char)
end)
if player.Character then
	onCharacter(player.Character)
end

UserInputService.InputBegan:Connect(function(input, gameProcessed)
	if gameProcessed or not watching then
		return
	end
	if input.KeyCode == Enum.KeyCode.Right then
		step(1)
	elseif input.KeyCode == Enum.KeyCode.Left then
		step(-1)
	end
end)

-- The living drift: refresh the watched frame every few seconds in case the
-- fighter we ride falls or leaves.
task.spawn(function()
	while true do
		task.wait(3)
		if watching then
			look()
		end
	end
end)

print("[Dharma] Spectate ready — spirits ride the eyes of the living.")
