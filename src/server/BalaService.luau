--!strict
-- BalaService: tends the sangha's shared strength. While a battle rages and
-- warriors fight shoulder to shoulder, a single server-wide meter fills; at
-- its brim it breaks into a SANGHA RALLY — every standing ally cleansed of
-- affliction, healed, and flooded with Tejas. Purely a gift of endurance
-- (no damage), so it is beneath the Stack Law's notice.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local Net = require(ReplicatedStorage.Shared.Net)
local Bala = require(ReplicatedStorage.Shared.Bala)
local Combat = require(ReplicatedStorage.Shared.Combat)
local Progression = require(ReplicatedStorage.Shared.Progression)
local PlayerRegistry = require(script.Parent.PlayerRegistry)
local ProgressionService = require(script.Parent.ProgressionService)
local EnemyService = require(script.Parent.EnemyService)

local BalaService = {}

local meter = 0

type Fighter = { player: Player, root: BasePart }

local function broadcastAll(data: { [string]: any })
	for _, p in Players:GetPlayers() do
		Net.CombatFeedback:FireClient(p, data)
	end
end

-- The standing sangha: living flesh, present and fighting (spirits, the
-- downed, and meditators are not shoulders in the line).
local function standingFighters(): { Fighter }
	local out: { Fighter } = {}
	for _, player in Players:GetPlayers() do
		local char = player.Character
		if not char then
			continue
		end
		local root = char:FindFirstChild("HumanoidRootPart")
		local hum = char:FindFirstChildOfClass("Humanoid")
		if not root or not root:IsA("BasePart") or not hum or hum.Health <= 0 then
			continue
		end
		if char:GetAttribute("DharmaDowned") == true or char:GetAttribute("DharmaBhoota") == true or char:GetAttribute("DharmaDhyana") == true then
			continue
		end
		table.insert(out, { player = player, root = root })
	end
	return out
end

-- The largest shoulder-to-shoulder cluster among the standing right now.
local function largestCluster(fighters: { Fighter }): number
	local r2 = Bala.Config.Radius * Bala.Config.Radius
	local best = 0
	for i, a in fighters do
		local count = 1
		for j, b in fighters do
			if i ~= j then
				local d = a.root.Position - b.root.Position
				if d.X * d.X + d.Z * d.Z <= r2 then
					count += 1
				end
			end
		end
		best = math.max(best, count)
	end
	return best
end

-- The rally: cleanse, heal, and Tejas for every standing ally at once.
local function rally(fighters: { Fighter })
	broadcastAll({ sanghaRally = true })
	for _, f in fighters do
		local state = PlayerRegistry.get(f.player)
		state.venomUntil = 0
		state.curseUntil = 0
		state.chillUntil = 0
		local char = f.player.Character
		local hum = char and char:FindFirstChildOfClass("Humanoid")
		if hum and hum.Health > 0 then
			hum.Health = math.min(hum.MaxHealth, hum.Health + hum.MaxHealth * Bala.Config.RallyHealFraction)
		end
		local level = Progression.resolve(state.totalXp).level
		state.tejas = Combat.clampTejas(state.tejas + Bala.Config.RallyTejas, Progression.maxTejasForLevel(level))
		Net.CombatFeedback:FireClient(f.player, { tejas = state.tejas })
		ProgressionService.refreshStats(f.player) -- the cleanse thaws chilled legs now
	end
end

task.spawn(function()
	while true do
		task.wait(Bala.Config.TickSeconds)
		-- The meter only lives during the fight; peace lets it fade.
		if EnemyService.aliveCount() <= 0 then
			if meter > 0 then
				meter = 0
				broadcastAll({ balaMeter = 0, balaMax = Bala.Config.Max })
			end
			continue
		end
		local fighters = standingFighters()
		local fill = Bala.fillFor(largestCluster(fighters))
		if fill > 0 then
			meter = Bala.add(meter, fill)
			if Bala.isFull(meter) then
				meter = 0
				rally(fighters)
			end
			broadcastAll({ balaMeter = meter, balaMax = Bala.Config.Max })
		end
	end
end)

print("[Dharma] BalaService ready — the sangha grows strong together.")

return BalaService
