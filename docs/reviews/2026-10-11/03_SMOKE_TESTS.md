# Smoke tests: Ka0s Drop Watcher v1 review (2026-10-11)

In-client checks for the changes in `02_PROPOSED_CHANGES.md`. These are the owner's to run. Nothing
here is marked passed by an agent. The lasting copies are TOAST-2 and ASK-9 in `docs/smoke-tests.md`.

## Pre-flight

- Retail client, `## Interface: 120100`. The game loads `GIT/DropWatcher` through its symlink: test
  from the main checkout, never from a side worktree.
- Re-run `lua tests/run.lua` and `luacheck .` once after the changes land (headless; already green
  in the commits).
- `/console scriptErrors 1`, then `/reload`. `/dw debug on` for the auto-ask and scorer checks.
- Settings › Window › Toast › **Show a toast** on, **Least gain** 10.

## C-01..C-04: the toast follows its drop and its switch (F-001, F-004)

- **Setup:** toast on, not in combat.
- **Steps:**
  - `/dw test`. A test drop's toast appears; it stays, since a test toast has no countdown.
  - Untick Settings › Window › Toast › **Show a toast**.
  - Tick it again, then `/dw test` twice (off, then on) to get a toast back.
  - On the Group drops tab, click the toasted drop's row ×.
  - Turn test mode off. In a group, `/dw add <an item link for a slot you would upgrade> <member>`
    with toasts on, so a live toast appears, then type `/dw clear` while it shows.
  - Repeat the `/dw add`, then switch to a profile with **Show a toast** off (Settings › Profiles).
- **Expected:** each of the untick, the row ×, `/dw clear` and the profile switch takes the toast
  off screen at once, and no other toast takes its place. No Lua error.
- **Pass / Fail:** pass when the toast disappears on each of the four actions and never shows a
  button for a drop that is gone or dismissed.

## C-05: an empty slot qualifies (F-002)

- **Setup:** a character with one empty equippable slot (take off a ring), toast on, in a group.
- **Steps:** `/dw add <a ring link> <member>`. The trade estimate must be `likely` or `yes` (a BoE
  ring is `yes`).
- **Expected:** a toast reading `Looted by <member> · empty ▲ · Tradeable` (or `Likely tradeable`).
- **Pass / Fail:** pass when the toast appears and its line reads `empty`, not `+0`.

## C-06: Pawn counts once it is initialized (F-003)

- **Setup:** Pawn installed, Settings › Comparison › Scoring › Scorer on Automatic, and weights
  entered for your spec.
- **Steps:** `/reload`, then type `/dw diagnostics` at once and look at the Scoring section. Wait 10
  seconds and type it again.
- **Expected:** the scorer in use reads `pawn` only once Pawn reports `ready=true`. Before that it
  reads `weights`. With Pawn disabled it reads `weights` throughout.
- **Pass / Fail:** pass when the report never pairs `pawn` with `ready=false`.

## C-07: auto-ask lets go after leaving an encounter (F-005)

- **Setup:** auto-ask on (Settings › Messages › Auto-ask), in a dungeon group, `/dw debug on`.
- **Steps:** pull a boss so `ENCOUNTER_START` fires, then hearth out (or release and run out) before
  it ends. After the loading screen, have a group member loot a likely tradeable upgrade for you (or
  `/dw add` one naming them).
- **Expected:** the debug console shows the auto-ask scheduled and, after the delay, sent. It is not
  held by an encounter you are no longer in. `/dw diagnostics` shows auto-ask `inEncounter=false`.
- **Pass / Fail:** pass when the ask fires after the delay without a later boss or a `/reload`.

## C-08: the confirmations (F-006)

- **Steps:** History tab › **Clear history**, then **No**. Settings › General › **Defaults**, then
  **No**.
- **Expected:** both dialogs show, and **No** changes nothing. No "Interface action failed" line.
- **Pass / Fail:** pass when both behave as before.

## Regression suite

- `/reload` cleanly with no Lua error. ADDON_LOADED, PLAYER_LOGIN and PLAYER_ENTERING_WORLD complete
  without error.
- `/dw disable`, then `/dw enable`: no toast, and no auto-ask while disabled. Test mode cannot start
  while disabled.
- Combat: with a toast up, enter combat. The toast hides and returns after combat. Test mode ends on
  combat.
- Profile switch with auto-ask on in one profile and off in the other: waiting asks are dropped on
  the switch to off.

## Sign-off

| ID | Tested? | Pass/Fail | Notes |
|---|---|---|---|
| C-01..C-04 | | | |
| C-05 | | | |
| C-06 | | | |
| C-07 | | | |
| C-08 | | | |
