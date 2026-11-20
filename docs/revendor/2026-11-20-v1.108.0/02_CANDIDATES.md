# 02 — Candidates: LibKa0s v1.107.0 -> v1.108.0

Sources: `git -C ../LibKa0s log --oneline v1.107.0..v1.108.0` (15 commits) and the v1.108.0 CHANGELOG block at the tag.

## Class A: reached the addon on the re-vendor alone
- The footer lays out only its shown marks (Widgets minor 30, LibKa0s#94). The main window's footer hides the marks a tab does not bind (modules/FooterRow.lua `FR.Bind`), so its left line now reaches the leftmost shown mark. Checked under SD-DW-94.
- Insights chart bars wear the skin's gloss under Glass (Charts minor 3, ChartsRender minor 2, U-4), through the owner this addon already passes.
- The shared menu's submenu arrows follow the menu palette (WidgetsDropdown minor 3), on the compact Filters menu.

## Class B: host change required
- None taken here beyond the blockers in `01_DELTA.md`. `W.OwnerWarnings(owner, sink)` (Widgets minor 30) is new and optional: this addon builds every library widget with its owner, so it is not wired in this run (noted for the lead).

## Class C: whole-module adoption
- None new.
