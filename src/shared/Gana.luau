--!strict
-- Ganas: warbands-lite. A gana is a NAME worn above the head — declare one,
-- match your friends', and you march as one host. No treasury, no officers,
-- no politics: the bond is the banner. Pure name law (Lune-tested);
-- GanaService wears it.

local Gana = {}

Gana.MaxLength = 14

-- Tidy a declared banner: collapse whitespace, trim, cap, keep it printable.
-- Returns "" when nothing readable is left (which means: no gana).
function Gana.cleanName(raw: string): string
	local collapsed = string.gsub(raw, "%s+", " ")
	local name = string.match(collapsed, "^ ?(.-) ?$") or ""
	name = string.sub(name, 1, Gana.MaxLength)
	name = string.match(name, "^(.-) ?$") or ""
	return name
end

-- The ledger key: one banner, one key, whatever the capitalization.
function Gana.storeKey(name: string): string
	return string.lower(Gana.cleanName(name))
end

-- A key back in parade dress for the stone slab.
function Gana.displayName(key: string): string
	local words: { string } = {}
	for word in string.gmatch(key, "%S+") do
		table.insert(words, string.upper(string.sub(word, 1, 1)) .. string.sub(word, 2))
	end
	return table.concat(words, " ")
end

-- Two players march together when their banners match (case-insensitive).
function Gana.sameBanner(a: string, b: string): boolean
	if #a == 0 or #b == 0 then
		return false
	end
	return string.lower(a) == string.lower(b)
end

return Gana
