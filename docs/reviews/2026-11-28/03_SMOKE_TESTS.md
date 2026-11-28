# 03 — Smoke tests (in-client)

**Headless pre-flight**, to run once after the changes land. It is not repeated below.

`lua tests/run.lua`, `KA0S_KIT_CLIENT=forever lua tests/run.lua`, `~/.claude/dev-copilot/bin/ka0s-bounded luacheck .` and `python3 -m pytest -q tools/seeds`. All must report 0 failed and 0/0.

## Pre-flight (client)

- Run two clients: Retail (`## Interface: 120105`) and WoW Forever (`16001`). Use a level-capped character with a full gear set and one with an empty slot.
- Type `/console scriptErrors 1`, then `/reload`.
- Install the branch build of Drop Watcher alone first, then together with the branch build of Ka0s Item Search (Forever) and Ka0s Loot History.

## Per-change tests

### C-01: the narrowed pre-tag shim

Headless only; no in-client step.

### C-02: explicit read set

- **Setup:** Retail, in a dungeon group (or `/dw test`).
- **Steps:**
  1. `/dw sim start` and let a run play.
  2. Pick up a drop in the sim.
  3. Swap a worn ring.
- **Expected:** every sim drop gets a Me verdict (not `unknown`). Swapping the ring re-judges the live drops (DropUpdated `gear`). No Lua error appears.
- **Pass:** all three hold on both clients.

### C-03 and C-04: golden suite

Headless only.

### C-05: seed tool

Headless only.

### C-06 and C-07: view cleanup

- **Steps:** `/dw diagnostics`.
- **Expected:** the gear and scorer lines print as before, with no `nil` method errors.
- **Pass:** no error popup.

### C-08: perf gate

- **Steps:**
  1. `/dw perf` two-arm capture: the clean arm first, then the suspended arm, with no `/reload` between.
  2. Equip and unequip an item 5 times in each arm.
- **Expected:** the report lists `gear.rebuild` with a bucket figure in the clean arm.
- **Pass:** the bucket is present and non-zero. Record it as a `docs/perf-analysis/<stamp>/` bundle through `/dev-copilot:wow-perf-analysis`. Read bucket figures, not the frame-time delta.

### C-09: enable order

- **Steps:**
  1. `/dw disable`, then `/reload`.
  2. Esc → Options → AddOns → Ka0s Drop Watcher.
  3. `/dw enable`.
- **Expected:** the panel opens while disabled. Enable restores the window and the verdicts.
- **Pass:** both hold.

## Item Search cut (branch-level regression)

1. **WoW Forever, Drop Watcher alone.**
   1. Hover any bag item: the tooltip has **no** Drop Watcher block or badge.
   2. The main window's title bar has **no** magnifier.
   3. `/dw search` answers as an unknown verb (the dispatcher's usage line).
   4. Options → Keybindings → Ka0s Drop Watcher lists **one** binding, *Toggle drop feed*.
   5. Settings has no Item Search page.
2. **SavedVariables.** Use a profile that was used with a pre-split dev build. After `/reload` and `/logout`, open `WTF/Account/<acct>/SavedVariables/DropWatcher.lua`.
   - **Expected:** no `itemSearch` key under `global`, under any `char.*` or under any `profiles.*`. `schemaVersion = 19`.
3. **Comparison page** (both clients). Settings → Comparison shows Scoring's four rows plus the Weights and Unwanted types tabs. Set a weight, `/reload`, and the weight persists. A Pawn import (`/dw` → Weights → import) prints one tagged line.

## Cross-addon (owed even though the source greps are clean)

1. Load Drop Watcher, Ka0s Item Search and Ka0s Loot History together (branch builds).
2. Type `/dw`, `/dropwatcher`, `/is` and `/lh`, `/loothistory`. Each reaches its own addon.
3. Settings → AddOns: each addon appears exactly once, and each of Drop Watcher's pages appears once.
4. **F-001 repro:** run `/dw diagnostics` and Loot History's diagnostics. Read the identity header's major list in each.
   - **Expected today (the defect):** one of the two leaves out `Verdict` or `Feed`.
   - **After the renumbered re-vendor:** both list both.
5. **Verdict agreement (F-003):** on Forever, hover one gear item that Item Search judges and Drop Watcher has as a live drop. The two verdict words agree.

## Regression

- `/reload` is clean.
- A fresh profile gets first-time defaults (the skin picker appears once).
- ADDON_LOADED → PLAYER_LOGIN → PLAYER_ENTERING_WORLD with no errors.
- Enter and leave combat with the window shown. Loot a drop in combat: it is judged after combat (the bag defer).
- Switch profiles with AceDB (`/dw` → Profiles). The incoming profile's Comparison values are read.
- Toggle every option on the Comparison page at least once.
- `/dw disable`, then enter combat: no chat line, no window, no SavedVariables write. Then `/dw enable`.

## Sign-off

| ID | Tested? | Pass/Fail | Notes |
|---|---|---|---|
| C-01 | | | headless |
| C-02 | | | |
| C-03 | | | headless |
| C-04 | | | headless |
| C-05 | | | headless |
| C-06 | | | |
| C-07 | | | headless |
| C-08 | | | |
| C-09 | | | |
| C-10 | | | comment only |
| Item Search cut | | | |
| Cross-addon | | | |
