--!strict
-- Server-side progression: award XP, apply level-ups, sync the HUD.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Net = require(ReplicatedStorage.Shared.Net)
local Progression = require(ReplicatedStorage.Shared.Progression)
local PlayerRegistry = require(script.Parent.PlayerRegistry)

local ProgressionService = {}

local function applyLevelStats(player: Player, level: number, fullHeal: boolean)
	local char = player.Character
	if not char then
		return
	end
	local humanoid = char:FindFirstChildOfClass("Humanoid")
	if not humanoid then
		return
	end
	humanoid.MaxHealth = Progression.maxHealthForLevel(level)
	if fullHeal then
		humanoid.Health = humanoid.MaxHealth
	end
end

function ProgressionService.getLevel(player: Player): number
	return Progression.resolve(PlayerRegistry.get(player).totalXp).level
end

-- Push the current XP/level snapshot to the client HUD.
function ProgressionService.sync(player: Player)
	local info = Progression.resolve(PlayerRegistry.get(player).totalXp)
	Net.CombatFeedback:FireClient(player, {
		progress = true,
		level = info.level,
		xpIntoLevel = info.xpIntoLevel,
		xpForNext = info.xpForNext,
		isMax = info.isMax,
	})
end

-- Called when a player's character spawns: set their level-based stats.
function ProgressionService.onCharacterSpawn(player: Player)
	applyLevelStats(player, ProgressionService.getLevel(player), true)
	ProgressionService.sync(player)
end

function ProgressionService.awardXp(player: Player, amount: number)
	if amount <= 0 then
		return
	end
	local state = PlayerRegistry.get(player)
	local before = Progression.resolve(state.totalXp)
	state.totalXp += amount
	local after = Progression.resolve(state.totalXp)

	if after.level > before.level then
		-- LEVEL UP: bigger max health, full heal, Tejas topped off.
		applyLevelStats(player, after.level, true)
		state.tejas = Progression.maxTejasForLevel(after.level)
		Net.CombatFeedback:FireClient(player, {
			levelUp = true,
			level = after.level,
			tejas = state.tejas,
		})
	end

	ProgressionService.sync(player)
end

return ProgressionService
