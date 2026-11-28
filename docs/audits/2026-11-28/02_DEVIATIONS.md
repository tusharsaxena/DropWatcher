# Deviations: Ka0s Drop Watcher (standards audit, 2026-11-28)

Audited against standard **v2.122.0 (2026-11-28)** at `c7b9bbc`.

**Verdict: minor deviations.** No player, SavedVariables file or game session is hit today. Both
suites are green on both clients, lint is 0/0, the vendored payload and kit match tag v1.120.0, and
the line-ending and packaging bodies are canonical. Everything filed is documentation, record-keeping
or a latent cosmetic gap.

**Tallies.** One entry is filed as `derived from` another: DRW-19, under DRW-10.

| Grade | Roots (headline) | Total incl. dependents | Roots failing a MUST |
|---|---|---|---|
| High | 0 | 0 | 0 |
| Medium | 0 | 0 | 0 |
| Low | 10 (DRW-03, -04, -07, -11, -12, -13, -14, -15, -16, -17) | 10 | 10 |
| Info | 3 (DRW-09, -10, -18) | 4 (+DRW-19) | 0 |
| **Total** | **13** | **14** | **10** |

The headline tally counts roots only, and the total adds DRW-19. All ten Lows fail a MUST. They are
graded Low because none of them is reachable by a player (doc, config, record or a test gap), or, for
DRW-15, because it is cosmetic and reached only inside a simulation.

**Since the 2026-10-14 run:** DRW-01, -05, -06 and -08 are closed (evidence in `03_EVIDENCE.md`
§Prior). DRW-03, -07 and -10 recur. DRW-04 has narrowed to step 5. DRW-09 was re-run.

**Recorded deviations (accepted, not counted).** The register (`docs/ARCHITECTURE.md:835-845`) has
nine rows. Eight are accepted, each under its rule and Decided date, and none counts toward the MUST
tally (DRW-09). The ninth is accepted too, but its re-check trigger has fired (DRW-11).

**Owed at adoption, no severity:** none open. Drop Watcher has adopted Tooltip, Sim, Glow, Skin,
Lifecycle and the header strip.

## Entries

### DRW-03: the hub has grown to 856 lines, with Event Subscriptions unspilled (recurring)

- **Section:** documentation-§3 (**MUST**: hub shape, a mandated section spills to its topic doc
  past roughly 60 lines, and the file stays under roughly 400).
- **Grade:** Low. Documentation only.
- **Description:** `docs/ARCHITECTURE.md` is 856 lines (571 at the last run). Three sections run
  long. Module Map is 217 lines, but 143 of them are the clients-§4 per-client table the hub has to
  carry. Event Subscriptions is 106 lines and has not spilled to `data-flow.md`. Skins is 139 lines,
  an addon-specific section with no canonical target.
- **Fix direction:** spill Event Subscriptions into `data-flow.md` and leave a pointer paragraph.
  Move Skins and Tooltip placement (49 lines) into a Tier 3 `skins.md` registered under
  Addon-specific. That leaves the hub at about 570 lines (856 less the 294 moved, plus pointers). Whether a 143-line mandated table may sit
  in a hub capped at roughly 400 lines is noted for the standard (U-4).

### DRW-04: the disabled conformance suite's step 5 checks one frame, not `F_on` (narrowed)

- **Section:** slash-commands-§7, *The conformance test every addon ships*, step 5 (**MUST**).
- **Grade:** Low. A test gap. Nothing in the code is known to be wrong.
- **Description:** step 5 requires every frame in `F_on`, the frames shown before the disable, to be
  hidden after it. `tests/test_disabled.lua` case 2 asserts only the main window
  (`:130`, `:133`) and never takes `F_on` from the mock's `__shownFrames()`. The Rolls panel, the
  roll popup's side card and a toast shown at the moment of disable are not asserted. Cases 3 and 8
  do read `__shownFrames()`, but only as a "no new show" delta. Steps 6-10, which the last run filed,
  are now covered (cases 3, 4/5, 8, 6, 11).
- **Fix direction:** in case 2, open the Rolls panel and a toast in test mode first. Capture
  `F_on = m.__shownFrames()`, disable, then assert each of its frames `:IsShown() == false`, with a
  `-- red under:` line naming the stand-down step whose removal turns it red.

### DRW-07: the hub's compat-family count is stale after the Item Search split (recurring)

- **Section:** documentation-§5 (**MUST**: docs stay in sync with code); documentation-§3 (the
  compat-layer trigger is a count over the family).
- **Grade:** Low. Documentation only. The trigger still fires, since 100 is three or more.
- **Description:** `docs/ARCHITECTURE.md:806` says the family publishes **132** shims (`Compat.lua`
  59, `CompatClient` 12, `CompatLoot` 17, `CompatWorld` 18, `CompatItem` 5, `CompatJournal` 5,
  `CompatCollect` 16). Its own command gives **100** today (43, 10, 17, 18, 4, 5, 3). The split moved
  shims out and the row was not re-run.
- **Fix direction:** re-run the command the row quotes and write 100 with the per-file split. Better,
  state the count as "the command below answers N on <date>" so it is dated rather than present-tense
  (documentation-§6).

### DRW-09: register rows re-checked (Info)

- **Section:** audit-review-history (the register's three MUSTs).
- **Grade:** Info.
- **Description:** nine rows. Every evidence id resolves: LibKa0s#49 is closed `state:will-not-do`,
  LibKa0s#51 is closed `state:done`, WowAddonStandards#11 is open `state:triaged`, and both
  Ka0sAddonsCommonTasks paths exist. The chat-sender, loot-parser, restriction-tracker and
  localization rows keep their rules unchanged, and their triggers have not fired (the standard still
  has no addon-sent-chat rule, no non-enUS locale ships, and the track-id table is still empty). The
  tooltip-placement row's trigger has not fired. The side-card row's trigger ("the card becoming
  movable or outliving its popup") has not fired: the only movable frame in `modules/RollPopup.lua`
  is the simulator's stand-in popup (`:515`), not the card. The options-ui-§17 row is DRW-11.

### DRW-10: the automated-test record is 218 commits behind HEAD (recurring, Info)

- **Section:** automated-tests-§4 (the record is a release checkpoint); anti-pattern #51.
- **Grade:** Info. The checkpoint is release, not commit, and no release has been cut since 1.1.0
  (tag `1.1.0-release`, 2026-10-25).
- **Description:** the newest bundle, `20261116-102800`, measured `c03cddd`. The runner reports it
  "218 commit(s) behind HEAD". Today's sighted measurement is still green (0 warnings, max CCN 15,
  `blindFiles` 0). This is owed at the next release, not now.
- **Dependents:** DRW-19.

### DRW-11: the options-ui-§17 register row's re-check trigger has fired

- **Section:** audit-review-history (**MUST**: every row's re-check trigger is evaluated, and a fired
  one is reported).
- **Grade:** Low. A record only. The layout the row covers is unchanged.
- **Description:** `docs/ARCHITECTURE.md:845` ratifies the companion sitting below its swatch, with
  the trigger "the next options-ui-§17 edit, or LibKa0s gaining a mirrored color-pair layout". That
  section has been edited twice since the row's Decided date of 2026-10-18: v2.119.0 (2026-11-24, the
  precedence and *A preview shows a class*) and v2.122.0 (2026-11-28, the `disabledIf` MAY). The row
  carries no re-check note, so it asserts a live ratification whose own trigger has already ended it.
- **Fix direction:** re-read the current options-ui-§17. If it still asks for the companion as the
  **next** row, re-ratify with a dated re-check note and a forward trigger (for example "options-ui-§17
  changing its placement sentence"). If the edits changed nothing about placement, say so in the row.

### DRW-12: three TOC load-bearing annotations name `modules\Gear.lua`, which no longer exists

- **Section:** toc-file-§5 (**MUST**: a load-bearing line names what resolves).
- **Grade:** Low. The order is still correct: the verdict engine's rows now come from
  `core\VerdictSetup.lua`, which loads before every module. A reader following the annotation finds
  no file.
- **Description:** `DropWatcher.toc:263` (Inspect), `:293` (TradeTimer) and `:545` (Toast) each
  order a `NS.FEATURE_EVENTS` row "after modules\Gear.lua's". The gear handler moved into
  LibKa0s-Verdict-1.0 and its rows are appended by `core/VerdictSetup.lua:136-150`
  (`NS.Verdict.EventsFor(client)`). No test sees a comment, so it survived the split.
- **Fix direction:** rewrite each clause as "after core\VerdictSetup.lua's (the verdict engine's
  rows)". Consider a static case asserting that every `modules\X.lua` or `core\X.lua` a TOC comment
  names exists (an upstream kit candidate, U-3).

### DRW-13: the README H1 drops the brand under an owner ruling that has no register row

- **Section:** documentation-§1 item 1 (**MUST**: `# Ka0s <Name>`); documentation-§3 /
  audit-review-history (a deviation not in the register is not ratified).
- **Grade:** Low. A doc file.
- **Description:** `README.md:1` reads `# Drop Watcher`. Commit `2df58ad` (R6-NAME, 2026-11-04)
  records the owner's ruling (Ka0sAddonsCommonTasks
  `docs/2026-11-03-SMOKE_ROUND6/inputs/OWNER_ANSWERS.md`) that the README title drops "Ka0s". The
  ruling is real, but `## Documented deviations` has no row for it, so by the register's own rule it is
  not ratified.
- **Fix direction:** the owner picks one. (a) File the row in Drop Watcher: `documentation-§1 item 1 |
  H1 is "# Drop Watcher" | owner ruling R6-NAME | 2026-11-04 | the standard changes the H1 rule`.
  (b) Propose upstream, in WowAddonStandards, that the H1 may name the addon without the brand while
  the TOC Title and launcher label keep it (U-1).

### DRW-14: the README names the Show window binding with only one of its two places

- **Section:** launcher-§6, *Documented* (**MUST**); anti-pattern #96.
- **Grade:** Low. A doc gap.
- **Description:** `README.md:49` (in `## Usage`) says "Bind a key under Options → Keybindings → Ka0s
  Drop Watcher". It never names the addon's own General → Keybindings tab, which launcher-§6 requires
  beside it and which `docs/settings-panel.md:17` lists.
- **Fix direction:** append "or under Settings → General → Keybindings" to that sentence.

### DRW-15: the simulator's movable stand-in popup is not toplevel

- **Section:** frame-layering-§4 (**MUST**: a movable window calls `SetToplevel(true)`); anti-pattern
  #103.
- **Grade:** Low. Cosmetic, and only reachable during a simulated roll. Clicking a stand-in does not
  raise it over its ALERT-strata peers, including another stand-in.
- **Description:** `modules/RollPopup.lua:511-535`'s `buildStandIn` makes the frame through
  `skinned()` (`:270-276`, which sets the strata only). It then calls `SetMovable(true)` and wires a
  drag (`:515-522`), but never `SetToplevel(true)`. The main window does call it
  (`modules/Window.lua:479`).
- **Fix direction:** add `f:SetToplevel(true)` beside `SetMovable(true)` in `buildStandIn`. The
  stand-in could arguably be classed as a non-window preview stand-in that imitates a client frame. If
  the owner reads it that way, record that instead (U-2 asks the standard).

### DRW-16: the v1.120.0 re-vendor has no bundle

- **Section:** audit-review-history (**MUST**: every re-vendor commit has its `docs/revendor/`
  bundle).
- **Grade:** Low. A record only.
- **Description:** the comparison of the two listings, recorded in `03_EVIDENCE.md`, finds 36
  vendored tags against 35 recorded, and the one gap is **v1.120.0**. Commit `161927d` ("D1:
  re-vendor LibKa0s v1.120.0") rolled `CLAUDE.md:48` with no
  `docs/revendor/2026-11-28-v1.120.0/`. The newest bundle is `2026-11-28-v1.119.0`.
- **Fix direction:** write `docs/revendor/2026-11-28-v1.120.0/` (`01_DELTA.md` line 1 `Delta:
  LibKa0s v1.119.0 -> v1.120.0`), covering the payload delta (LibKa0s#107, #108, #110, #111, #109)
  and the host follow-through D2 already made.

### DRW-17: `.pkgmeta` accounts for three on-disk dot-entries wrongly

- **Section:** packaging (**MUST**: every root dot-entry present is ignored or justified, and a
  conditional entry follows the folder's presence).
- **Grade:** Low. The packager works from a git checkout, and all three directories are untracked, so
  no downloaded byte changes today.
- **Description:** check (a) prints `NOT IGNORED — .claude`, and check (b) prints `UNACCOUNTED —
  .claude`, `.pytest_cache` and `.ruff_cache`. `.pkgmeta:11` keeps `.claude` commented out with "it
  has none today", but an empty `.claude/` exists (gitignored at `.gitignore:12`). The two tool caches
  ignore themselves from the inside, through their own `*` `.gitignore`.
- **Fix direction:** uncomment `- .claude` and drop "it has none today". Add `- .pytest_cache` and
  `- .ruff_cache`, or a comment beside the ignore list naming them as self-ignoring tool caches. Then
  re-run the three checks. Whether self-ignoring caches owe a line is put to the standard (U-5).

### DRW-18: issue #19 is closed but still labeled `state:untriaged` (Info)

- **Section:** audit-review-history (labels are the issue store).
- **Grade:** Info. A stray label, which is the kind of thing the write commands repair.
- **Description:** `gh issue list` shows #19 ("Separate Item Search into its own Ka0s addon") as
  `CLOSED` with `state:untriaged`. A closed issue should be `state:done` or `state:will-not-do`.
- **Fix direction:** relabel #19 `state:done`, since the split shipped as DropWatcher#19's run.

### DRW-19: the watch list's band dispositions have drifted (derived from DRW-10, Info)

- **Section:** automated-tests-§4; layout-§1 (the on-notice band).
- **Grade:** Info. It does not graduate: same root (an unrefreshed record), same grade.
- **Description:** comparing `docs/automated-tests/RESULTS.md:135-150` with today's tree:
  - `core/Compat.lua` (now 748) and `modules/Window.lua` (977) have left the band.
  - `modules/LootFeed.lua` is 1113, past the "split the re-judge path out next if it passes 1100"
    its own disposition set.
  - `tests/test_window_shell.lua` (1298) and `tests/wow_mock.lua` (1090) are in the band with no
    disposition.
  - `tests/test_test_mode.lua` is at 1445, 55 lines under the cap.

  No function is warned on. Anti-pattern #53 is not met: only one release, 1.1.0, carried the
  Accepted dispositions, and not every entry reads Accepted.
- **Fix direction:** at the next release run, rule on the new band entries. Act on LootFeed's own
  1100 trigger, and split `tests/test_test_mode.lua` before it reaches the cap.

## Upstream notes (not Drop Watcher deviations)

| ID | Repo | Note |
|---|---|---|
| U-1 | WowAddonStandards | documentation-§1 item 1: settle whether a README H1 may name the addon without the brand (DRW-13, option b) |
| U-2 | WowAddonStandards | frame-layering-§4: say whether a draggable **preview stand-in** for a client frame counts as a "movable window" (DRW-15) |
| U-3 | LibKa0s (testkit) | a static kit case: every `core\`/`modules\`/`settings\` path named in a TOC comment exists (DRW-12 survived because nothing reads comments) |
| U-4 | WowAddonStandards | documentation-§3 hub shape vs clients-§4: the mandated per-client feature table (143 lines here) sits in the hub, so a dual-client hub cannot meet roughly 400 lines; name a spill target for it or exempt it from the count (DRW-03) |
| U-5 | WowAddonStandards | packaging check (b): say whether an untracked, self-gitignored tool cache (`.pytest_cache`, `.ruff_cache`) owes an ignore line, since the packager never sees it (DRW-17) |
| U-6 | WowAddonStandards | `AUDIT.md` step 4's line-ending checks (b) and (c) grep `…eol=crlf$` and `…eol=lf$` directly, and the `$` never matches in a CRLF-pinned `.gitattributes`, so both print nothing for a canonical file; pipe through `tr -d '\r'` as §5's own body check already does |
