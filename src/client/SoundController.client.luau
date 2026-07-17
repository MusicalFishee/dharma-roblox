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
-- `pitchMult` scales the randomized pitch (combo chains climb as they go).
local function play(name: string, at: BasePart?, pitchMult: number?)
	local def = SoundDefs.Sfx[name]
	if not def then
		return
	end

	local sound = Instance.new("Sound")
	sound.SoundId = def.path
	sound.Volume = def.volume
	sound.PlaybackSpeed = rng:NextNumber(def.pitchMin, def.pitchMax) * (pitchMult or 1)
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
	local name = tostring(trackName)
	local sfxName = SoundDefs.AnimSounds[name]
	if sfxName then
		-- Swing sounds climb with the chain (combo1 lowest -> combo4 finisher).
		local comboIndex = string.match(name, "^combo(%d)$")
		local pitchMult = if comboIndex then SoundDefs.comboPitch(tonumber(comboIndex) :: number) else 1
		play(sfxName, rootOf(model), pitchMult)
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

	-- Own offense: crits ring sharp, finishers land with extra crunch.
	if data.outcome == "Hit" and data.isCrit then
		play("critHit")
		return
	end
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
	if data.dailyComplete then
		play("levelUp")
		return
	end
	if data.dailyReset then
		play("waveStart")
		return
	end
	if data.milestone then
		play("levelUp")
		return
	end
	if data.weaponChosen then
		play("levelUp")
		return
	end
	if data.pathChosen then
		play("levelUp")
		return
	end
	if data.relicDrop then
		play(if data.mythic then "thunderCrack" else "questDone")
		return
	end
	if data.downed then
		play("playerDown")
		return
	end
	if data.revived or data.liftedAlly then
		play("levelUp")
		return
	end
	if data.masteryUp then
		play("levelUp")
		return
	end
	if data.bhoota then
		play("playerDown")
		return
	end
	if data.punarjanma then
		play("levelUp")
		return
	end
	if data.agnihotra then
		play("levelUp")
		return
	end
	if data.bazaarGranted then
		play("shopBuy")
		return
	end
	if data.vira then
		play("critHit")
		return
	end
	if data.tutorialDone then
		play("levelUp")
		return
	end
	if data.rankUp then
		play("thunderCrack")
		return
	end
	if data.varaOffer then
		play("questDone")
		return
	end
	if data.varaPicked then
		play("levelUp")
		return
	end
	if data.waveGrade == "S" then
		play("thunderCrack")
		return
	end
	if data.dosha then
		play("bossSpawn")
		return
	end
	if data.doshaBounty then
		play("goldPickup")
		return
	end
	if data.siddhiUnlocked then
		play("thunderCrack")
		return
	end
	if data.utsava == "begin" then
		play("waveStart")
		return
	end
	if data.utsava == "deerSlain" or data.utsava == "merchantSold" then
		play("goldPickup")
		return
	end
	if data.headFall then
		play("finisherLand")
		return
	end
	if data.raidEnrage then
		play("bossSpawn")
		return
	end
	if data.raidVictory then
		play("bossDefeated")
		return
	end
	if data.storyChapter or data.storyCatchup then
		play("levelUp")
		return
	end
	if data.titleEquipped then
		play("shopBuy")
		return
	end
	if data.pvp == "countdown" then
		play("guardUp")
		return
	end
	if data.pvp == "begin" then
		play("bossSpawn")
		return
	end
	if data.pvp == "won" then
		play("bossDefeated")
		return
	end
	if data.pvp == "lost" then
		play("playerDown")
		return
	end
	if data.shardUpdate then
		play("amritPickup")
		return
	end
	if data.enchantResult then
		-- A mythic reveal cracks like thunder; ordinary inscriptions chime.
		play(if data.mythic then "thunderCrack" else "questDone")
		return
	end

	-- Zone transitions get the deep boom.
	if data.zoneChange then
		play("bossSpawn")
		return
	end

	-- Party wipe: deep toll, and silence the drums.
	if data.waveState == "wipe" then
		play("playerDown")
		setDrums(false)
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

	-- Boss speech: every line lands on a deep drum note.
	if data.bossLine then
		play("waveStart")
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
	if data.bossState == "passed" then
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
