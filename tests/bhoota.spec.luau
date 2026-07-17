--!strict
-- Headless tests for the bhoota wander: config sanity, the ghost gate,
-- and every spiritual line (a missing line = a silent, English-flavored beat).

local process = require("@lune/process")
local Bhoota = require("../src/shared/Bhoota")

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

print("Bhoota")

-- Config sanity.
local cfg = Bhoota.Config
check("spirits drift quicker than flesh", cfg.WalkSpeed > 16)
check("the vessel-less look is faded but visible", cfg.Transparency > 0.3 and cfg.Transparency < 1)
check("the pale glow is a real color", #cfg.LightColor == 3 and cfg.LightRange > 0)

-- Every line exists and speaks.
local lineKeys = { "downedTitle", "downedSub", "fell", "ghostTitle", "ghostSub", "ghostToast", "reborn", "graspDenied" }
local allLines = true
for _, key in lineKeys do
	local line = (Bhoota.Lines :: any)[key]
	if type(line) ~= "string" or #line == 0 then
		allLines = false
		print("    !! missing line: " .. key)
	end
end
check("every spiritual beat has its line", allLines)
check("the countdown line takes the seconds", string.find(Bhoota.Lines.downedSub, "%%d") ~= nil)
check("no lobby-speak survives", string.find(Bhoota.Lines.ghostSub:lower(), "spectat") == nil and string.find(Bhoota.Lines.fell:lower(), "you died") == nil)

-- The ghost gate: only mid-battle deaths wander.
check("a mid-battle death wanders", Bhoota.shouldGhost(true, true) == true)
check("an intermission death respawns clean", Bhoota.shouldGhost(false, true) == false)
check("the living never ghost", Bhoota.shouldGhost(true, false) == false)
check("quiet fields hold no ghosts", Bhoota.shouldGhost(false, false) == false)

print(string.format("\n%d passed, %d failed", passed, failed))
if failed > 0 then
	print("FAILURES: " .. table.concat(failures, ", "))
	process.exit(1)
end
