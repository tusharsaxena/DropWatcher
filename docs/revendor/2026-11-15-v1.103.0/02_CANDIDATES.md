# 02 — Candidates: LibKa0s v1.102.0 -> v1.103.0

Sources: `git -C ../LibKa0s log --oneline v1.102.0..v1.103.0` (4 commits), the CHANGELOG block v1.103.0
at the tag, and `docs/api/Widgets/version-27.1.6.13.7.8.5-docs.md` (the only major whose minor moved
forward). The 3g read found no blocker, so every item below is optional to the library; items 1 and 2
are required by the standard from this re-vendor (WowAddonStandards v2.110.0, library-stack-§7,
anti-pattern #118) and pre-decided by the owner's approval (plan M10, UC-DW).

## Class A: reached the addon on the re-vendor alone (delivered, not offered)
- Nothing new on screen. An undocked strip is Widgets minor 26's, call for call (version-27 docs,
  *What a consumer owes at 27.1.6.13.7.8.5*). The Callout files go back a minor (01, 3a), unconsumed.

## Class B: host change required
1. **TestStrip docking** (`opts.dock = "title"` / `W.DockTestStrip`, Since 27; version-27 docs lines
   50-70): the strip anchors itself under a title bar, full width, re-places on show, hide and resize,
   and answers `BodyOffset()`. Touches `core/WidgetsSetup.lua` (`NS.MakeTestStrip`'s `dock`),
   `modules/Window.lua` (both strips, the body's top), `modules/CompactChrome.lua` (the strip's height),
   `modules/RollsPanel.lua` (both strips under a title-band frame). Replaces host anchoring (the main
   window's strips sat between the filter bar and the body). **Adopt** (pre-decided).
2. **Widgets Footer** (`W.Footer`, `W.FOOTER`, Since 27; version-27 docs lines 23-48): no fill, a
   hairline in `divider`, `FOOTER.HEIGHT` 24, left and right lines in `text.muted`, a marks slot, the
   grip's corner. Touches `modules/Window.lua` (the footer replaces the `S.Footer` dark band), the tab
   strips that ride it (`modules/DropsStrip.lua`, `modules/WindowHistory.lua`,
   `modules/WindowInsights.lua`: no rule of their own, the footer's height, `text.muted`),
   `modules/WindowFooter.lua` (the status line's token), `core/Constants.lua` (`STRIP_H` and
   `BANNER_H` leave the constants file). Replaces host code. **Adopt** (pre-decided).

## Listed for the owner, not adopted (no issue filed, by the ruling)
3. **`dock = "hud"`** (version-27 docs line 61): a HUD display's strip on its top edge, outside it,
   flipped under its bottom edge off-screen. Candidates here: the loot toast in test mode
   (`modules/Toast.lua`, its placeholders toast like live drops), and the simulated roll popup's
   stand-in and its side card in test mode and a simulation (`modules/RollPopup.lua`). The standard
   (preview-mode, *Where the strip sits*, v2.110.0) makes the HUD strip a MUST from this re-vendor, so
   these are open standard items, not optional ones.
4. **Footer marks** (`opts.marks`, version-27 docs line 30): host-passed catalog marks in the footer's
   right slot. The compact layout already draws the row's buttons as their marks alone
   (`FooterRow.SetCompact`); the full layout's labeled 150 px buttons and the tab's Sort dropdown are
   not marks, and the slot is built once per footer while each tab has its own row.
5. **Other windows that draw test data**: the Offer panel and the Edit message box (title bands of
   their own, test mode's samples reach the Offer panel) carry no strip today.
6. **Settled from earlier bundles, unchanged in this range**: `O.SideTabs` (OptionsNav 7), the
   Callout, WaypointArrow and IconBrowser majors (`../2026-11-15-v1.102.0/02_CANDIDATES.md`).
