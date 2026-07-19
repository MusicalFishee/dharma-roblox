--!strict
-- THE OUTFITTED-LORD LAW: every boss-lord in the roster must arrive fully
-- dressed — a voice (spawn + fall lines), a signature special that is HIS
-- and not the generic slam, and a treasure set of real relics. A future
-- lord that ships nameless, generic, or empty-handed fails the suite.

local process = require("@lune/process")
local BossLore = require("../src/shared/BossLore")
local Bosses = require("../src/shared/Bosses")
local BossSpecials = require("../src/shared/BossSpecials")
local Relics = require("../src/shared/Relics")

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

print("BossLore")

-- Harvest every lord the wave director can field (the ROSTER is private, so
-- reach them the same way the game does: through the public door).
local lordIds: { [string]: boolean } = {}
for k = 1, 20 do
	lordIds[Bosses.forWave(k * 5, 5).id] = true
end
local lordCount = 0
for _ in lordIds do
	lordCount += 1
end
check("the door yields a full court of lords", lordCount >= 6)

-- A generic-slam sentinel: whatever an unconfigured id gets back.
local genericSlam = BossSpecials.forBoss("__no_such_lord__")

local allVoiced, allArmed, allTreasured = true, true, true
for id in lordIds do
	local lore = BossLore.forBoss(id)
	if not lore or #lore.spawn == 0 or #lore.fall == 0 then
		allVoiced = false
		print("    !! silent lord: " .. id)
	end
	if BossSpecials.forBoss(id) == genericSlam then
		allArmed = false
		print("    !! lord with only the generic slam: " .. id)
	end
	local drops = Relics.dropsFor(id)
	if #drops == 0 then
		allTreasured = false
		print("    !! empty-handed lord: " .. id)
	end
	for _, relicId in drops do
		if not Relics.isValidId(relicId) then
			allTreasured = false
			print("    !! lord drops a phantom relic: " .. id .. " -> " .. relicId)
		end
	end
end
check("every lord has a voice", allVoiced)
check("every lord has his own technique", allArmed)
check("every lord guards real treasure", allTreasured)

-- The lines carry a lord's weight, not a placeholder's.
local weighty = true
for _, lore in BossLore.Lines do
	if #lore.spawn < 20 or #lore.fall < 15 then
		weighty = false
	end
end
check("no line is a placeholder", weighty)
check("unknown names stay lore-less", BossLore.forBoss("Adi") == nil)

print(string.format("\n%d passed, %d failed", passed, failed))
if failed > 0 then
	print("FAILURES: " .. table.concat(failures, ", "))
	process.exit(1)
end
