--!strict
-- Headless tests for Ganas: the banner law.

local process = require("@lune/process")
local Gana = require("../src/shared/Gana")

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

print("Gana")

check("banners stay short", Gana.MaxLength <= 16)
check("names are trimmed and collapsed", Gana.cleanName("  Vira   Sena  ") == "Vira Sena")
check("long banners are cut", #Gana.cleanName(string.rep("a", 99)) == Gana.MaxLength)
check("nothing readable means no gana", Gana.cleanName("   ") == "")

check("matching banners march together", Gana.sameBanner("Vira Sena", "vira sena"))
check("different banners do not", not Gana.sameBanner("Vira Sena", "Nandi"))
check("the bannerless march alone", not Gana.sameBanner("", "") and not Gana.sameBanner("Vira", ""))

print(string.format("\n%d passed, %d failed", passed, failed))
if failed > 0 then
	print("FAILURES: " .. table.concat(failures, ", "))
	process.exit(1)
end
