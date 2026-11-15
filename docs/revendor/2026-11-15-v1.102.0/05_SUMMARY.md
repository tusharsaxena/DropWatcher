# 05 — Summary: LibKa0s v1.95.0 -> v1.102.0

Run 2026-11-15 by RX-13 of the rolls UX round. Nothing was pushed.

- **Tag:** v1.95.0 -> v1.102.0 (tag commit 2748549), base from the CLAUDE.md provenance line, which
  agreed with the last payload commit (006e2e5). Kit revision 54 -> 56. Per-file minors: Media 12->13,
  SkinDefsOthers 8->9, DebugLogDiagnostics 8->10, OptionsWidgets 45->46, OptionsNav 6->7; new Callout 4,
  CalloutSettings 5, WaypointArrow 2, WaypointArrowSettings 2. No cross-major skew.
- **Span bundle:** `../2026-11-15-v1.95.0-v1.95.0/`, one tag (v1.95.0, vendored by 006e2e5 under the
  Forever port with no bundle). No base correction was owed (Step 0: every roster row `ok`).
- **Free (class A):** the slider box's junk guard (OptionsWidgets 46), two new faces (Media 13,
  SkinDefsOthers 9), the diagnostics line naming the new majors, the kit's sound-subset gate.
- **Contract blockers:** none. The one adjustment on landing was the degraded Options stub, which
  needed `SideTabs` (OptionsNav 7) for `tests/test_surface_parity.lua`'s live-surface case; it is in
  the re-vendor commit.
- **Icons:** the `LibKa0s icons:` line gains `ph:hourglass` and, in the second commit, loses `clock`
  (32 names). The prune at the re-vendor cut the catalog (224 Open Iconic, 1434 Phosphor, 4178 Game-icons)
  to the 33 declared names and removed all 362 voice-pack files (no
  `LibKa0s sounds:` line, so none); the second prune removed `clock.tga`. No provenance split.
  `media/waypoint/` (eight TGAs, about 450 KB) ships whole, as the library requires.
- **README credits:** Phosphor (MIT) added beside Open Iconic for the hourglass. No Game-icons ship.
  No dead stub mirrors.
- **Adopted:** `ph:hourglass` as the roll waiting mark (`RollCells.WAITING_ICON`) and the Queued state
  of Ask, Offer and your own Offer (`modules/WindowCells.lua`, `modules/MineCells.lua`), in RX-13's
  second commit.
- **Unreached, listed for the owner (no issue filed, by the ruling):** `O.SideTabs`, the Callout major,
  the WaypointArrow major (`02_CANDIDATES.md`).
- **Note for the owner:** `ph:hourglass` was already in the v1.95.0 catalog
  (`phosphor/hourglass.tga`); what the addon lacked was the declaration, not the library tag.
- **Gates:** after each commit, Retail and Forever 0 failed (2486 passed / 1 skipped; 2378 / 108),
  luacheck 0/0 in 261 files, lizard silent, the kit's complexity suite green (0 over CCN 15).
