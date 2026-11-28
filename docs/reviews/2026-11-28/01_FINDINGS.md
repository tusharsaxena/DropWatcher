# 01 — Findings: `feat/2026-11-27-itemsearch-split` vs `master`

**Verdict: minor issues.** Nothing here blocks shipping a working Drop Watcher. But the branch cannot be tagged as it stands: two LibKa0s release branches both claim `v1.119.0`, and the complexity release gate is red.

**Resolved scope:** `branch`: `git diff master...HEAD` (merge base `7c36f40`, HEAD `a4258eb`, 39 commits, 199 files, +8713 / -30477). That covers Drop Watcher moving onto `LibKa0s-Verdict-1.0` and Item Search being cut out. Step 0b measured the whole addon. Vendored `libs/` and `tests/_kit/` were reviewed only where the addon wires them (descriptor, stub, provenance).

Profile: `dev-copilot-profile` printed `profile=wow kind=addon`. The Clients value is `retail+forever` (`roster_clients.py DropWatcher`), so both kit profiles were run.

## Measurement run

All runs were made from the repo root on 2026-11-28 at HEAD `a4258eb`. Output went to a scratch path; nothing was written into the repo.

| Suite | Result | Command |
|---|---|---|
| luacheck | **pass**: 0 warnings / 0 errors in 263 files | `~/.claude/dev-copilot/bin/ka0s-bounded luacheck .` |
| Headless suite, Retail | **pass**: 2669 passed, 0 failed, 8 skipped (2677 total) | `~/.claude/dev-copilot/bin/ka0s-bounded lua tests/run.lua` |
| Headless suite, WoW Forever | **pass**: 2556 passed, 0 failed, 116 skipped (2672 total) | `KA0S_KIT_CLIENT=forever ~/.claude/dev-copilot/bin/ka0s-bounded lua tests/run.lua` |
| Seed contract | **pass**: 22 passed | `timeout 300 python3 -m pytest -q tools/seeds -p no:cacheprovider` |
| Fresh `--list` inventory | **pass**: Total 2669, Skipped 8. Identical to the committed `docs/test-cases.md` after CR normalization. The README badge `Tests-2669/2669_passing` agrees | `~/.claude/dev-copilot/bin/ka0s-bounded lua tests/run.lua --list` |
| Offline perf (`tests/perf.lua`) | **ran**: 9 scenarios. `refreshCaptureOff`/`On` 11120.0 B, `refreshCompact*` 6768.0, `parseCapture*` 664.0, `showDecisionStoodDown` 0, `insightsCompute` 4957904.0, `rollsPanelRaid` 79392.0. The Off/On pairs match. No scenario covers the verdict view layer | `~/.claude/dev-copilot/bin/ka0s-bounded lua tests/perf.lua` |
| Complexity (sighted, kit rev 65) | **pass (non-gating)**: **4 warnings**, max CCN **20**, 9033 functions, 74705 NLOC, 0 blind files | `~/.claude/dev-copilot/bin/ka0s-bounded bash tests/_kit/run-automated-tests.sh --suite complexity --no-bundle` |
| Complexity names | `RT.FlushOverlaps` 20 (`modules/RowTooltip.lua:159`), `buildMembers` 19 (`modules/TestData.lua:406`), `RC.Left` 17 (`modules/RollCells.lua:187`), `seed` 18 (`tests/test_verdict_golden.lua:123`). The first three warn on `master` too (the same three files from `master` through the sighted shadow). `seed` is new on this branch | the sighted shadow (`lizard_sighted.lua shadow`), then `lizard -l lua -L 1500 -x "./libs/*" -x "./tests/_kit/*" .` |
| `make test` | not applicable (no root `Makefile`) | — |
| Vendor sync, `libs/LibKa0s` | **clean** against LibKa0s `feat/2026-11-27-itemsearch-split` @ `110e02be` (local = origin). No content diff; the only differences are the icons the declaration prunes. **The in-suite gate did not compare it**: both payload cases are declared skips (F-002) | `git -C ../LibKa0s archive 110e02be LibKa0s testkit` to scratch, then `diff -rq libs/LibKa0s <scratch>/LibKa0s` |
| Vendor sync, `tests/_kit` | **clean** against the same ref | `diff -rq tests/_kit <scratch>/testkit` |
| Cross-addon 1: slash tokens | **clean**: 36 roots over the 19 roster addons, no duplicate, no raw `SLASH_*` in loaded source. DW contributes `dw`, `dropwatcher` | the two loops of the overlay's class 1, over the `ADDONS.md` roster |
| Cross-addon 2: vendored minors | **split** (19 consumers, several lines). Most of the split is the expected re-vendor sweep (provenance tags v1.113.0 to v1.119.0). One part is a real collision: **DropWatcher and LootHistory both name `v1.119.0`, with different payloads** (F-001) | the overlay's class 2 loop |
| Cross-addon 3: payload bytes | DW vs LootHistory: `DebugLogDiagnostics.lua` and `LibKa0s.xml` differ beyond CR, at the **same** `DIAG_MINOR = 13`. DW vs ItemSearch: identical outside `media/` | `diff -rq DropWatcher/libs/LibKa0s LootHistory/libs/LibKa0s` and `diff <(tr -d '\r' < …) <(tr -d '\r' < …)` |
| Cross-addon 4: `## Interface:` | **clean per slot**: Retail `120105` only, Forever `16001` only. DW carries `120105, 16001` | the overlay's class 4 loop |
| Standards cross-check | fetched over the network: **WowAddonStandards v2.121.0** (2026-11-25), 32 section files. The sibling checkout was not used because its HEAD `b83f039c` lags origin `e23dcd5f` | `curl -fsSL … $RAW/standards/STANDARDS.md` and the linked sections |

**Committed artifacts that disagree with today's run:**

- `docs/automated-tests/RESULTS.md:117` says "Max CCN **15** across 9196 functions, **0** of them warned on", current as of bundle `20261116-102800`. The runner reports that bundle measured `c03cddd`, "196 commit(s) behind HEAD". Today: 4 warnings, max 20, 9033 functions. This is stale, not non-compliant: it is regenerated at release.
- `docs/test-cases.md` and the README badge: no disagreement.
- `docs/performance.md`: the refresh pairs (11120.0 / 6768.0), the parse pair and `showDecisionStoodDown` match its latest re-run block. No disagreement.

## Medium

### F-001 `[cross-addon]` `[upstream]` Two LibKa0s release branches both ship as `v1.119.0`, each taking `DebugLogDiagnostics` minor 13 with different bytes

- **Where:** `CLAUDE.md:48` ("Bundles [LibKa0s](https://github.com/tusharsaxena/LibKa0s) v1.119.0 (MIT).") and `libs/LibKa0s/DebugLogDiagnostics.lua:50` (`local DIAG_MINOR = 13`). The line-95 major list includes `"ForeverDB", "Verdict", "Glow", "Toast", "Callout"`.
- **The other side:** `LootHistory/CLAUDE.md` also names `v1.119.0`. `LootHistory/libs/LibKa0s/DebugLogDiagnostics.lua:50` is also `local DIAG_MINOR = 13`, but its line 95 lists `"ForeverDB", "Glow", "Toast", "Feed", "Callout"`. Two branches are involved: LibKa0s `feat/2026-11-27-itemsearch-split` (110e02be) and `feat/2026-11-27-feed` (5c681f34). Their merge base is master `4dbc1636`, and their CHANGELOGs both open `## v1.119.0`.
- **Problem:** LibStub admits a file only if its minor is higher. With the same minor and different bytes, the copy that loads first wins.
- **Impact:** Whichever addon loads second runs the other's diagnostics header. Today that only means the identity line leaves out `Feed` or `Verdict`; the minor's own comment says "No member change". At release, one of the two branches must become `v1.120.0` with DIAG minor 14. The consumer that loses that race then names a tag whose payload it does not carry. The plan's builder note B1 (`docs/superpowers/plans/2026-11-27-itemsearch-split.md:117`, item 2) records this collision, but nothing in the repo gates it.
- **Reachability:** Only someone running both pre-release branch builds of DropWatcher and LootHistory in one session (the owner's test client). DropWatcher loads first alphabetically, so LootHistory gets DW's header. No shipped build is affected yet. It becomes a release-coordination fault at task G1.
- **Fix direction:** Fix this in LibKa0s, not here. Merge one branch, re-bump the second to the next semver and DIAG minor 14 with both majors in the list, then re-vendor whichever consumer ends up on the renumbered tag as its own commit. Never edit `libs/` in place.

### F-002 `[tests]` The vendor-sync gate's payload cases are hand-converted to declared skips; the shim is broader than its stated purpose and is not in the deviation register

- **Where:** `tests/test_vendor_sync.lua:40-51`. The trigger is `local preTag = tag ~= nil and resolves("HEAD:LibKa0s/Core.lua") == true and resolves(tag .. ":LibKa0s/Core.lua") == false`. It then registers `T.test("libs/LibKa0s is the LibKa0s release CLAUDE.md says this addon bundles", never, reason)` and the `tests/_kit` case as skips. The header at `:5` still reads "The comparison is the kit's; nothing is reimplemented here."
- **Problem:**
  - This branch edited a test so a red gate would go green: the re-vendor summary records both cases failing before the shim.
  - The trigger is not limited to "v1.119.0 before IS-G1". **Any** provenance tag the sibling cannot resolve now registers a skip, a typo in `CLAUDE.md`'s version included. The kit fails that case (`tests/_kit/vendor_sync.lua:696`: "a missing tag, a missing file, an extra file or a content difference all FAIL").
  - The shim hand-rolls part of the kit's ref logic (`resolves`, `provenanceTag`) beside the kit, contradicting its own header.
  - `docs/ARCHITECTURE.md` → `## Documented deviations` has no row for the gate's temporary weakening or for vendoring an untagged payload.
- **Impact:** Today's run did not compare the shipped `libs/LibKa0s`. I diffed it by hand (clean, see Measurement run), but the gate itself proved nothing, and it will keep proving nothing for any future tag mistake until the shim is removed.
- **Reachability:** Test inventory only. The shipped code is the payload I diffed and found clean, so this is capped at Medium.
- **Fix direction:** Narrow the shim to the one tag it exists for, or drop it at G1 as the plan intends. Add a `## Documented deviations` row (testing-§11 / library-stack-§7) with re-check trigger "LibKa0s v1.119.0 tagged" until then. Never weaken the kit or edit `tests/_kit/`.

### F-003 `[design]` 33 `NS.Compat` reads exist only to override `LibKa0s-Verdict-1.0`'s `lib.Reads` by name match, with no parity check

- **Where:** `core/VerdictSetup.lua:129-132`:
  ```lua
  local reads = setmetatable({}, { __index = function(_, name)
      if ITEM_READS[name] then return NS.Item and NS.Item[name] end
      return NS.Compat[name]
  end })
  ```
- **Census:**
  - **Scope:** authored, shipped Lua outside the Compat family (`git ls-files '*.lua' | grep -vE '^(libs/|tests/|core/Compat)'`), checked against every `function R.<name>` in `libs/LibKa0s/VerdictReads.lua` (53 names).
  - **Result:** 50 of the 53 have a same-named `NS.Compat` member. **33** of those have no direct caller in that scope: they reach Drop Watcher only through the engine. They are `BagItemLevelQuality`, `CanRequestItemLoad`, `CanRequestSpellLoad`, `GetItemSpecs`, `GetItemStats`, `GetItemUniqueness`, `GetItemUpgradeInfo`, `IsItemBindToAccount`, `IsItemBindToAccountUntilEquip`, `IsToy`, `ItemClassRestriction`, `ItemOpens`, `ItemPrimaryStats`, `ItemUseText`, `MountCollected`, `MountFromItem`, `PawnClassScales`, `PawnCustomScale`, `PawnItemData`, `PawnItemValue`, `PawnUpgradeInfo`, `PetCollected`, `PetSpeciesFromItem`, `PlayerHasTransmog`, `PlayerSpecID`, `PlayerTalentTree`, `ProfessionSkillLines`, `ReadTooltipLine`, `RecipeKnown`, `RequestSpellLoad`, `TalentTreeNames`, `TierTokenSlot`, `ToyCollected`.
  - **Tests:** a grep over `tests/` finds no test referencing `Verdict.Reads` or `lib.Reads`.
- **Problem:** Two implementations of each read are kept, the library's and this addon's, and the addon's wins for any matching name. That covers the deliberate cases (the `PlayerRole` override, the simulator's seam) and also any member that merely shares a name. Nothing checks that the two still agree in arguments, returns or secret-safety.
- **Impact:** This is a drift hazard. A library minor that changes a read's contract (say `ItemUseText`'s second return) is silently shadowed by Drop Watcher's older copy, so Drop Watcher and Ka0s Item Search judge the same item differently. Avoiding that was the stated purpose of the split.
- **Reachability:** No player today: both copies agree at this tag, as far as the golden suite's read half shows. It becomes a real fault the first time either side changes a read.
- **Fix direction:** Make the override explicit: name the reads Drop Watcher must own (role, plus whatever the simulator must guard), and add a parity test over the rest. Or have the seam wrap `lib.Reads` so the 33 duplicates can go. Either way the change lands in the addon's own host, never in `libs/`.

### F-004 `[tests]` The golden suite's kernel half duplicates the library's own golden suite over a hand-copied fixture

- **Where:** `tests/test_verdict_golden.lua:1-5` ("The library's own golden suite ports the same table unchanged") and `tests/fixtures/verdict_golden.lua`. With CR stripped, the fixture is byte-identical to LibKa0s `110e02be:tests/fixtures/verdict_golden.lua`. `docs/test-cases.md:1694` lists `test_verdict_golden.lua (64)`.
- **Problem:** Once the move is complete, the `cases` (kernel) half runs `lib.Evaluate` through views with no logic of their own (`core/VerdictViews.lua:6` says so). That is coverage the vendored library owns (testing-§8). The fixture is a second copy across repos, and no gate checks that the copies stay identical.
- **Impact:** A fix to the kernel has to land in two fixtures. The badge counts library verdicts as this addon's coverage. A drifted copy reads as a regression on one side only.
- **Reachability:** Test inventory only. The plan intends it as a move-time cross-check, so Medium.
- **Fix direction:** After G1, keep the `me` (read/integration) half here and drop or reduce the `cases` half to a handful of wiring checks (the client named, the opts unwritten). If the pin is kept, add an identity check against the library's fixture at the provenance tag. The README badge and `docs/test-cases.md` move in the same change.

### F-005 `[complexity]` Four functions above CCN 15. The branch adds `seed` (18), which the library already split in its own copy

- **Where:** `tests/test_verdict_golden.lua:123` (`local function seed(m, s)`, CCN 18). Three are pre-existing on `master`: `modules/RowTooltip.lua:159` (`function RT.FlushOverlaps(tip, row, group)`, 20), `modules/TestData.lua:406` (`local function buildMembers()`, 19) and `modules/RollCells.lua:187` (`function RC.Left(roll, now, rollID)`, 17).
- **Problem:** The release gate (automated-tests-§3, *The release gate*: zero functions above CCN 15) is red at HEAD. LibKa0s commit `55a7c6dc` ("IS-B4: split the golden suite's seed below CCN 15") fixed the same function in the library copy. Drop Watcher's copy was not given the same split.
- **Impact:** `/dev-copilot:bump-version` will refuse the tag. The committed watch list (`docs/automated-tests/RESULTS.md:117`) shows 0 and hides this.
- **Reachability:** Release gate and maintainers only. No runtime effect.
- **Fix direction:** Port LibKa0s's `seed` split. The three pre-existing ones are outside this branch's scope; they are listed only so the release gate's count is complete.

## Low

### F-006 `[dead-code]` `tools/seeds` `apply` can no longer apply anything; its writer survives on a fixture-only test

- **Where:** `tools/seeds/seeds.py:112` (`CLASS_DATA = "libs/LibKa0s/VerdictClassData.lua"`) is now both flavors' `seed`. `:893` reads `if spec["seed"].startswith(VENDORED):` and raises `SystemExit`. `tools/seeds/test_seeds.py:269` (`test_apply_writes_weapons_keeps_crlf_and_is_idempotent`) rebinds `FLAVORS["retail"]` to the deleted `core/ClassData.lua` to keep `edit_weapons` exercised.
- **Problem:** No real flavor can reach the CRLF-preserving WEAPONS writer. The tool also validates data this repo no longer owns, so the check belongs beside the data in LibKa0s.
- **Impact:** This is maintenance weight, and the seed contract claims more than it can do.
- **Reachability:** A developer running `seeds.py apply`. It now refuses loudly and correctly.

### F-007 `[dead-code]` Five `NS.Gear` view members have no caller at all, and a sixth is test-only

- **Where:** `core/VerdictViews.lua:190` (`Signature`), `:196` (`Read`), `:204` (`Schedule`), `:206` (`OnEvent`) and `:207` (`OnCombatEnd`) have zero callers. `:194` (`OffSpecGear`) has callers only in `tests/test_gear.lua:353` and `:359`.
- **Census:** `git ls-files '*.lua' | grep -vE '^(libs/|tests/_kit/)' | xargs grep -nE '[.:](Signature|OffSpecGear|OnCombatEnd|OnEvent|Schedule)\('`. The only hits are the definitions, unrelated `DW.OnCombatEnd`, `Toast.OnCombatEnd` and `TT.Schedule`, and the two test lines.
- **Problem:** The view mirrors the deleted `modules/Gear.lua` surface rather than what the addon reads.
- **Reachability:** Nobody. No runtime effect.

### F-008 `[design]` `NS.ClassData.Install` is a test-only mutator in shipped code, and it puts the views and the instance on different clients

- **Where:** `core/VerdictViews.lua:55-61` (`function CD.Install(list)`). There are no callers in shipped code (grep over non-test Lua). The instance keeps `host.client = CLIENT` (`core/VerdictSetup.lua:168`).
- **Problem:** After `Install(LISTS.retail)` on the Forever profile, every kernel view names `retail` while the instance (facts, gear snapshot, scorer) stays on `forever`. That is a mixed state no client runs, and the suites using `T.retailList` measure it.
- **Reachability:** Test suite only.

### F-009 `[perf]` The verdict host's perf gate is a metatable accessor, and no scenario covers the views' per-call allocations

- **Where:**
  - `core/VerdictSetup.lua:196-198`: `host.perf = setmetatable({ Note = … }, { __index = function(_, k) if k == "on" then return NS.Perf and NS.Perf.on end end })`.
  - The library's `methods:PerfStart()` (`libs/LibKa0s/Verdict.lua:165`) is a colon method that reads `p.on` through it.
  - `core/VerdictViews.lua:69-74` (`withClient`) builds a fresh opts table on every `NS.Evaluate.Evaluate` and `NS.TierTokens.Fold` call.
- **Problem:** The dormant bracket on `gear.rebuild` costs a method call plus an `__index` function call while capture is off. Bracket hygiene expects a plain boolean field read. The extra table per verdict is unmeasured: `tests/perf.lua` has no judge scenario.
- **Reachability:** Every player, on every gear rebuild (throttled to 0.5 s) and every verdict. The per-call cost is tiny; **unverified** for lack of a scenario.
- **Fix direction:** On the host side, pass a table with a real `on` field kept in step with `NS.Perf`, or `NS.Perf` itself if its shape matches. The `PerfStart` colon-method shape is the library's (`[upstream]`, LibKa0s).

### F-010 `[error-handling]` `NS.VerdictEnable` runs ahead of settings registration, and its re-raise drops the traceback

- **Where:** `core/VerdictSetup.lua:211-216` (`local ok, err = pcall(NS.VerdictEngine.StandUp, NS.VerdictEngine)` … `if not ok then error(err, 0) end`). It is called at `core/DropWatcher.lua:757`, before `self.Settings.Register()` at `:760`.
- **Problem:** A throw from the instance's stand-up aborts `OnEnable` before the settings category registers, so the panel the player would use to turn the addon off is gone too. `error(err, 0)` also discards where it came from.
- **Reachability:** Nobody today: no known stand-up throw. It matters only for a future library minor.

### F-011 `[dead-code]` Schema steps 16 to 19 reshape and then delete Item Search data that no tagged release ever stored

- **Where:** `core/Database.lua:474-477` (`{ to = 17, run = function(sv) NS.RetireItemSearchRows(sv) end }`, step 18's `NS.MigrateGatheredSection(profile)`, `{ to = 19, … }`). Also `NS.MigrateTipRows` (`:389-397`). `git show 1.1.0-release:core/Database.lua` has no step past 9. `git show 1.1.0-release:DropWatcher.toc | grep -ci itemsearch` prints 0.
- **Problem:** After this branch, step 17 deletes everything step 16 reshapes and step 18 then reads. Step 19 repeats step 17. Only the owner's development SavedVariables can carry any of it.
- **Reachability:** Only the developer's own SavedVariables. A comment-level cleanup.
- **Note:** Not a data-loss finding, because the deleted data never shipped. The owner's split ruling R5 (no migration into Ka0s Item Search) is respected.

## Upstream findings (do not land in this repo)

- **F-001** (above). LibKa0s release coordination, `LibKa0s/DebugLogDiagnostics.lua`, between the two `v1.119.0` branches.
- **F-012 `[upstream]` LibKa0s testkit.**
  - **Where:** `testkit/vendor_sync.lua`, vendored at `tests/_kit/vendor_sync.lua:696-706`.
  - **Problem:** The kit fails a payload case when the sibling is present but the provenance tag is missing. testing-§11 says the case "**MUST** register as a **skip carrying its reason** when the precondition is absent — the sibling checkout is not there, or the ref cannot be resolved."
  - **Why it matters:** The kit and the standard disagree, and F-002's local shim exists because of that gap.
  - **Reachability:** Test inventory only, for any consumer vendoring before a tag. **Low.**
  - **Fix direction:** Decide in WowAddonStandards or LibKa0s which is right. If the kit changes, bump the kit revision and re-vendor `tests/_kit/` as its own commit. **Not a local edit.**
- **F-009** (part). The library's `PerfStart` is a colon-method gate (`LibKa0s/Verdict.lua:165`). Fix it upstream with a minor bump, then re-vendor.

## Counts

Critical 0 · High 0 · Medium 5 (F-001 to F-005) · Low 7 (F-006 to F-012). F-001 is counted once although it is also listed as upstream.

## Coverage cross-check

- There are no Critical or High findings to check against the inventory.
- `tests/test_verdict_setup.lua` was read for tests that cannot fail:
  - Its library-absent case (`:215`) really loads without the library (`skip = T.loadAddon.libFiles`) and compares the stand-in against the live instance's metatable surface, so it is falsifiable.
  - It does not compare the **library** stand-in (`stubLib`) against the members `core/VerdictViews.lua` reads. By hand every member is present: `ClassData.ForClient/LISTS`, `Evaluate`, `Equippability`, `ItemVerdict`, `TrackDelta`, `SubClassKey`, `OffSpec.*`, `TierTokens.*`, `ItemRead.*`, `Facts.TrackTier`, `Gear.THROTTLE/SlotsFor`, `Score.*` and `Collect.*`. Recorded as a non-finding.
- `tests/test_bindings.lua:73` asserts a negative (no `DropWatcherItemSearch` button). It carries a `red under:` comment, and the deleted positive test proved the mock files named frames, so it can fail.
