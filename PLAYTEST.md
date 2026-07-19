# Dharma — London Playtest Checklist

Everything below was built and tested headless (1300+ Lune checks), but none of
it has been *felt* in Studio yet. This is the tour, in the order a real session
meets it. Tick things off; anything that feels wrong, note the wave number and
what you expected.

**Before anything:** `./check.sh` must pass, then open `Dharma.rbxl`
(rebuild with `rojo build -o Dharma.rbxl` if stale). Test with 2+ players
(Studio: Test → Clients and Servers) — half the game is social.

**Tip for reaching deep waves fast:** temporarily lower thresholds in the
shared defs (e.g. `Zones.List` thresholds, `Tarakasura.FirstWave = 6`,
`Trial.FirstWave`) — they're pure data. REVERT BEFORE PUBLISHING; the specs
will catch you if you forget (hierarchy/coverage laws pin the real numbers).

---

## First minutes
- [ ] Spawn: tutorial (Adhyaya 0) fires once, never repeats on rejoin
- [ ] Dvarapala greeting ~6s after join: "Welcome back to the war, …" (+ owed
      gold lines if any ledgers owe; + vairi line if a grudge is held)
- [ ] Starter weapon choice prompts exactly once; armory (O) shows all 9 rows
      with mastery standing beside each signature ("Shishya (0 / 100)")
- [ ] HUD: Tejas bar, XP bar, gold, stance chip bottom-right ("◈ SAMA")

## Core combat
- [ ] LMB combo chain; heavy finisher lands harder (sound pitch climbs)
- [ ] Shift block, perfect parry → "PERFECT PARRY — RIPOSTE!" + parry ring +
      next hit guaranteed crit
- [ ] Q dodge i-frames (dash through a telegraphed blast)
- [ ] Tab (or tap the chip) cycles stances: Sama → Raudra → Sthira → Pravaha;
      toast + unsheath sound each turn; damage numbers visibly shift
- [ ] Z/X/C/V Astras; HOLD Z then release: "CHARGED —" / "OVERCHARGED —"
      prefix at half/full draw; a tap is identical to before
- [ ] Typing 'z' in a panel TextBox does NOT cast on key-up

## The training yard (Akhada, ~(34, -34) by spawn)
- [ ] Dummy takes all damage; billboard shows YOUR name, 10s damage, DPS,
      live string
- [ ] Break a 5+ hit string → "STRING — n hits · total · best · s" toast
- [ ] "TODAY'S FIERCEST" post ranks session-best DPS (top 5)
- [ ] Ring the bell → Sparring Rakshasa: parry staggers it, its death pays
      NOTHING (no kill stat, no grantha ink, no vira)

## Waves & the world
- [ ] Wave rhythm: 5s bosses (war-drums start/stop), 7s doshas, 3s wheels
- [ ] Wave 13/23/…: CHAKRAVYUHA — spiral spawn around the Vyuha-Pati; kill the
      axis → all bound ranks stagger 4s + bounty toast + glass-shatter sound
- [ ] Zone hazards from Dandakaranya on (never in ashram waves 1–14): danger
      circles telegraph ≥1.5s; dash escapes clean, block halves
- [ ] Tirtha stone each ordinary wave (wandering spot): touch once → zone
      blessing toast; second touch same wave denied
- [ ] Rahu's Eclipse (7% past wave 20 — force by raising `Rahu.Config.Chance`
      temporarily): sky goes black-crimson, horde gilded, wave pays double,
      sun returns next wave
- [ ] Naga family arrives at 30 (venom), Hima at 60 (chill slows your legs —
      and a relic equip mid-chill must NOT unfreeze you early)

## Death & the spirit world
- [ ] Downed → crawl, ally lifts you (Uddhāra prompt)
- [ ] Full death mid-wave → BHOOTA ghost + spectate-cam (←/→ cycles fighters,
      camera comes home on revive); death text is spiritual, never lobby-speak
- [ ] A ghat flame appears where you fell; an ally pays tribute → +Tejas once
- [ ] The demon that downed you → "A VAIRI IS BORN" toast; on a later
      ordinary wave it returns: "…, Bane of <you>" (elite, bigger). YOUR kill
      clears it + pays; a friend's kill → "the grudge stands"; dying to it
      again → it grows

## Spectacles (force wave numbers to test)
- [ ] Wave 25: Kirata Trial — 3 phases, ends in a BLESSING (never a corpse)
- [ ] Wave 50: Ravana — ten heads sever at health tenths, taunts, enrage on
      the last; guaranteed mythic on victory
- [ ] Wave 150: WAR-MOON — Tarakasura hovers untouchable; shatter 3 anchors
      (glass sound, guards spawn); he descends; batter him below 8% → he
      KNEELS laughing → the Vel falls → victory. Mortals never land the
      last blow (try overkilling — the Vel still takes the ending)
- [ ] Golden deer festival: your 10th lifetime deer TEARS OPEN → Maricha
      Revealed (kiting archer boss)

## Panels (letters + drawers must match)
- [ ] All 17 panels open from keys AND touch/gamepad drawers: B N M H O Y U
      J K I L P T G F R ; — each shows live data on open
- [ ] Kirti (H): 11 deeds incl. "The Golden Hunt"; CLAIM buttons pay once
- [ ] Grantha (;): 9 family pages, lore reveals per tier, claims pay
- [ ] Yatra (F): steps light by level; one CLAIM sweeps all owed
- [ ] Loadouts (L): save current gear, APPLY swaps weapon+relics (never path)
- [ ] Gana (R): banner over head; matching banners muster; war-ledger slab
      (4th stone) fills weekly; weekly-wave slab resets Mondays
- [ ] PvP (G): duels work; JOIN KUMBHA with 4 players → semis → final →
      champion purse; a rage-quit forfeits by walkover

## AFK & social
- [ ] Dhyana grove: forced meditation pose, scarce drip, friend-multiplied
      (real friends only, level 15+), NO wave rewards leak to meditators
- [ ] Seva stone: server-wide goal progresses from everyone; completion pays
      all online + wheel turns
- [ ] Input badges in duels: tiny ⌨/🎮/📱 per fighter — glanceable, small

## Controllers
- [ ] Xbox pad → Xbox glyphs; PlayStation pad → PS glyphs; drawer covers all
      panels; charged Astras NOT expected on pad (tap only)

## Sound sweep
- [ ] Every big moment speaks: eclipse/vairi (bass), anchors/wheel (glass),
      Vel (heavy impact), tirtha (water), claims (coins), stance (unsheath),
      mastery rank (level ping)

## Monetization (after publish only)
- [ ] Paste real product ids into `src/shared/Products.luau` (currently 0)
- [ ] Buy each currency pack in a real client; ledger blocks double-grants

## If something breaks
Note: wave number, zone, what you pressed, what you expected. Server output
(F9) prints every service's boot line — a missing "[Dharma] X ready" line
means a require failed. `./check.sh` locally reproduces all logic laws.
