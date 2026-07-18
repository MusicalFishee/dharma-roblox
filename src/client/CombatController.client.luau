--!strict
-- Captures player combat input and forwards intent to the server.
-- LMB drives the auto-combo (the server's chain decides light vs heavy).
-- Z / X / C / V are the ability slots. Shift blocks, Q dodges.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local Net = require(ReplicatedStorage.Shared.Net)

local abilityKeys: { [Enum.KeyCode]: string } = {
	[Enum.KeyCode.Z] = "Z",
	[Enum.KeyCode.X] = "X",
	[Enum.KeyCode.C] = "C",
	[Enum.KeyCode.V] = "V",
}

UserInputService.InputBegan:Connect(function(input: InputObject, gameProcessed: boolean)
	if gameProcessed then
		return
	end

	if input.UserInputType == Enum.UserInputType.MouseButton1 then
		Net.AttackRequest:FireServer() -- server chain decides light/heavy + cadence
		return
	end

	local ability = abilityKeys[input.KeyCode]
	if ability then
		Net.AbilityRequest:FireServer({ slot = ability, action = "chargeStart" })
		return
	end

	if input.KeyCode == Enum.KeyCode.LeftShift then
		Net.DefenseState:FireServer({ isBlocking = true })
	elseif input.KeyCode == Enum.KeyCode.Q then
		Net.DefenseState:FireServer({ dodge = true })
	end
end)

UserInputService.InputEnded:Connect(function(input: InputObject)
	local ability = abilityKeys[input.KeyCode]
	if ability then
		Net.AbilityRequest:FireServer({ slot = ability, action = "release" })
		return
	end
	if input.KeyCode == Enum.KeyCode.LeftShift then
		Net.DefenseState:FireServer({ isBlocking = false })
	end
end)

print("[Dharma] Input ready — LMB combo, Z/X/C/V abilities (hold to draw), Shift block, Q dodge.")
