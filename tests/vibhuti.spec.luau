--!strict
-- Headless tests for Vibhuti: the mark catalog, unlock gates, equip gating,
-- and the emote contract (every emote has a track AND a sound — no silent
-- gestures, no invisible ones).

local process = require("@lune/process")
local Vibhuti = require("../src/shared/Vibhuti")
local AnimationDefs = require("../src/shared/AnimationDefs")
local SoundDefs = require("../src/shared/SoundDefs")

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

local function snap(over: { [string]: number }): Vibhuti.UnlockSnapshot
	local s: Vibhuti.UnlockSnapshot = { kills = 0, bossKills = 0, bestWave = 0, trials = 0, duelWins = 0, raidClears = 0, revives = 0 }
	for k, v in over do
		(s :: any)[k] = v
	end
	return s
end

print("Vibhuti")

-- Catalog integrity.
local slots = { tilak = true, aura = true }
local styles = { dot = true, lines = true, fire = true, sparkles = true, glow = true }
local defsOk = true
local orderSeen: { [string]: boolean } = {}
for _, id in Vibhuti.Order do
	local def = Vibhuti.Defs[id]
	if not def or def.id ~= id or orderSeen[id] or not slots[def.slot] or not styles[def.style] then
		defsOk = false
	end
	orderSeen[id] = true
	if #def.name == 0 or #def.line == 0 or #def.color ~= 3 or #def.unlock.label == 0 or def.unlock.threshold <= 0 then
		defsOk = false
	end
end
local defCount = 0
for _ in Vibhuti.Defs do
	defCount += 1
end
check("marks are well-formed", defsOk)
check("order covers every mark once", defCount == #Vibhuti.Order)

-- Both slots have wares; nothing is free (every mark is a deed).
local tilaks, auras = 0, 0
for _, id in Vibhuti.Order do
	if Vibhuti.Defs[id].slot == "tilak" then
		tilaks += 1
	else
		auras += 1
	end
end
check("four tilaks, four auras", tilaks == 4 and auras == 4)

-- Unlock gates, one per kind used.
check("bhasma waits for first blood", not Vibhuti.isUnlocked("tilak_bhasma", snap({})) and Vibhuti.isUnlocked("tilak_bhasma", snap({ kills = 10 })))
check("chandana waits for the deep", Vibhuti.isUnlocked("tilak_chandana", snap({ bestWave = 25 })) and not Vibhuti.isUnlocked("tilak_chandana", snap({ bestWave = 24 })))
check("tripundra answers the trial", Vibhuti.isUnlocked("tilak_tripundra", snap({ trials = 1 })))
check("the moonlit crown demands the king", not Vibhuti.isUnlocked("aura_moon", snap({ bossKills = 999 })) and Vibhuti.isUnlocked("aura_moon", snap({ raidClears = 1 })))
check("seva bloom honors the lifter", Vibhuti.isUnlocked("aura_seva", snap({ revives = 25 })))
check("junk marks are never earned", not Vibhuti.isUnlocked("halo_of_hax", snap({ kills = 999999 })))

-- Equip gating.
check("an earned mark wears in its slot", Vibhuti.tryEquip("tilak", "tilak_bhasma", snap({ kills = 10 })).ok)
check("a locked mark refuses the brow", Vibhuti.tryEquip("tilak", "tilak_kumkuma", snap({ kills = 10 })).reason == "locked")
check("a tilak cannot ride the air", Vibhuti.tryEquip("aura", "tilak_bhasma", snap({ kills = 999 })).reason == "slot")
check("bare slots are always allowed", Vibhuti.tryEquip("tilak", "", snap({})).ok and Vibhuti.tryEquip("aura", "", snap({})).ok)
check("unknown slots are refused", not Vibhuti.tryEquip("crown", "tilak_bhasma", snap({ kills = 999 })).ok)
check("unknown marks are refused", Vibhuti.tryEquip("aura", "halo_of_hax", snap({})).reason == "unknown")

-- The emote contract: every emote has a track and a sound.
check("six emotes", #Vibhuti.Emotes == 6)
local emotesOk = true
for _, id in Vibhuti.Emotes do
	if not Vibhuti.isEmote(id) then
		emotesOk = false
	end
	if not AnimationDefs.Tracks[id] then
		emotesOk = false
		print("    !! emote has no track: " .. id)
	end
	if not SoundDefs.AnimSounds[id] then
		emotesOk = false
		print("    !! emote has no sound: " .. id)
	end
end
check("every emote has a track and a voice", emotesOk)
check("meditation is a held pose", (AnimationDefs.Tracks.emote_meditate :: any).hold == true)
check("non-emotes are refused", not Vibhuti.isEmote("emote_floss"))

print(string.format("\n%d passed, %d failed", passed, failed))
if failed > 0 then
	print("FAILURES: " .. table.concat(failures, ", "))
	process.exit(1)
end
