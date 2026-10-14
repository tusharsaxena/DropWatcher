# Deviations: Ka0s Drop Watcher (standards audit, 2026-10-14)

Audited against standard **v2.80.0 (2026-10-13)** at `3eadd89`.

**Verdict: minor deviations.** No player, SavedVariables file or game session is hit today. One
entry is a wrong message a player can reach during a performance capture (Medium). Five entries
fail a MUST, and all five are documentation, test-suite or latent defects (Low).

**Tallies.** Nothing in this run is filed as `derived from` another entry. DRW-04's items are parts
of one missing conformance case, not separate rows. So the headline tally (roots only) and the total
including dependents are the same: **9**.

| Grade | Entries (roots) | Total incl. dependents | Of which fail a MUST |
|---|---|---|---|
| High | 0 | 0 | 0 |
| Medium | 1 (DRW-05) | 1 | 0 |
| Low | 6 (DRW-01, -03, -04, -06, -07, -08) | 6 | 5 (DRW-03, -04, -06, -07, -08) |
| Info | 2 (DRW-09, -10) | 2 | 0 |
| **Total** | **9** | **9** | **5** |

**Since the 2026-10-11 run:**

- **DRW-02 is closed.** The issues the register rows promised now exist and are cited:
  LibKa0s#49, #51 and #53, and WowAddonStandards#11. All four are open and `state:triaged`, read
  with `gh issue view`.
- **DRW-01 recurs, unchanged.**
- That run's "Checked and compliant" list held two items this run re-measures differently. Its
  disabled-state line passed the conformance suite, which lacks step 10 (DRW-04). Its docs-shape
  line read a 332-line hub with no section over 60 lines, and the hub has since grown to 571 lines
  (DRW-03).

**Recorded deviations (accepted, not counted).** The register at `docs/ARCHITECTURE.md:558-563`
carries six rows. Each is accepted, citing its rule and its Decided date, and none counts toward the
MUST tally (DRW-09 records the check).

## Entries

### DRW-01: the toast's degraded close is a typed glyph (recurring)

- **Section:** standalone-windows (chrome degrades to nothing), library-stack-§8 (no one-off marks).
- **Grade:** Low. Only an install with LibKa0s missing reaches it, and the effect is cosmetic.
- **Description:** when `NS.MakeCloseButton` answers nil (the Core stub, `core/CoreSetup.lua:49`),
  `modules/Toast.lua:270-272` draws its own text button labeled `"×"`. Every other close control
  degrades to nothing.
- **Fix direction:** time the test-mode toast out on the degraded path and delete the fallback. Or
  keep the fallback and record a register row for it. Today it is neither, so the entry stays open.

### DRW-03: the hub has stopped being an index (three sections past the spill threshold)

- **Section:** documentation-§3, *`ARCHITECTURE.md` is a hub, and the spill rule keeps it one*
  (**MUST** spill past ~60 lines; **SHOULD** stay under ~400 lines).
- **Grade:** Low. Documentation only. The entry still fails a MUST.
- **Description:** `docs/ARCHITECTURE.md` is **571** lines. *Module Map* runs 175 lines (43-217).
  It links `module-map.md` but keeps a 170-line "In short" walk of every module. *Settings Schema*
  runs 89 lines (218-306), and *Known Limitations* runs 73 (432-504). The previous run measured
  332 lines.
- **Fix direction:** cut *Module Map* to a short summary with one link to `module-map.md`. Move the
  row narrative and the long *State written outside the seam* paragraph from *Settings Schema* into
  `schema.md`. Keep a short summary, plus the named-state sentence that architecture-§5 requires
  in this section (see upstream finding U-2). Move the per-feature limitation bullets into
  `design-readings.md`, or a Tier 3 `known-limitations.md`, and leave a summary.

### DRW-04: the disabled-state conformance suite misses step 10 and parts of steps 6-8

- **Section:** slash-commands-§7, *The conformance test every addon ships* (**MUST**), and testing-§12.
- **Grade:** Low. The behavior holds today: the stand-down is one latch and the registration set
  empties, as cases 1, 2 and 6 assert. What is missing is the guard that would catch a regression.
- **Description:** `tests/test_disabled.lua` (179 lines, cases 1-8):
  - **Step 10 is absent.** No case takes the `perf` hold, writes `enabled = false`, releases `perf`
    and asserts the addon stays down, or runs the reverse order. A repo-wide grep finds
    `Hold(NS.HOLD_PERF)` only in `tests/perf.lua:147`.
  - **Step 7 is partial.** `:111` dispatches only `help, version, list, get enabled, diagnostics,
    profile`. `config`, `enable`, `disable`, `debug`, `perf`, `set`, `reset`, `resetall` and the bare
    `/dw` are never dispatched while disabled. `:127` checks three feature verbs (`show, test, lock`)
    of the 16 the table carries, where the rule is "every entry in `NS.COMMANDS`".
  - **Step 6 is partial.** Case 2 (`:90`) fires each of the 28 pinned events through the mock and
    asserts that no handler dispatches. Case 3 (`:103-105`) fires the two `PLAYER_REGEN_*` edges
    unconditionally and asserts zero SavedVariables writes. No case asserts **zero printer calls**
    or **zero frame shows** after the events fire, as step 6 requires.
  - **Step 8 is partial.** `:174` drives `RightButton` only. The left-click (panel opened, zero
    writes, zero shows) is not asserted.
  - **Falsification comments.** Only step 3 carries one (`:88`). The rule requires one on steps 3, 6
    and 10.
- **Fix direction:** add a step-10 case in both hold orders. Drive every `NS.COMMANDS` row and the
  bare slash in the step-7 case. Fire every pinned event and assert prints and shows as well as
  writes. Add the left-click assertion. Write the `-- red under:` lines for steps 6 and 10.

### DRW-05: a performance capture's refusal says the addon is disabled

- **Section:** slash-commands-§7, *The refusal line* (a line naming `/dw enable` is for the
  **disabled** state); performance-§6 (the `perf` hold is not the disabled state).
- **Grade:** Medium. A player can reach it (type `/dw scan`, `/dw test`, `/dw sim start …` or
  `/dw add` during a guided `/dw perf` capture's suspended arm). It prints a false line, and the
  remedy it names does nothing, because `enabled` is already true. Nothing breaks.
- **Description:** the dispatcher gates correctly on the **stored** flag (`settings/Slash.lua:100-103`,
  `:176`), so the feature verb goes through to its handler. The handler then refuses on
  `NS.IsStoodDown()`, which is true while **either** hold is taken (`core/LifecycleSetup.lua:14-16`),
  and prints `NS.SlashCommands:DisabledLine()`: "Ka0s Drop Watcher is disabled — enable it with
  /dw enable". Sites: `core/DropWatcher.lua:120` (test mode), `:178` (scan), `:283` (retry inspect),
  `:394` (post tradeables), `modules/Sim.lua:128` (sim start).
- **Fix direction:** refuse on the hold that is actually taken. Use `DisabledLine()` only when
  `NS.Lifecycle:IsHeld(NS.HOLD_DISABLED)`. Under the `perf` hold alone, print a localized
  "not available during a performance capture" line. One helper (`NS.StoodDownRefusal()`) can serve
  all five sites, with a test per hold.

### DRW-06: the When-to-show table rides a pooled AceGUI frame, cleaned up outside `OnRelease`

- **Section:** options-ui-§19 (**MUST**: whatever addon code puts on a widget's `.frame` is undone in
  that widget's `"OnRelease"`); anti-pattern #93.
- **Grade:** Low. It is latent. Every release path today is a render through `renderGeneral`, which
  parks the table first (`settings/Panel.lua:75-79`), and the tab-click `rerender` is the same
  function. A release that skips that renderer (a library-side `ClearScroll` on another path, a
  future second renderer) would leave the table riding a pooled `SimpleGroup` frame into an
  unrelated widget, which is the #93 symptom.
- **Description:** `settings/PageEditors.lua:225-227` reparents the table's host frame onto
  `holder.frame`, a `SimpleGroup` from `AceGUI:Create`. The undo is `P.ParkSituationTable`
  (`:200-206`), which the page renderer calls. The widget's own `OnRelease` does not undo it.
- **Fix direction:** add `holder:SetCallback("OnRelease", function() P.ParkSituationTable(ctx) end)`
  in `P.SituationTable`, so the park runs on every release, and keep the renderer's call as
  belt-and-braces. Add a case that releases the holder without the renderer and asserts the host is
  parked.

### DRW-07: two hub inventory counts are stale

- **Section:** documentation-§5 (**MUST** keep the doc set in sync with code); documentation-§3
  (the compat-layer trigger counts across the family since v2.79.0).
- **Grade:** Low. Documentation only.
- **Description:** `docs/ARCHITECTURE.md:45` reads "Ninety-four authored files load from the TOC".
  The TOC loads **97**, and `docs/module-map.md` numbers its rows 1-97. `docs/ARCHITECTURE.md:532`
  reads "`core/Compat.lua` publishes 62 addon-specific shims". documentation-§3's count runs over
  the whole family (`cat core/Compat*.lua | grep -cE …`), which gives **83**: 62 + 16 + 5. The
  trigger fires either way, but the row cites the wrong basis.
- **Fix direction:** write 97 and 83 (family) with the command. Better, drop the spelled-out file
  count from the hub, since `module-map.md` is the inventory.

### DRW-08: load-bearing TOC positions are annotated `Conventional`

- **Section:** toc-file-§5 (**MUST**: a load-bearing line carries a comment saying so and naming what
  resolves). Filed once, rolled up.
- **Grade:** Low. The annotations name what resolves, so a careful reader is not misled. The label
  tells a hurried one the line is free to move.
- **Description:** 51 of the TOC's 66 `# Conventional:` comments describe a file-scope read or a write into
  an `NS` table at load (counted in `03_EVIDENCE.md` §TOC). Several state an ordering between files
  of the **same** group, where moving the line changes behavior:
  - `DropWatcher.toc:47-48`: `core\Compat.lua` "needs LibStub and NS.TextParse (above) at load".
  - `:158-163`: `modules\Roster.lua` appends `GROUP_ROSTER_UPDATE` "so its handler runs second… A
    module declaring the event below it hears it after the roster is fresh".
  - `:190-196`: `modules\Inspect.lua`'s rows sit "after modules\Roster.lua's and
    modules\Situations.lua's, so the roster is fresh".
  - `:262-268`: `modules\TipMarks.lua` sits "Above modules\MineCells.lua, … (which take it at load)".
  - Similarly `modules\LootFeed.lua` (`:197-203`), `modules\TradeTimer.lua` (`:204-209`) and
    `modules\WindowCompact.lua` (`:245-251`).

  `modules\Asks.lua` (`:212-221`), whose comment makes the same kind of claim, is correctly
  labeled `LOAD-BEARING`. The labeling is inconsistent, not just strict.
- **Fix direction:** relabel every line whose comment states a load-time read or an in-group order
  `LOAD-BEARING`. Keep `Conventional` for lines whose comments say "read inside functions only".
  Upstream finding U-1 asks the standard to settle whether a dependency the group order already
  guarantees makes a line load-bearing. Until it rules, follow the denominator paragraph as written.

### DRW-09: the six register rows were re-checked and hold

- **Section:** audit-review-history (rows' rules unchanged, triggers not fired, evidence resolves).
- **Grade:** Info.
- **Description:** rows at `docs/ARCHITECTURE.md:558-563` cover library-stack-§7/#47 (×5) and
  "(no rule yet)" addon-sent chat. None of the cited rules changed in v2.79.0-v2.80.0. No LibKa0s
  major yet carries a chat sender, tooltip reader, loot parser, restriction tracker, exact item read
  or step panel. LibKa0s v1.71.0 is the newest tag. The issues resolve: LibKa0s#49, #51 and #53, and
  WowAddonStandards#11 (all open, `state:triaged`). The plan id `DW-91` resolves to
  `docs/superpowers/plans/2026-10-10-drop-watcher-v1/issues-to-file.md:51`.
- **Fix direction:** none.

### DRW-10: the automated-test record is seven commits behind HEAD

- **Section:** automated-tests-§4 (staleness is read off the newest row's commit cell).
- **Grade:** Info. The checkpoint is the release, the addon is unreleased (0.1.0, "Unreleased"), and
  the live sighted run matches the record within noise (max CCN 14, 0 warnings, 0 in the
  1000-1500 band).
- **Description:** the newest bundle `20261014-133254` measured `5996818`, and
  `git rev-list --count 5996818..HEAD` is 7. Live run: 41618 NLOC and 5314 functions against the
  record's 41539 and 5304.
- **Fix direction:** cut a fresh bundle with the release run, as usual.

## Checked and compliant (not entries)

- **Line endings:** canonical 84-line body, 0 strays, gate wired (line-endings-§1..§7).
- **Packaging:** nothing unaccounted but `.git`, and no false conditional line (packaging).
- **Generators / `Bindings.xml`:** none (layout-§1, toc-file-§4).
- **Over-cap census:** heading present, nothing over 1500 and nothing in 1000-1500, `test_layout_cap`
  wired (layout-§1).
- **Re-vendor bundles:** one tag vendored (v1.71.0) and no store yet; measured from the next
  re-vendor (audit-review-history).
- **Bus:** no literal at a shipped call site, and all ten tails PascalCase (architecture-§4).
- **Event registration:** one `pcall`ed helper per event, with a rejected list reachable from
  diagnostics (events-frames-taint-§1). The `hooksecurefunc` body gates itself.
- **`## IconTexture`:** own 128x128 type-2 32-bit TGA (toc-file-§1, layout-§4).
- **Compat family:** root first and contiguous, the root header names both family files, and no
  client call outside the family (compat, v2.79.0).
- **Disabled stand-down itself:** one latch, two holds, no second teardown. The registration set
  empties (cases 1/2/6), and the reserved verbs stay live through `LIVE_VERBS`
  (slash-commands-§2/§7). The suite's gaps are DRW-04, and the message under the perf hold is DRW-05.
- **Launcher:** one object, the menu matches `ADDONS.md`, label `Ka0s Drop Watcher`, no host
  tooltip (launcher).
- **Diagnostics:** one row, no alias, live while disabled, logging turned on by the library, README
  section verbatim (debug-logging-§14).
- **Write paths:** one seam, and every outside writer is named with its owner (architecture-§5).
- **Settings content:** every page tabbed. Master controls is first on General and composed by the
  library. No color rows, no reorder arrows, no `LSM30_*` copies, no Settings-window calls, and the
  secondary strip is session state (options-ui-§13-§18).
- **Vendoring:** whole payload and kit, byte-identical to v1.71.0 (library-stack-§7, #45/#48).
- **Lint scope, kit revision, complexity:** `tests/` linted, kit 38, sighted gate wired, blind 0
  (lint, automated-tests-§3).
- **README:** structure, badges, no logo, no inventory, no numbered list, no placeholders
  (documentation-§1).
