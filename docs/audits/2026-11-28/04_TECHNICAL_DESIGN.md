# Technical design: Ka0s Drop Watcher remediation (standards audit, 2026-11-28)

Keyed to `02_DEVIATIONS.md`. Nothing here touches `libs/` or `tests/_kit/`. One item changes shipped
Lua (DRW-15, one line). One changes a test (DRW-04). Everything else is docs, the TOC's comments,
`.pkgmeta` or issue labels.

## 1. Code and tests

### DRW-15: make the stand-in toplevel

- `modules/RollPopup.lua`, in `buildStandIn` (`:511-535`): add `f:SetToplevel(true)` directly after
  `f:SetMovable(true)` (`:515`), with the comment `-- a click raises it among its ALERT peers
  (frame-layering-§4)`.
- Test: in `tests/test_roll_popup.lua` (or `test_sim_*`, wherever the stand-in is built), assert
  `RP.StandIn(1):IsToplevel()`. This needs the mock's frame to record `SetToplevel`. If the kit mock
  lacks `IsToplevel`, assert on the recorded call instead, and file the mock gap against LibKa0s's
  testkit rather than patching `tests/_kit/`.
- Risk: none. A toplevel frame is raised among peers of its own strata only.
- Alternative: if the owner reads the stand-in as a preview stand-in, not a window, record that
  ruling and raise U-2 upstream, with no code change.

### DRW-04: step 5 takes `F_on`

- `tests/test_disabled.lua` case 2 (`:118-135`): before `way[2](NS)`, open the surfaces a player can
  have up: `NS.SetTestMode(true)` (already there; the window), `NS.RollsPanel.Toggle()`, and a
  test-mode toast where the profile allows one. Then take
  `local F_on = {}; for _, f in ipairs(m.__shownFrames()) do F_on[#F_on+1] = f end`, with a
  non-empty assertion. After the disable, assert each `F_on[i]:IsShown() == false` by name. Add
  `-- red under: drop modules/RollsPanel.lua's NS.STAND_DOWN step`.
- Name the mutation in the comment, so the case has a way to go red (testing-§12). Run both profiles,
  since the Rolls panel exists on both.

## 2. TOC comments

### DRW-12: name the live source of the verdict rows

- `DropWatcher.toc:263`, `:293` and `:545`: replace `modules\Gear.lua's` with `core\VerdictSetup.lua's
  (the verdict engine's rows)`. Keep each line's CRLF ending. The `test_eol` gate catches a
  conversion.
- Optional static guard: a host case, `tests/test_toc_comments.lua`, that parses the TOC and asserts
  every `(core|modules|settings|locales|defaults)\X.lua` it names exists. The kit already owns TOC
  parsing, so the durable home is a kit case (U-3, LibKa0s). Until that exists, a local case is
  allowed, because it does not shadow a kit suite.

## 3. Docs

### DRW-03: spill the hub

- Move `docs/ARCHITECTURE.md` `## Event Subscriptions` (`:368-473`, its table and *The simulator on
  LibKa0s-Sim-1.0*) into `docs/data-flow.md` under a matching heading. In the hub, leave a 5-10 line
  pointer that keeps the `NS.FEATURE_EVENTS` and `SafeRegisterEvent` summary.
- Move `## Skins` (`:544-682`) and `## Tooltip placement` (`:475-523`) into a new Tier 3 doc,
  `docs/skins.md`, or into `settings-panel.md` if the owner prefers. Register the new doc under
  `### Addon-specific` with a one-line pointer left in the hub.
- Keep the per-client table in the hub (clients-§4 requires it there). Raise U-4.
- After the moves, re-run the map coverage check (`03_EVIDENCE.md` §Docs shape) and re-read every
  `docs/ARCHITECTURE.md#…` anchor that other docs link to (`grep -rn 'ARCHITECTURE.md#' docs README.md
  CLAUDE.md`).

### DRW-07: re-count the compat family

- `docs/ARCHITECTURE.md:806`: rewrite the trigger cell as "The compat family publishes 100
  addon-specific shims as of 2026-11-28 (…per-file…), counted by `cat core/Compat*.lua | grep -cE
  …`". Dating the count follows documentation-§6.
- Check `docs/compat-layer.md` for any per-file count (none was found by this run's grep) and the
  rows for shims the split removed.

### DRW-11: re-ratify the options-ui-§17 row

- Read the current options-ui-§17 (v2.122.0) against the mirrored layout. The companion still sits
  below its swatch, and the new bullets (precedence, preview class, the `disabledIf` MAY) do not touch
  placement. So the row survives. Append "Re-checked 2026-11-28 against v2.119.0 and v2.122.0: neither
  edit moves the companion's placement" to Decided. Change the trigger to "options-ui-§17's placement
  sentence changes, or LibKa0s gains a mirrored color-pair layout", so ordinary edits stop firing it.

### DRW-13: the H1 (owner decision)

- Option (a): add a register row (`documentation-§1 item 1 | README H1 is "# Drop Watcher" | owner
  ruling R6-NAME, Ka0sAddonsCommonTasks docs/2026-11-03-SMOKE_ROUND6/inputs/OWNER_ANSWERS.md |
  2026-11-04 | the standard rules on the H1 (U-1)`).
- Option (b): restore `# Ka0s Drop Watcher` and file U-1. The owner has already ruled for the unbranded
  title, so (a) plus U-1 is the default.

### DRW-14: name both binding places

- `README.md:49`: change "Bind a key under Options → Keybindings → Ka0s Drop Watcher if you like" to
  "Bind a key under Options → Keybindings → Ka0s Drop Watcher, or Settings → General → Keybindings, if
  you like". The README is CurseForge-facing, so no numbered list and no table row.

### DRW-16: the missing re-vendor bundle

- Create `docs/revendor/2026-11-28-v1.120.0/` in the store's usual shape. `01_DELTA.md` line 1 is
  `Delta: LibKa0s v1.119.0 -> v1.120.0`, followed by the per-major deltas the plan ledger lists (#107
  slider range, #108 lazy stand-up, #110 vendor_sync skip, #111 seam wrapping, #109 seed contract,
  kit revision 67) and the host follow-through commits D2/D3 (`02c3507`, `ea0b9d8`, `4514c64`,
  `aa6f0eb`, `77cb9a8`, `bf08c0c`). The bundle is frozen once written.

### DRW-19 (with DRW-10): refresh the record at release

- No action now: the checkpoint is release. At the next `/dev-copilot:bump-version`, the release run
  regenerates `RESULTS.md`. Then rule on the new band rows (`tests/test_window_shell.lua`,
  `tests/wow_mock.lua`), retire the Compat and Window rows, and carry out LootFeed's own 1100 trigger
  (peel the re-judge path), or re-rule it with a date. Split `tests/test_test_mode.lua` (1445) by
  surface before it crosses 1500.

## 4. Config and record

### DRW-17: `.pkgmeta`

- Replace `.pkgmeta:11` with `  - .claude         # dev-only: Claude Code's local state (packaging)`.
  Keep `:12` (`.superpowers`) commented, because that folder really is absent.
- Add `  - .pytest_cache` and `  - .ruff_cache` with a one-word justification. Or, if the owner takes
  U-5's reading, add a comment line naming them as self-ignoring, untracked tool caches.
- Re-run the three packaging checks. All three must print nothing except `.git`.

### DRW-18: relabel issue #19

- `gh issue edit 19 --remove-label state:untriaged --add-label state:done`.

## 5. Upstream

| ID | Repo | Shape of the issue |
|---|---|---|
| U-1 | WowAddonStandards | documentation-§1 item 1: may the README H1 drop the brand while TOC Title, launcher label and in-game paths keep it? Drop Watcher's R6-NAME ruling is the case |
| U-2 | WowAddonStandards | frame-layering-§4: classify a draggable preview stand-in for a client frame |
| U-3 | LibKa0s | testkit: a static TOC-comment path check (a file a TOC comment names must exist) |
| U-4 | WowAddonStandards | documentation-§3 hub cap vs the clients-§4 per-client table that must stay in the hub |
| U-5 | WowAddonStandards | packaging check (b) and untracked, self-gitignored tool caches |
| U-6 | WowAddonStandards | `AUDIT.md` line-ending checks (b)/(c) need `tr -d '\r'` on a CRLF-pinned `.gitattributes` |

## Ordering constraints

- Run DRW-12 before any new TOC row is added, so the edit stays a pure comment change.
- Run DRW-03's spill before DRW-07's rewrite only if `:806` moves. It does not (the map stays in the
  hub), so the two are independent.
- DRW-16's bundle cites the D-commits and should be written before any further re-vendor, so the next
  bundle's base is v1.120.0.
- After every step: `ka0s-bounded lua tests/run.lua`, the Forever profile, `ka0s-bounded luacheck .`
  and `python3 -m pytest -q tools/seeds`. Update the README Tests badge only if the pass count moves
  (DRW-04 and DRW-15 each add cases).
