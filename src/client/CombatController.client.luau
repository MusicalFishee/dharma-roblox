--!strict
-- Captures player combat input and forwards intent to the server.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local Net = require(ReplicatedStorage.Shared.Net)

local function sendAttack(kind: string)
	Net.AttackRequest:FireServer(kind)
end

local function setBlocking(isBlocking: boolean)
	Net.DefenseState:FireServer({ isBlocking = isBlocking })
end

local function sendDodge()
	Net.DefenseState:FireServer({ dodge = true })
end

UserInputService.InputBegan:Connect(function(input: InputObject, gameProcessed: boolean)
	if gameProcessed then
		return
	end

	if input.UserInputType == Enum.UserInputType.MouseButton1 then
		sendAttack("Light")
	elseif input.KeyCode == Enum.KeyCode.R then
		sendAttack("Heavy")
	elseif input.KeyCode == Enum.KeyCode.LeftShift then
		setBlocking(true)
	elseif input.KeyCode == Enum.KeyCode.Q then
		sendDodge()
	end
end)

UserInputService.InputEnded:Connect(function(input: InputObject)
	if input.KeyCode == Enum.KeyCode.LeftShift then
		setBlocking(false)
	end
end)

-- Gamepad support.
UserInputService.InputBegan:Connect(function(input: InputObject, gameProcessed: boolean)
	if gameProcessed then
		return
	end
	if input.KeyCode == Enum.KeyCode.ButtonR2 then
		sendAttack("Light")
	elseif input.KeyCode == Enum.KeyCode.ButtonR1 then
		sendAttack("Heavy")
	elseif input.KeyCode == Enum.KeyCode.ButtonL2 then
		setBlocking(true)
	elseif input.KeyCode == Enum.KeyCode.ButtonB then
		sendDodge()
	end
end)

UserInputService.InputEnded:Connect(function(input: InputObject)
	if input.KeyCode == Enum.KeyCode.ButtonL2 then
		setBlocking(false)
	end
end)

print("[Dharma] Combat input ready — LMB light, R heavy, Shift block, Q dodge.")
