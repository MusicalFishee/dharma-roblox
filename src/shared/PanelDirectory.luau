--!strict
-- The panel directory: every letter-key panel, as data — shared by the touch
-- drawer and the gamepad drawer so neither ever drifts from the other.
-- `remote`/`payloadAction` name the info request fired when a panel opens.

local PanelDirectory = {}

export type Entry = {
	label: string,
	gui: string, -- the panel's ScreenGui.Name
	remote: string?, -- Net remote to fire on open (nil = none needed)
	payloadAction: string?,
}

PanelDirectory.Entries = {
	{ label = "Shop", gui = "DharmaShop", remote = "ShopRequest", payloadAction = "info" },
	{ label = "Altar", gui = "DharmaAltar", remote = "EnchantRequest", payloadAction = "info" },
	{ label = "Paths", gui = "DharmaPathSelect", remote = "PathRequest", payloadAction = "info" },
	{ label = "Relics", gui = "DharmaRelics", remote = "RelicRequest", payloadAction = "info" },
	{ label = "Armory", gui = "DharmaArmory", remote = "StatsRequest", payloadAction = "info" },
	{ label = "Stats", gui = "DharmaStats", remote = "StatsRequest", payloadAction = "info" },
	{ label = "Kirti", gui = "DharmaKirti", remote = "KirtiRequest", payloadAction = "info" },
	{ label = "Titles", gui = "DharmaTitles", remote = "TitleRequest", payloadAction = "list" },
	{ label = "Duels", gui = "DharmaPvP", remote = "PvPRequest", payloadAction = "list" },
	{ label = "Story", gui = "DharmaStory", remote = "StoryRequest", payloadAction = "info" },
	{ label = "Rites", gui = "DharmaRites", remote = "RitesRequest", payloadAction = "info" },
	{ label = "Marks", gui = "DharmaVibhuti", remote = "VibhutiRequest", payloadAction = "info" },
	{ label = "Bazaar", gui = "DharmaBazaar" },
} :: { Entry }

return PanelDirectory
