# Dharma (Roblox)

Action-adventure set in sacred ancient India — Roblox edition. Authored as files with
[Rojo](https://rojo.space), gameplay logic verified headlessly with [Lune](https://lune-org.github.io/docs).

## Layout
```
src/shared/   -> ReplicatedStorage.Shared   (pure logic, engine-agnostic modules)
src/server/   -> ServerScriptService.Server  (world, combat authority)
src/client/   -> StarterPlayerScripts.Client (input, camera, HUD)
tests/        -> Lune specs (run outside Roblox)
```

## Commands (run from this folder)
```bash
lune run tests/combat.spec     # headless logic tests — no Roblox needed
rojo build -o Dharma.rbxl      # produce a place file to open in Studio
rojo serve                     # live-sync into Studio via the Rojo plugin
```

## First look (MacBook / Studio)
1. Open Roblox Studio, install the **Rojo** plugin (Plugins → Manage → search "Rojo").
2. On the Fedora laptop: `rojo serve` (same folder as this README).
3. In Studio: open the Rojo plugin → **Connect** (same Wi-Fi), or just open a fresh
   baseplate and Connect.
4. Press **Play**. You spawn in the arena; the Output window shows the `[Dharma]` logs.

Quick alternative with zero Rojo on the Mac: copy `Dharma.rbxl` over and double-click it.
