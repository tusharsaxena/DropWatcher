# Findings — Ka0s Drop Watcher, whole-addon review (2026-11-28, second pass)

**Verdict: minor issues.** No Critical or High finding. Three Medium and two Low in Drop Watcher's own
code and suites, plus one Medium cross-addon finding whose fix lands in LibKa0s and LootHistory.

**Resolved scope:** the whole addon at `c7b9bbc` (branch `feat/2026-11-28-audit-review`, clean tree):
`core/`, `modules/`, `settings/`, `defaults/`, `locales/`, `tests/` (minus `tests/_kit/`), `tools/seeds/`,
the TOC and `Bindings.xml`. `libs/` and `tests/_kit/` were read only to review the addon's seams and
to check vendor sync. The frozen bundle `docs/reviews/2026-11-28/` was read as evidence and not edited.

## Measurement run

Every Lua run went through `~/.claude/dev-copilot/bin/ka0s-bounded` (written `ka0s-bounded` below), from
the repo root, with output written to a scratch path outside the repo. The addon is `retail+forever`
(`roster_clients.py DropWatcher`), so the suite ran on both kit profiles.

| Suite | Result | Command |
|---|---|---|
| luacheck | **pass**: 0 warnings / 0 errors in 263 files | `ka0s-bounded luacheck .` |
| Headless suite, Retail | **pass**: 2648 passed, 0 failed, 6 skipped (2654) | `ka0s-bounded lua tests/run.lua` |
| Headless suite, WoW Forever | **pass**: 2535 passed, 0 failed, 114 skipped (2649) | `KA0S_KIT_CLIENT=forever ka0s-bounded lua tests/run.lua` |
| Test-case inventory | **fresh = committed**: `diff` of the CR-stripped `docs/test-cases.md` against the fresh list is empty; Total 2648 = README badge `Tests-2648/2648` (`README.md:7`) | `ka0s-bounded lua tests/run.lua --list > <scratch>` |
| Seed contract | **pass**: 14 passed | `python3 -m pytest -q tools/seeds -p no:cacheprovider` |
| Offline perf | **ran** (orientation only): `refreshCaptureOff` 11120.0 B = `refreshCaptureOn` 11120.0 B; compact 6768.0 = 6768.0; `showDecisionStoodDown` 0 B; `parseCaptureOff`/`On` 664.0 B; `insightsCompute` 4957904 B (ceiling 5200000); `rollsPanelRaid` 79392 B (ceiling 95000) | `ka0s-bounded lua tests/perf.lua` |
| Complexity (sighted, kit 67) | **pass**: 0 warnings, max CCN 15, 8942 functions / 74053 NLOC, avg CCN 2.5; the run named no blind or crashed file | `ka0s-bounded bash tests/_kit/run-automated-tests.sh --suite complexity --no-bundle` |
| `make test` | not applicable: no root `Makefile` | — |
| Vendor sync | **clean**: `diff -rq libs/LibKa0s <v1.120.0 extract>/LibKa0s` lists only the declared icon prune and the pruned `media/sounds` (0 non-icon lines besides `sounds`, 0 `Only in libs` lines); `diff -rq tests/_kit <extract>/testkit` is empty; the kit's `test_vendor_sync` cases run (3/3 PASS, not skipped) | `git -C ../LibKa0s archive v1.120.0 LibKa0s testkit \| tar -x -C <scratch>` then the two diffs |
| Cross-addon pass | **1 finding (F-005)**, otherwise clean; detail below | the four collision-class loops, run from the sibling root |

Cross-addon detail. Roster: 19 addons, derived from `WowAddonStandards/standards/ADDONS.md`'s
*In-scope addons* table (sibling checkout). The consumers vendor different tags (v1.113.0 ×14,
v1.114.0 ×2, v1.117.0, v1.119.0 for LootHistory, v1.120.0 for Drop Watcher): mid-sweep, not a fault.
Class 1: 36 roots, no root claimed twice, no raw `SLASH_*` assignment in any TOC-loaded file; Drop
Watcher's are `dw` and `dropwatcher`. Class 2: five distinct minor lines, all explained by the tag
split. Class 3: with Drop Watcher as the reference, the differing `.lua` files are explained by the
tag split except one: `DebugLogDiagnostics.lua` carries **minor 13 with different bytes** in Drop
Watcher and LootHistory (F-005). Class 4: one Retail value (120105) and one Forever value (16001)
across the addons that carry each slot.

Committed artifacts that disagree with today's run:
- `docs/automated-tests/RESULTS.md`: its newest bundle `20261116-102800` measured `c03cddd`, and the
  runner reports it 218 commits behind HEAD (76362 NLOC / 9196 functions there, against 74053 / 8942
  today). It is stale, as expected between releases. Its regeneration belongs to the release.
- `docs/test-cases.md`, `docs/performance.md`: agree with today's run.

Standards cross-check: the network fetch of `STANDARDS.md` **v2.122.0** (2026-11-28) and its 32 section
files. The sibling `../WowAddonStandards` sits at `b83f039` (v2.122.2), ahead of `origin/master`
`1647801`, so it was not used.

## Medium

### F-001 `[design]` `[tests]` The skin notice's combat retry is a 5-second timer that the stand-down does not cancel, and nothing tests it

- **Where:** `core/SkinSetup.lua:597` `local NOTICE_RETRY = 5   -- seconds between asks while the player is in combat`;
  `:620` `if why == "combat" and not noticeWaiting and type(_G.C_Timer) == "table" and _G.C_Timer.After then`;
  `:622` `_G.C_Timer.After(NOTICE_RETRY, function()`.
- **Problem:** when `O.SkinNotice` answers `combat`, the host arms a `C_Timer.After` that cannot be
  canceled, and arms it again every 5 s for the rest of the fight. `NS.StandDown`
  (`core/DropWatcher.lua:140`) puts out the picker's fuse (`:150` `if NS.ArmSkinPicker then NS.ArmSkinPicker(false) end`
  → `core/SkinSetup.lua:666` `if pickerFuse then pickerFuse:Cancel(); pickerFuse = nil end`) but cannot
  reach this timer. The addon already has the combat-end edge this needs: `NS.SkinPickerCombatEnd`
  (`core/SkinSetup.lua:657` `function NS.SkinPickerCombatEnd()`) is what the picker's own combat hold uses.
  The library's contract asks for the edge too: `libs/LibKa0s/OptionsSkinPicker.lua:1328`
  `--- recorded (nil, "combat"): the host asks again after it.` and `:1329`
  `--- so every vendored copy of an addon shares it. No timer: a stand-down must leave nothing armed,`.
- **Impact:** a timer outlives `/dw disable` (slash-commands-§7: *"Every timer, ticker and `OnUpdate`
  is canceled"*). When it fires stood down, it takes the `recordOnly` branch (`:615`
  `O.SkinNotice(nil, noticeStore, true)`), which can write `db.global.skinNotice` (the library's
  `claimed` answer). That is a SavedVariables write while disabled. No suite reaches
  `NS.MaybeShowSkinNotice`: `grep -n 'MaybeShowSkinNotice\|NOTICE_RETRY\|noticeWaiting' tests/*.lua`
  prints nothing.
- **Reachability:** a player whose first skin-notice check of a session falls in combat. That check is
  the login fuse after OnEnable, or a profile switch, copy or reset. The account must not have recorded
  the library's current `SKIN_NOTICE_VERSION`, and the profile must have already seen the picker (an
  unseen profile's picker takes its own combat hold, which re-asks at combat end). Rare, but it happens
  on a normal install.

### F-002 `[tests]` The golden suite's 48-case kernel half re-runs a byte copy of the library's own fixture

- **Where:** `tests/test_verdict_golden.lua:17` `local GOLDEN = dofile("tests/fixtures/verdict_golden.lua")`;
  `:97` `for _, case in ipairs(GOLDEN.cases) do`; `:98` `test("golden kernel: " .. case.name, function()`.
- **Problem:** `tests/fixtures/verdict_golden.lua` is identical, CR-stripped, to LibKa0s v1.120.0's
  `tests/fixtures/verdict_golden.lua`. The command was
  `diff <(git -C ../LibKa0s show v1.120.0:tests/fixtures/verdict_golden.lua | tr -d '\r') <(tr -d '\r' < tests/fixtures/verdict_golden.lua)`,
  which is empty. The 48 `golden kernel:` cases (the count of `^- golden kernel:` in
  `docs/test-cases.md`'s `test_verdict_golden.lua (64)` group) re-judge behavior that
  LibKa0s-Verdict-1.0's suite owns. testing-§8 says the addon **MUST NOT** keep a duplicate copy of
  those cases. The 16 `golden me:` cases are Drop Watcher's own integration (its reads, its feed's
  `JudgeMe`) and are not in question.
- **Impact:** two suites over one behavior. A library change that legitimately moves a verdict reddens
  Drop Watcher's gate until the copy is hand-synced. The copy has no vendor-sync pin, so it will drift
  silently the first time only one side is edited.
- **Reachability:** only the test inventory. No shipped behavior changes, so it is capped at Medium.
  Deferring this was the owner's call until the tag existed (`docs/reviews/2026-11-28/06_FIX_PASS.md`,
  row F-004: *"Open for G1 / the owner … waits on the tag"*). The tag v1.120.0 now exists, so the
  question is ready to be ruled on.

## Low

### F-003 `[error-handling]` Seven pcall-and-re-raise sites drop the original stack

- **Where:** `core/DropWatcher.lua:78` `if first ~= nil then error(first, 0) end`;
  `core/SkinSetup.lua:571` `if not ok then error(err, 0) end`; `modules/HistoryRetention.lua:237`
  `if not ok then error(err, 0) end`; `modules/LootFeed.lua:745` `if not ok then error(id, 0) end`;
  `modules/Pending.lua:453` `if not ok then error(err, 0) end`; `settings/Schema.lua:326`
  `error(err, 0)`; `settings/SchemaSetup.lua:191` `if not ok then error(err, 0) end`. Census:
  `git grep -nE 'error\([a-z]+, 0\)' -- core modules settings` (authored, TOC-loaded source) prints these 7.
- **Problem:** each site catches with `pcall`, runs its clean-up, then re-raises the message alone.
  Lua 5.1's `pcall` has already unwound the stack, so the error report's stack is the re-raise frame's.
- **Impact:** the message keeps its `file:line` prefix, but the call chain that led there is lost. For
  `OnSharedFeatureEvent`, the dispatcher behind GROUP_ROSTER_UPDATE, PLAYER_ENTERING_WORLD and the other
  shared events, a report shows the dispatcher, not which module's handler path raised.
- **Reachability:** any player who hits a Lua error inside one of these seven paths. The report still
  names the raising line, so diagnosis is slower but not blocked.

### F-004 `[ux]` `[locale]` Two refusal reasons have no words, so chat would print the internal key

- **Where:** `core/DropWatcher.lua:371` `why = why and why:format(target or "?") or tostring(reason)`
  (also `:431` and `:507`); the reasons without a table entry are `modules/Asks.lua:389`
  `if NS.Collectibles.IsFeedOnly(rec) then return refused("collectible") end` and
  `modules/Messaging.lua:202` `if not validRequest(book, req) then return refuse("badRequest") end`.
- **Problem:** `ASK_REFUSAL`, `ASK_ML_REFUSAL` and `SEND_REFUSAL` have no `collectible` or `badRequest`
  entry, so the fallback prints the raw key (`Not asked: collectible`). `A.Preview` also lacks the
  `collectible` refusal that `A.Request` makes, so the two do not agree on what may be asked
  (`modules/Asks.lua:410` `local who, why = recipient(kind, target, isTest(rec))` follows straight on
  from the ML check).
- **Impact:** an untranslated, unexplained token in chat, if that line is ever reached.
- **Reachability:** nobody through a drawn control today. A feed-only collectible draws no Ask
  (`modules/WindowCells.lua:852` `if NS.Collectibles.IsFeedOnly(drop) then return { row(L["Why"], NS.CollectCells.NO_ASK) } end`)
  and no Offer (`modules/OfferPanel.lua:384`), and auto-ask calls `A.Request` without printing. It
  becomes reachable the first time a new surface (a keybind, a verb) calls `NS.PressAsk` directly.

## Upstream and cross-addon findings (these do not land in Drop Watcher's own files)

### F-005 `[cross-addon]` `[upstream]` LibKa0s-DebugLogDiagnostics minor 13 has two byte sets in the field: Drop Watcher's (the tag's) and LootHistory's (the Feed branch's)

- **Where:** Drop Watcher `libs/LibKa0s/DebugLogDiagnostics.lua:50` `local DIAG_MINOR = 13`, `:51`
  `-- Minor 13 (DropWatcher#19, task B1 of the Item Search split): the identity header names`. The
  LibKa0s tags v1.119.0 and v1.120.0 carry the same text. LootHistory
  `libs/LibKa0s/DebugLogDiagnostics.lua:50` is also `local DIAG_MINOR = 13`, but `:51` reads
  `-- Minor 13 (LootHistory#38, task S1 of the Feed build): the identity header names`, and its running
  majors list (`:95`) names `"Feed"` where Drop Watcher's names `"Verdict"`. LootHistory's `CLAUDE.md`
  names v1.119.0. The difference survives `tr -d '\r'`, so it is not a line-ending artifact.
- **Problem:** LibStub admits a file only at a higher minor. Whichever addon loads first owns minor 13,
  and the other silently runs that copy. This is the hazard class 2/3 exists for (the same minor with
  different bytes), and the earlier bundle's F-001 is now live, not latent.
- **Impact:** with both loaded, Drop Watcher loads first alphabetically, so LootHistory's diagnostics
  identity header runs Drop Watcher's copy. That copy names LibKa0s-Verdict-1.0 and omits
  LibKa0s-Feed-1.0. Drop Watcher's own report is unaffected.
- **Reachability:** any player running Drop Watcher and LootHistory together who opens LootHistory's
  diagnostics. Drop Watcher loads first and LootHistory gets Drop Watcher's DebugLogDiagnostics.
- **Owner:** LibKa0s (the Feed branch takes the next version and `DIAG_MINOR = 14`, the renumber the
  2026-11-28 issue-fix plan already calls for: *"the other session's Feed and lh-farm branches renumber
  after"*), then LootHistory re-vendors. Nothing changes in Drop Watcher.

## Checked and clean (no finding)

- Every SavedVariables write goes through the schema seam. The one raw write is a migration
  (`core/Database.lua:413`).
- No raw `print` outside the library-absent fallback in `core/CoreSetup.lua`.
- No literal strata or level.
- No deprecated API from the checklist.
- No `WOW_PROJECT_*` read outside `core/Compat.lua`.
- Every `C_Timer.NewTimer`/`NewTicker` handle is canceled by its module's `NS.STAND_DOWN` step. F-001's
  `C_Timer.After` is the exception.
- `Bindings.xml` is one binding, with the category and no `header=`/`default=`.
  `BINDING_HEADER_DROPWATCHER = NS.BRAND` is at file scope.
- The verdict seam's stand-in covers every `NS.Verdict`/`NS.VerdictEngine` member the addon calls. The
  exceptions are `NS.Verdict.Settings`/`.C`, whose callers guard them (`defaults/Profile.lua:159`), and
  `NS.VerdictEngine.R`, read only under `if V and Sim` (`core/VerdictSetup.lua:200`).
- None of the 32 Compat reads deleted in `4514c64` has a caller left.
