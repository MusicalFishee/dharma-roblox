--!strict
-- Loot drops: slain enemies burst into a gold orb (and sometimes a healing Amrit orb).
-- Walk over an orb to collect it. Gold persists via DataService.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local Debris = game:GetService("Debris")
local TweenService = game:GetService("TweenService")

local Net = require(ReplicatedStorage.Shared.Net)
local Loot = require(ReplicatedStorage.Shared.Loot)
local Relics = require(ReplicatedStorage.Shared.Relics)
local Progression = require(ReplicatedStorage.Shared.Progression)
local Ranks = require(ReplicatedStorage.Shared.Ranks)
local EnemyTypes = require(ReplicatedStorage.Shared.EnemyTypes)
local StatusEffects = require(ReplicatedStorage.Shared.StatusEffects)
local PlayerRegistry = require(script.Parent.PlayerRegistry)
local QuestService = require(script.Parent.QuestService)

local ORB_LIFETIME = 25

local LootService = {}

local function makeOrb(position: Vector3, color: Color3, size: number): Part
	local orb = Instance.new("Part")
	orb.Shape = Enum.PartType.Ball
	orb.Size = Vector3.new(size, size, size)
	orb.Position = position + Vector3.new(0, 2, 0)
	orb.Color = color
	orb.Material = Enum.Material.Neon
	orb.Anchored = true
	orb.CanCollide = false
	orb.CanQuery = false
	orb.Parent = workspace

	-- Gentle bob so it catches the eye.
	TweenService:Create(
		orb,
		TweenInfo.new(0.8, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true),
		{ Position = orb.Position + Vector3.new(0, 1.2, 0) }
	):Play()

	Debris:AddItem(orb, ORB_LIFETIME)
	return orb
end

-- First player to touch claims it; returns their Player.
local function onFirstTouch(orb: Part, claim: (Player) -> ())
	local taken = false
	orb.Touched:Connect(function(other: BasePart)
		if taken then
			return
		end
		local char = other:FindFirstAncestorOfClass("Model")
		local player = char and Players:GetPlayerFromCharacter(char)
		if not player then
			return
		end
		if char and char:GetAttribute("DharmaBhoota") == true then
			return -- mist cannot hold gold; the orb waits for the living
		end
		taken = true
		claim(player)
		orb:Destroy()
	end)
end

function LootService.dropAt(position: Vector3, archetype: EnemyTypes.EnemyArchetype)
	-- Gold orb (bosses drop a bigger, brighter one).
	local gold = Loot.goldFor(archetype.xpReward, archetype.isBoss == true)
	local goldOrb = makeOrb(
		position,
		Color3.fromRGB(255, 200, 40),
		if archetype.isBoss then 3.2 else 1.6
	)
	onFirstTouch(goldOrb, function(player: Player)
		local state = PlayerRegistry.get(player)
		-- Worn relics and held rank both fatten every orb you claim.
		local rankIndex = Ranks.rankFor(Progression.resolve(state.totalXp).level)
		local gained = math.floor(gold * Relics.totalBonus(Relics.equippedList(state.relics.equipped)).goldMult * Ranks.boonFor(rankIndex).goldMult)
		state.gold = Loot.clampGold(state.gold + gained)
		Net.CombatFeedback:FireClient(player, { goldUpdate = true, gained = gained, gold = state.gold })
		QuestService.onGold(player, gained)
	end)

	-- Occasional Amrit orb: heals on pickup.
	if Loot.rollAmrit() then
		local amritOrb = makeOrb(position + Vector3.new(3, 0, 0), Color3.fromRGB(90, 255, 140), 1.8)
		onFirstTouch(amritOrb, function(player: Player)
			local char = player.Character
			local hum = char and char:FindFirstChildOfClass("Humanoid")
			-- Curses thin even Amrit, the nectar of immortality.
			local state = PlayerRegistry.get(player)
			local heal = StatusEffects.effectiveHeal(Loot.AmritHeal, os.clock() < state.curseUntil)
			if hum then
				hum.Health = math.min(hum.MaxHealth, hum.Health + heal)
			end
			Net.CombatFeedback:FireClient(player, { amrit = true, heal = heal })
		end)
	end
end

return LootService
