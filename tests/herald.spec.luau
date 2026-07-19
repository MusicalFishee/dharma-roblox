--!strict
-- Headless tests for the Charana's proclamations.

local process = require("@lune/process")
local Herald = require("../src/shared/Herald")

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

print("Herald")

-- Every cry is well-formed, names the warrior, and is worth crying.
local wellFormed = true
local seen = 0
for _, kind in Herald.Order do
	local cry = Herald.Cries[kind]
	if not cry or #cry.color ~= 3 or string.find(cry.template, "%%s") == nil or #cry.template < 20 then
		wellFormed = false
	end
	seen += 1
end
local total = 0
for _ in Herald.Cries do
	total += 1
end
check("every cry names the warrior and is weighty", wellFormed)
check("the order covers every cry once", seen == total)

check("known kinds are known", Herald.isKind("moksha") and Herald.isKind("kailasa"))
check("junk kinds are refused", not Herald.isKind("epic_gamer_moment"))

local text = Herald.proclaim("moksha", "Adi")
check("the proclamation carries the name", text ~= nil and string.find(text :: string, "Adi") ~= nil and string.find(text :: string, "MOKSHA") ~= nil)
check("an unknown kind proclaims nothing", Herald.proclaim("nope", "Adi") == nil)
check("the moksha cry shines near-white", Herald.colorOf("moksha")[1] > 240 and Herald.colorOf("grudge")[1] < 240)

print(string.format("\n%d passed, %d failed", passed, failed))
if failed > 0 then
	print("FAILURES: " .. table.concat(failures, ", "))
	process.exit(1)
end
