# Item Search Split Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Ship Ka0s Item Search as its own Forever-only addon on a new `LibKa0s-Verdict-1.0` major, and cut Item Search out of Drop Watcher (DropWatcher#19).

**Architecture:** Drop Watcher's "my verdict on this item" engine is de-tangled in place, then moved into a LibKa0s major that each addon instantiates with `New(host)`. Drop Watcher moves onto it with no behavior change (golden tests), Item Search is scaffolded on the standard and ported on it, then Drop Watcher drops Item Search.

**Tech Stack:** Lua 5.1 (WoW addon), Ace3, LibStub, LibKa0s (vendored), the LibKa0s test kit (`tests/run.lua`), luacheck via `ka0s-bounded`, Python for seeds, `gh` CLI.

**Spec:** `docs/superpowers/specs/2026-11-27-itemsearch-split-design.md` (rulings R1-R11). Boundary map: `docs/superpowers/research/2026-11-27-itemsearch-split/verdict-boundary.md`.

## Resume protocol (read first)

- The **status ledger** below is the checkpoint. A task is `done` only when its gate is green and its commit hash is written in the ledger. Resume from the first row not `done`.
- Every repo works on branch **`feat/2026-11-27-itemsearch-split`** (ItemSearch's first branch is the same name off its initial commit). Sibling folders under `/mnt/d/Profile/Users/Tushar/Documents/GIT/`.
- Before resuming a task: `git -C <repo> status` must be clean or hold only that task's work; `git log` shows the ledger's last hash.
- Commits are task-prefixed `IS-<ID>:` and end with the run's attribution lines. Never `--no-verify`.
- **Never merge, tag, or bump Drop Watcher's version** until the owner's go-ahead (task G1). LibKa0s v1.119.0 is authorized (R8); its tag is G1's.
- Push each repo's branch after its milestone (B4, C1, C3, D1, E1, F1).

## Status ledger

| ID | Repo | Task | Status | Commit |
|---|---|---|---|---|
| A0 | DW | Design, research note, this plan | done | (this commit) |
| A1 | DW | Golden verdict characterization suite | done | 5dafd4e |
| A2 | DW | De-tangle refactors (6 cuts), behavior-neutral | done | 5a50224 |
| B1 | LK | `LibKa0s-Verdict-1.0` shell + pure kernel files | done | b940cc70 |
| B2 | LK | Reads, facts, gear, score, collect + instance API | done | fc303a5e |
| B3 | LK | `VerdictSettings.lua` drop-in Comparison section | done | 021bdc46 |
| B4 | LK | v1.119.0 release record (minors, xml, majors, CHANGELOG, API docs, bundle); push | done | 110e02be |
| C1 | DW | Re-vendor branch build; DW on the major; moved files deleted; push | done | 296e8ec |
| C2 | IS | Repo + scaffold (NEW_ADDON, Forever-only), #18 transferred | todo | |
| C3 | IS | Port Item Search; R11 key; Test mode; Comparison; docs; bundle; push | todo | |
| D1 | DW | Clean cut of Item Search; retire its data; docs; push | todo | |
| E1 | STD | Roster row + library-stack-§7 ripple; push | todo | |
| F1 | all | Reviews, Item Search standards audit, fix pass; push | todo | |
| G1 | all | Owner go-ahead → merge, tag, re-verify, close #19, cleanup | todo | |

C1 and C2/C3 run in parallel once B4 is green. D1 follows C1 and C3. E1 can run any time after B4.

## Global Constraints

- Ka0s WoW Addon Standard binds every repo; a deviation stops the run and is raised (CLAUDE.md). None planned.
- library-stack-§6: Item Search never reads `DropWatcherDB`, never names Drop Watcher in `Dependencies`/`OptionalDeps`, no presence hook either way (R5, R6).
- Item Search TOC: `## Interface: 16001`, `## AllowLoadGameType: camelot`, `## ExcludeLoadGameType: standard`, `## Version: 0.1.0`, Title `Ka0s Item Search`, SavedVariables `ItemSearchDB, ItemSearchPerfDB`, no `X-Curse-Project-ID` (R9), `## OptionalDeps:` includes ForeverDB, ForeverDB_Full, Auctionator, Pawn, TomTom.
- Slash `/is` and `/itemsearch` (R1). Default key `ALT-CTRL-S`; hint text `Ctrl-Alt-S: open in Item Search` (modifiers written Ctrl, Alt, Shift); tooltip label `Item Search` (R11).
- Launcher: Enabled · Locked · Test mode · Show window. Skin picker preview `test`. No Sim mode (R7).
- LibKa0s new version `v1.119.0`; Drop Watcher `## Version` unchanged; Item Search `0.1.0` (R8).
- Gates: DW — `lua tests/run.lua`, `KA0S_KIT_CLIENT=forever lua tests/run.lua`, `~/.claude/dev-copilot/bin/ka0s-bounded luacheck .` (0/0), `python3 -m pytest -q tools/seeds`. LibKa0s — `lua tests/run.lua`, `ka0s-bounded luacheck .` (0/0). Item Search — `KA0S_KIT_CLIENT=forever lua tests/run.lua`, luacheck 0/0, `python3 -m pytest -q tools/seeds`.
- Never edit `libs/` or `tests/_kit/` except by re-vendoring whole payloads from LibKa0s's ship folders.
- No authored `.lua` file over 1500 lines (layout-§1).
- CRLF line endings via each repo's `.gitattributes` (Item Search's is its first commit).

## Review Focus

1. **ForeverDB absent or loading late** → Item Search shows no tooltip block and the window says ForeverDB is missing; no Lua error. Test: C3 `test_no_foreverdb.lua` (block absent, window empty-state text).
2. **Pawn absent or not ready** → the Keep verdict omits the gear part (`scorePending` → nil gear), never errors, and is re-judged once Pawn answers. Test: B2 `test_verdict_score.lua` case "pawn not ready then ready".
3. **Ctrl-Alt-S already bound to something else** → Item Search leaves it alone, the hint is omitted until a key is bound. Test: C3 in `test_item_search_key.lua` ("a bound ALT-CTRL-S that is not ours is left alone").
4. **Drop Watcher and Item Search both loaded, different LibKa0s copies** → LibStub keeps the higher Verdict minor; each addon's instance keeps its own host config (no shared state). Test: B2 `test_verdict_instances.lua` (two instances, different `config()`, independent verdicts and signatures).
5. **Stand-down (addon disabled) while gear events fire** → the instance's timer is cancelled and no `onChange` fires until stand-up. Test: B2 `test_verdict_gear.lua` case "stand-down drops pending refresh".

---

### Task A1: Golden verdict characterization suite (DW)

**Files:**
- Create: `tests/test_verdict_golden.lua`, `tests/fixtures/verdict_golden.lua` (the fixture table)

**Interfaces:**
- Produces: `tests/fixtures/verdict_golden.lua` returning `{ cases = { {name, client, facts, candidate, opts, expect = {verdict, reasonKeys}} , ... }, me = { {name, client, link, setup, expect} } }`. B1/B2 port the same fixture file into LibKa0s unchanged, so the same table pins both sides.

- [x] **Step 1:** Write cases through the current public seams only (`NS.Evaluate.Evaluate`, `NS.LootFeed.JudgeMe`, `NS.Collectibles.Verdict`, `NS.Scoring.Scorer`, `NS.Gear.Snapshot`), covering at least: upgrade / sidegrade (band edge) / downgrade / cantUse / doesntWant / unknown; scoreFirst (Forever) vs ilvlFirst (Retail); Pawn pending → `scorePending`; weights scorer; compareOwned on/off; heirloomProtect; undesired subclass; tier token fold; off-spec attach (Retail); each collectible kind (newCollect, collected, lockbox); a group candidate (Inspect-shaped) judged through `Evaluate`.
- [x] **Step 2:** Run both clients: `lua tests/run.lua` and `KA0S_KIT_CLIENT=forever lua tests/run.lua`. Expected: PASS (characterizing today's behavior; any surprise is recorded as the expected value, not fixed).
- [x] **Step 3:** Commit `IS-A1: golden verdict suite pins today's engine on both clients`.

Builder note (A1): the fixture shape grew a few fields beyond the sketch, all plain data and documented in its header: a case's `profile` (the kit profile it runs on alone; only the Retail off-spec case uses it), `via` (`evaluate` or `collect`), `forced`, and `expect.fields` / `details` / `offSpec` / `none`. Two things are data the suite turns into functions: `opts.scorer` (`{kind="table", scores}` or `{kind="weights", weights}`) and `candidate.offSpecGear` (`{[specID]=gear}`). In a `me` case, `client` is the kit profile it runs on, and the case is a declared skip on the other. In `setup`, items and worn/bag slots are keyed by link. B1 and B2 interpret the same fields. One surprise is recorded as found, not fixed: under scoreFirst a `cantUse` carries no `noScore`, because the refusal returns before the score is weighed. Kernel cases: 48. Read cases: 16. The gate's eol check also flagged this run's design spec as LF on disk (A0's write). Re-checking it out fixed that; its content is unchanged.

### Task A2: De-tangle refactors (DW, behavior-neutral)

**Files:** Modify `modules/LootFeed.lua`, `modules/Scoring.lua`, `modules/Collectibles.lua`, `modules/ItemFacts.lua`, `modules/Gear.lua`, `modules/OffSpec.lua`, `core/ClassData.lua`, `core/ClassDataForever.lua`, and their tests.

**Interfaces:**
- Produces (the exact shapes B1/B2 lift):
  - `LF.VerdictConfig() -> {sidegradeBand, compareOwned, undesired, heirloomProtect, scorer, weights, verdictMode}`; `LF.Config()` keeps its fields and reads these from it.
  - `NS.Scoring.Scorer(cfg)` / `NS.Scoring.ScoreFor(link, cfg)` take `cfg.scorer`, `cfg.weights` (no `NS.Setting` inside Scoring).
  - `NS.Collectibles.Verdict`, `.Read`, `.CategoryOf`, `.IsCollectible` stay; the feed refresh moves to `modules/CollectFeed.lua` (new, DW-only) subscribed to `NS.ItemFacts.OnCollectionsChanged(fn)`.
  - `NS.ItemFacts.OnCollectionsChanged(fn)` replaces the direct `NS.Collectibles.Changed()` call.
  - `NS.Gear` takes `G.SetDeferPredicate(fn)` for the combat defer; `G.Qualities` moves to `modules/GearQualities.lua` (DW-only).
  - `NS.ClassData.ForClient(clientKey)` and `NS.OffSpec.Enabled(clientKey)`; file-load selection kept as a call to them with `NS.Compat.ClientKey()`.

- [x] **Step 1:** One cut at a time (1-6 of the boundary map's *Tangles* list), each: refactor → full gate on both clients + luacheck → commit `IS-A2.<n>: <cut>`. A1's golden suite must stay green unchanged at every commit.
- [x] **Step 2:** Update `docs/module-map.md` and `docs/ARCHITECTURE.md` module map rows for the two new files; layout-§1 census if any file nears 1500.

Builder note (A2): commits 8324b0d (A2.1) .. 948fd20 (A2.6), docs 03e7451; the golden suite and its fixture are byte-unchanged since A1. Decisions: (1) `LF.Config()` carries the verdict config whole as `cfg.verdict` and only there (the review fixes dropped the four flat judging fields it kept beside it), and every verdict read (`judgeMe`, `judgeLooter`, `candidateEntry`) takes `cfg.verdict`. (2) `ScoreFor` keeps its `who` and takes the config third, `S.ScoreFor(link, who, cfg)`; `S.InUse(cfg)` takes it too (the detail card and diagnostics pass `LF.VerdictConfig()`); a nil cfg reads as `{}` (auto with nothing set). (3) Only the transmog call moved to `IF.OnCollectionsChanged`; the five collection events (NEW_MOUNT_ADDED ...) and the regen pass stay in `modules/CollectFeed.lua` with the timer (behavior-neutral); B2 decides whether the library owns them as `onChange("collection")`. `IsFeedOnly` stays on `NS.Collectibles` (pure, widely read). (4) `G.Qualities` is still published as `NS.Gear.Qualities`, now defined in `modules/GearQualities.lua` (LOAD-BEARING after Gear.lua), which also calls `G.SetDeferPredicate` with combat; with no predicate set Gear defers nothing. C1 must keep a `Qualities` reader once `NS.Gear` becomes the library instance. (5) `CD.ForClient(key)` answers Forever's list for "forever", Retail's for any other key (nil for "forever" before ClassDataForever loads); `OS.Enabled(key)` reads `C.FEATURE_CLIENTS.offSpec`, the declaration `C.FEATURE.offSpec` already reads.

Builder note (A2 review fixes): the verifier found that `judgeLooter` and `candidateEntry` still handed `evalOpts` the feed's whole `LF.Config()`, whose top level has no `verdictMode`, `scorer` or `weights`, so the looter's and the candidates' verdicts lost WoW Forever's `scoreFirst` and the scorer setting (`none` read as auto, `weights` scored nobody else). The golden suite pins only your own verdict, so nothing caught it. Fixed: both pass `cfg.verdict`, and `LF.Config()` no longer duplicates any verdict field at its top level, so there is one shape. New red-first tests in `tests/test_feed.lua` spy on `NS.Evaluate.Evaluate` for the looter and a candidate on both clients (verdict mode and the `weights` scorer). The golden suite's neutrality claim covers your own verdict only, and B2 must keep these two tests. B2 lifts `ScoreFor(link, who, cfg)` (3 args) and `InUse(cfg)`, not the interface list's 2-arg `ScoreFor(link, cfg)`. Rejected: replacing `OS.Enabled`'s token loop with a Compat helper keyed by client (`ForClientKey`). `ForClient` is a LibKa0s-Compat-1.0 member, so the helper is a library surface change outside A2; it is raised for B1/B2, where `V.ClassData.ForClient(key)` and the client-keyed instance land.

Builder note (A2 review fixes, round 2): the off-spec registration gate went back to clients-§4. A2 had set `INITIALIZED = OS.Enabled(NS.Compat.ClientKey())`, which bypassed `Compat.ForClient` and its load-time error on an unknown token. It is again `NS.Constants.FEATURE.offSpec == true`. `OS.Enabled(key)` stays only as the pure query for a named client, and `tests/test_offspec.lua` now pins `Initialized() == C.FEATURE.offSpec`. The two client helpers keep different defaults for a nil or unknown key, and their docblocks now say so: `CD.ForClient` answers Retail's list, `OS.Enabled` answers false. B2 must not merge them into one default. The `ForClientKey` helper is still out of A2's scope (see above).

Builder note (A2 review fixes, round 3): `docs/test-cases.md` is regenerated (testing-§5: Total 2931 -> 2940, A2's nine new cases) and the README tests badge moved with it. `docs/message-bus.md`'s `collection` cause now names `modules/CollectFeed.lua`. In `tests/test_offspec.lua` the `Enabled(client)` test sits above the Forever comment block, which again heads the test it describes. `tests/test_class_data.lua` asserts both lists are built before the identity checks. `modules/CollectFeed.lua`'s header paragraph is rewrapped, with no line past 100 columns.

### Task B1: `LibKa0s-Verdict-1.0` shell + pure kernel (LibKa0s)

**Files:**
- Create: `LibKa0s/Verdict.lua` (shell: `MINOR = 1`, floors on Core ≥ 1, `lib.New(host)`, `lib.Evaluate`, `lib.Equippability`, `lib.ItemVerdict`, `lib.TrackDelta`), `LibKa0s/VerdictEvaluate.lua` (`EVALUATE_MINOR = 1`; Evaluate + OffSpec), `LibKa0s/VerdictTierTokens.lua` (`TIERTOKENS_MINOR = 1`), `LibKa0s/VerdictClassData.lua` (`CLASSDATA_MINOR = 1`; Retail + Forever lists, `ClassData.ForClient(key)`), `LibKa0s/VerdictConstants.lua` (`CONSTANTS_MINOR = 1`; the `NS.Constants` subset the kernel reads, verbatim values).
- Test: `tests/test_verdict_kernel.lua`, `tests/test_verdict_classdata.lua`, `tests/test_verdict_tokens.lua`, `tests/fixtures/verdict_golden.lua` (copied from DW A1) + `tests/test_verdict_golden.lua` (kernel half).

**Interfaces:**
- Produces: `local V = LibStub("LibKa0s-Verdict-1.0")`; `V.Evaluate(facts, candidate, opts) -> me` (opts adds `client`), `V.Equippability(facts, candidate)`, `V.ClassData.ForClient(key) -> {SPECS, STAT, SpecKey(...), DualWieldFor(...), TitanGripFor(...)}`, `V.TierTokens.Fold/SlotOf/Users/IsCurio`, `V.OffSpec.*` (as DW's, `Enabled(client)`), `V.C` (constants subset). Token vocabulary from `host.L` keys identical to DW's locale keys.

- [x] **Step 1:** Port DW's kernel tests + the golden kernel half; run `lua tests/run.lua` → FAIL (no major).
- [x] **Step 2:** Move the code (pure move; renames only where the shell requires), register files in `LibKa0s.xml` and `tests/majors.lua`.
- [x] **Step 3:** Gate green (`lua tests/run.lua`, luacheck 0/0) → commit `IS-B1: LibKa0s-Verdict-1.0 shell and pure kernel`.

Builder note (B1): commit `b940cc70` in LibKa0s. (1) WHERE: the LibKa0s checkout itself was on another run's branch (`feat/2026-11-27-feed`, Loot History #38) with uncommitted work in `LibKa0s/Feed.lua`, so switching it would have disturbed that run. B1 built in a git worktree of the same repo, `/mnt/d/Profile/Users/Tushar/Documents/GIT/.worktrees/LibKa0s-itemsearch`, on branch `feat/2026-11-27-itemsearch-split` (created from `master` 4dbc1636); B2 to B4 continue there (or in the checkout once the Feed run is done with it). (2) COLLISION, for B4 and G1: the Feed branch also opens `v1.119.0` and also takes **DebugLogDiagnostics minor 13** (Feed in the major list); this branch does the same for Verdict, because `test_debuglog_diagnostics` fails while a major is missing from that list. Whichever branch merges second re-bumps to the next semver and DIAG minor 14 and merges both names into the list. (3) THE CLIENT IS PER CALL: `V.Evaluate(facts, candidate, opts)` reads `opts.client`, which picks the class list, the ranged slot plans (`V.C.SlotPlanFor`) and the off-spec gate (`V.OffSpec.Enabled(opts.client)`); nil means Retail's list and plans and NO off-spec pass. `V.Equippability(facts, candidate, client)`, `V.OffSpec.Who(classFile, specID, client)` and `V.OffSpec.WornGear(gear, who, client)` take a trailing client (nil: Retail's list). C1 must pass `client` on every kernel call, Inspect's group judging included, or it loses off-spec on Retail. The kernel is built once per class list (`buildKernel(CD, SLOT_PLAN)` closing over Drop Watcher's functions unchanged). `V.C.SLOT` is the shared slots; `V.C.SlotsFor("forever").RANGED` is 18. (4) `V.ClassData` has no `Install` (it would write one client's list onto a table every addon shares); each list carries `STAT`. DW's `NS.ClassData` in C1 must read `V.ClassData.ForClient(key)` itself. (5) `V.TierTokens`' word members take the host's locale table as their last argument (`UseNamesClass(text, L)`, `UseSlot`, `NameSlot`, `IsCurio(facts, L)`, `Users(facts, L)`, `SlotOf(facts, readTooltip, L)`), read by `TT.WORDS` (Drop Watcher's locale keys); nil L reads each key as its word (enUS). The text parsers moved with them as `TT.EscapePattern/WordMap/FirstWord/EndsWithWord/TokenUseSlot`; DW's `NS.TextParse` keeps its other parsers. `IsCurio`'s "is gear" check reads both clients' plans (no Curio carries a ranged slot). (6) Tests: beyond the plan's list, `tests/test_verdict.lua` (shell) and `tests/test_verdict_offspec.lua` (DW's off-spec suite), on `tests/fixture_verdict.lua`. In the golden kernel half the 12 `collect` cases and the 2 `weights` cases are declared skips that lift on their own once `V.Collect` / `V.Score` exist (B2); the off-spec case runs on every profile (its client is named). The `me` half is B2's. (7) The gate forces part of B4's record now: the CHANGELOG `v1.119.0 — unreleased` block, `docs/api/Verdict/version-1.1.1.1.1-docs.md` (in progress) and its manifest, DebugLog `23.13.1.5`, `docs/api/README.md`, `docs/releasing.md` (ninety-two files), `docs/test-cases.md`. Each later file changes the version key, so B2 and B3 rename the Verdict document and manifest to the new key and regenerate the manifests (`lua tools/gen-api-members.lua`).

### Task B2: Reads, facts, gear, score, collect + instance API (LibKa0s)

**Files:**
- Create: `LibKa0s/VerdictReads.lua` (`READS_MINOR = 1`; the ~40 default reads, named as DW's Compat members), `LibKa0s/VerdictFacts.lua` (`FACTS_MINOR = 1`; ItemFacts + ItemRead), `LibKa0s/VerdictScore.lua` (`SCORE_MINOR = 1`), `LibKa0s/VerdictCollect.lua` (`COLLECT_MINOR = 1`), `LibKa0s/VerdictGear.lua` (`GEAR_MINOR = 1`).
- Test: `tests/test_verdict_instances.lua`, `tests/test_verdict_gear.lua`, `tests/test_verdict_score.lua`, `tests/test_verdict_facts.lua`, `tests/test_verdict_collect.lua`, golden `me` half.

**Interfaces:**
- `V:New(host) -> v` with `host = { client = "retail"|"forever", config = fn -> VerdictConfig (A2 shape), debug = fn(tag,msg), perf = obj|nil, reads = {member = fn}|nil, deferWhile = fn -> bool|nil, L = table, registerEvent = fn(event, handler), unregisterEvent = fn(event), onChange = fn(kind) }` where `kind ∈ {"gear","collection","score"}`.
- `v:Judge(link) -> me|nil, pending:boolean`; `v:JudgeFacts(facts, {forced=bool, candidate=cand|nil}) -> me`; `v:Facts(link) -> facts|nil`; `v:Request(link)`; `v:Snapshot() -> {signature, equipped, owned, ...}`; `v:Signature() -> string|false`; `v:Candidate() -> cand`; `v:OffSpecGear()`; `v:Scorer() -> fn`; `v:StandDown()`; `v:StandUp()`.
- `reads` override: every read the instance makes goes through `host.reads[name] or VerdictReads[name]`, resolved at call time (so a host's simulator seam can guard it).

- [x] **Step 1:** Port DW's test_gear / test_item_facts / test_item_read / test_scoring / test_collectibles to instance form + Review Focus tests 2, 4, 5; run → FAIL.
- [x] **Step 2:** Move the code; events through `host.registerEvent`; throttle 0.5 s; `onChange("gear")` where DW sent `GEAR_CHANGED`.
- [x] **Step 3:** Gate green → commit `IS-B2: Verdict instance: reads, facts, gear, score, collect`.

Builder note (B2): commit `fc303a5e` in LibKa0s, built in the same worktree as B1
(`/mnt/d/Profile/Users/Tushar/Documents/GIT/.worktrees/LibKa0s-itemsearch`, branch
`feat/2026-11-27-itemsearch-split`); the checkout itself is still on the Feed run's branch. Five
files, load order Reads, Collect, Facts, Score, Gear after VerdictEvaluate, each minor 1 paired on the
shell; the version key is `1.1.1.1.1.1.1.1.1.1` (document and manifest renamed). Decisions C1 and C3
must follow: (1) ONCHANGE KINDS: `gear`, `collection`, `score` and a fourth, `item`, which the plan did
not list: `v:Judge(link)` on an uncached item asks for it and fires `onChange("item", link)` when it
loads, so a host need not hold its own Request callback; `score` and `item` carry the link second.
(2) `v:Judge(link, forced)` answers `me, pending` (`nil, true` loading; `me, true` score pending,
retried every `SCORE_RETRY` 1 s, `SCORE_TRIES` 5, DW's LootFeed values; `nil, false` no item).
`v:JudgeFacts(facts, { forced, candidate })`: with `candidate` (another player) there is no
heirloomProtect, DW's judgeLooter rule; the sidegrade band, compareOwned, scorer and verdict mode
still come from the host's config. (3) THE COLLECTION EVENTS ARE THE LIBRARY'S (A2 left it to B2):
NEW_MOUNT_ADDED, NEW_PET_ADDED, NEW_TOY_ADDED, NEW_RECIPE_LEARNED, SKILL_LINES_CHANGED and the
transmog event arm one 0.5 s re-read per instance (`v:RereadCollections`), then
`onChange("collection")`. C1: DW's `modules/CollectFeed.lua` drops its five event rows and its
`RereadCollections` call and runs its feed pass from `onChange("collection")`; its
PLAYER_REGEN_ENABLED collectUnknown pass stays DW's. `IsFeedOnly` is not in the library (it reads a
feed record): it stays DW's. (4) READS: `PawnScaleForSpec` and `PawnVisibleScale` take a trailing
`client` (the class list Pawn's spec index is read from); DW's members ignore it. The library's
`PlayerRole` reads LibKa0s-Role-1.0 with no store, so DW (and IS if it keeps a role store) must hand
its own `PlayerRole` in `host.reads` or the Feral tank scale and the role override are lost. (5)
CLIENT PER CALL in the pure halves: `lib.Collect.Verdict(facts, forced, client)` (whose slot plans
say an item of no category reads as gear; either client's when nil), `lib.Score.WeightsScorer(map,
client, warn)` and `WeightsFor(map, candidate, dropStats, client, warn)` (Retail's list when nil),
`ParseImport/ImportInto/WeightsScore` take an optional `warn(key, name)` for the once-per-key debug
line DW's NS.DebugOnce gave. C1 must pass the client wherever DW's group-side code calls them.
`ScoreFor`/`InUse` are instance methods (`v:ScoreFor(link, who, cfg)`, `v:ScorerInUse(cfg)`; cfg nil
reads the host's config). (6) `host.config()` is the A2 `VerdictConfig` shape; a nil `verdictMode`
reads `V.VerdictModeFor(client)` (scoreFirst on Forever), so IS need not name it. A host with no
config judges on all-nil values, not DW's defaults: B3's `V.Settings.DEFAULTS` is where a host gets
them (the golden suite carries DW's six defaults inline until then). (7) `host.deferWhile`'s release
edge is PLAYER_REGEN_ENABLED (DW's is combat); a host with another predicate calls
`v:OnGearDeferEnd()` itself. DW's `G.Qualities` stays DW's, read off `v:Snapshot().equipped`. (8) The
fixture sets the mock's `_G` to the mock set so `Reads.GlobalString` (`_G[name]`, as DW's) reads the
client's strings. (9) A small B1-file fix, unreleased so no minor moves: VerdictTierTokens read a key
missing from a host's locale table as nil and raised; it now reads as its own word (a red-first case in
test_verdict_tokens). (10) Tests beyond the plan's list: `tests/test_verdict_reads.lua` (the reads'
absent values and secret guards) and the shared `tests/fixture_verdict_client.lua` (a fresh mock
client per case, ported from DW's wow_mock item, tooltip, gear and collection fakes). The golden read
half runs all 16 cases through `v:JudgeFacts` on a fresh client per case, and the kernel half's 14
declared skips lifted (17 skips to 3). TDD order: the library files were written before the suites;
red was shown by running the six new suites and the golden suite against the B1 library (116 of 152
failed), then green. Gate: 5523 passed / 0 failed / 3 skipped on both kit profiles, luacheck 0/0 (419
files), lizard -C 15 clean.

### Task B3: `VerdictSettings.lua` (LibKa0s)

**Files:** Create `LibKa0s/VerdictSettings.lua` (`SETTINGS_MINOR = 1`); Test `tests/test_verdict_settings.lua`.

**Interfaces:**
- `V.Settings.Rows(spec) -> schemaRows` and `V.Settings.Section(container, helpers, spec)` in the `CalloutSettings.lua` shape: `spec = { root = "comparison", L = host L, client, get = fn(path), set = fn(path, v) }`; emits the six rows with DW's defaults (`defaults/Profile.lua:159` values) and the weights + undesired editors (moved from DW `settings/PageEditors.lua`, `settings/ListEditors.lua`), built on LibKa0s Options widgets.
- `V.Settings.DEFAULTS` — the six defaults table.

- [x] **Step 1:** Tests: rows/keys/defaults equal DW's; editor writes go through `spec.set`; run → FAIL.
- [x] **Step 2:** Implement; gate green → commit `IS-B3: Verdict settings section (the six comparison rows and both editors)`.

Builder note (B3): LibKa0s commit `021bdc46`, same worktree and branch as B1/B2. Version key now
`1.1.1.1.1.1.1.1.1.1.1` (document and manifest renamed). Decisions C1 and C3 follow: (1) THE
UNDESIRED EDITOR was not in `settings/ListEditors.lua` (that file is the Item lists editor and
stays DW's); it is `settings/PageEditors.lua`'s `PrefsTab`, moved with `WeightsTab` and the pure
halves of `settings/Editors.lua` (SpecNamer, ClassSpecs, PickSpec, StatsFor, StatLabel, Weight,
WithWeight, ImportText, UndesiredChoices, IsUndesired, WithUndesired; the client is a trailing
argument). (2) SURFACE: `V.Settings.Rows(spec)` (the six path rows in DW's order, groups Scoring /
Weights / Unwanted types, maps `skipRender`, `page` only when `spec.page` is given),
`V.Settings.Section(ctx, O, spec, tab)` (`O` = the host's Options instance, the plan's "helpers";
`tab` "scoring" | "weights" | "undesired", or nil for all three under headings, the two editors
then sharing ONE spec strip, because O.SubTabStrip keeps one strip ledger per ctx), and
`V.Settings.Tabs(O, spec)`, the two host tabs keyed `L["Weights"]` / `L["Unwanted types"]` that
DW's Pages.lua `comparison.tabs` takes as is. Also `DEFAULTS`, `Defaults()`, `KEYS`, `SCORERS`,
`Checks`, `WORDS`. (3) SPEC beyond the plan's fields: `page`, `print` (the import's chat line; DW
passes NS.Print) and `reads` (overrides of `lib.Reads` for UnitClass, PlayerSpecID,
PlayerTalentTree, SpecName, TalentTreeNames; DW hands its NS.Compat members). `spec.set(path,
value)` is the host's seam (DW: NS.SchemaRuntime.Set); a nil `spec.get` value reads as the default.
(4) WORDS are DW's locale keys, read with rawget, else the English key; the one changed string is
the import's noStats line, now "That scale has no stat the verdict scores, so nothing was
imported." (the library names no addon): DW and IS add that key to their locales. (5)
VerdictReads (unreleased, minor 1) gained `SpecName` and `TalentTreeNames`. (6) Test:
`tests/test_verdict_settings.lua` (21 cases, DW's test_settings_pages Comparison and editors cases
ported).

### Task B4: v1.119.0 release record (LibKa0s)

**Files:** `CHANGELOG.md` (v1.119.0 block naming every file minor), `docs/api/Verdict/version-1-docs.md` + `members-1.json` (owner ruling R4 recorded, the two consumers), `docs/api/README.md`, `docs/api/CONSUMERS.md`, `README.md` (major count, payload tree), `docs/releasing.md` (minor-name list incl. the eight Verdict constants, version pointers), `docs/test-cases.md` (regenerated), `docs/automated-tests/<stamp>/` bundle + `RESULTS.md` row.

- [x] **Step 1:** Follow `docs/releasing.md` order of operations; `tests/test_versioning.lua` green.
- [x] **Step 2:** Run the vendored automated-test runner (`/dev-copilot:wow-automated-tests` playbook) → bundle.
- [x] **Step 3:** Commit `IS-B4: v1.119.0 release record`; `git push -u origin feat/2026-11-27-itemsearch-split`. No tag (G1).

Builder note (B4): LibKa0s commits `39fc0021` (the release, all but its evidence: CHANGELOG dated
`## v1.119.0 — 2026-11-27`, the Verdict document complete with the consumers at the tag beside R4, README
twenty-seven majors / row / tree, releasing.md pointers and lists, CONSUMERS.md, test-cases unchanged),
`55a7c6dc` and `110e02be` (the record: bundle `docs/automated-tests/20261127-234144/`, ANALYSIS.md,
RESULTS row, release-gate lines), as releasing.md step 7's two commits. Decisions: (1) the first release
run measured `seed` in `tests/test_verdict_golden.lua` at CCN 18 (the tag gate allows none over 15), so
`55a7c6dc` split it in three, behavior unchanged, and the run was retaken; the first bundle was not
committed. (2) The vendored runner refuses a git worktree (it tests `-d .git`, and a worktree's `.git`
is a file), so the run was taken in a fresh clone of the branch at the same commit, named `LibKa0s`, and
the bundle copied back; ANALYSIS.md records it and names the kit fix as a new action. (3) README's
standards pointer stays v2.121.0, WowAddonStandards `master` (its checkout is on another run's branch
at v2.122.1). (4) `tests/test_verdict_kernel.lua` (1092) entered the 1000–1500 band; its RESULTS
disposition is accepted with a 1250-line trigger, not yet in LibKa0s CLAUDE.md's band census (the
ForeverDB.lua precedent). (5) Seen, not changed: `LibKa0s/Verdict.lua`'s header file list omits
`VerdictSettings.lua`; for F1.

### Task C1: Drop Watcher on the major (DW)

**Files:** `libs/LibKa0s/`, `tests/_kit/` (re-vendored from LibKa0s branch HEAD), `CLAUDE.md` provenance line `v1.119.0` + icons line; new `core/VerdictSetup.lua` (the instance: `host.reads` = the DW Compat members so the Sim seam guards them; `onChange("gear")` → `NS.MSG.GEAR_CHANGED`); rewire every reader of `NS.Evaluate`, `NS.ClassData`, `NS.OffSpec`, `NS.TierTokens`, `NS.Scoring`, `NS.Collectibles` (pure half), `NS.ItemFacts`, `NS.ItemRead`, `NS.Gear` onto the instance or `V.*`; delete the moved DW files and their now-library tests (keeping DW-side tests + golden); Comparison page from `V.Settings`; TOC; docs (ARCHITECTURE module map, module-map, schema, compat-layer, DEPENDENCIES, revendor bundle `docs/revendor/2026-11-27-v1.119.0/`).

- [x] **Step 1:** Re-vendor per `/dev-copilot:wow-revendor-libka0s` (copy only; adoption decisions are this task's).
- [x] **Step 2:** Rewire in slices (kernel readers → facts/read → gear → scoring → collect → settings), full gate both clients after each, commit `IS-C1.<n>`.
- [x] **Step 3:** Golden suite unchanged and green; push.

Builder note (C1): commits `b3b324b` (IS-C1.1, the re-vendor and bundle `docs/revendor/2026-11-28-v1.119.0/`)
.. `296e8ec` (IS-C1.9, docs). Decisions C3, D1, F1 and G1 should know: (1) THE VENDOR GATE: the
provenance line names v1.119.0, which is untagged (G1's), so `tests/test_vendor_sync.lua`'s two
payload cases fail on both profiles at every C1 commit ("the library repo v1.119.0 carries
LibKa0s/"); no tag was made (`../LibKa0s` is another session's, and the Feed branch also opens
v1.119.0). The bytes were proven instead: a scratch clone of the LibKa0s worktree with a throwaway
local tag at `110e02be` beside a clone of this branch passes all three VendorSync cases. Every other
case is green; G1's tag turns the two green in place. IS (C2/C3) meets the same two cases. (2) THE
SHAPE: `core/VerdictSetup.lua` (the host, `NS.Verdict`, `NS.VerdictEngine`, the stand-in) and
`core/VerdictViews.lua`: DW keeps its reader names (`NS.Evaluate`, `NS.ClassData`, `NS.OffSpec`,
`NS.TierTokens`, `NS.ItemRead`, `NS.ItemFacts`, `NS.Gear`, `NS.Scoring`, `NS.Collectibles`) as thin
views, because the golden suite (byte-unchanged, green) and the A2 spy cases drive those names, and
suites stand members in (NS.Scoring, NS.Gear.Snapshot). Every kernel view names the client of the
class list in force (`NS.ClassData.ClientKey()`, Install for suites); the off-spec gate stays
`C.FEATURE.offSpec` (a candidate's offSpecGear is withheld from the kernel where it is false). The
feed (`LootFeed.judgeMe`, judgeLooter, candidates) still judges through the views, not
`v:JudgeFacts`, so its `evaluate` perf parent and test seams hold; DW's Item Search runs on the
instance through the same views. (3) EVENTS: `host.registerEvent` only keeps the instance's
handler; each library event is an `NS.FEATURE_EVENTS` row (`OnVerdictEvent`, the list from the API
document), so stand-down and the simulator's `NS.DeliverEvent` reach them. (4) THE FIRST READ: the
library's `StandUp` reads gear at once, and DW's snapshot was lazy and quiet. OnEnable stands the
instance up with its gear change suppressed and marks the read provisional; the first ask through
`NS.Gear` re-reads quietly (`NS.VerdictEnable`, `NS.VerdictFresh`); the latch's stand-up announces as
before. A library `StandUp(lazy)` would remove this; for F1. `NS.State.gear` mirrors the snapshot
DW last saw, for the diagnostics. (5) `host.reads` resolves every name through `NS.Compat` (NS.Item
for the item load) at each call. (6) SETTINGS: rows from `V.Settings.Rows` (defaults set to
`P.comparison[key]`, which defaults/Profile.lua takes from `Settings.Defaults()`), tabs from
`V.Settings.Tabs(Helpers, spec)` with `spec.client` read per draw; no rows without the library.
The noStats key is the library's new text. test_locale reads `VerdictTierTokens.lua` and
`VerdictSettings.lua` as readers of NS.L. test_skin_settings no longer counts the import box as DW's
own widget (the library draws it through the owner proxy). (7) SEEDS: deleting
`core/ClassData.lua` (IS-C1.2) broke `pytest tools/seeds` and IS-C1.2..C1.6 were committed with it
red (only the Lua gate was run); IS-C1.7 fixed it: the tool reads `libs/LibKa0s/VerdictClassData.lua`
and `VerdictFacts.lua` read-only and `apply` refuses under `libs/`. The class-list seed contract
should move to LibKa0s (raise at F1/E1). (8) TESTS: deleted as now-library: test_evaluate,
test_class_data, test_item_facts, test_scoring, test_collectibles, the kernel cases of test_offspec,
the editor pure-halves of test_settings_pages, the tier-token parser cases of test_text_parse. Kept
as host integration: test_gear (its off-spec cases Retail-only), test_tier_token, test_item_read,
test_collect_feed. New: tests/test_verdict_setup.lua (11 cases). Total 2799. (9) Left for F1: DW's
`core/Constants.lua` still carries kernel tables only the library now reads (`TRACK_TIER`,
`TRACK_TIER_BY_STRING_ID`, the slot plans' kernel half); `C.TIER_SLOTS`/`C.TIER_TOKENS` were removed.
The item read's deviation row is retired (the read is the library's).

### Task C2: Item Search repo + scaffold (IS)

**Files:** new repo `/mnt/d/Profile/Users/Tushar/Documents/GIT/ItemSearch`, everything `NEW_ADDON.md` steps 0-9 lay down, Forever-only shape.

- [ ] **Step 1:** `gh repo create tusharsaxena/ItemSearch --public --description "<one line>"`; clone to the sibling folder; copy labels from DropWatcher (`gh label clone tusharsaxena/DropWatcher -R tusharsaxena/ItemSearch`); transfer #18 (`gh issue transfer 18 tusharsaxena/ItemSearch -R tusharsaxena/DropWatcher`).
- [ ] **Step 2:** Follow `WowAddonStandards/NEW_ADDON.md` steps 0-9 (context pack read from the scratchpad, never stored), vendoring LibKa0s from its branch HEAD (v1.119.0 pre-tag); launcher entries per Global Constraints.
- [ ] **Step 3:** Gate green → commit per playbook step; push `master` (initial) and the run branch.

### Task C3: Port Item Search (IS)

**Files:** from DW (paths in design §5.2) into IS's `core/ modules/ settings/ locales/ defaults/ tests/ tools/seeds/ docs/`; `core/VerdictSetup.lua` (IS instance, `client = "forever"`); `Bindings.xml` (`CLICK ItemSearchKey:LeftButton`); Test mode module; Comparison page; README / ARCHITECTURE / testing / smoke-tests / scope / module-map / schema / settings-panel / validate-seeds / performance / known limitations; automated-test bundle.

- [ ] **Step 1:** Port tests first (DW's `test_item_search*`, `test_tip_marks`, `test_row_tooltip`, `test_tooltip_placement`, `mock_tooltip_data`) with `NS` re-rooted (`itemSearch.*` → top-level profile keys), plus Review Focus 1 and 3 tests; R11 tests (default `ALT-CTRL-S`, hint `Ctrl-Alt-S: open in Item Search`, label `Item Search`); Test mode tests. Run → FAIL.
- [ ] **Step 2:** Port modules in dependency slices; replace DW-only helpers per design §5.2 with LibKa0s equivalents or IS-local thin helpers; commit per slice `IS-C3.<n>`.
- [ ] **Step 3:** Gate green; bundle; push.

### Task D1: Drop Watcher clean cut (DW)

- [ ] **Step 1:** Remove every Item Search file/row/string/default/binding/magnifier/`search` verb/sim + diagnostics mention/tests; drop OptionalDeps only Item Search read (ForeverDB, ForeverDB_Full, TomTom, Auctionator — check each for another reader first) and `core/ForeverDBSetup.lua` if unused.
- [ ] **Step 2:** Migration step: delete `profile.itemSearch` and `global.itemSearch` (extend `NS.RetireItemSearchRows`), with a test.
- [ ] **Step 3:** Docs sync (README Version History unreleased note "Item Search moved to Ka0s Item Search", scope, ARCHITECTURE incl. per-client table, smoke-tests, DEPENDENCIES, validate-seeds); gate green both clients; push.

### Task E1: Standard (STD)

- [ ] **Step 1:** `standards/ADDONS.md` row: `| Ka0s Item Search | ../../ItemSearch/ | https://github.com/tusharsaxena/ItemSearch | Forever | Enabled · Locked · Test mode · Show window (the Item Search window) | test | none |` (alphabetical position).
- [ ] **Step 2:** library-stack-§7 module table row + counts (27 majors, file count), inter-module paragraph (Verdict floors on Core; Options/Widgets read at call time), `EXECUTIVE_SUMMARY.md` counts.
- [ ] **Step 3:** If the repo's CLAUDE.md requires a version bump for these, STOP and ask the owner (R8 covers LibKa0s only). Commit; push.

### Task F1: Reviews and audit (all)

- [ ] `/dev-copilot:review` on LibKa0s (branch), DW (branch), IS (all); `/dev-copilot:wow-standards-audit` on IS; adversarially verify findings; fix the confirmed ones (commit `IS-F1.<n>`); every gate green; push all.

### Task G1: Close-out (owner go-ahead required)

- [ ] Merge LibKa0s → tag `v1.119.0` → push tag; re-vendor check (bytes equal tag) in DW and IS; merge DW, IS, WowAddonStandards; close DropWatcher#19 with a link to the new repo; delete the run's branches (local + remote), stashes, worktrees.
