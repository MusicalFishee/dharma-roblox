--!strict
-- Headless tests for the Dvarapala's greeting.

local process = require("@lune/process")
local Welcome = require("../src/shared/Welcome")

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

print("Welcome")

local function summary(over: { [string]: any }): Welcome.Summary
	local s: Welcome.Summary = { name = "Adi", vairiName = nil, vairiCount = 0, owedYatraGold = 0, owedKirtiGold = 0, owedGranthaGold = 0 }
	for k, v in over do
		(s :: any)[k] = v
	end
	return s
end

local quiet = Welcome.lines(summary({}))
check("a quiet return gets one warm line", #quiet == 1 and string.find(quiet[1], "Adi") ~= nil)

local grudged = Welcome.lines(summary({ vairiName = "Vetala", vairiCount = 3 }))
check("the waiting grudge is named", #grudged == 2 and string.find(grudged[2], "Vetala") ~= nil and string.find(grudged[2], "×3") ~= nil)

local owed = Welcome.lines(summary({ owedYatraGold = 300, owedGranthaGold = 150 }))
check("the ledgers speak their debts", #owed == 2 and string.find(owed[2], "450") ~= nil and string.find(owed[2], "Yatra 300") ~= nil and string.find(owed[2], "Grantha 150") ~= nil)
check("silent ledgers stay silent", string.find(owed[2], "Kirti") == nil)

local everything = Welcome.lines(summary({ vairiName = "Pisacha", vairiCount = 1, owedYatraGold = 100, owedKirtiGold = 200, owedGranthaGold = 150 }))
check("the door never talks past three lines", #everything == Welcome.MaxLines)
check("a bodiless grudge stays unspoken", #Welcome.lines(summary({ vairiName = "" })) == 1)

print(string.format("\n%d passed, %d failed", passed, failed))
if failed > 0 then
	print("FAILURES: " .. table.concat(failures, ", "))
	process.exit(1)
end
