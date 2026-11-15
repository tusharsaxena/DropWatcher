# 05 — Summary: LibKa0s v1.102.0 -> v1.103.0

Run 2026-11-15 by UC-DW of the rolls UX round (plan M10). Nothing was pushed.

- **Tag:** v1.102.0 -> v1.103.0 (tag commit 48a166d5), base from the CLAUDE.md provenance line, which
  agreed with the last payload commit (4ee0a01). Kit revision 56 -> 56. Per-file minors: Widgets
  26 -> 27; Callout 4 -> 3 and CalloutSettings 5 -> 4 (backwards: v1.103.0 is cut from v1.101.0 and
  does not contain v1.102.0; neither major is looked up here). No cross-major skew in what this addon
  consumes.
- **Span bundle:** none (every vendored tag recorded). No base correction (Step 0: every roster row `ok`).
- **Free (class A):** nothing on screen; an undocked strip is minor 26's.
- **Contract blockers:** none.
- **Icons:** the `LibKa0s icons:` line kept (32 names); the prune removed no icon and the 362
  voice-pack files the copy brought back (no `LibKa0s sounds:` line). No provenance split. README
  credits unchanged (Open Iconic and Phosphor still ship; no Game-icons). No dead stub mirrors.
- **Adopted:** TestStrip docking (the main window's test and sim strips under `f.titleBar`, the body
  moved by `BodyOffset`; the Rolls panel's two strips under `p.titleBar`, a bare frame on its band) and
  Widgets Footer (the main window's footer, no fill, the divider hairline, `FOOTER.HEIGHT`, the grip on
  it in its corner, `SetGrip` with the lock), in the adoption commit after the re-vendor commit.
- **Flagged to the owner (a standard question, not ratified):** the tab's words and controls on the
  footer stay the host's own (the strip's info and status font strings, its labeled buttons and the
  Sort dropdown), laid over the library's footer, rather than the footer's `left` / `right` lines and
  `marks` slot; standalone-windows' *The footer* and anti-pattern #118 read that as a host-drawn footer.
  **Resolved 2026-11-15 (RX-24):** the owner ruled a rework, not a deviation row and not a standard
  change. The footer's words are its own left line (`foot:SetLeft`), its controls its `marks` (catalog
  icon buttons with tooltips), the labeled buttons are gone and Sort is on the filter bar; the Offer
  panel's Announce to group is its footer's mark.
- **Unreached, listed for the owner (no issue filed, by the ruling):** `dock = "hud"` for the loot
  toast and the simulated roll popup's stand-in and side card; footer marks (adopted by RX-24); strips on the Offer panel
  and the Edit message box; the settled `O.SideTabs`, Callout, WaypointArrow and IconBrowser
  (`02_CANDIDATES.md`).
- **Gates:** re-vendor commit (b12996a): Retail 2553 passed / 0 failed / 1 skipped, Forever 2445 / 0 /
  108, luacheck 0/0 in 264 files, perf 0 fail lines, the kit's complexity suite green (0 warnings).
  Adoption commit: Retail 2552 passed / 0 failed / 1 skipped, Forever 2444 / 0 / 108, luacheck 0/0 in
  264 files, perf 0 fail lines, the kit's complexity suite green (0 warnings, max CCN 15).
