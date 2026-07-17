--!strict
-- Gamepad controls: R2 strike, L2 hold-to-block, B dodge, D-Pad Astras,
-- Y for the menu drawer (with Roblox's virtual cursor for panel clicking).
-- The hint bar renders GetImageForKeyCode glyphs — Xbox buttons on Xbox,
-- PlayStation buttons on PlayStation, each console sees its own controls.
-- Fires the exact remotes the keyboard does; the server can't tell pad from key.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local ContextActionService = game:GetService("ContextActionService")
local GamepadService = game:GetService("GamepadService")

local Net = require(ReplicatedStorage.Shared.Net)
local Gamepad = require(ReplicatedStorage.Shared.Gamepad)
local PanelDirectory = require(ReplicatedStorage.Shared.PanelDirectory)

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local GOLD = Color3.fromRGB(255, 200, 40)
local BTN_BG = Color3.fromRGB(24, 20, 30)
local DIM = Color3.fromRGB(200, 195, 205)

local screenGui = Instance.new("ScreenGui")
screenGui.Name = "DharmaGamepad"
screenGui.ResetOnSpawn = false
screenGui.DisplayOrder = 12
screenGui.Parent = playerGui

-- ---------------------------------------------------------------------------
-- The drawer (shared directory; big rows, virtual-cursor friendly).
-- ---------------------------------------------------------------------------
local drawerOpen = false
local drawerButtons: { TextButton } = {}

for i, entry in PanelDirectory.Entries do
	local b = Instance.new("TextButton")
	b.Size = UDim2.fromOffset(150, 40)
	b.Position = UDim2.fromOffset(16, 100 + (i - 1) * 46)
	b.BackgroundColor3 = BTN_BG
	b.BackgroundTransparency = 0.15
	b.Font = Enum.Font.GothamBold
	b.TextSize = 15
	b.TextColor3 = DIM
	b.Text = entry.label
	b.Visible = false
	b.Parent = screenGui
	local bc = Instance.new("UICorner")
	bc.CornerRadius = UDim.new(0, 8)
	bc.Parent = b

	b.Activated:Connect(function()
		local gui = playerGui:FindFirstChild(entry.gui)
		if gui and gui:IsA("ScreenGui") then
			gui.Enabled = not gui.Enabled
			if gui.Enabled and entry.remote then
				local remote = (Net :: any)[entry.remote]
				if remote then
					remote:FireServer({ action = entry.payloadAction })
				end
			end
		end
	end)
	table.insert(drawerButtons, b)
end

local function setDrawer(open: boolean)
	drawerOpen = open
	for _, b in drawerButtons do
		b.Visible = open
	end
	pcall(function()
		if open then
			GamepadService:EnableGamepadCursor(drawerButtons[1])
		else
			GamepadService:DisableGamepadCursor()
		end
	end)
	if not open then
		-- Y while the menu is up closes every Dharma panel too.
		for _, entry in PanelDirectory.Entries do
			local gui = playerGui:FindFirstChild(entry.gui)
			if gui and gui:IsA("ScreenGui") then
				gui.Enabled = false
			end
		end
	end
end

-- ---------------------------------------------------------------------------
-- Combat binds (ContextActionService; one button, one job).
-- ---------------------------------------------------------------------------
local function handler(actionName: string, inputState: Enum.UserInputState, _input: InputObject)
	if actionName == "DharmaPadAttack" then
		if inputState == Enum.UserInputState.Begin then
			Net.AttackRequest:FireServer()
		end
	elseif actionName == "DharmaPadBlock" then
		if inputState == Enum.UserInputState.Begin then
			Net.DefenseState:FireServer({ isBlocking = true })
		elseif inputState == Enum.UserInputState.End then
			Net.DefenseState:FireServer({ isBlocking = false })
		end
	elseif actionName == "DharmaPadDodge" then
		if inputState == Enum.UserInputState.Begin then
			Net.DefenseState:FireServer({ dodge = true })
		end
	elseif actionName == "DharmaPadMenu" then
		if inputState == Enum.UserInputState.Begin then
			setDrawer(not drawerOpen)
		end
	else
		local slot = string.match(actionName, "^DharmaPadAbility(%a)$")
		if slot and inputState == Enum.UserInputState.Begin then
			Net.AbilityRequest:FireServer(slot)
		end
	end
	return Enum.ContextActionResult.Pass
end

for _, bind in Gamepad.Binds do
	local keyCode = (Enum.KeyCode :: any)[bind.button] :: Enum.KeyCode?
	if not keyCode then
		continue
	end
	local actionName = if bind.action == "attack" then "DharmaPadAttack"
		elseif bind.action == "block" then "DharmaPadBlock"
		elseif bind.action == "dodge" then "DharmaPadDodge"
		elseif bind.action == "menu" then "DharmaPadMenu"
		else "DharmaPadAbility" .. (bind.slot :: string)
	ContextActionService:BindAction(actionName, handler, false, keyCode)
end

-- ---------------------------------------------------------------------------
-- The hint bar: platform-correct glyphs, shown only while the pad speaks last.
-- ---------------------------------------------------------------------------
local hintBar = Instance.new("Frame")
hintBar.Size = UDim2.fromOffset(#Gamepad.Binds * 96, 40)
hintBar.AnchorPoint = Vector2.new(0.5, 1)
hintBar.Position = UDim2.new(0.5, 0, 1, -6)
hintBar.BackgroundColor3 = Color3.fromRGB(14, 11, 17)
hintBar.BackgroundTransparency = 0.35
hintBar.Visible = false
hintBar.Parent = screenGui
local hc = Instance.new("UICorner")
hc.CornerRadius = UDim.new(0, 10)
hc.Parent = hintBar

for i, bind in Gamepad.Binds do
	local keyCode = (Enum.KeyCode :: any)[bind.button] :: Enum.KeyCode?
	local x = (i - 1) * 96

	local glyph = Instance.new("ImageLabel")
	glyph.Size = UDim2.fromOffset(26, 26)
	glyph.Position = UDim2.fromOffset(x + 8, 7)
	glyph.BackgroundTransparency = 1
	glyph.Parent = hintBar
	if keyCode then
		pcall(function()
			-- Xbox art on Xbox, PlayStation art on PlayStation — the platform decides.
			glyph.Image = UserInputService:GetImageForKeyCode(keyCode)
		end)
	end

	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromOffset(60, 40)
	label.Position = UDim2.fromOffset(x + 36, 0)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.GothamMedium
	label.TextSize = 10
	label.TextColor3 = if bind.action == "attack" then GOLD else DIM
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.TextWrapped = true
	label.Text = bind.label
	label.Parent = hintBar
end

local function refreshHintBar()
	local lastInput = UserInputService:GetLastInputType()
	hintBar.Visible = lastInput.Name and string.find(lastInput.Name, "^Gamepad") ~= nil
end

UserInputService.LastInputTypeChanged:Connect(refreshHintBar)
refreshHintBar()

print("[Dharma] GamepadUI ready — pads welcome (the doorman handles Nintendo).")
