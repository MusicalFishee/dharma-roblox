--!strict
-- Server entry point. Wires up players and proves the shared Combat module loads.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local Combat = require(ReplicatedStorage.Shared.Combat)

print(string.format(
	"[Dharma] Server up. Combat loaded — light=%d heavy=%d Astra cost=%d",
	Combat.Config.LightDamage,
	Combat.Config.HeavyDamage,
	Combat.Config.AgniAstraCost
))

Players.PlayerAdded:Connect(function(player: Player)
	print(string.format("[Dharma] %s entered the world.", player.Name))
end)
