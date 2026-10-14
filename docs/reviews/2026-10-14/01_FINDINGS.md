# Review findings: Ka0s Drop Watcher (2026-10-14)

**Verdict: minor issues.** Nothing crashes, taints, leaks a secret value or loses saved data, and
the disabled state really is inert (measured below). What is left: one test that cannot fail, one
announce path that skips its own guard, a shared event dispatcher with no per-handler isolation, perf
buckets that nest without saying so, and four low items. Four findings are upstream, in LibKa0s,
the Ka0s WoW Addon Standard and dev-copilot.

**Resolved scope:** the whole addon (`all`), at `3eadd89` on branch
`feat/2026-10-14-drop-watcher-review-audit`, clean tree. Under the standard's census rule the
default scope is `git ls-files '*.lua' | grep -vE '^(libs/|tests/_kit/)'`: 182 authored files, 97 of
them outside `tests/`. The previous review (`docs/reviews/2026-10-11/`, at `87d8694`) was read for
context only. 152 commits have landed since then.

**Standards cross-check:** done against Ka0s WoW Addon Standard **v2.80.0 (2026-10-13)**. The index
and sections came from `raw.githubusercontent.com/tusharsaxena/WowAddonStandards/master` with `curl`.
Some section files had not finished downloading by the time the review needed them. Those were read
from the local `../WowAddonStandards` checkout at `8aad69d`, which is the same v2.80.0. The fetch
finished later in the review, and every fetched section file was then compared byte for byte with
the local copy. All of them matched.

## Measurement run

Every suite ran fresh on 2026-10-14 from the repo root, through `~/.claude/dev-copilot/bin/ka0s-bounded`.
Output went to the session scratchpad and never into the repo. The interpreter was `lua5.1` (`luajit`
is not installed).

| Suite | Result | Command |
|---|---|---|
| luacheck | **pass**: 0 warnings / 0 errors in 169 files | `ka0s-bounded luacheck .` |
| Headless test suite | **pass**: 1402 passed, 0 failed, 1 skipped, 1403 total. The skip is the kit's diagnostics-contract opt-out case, which does not apply to this addon | `ka0s-bounded lua5.1 tests/run.lua` |
| Test-case inventory | **pass**: the fresh `--list` output is identical to the committed `docs/test-cases.md` (`diff` printed nothing), Total 1402 | `ka0s-bounded lua5.1 tests/run.lua --list > <scratch>/list.txt`, then `diff` |
| Offline perf runner | **ran** (not a gate): `refreshCaptureOff` 14240.8 B/iter, `refreshCaptureOn` 14240.8 B/iter and 1.00 notes/iter, `refreshCompactCaptureOff` / `On` 10432.9 B/iter, `showDecisionStoodDown` 0.0, `parseCaptureOff` / `On` 664.2. Each zero-overhead pair matches, so a dormant bracket allocates nothing | `ka0s-bounded lua5.1 tests/perf.lua` |
| Complexity (sighted, kit rev 38) | **pass**: 0 warnings, max CCN 14, 5314 functions, 41618 NLOC, avg CCN 2.4. The newest bundle's manifest records `blindFiles: 0` | `ka0s-bounded bash tests/_kit/run-automated-tests.sh --suite complexity --no-bundle` |
| `make test` | not applicable: there is no root `Makefile` | none |
| Vendor sync | **clean**: `diff -rq libs/LibKa0s ../LibKa0s/LibKa0s` and `diff -rq tests/_kit ../LibKa0s/testkit` both print nothing. `git -C ../LibKa0s diff --stat v1.71.0 HEAD -- LibKa0s testkit` is also empty, so the copies equal the `v1.71.0` tag that `CLAUDE.md` names | as shown |
| Cross-addon pass | **clean** on all four classes at LibKa0s `v1.71.0`. All 14 roster addons name that tag (`$#` = 14, derived from `WowAddonStandards/standards/ADDONS.md`) | the four loops of the review playbook, run from `GIT/` |

Cross-addon detail:

- **Class 1, slash tokens.** The census found 24 roots in 12 addons, no duplicates, and no raw
  `SLASH_*` line in any TOC-loaded file. It **could not see** Drop Watcher's two roots or QuickComms'
  two. Both addons register from constants:
  `core/DropWatcher.lua:518` `self:RegisterChatCommand(NS.SLASH:sub(2), "OnSlashCommand")`, and
  `QuickComms/core/QuickComms.lua:120`. I checked them by hand: `dw`, `dropwatcher`, `qc` and
  `quickcomms` collide with none of the 24. This is the blind spot already noted on 2026-10-11, and
  it is still in the playbook (F-012).
- **Class 2, vendored minors.** All 14 addons print one line:
  `Bus:2 Compat:1 Core:10 DebugLog:19 Env:2 Item:2 Launcher:5 Lifecycle:3 Media:4 Options:28 Perf:14 Pool:3 Schema:2 Slash:20 Widgets:12`.
- **Class 3, payload bytes.** Reference addon AbsorbTracker, 159 files (the tag's `LibKa0s/` also has
  159). No `diff -rq` output for any of the 14.
- **Class 4, `## Interface:`.** One value: `120100`.

Where a committed record differs from today's run:

- `docs/automated-tests/` newest bundle `20261014-133254` was measured at `5996818`, 7 commits behind
  HEAD. It records 5304 functions; today's sighted run counts 5314. Max CCN (14) and the warning
  count (0) are unchanged. The bundle is stale, which is not the same as non-compliant. Release
  regenerates it.
- `docs/performance.md` budgets (14500 / 11500 / 700 B) still hold against today's figures.
- `docs/test-cases.md` and the README badge (`1402/1402 passing`) agree with today's run.

Three extra probes ran in a **scratch copy** of the tree. The repo was not touched.

- **P1.** I wrapped `tests/test_disabled.lua:103`'s two `__fireUnconditional` calls in a `print`.
  Both returned **0**, meaning no handler ran (`FIRE-RAN 0 0`).
- **P2.** I disabled the addon, then called each of the **53** `NS.FEATURE_EVENTS` handler rows
  directly. The result was **0** SavedVariables writes, **0** printed lines, no newly shown frame
  and no error. So the shipped stand-down really is inert, and F-001 is a defect in the test only.
- **P3.** I counted the `NS.FEATURE_EVENTS` rows per event. 10 events have more than one handler:
  `GROUP_ROSTER_UPDATE` 6, `PLAYER_ENTERING_WORLD` 5, `CHALLENGE_MODE_COMPLETED` 4,
  `PLAYER_REGEN_ENABLED` 4, `CHALLENGE_MODE_START` 3, `ENCOUNTER_END` 3, `PLAYER_REGEN_DISABLED` 3,
  `ZONE_CHANGED_NEW_AREA` 3, `BAG_UPDATE_DELAYED` 2 and `ENCOUNTER_START` 2.

---

## Medium

**F-001 [tests] "disabled 3" cannot fail: it fires nothing.**
`tests/test_disabled.lua:99-106`. Line 99 is `test("disabled 3: no SavedVariables write from a game event while disabled", function()`,
line 103 is `m.__fireUnconditional(NS.addon, "PLAYER_REGEN_DISABLED")` and line 105 is
`assertEqual(#m.__svWrites(), 0)`.
- **Problem.** The addon registers `PLAYER_REGEN_*` under the method names `OnCombatStart` and
  `OnCombatEnd`. Once the stand-down unregisters them, the kit's `__fireUnconditional` has no record
  of those handlers and finds no method named after the event. It returns 0 (probe P1). The test
  throws that 0 away, so it asserts on silence.
- **The case is also narrower than slash-commands-§7 step 6 asks.** It fires 2 of the 28 registered
  events, checks only SV writes (no printer calls, no frame shows) and has no `-- red under:` line
  (testing-§12).
- **Impact.** The inventory counts a conformance case that cannot go red. If a handler that writes or
  prints while disabled is added later, this case stays green.
- **Reachability:** Only the test inventory. The shipped code is correct: probe P2 drove all 53
  handlers and saw nothing.
- Measured: probe P1. The kit side of this is F-009 (upstream).

**F-002 [correctness] A fixed announce channel skips the "not in a group" refusal, then confirms a send that went nowhere.**
`modules/Asks.lua:128-136`, with `:130` `if want ~= "auto" then return want end`, and `:235-238`
(`route`), with `:237` `return A.AnnounceChannel(), nil`.
- **Problem.** The file header promises at `:27` that "an announce outside a group fails `noChannel`".
  That is only true for the default `auto`. With `messages.announceChannel` set to `INSTANCE_CHAT`,
  `RAID` or `PARTY`, `route` hands that channel to the sender no matter what group you are in. The
  queued-announce cancel at `:459` (`if a.target == A.GROUP then return not NS.Compat.InGroup() end`)
  checks group membership, but the send path does not.
- **Impact.** The client refuses the message with a system line, not a Lua error, so the `pcall`
  succeeds. The addon then prints "Announced in Party: [item]" and marks the announce `sent`. With
  `Ask once` on (the default), every retry is refused with "You already announced it." for the rest of
  the session. Post my tradeables has the same problem.
- **Reachability:** A player who changes **Announce channel** from Automatic to a fixed channel, then
  presses Announce to group or Post my tradeables while solo or in a group that lacks that channel
  (for example `INSTANCE_CHAT` in a premade group). It is not reachable on the default profile.
- The client's exact reply to a channel it refuses is **unverified** (it cannot be measured headless).
  It is carried as smoke check ANN-1.

**F-003 [design] The shared event dispatcher has no per-handler isolation.**
`core/DropWatcher.lua:57-59`, with `:58`
`for _, method in ipairs(sharedHandlers[event] or {}) do self[method](self, event, ...) end`.
- **Problem.** Ten events are shared between modules (probe P3). On each of them, a raise in one handler
  silently skips every handler after it. `GROUP_ROSTER_UPDATE` has six, in TOC order: Sim,
  Situations, Roster, Inspect, Asks and AutoAsk. One error in the situation edge would leave the roster
  stale, the inspect queue unpruned and asks queued to a member who left. The addon already isolates
  every other fan-out it owns: `modules/Sim.lua:148` (`pcall(DW[row[2]], DW, event, ...)`) and the
  parser's sinks at `modules/LootParser.lua:263` (`pcall(fn, loot)`). The live client path is the
  one that does not.
- **Impact.** It is a latent coupling. A bug in one module turns into missing behavior in five
  unrelated ones, and only the first error is ever reported.
- **Reachability:** Any player, on any shared event, but only after some handler raises. No raise is
  known today: the suite is green and probe P2 ran clean.

**F-004 [perf] `evaluate` and `quality.gate` run inside `feed.add` but are declared flat.**
`core/PerfSetup.lua:24-25` (`{ key = "evaluate" },`, `{ key = "quality.gate" },`), with the brackets
at `modules/LootFeed.lua:225`, `:266` and `:635`.
- **Problem.** On the receipt path, `LF.Receive`'s `feed.add` bracket (`:633-635`) encloses
  `receive → start → judge` (`:507-519`). `judge` calls `judgeMe → evaluate` (`:242`) and
  `qualityGate` (`:516`), so both of those buckets nest inside `feed.add`. Neither declares
  `within`, and neither call site passes the parent argument. performance-§3 makes `within` a MUST.
  Both buckets also run outside `feed.add`: the async item-facts callback (`:529`) and the re-judges
  on InspectDone or GearChanged. They are therefore *sometimes* nested, which the library cannot
  record today (F-010).
- **Impact.** A `/dw perf` report shows three disjoint-looking totals that overlap. Anyone summing
  them counts the verdict and gate time twice.
- **Reachability:** Only a maintainer reading a perf capture. There is no runtime effect, and no
  capture is committed under `docs/perf-analysis/` yet.

## Low

**F-005 [locale] Most of the strings routed through `NS.L` have no entry in `locales/enUS.lua`.**
`locales/enUS.lua:9` (`local L = setmetatable({}, {`, the fallback that returns the key).
- **Problem.** A scan of the 97 non-test authored files finds 1299 `L["…"]` uses and 722 distinct
  keys that are not in `enUS.lua`. The biggest gaps are `modules/WindowCells.lua` (190 uses),
  `modules/DetailCells.lua` (160) and `settings/SchemaRows.lua` (140). Examples:
  `core/DropWatcher.lua:183` "Inspecting %d group members, one at a time." and
  `modules/CompactHistory.lua:117` "Clear history". In the other direction, none of the 327 keys the
  file defines is unused.
- **Impact.** On enUS nothing changes, because the fallback renders the key. But `enUS.lua` is no
  longer the catalog a translator can start from: a `deDE.lua` copied from it would leave about two
  thirds of the UI in English. localization-§1/§3 do not require every key in `enUS.lua`, so this is
  hygiene, not a deviation.
- **Reachability:** Nobody today, since the addon ships English only. Only a future translator.
- **Scope:** a script over `git ls-files '*.lua' | grep -vE '^(libs/|tests/)'`, excluding
  `locales/enUS.lua`. It matches `L["…"]` literals and resolves escapes.

**F-006 [lint] The lint config waves the world reads through for every file, and two optional-addon probes already go around Compat.**
`.luacheckrc:22-30`: the top-level `read_globals` holds `"C_AddOns"`, `"InCombatLockdown"`,
`"GetInstanceInfo"`, `"IsInGroup"`, `"UnitGUID"`, `"UnitName"` and others.
- **Problem.** `docs/ARCHITECTURE.md` says the Compat family is the only caller of these client
  globals ("no other file names those client globals"). But they are declared at the top level, so
  lint would accept a feature module calling `UnitName` directly. Two files already reach past the
  seam: `core/DropWatcher.lua:524` and `modules/Diagnostics.lua:366`, each
  `local loaded = C_AddOns and C_AddOns.IsAddOnLoaded`. That is also two copies of one optional-addon
  probe.
- **Impact.** The seam is enforced by convention only, and the doc's claim is already untrue in two
  places.
- **Reachability:** No runtime effect. It only matters to maintainers.

**F-007 [naming] `NS.SetTestMode`'s doc block is stranded above another function.**
`core/DropWatcher.lua:107-111`. `:107` reads `--- Turn test mode on or off (preview-mode). …`, but the
function that follows at `:113` is `local function refreshPanels()`. `function NS.SetTestMode(on)` is
at `:127`.
- **Impact.** An LDoc or LuaLS reader attaches the `@param on` / `@return changed` block to
  `refreshPanels`.
- **Reachability:** A comment. No runtime effect.

**F-008 [ux] Three wordings for "the addon is off", none of them the dispatcher's.**
- `modules/TradeHelper.lua:31` `stoodDown  = L["Drop Watcher is disabled."],`
- `core/DropWatcher.lua:215` `disabled = NS.L["The addon is disabled."],`
- `modules/DetailCard.lua:60` `disabled = L["the addon is disabled"],`
- The library's refusal is `"%s is disabled — enable it with /dw enable"`, branded "Ka0s Drop
  Watcher" (`libs/LibKa0s/Slash.lua:94`). `NS.ScanGroup` and `NS.RetryInspect` already print
  `NS.SlashCommands:DisabledLine()`.
- **Impact.** The brand is dropped or changed, and the player is not told how to turn the addon back
  on (slash-commands-§7: every refusal is one string).
- **Reachability:** Almost nobody. These are the Ask and Trade refusals while stood down, and the
  window, card and toast that carry those buttons are hidden by the stand-down. A host-API caller
  (`NS.PressAsk`) is the only route.

## Upstream (do not land in this repo)

Each of these is fixed in its own repository, released, then taken here as **its own commit**: a
re-vendor of the whole `libs/LibKa0s/` and `tests/_kit/` folders for LibKa0s, or nothing for the
others. **None is a local edit.**

**F-009 [upstream] [tests] LibKa0s testkit: `__fireUnconditional` cannot reach a handler registered under a method name, and fails silently.**
`../LibKa0s/testkit/mock_record.lua:614-639` (`function M.__fireUnconditional(target, event, ...)`).
Its vendored copy is `tests/_kit/mock_record.lua:614`.
- **Problem.** The function looks in `__scripts`, then `__events` (cleared on unregister), then a
  method named after the event. An AceEvent handler registered as
  `RegisterEvent("PLAYER_REGEN_DISABLED", "OnCombatStart")` matches none of these once it is
  unregistered. The function then returns 0 and does not raise.
- **Why it matters.** The function's own comment calls it "the falsification half". For every addon
  that names its handlers (all of this collection's feature-event tables), it falsifies nothing.
  Callers that ignore the return value, as F-001 does, become vacuous.
- **Reachability:** Only the test inventory, across every consumer's `test_disabled.lua`. 13 of the 14
  roster addons call it, and QuickComms sums the return value.
- **Fix direction.** Keep a per-target record of every handler ever registered for an event, and
  never clear it on unregister. Reach through that record. Raise, rather than return 0, when nothing
  can be reached. Bump `Kit.VERSION`, release LibKa0s, and re-vendor `tests/_kit/` here and in every
  consumer.

**F-010 [upstream] [perf] LibKa0s Perf: `P.Note` cannot record a top-level observation, so a sometimes-nested bucket cannot be recorded truthfully.**
`../LibKa0s/LibKa0s/Perf.lua:669` (`function P.Note(key, ms, parentKey)`). A nil `parentKey` means
"not stated", and an omitted parent defaults to the declared `within`.
- **Problem.** A bucket reached both inside a parent and at top level, like F-004's `evaluate` and
  `quality.gate`, cannot report "observed inside more than one parent". Either it claims nesting it
  only sometimes has, or it claims none.
- **Reachability:** Maintainers reading a capture, in any consumer with such a bucket.
- **Fix direction (additive).** Accept `parentKey == false` as "observed at top level", and feed it to
  the existing `observedMixed` logic, so the report says *observed inside `feed.add` and at top
  level*. Bump the Perf file's minor, release, and re-vendor.

**F-011 [upstream] [tests] WowAddonStandards: slash-commands-§7's conformance step 6 does not require the fire to have reached anything.**
`../WowAddonStandards/standards/standards/slash-commands.md:304` ("6. **Fire every event in `R_on` at
the mock anyway** …").
- **Problem.** The step asks for zero writes, prints and shows after the fire. It never asks the test
  to prove the fire ran a handler. That is the testing-§12 trap the step exists to avoid, and F-001
  passed it vacuously.
- **Reachability:** Doc text. It affects every addon's `test_disabled.lua`.
- **Fix direction.** Add a MUST that each unconditional fire reaches at least one handler (assert
  `__fireUnconditional`'s return value), and require a `-- red under:` line on the step's assertion.
  This is a standard version bump. The addon then conforms through F-001's change.

**F-012 [upstream] [tooling] dev-copilot: the cross-addon slash census is blind to constant-driven `RegisterChatCommand`.**
`../dev-copilot/profiles/wow/agent-review.md:363`
(`xargs -r grep -hoE 'RegisterChatCommand\("[a-z]+"' …`).
- **Problem.** Drop Watcher (`dw`, `dropwatcher`) and QuickComms (`qc`, `quickcomms`) register through
  `NS.SLASH:sub(2)` / `NS.SLASH_ALIAS:sub(2)`. The class-1 census silently omits them, so a collision
  with either would read "clean". This is the second review in a row to cover the gap by hand
  (2026-10-11 did too).
- **Reachability:** Every reviewer running the cross-addon pass. No runtime effect.
- **Fix direction.** Have the census also read `NS.SLASH` / `NS.SLASH_ALIAS` string literals from
  each addon's TOC-loaded `core/Namespace.lua`, or match `RegisterChatCommand(` generically and
  resolve constant arguments. Then re-sync the plugin cache.

## Counts

Critical: 0 · High: 0 · Medium: 8 (F-001, F-002, F-003, F-004, F-009, F-010, F-011, F-012) · Low: 4
(F-005, F-006, F-007, F-008). Of these, 4 are upstream (F-009..F-012).
