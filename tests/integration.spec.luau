--!strict
-- Cross-system integration checks: the seams BETWEEN modules, where unit tests
-- don't look. If a name flows from one system into another (quest -> enemy id,
-- server anim broadcast -> track, ability slot -> unlock table), it's verified here.

local process = require("@lune/process")
local Quests = require("../src/shared/Quests")
local EnemyTypes = require("../src/shared/EnemyTypes")
local Bosses = require("../src/shared/Bosses")
local BossSpecials = require("../src/shared/BossSpecials")
local Abilities = require("../src/shared/Abilities")
local Progression = require("../src/shared/Progression")
local AnimationDefs = require("../src/shared/AnimationDefs")
local SoundDefs = require("../src/shared/SoundDefs")
local Elites = require("../src/shared/Elites")
local Waves = require("../src/shared/Waves")
local Zones = require("../src/shared/Zones")

local passed, failed = 0, 0
local failures: { string } = {}
local function check(name: string, cond: boolean)
	if cond then
		passed += 1
		print("  ok   " .. name)
	else
		failed += 1
		table.insert(failures, name)
		print("  FAIL " .. name)
	end
end

print("Integration")

-- 1. Kill-quests reference REAL enemy archetypes (a typo = quest never advances).
local killQuestsOk = true
for id, q in Quests.Catalog do
	if q.kind == "kill" and q.enemyId then
		if not EnemyTypes.List[q.enemyId] then
			killQuestsOk = false
			print("    !! quest " .. id .. " references unknown enemy " .. tostring(q.enemyId))
		end
	end
end
check("every kill-quest targets a real enemy archetype", killQuestsOk)

-- 2. Ability slots are consistent across config and unlock tables.
local slotsOk = true
for slot in Abilities.Config do
	if Progression.AbilityUnlockLevel[slot] == nil then
		slotsOk = false
	end
end
for slot in Progression.AbilityUnlockLevel do
	if Abilities.Config[slot] == nil then
		slotsOk = false
	end
end
check("ability slots match between Abilities.Config and unlock levels", slotsOk)

-- 3. Every roster boss has its own named special (never the generic fallback).
local specialsOk = true
for encounter = 1, 7 do
	local boss = Bosses.forWave(encounter * 5, 5)
	local sp = BossSpecials.forBoss(boss.id)
	if sp.name == BossSpecials.forBoss("__nonexistent__").name then
		specialsOk = false
		print("    !! boss " .. boss.id .. " fell back to the default special")
	end
end
check("all roster bosses have bespoke specials", specialsOk)

-- 4. Every animation the SERVER broadcasts exists as a track (or handled alias).
-- Canonical list of names fired via Net.AnimEvent in server code — keep in sync.
local broadcastAnims = {
	"combo1", "combo2", "combo3", "combo4", -- CombatService swings
	"flinch", -- CombatService + EnemyService + boss blast
	"enemySwing", -- EnemyService strikes
	"dash", -- DefenseState dodge + ability X
	"throw", "heal", "ult", -- abilities Z / C / V (+ boss windup reuses ult)
}
local animsOk = true
for _, name in broadcastAnims do
	if not AnimationDefs.Tracks[name] then
		animsOk = false
		print("    !! broadcast anim has no track: " .. name)
	end
end
check("every server-broadcast anim resolves to a track", animsOk)
check("block aliases handled (blockstart -> held block track exists)", AnimationDefs.Tracks.block ~= nil and AnimationDefs.Tracks.block.hold == true)

-- 5. Every broadcast anim has a sound mapping (blockend intentionally silent).
local animSoundsOk = true
for _, name in broadcastAnims do
	if not SoundDefs.AnimSounds[name] then
		animSoundsOk = false
		print("    !! broadcast anim has no sound: " .. name)
	end
end
check("every broadcast anim has an AnimSounds mapping", animSoundsOk)

-- 6. Elite copies of every archetype stay roster-shape compatible.
local eliteOk = true
for id, base in EnemyTypes.List do
	local e = Elites.makeElite(base :: any)
	if e.id ~= id or e.maxHealth <= base.maxHealth or e.xpReward <= base.xpReward or e.isElite ~= true then
		eliteOk = false
	end
end
check("elite variants of all archetypes are well-formed", eliteOk)

-- 7. Loot derives gold from xpReward: every spawnable must pay XP.
local xpOk = true
for _, a in EnemyTypes.List do
	if a.xpReward <= 0 then
		xpOk = false
	end
end
for encounter = 1, 7 do
	if Bosses.forWave(encounter * 5, 5).xpReward <= 0 then
		xpOk = false
	end
end
check("every enemy and boss pays XP (gold derives from it)", xpOk)

-- 8. Defense outcomes agree across melee (Combat) and blasts (BossSpecials),
--    and the HUD sound map covers them.
local meleeOutcomes = { "Dodge", "Parry", "Block", "Hit" }
local mapped = SoundDefs.FeedbackSounds
check("HUD sounds cover Parry/Block/Hit outcomes", mapped.Parry ~= nil and mapped.Block ~= nil and mapped.Hit ~= nil)
local blastOutcomes: { [string]: boolean } = {}
for _, args in { { true, false }, { false, true }, { false, false } } do
	blastOutcomes[BossSpecials.resolveBlast(10, args[1], args[2]).outcome] = true
end
local blastAgree = true
for outcome in blastOutcomes do
	local found = false
	for _, m in meleeOutcomes do
		if m == outcome then
			found = true
		end
	end
	if not found then
		blastAgree = false
	end
end
check("blast outcomes are a subset of melee outcomes (shared HUD/sounds)", blastAgree)

-- 9. Zone thresholds sit inside reachable wave space, and the first boss comes
--    before the first zone shift (learn bosses in the ashram first).
check("first zone change is deeper than the first boss wave", Zones.List[2].threshold > Waves.BossInterval)
check("zone thresholds are boss waves (transition = spectacle)", Zones.List[2].threshold % Waves.BossInterval == 0 and Zones.List[3].threshold % Waves.BossInterval == 0)


-- 9. The century systems agree with the rest of the game.
local Vira = require("../src/shared/Vira")
local Grade = require("../src/shared/Grade")
local Doshas = require("../src/shared/Doshas")
local Deeds = require("../src/shared/Deeds")
local Tutorial = require("../src/shared/Tutorial")
local CombatShared = require("../src/shared/Combat")

-- Vīra surges can never overflow the Tejas bar's own clamp contract.
local surgesOk = true
for _, rank in Vira.Ranks do
	if rank.tejas > CombatShared.Config.TejasMax then
		surgesOk = false
	end
end
check("vira surges fit inside the tejas bar", surgesOk)

-- Every grade the judge can emit has a color and a multiplier.
local gradesOk = true
for _, tallyCase in { { kills = 20, parries = 5, timesHit = 0, downs = 0 }, { kills = 7, parries = 1, timesHit = 3, downs = 0 }, { kills = 5, parries = 1, timesHit = 2, downs = 0 }, { kills = 0, parries = 0, timesHit = 9, downs = 2 } } do
	local g = Grade.gradeFor(Grade.score(tallyCase), 8)
	if not Grade.Color[g] or Grade.xpMult(g) < 1 then
		gradesOk = false
	end
end
check("every reachable grade has a color and pays", gradesOk)

-- Dosha waves never land on any bespoke encounter, across two hundred waves.
local cadenceOk = true
for wave = 1, 200 do
	if Doshas.isDoshaWave(wave) and (Waves.isBossWave(wave) or wave % 25 == 0) then
		cadenceOk = false
	end
end
check("doshas keep clear of every spectacle night", cadenceOk)

-- Tutorial steps speak only events the quest pipeline actually relays.
local relayed = { kill = true, parry = true, ability = true, gold = true, waveClear = true }
local eventsOk = true
for _, s2 in Tutorial.Steps do
	if not relayed[s2.event] then
		eventsOk = false
	end
end
check("the lesson listens only to relayed events", eventsOk)

-- Every deed reads a stat the snapshot actually carries.
local snapFields = { kills = true, bossKills = true, bestWave = true, duelWins = true, raidClears = true, revives = true, trials = true, level = true, playtime = true, deaths = true }
local deedsOk = true
for _, def in Deeds.List do
	if not snapFields[def.kind] then
		deedsOk = false
	end
end
check("every deed reads a real stat", deedsOk)

print(string.format("\n%d passed, %d failed", passed, failed))
if failed > 0 then
	print("FAILURES: " .. table.concat(failures, ", "))
	process.exit(1)
end
