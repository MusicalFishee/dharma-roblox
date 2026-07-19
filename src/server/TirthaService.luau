--!strict
-- TirthaService: raises one shrine stone per ordinary wave at a wandering
-- spot; one touch per pilgrim per wave grants the REALM's blessing, and the
-- stone sinks when the wave breaks. Spirits and the meditating pass by.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Debris = game:GetService("Debris")

local Net = require(ReplicatedStorage.Shared.Net)
local Tirtha = require(ReplicatedStorage.Shared.Tirtha)
local Zones = require(ReplicatedStorage.Shared.Zones)
local Combat = require(ReplicatedStorage.Shared.Combat)
local Progression = require(ReplicatedStorage.Shared.Progression)
local Loot = require(ReplicatedStorage.Shared.Loot)
local PlayerRegistry = require(script.Parent.PlayerRegistry)
local ProgressionService = require(script.Parent.ProgressionService)

local TirthaService = {}

local stone: Part? = nil
local served: { [Player]: boolean } = {}

local function bless(def: Tirtha.TirthaDef, player: Player)
	local state = PlayerRegistry.get(player)
	if def.kind == "tejas" then
		local level = Progression.resolve(state.totalXp).level
		state.tejas = Combat.clampTejas(state.tejas + def.amount, Progression.maxTejasForLevel(level))
		Net.CombatFeedback:FireClient(player, { tejas = state.tejas })
	elseif def.kind == "ward" then
		state.wardUntil = os.clock() + def.seconds
		state.wardMult = def.amount
	elseif def.kind == "empower" then
		state.empowerUntil = os.clock() + def.seconds
		state.empowerMult = def.amount
	elseif def.kind == "cleanse" then
		state.venomUntil = 0
		state.curseUntil = 0
		state.chillUntil = 0
		ProgressionService.refreshStats(player) -- the spring thaws the legs NOW
	elseif def.kind == "gold" then
		state.gold = Loot.clampGold(state.gold + def.amount)
		Net.CombatFeedback:FireClient(player, { goldUpdate = true, gained = def.amount, gold = state.gold })
	end
	Net.CombatFeedback:FireClient(player, { tirthaBlessed = true, name = def.name, line = def.line })
end

-- An ordinary wave begins: the realm's ford rises at a wandering spot.
function TirthaService.raise(wave: number)
	TirthaService.sink()
	local def = Tirtha.forZone(Zones.forWave(wave).id)
	if not def then
		return
	end
	table.clear(served)

	local angle = math.random() * 2 * math.pi
	local r = 14 + math.random() * 22
	local rock = Instance.new("Part")
	rock.Name = "TirthaStone"
	rock.Size = Vector3.new(2.4, 3.6, 2.4)
	rock.Position = Vector3.new(math.cos(angle) * r, 4.2, math.sin(angle) * r)
	rock.Color = Color3.fromRGB(235, 225, 200)
	rock.Material = Enum.Material.Marble
	rock.Anchored = true
	rock.Parent = workspace
	local halo = Instance.new("PointLight")
	halo.Color = Color3.fromRGB(255, 245, 210)
	halo.Range = 12
	halo.Brightness = 1.4
	halo.Parent = rock

	local billboard = Instance.new("BillboardGui")
	billboard.Size = UDim2.fromOffset(200, 44)
	billboard.StudsOffset = Vector3.new(0, 3.2, 0)
	billboard.AlwaysOnTop = true
	billboard.Parent = rock
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.GothamBold
	label.TextSize = 14
	label.TextColor3 = Color3.fromRGB(255, 245, 210)
	label.TextStrokeTransparency = 0.4
	label.TextWrapped = true
	label.Text = "TIRTHA\n" .. def.name
	label.Parent = billboard

	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = "Touch the stone"
	prompt.ObjectText = def.name
	prompt.HoldDuration = 0.6
	prompt.MaxActivationDistance = 10
	prompt.RequiresLineOfSight = false
	prompt.Parent = rock
	prompt.Triggered:Connect(function(pilgrim: Player)
		if served[pilgrim] then
			return
		end
		local char = pilgrim.Character
		if char and (char:GetAttribute("DharmaBhoota") == true or char:GetAttribute("DharmaDhyana") == true) then
			return -- the ford blesses walking flesh
		end
		served[pilgrim] = true
		bless(def, pilgrim)
	end)

	stone = rock
end

-- The wave breaks (or wipes): the ford sinks.
function TirthaService.sink()
	local rock = stone
	stone = nil
	if rock and rock.Parent then
		TweenService:Create(rock, TweenInfo.new(1.0), { Transparency = 1 }):Play()
		Debris:AddItem(rock, 1.1)
	end
end

return TirthaService
