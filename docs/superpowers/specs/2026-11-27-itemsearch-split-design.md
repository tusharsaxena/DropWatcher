# Item Search split — design (DropWatcher#19)

Date: 2026-11-27. Status: draft for owner approval (builder check done). Run branch: `feat/2026-11-27-itemsearch-split`
(the same branch name in every repo the run touches).

## 1. Intent

Item Search began inside Drop Watcher (#17) and grew into a separate product: the item tooltip block
with its Keep / Hold / Auction / Vendor / Toss badge, the Item Search window (tabs, verdict panel,
waypoints), ForeverDB loading, recorded vendor prices and Auctionator prices. None of it is group
loot. The owner wants it shipped as its own Ka0s addon, **Ka0s Item Search**, built to the full Ka0s
WoW Addon Standard, so each addon does one job and Item Search no longer needs Drop Watcher installed.

Success: a player on WoW Forever installs Ka0s Item Search alone and gets everything Drop Watcher's
Item Search gives them today, the Keep badge's "upgrade for you" verdict included. Drop Watcher carries
no Item Search code afterwards. Both addons pass their full green gates and a standards audit.

## 2. Owner rulings (2026-11-27)

| # | Ruling |
|---|---|
| R1 | New sibling folder and repo `ItemSearch` (`tusharsaxena/ItemSearch`); slash `/itemsearch` and `/is`. |
| R2 | Full standard, "all bells and whistles"; row added to WowAddonStandards `standards/ADDONS.md`. |
| R3 | DropWatcher#18 (Retail data source) is transferred to the new repo. |
| R4 | Drop Watcher's upgrade engine is **promoted into LibKa0s**, not copied. Both addons use it. |
| R5 | **No migration** of `DropWatcherDB` Item Search data (library-stack-§6 forbids reading another addon's SavedVariables). Players start fresh. |
| R6 | Drop Watcher afterwards: **clean cut, nothing** — no magnifier, no `/dw search`, no pointer. Docs, README Version History and the CurseForge text say where it went. |
| R7 | Optional surfaces: **Test mode** yes, **Sim mode** no. The launcher (minimap + broker) is mandatory anyway. |
| R8 | Claude may bump LibKa0s to v1.119.0 and tag it, the tag only after the owner approves the LibKa0s merge. Item Search starts at **v0.1.0**. Drop Watcher's version is not bumped. |
| R9 | No CurseForge project yet: the TOC leaves `X-Curse-Project-ID` out; README/DEPENDENCIES note it. |
| R10 | The verdict's six settings (scorer, sidegrade band, compare owned, heirloom protect, per-spec stat weights, unwanted types) and their two custom editors ship **in the library as a drop-in settings section**. Item Search gets a Comparison page from it; Drop Watcher's Comparison page is rebuilt from the same section. Each addon stores its own values; a fresh Item Search install gives Drop Watcher's out-of-box verdicts. |
| R11 | The default key becomes **Ctrl-Alt-S** (stored `ALT-CTRL-S`, the client's canonical order; was Alt-Ctrl-D). The tooltip hint writes the bound key in Ctrl, Alt, Shift order (`Ctrl-Alt-S: open in Item Search`), not the client's `GetBindingText` order. The tooltip's label line reads **Item Search**. Mockup: https://claude.ai/artifact/YFERKSnAVrgK9Hz7CYbsUs (owner asked to see it before the build). |

## 3. Goals, non-goals, anti-goals

**Goals**
- Ka0s Item Search, Forever-only (`## Interface: 16001`, `AllowLoadGameType: camelot`,
  `ExcludeLoadGameType: standard`; roster Clients `Forever`; reason: its data source, ForeverDB, exists
  only on WoW Forever — Retail is the transferred #18).
- Feature parity with Drop Watcher's Item Search at `7c36f40` (round 7 included).
- `LibKa0s-Verdict-1.0`: the "my verdict on this item" engine, consumed by both addons.
- Drop Watcher moved onto the library with **no behavior change** (characterization tests first), then
  stripped of Item Search.

**Non-goals**
- Retail support for Item Search (#18 stays open in the new repo).
- Any new Item Search feature beyond what the standard requires of a new addon.
- Moving Drop Watcher's group-side judging (inspect, roster, candidates, trade estimates) into the
  library.

**Anti-goals** (failure even if it technically works)
- Item Search that silently loses the Keep verdict when Drop Watcher is absent.
- Any read of `DropWatcherDB`, any `## Dependencies: DropWatcher`, any presence hook between the two.
- A Drop Watcher verdict that differs from today's on any tested input.
- Two copies of the engine.

## 4. Approaches considered

| Approach | Trade-off | Outcome |
|---|---|---|
| Promote the engine to LibKa0s | One source of truth; three repos plus the standard in one run; a release gate mid-run | **Picked (R4)** |
| Copy the engine into Item Search | Fast and low risk; two copies drift | Rejected |
| Item Search's own slim gear verdict | Small; may disagree with Drop Watcher on the same item | Rejected |

Data migration (deviation / amend the standard / none): **none** picked (R5). Drop Watcher hand-off
(soft / clean cut + pointer / clean cut): **clean cut** picked (R6).

## 5. The pieces

### 5.1 `LibKa0s-Verdict-1.0` (new major, LibKa0s v1.119.0)

Promotion: bar 1 is met (two consumers, same semantics: "what is this item to me"); bars 2/3 are met
by the characterization suite carried over from Drop Watcher. The owner ruling (R4) is recorded in the
major's API document as library-stack-§7 asks.

**What moves** (from Drop Watcher at `7c36f40`; the full boundary map — files, reads, settings, events, tangles —
is `docs/superpowers/research/2026-11-27-itemsearch-split/verdict-boundary.md`, written as the
plan's first task and fixed before any code moves):

| Library file (proposed) | From Drop Watcher | Kind |
|---|---|---|
| `Verdict.lua` (shell: `New(host)`, floors on Core) | `LootFeed.lua` `judgeMe`'s verdict half, the `comparison.*` config | seam |
| `VerdictEvaluate.lua` | `modules/Evaluate.lua`, `modules/OffSpec.lua` | pure |
| `VerdictTierTokens.lua` | `modules/TierTokens.lua`, the token parts of `core/TextParse.lua` | pure |
| `VerdictClassData.lua` | `core/ClassData.lua`, `core/ClassDataForever.lua` | pure data |
| `VerdictCollect.lua` | `modules/Collectibles.lua` (pure verdict + read; the feed refresh stays in DW) | pure + reads |
| `VerdictScore.lua` | `modules/Scoring.lua` (settings injected; the Pawn reads) | pure + reads |
| `VerdictFacts.lua` | `modules/ItemFacts.lua`, `core/ItemRead.lua` | reads + cache |
| `VerdictGear.lua` | `modules/Gear.lua` minus `Qualities` (the feed's gate input stays in DW) | player state |
| `VerdictReads.lua` | the ~40 client reads the above make (Compat members today) | reads |
| `VerdictSettings.lua` | the six `comparison.*` rows from `settings/SchemaRows.lua`, the weights editor (`settings/PageEditors.lua`) and the unwanted-types editor (`settings/ListEditors.lua`), as a section a host drops into its page (the `CalloutSettings.lua` shape); values stored at the host's path | settings section (R10) |

**Instance API** (shape; exact names settled in the library's `docs/api/Verdict/version-1-docs.md`):
`Verdict:New(host)` → `v`; `v:Judge(link)`, `v:JudgeFacts(facts, opts)`, `v:Facts(link)`,
`v:Request(link)`, `v:Snapshot()`, `v:Signature()`, `v:StandDown()`, `v:StandUp()`. The **pure kernel is a
public lib-level member** too (`Verdict.Evaluate(facts, candidate, opts)` and its `Equippability`,
`TierTokens`, `ClassData`, `OffSpec` helpers): Drop Watcher's group-side judging (`modules/Inspect.lua`
judging other members, roll cells, candidates) calls the same kernel with another player's candidate,
so there is never a second copy. That contract is characterized in the major's API document.
`host` supplies: `client` (`"retail"`/`"forever"`, which picks verdict mode, the class list and the
off-spec gate per instance, not at file load), `config()` (the six `comparison.*` values),
`debug(tag, msg)`, optional `perf`, optional `reads` (per-member overrides of `VerdictReads`, which is
how Drop Watcher keeps its simulator's guarded seam over every read), `inCombat()` (optional bag
defer), `L` (token vocabulary), `registerEvent`/`unregisterEvent` (or an AceEvent target from the
host's Bus), and `onChange(kind)` (gear, collection, score readiness) which the host turns into its own
bus message (`GEAR_CHANGED` in both addons).

Client reads inside a library major need no `core/Compat.lua` in the consumer (compat; the rule binds
calls made outside the library's majors), so Item Search does not copy the engine's reads. It still
has its own `core/Compat.lua` for its own reads (`CompatSearch.lua`'s, plus `HookItemTooltips`,
`AuctionPrice`, `AuctionatorLoaded`, `CoinText`, `ItemInfoByID`).

**Refactors done in Drop Watcher first, so the move is a pure move:** inject Scoring's settings;
split Collectibles' pure/read halves from its feed refresh; replace ItemFacts' transmog call into
Collectibles with a callback; make ClassData/OffSpec take the client from the instance; carve the
verdict's `comparison.*` config out of `LF.Config`.

**Standard ripple:** library-stack-§7's module table and its counts (26 → 27 majors, file count,
the inter-module dependency paragraph), `EXECUTIVE_SUMMARY.md`'s counts, the standard's changelog.

### 5.2 Ka0s Item Search (new addon, v0.1.0)

Scaffolded with the `NEW_ADDON.md` playbook (`.gitattributes` first, context pack read from temp,
never stored). Identity: folder `ItemSearch`, Title `Ka0s Item Search`, SavedVariables
`ItemSearchDB` + `ItemSearchPerfDB`, slash `/is` with `/itemsearch` as the long form, MIT, Ace3,
LibKa0s v1.119.0 vendored from the LibKa0s ship folder.

**Moves from Drop Watcher:** `modules/ItemSearch*.lua` (16 files), `settings/ItemSearch*.lua` (3),
`core/CompatSearch.lua`, `core/RecipeReagentsForever.lua`, `core/GatherNodes.lua`, `tools/seeds/recipes.py`
and its test, the `docs/validate-seeds.md` recipe/gather part, the `itemSearch.*` defaults (re-rooted
at the profile top level), the locale strings, the keybinding, the ForeverDB seam
(`core/ForeverDBSetup.lua`), and the 16 `test_item_search*` / tooltip test files (plus
`mock_tooltip_data.lua`).

**Shared Drop Watcher helpers it uses today** (`NS.Window.AttachTooltip`/`TextButton`/`SetButtonMark`,
`NS.WindowRows`, `NS.WindowTitleBar.Marks`, `NS.ContextMenu`, `NS.FooterMetric`, `NS.MakeResizable`,
`NS.MakeSearchBox`, `NS.GroupRoster.Colored`, `NS.QualityColor`, `NS.TipMarks`, `NS.RowTooltip`,
`NS.SkinSetup`'s seam): rebuilt in Item Search on the LibKa0s equivalents (Widgets `HeaderButtons`,
`ContextMenu`, `Footer`, `SearchBox`; Tooltip; Skin facade) where they exist, and as Item Search's own
thin helpers where they do not. Only a helper that clears library-stack-§7's bars goes upstream; the
badge pill and table-row helpers are evaluated there and promoted only if both addons would use them
with the same semantics (otherwise recorded in the run's research note as "kept local, why").

**Settings window:** its own panel (General with Master controls; the Item Search page's tabs as they
are today; Comparison, from the library's settings section (R10); Skin; Keybindings; Profiles), schema-driven, `/is list|get|set|reset`, diagnostics, debug
console, perf.

**Launcher:** Enabled · Locked (the window lock it already has) · Test mode · Show window (the Item
Search window). Skin picker preview: test. Sim mode checkbox: none.

**Test mode** (new, session-only): fills the window with a canned item set and its verdicts and shows
a sample tooltip block, without ForeverDB, behind the test strip (preview-mode).

**Keybinding:** `Bindings.xml` `CLICK ItemSearchKey:LeftButton`, default `ALT-CTRL-S` (R11), with the
same once-per-character free-key rule Drop Watcher used; the hint formats the key Ctrl-Alt-Shift order. No binding migration (R5).

**Optional dependencies:** ForeverDB, ForeverDB_Full, Auctionator, Pawn, TomTom.

**Docs:** README (player-facing), CLAUDE.md stub, DEPENDENCIES.md, `docs/` trio and the required
topic docs, the first automated-test bundle, Known Limitations (Retail absence, no migration from
Drop Watcher).

### 5.3 Drop Watcher afterwards (clean cut)

- Drop Watcher's every reader of `NS.Evaluate`, `NS.ClassData`, `NS.OffSpec`, `NS.TierTokens`,
  `NS.Scoring`, `NS.Collectibles`, `NS.ItemFacts`, `NS.ItemRead` and `NS.Gear` is rewired onto the
  library in step 2, under characterization tests (no behavior change).
- Remove every Item Search file, setting, default, locale string, keybinding row, the title-bar
  magnifier, the `search` slash verb and sim/diagnostics mentions; remove the tests.
- Remove now-unused optional deps (ForeverDB, TomTom, Auctionator if Item Search was its only reader)
  from TOC, DEPENDENCIES and Diagnostics.
- A migration step deletes the stale `itemSearch` profile/global data (the existing
  `NS.RetireItemSearchRows` pattern). It deletes Drop Watcher's own data; nothing is exported.
- README Version History (unreleased section) and the CurseForge text say Item Search is now Ka0s
  Item Search. Architecture docs, scope, module map, schema, smoke tests synced.
- The design spec and plans of #17 under `docs/superpowers/` stay (frozen evidence).

### 5.4 GitHub and the standard

- Create `tusharsaxena/ItemSearch` (public, MIT, same topics and labels as the other addon repos,
  including the `state:*` / `severity:*` labels). Transfer #18. Close #19 when the run merges, with a
  link to the new repo.
- `standards/ADDONS.md` row: `Ka0s Item Search | ../../ItemSearch/ | https://github.com/tusharsaxena/ItemSearch | Forever | Enabled · Locked · Test mode · Show window (the Item Search window) | test | none`.
- If the standard's own process requires a version bump for the roster row and the §7 ripple, that is
  raised with the owner at that point (R8 covers LibKa0s only).

## 6. Order of work

1. **LibKa0s:** the pre-move refactors land in Drop Watcher first (behavior-neutral, gate green), then
   the major is built in LibKa0s with the moved code and its tests, API docs, CHANGELOG, v1.119.0.
2. **In parallel**, once the library branch is green: Drop Watcher switches to the major (vendored
   from the library branch build); Item Search is scaffolded and ported on it.
3. Drop Watcher clean cut.
4. Standard: roster row and §7 ripple.
5. Reviews: a code review per repo, a standards audit of Item Search, both addons' green gates on
   Retail and Forever (Item Search: Forever only).
6. Owner go-ahead → merge in dependency order (LibKa0s → tag v1.119.0 → re-verify vendored bytes
   against the tag in both addons → Drop Watcher → Item Search → WowAddonStandards), transfer #18,
   close #19, delete the run's branches, stashes and worktrees.

## 7. Deviations

None planned. Anything that turns up mid-run is stopped and raised (CLAUDE.md).

## 8. Left to the builder

File-level splitting inside the major (the table above is a proposal), the exact API member names,
how Item Search's thin UI helpers are named and split, Test mode's canned data, the test file
re-organization in Item Search, and every naming choice the standard does not fix.
