--!strict
-- Headless tests for Seva: the shared stone.

local process = require("@lune/process")
local Seva = require("../src/shared/Seva")

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

print("Seva")

check("there are stones to move", #Seva.Goals >= 4)
check("every stone is whole", (function()
	local kinds = { kills = true, bossKills = true, parries = true, revives = true }
	for _, g in Seva.Goals do
		if not kinds[g.kind] or g.target <= 0 or #g.name == 0 or #g.line == 0 or g.gold <= 0 then
			return false
		end
	end
	return true
end)())
check("the wheel of goals turns", Seva.goalAt(1).id == Seva.Goals[1].id and Seva.goalAt(#Seva.Goals + 1).id == Seva.Goals[1].id)

-- Milestones: quarters only, never the finish, never spam.
check("a quarter speaks", Seva.isMilestone(75, 300))
check("mid-stone stays quiet", not Seva.isMilestone(76, 300))
check("the finish is not a milestone", not Seva.isMilestone(300, 300))
check("zero is silent", not Seva.isMilestone(0, 300))

print(string.format("\n%d passed, %d failed", passed, failed))
if failed > 0 then
	print("FAILURES: " .. table.concat(failures, ", "))
	process.exit(1)
end
