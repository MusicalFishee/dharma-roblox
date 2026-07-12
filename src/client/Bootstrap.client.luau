--!strict
-- Client entry point (runs on each player's device).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Combat = require(ReplicatedStorage.Shared.Combat)

print(string.format(
	"[Dharma] Client up. Parry window = %.2fs, block soak = %d%%",
	Combat.Config.ParryWindowSeconds,
	math.floor((1 - Combat.Config.BlockDamageMultiplier) * 100)
))
