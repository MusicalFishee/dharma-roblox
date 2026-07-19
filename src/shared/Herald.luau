--!strict
-- The Charana: the bard who cries a warrior's greatest deeds across the whole
-- server. Only the rare, cross-session-legendary moments earn a herald — a
-- golden banner every soul online sees at once — so the endgame is aspirational
-- for everyone watching. Pure proclamation catalog (Lune-tested); HeraldService
-- dedupes per session and broadcasts.

local Herald = {}

export type Cry = {
	template: string, -- one %s for the warrior's name
	color: { number },
}

Herald.Cries = {
	moksha = { template = "%s has ATTAINED MOKSHA — released from the wheel, one with Brahman.", color = { 255, 252, 245 } },
	kailasa = { template = "%s has reached the Threshold of Kailasa.", color = { 190, 210, 255 } },
	loremaster = { template = "%s has completed the Ripu-Grantha — the whole book of foes.", color = { 210, 180, 130 } },
	grudge = { template = "%s has broken a grudge that would not die.", color = { 220, 90, 120 } },
	grandmaster = { template = "%s has mastered three blades to the summit.", color = { 235, 240, 250 } },
} :: { [string]: Cry }

Herald.Order = { "moksha", "kailasa", "loremaster", "grandmaster", "grudge" }

function Herald.isKind(kind: string): boolean
	return Herald.Cries[kind] ~= nil
end

-- The banner text for a herald (nil for an unknown kind).
function Herald.proclaim(kind: string, warriorName: string): string?
	local cry = Herald.Cries[kind]
	if not cry then
		return nil
	end
	return string.format(cry.template, warriorName)
end

function Herald.colorOf(kind: string): { number }
	local cry = Herald.Cries[kind]
	return if cry then cry.color else { 255, 255, 255 }
end

return Herald
