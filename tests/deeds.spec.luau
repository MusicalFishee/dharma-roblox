--!strict
-- Headless tests for the Kirti ledger: deed integrity, tier math, progress.

local process = require("@lune/process")
local Deeds = require("../src/shared/Deeds")

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

local function snap(over: { [string]: number }): Deeds.Snapshot
	local s: Deeds.Snapshot = { kills = 0, bossKills = 0, bestWave = 0, duelWins = 0, raidClears = 0, revives = 0, trials = 0, level = 1, playtimeSeconds = 0, deaths = 0, deerKills = 0 }
	for k, v in over do
		(s :: any)[k] = v
	end
	return s
end

print("Deeds")

-- Ledger integrity.
check("the ledger is eleven deeds deep", #Deeds.List == 11)
check("three tiers, three colors", #Deeds.TierNames == 3 and #Deeds.TierColor == 3)
local defsOk = true
local ids: { [string]: boolean } = {}
for _, def in Deeds.List do
	if ids[def.id] or #def.name == 0 or #def.line == 0 or #def.thresholds ~= 3 then
		defsOk = false
	end
	ids[def.id] = true
	if not (def.thresholds[1] < def.thresholds[2] and def.thresholds[2] < def.thresholds[3]) then
		defsOk = false
	end
	local field = if def.kind == "playtime" then "playtimeSeconds" else def.kind
	if Deeds.statFor(def.kind, snap({ [field] = 999999 })) == 0 then
		defsOk = false -- a deed reading an unknown stat can never be earned
	end
end
check("deeds are well-formed with ascending tiers and real stats", defsOk)

-- Tier math.
local slayer = Deeds.List[1]
check("unmarked below the first rung", Deeds.tierFor(slayer, 99) == 0)
check("kansya at the first rung", Deeds.tierFor(slayer, 100) == 1)
check("rajata holds mid-ladder", Deeds.tierFor(slayer, 4999) == 2)
check("svarna at the summit and beyond", Deeds.tierFor(slayer, 5000) == 3 and Deeds.tierFor(slayer, 999999) == 3)

-- Progress.
local p = Deeds.progress(slayer, snap({ kills = 150 }))
check("progress reads the right stat", p.value == 150 and p.tier == 1)
check("progress names the next rung", p.nextThreshold == 1000)
local maxed = Deeds.progress(slayer, snap({ kills = 5000 }))
check("svarna has no next rung", maxed.nextThreshold == nil)

-- The headline count.
check("a fresh ledger is unmarked", Deeds.totalTiers(snap({})) == 0)
local hero = snap({ kills = 5000, bossKills = 200, bestWave = 100, duelWins = 50, raidClears = 25, revives = 50, trials = 10, level = 60, playtimeSeconds = 72000, deaths = 200, deerKills = 100 })
check("a full life fills the ledger", Deeds.totalTiers(hero) == Deeds.MaxTiers)
check("the max is eleven gold deeds", Deeds.MaxTiers == 33)
check("even deaths are honored (the atman remembers)", Deeds.tierFor(Deeds.List[10], 10) == 1)


-- Boundaries and colors.
check("the exact threshold earns the tier", Deeds.tierFor(Deeds.List[1], Deeds.List[1].thresholds[2]) == 2)
local colorsOk = true
for _, c in Deeds.TierColor do
	for _, v in c do
		if type(v) ~= "number" or v < 0 or v > 255 then
			colorsOk = false
		end
	end
end
check("tier colors are honest rgb", colorsOk)
check("half a life fills half-ish a ledger", Deeds.totalTiers(snap({ kills = 1000, bossKills = 50, bestWave = 50, level = 30 })) == 8)
check("an hour of war marks the devoted", Deeds.tierFor(Deeds.List[9], 3600) == 1)

local reachable = true
for _, def in Deeds.List do
	if def.thresholds[3] > 100000 then
		reachable = false -- svarna must be a life's work, not a lifetime's impossibility
	end
end
check("every svarna is humanly reachable", reachable)


-- The bounties: ascending tiers, exact owed math, no double-claims.
check("bounties ascend with the tier", Deeds.TierReward[1] < Deeds.TierReward[2] and Deeds.TierReward[2] < Deeds.TierReward[3])
local slayerDef = Deeds.List[1]
check("nothing earned owes nothing", Deeds.owedFor(slayerDef, 0, 0).gold == 0)
local fresh2 = Deeds.owedFor(slayerDef, 1000, 0)
check("two earned tiers owe both bounties", fresh2.tiers == 2 and fresh2.gold == Deeds.TierReward[1] + Deeds.TierReward[2])
check("claimed tiers never pay twice", Deeds.owedFor(slayerDef, 1000, 2).gold == 0)
local partial = Deeds.owedFor(slayerDef, 5000, 1)
check("a partial claim owes only the rest", partial.tiers == 2 and partial.gold == Deeds.TierReward[2] + Deeds.TierReward[3])
check("junk claim marks clamp", Deeds.owedFor(slayerDef, 5000, 99).gold == 0 and Deeds.owedFor(slayerDef, 100, -5).gold == Deeds.TierReward[1])

print(string.format("\n%d passed, %d failed", passed, failed))
if failed > 0 then
	print("FAILURES: " .. table.concat(failures, ", "))
	process.exit(1)
end
