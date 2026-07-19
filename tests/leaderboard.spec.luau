--!strict
-- Headless tests for leaderboard defs + score hygiene.

local process = require("@lune/process")
local Leaderboard = require("../src/shared/Leaderboard")

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

print("Leaderboard")

-- Board defs.
check("the lifetime boards still stand (level + wave)", Leaderboard.Boards[1].id == "level" and Leaderboard.Boards[2].id == "wave")
local idsSeen: { [string]: boolean } = {}
local storesSeen: { [string]: boolean } = {}
local defsValid = true
for _, b in Leaderboard.Boards do
	if idsSeen[b.id] or storesSeen[b.storeName] then
		defsValid = false -- duplicates would collide in the DataStore
	end
	idsSeen[b.id] = true
	storesSeen[b.storeName] = true
	if #b.title == 0 or #b.prefix == 0 or #b.storeName == 0 then
		defsValid = false
	end
end
check("board ids + stores unique and non-empty", defsValid)
check("TopN is sensible", Leaderboard.TopN >= 5 and Leaderboard.TopN <= 100)

-- Score hygiene (OrderedDataStore only takes non-negative ints).
check("sanitize junk -> 0", Leaderboard.sanitizeScore("99") == 0 and Leaderboard.sanitizeScore(nil) == 0)
check("sanitize NaN -> 0", Leaderboard.sanitizeScore(0 / 0) == 0)
check("sanitize negative -> 0", Leaderboard.sanitizeScore(-7) == 0)
check("sanitize floors floats", Leaderboard.sanitizeScore(12.9) == 12)
check("sanitize caps at ScoreMax", Leaderboard.sanitizeScore(1e12) == Leaderboard.ScoreMax)

-- Formatting.
local levelBoard = Leaderboard.Boards[1]
local waveBoard = Leaderboard.Boards[2]
check("level values format as Lv N", Leaderboard.formatValue(levelBoard, 12) == "Lv 12")
check("wave values format as Wave N", Leaderboard.formatValue(waveBoard, 8) == "Wave 8")
check("rows format rank, name, value", Leaderboard.formatRow(levelBoard, 1, "Vajra", 12) == "1.  Vajra  —  Lv 12")


-- The weekly board: week-stamped stores, fresh every Monday.
local weeklyDef = nil
for _, def in Leaderboard.Boards do
	if def.id == "weeklyWave" then
		weeklyDef = def
	end
end
check("the weekly board stands among the slabs", weeklyDef ~= nil and (weeklyDef :: any).weekly == true)
check("four boards at the arena's edge", #Leaderboard.Boards == 4)
local ganaDef: Leaderboard.BoardDef? = nil
for _, def in Leaderboard.Boards do
	if def.kind == "gana" then
		ganaDef = def
	end
end
check("the war-ledger is weekly, keyed by banner", ganaDef ~= nil and (ganaDef :: Leaderboard.BoardDef).weekly == true)
check("weekly stores carry the week's stamp", Leaderboard.storeNameFor(weeklyDef :: any, 2951) == "DharmaWeeklyWave_v1_wk2951")
check("different weeks, different stores", Leaderboard.storeNameFor(weeklyDef :: any, 2951) ~= Leaderboard.storeNameFor(weeklyDef :: any, 2952))
check("lifetime boards ignore the week", Leaderboard.storeNameFor(Leaderboard.Boards[1], 2951) == Leaderboard.Boards[1].storeName)

print(string.format("\n%d passed, %d failed", passed, failed))
if failed > 0 then
	print("FAILURES: " .. table.concat(failures, ", "))
	process.exit(1)
end
