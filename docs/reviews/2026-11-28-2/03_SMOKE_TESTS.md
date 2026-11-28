# In-client smoke tests — Ka0s Drop Watcher (2026-11-28, second pass)

Headless suites are not repeated here. After the changes land, run the green gate once as a
pre-flight: `lua tests/run.lua`, `KA0S_KIT_CLIENT=forever lua tests/run.lua`,
`~/.claude/dev-copilot/bin/ka0s-bounded luacheck .` and `python3 -m pytest -q tools/seeds`.

## Pre-flight

- Retail 12.1.5 (`## Interface: 120105`) and WoW Forever 1.60.1 (`16001`): run each section on Retail.
  Run the C-003 regression rows on Forever too.
- `/console scriptErrors 1`, plus BugSack/BugGrabber if installed (C-003 reads its report).
- `/dw debug` on, so the `Cfg`/`MSG` lines are visible.
- A target dummy, for combat.

## C-001: the skin notice waits for combat to end (F-001)

- **Setup:** an account that has not recorded the current notice. `/run DropWatcherDB.global.skinNotice = nil`,
  then `/reload` out of combat, and dismiss the picker so the profile has seen it
  (`skin.pickerSeen` true). Then do the same reset again, but this time hit the dummy *before* the
  login fuse fires: `/reload`, and attack within the first seconds.
- **Steps:**
  1. Stay in combat for 20 s or more, watching chat and the screen.
  2. Leave combat.
  3. Repeat the setup, then type `/dw disable` while still in combat, and leave combat.
- **Expected:** (1) no picker in combat, and no `Cfg` line repeating every 5 s. (2) the skin picker
  (the notice) shows once, at combat end. (3) nothing shows, and
  `/dump DropWatcherDB.global.skinNotice` is unchanged from before the fight.
- **Pass/Fail:** pass when all three hold.

## C-002: the golden suite (F-002)

Headless only, nothing in client. The regression rows below cover the verdicts the suite pins.

## C-003: errors keep their stack (F-003)

- **Setup:** BugSack installed.
- **Steps:** make one of GROUP_ROSTER_UPDATE's shared handlers raise for 5 s
  (`OnAskRosterEvent`, `modules/Asks.lua:616`):
  `/run local a=LibStub("AceAddon-3.0"):GetAddon("DropWatcher"); local o=a.OnAskRosterEvent; a.OnAskRosterEvent=function() error("smoke") end; C_Timer.After(5,function() a.OnAskRosterEvent=o end)`,
  then invite someone or leave a party within the 5 s.
- **Expected:** one BugSack entry whose text contains `smoke` *and* a stack naming the handler's
  frame, not only `core/DropWatcher.lua:78`. The other GROUP_ROSTER_UPDATE handlers still ran (the
  roster updates).
- **Pass/Fail:** pass when the stack shows the raising frame.

## C-004: every refusal has words (F-004)

- **Steps:** `/dw test` to turn on test mode, then
  `/run local NS=LibStub("AceAddon-3.0"):GetAddon("DropWatcher"); for _,d in ipairs(NS.LootFeed.Drops("test")) do if NS.Collectibles.IsFeedOnly(d) then NS.PressAsk(d.id) break end end`.
- **Expected:** chat reads `Not asked: Collectibles are judged for you alone.`, never `Not asked: collectible`.
- **Pass/Fail:** pass when the line is worded.

## Cross-addon (F-005: run after the LibKa0s release and LootHistory's re-vendor)

- **Setup:** Drop Watcher and LootHistory both enabled.
- **Steps:** run LootHistory's `diagnostics` verb (its slash root, from `/lh help` or its README), then
  `/dw diagnostics`. Then type each roster addon's slash root and
  confirm it reaches its own addon. Open Settings → AddOns and confirm each addon appears exactly once,
  and each of Drop Watcher's pages once.
- **Expected:** LootHistory's identity header names LibKa0s-Feed-1.0 among the running majors, and Drop
  Watcher's names LibKa0s-Verdict-1.0. With LootHistory on DIAG minor 14, both lists name both majors.
- **Pass/Fail:** pass when each header names its own addon's majors.

## Regression suite

- `/reload` clean, with no Lua error; the `[Init]` summary line prints with `/dw debug` on.
- Fresh SavedVariables (`DropWatcherDB = nil`, `/reload`): defaults populate, the picker shows once
  after the login delay, and the schema stamp reads 19 (`/dump DropWatcherDB.global.schemaVersion`).
- Combat enter and leave with the window open: test mode ends on combat start, and the window follows
  General › visibility.
- `/dw disable` then `/dw enable`: the window and launcher behave as slash-commands-§7 describes, and
  `/dw config` and the bare `/dw` still answer while disabled.
- Profile switch, copy and reset: the skin re-applies and no picker shows on a profile that has seen it.
- A dungeon run, or `/dw sim start` in a city: drops list with verdicts, and the Ask, Offer and
  Announce buttons send or queue (sim: printed `[sim]` lines only).

## Sign-off

| ID | Tested? | Pass/Fail | Notes |
|---|---|---|---|
| C-001 | | | |
| C-002 | headless | | |
| C-003 | | | |
| C-004 | | | |
| F-005 (cross-addon) | | | |
| Regression | | | |
