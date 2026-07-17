--!strict
-- Bhoota: when a warrior dies mid-wave in a team fight, they don't "spectate" —
-- they wander the field as a bhoota, a spirit without a vessel. Translucent,
-- pale-lit, unseen by the horde, unable to touch gold or lift the fallen.
-- When the wave breaks: Punarjanma — the wheel turns, and flesh returns.
-- Deaths between waves (and party wipes) never ghost; the reform handles those.
-- Pure config + gating + every spiritual line (Lune-tested); BhootaService runs it.

local Bhoota = {}

Bhoota.Config = {
	WalkSpeed = 22, -- spirits drift quicker than flesh walks
	Transparency = 0.65, -- how faded the vessel-less look is
	LightColor = { 170, 210, 255 }, -- the pale glow a bhoota carries
	LightRange = 14,
}

-- The words. Death in Dharma speaks the language of the epics, not a lobby.
Bhoota.Lines = {
	-- While you bleed out (the Uddhāra crawl).
	downedTitle = "PRĀṆA FADES",
	downedSub = "Crawl to your brothers — Uddhāra can pull you back   (%ds)",
	-- The moment the body gives out.
	fell = "The body breaks — the ātman endures…",
	-- The wander.
	ghostTitle = "BHOOTA",
	ghostSub = "A spirit without a vessel. Wander — flesh returns when the wave breaks.",
	ghostToast = "You rise from the body as a bhoota — the war goes on without your blade.",
	-- The return.
	reborn = "PUNARJANMA — the wheel turns, and you stand in flesh again",
	-- A ghost reaching for the world.
	graspDenied = "Mist cannot hold gold",
}

-- Does this death lead to the wander? Only when the battle still rages —
-- deaths between waves respawn clean, and a full wipe reforms everyone.
function Bhoota.shouldGhost(battleActive: boolean, fellInBattle: boolean): boolean
	return battleActive and fellInBattle
end

return Bhoota
