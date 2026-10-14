# In-client smoke tests: Ka0s Drop Watcher review (2026-10-14)

These are the checks only a logged-in client can make, run after `02_PROPOSED_CHANGES.md` lands.
The headless suites were already run in `01_FINDINGS.md`'s measurement block. After the changes,
re-run `lua tests/run.lua` and `luacheck .` once (expect `1410` passed, 0 failed, 1 skipped, and 0/0)
before logging in.

## Pre-flight

- Retail client at `## Interface: 120100`. Install the branch build as `Interface/AddOns/DropWatcher`.
- `/console scriptErrors 1`. If BugSack is installed, clear it.
- You need a second character, or a friend, for group checks, and a premade 5-man group for ANN-1b.
- Run `/dw debug on`, so the `MSG`, `Init` and `Set` tags show what each step did.

## Per-change tests

### C-01: disabled 3 drives every handler (test-only)
- **Change covered:** C-01, the vacuous case made falsifiable.
- **Setup:** none in client. This change has no in-game surface.
- **Steps:** 1. `/dw disable`. 2. Enter combat with a training dummy, leave combat, then
  travel to another zone (a city) without reloading.
- **Expected:** no chat line from Drop Watcher, no window, and the SavedVariables file after logout is
  unchanged from before step 2 except AceDB's own housekeeping.
- **Pass / Fail:** pass if no `[DW]` line appears and no window opens.

### C-02 (ANN-1): a fixed announce channel without that group is refused
- **Change covered:** C-02, the fixed announce channel honors the group check.
- **Setup:** Settings → Messages → Announce channel = **Party**. Solo, with one of your own drops in
  the feed (`/dw add <item link>`).
- **Steps:**
  1. Open the drop's Offer panel and press **Announce to group**.
  2. Join a party with a second character and press it again.
  3. Set Announce channel = **Instance**, stay in the home party, and press Announce again
     (ANN-1b: use a premade group outside an instance).
- **Expected:**
  1. Chat says `Not announced: You are not in a group, so there is no channel to post in.`, and no
     red system line about the party appears.
  2. `Announced in Party: [item]`, and the party sees it.
  3. Refused with the same `noChannel` line.
- **Pass / Fail:** pass if no step prints "Announced in" without the message actually appearing in
  that channel. A step that refuses must leave the button retryable.

### C-03: the shared dispatcher survives one bad handler
- **Change covered:** C-03, per-handler isolation in the shared dispatcher.
- **Setup:** in a party.
- **Steps:**
  1. `/run local D=LibStub("AceAddon-3.0"):GetAddon("DropWatcher"); D._s=D.OnSituationEvent; D.OnSituationEvent=function() error("probe") end`
  2. Have the second character leave and rejoin the party.
  3. `/run local D=LibStub("AceAddon-3.0"):GetAddon("DropWatcher"); D.OnSituationEvent=D._s`
- **Expected:**
  1. One Lua error `probe` per roster update.
  2. The window's group roster (header tooltip) and `/dw diagnostics` roster line show the rejoined
     member.
- **Pass / Fail:** pass if the roster is current despite the error.

### C-04: perf nesting is observed (after the LibKa0s re-vendor)
- **Change covered:** C-04, the `within` declarations confirmed by the record.
- **Setup:** a dungeon, in a group.
- **Steps:** run the standard two-arm `/dw perf` protocol (clean arm first, suspend as the second arm,
  no `/reload` between arms), with at least one boss kill and loot in the clean arm.
- **Expected:** the report's nesting note reads `evaluate observed inside feed.add and at top level`
  (and the same for `quality.gate`). No line says "declared … not observed".
- **Pass / Fail:** pass on that nesting text. Record the capture with
  `/dev-copilot:wow-perf-analysis` as `docs/perf-analysis/<YYYYMMDD-HHMMSS>/`. Read the bucket
  figures, not the frame-time delta.

### C-05: the enUS catalog renders the same
- **Change covered:** C-05, the completed `enUS.lua` catalog.
- **Setup:** an enUS client.
- **Steps:** open the window (both tabs), a detail card, the Offer panel, every settings page and
  `/dw help`.
- **Expected:** every string reads exactly as before. A key typo would show as different text.
- **Pass / Fail:** pass if nothing is visibly different.

### C-06: optional-addon probe through Compat
- **Change covered:** C-06, `Compat.IsAddOnLoaded` and the lint fence.
- **Setup:** Pawn installed and enabled, CanIMogIt not.
- **Steps:** `/dw debug on`, `/reload`, then `/dw diagnostics`.
- **Expected:** the `[Init]` optional line and the diagnostics line both read
  `Pawn loaded, CanIMogIt absent`.
- **Pass / Fail:** both lines agree with the AddOns list.

### C-07: comment only
- **Change covered:** C-07, the moved doc block.
- No in-client check.

### C-08: one refusal wording
- **Change covered:** C-08, every disabled refusal through the dispatcher's line.
- **Setup:** a drop in the feed.
- **Steps:**
  1. `/dw disable`.
  2. `/run local NS=LibStub("AceAddon-3.0"):GetAddon("DropWatcher"); NS.PressAsk(1)`
  3. `/dw scan`.
- **Expected:** steps 2 and 3 each print exactly
  `[DW] Ka0s Drop Watcher is disabled — enable it with /dw enable`.
- **Pass / Fail:** pass if the two lines are byte-identical.

### Upstream re-vendor (U-1, U-2)
- **Change covered:** the re-vendor of `libs/LibKa0s/` and `tests/_kit/`.
- **Setup:** after the re-vendor commit.
- **Steps:** `/reload`, then `/dw diagnostics`.
- **Expected:** the LibKa0s version line names the new tag. There are no new errors.
- **Pass / Fail:** pass on the version line.

## Regression suite

- `/reload` is clean, and the `[Init]` summary prints with `debug on`.
- Login on a fresh SavedVariables: defaults populate, the window opens with `/dw show`, and the Drops
  tab's Content reads This session.
- Enter and leave combat with the window shown: no Lua error, and the window stays as the General
  visibility rule says.
- Switch, copy and reset a profile from the Profiles page: the window re-applies and no error appears.
- Open every settings page and toggle one control on each. Restore defaults on one page.
- `/dw test` on, then off; `/dw sim start dungeon`, `run`, `stop`.

## Cross-addon (in-client half of the census)

- Load several roster addons together. Type each root (`/dw`, `/dropwatcher`, `/qc`, `/quickcomms`,
  `/at`, `/mm`, …) and confirm each reaches its own addon.
- Then open Settings → AddOns and confirm each addon appears once, and each multi-page addon's pages
  appear once each.

## Sign-off

| ID | Tested? | Pass/Fail | Notes |
|---|---|---|---|
| C-01 | | | |
| C-02 (ANN-1) | | | |
| C-03 | | | |
| C-04 | | | |
| C-05 | | | |
| C-06 | | | |
| C-07 | n/a | | comment only |
| C-08 | | | |
| U-1/U-2 re-vendor | | | |
| Regression | | | |
| Cross-addon | | | |
