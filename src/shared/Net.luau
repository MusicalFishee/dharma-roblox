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
	-- client -> server: boon draft pick ({action="pick", id=...})
	VaraRequest = ensureRemote("VaraRequest"),
	-- client -> server: rites ({action="info"|"offer"|"swear", id=...})
	RitesRequest = ensureRemote("RitesRequest"),
	-- client -> server: sacred marks + emotes ({action="info"|"equip"|"emote", ...})
	VibhutiRequest = ensureRemote("VibhutiRequest"),
	-- client -> server: the device class being played on ({method="keyboard"|"gamepad"|"touch"})
	InputReport = ensureRemote("InputReport"),
	-- client -> server: kirti bounty claims ({action="info"} or {action="claim", id=...})
	KirtiRequest = ensureRemote("KirtiRequest"),

	LoadoutRequest = ensureRemote("LoadoutRequest"),

	GanaRequest = ensureRemote("GanaRequest"),

	YatraRequest = ensureRemote("YatraRequest"),

	BhavaRequest = ensureRemote("BhavaRequest"),
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
