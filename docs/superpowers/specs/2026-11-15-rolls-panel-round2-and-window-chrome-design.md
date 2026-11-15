# Rolls panel round 2, and the collection's window chrome (design)

Date: 2026-11-15. Owner's smoke of the Rolls panel (`feat/2026-11-14-rolls-ux` at `ba87945`). Two parts: Drop
Watcher's Rolls panel (A), and two collection-wide chrome standards delivered through WowAddonStandards and LibKa0s
and adopted by every addon (B). The owner chose to do both in this run, before Drop Watcher's branch merges.

## A. Rolls panel, round 2 (Drop Watcher)

Owner rulings (2026-11-15):
1. **Test mode strip, not a header word.** The panel's title band loses "TEST MODE"; a test strip (and the sim
   flavor during a simulation) sits directly under the panel's title bar, built with LibKa0s Widgets `TestStrip`,
   with the panel's own text (e.g. "TEST: sample rolls. Nothing is sent; combat ends it.").
2. **Item headers with a collapser.** Each rolled item is a header row styled like the window's "Rolling now (1)"
   section header (chevron, gold text, band), with the item icon and name; clicking toggles that item. The panel's
   title bar gains **Expand all** and **Collapse all** buttons (catalog marks, with tooltips). **Every item starts
   expanded, in any group size; collapse is manual only**, and a manual state sticks while that roll is listed.
   Raid mode's one-open rule (RX-18) is removed; folding Pass and Waiting in a raid (`foldInRaid`) stays.
3. **Width** grows as needed so header, rows and roll numbers fit: 290 full layout, 250 compact (layout units).
4. **No verdict line** ("^ Upgrade +9") in the panel.
5. **Alternate row shading** for the roller rows (skin's row and alt-row tokens).
6. **Every actual roll is shown**: each player who rolled shows their roll number right-aligned (Need, Greed,
   Disenchant); Pass and Waiting show none. Test mode's samples carry roll numbers so this is obvious there.
7. **Tooltips** wherever relevant: item header (item tooltip plus the all-rolls tooltip), each roller row (name,
   choice, roll, class), folded Pass/Waiting lines (names), title buttons, the close button, the strip.
8. **Title "Rolls"**, no count.
9. **Panel-level linger replaces per-roll linger**: finished rolls stay in the panel (winner highlighted, result
   line) until every current roll is done; then the panel stays `rolls.panel.linger` seconds (0–60, default 10) and
   closes. A new roll during that time cancels the countdown. Hover holds it; the count restarts on leave.
10. **Flush docking**: the panel's edge touches the window's edge (gap 0), top-aligned.
11. **Test mode shows the simulated roll popup and its side card** (as `/dw sim roll` does) for its sample rolls; they
    go away when test mode ends.

## B. Collection chrome standards (WowAddonStandards + LibKa0s + every addon)

### B.1 The test/sim strip sits directly under the header (owner rulings)
- **Every window** that shows test or simulated data **MUST** mark it with LibKa0s Widgets `TestStrip` (amber test,
  cyan sim), placed **directly under the title bar**, full width, above tabs, filter bars and body; the body moves
  down by the strip height while it shows. The header carries no mode word while the strip shows. A window whose
  header is hidden or minimized keeps a header-word or badge marker as today (preview-mode's one-marker rule).
- **HUDs too** (owner ruling; reverses preview-mode's v2.93.0 HUD exemption and the "HUD MUST NOT carry a simulation
  marker" clause): a HUD display in test or sim shows the strip **docked to its top edge, outside it** (where a header
  would be), or under its bottom edge when the top would leave the screen (orchestrator's ruling: a HUD has no header,
  this is the nearest equivalent). The simulation step panel stays as well.
- LibKa0s gains the placement helper so hosts do not hand-anchor: e.g. `TestStrip` `opts.dock = "underTitle"` with a
  title-bar reference, and `opts.dock = "hudTop"` with flip; exact API is LibKa0s's call.

### B.2 The footer (owner rulings)
- Any window with a footer **MUST** build it with a new LibKa0s Widgets **Footer** primitive in the CombatTrail look:
  no dark fill band; a hairline divider along its top edge; left text and optional right text in the muted text token;
  an optional right-hand control slot (catalog marks); the resize grip, if any, in its bottom-right corner.
- **Height 24 px**, published as a library constant (like the title bar height), skin-invariant (skinning: geometry
  is skin-invariant).
- The standard defines the footer height beside the header height.

### B.3 Delivery
- WowAddonStandards: the rules above (preview-mode, standalone-windows, skinning/frame-layering as needed,
  anti-patterns, audit playbook, context pack, changelog), a minor version bump, merged, tagged, pushed.
- LibKa0s: the Footer primitive, TestStrip docking, skin tokens if needed, tests, docs/api, changelog, version bump,
  merged, tagged, pushed (addons re-vendor from the tag).
- Every roster addon (standards/ADDONS.md) with a window or HUD that shows test/sim data or a footer: re-vendor the new
  tag, move its strip under the title bar (or to the HUD top), adopt the Footer, gate green, on its own branch, pushed;
  merge waits for the owner. Addon versions are not bumped. Drop Watcher adopts on `feat/2026-11-14-rolls-ux`.
- Other sessions are active in some repos (WowAddonStandards, LibKa0s, AuraMaster branches): this run works in its
  own worktrees cut from each repo's default branch and never touches another session's branch.
