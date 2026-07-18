--!strict
-- Headless tests for Tarakasura's War-Moon: wave claims, the boon (mortals
-- break, never end), and THE HIERARCHY LAW — Trial > War-Moon > Ravana in
-- every tested number, at every visitation, forever.

local process = require("@lune/process")
local Tarakasura = require("../src/shared/Tarakasura")
local Ravana = require("../src/shared/Ravana")
local Trial = require("../src/shared/Trial")

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

print("Tarakasura")

-- Wave claims.
check("the Moon rises at 150", Tarakasura.isWarMoonWave(150) and Tarakasura.encounterIndex(150) == 1)
check("and every 150th after", Tarakasura.isWarMoonWave(300) and Tarakasura.encounterIndex(300) == 2)
check("no other night is his", not Tarakasura.isWarMoonWave(149) and not Tarakasura.isWarMoonWave(151) and not Tarakasura.isWarMoonWave(50))

-- Every War-Moon night is also a Ravana night (the director checks the Moon
-- first) — and NEVER a Trial night: the god's hour is untouchable.
local risesOverKing = true
local neverTrial = true
for wave = 1, 2000 do
	if Tarakasura.isWarMoonWave(wave) then
		if not Ravana.isRaidWave(wave) then
			risesOverKing = false
		end
		if Trial.isTrialWave(wave) then
			neverTrial = false
		end
	end
end
check("the Moon rises over the king's nights", risesOverKing)
check("the Moon never touches the god's hour", neverTrial)

-- THE HIERARCHY LAW, at every visitation.
local hierarchyHolds = true
for e = 1, 8 do
	if not (Trial.healthFor(e) > Tarakasura.healthFor(e) and Tarakasura.healthFor(e) > Ravana.healthFor(e)) then
		hierarchyHolds = false
	end
	local t, w, r = Trial.rewardFor(e), Tarakasura.rewardFor(e), Ravana.rewardFor(e)
	if not (t.xp > w.xp and w.xp > r.xp) then
		hierarchyHolds = false
	end
	if not (t.shards > w.shards and w.shards > r.shards) then
		hierarchyHolds = false
	end
	if not (t.gold > w.gold) then
		hierarchyHolds = false
	end
end
check("Trial > War-Moon > Ravana, at every visitation", hierarchyHolds)
check("his cruelest blow sits between king and god", Tarakasura.statsForStage(3).meleeDamage > Ravana.statsForStage(Ravana.HeadCount - 1).meleeDamage and Tarakasura.statsForStage(3).meleeDamage < Trial.Phase3.meleeDamage)

-- Stage math.
check("full health is calm", Tarakasura.stageFor(1) == 0)
check("a wounded moon sharpens", Tarakasura.stageFor(0.5) == 1)
check("a furious moon sharpens again", Tarakasura.stageFor(0.2) == 2)
check("the last light enrages", Tarakasura.stageFor(0.1) == 3 and Tarakasura.statsForStage(3).enraged)
check("junk fractions stay calm", Tarakasura.stageFor(0 / 0) == 0)
local growsCrueler = true
for s = 1, 3 do
	local prev, cur = Tarakasura.statsForStage(s - 1), Tarakasura.statsForStage(s)
	if not (cur.meleeDamage > prev.meleeDamage and cur.walkSpeed > prev.walkSpeed and cur.meleeCooldown < prev.meleeCooldown) then
		growsCrueler = false
	end
end
check("every stage is crueler than the last", growsCrueler)

-- The anchors.
check("three chains hold the Moon", Tarakasura.AnchorCount == 3)
check("the chains thicken each return", Tarakasura.anchorHealthFor(2) > Tarakasura.anchorHealthFor(1))

-- The boon: mortals break, the Vel ends.
check("the boon holds — mortals never land the last blow", Tarakasura.BrokenFraction > 0 and Tarakasura.BrokenFraction < 0.15)
check("the Vel takes its time", Tarakasura.VelSeconds >= 1.5)

-- The words are written.
local linesOk = true
for _, key in { "spawn", "anchorDown", "descend", "wounded", "furious", "enrage", "broken", "vel", "defeated", "victory" } do
	if #((Tarakasura.Lines :: any)[key] :: string) == 0 then
		linesOk = false
	end
end
check("every line is written", linesOk)

-- Spoils deepen each visitation.
local r1, r2 = Tarakasura.rewardFor(1), Tarakasura.rewardFor(2)
check("the spoils deepen each return", r2.xp > r1.xp and r2.shards > r1.shards and r2.gold > r1.gold)

print(string.format("\n%d passed, %d failed", passed, failed))
if failed > 0 then
	print("FAILURES: " .. table.concat(failures, ", "))
	process.exit(1)
end
