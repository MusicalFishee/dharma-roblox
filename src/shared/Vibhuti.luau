--!strict
-- Vibhuti: the sacred marks. Tilaks worn on the brow and auras worn in the
-- air — every one EARNED by deed, none sold, zero power. The flex layer.
-- Pure catalog + unlock + equip gating (Lune-tested); VibhutiService renders.

local Vibhuti = {}

export type UnlockSnapshot = {
	kills: number,
	bossKills: number,
	bestWave: number,
	trials: number,
	duelWins: number,
	raidClears: number,
	revives: number,
}

export type MarkDef = {
	id: string,
	slot: string, -- "tilak" | "aura"
	name: string,
	line: string,
	style: string, -- tilak: "dot" | "lines"; aura: "fire" | "sparkles" | "glow"
	color: { number }, -- {r, g, b}
	unlock: { kind: string, threshold: number, label: string },
}

local function mark(def: MarkDef): MarkDef
	return def
end

Vibhuti.Defs = {
	-- Tilaks (the brow).
	tilak_bhasma = mark({ id = "tilak_bhasma", slot = "tilak", name = "Bhasma Tilak", line = "Ash of the first fire.", style = "dot", color = { 220, 218, 210 }, unlock = { kind = "kills", threshold = 10, label = "Slay 10 demons" } }),
	tilak_kumkuma = mark({ id = "tilak_kumkuma", slot = "tilak", name = "Kumkuma Tilak", line = "Crimson of the war-goddess.", style = "dot", color = { 220, 40, 50 }, unlock = { kind = "kills", threshold = 250, label = "Slay 250 demons" } }),
	tilak_chandana = mark({ id = "tilak_chandana", slot = "tilak", name = "Chandana Tilak", line = "Cooling sandalwood, earned in deep water.", style = "dot", color = { 235, 200, 130 }, unlock = { kind = "bestWave", threshold = 25, label = "Clear wave 25" } }),
	tilak_tripundra = mark({ id = "tilak_tripundra", slot = "tilak", name = "Tripundra", line = "Three lines of ash — His own mark.", style = "lines", color = { 235, 232, 225 }, unlock = { kind = "trials", threshold = 1, label = "Pass the Kirata Trial" } }),
	-- Auras (the air).
	aura_ember = mark({ id = "aura_ember", slot = "aura", name = "Ember Vein", line = "Sparks of every lord you felled.", style = "fire", color = { 255, 140, 40 }, unlock = { kind = "bossKills", threshold = 25, label = "Fell 25 asura lords" } }),
	aura_gale = mark({ id = "aura_gale", slot = "aura", name = "Gale Halo", line = "The air remembers your duels.", style = "sparkles", color = { 200, 235, 255 }, unlock = { kind = "duelWins", threshold = 10, label = "Win 10 duels" } }),
	aura_moon = mark({ id = "aura_moon", slot = "aura", name = "Moonlit Crown", line = "Pale light wrested from Lanka.", style = "glow", color = { 190, 210, 255 }, unlock = { kind = "raidClears", threshold = 1, label = "Fell the Ten-Headed King" } }),
	aura_seva = mark({ id = "aura_seva", slot = "aura", name = "Seva Bloom", line = "Green grace, grown from lifting others.", style = "sparkles", color = { 130, 255, 180 }, unlock = { kind = "revives", threshold = 25, label = "Lift 25 fallen allies" } }),
} :: { [string]: MarkDef }

Vibhuti.Order = { "tilak_bhasma", "tilak_kumkuma", "tilak_chandana", "tilak_tripundra", "aura_ember", "aura_gale", "aura_moon", "aura_seva" }

Vibhuti.Slots = { "tilak", "aura" }

function Vibhuti.get(id: string): MarkDef?
	return Vibhuti.Defs[id]
end

local function statFor(kind: string, snap: UnlockSnapshot): number
	if kind == "kills" then
		return snap.kills
	elseif kind == "bossKills" then
		return snap.bossKills
	elseif kind == "bestWave" then
		return snap.bestWave
	elseif kind == "trials" then
		return snap.trials
	elseif kind == "duelWins" then
		return snap.duelWins
	elseif kind == "raidClears" then
		return snap.raidClears
	elseif kind == "revives" then
		return snap.revives
	end
	return 0
end

function Vibhuti.isUnlocked(id: string, snap: UnlockSnapshot): boolean
	local def = Vibhuti.Defs[id]
	if not def then
		return false
	end
	return statFor(def.unlock.kind, snap) >= def.unlock.threshold
end

export type EquipCheck = {
	ok: boolean,
	reason: string, -- "ok" | "unknown" | "slot" | "locked"
}

-- Gate an equip: a real mark, into its own slot, earned. "" bares the slot.
function Vibhuti.tryEquip(slot: string, id: string, snap: UnlockSnapshot): EquipCheck
	local slotValid = false
	for _, s in Vibhuti.Slots do
		if s == slot then
			slotValid = true
		end
	end
	if not slotValid then
		return { ok = false, reason = "slot" }
	end
	if id == "" then
		return { ok = true, reason = "ok" }
	end
	local def = Vibhuti.Defs[id]
	if not def then
		return { ok = false, reason = "unknown" }
	end
	if def.slot ~= slot then
		return { ok = false, reason = "slot" }
	end
	if not Vibhuti.isUnlocked(id, snap) then
		return { ok = false, reason = "locked" }
	end
	return { ok = true, reason = "ok" }
end

-- The emotes VibhutiService will broadcast (each has a track + a sound, by law).
Vibhuti.Emotes = { "emote_namaste", "emote_warcry", "emote_meditate" }

function Vibhuti.isEmote(id: string): boolean
	for _, e in Vibhuti.Emotes do
		if e == id then
			return true
		end
	end
	return false
end

return Vibhuti
