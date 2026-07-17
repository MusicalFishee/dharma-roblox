--!strict
-- Gamepad bindings: one humane layout, no chords, no extra buttons.
-- KeyCodes are stored as STRINGS (Enum isn't available in Lune); the client
-- resolves Enum.KeyCode[name]. Prompts render via GetImageForKeyCode, which
-- serves Xbox glyphs on Xbox and PlayStation glyphs on PlayStation — each
-- console sees its own controls, automatically.
--
-- On Nintendo controllers, per the studio head's decree: no ban is needed.
-- Roblox does not run on Nintendo hardware, so the doorman upstream already
-- enforces it. Adi's law stands, effortlessly.

local Gamepad = {}

export type Bind = {
	action: string, -- "attack" | "block" | "dodge" | "ability" | "menu"
	button: string, -- Enum.KeyCode name
	slot: string?, -- ability binds carry their Z/X/C/V slot
	label: string, -- what the hint bar calls it
}

Gamepad.Binds = {
	{ action = "attack", button = "ButtonR2", label = "Strike" },
	{ action = "block", button = "ButtonL2", label = "Block (hold)" },
	{ action = "dodge", button = "ButtonB", label = "Dodge" },
	{ action = "ability", button = "DPadLeft", slot = "Z", label = "Astra Z" },
	{ action = "ability", button = "DPadUp", slot = "X", label = "Astra X" },
	{ action = "ability", button = "DPadRight", slot = "C", label = "Astra C" },
	{ action = "ability", button = "DPadDown", slot = "V", label = "Astra V" },
	{ action = "menu", button = "ButtonY", label = "Menu" },
} :: { Bind }

return Gamepad
