--!strict
-- Central place for networking objects. The server creates them; clients wait for them.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local function ensureRemote(name: string): RemoteEvent
	if RunService:IsServer() then
		local existing = ReplicatedStorage:FindFirstChild(name)
		if existing and existing:IsA("RemoteEvent") then
			return existing
		end
		local remote = Instance.new("RemoteEvent")
		remote.Name = name
		remote.Parent = ReplicatedStorage
		return remote
	else
		return ReplicatedStorage:WaitForChild(name) :: RemoteEvent
	end
end

local Net = {
	-- client -> server: "the player swung" ("Light" | "Heavy")
	AttackRequest = ensureRemote("AttackRequest"),
	-- client -> server: current guard state (blocking / dodging)
	DefenseState = ensureRemote("DefenseState"),
	-- server -> client: HUD feedback (combo count, tejas, outcome text)
	CombatFeedback = ensureRemote("CombatFeedback"),
}

return Net
