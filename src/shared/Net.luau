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
	-- client -> server: "the player swung" (LMB; server decides light/heavy via the chain)
	AttackRequest = ensureRemote("AttackRequest"),
	-- client -> server: an ability was used ("Z" | "X" | "C" | "V")
	AbilityRequest = ensureRemote("AbilityRequest"),
	-- client -> server: shop actions ({action="info"} or {action="buy", id=...})
	ShopRequest = ensureRemote("ShopRequest"),
	-- client -> server: weapon actions ({action="select", id=...})
	WeaponRequest = ensureRemote("WeaponRequest"),
	-- client -> server: Mantra Altar actions ({action="info"} or {action="inscribe"})
	EnchantRequest = ensureRemote("EnchantRequest"),
	-- client -> server: stats page requests ({action="info"})
	StatsRequest = ensureRemote("StatsRequest"),
	-- client -> server: title actions ({action="list"} or {action="equip", id=...})
	TitleRequest = ensureRemote("TitleRequest"),
	-- client -> server: duel actions ({action="list"|"challenge"|"accept"|"decline", userId=...})
	PvPRequest = ensureRemote("PvPRequest"),
	-- client -> server: Astra Path actions ({action="info"} or {action="choose", id=...})
	PathRequest = ensureRemote("PathRequest"),
	-- client -> server: relic actions ({action="info"} or {action="equip", slot=..., id=...})
	RelicRequest = ensureRemote("RelicRequest"),
	-- client -> server: story journal requests ({action="info"})
	StoryRequest = ensureRemote("StoryRequest"),
	-- client -> server: current guard state (blocking / dodging)
	DefenseState = ensureRemote("DefenseState"),
	-- server -> client: HUD feedback (combo count, tejas, outcome text)
	CombatFeedback = ensureRemote("CombatFeedback"),
	-- server -> all clients: play a procedural animation on a character (model, trackName)
	AnimEvent = ensureRemote("AnimEvent"),
}

return Net
