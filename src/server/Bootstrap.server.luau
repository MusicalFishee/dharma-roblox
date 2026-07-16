--!strict
-- Server entry point. Wires players into the progression system on spawn.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local Combat = require(ReplicatedStorage.Shared.Combat)
local ProgressionService = require(script.Parent.ProgressionService)
require(script.Parent.WeaponService) -- activates the armory (weapon build/weld + choice remote)
require(script.Parent.PathService) -- activates the Astra Path oath + respec remote
require(script.Parent.RelicService) -- activates relic drops + the satchel remote
require(script.Parent.ReviveService) -- activates Uddhāra (bleed-out + lift prompts)
require(script.Parent.UtsavaService) -- activates festival events (deer/storm/vaidya)
require(script.Parent.StoryService) -- activates Agastya's journal remote

print(string.format(
	"[Dharma] Server up. Combat loaded — light=%d heavy=%d Astra cost=%d",
	Combat.Config.LightDamage,
	Combat.Config.HeavyDamage,
	Combat.Config.AgniAstraCost
))

local function onPlayer(player: Player)
	print(string.format("[Dharma] %s entered the world.", player.Name))
	player.CharacterAdded:Connect(function()
		task.wait(0.2)
		ProgressionService.onCharacterSpawn(player)
	end)
	if player.Character then
		ProgressionService.onCharacterSpawn(player)
	end
end

Players.PlayerAdded:Connect(onPlayer)
for _, p in Players:GetPlayers() do
	onPlayer(p)
end
