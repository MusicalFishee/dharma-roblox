--!strict
-- Input badges: how each duelist plays — pad, keys, or thumbs — shown Rivals-
-- style as one tiny glyph. Minimal by design: glimpsed once, never studied;
-- the battlefield stays the main thing. (Xbox and PlayStation share the pad
-- glyph: Roblox exposes no controller brand, only the class.)
-- Pure classification + glyphs (Lune-tested); clients report, PvP displays.

local InputBadge = {}

InputBadge.Methods = { "keyboard", "gamepad", "touch" }

InputBadge.Glyph = {
	keyboard = "⌨",
	gamepad = "🎮",
	touch = "📱",
} :: { [string]: string }

-- Classify a UserInputType NAME into a method ("" = not an input we track,
-- e.g. Focus/TextInput noise — the reporter ignores those).
function InputBadge.classify(inputTypeName: string): string
	if string.find(inputTypeName, "^Gamepad") then
		return "gamepad"
	end
	if inputTypeName == "Touch" then
		return "touch"
	end
	if inputTypeName == "Keyboard" or string.find(inputTypeName, "^Mouse") then
		return "keyboard"
	end
	return ""
end

function InputBadge.valid(method: string): boolean
	for _, m in InputBadge.Methods do
		if m == method then
			return true
		end
	end
	return false
end

-- The glyph for a method; unknown methods show nothing at all.
function InputBadge.glyphFor(method: string): string
	return InputBadge.Glyph[method] or ""
end

return InputBadge
