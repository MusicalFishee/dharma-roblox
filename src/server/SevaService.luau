--!strict
-- SevaService: the shared stone. One server-wide goal at a time; everyone's
-- hands move it, everyone online is paid when it breaks, and the wheel turns
-- to the next. Session-scoped — each server carries its own stone.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local Net = require(ReplicatedStorage.Shared.Net)
local Seva = require(ReplicatedStorage.Shared.Seva)
local Loot = require(ReplicatedStorage.Shared.Loot)
local PlayerRegistry = require(script.Parent.PlayerRegistry)

local SevaService = {}

local goalIndex = 1
local progress = 0

local function broadcastAll(data: { [string]: any })
	for _, p in Players:GetPlayers() do
		Net.CombatFeedback:FireClient(p, data)
	end
end

local function currentGoal(): Seva.GoalDef
	return Seva.goalAt(goalIndex)
end

local function announceGoal()
	local goal = currentGoal()
	broadcastAll({ sevaGoal = true, name = goal.name, line = goal.line, target = goal.target })
end

local function complete()
	local goal = currentGoal()
	for _, p in Players:GetPlayers() do
		local state = PlayerRegistry.tryGet(p)
		if not state then
			continue
		end
		state.gold = Loot.clampGold(state.gold + goal.gold)
		state.shards += goal.shards
		Net.CombatFeedback:FireClient(p, { goldUpdate = true, gained = goal.gold, gold = state.gold })
		if goal.shards > 0 then
			Net.CombatFeedback:FireClient(p, { shardUpdate = true, gained = goal.shards, shards = state.shards })
		end
	end
	broadcastAll({ sevaComplete = true, name = goal.name, gold = goal.gold, shards = goal.shards })

	goalIndex += 1
	progress = 0
	task.delay(6, announceGoal)
end

-- The tally. Kind must match the standing stone.
local function feed(kind: string, amount: number)
	local goal = currentGoal()
	if goal.kind ~= kind or progress >= goal.target then
		return
	end
	progress = math.min(progress + amount, goal.target)
	if progress >= goal.target then
		complete()
	elseif Seva.isMilestone(progress, goal.target) then
		broadcastAll({ sevaProgress = true, name = goal.name, progress = progress, target = goal.target })
	end
end

function SevaService.onKill(isBoss: boolean)
	feed("kills", 1)
	if isBoss then
		feed("bossKills", 1)
	end
end

function SevaService.onParry()
	feed("parries", 1)
end

function SevaService.onRevive()
	feed("revives", 1)
end

-- The first stone is announced when the server wakes.
task.delay(8, announceGoal)

print("[Dharma] SevaService ready — the stone waits for every hand.")

return SevaService
