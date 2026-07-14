--!strict
-- The ears of the game: turns combat/reward/wave events into sound.
-- SFX use built-in rbxasset audio (no uploads needed); pitch is randomized per
-- play within each def's range so few sources feel like many.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")
local Players = game:GetService("Players")
local Debris = game:GetService("Debris")

local Net = require(ReplicatedStorage.Shared.Net)
local SoundDefs = require(ReplicatedStorage.Shared.SoundDefs)

local player = Players.LocalPlayer
local rng = Random.new()

-- Play a named SFX. With `at` (a BasePart), it's positional 3D; otherwise 2D/local.
local function play(name: string, at: BasePart?)
	local def = SoundDefs.Sfx[name]
	if not def then
		return
	end

	local sound = Instance.new("Sound")
	sound.SoundId = def.path
	sound.Volume = def.volume
	sound.PlaybackSpeed = rng:NextNumber(def.pitchMin, def.pitchMax)
	sound.RollOffMaxDistance = 140
	sound.Parent = at or SoundService
	sound:Play()
	Debris:AddItem(sound, 6)
end

local function rootOf(model: Model): BasePart?
	local part = model:FindFirstChild("HumanoidRootPart")
	if part and part:IsA("BasePart") then
		return part
	end
	return model.PrimaryPart
end

-- ---------------------------------------------------------------------------
-- Combat actions (piggyback the animation broadcasts — they ARE the combat events).
-- ---------------------------------------------------------------------------
Net.AnimEvent.OnClientEvent:Connect(function(model: any, trackName: any)
	if typeof(model) ~= "Instance" or not model:IsA("Model") then
		return
	end
	local sfxName = SoundDefs.AnimSounds[tostring(trackName)]
	if sfxName then
		play(sfxName, rootOf(model))
	end
end)

-- ---------------------------------------------------------------------------
-- Boss war-drums.
-- ---------------------------------------------------------------------------
local drumsActive = false

local function drumLoop()
	local drums = SoundDefs.BossDrums
	while drumsActive do
		local cycleStart = os.clock()
		for _, beat in drums.beats do
			if not drumsActive then
				return
			end
			local waitFor = (cycleStart + beat.t) - os.clock()
			if waitFor > 0 then
				task.wait(waitFor)
			end
			if not drumsActive then
				return
			end
			local sound = Instance.new("Sound")
			sound.SoundId = drums.sfxPath
			sound.Volume = beat.volume
			sound.PlaybackSpeed = beat.pitch
			sound.Parent = SoundService
			sound:Play()
			Debris:AddItem(sound, 4)
		end
		local remaining = (cycleStart + drums.cycleSeconds) - os.clock()
		if remaining > 0 then
			task.wait(remaining)
		end
	end
end

local function setDrums(on: boolean)
	if on and not drumsActive then
		drumsActive = true
		task.spawn(drumLoop)
	elseif not on then
		drumsActive = false
	end
end

-- ---------------------------------------------------------------------------
-- HUD-feedback events (defense outcomes, rewards, waves, bosses).
-- ---------------------------------------------------------------------------
Net.CombatFeedback.OnClientEvent:Connect(function(data: any)
	if typeof(data) ~= "table" then
		return
	end

	-- Incoming-defense outcomes.
	if data.incoming and data.outcome then
		local sfxName = SoundDefs.FeedbackSounds[tostring(data.outcome)]
		if sfxName then
			play(sfxName)
		end
		return
	end

	-- Own offense: landing the finisher gets extra crunch.
	if data.outcome == "Hit" and data.isFinisher then
		play("finisherLand")
		return
	end

	-- Rewards.
	if data.goldUpdate and data.gained and data.gained > 0 then
		play("goldPickup")
		return
	end
	if data.amrit then
		play("amritPickup")
		return
	end
	if data.levelUp then
		play("levelUp")
		return
	end
	if data.shopBought then
		play("shopBuy")
		return
	end
	if data.questComplete then
		play("questDone")
		return
	end

	-- Waves.
	if data.waveState == "start" then
		play("waveStart")
		return
	end
	if data.waveState == "clear" then
		play("waveClear")
		setDrums(false)
		return
	end

	-- Bosses.
	if data.bossState == "spawn" then
		play("bossSpawn")
		setDrums(true)
		return
	end
	if data.bossState == "defeated" then
		play("bossDefeated")
		setDrums(false)
		return
	end
end)

-- Your own fall.
local function hookCharacter(char: Model)
	local hum = char:WaitForChild("Humanoid", 10)
	if hum and hum:IsA("Humanoid") then
		hum.Died:Connect(function()
			play("playerDown")
		end)
	end
end
if player.Character then
	task.spawn(hookCharacter, player.Character)
end
player.CharacterAdded:Connect(function(char)
	task.spawn(hookCharacter, char)
end)

print("[Dharma] SoundController ready — combat has a voice.")
