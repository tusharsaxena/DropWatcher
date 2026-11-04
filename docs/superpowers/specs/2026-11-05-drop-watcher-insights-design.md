# Ka0s Drop Watcher: Insights tab design (GitHub #12)

Status: design, ready to plan. It is built after #13 (run plan M4: DW-N1..DW-N4) and after the LibKa0s v1.87.0 re-vendor (DW-T1).

Inputs:
- issue #12;
- the owner's decisions of 2026-11-05 (run plan `docs/superpowers/plans/2026-11-05-issues-10-14.md`, Decisions, #12);
- LibKa0s-Charts-1.0 v1.1 (`../LibKa0s/docs/api/Charts/version-1.1-docs.md`), vendored as `libs/LibKa0s/Charts.lua` (`MINOR = 1`) and `ChartsRender.lua` (`RENDER_MINOR = 1`) and already loaded through `libs/LibKa0s/LibKa0s.xml`;
- Ka0s DPS Race's Insights (`../DpsRace/modules/Results_Insights.lua`, `Results_InsightsData.lua`, `core/ChartsSetup.lua`);
- Ka0s Loot History's `docs/browser.md` "Insights tab — Analytics";
- the real account history (`WTF/.../SavedVariables/DropWatcher.lua`, read on 2026-11-05).

**Owner decisions this design must honor** (run plan, #12):
- an Insights tab after History;
- built on the vendored LibKa0s-Charts-1.0, with no private chart copy;
- **every** candidate insight in the issue is built, even the sparse ones;
- its own data-driven filters: Character, Instance, Difficulty, Situation, Date, Quality, and Category from #13;
- the tab names the period it covers (`history.retentionDays`);
- built after #13.

**Pre-flight at DW-N1 start:** confirm that the DW-T1 re-vendor (v1.87.0) left `Charts.lua` at minor 1 and `ChartsRender.lua` at render minor 1. If either moved, re-read the API doc before DW-N2. Also confirm the field name and key set DW-C3 writes on a History entry for #13's category. This design assumes `e.category`.

---

## 0. What the real history says (and three things it changes)

The facts come from the account's `global.history` as saved on 2026-11-05:
- 160 groups and 452 drops;
- 23 active days, from 2026-10-11 to 2026-11-05;
- 8 recorders, plus 7 drops with no recorder;
- `retentionDays` unset, so the schema default of 30 applies (`NS.HistoryRetention.DEFAULT_DAYS`).

| Field | Distribution |
|---|---|
| `outcome` | seen 425, expired 9, received 8, tradedAway 6, offered 3, asked 1, declined 0 |
| `isMine` | 204 yours, 248 others'. Others': seen 239, received 8, asked 1. Yours: seen 186, expired 9, tradedAway 6, offered 3 |
| `me.verdict` | cantUse 198, downgrade 171, sidegrade 55, upgrade 26, unknown 2. Off-spec parts: downgrade 6, sidegrade 1, upgrade 1 |
| `trade.state` | likely 263, no 153, yes 20, unknown 16 |
| `quality` | Epic 431, Rare 21 |
| `equipLoc` | 20 slots, plus `INVTYPE_NON_EQUIP_IGNORE` 12 (Dreamheart tier tokens, Venomforged Icon/Remnant) |
| group `kind` | run 118, encounter 30, area 12 |
| group `situation` | mythicPlus 118, raid 19, delve 7, solo 7, dungeon 5, openWorldGroup 2, raidLFR 2 |
| group `difficulty` | Mythic+ 6..16 (11 distinct levels), Mythic 19, LFR 2, Heroic 1, Delves 7, none 17 |
| group `instance` | 143 set. The 17 without one: 9 `area` "Open world", 4 `encounter` groups labeled by boss, 4 `run` groups labeled by dungeon |
| received | all 8 from others, every one recorded as `sidegrade 0` or `downgrade -7` |

Three findings shape the definitions below.

1. **"Asked" is lost once an entry moves on.**
   - A completed trade's `settle` (`modules/History.lua:667`) writes `m.entry.outcome, m.entry.before = m.outcome, nil` directly. It does not go through `H.Advance`.
   - `H.Advance` itself clears `before`, and only an advance to `expired` keeps the outcome it replaced (`beforeExpired`).
   - So `asked` survives only in `beforeExpired` (after an automatic expiry) or in `before` (after a manual decline, `H.SetDeclined`).
   - The current data therefore cannot count "asks sent" or "success rate" exactly: 8 items were received and only 1 entry still reads `asked`.
   - **Decision:** DW-N1 adds sticky stamps (`askedAt`, `offeredAt`, `settledAt`) and a legacy inference rule (§1.2).
2. **The ilvl recorded for a received item is post-equip, not the gain.**
   - `LF.OnGearChanged` (`modules/LootFeed.lua:892`) re-judges every live drop and sends `DROP_UPDATED`.
   - `H.OnDropUpdated` → `H.Refresh` → `takeSnaps` (`modules/History.lua:223`) then overwrites `e.me`.
   - Once you equip the item you received, it is compared with itself and becomes `sidegrade 0`. That explains the 7-of-8 pattern in the real data.
   - **Decision:** DW-N1 freezes the verdict at receipt (`got`), with a legacy fallback that is marked as such (§1.2).
3. **Mythic+ keys have no per-boss groups.** A key is one `run` group labeled with the dungeon. "Upgrades by boss" can therefore only count `encounter` groups: raids, and dungeons run without a key. The section says so in its empty state.

---

## 1. Metric definitions

### 1.1 Per-drop reads (the facet and stat accessors)

`e` is a drop entry and `g` is its group. All of these are pure and live in `InsightsFilters` (§3), which computes them once per row.

| Accessor | Definition | Legacy fallback |
|---|---|---|
| `char(e,g)` | `e.seenBy or g.seenBy` | nil: the key `"unknown"`, shown as "Not recorded" (7 real drops). History's own Character filter (`CF.Characters`, `CF.Passes`) reads `e.seenBy` only, so a drop with only a group recorder is "Not recorded" there and named here. This is intended (Insights recovers more) and is recorded in `docs/known-limitations.md` |
| `charClass` | `e.seenByClass or g.seenByClass` | nil: no color |
| `instance(g)` | `g.instance or g.label` | area: "Open world". encounter without an instance: the boss label |
| `difficulty(g)` | `g.difficulty` | nil: the key `"none"`, shown as "No difficulty" |
| `situation(g)` | `g.situation` | nil: `"unknown"` |
| `quality(e)` | `e.quality` | nil: `"unknown"` |
| `category(e)` | `e.category` (the key DW-C3 writes) | nil: **`"equipment"`** (see Q3) |
| `day(e)` | local midnight of `e.at`: `date("*t")`, then `time{...hour=0}`. This is DST-safe, as DPS Race's `midnight` is | |
| `mine(e)` | `e.isMine == true` | |
| `upgradeForMe(e)` | `e.me.verdict == "upgrade"` or `NS.OffSpec.Of(e.me).verdict == "upgrade"` | |
| `asked(e)` | `NS.History.WasAsked(e)` (see below) | |
| `offered(e)` | `NS.History.WasOffered(e)` (see below) | |
| `askAt(e)` | `e.askedAt or e.at` | |
| `gain(e)` | `NS.OffSpec.EvalFor(e.got or e.me).ilvlDelta` | `e.settledAt == nil`: flagged `legacy` ("as last judged"). nil `ilvlDelta` (no comparable item): no row in F; counted in F's hover as "n without an item level comparison" |

Notes on the accessors:
- **`upgradeForMe`** mirrors the filter bar's rule. That rule is the file-local `upgradeForMe` in `modules/WindowFilterBar.lua` (about line 320), which is not exported. Insights re-implements it on the snapshot shape, and a parity test checks both on the same fixtures.
- **`asked` and `offered` live in `NS.History`.** Today History keeps a file-local `wasAsked`. DW-N1 publishes it as the pure `H.WasAsked(e)`, and `H.AskState` keeps calling it, so one rule serves the Ask button and Insights. `H.WasOffered(e)` is added next to it. Definitions:
  - `H.WasAsked(e)` is true when any of these holds: `e.askedAt ~= nil`; `e.outcome == "asked"`; `e.before == "asked"`; `e.beforeExpired == "asked"`; or (**legacy**) `not e.isMine and e.outcome == "received" and e.settledAt == nil`.
  - `H.WasOffered(e)` follows the same shape for `offered`, with the legacy case `e.isMine and e.outcome == "tradedAway" and e.settledAt == nil`.
  - The legacy test keys on `settledAt`, which every post-N1 settle writes. Keying on `got` would have misread a post-N1 trade with no ask, or with no verdict, as a legacy ask or offer.
- **Colors are answered as triples** (`NS.QualityColor(q)` and `NS.Compat.ClassColor(class)` both return `r, g, b`, or nil). The row builders wrap them into the `{r,g,b}` tables the Charts rows take. A nil answer means no color, so the Charts default applies.

### 1.2 The new History fields (DW-N1, additive, no migration)

The fields are written in `modules/History.lua`. An entry that lacks them is a legacy entry, and the readers in 1.1 handle it.

- **`askedAt`** (`time()`) is set once in `H.OnAskState` when `state == "sent"` and `kind == "ask"`.
  - **`offeredAt`** is set the same way for `kind` `offer` and `announce`, the `SENT_OUTCOME` table's keys.
  - Both are set whether or not `H.Advance` moves the outcome. An ask sent after the drop expired still stamps.
  - A later call never overwrites them.
  - **`H.OnAskState` must send `HISTORY_CHANGED` when it stamps, even when the advance did not move the outcome.** Today it sends only on an advance, so the Insights cache would go stale.
- **`settledAt`** (`time()`) is set in `settle` (`modules/History.lua:667`) on every entry a completed trade settles, both `received` and `tradedAway`. It is what tells a post-N1 settle from a legacy one.
- **`got = { verdict, ilvlDelta, scoreDelta, offSpec?, at }`** is a copy of `e.me` (the `verdictSnap` shape) taken in `settle`.
  - It is taken only for `received`, and only when `e.got == nil`.
  - It is taken before any later gear re-judge, because trade completion comes before you can equip the item.
  - When `e.me` is nil, `got = { at = now }`, so `got` and `settledAt` always arrive together on a received entry.
  - Nothing writes it again. `H.Refresh`, `takeSnaps` and `H.SetDeclined` leave it alone.
  - Your own `tradedAway` drops get `settledAt` but no `got`.
- **`H.VERSION` stays 1**, because the fields are optional and additive. `H.Normalize` needs no step. `docs/schema.md` documents them.
  - **Flag (savedvariables):** under the standard's migration rules, an additive optional field needs no migration step. Ask if a version bump is wanted anyway.
- The header comment of `modules/History.lua` gains a paragraph on the stamps and `got`.

### 1.3 Cards (owner's six, plus two proposed: Q4)

All counts run over the filtered rows. The figures in brackets are the real data, unfiltered.

| Card | Figure | Definition | Hover |
|---|---|---|---|
| Drops seen | `n` [452] | every filtered drop, yours included | "n yours, m by others" |
| Upgrades for me | `u` [27: 26 main, 1 off-spec] | `upgradeForMe` | "x looted by you, y by others; z on another spec" |
| Asks sent | `a` [9: 1 asked plus 8 legacy-inferred] | `not mine and asked(e)` | "k recorded before asks were stamped (counted from items received)" when k > 0 |
| Items received | `r` [8] | `outcome == "received"` | "From n group members" |
| Ask success | `r_a / a` as a percentage [89%] | asks whose outcome is `received`, over asks sent. A dash when `a == 0`. A received item you never asked for (post-N1: `received` with `settledAt` and no `askedAt`) is not in the rate | "r_a of a asks ended in a trade", plus "legacy asks are inferred from items received, so the rate reads high" when `asksLegacy > 0` |
| Active days | `d` [23] | distinct `day(e)` | "first .. last" |
| *Offers sent* (proposed) | [9: 3 plus 6 legacy] | `mine and offered(e)` | legacy hover as for asks |
| *Traded away* (proposed) | [6] | `mine and outcome == "tradedAway"` | |

With eight cards, the grid is 4 columns × 2 rows in the full layout and 2 × 4 in compact.

### 1.4 Sections (every candidate, plus the ones the data earns)

| # | Section | Definition | Real data (unfiltered) |
|---|---|---|---|
| A | **Drops by outcome** | Three stacked rows. **Others' drops**: Traded to me (`received`), Asked, no trade (`asked`), Declined, Expired, Kept by the looter (`seen`). **Upgrades for me, looted by others**: the same segments over the `upgradeForMe` subset. **Your drops**: Traded away, Offered, Declined, Expired, Kept (`seen`). Segment `frac` = count / the largest row total, which is the Charts contract: the caller divides. A legend follows (`renderLegend`, its own pool) | 248 / ~20 / 204 |
| B | **Upgrades for me by instance** | `instance(g)` over `upgradeForMe`, stacked "Looted by you" / "Looted by others", top 10 by total, with a legend | Altar of Fangs 6, Ruby Life Pools 6, Temple 4, ... |
| C | **Upgrades for me by boss** | `g.label` over `upgradeForMe` where `g.kind == "encounter"`. Sublabel `instance · difficulty`. Top 10. Empty state: "No boss kills in these filters. Mythic+ keys are kept as whole runs." | sparse |
| D | **Top instances for upgrades** | per `instance(g)` with at least **2 visits** (distinct groups): `upgrades / visits`. List panel with right column `0.43 / visit` and hover `6 upgrades in 14 visits`. Capped at `Charts.K.LIST_MAX` (10) | Ruby .43, Altar .38, Temple .25 |
| E | **Most generous group members** | `e.looter` over `outcome == "received"`, by count descending, then most recent. Name in the `e.class` color. Hover lists the items. Capped at 10 | 5 members, top 2 each |
| F | **Item level gained from items received** | one range row per received item with a non-nil `gain`, from `lo = min(0,gain)` to `hi = max(0,gain)` with `mark = 0`. Label: the item name in its quality color (the library cuts a label at `K.LABEL_MAXCHARS`, 16 glyphs; the hover shows it whole). Sublabel: `from <looter> · <day>`, plus "as last judged" when legacy. Value `+7`. Header suffix: `+N in all` (positive gains summed). When there are more than 10 rows: the 10 biggest by absolute gain, with "n more". All-zero gains are safe: `Charts.RangeScale` opens the scale ±1 | 8 rows, all legacy |
| G | **Asks per day** | strip of daily buckets over the period (§3.4). Count = asks with `day(askAt)` = bucket. Bucket shape `{ count, label, info }`. Hover `Oct 22: 2 asks, 1 offer` | 1..9 sparse |
| H | **Drops per day** *(added: data earns it)* | strip, the same buckets, count = drops seen. Hover adds upgrades | busy |
| I | **Drops by looter class** | `e.class`, class color (`NS.Compat.ClassColor`, wrapped), localized class name | 13 classes |
| J | **Drops by quality** | `e.quality`, `NS.QualityColor` (wrapped), `NS.Item.QualityLabel` | Epic / Rare |
| K | **Drops by slot** | `WC.SlotLabel(e.equipLoc)` (ROBE folds into Chest). `SlotLabel` answers nil for an unlisted `equipLoc` (`INVTYPE_NON_EQUIP_IGNORE`, the 12 real tokens). A non-equipment category (#13) shows under its category label; anything else under "Other" | 20 rows plus Tier token / Other |
| L | **Drops by category** | `category(e)` in #13's order and labels | Equipment 452 on old data |
| M | **Your verdicts** *(added)* | `me.verdict` buckets: Upgrade, Sidegrade, Downgrade, Can't use (hover "n usable on another spec"), Unknown, and #13's New to collection / Already collected. Colors from the owner tokens `dw.upgrade`, `dw.sidegrade`, `dw.downgrade`, `dw.cantUse`, `dw.notWanted` | 5 rows |
| N | **Trade estimates on others' drops** *(added)* | `trade.state` over `not mine`: Yes, Likely, No, Unknown. Toned through `WC.TRADE_TONE`, which answers tone **names** (`good`, `red`, `muted`); the color is `NS.Constants.TONE[name]`, a table `NS.RefillPalette` refills on a skin switch | 4 rows |

**Empty states.**
- **Bar, stacked, range and strip renderers hide the header and return the cursor unchanged when `rows` is empty** (`if #rows == 0 then header:Hide(); return y end`). So the layout pass checks `#rows == 0` **before** calling the renderer, and draws the empty state itself (§5.3): it places the heading with `ctx:placeHeader`, then one muted line under it, for example "No items received in these filters."
- **`renderListPanel` returns the panel's height, not a cursor,** and draws an empty panel with one row's height for 0 rows. D and E put their empty line inside the panel.
- **No row passes the filters at all:** the cards and sections hide, and one centered line shows: "No drops match these filters."
- **Empty log:** the line reads "No history yet. Drops your group receives are kept for N days." N is `R.Days()`; with retention 0 the line reads "... are kept until you clear them".

---

## 2. The stats module (pure)

### 2.1 Files

- `modules/InsightsFilters.lua`, `NS.InsightsFilters` (pure, about 330 lines): rows, facets, filter, faceted options, normalize, date ranges, period.
- `modules/InsightsStats.lua`, `NS.InsightsStats` (pure, about 420 lines): the one stats pass.

Both read only:
- plain tables and the clock passed in;
- `date`/`time` at call time;
- `NS.L`;
- the pure `NS.OffSpec.Of` / `EvalFor` and `NS.History.WasAsked` / `WasOffered`;
- `NS.Constants.SITUATIONS` and `NS.HistoryRetention.DAYS`.

They build their labels at call time from `NS.WindowFooter.SituationLabel`, `NS.Item.QualityLabel`, `NS.WindowCells.SlotLabel` and #13's category labels. These are call-time reads, so load order does not matter (conventional TOC position).

### 2.2 API

```lua
-- InsightsFilters
IF.DEFAULTS = { char="all", instance="all", difficulty="all", situation="all",
                date="all", quality="all", category="all" }
IF.ORDER    = { "char","instance","difficulty","situation","date","quality","category" }
IF.Rows(groups)                 --> { {e=, g=, char=, charClass=, instance=, difficulty=,
                                --      situation=, quality=, category=, at=, day=} ... }
                                --  one per drop, facets precomputed; skips non-tables
IF.Ranges(retentionDays)        --> { "all", "today", "7", "14", ... } offered values (§3.4)
IF.Since(range, now)            --> epoch | nil
IF.Filter(rows, f, now)         --> rows passing every filter (order kept)
IF.Options(rows, f, now)        --> { [key] = { {value,label,name,count,color?,choices?}, ... } }
IF.Normalize(rows, f, now, keep)--> f', options   (zero-count picks fall back to "all"; keep never)
IF.ClosedLabel(options, value)  --> "All instances (12)" | "Ruby Life Pools"
IF.Period(rows, days, range, now) --> { from, to, first, last, days, range, groups, drops }

-- InsightsStats
IS.Compute(rows, period)        --> stats (below)
```

The dropdown rows `Options` answers are the LibKa0s-Widgets dropdown's option shape: `value`, `label`, `color` (a `{r,g,b}`), `tooltip`. `name` and `count` are extra fields for `ClosedLabel` and the tests.

### 2.3 Stats shape

```lua
{
  totals = { drops, mine, others, upgrades, upgradesMine, upgradesOff, asks, asksLegacy,
             askHits, received, success|nil, offers, offersLegacy, tradedAway,
             activeDays, first, last, gainSum, gainN, gainLegacy, gainNone },
  outcomes   = { others = {received, asked, declined, expired, kept},
                 upgrades = {...same...}, mine = {tradedAway, offered, declined, expired, kept} },
  byInstance = { {key, upgrades, mine, others} ... },            -- B, sorted, all
  byBoss     = { {label, instance, difficulty, upgrades} ... },  -- C
  topRate    = { {key, upgrades, visits, rate} ... },            -- D, visits >= 2
  generous   = { {looter, class, n, last, items={e...}} ... },   -- E
  received   = { {e, looter, gain, legacy, at} ... },            -- F (gain ~= nil only)
  perDay     = { {day, drops, asks, offers, upgrades} ... },     -- G, H: continuous buckets
  byClass, byQuality, bySlot, byCategory, verdicts, tradeStates  -- I..N: ordered { {key, n} } lists
}
```

### 2.4 One pass

The pattern is DPS Race's:
- `REDUCERS` is an array of small functions `(acc, row)`, one per concern: totals, outcomes, instance/boss/visits, generous/received, day, mix.
- `Compute` walks `rows` once and hands each row to every reducer.
- `FINALIZERS` then sort, cap and bucket the results: continuous days, and week buckets above 62 days.

Each reducer and finalizer stays well under CCN 15. The outcome-to-segment mapping is a lookup table, not a chain of `if`s. A new section is one reducer and one finalizer.

---

## 3. Filters model

### 3.1 The seven dropdowns

All seven are **single-select** with an "all" head, the DPS Race #12 model. See Q6 for the difference from History's multi-select Character.

| Key | Values | Order | Label and color |
|---|---|---|---|
| char | recorder keys plus `unknown` | your key (`CF.CurrentKey()`) first, then by count | `CF.IconMarkup(class) .. name`, class color; `unknown` is "Not recorded" |
| instance | `instance(g)` | alphabetical | |
| difficulty | `g.difficulty` plus `none` | natural: Mythic+ by level descending, Mythic, Heroic, Normal, Looking For Raid, Timewalking, Delves, others alphabetical, No difficulty last (a rank function over a pattern table) | |
| situation | `g.situation` plus `unknown` | `NS.Constants.SITUATIONS` order (`WF.SITUATION_LABEL` is a hash with no order), `unknown` last | `WF.SituationLabel` |
| date | §3.4 | fixed, nested | |
| quality | numbers | descending | `NS.QualityColor` (wrapped) |
| category | #13 keys | #13's order | #13's label |

### 3.2 Data-driven options (one pass, faceted)

This is the algorithm of DPS Race's `InsightsData.Options`. Each row is checked against all seven filters once:
- a row that fails **none** counts toward every dropdown;
- a row that fails **exactly one** counts toward that dropdown only;
- a row that fails two or more counts toward none.

So each dropdown lists the values that are present once the *other* filters apply, each with its count (`Ruby Life Pools (14)`).
- The current pick is always listed, at 0 when nothing matches it.
- The head row reads `All instances (452)` and carries `choices`, the number of values under it.
- Closed, the head shows `All instances (12)`: `ClosedLabel`, put on the button with `dd:SetValue(value, label)` after every refresh. Open, each row keeps its drop count.
- The date ranges nest, so all of them are always listed, with their counts.

### 3.3 Normalize

`IF.Normalize(rows, f, now, keep)` checks every key except `keep` (the dropdown just changed), in `ORDER`. When a pick has count 0, it falls back to "all" and the options are recomputed before the next key is checked. The input `f` is never written.

### 3.4 Date range and period

- **Range values:** `all` (every kept day), `today` (since local midnight), and `N` days (since the local midnight N-1 days ago).
  - `N` is taken from `NS.HistoryRetention.DAYS` (7, 14, 30, 60, 90, 180, with 0 excluded) where `N < retentionDays`.
  - With retention 0 (never delete), all of them are offered.
  - With the default 30, the menu is All kept, Today, Last 7 days, Last 14 days.
- **Period** (`IF.Period`): `to = now`. `from = Since(range)`; for `all`, `from = max(now - days*86400, first drop)`; with days = 0, `from` is the first drop.
  - Retention prunes whole groups by their newest drop (`R.Prune`, `R.NewestAt`), so `first` can be older than `now - days*86400`. The caption's start is `from`, and the counts are what the rows hold.
- **Caption** (`InsightsRows.PeriodText`, shown on the tab's strip and in the tab tooltip):
  - range all, days 30: `Kept for 30 days: Oct 11 – Nov 5 · 452 drops in 160 groups`
  - days 0: `Every kept day: since Oct 11 · ...`
  - range 7: `Last 7 days (Oct 30 – Nov 5) of 30 kept · 84 drops in 31 groups`
- **Strip buckets:** one per local day from `from` to today when the period is 62 days or less, otherwise one per week.
  - Days are walked with `nextDay` (add 86400 + 3600, then re-midnight), so DST never skips or doubles a day.
  - `Charts.StripSlots` caps a slot at 48 px, and `StripLabels` thins the labels.

### 3.5 State

- The filter state is session-only: `NS.State.insightsFilters`, like `NS.State.windowFilters`. It is declared `nil` in `core/State.lua`.
- It has no schema row and no saved view.
- A **Reset filters** button on the tab's strip (`NS.FooterRow.Button(strip, "reset", L["Reset filters"], fn)`) returns it to `DEFAULTS`.
- `docs/schema.md`'s session-only list names it.
- Test mode and a simulation keep the same state, and Normalize corrects it against the log in force.

---

## 4. Tab integration

### 4.1 Window tab registry (`modules/Window.lua`, about +35 lines, 1025 to about 1060)

**layout-§1 band:** `Window.lua` is already in the 1000–1500 on-notice band. The growth below keeps it there, and the watch-list row (automated-tests-§4) is updated. If the edit would pass about 1060 lines, peel the tab registry (`TABS`, `TAB_SET`, `TAB_LABEL`, `TAB_TIP`, `TAB_PLACEHOLDER`, `tabTip`, the `ownBar` read) into `modules/WindowTabs.lua` (load-bearing, before `Window.lua`). Do this as its own commit before DW-N2's feature commit.

- **The tab tables:** `Window.TABS = { "group", "history", "insights" }`, plus `TAB_SET`, `TAB_LABEL` (`L["Insights"]`), `TAB_TIP` and `TAB_PLACEHOLDER`.
- **The tooltip:** `TAB_TIP.insights` is a **function**, because it names the period: `{ Holds: "charts over the kept history", Covers: <R.Label(R.Days())-based text> }`. `tabTip` (Window.lua:292), which today iterates a table, learns to call a function value first.
- **`ownBar`:** `Window.RegisterTab(key, spec)` gains an optional `spec.ownBar = true`. While the active tab's spec has `ownBar`:
  - `f.filterHost` is hidden.
  - `layoutPanes` puts that pane's top at `K.TAB_H + 4 (+ banner)`, with no `K.FILTER_H`. `layoutPanes` becomes per pane.
  - **The mode strips are re-anchored.** `f.banner` and `f.simBanner` are anchored to `f.filterHost`'s BOTTOMLEFT (`anchorStrip`), and a hidden host still positions them, so they would float `K.FILTER_H` below where the pane now starts. `layoutPanes` re-anchors both to `f.body` TOPLEFT at `-(K.TAB_H + 4)` while an `ownBar` tab is active, and back to `filterHost` otherwise.
  - `NS.WindowFilterBar.Sync` is not called for an `ownBar` tab (the call site in `Window.Refresh` checks), and `FB.Sync` also returns early for a tab with an empty HONORS row.
  - On switching in, `NS.CloseMenu()` and `NS.CompactChrome.CloseFilters()` run.
  - **The footer's Sort control is hidden.** `WF.AnchorSort` falls back to `footerHost` for a pane with no `sortHost`, and `WF.Refresh` grays it by `FB.HONORS[tab].sort`, which would put a dead Sort in the Insights footer. `WF.Refresh` hides `sortDropdown` while the active tab's spec has `ownBar`, through a `Window.TabOwnsBar(tab)` reader.
- **Why a bar of its own and not the shared bar?** The shared bar's controls (View, Quality mode, Content, Character, search, Sort) do not apply here. Its convention ("grayed, never reflowed", from Loot History) would put a fully grayed bar above a second one. DPS Race's Insights draws its own bar inside the pane, and this follows it.
  - This is a **DropWatcher convention, not a standard rule**. The `WindowFilterBar.lua` header comment (lines 8–9) records the exception.
- **`FB.HONORS.insights = {}`** guards every `FB.HONORS[tab]` index against nil:
  - `grayedTip` and `qualityDropdown` (WindowFilterBar.lua:580, 661);
  - `FB.Sync`;
  - `WF.Refresh` (WindowFooter.lua, about line 285);
  - `CompactChrome`'s `paintFilters` and the Filters tip (CompactChrome.lua:249, 490), which run whenever the Filters button's own shown flag is set, even with its parent `filterHost` hidden.

  `FB.CONTENTS` and `FB.TAB_FIXED` are not needed. `Window.TabContext("insights")` still seeds an unused `FB.State("insights")`, which is harmless. The Insights refresh ignores `tc`.
- The countdown ticker stays Drops-only (it is gated on `activeTab == "group"`).
- `/dw insights` opens the tab (Q5). It is a row in `settings/Slash.lua` (`{"insights", L["Open the Insights tab"], function() NS.SlashVerbs.OpenTab("insights") end}`), in parity with `/dw history`. `V.OpenTab`'s doc comment names the third key.

### 4.2 Compact layout (`modules/CompactChrome.lua`, about +3 lines)

- `SHORT_TAB.insights = L["Insights"]`. Three tabs at `CC.TAB_W` 84 plus gaps take about 260 px, which fits the 400 px minimum. In the full layout, 3 × `K.TAB_W` 118 fits as well.
- The Insights pane is the same in both layouts, re-laid out by width:
  - the **bar wraps** (`InsightsRows.BarPlan(width)`): dropdown rows are packed left to right at a 104 px floor each, which gives 1 row at 1080 px and 4 rows at 400 px. Reset sits on the strip in both layouts.
  - cards are 4 columns in full and 2 in compact (`CardGrid`, with a short last row stretched).
  - list panels D and E sit side by side in full and stack in compact.
- There is no Filters ▾ panel and no separate compact body: the pane is already single-column, so it fits. The compact Filters button lives on the hidden `filterHost`, and `CloseFilters` runs on switching in (§4.1).

### 4.3 The tab body (`modules/WindowInsights.lua`, edge, load-bearing)

`NS.Window.RegisterTab("insights", { build = build, refresh = refresh, ownBar = true })` runs at load, so the file sits after `Window.lua` in the TOC.

**build(pane):**
1. The bar: `NS.MakeDropdown(pane, w)` × 7, each with `onSelect → SetFilter(key, v)`.
   - `NS.MakeDropdown` answers **nil** when LibKa0s-Widgets is absent. The bar then draws no dropdowns, the filters stay at `DEFAULTS`, and the charts still draw. This is the same shape as the shared bar's degradation.
2. A `ScrollFrame` with content: `NS.Skin.ScrollBar(rawget(scroll, "ScrollBar"))`, as WindowHistory does, with a wheel step of 40.
3. `ctx = NS.Charts:New(content, NS.ChartsHost())`.
4. The chrome the sections place:
   - 8 `ctx:card`s;
   - headings (`ctx:sectionHeader`) and dividers (`ctx:sectionDivider`);
   - 2 `ctx:strip`s and 2 `ctx:listPanel`s;
   - the empty line;
   - the bottom strip: a `K.STRIP_H` row like History's, with the period caption on the left (`FR.PlaceInfo`) and the Reset filters button on the right (`FR.Button` with the `reset` icon, which is in the declared LibKa0s icon set; `FR.Place`).

Without the Charts library, only the bar, the strip and the line "The charts need LibKa0s-Charts-1.0, which did not load." are built.

**refresh(pane, tc)** is cheap when nothing changed. `Window.Refresh` runs on many bus messages, so refresh compares a **cache key**: `{ H.Log() identity, H.Log().groups identity, revision, NS.State.testMode == true, NS.Sim:IsActive(), filter signature, R.Days(), local day, width, compact }`.
- **Why both identities.** Test mode's log is one persistent table (`State.testHistory`) whose `.groups` `TM.fill` swaps. Turning test mode off sends no `HISTORY_CHANGED`, so the swap is seen only through identity and the mode flags.
- `revision` is bumped by the tab's own tracked `HISTORY_CHANGED` receiver: `NS.Bus:NewTarget()`, with the `STAND_DOWN`/`STAND_UP` pair, as in WindowHistory.lua:687–703. That receiver also calls `NS.Window.ScheduleRepaint()`.
- When only the width or layout changed, it re-lays out.
- When the data or filters changed, it runs `Rows → Normalize → Filter → Period → Compute`, then lays out.
- When the key is unchanged, it does nothing.
- Brackets: `Perf.Note("insights.compute", ...)` and `"insights.layout"` under `if Perf.on`. One `NS.Debug("UI", "insights: %d drops, %d after filters", ...)` line per recompute.

**Test mode and the simulator come for free:**
- `H.Log()` already answers test mode's sample log (`NS.TestMode.HistoryLog`) and a running simulation's session log (`NS.SimHost.HistoryLog`). The cache key sees each swap (identity or flags).
- `TM.fill`, `H.ReleaseLog` and the retention prune send `HISTORY_CHANGED`.
- Every card and chart then shows the samples, or the simulation's drops, asks and trades.
- `SimEvents.Trade` (`E.Trade`) drives a real trade through `TRADE_SHOW` … `UI_INFO_MESSAGE`. `settle` writes the simulation's log (`H.LogFor(t.sim)`), so it exercises `settledAt`, `got` and the stamps end to end.

**Resize:** `onResizeStop → Window.Refresh` changes the width, which re-lays out without recomputing.

### 4.4 Charts host and skin owner (`core/ChartsSetup.lua`, new, about 50 lines)

```lua
local addonName, NS = ...
NS.Charts = LibStub and LibStub("LibKa0s-Charts-1.0", true)   -- nil: the tab's library-absent state
if not NS.Charts then NS.Debug("UI", "LibKa0s-Charts-1.0 absent: the Insights tab draws no charts") end
function NS.ChartsHost()
  return { owner = addonName, pool = NS.Pool,
           onReskin = function(_ctx) NS.WindowInsights.MarkLayout() end }
end
```

- `NS.Pool` (core/PoolSetup.lua) is the `New / Acquire / ReleaseAll` API `Charts:New` takes as `host.pool`. It is never nil: PoolSetup has its own fallback, so `New` never raises.
- The skin owner is `DropWatcher`, the same owner `core/SkinSetup.lua` registers. Colors, fonts, panels, bar textures and the `chart.series` palette all come from the applied skin's tokens.
  - The context reskins itself on the owner's `OnLooksChanged` (`ctx:Reskin`).
  - `onReskin(ctx)` marks a re-layout, so the rows whose colors the host chose (class, quality, verdict, trade tone, all read at bind time) are rebound.
- The default `GameTooltip` hover is kept (the Loot History look). No new `dw.*` owner tokens are needed. Outcome segments use:
  - the existing `dw.upgrade` (received);
  - `dw.cantUse` (declined);
  - `dw.urgent` (expired);
  - `dw.offer` (offered or traded away);
  - the library's `chart.other` (kept).
- **The degradation says once that the library is missing** (library-stack-§7): one `NS.Debug` line at load, plus a row in the diagnostics report's library list if it lists majors. Following DPS Race and anti-pattern #73, it is not a drawing stub.
- TOC: `core\ChartsSetup.lua` goes right after `core\WidgetsSetup.lua`, which is a conventional position. Its TOC line carries the one-line description comment the TOC uses for every file.
- `docs/ARCHITECTURE.md`'s majors table gains a Charts row, and the Overview's "nineteen wired ... `LibKa0s-Charts-1.0` deliberately unwired, since this addon draws no chart" becomes "twenty wired". The payload version in that sentence is whatever DW-T1 left.

---

## 5. Layout

The full layout's content width is about 1046 px. Compact is about 366 px.

```
┌ bar: Character ▾  Instance ▾  Difficulty ▾  Situation ▾  Date ▾  Quality ▾  Category ▾ ┐
│ [Drops seen][Upgrades for me][Asks sent][Items received]                     (ctx:card) │
│ [Ask success][Active days][Offers sent][Traded away]                                    │
│ ── LOOT ──                                                       (ctx:sectionDivider)   │
│ A Drops by outcome            renderStackedBarSection + renderLegend                    │
│ M Your verdicts               renderBarSection (dw.* verdict colors)                    │
│ N Trade estimates             renderBarSection (C.TONE[TRADE_TONE[state]])              │
│ ── UPGRADES ──                                                                          │
│ B Upgrades by instance        renderStackedBarSection + renderLegend (you / others)     │
│ C Upgrades by boss            renderBarSection (sublabel: instance · difficulty)        │
│ D Top instances | E Most generous   renderListPanel ×2 (side by side; stacked compact)  │
│ ── TRADES ──                                                                            │
│ F Item level gained           renderRangeSection + scale line ("%+d")                   │
│ G Asks per day                renderStrip                                               │
│ ── ACTIVITY ──                                                                          │
│ H Drops per day               renderStrip                                               │
│ I By looter class             renderBarSection (class colors)                           │
│ J By quality                  renderBarSection (quality colors)                         │
│ K By slot                     renderBarSection                                          │
│ L By category                 renderBarSection                                          │
└ strip: Kept for 30 days: Oct 11 – Nov 5 · 452 drops in 160 groups      [Reset filters] ┘
```

The layout constants read are the library's, `NS.Charts.K` (`SECTION_GAP`, `HEADER_H`, `CARD_H`, `LIST_MAX`, ...). They are distinct from DropWatcher's `NS.Constants.WINDOW` (`K.STRIP_H`, `K.TAB_H`). Read them, and never write them.

### 5.1 Cards

- Each card is `ctx:card(content, caption)`, filled with `ctx:setCard(card, value, tip, cw - 12, color)` from `InsightsRows.CARD_FILL[key](totals)`.
- An empty value shows as a dash.
- Ask success is green (`dw.upgrade`) at 50% or more and gold (the heading color, `color = nil`) below. This is DPS Race's `shareColor` idea, with the 50% threshold fixed.

### 5.2 Layout pass

`InsightsSections.Layout(view, stats, y, w, pad)` runs these steps:
1. `ctx:ReleaseAll()`;
2. hide the chrome;
3. lay out the cards;
4. walk `SECTIONS`, each of which returns the cursor (for a list panel, the host turns the returned height into a cursor);
5. set the content height and clamp the scroll.

A second pass builds no frame, because everything is pooled.

### 5.3 Empty sections

`InsightsSections.empty(view, key, y, w, pad)` is called by the section in place of the renderer when `#rows == 0`:
1. `ctx:placeHeader(header, y, pad)`;
2. a muted line from the context's pool, using a host factory through `ctx:acquire(ctx:Pool("empty"), factory)`; the factory is `function(ctx, parent) ... end`, built with `ctx.text`;
3. return the cursor under it, minus `NS.Charts.K.SECTION_GAP`.

---

## 6. Tests

| File | New or edited | Cases |
|---|---|---|
| `tests/test_insights_filters.lua` | new | Rows' fallbacks: drop over group `seenBy`; `unknown`; instance from label; `none` difficulty; category defaults to `equipment`. Options counts exclude the dropdown's own filter; a row failing two filters counts nowhere; the current pick is kept at 0; head `choices`. Normalize: fallback in ORDER, `keep` respected, input not written. Ranges by retention (30, 0, 7) from `R.DAYS`. `Since` at local midnight, DST-safe. Difficulty natural order; situation in `C.SITUATIONS` order. `ClosedLabel` |
| `tests/test_insights_stats.lua` | new | Every §1 definition on fixture logs: asks via `askedAt`, `before`, `beforeExpired` and legacy received (no `settledAt`); a post-N1 received with `settledAt` and no `askedAt` is **not** an ask; offers likewise; success nil at 0 asks and excluding received-without-ask; the three outcome rows and segment fracs over the largest total; upgrades including off-spec, with a parity case against `WindowFilterBar`'s `upgradeForMe` on the same drops; by instance, boss (encounter only) and rate (2-visit floor); generous order and ties; gain from `got` vs legacy, and nil gain skipped (`gainNone`); continuous days with zero buckets; week buckets above 62 days; active days in local time; verdict and trade mixes; #13 verdicts; empty input gives all zeros; one pass (each reducer sees each row once) |
| `tests/test_history.lua` | edited | `askedAt` and `offeredAt` stamped once and kept through `Advance`, `received`, `SetDeclined`; a stamp on an expired entry with no advance still sends `HISTORY_CHANGED`; `settle` writes `settledAt` on both outcomes; `got` frozen at trade completion and untouched by a later `Refresh` (the gear re-judge red case: `me` becomes `sidegrade 0`, `got` keeps the pre-equip gain); `got = { at }` when `me` is nil; your own `tradedAway` has `settledAt` and no `got`; `H.WasAsked` / `H.WasOffered` cases; `H.AskState` unchanged behavior through `H.WasAsked` |
| `tests/test_insights_rows.lua` | new | `CARD_FILL` figures and tips (dash, legacy hover); `CardGrid` (4 and 2 columns, stretched last row); `BarPlan` at 1080, 600 and 400 px; each section's row builder (fracs, colors wrapped from triples and tone names, sublabels, top-N caps, slot fallback for `INVTYPE_NON_EQUIP_IGNORE`, empty gives `{}`); `PeriodText` for 30, 0 and a 7-day range |
| `tests/test_window_insights.lua` | new | Three tabs in strip order, both layouts; `SelectTab("insights")` builds the pane once; the shared bar is hidden and the pane top moves up, then comes back on History; **the test-mode and sim strips sit directly under the tabs on Insights and under the bar on History**; **the footer's Sort is hidden on Insights and back on History**; the compact Filters panel closes on switching in; dropdown labels carry counts and picking one redraws; Reset; an unrelated repaint does not recompute (cache), while `HISTORY_CHANGED` does, and so does turning test mode off (no message, identity change); retention change updates the caption; test mode fills every section; a sim trade appears (with `test_sim_e2e`); per-section empty lines (renderer not called); whole-tab empty; Charts absent gives the unavailable line; Widgets absent gives no dropdowns and charts still draw; compact: 2-column cards, wrapped bar |
| `tests/test_harness.lua` | edited | `NS.Charts == LibStub("LibKa0s-Charts-1.0")` (the adopted major is live) |
| `tests/test_surface_parity.lua` | edited | degraded load: `NS.Charts == nil`, `NS.ChartsHost` present, the tab builds with no error |
| `tests/test_window_shell.lua`, `test_compact_chrome.lua`, `test_slash.lua` | edited | the third tab's label, tooltip (function value) and width; `/dw insights` |
| `tests/skin_switch_facts.lua` | edited | declare the Insights pane (cards, a bar, a strip) as a skin-switch surface |
| `tests/test_test_mode.lua`, `test_sim_e2e.lua` | edited | sample and simulation coverage of the stamps, `settledAt` and `got` |
| `tests/test_debug_coverage.lua` | edited if it inventories lines | the `insights:` recompute line and the Charts-absent line |
| `tests/perf.lua` | edited | scenario `insights.compute`: Rows + Options + Filter + Compute over a 5,000-drop log (`H.CEILING`); the bracket notes nothing with capture off |
| `tests/run.lua` | edited | suite order: filters and stats after `test_history_retention`, rows and window after `test_content_tabs` |

**Locale strings.** Each key goes in the file of its first reader (localization-§6):
- the tab label `L["Insights"]` and the slash help `L["Open the Insights tab"]` go in `locales/enUS.lua`, next to `History` and `Open the History tab`;
- the tab tooltip's rows go in `enUS_Tooltips.lua`;
- the strings only the Insights modules read go in a new topic file `locales/enUS_Insights.lua`. It is named for its consumer, opens with `local _, NS = ...` / `local L = NS.L`, and sits contiguous after `enUS_Tooltips.lua` with a `LOAD-BEARING` TOC comment (reads `NS.L` from `enUS.lua`).
- **Flag:** layout-§1 describes a topic split as "optional, once enUS.lua would pass 1000 lines". `enUS.lua` is 798 lines today, plus #13's additions. If enUS.lua plus the about 130 Insights strings stays under 1000, the owner may prefer them in `enUS.lua` (precedent: `enUS_Tooltips.lua` was split as a consumer topic). Decide at DW-N2 (Q8).
- `test_locale` and the kit's `test_prose` cover them, so use "..." and never the ellipsis glyph.

---

## 7. Docs and smoke tests (DW-N4)

- **`docs/ARCHITECTURE.md`:**
  - Overview: twenty majors wired, with a Charts row;
  - Module Map: the Insights files;
  - Message Bus: WindowInsights receives `HISTORY_CHANGED`; History sends it on a stamp;
  - the `ownBar` exception;
  - the Known Limitations summary;
  - the Documentation map, if a topic is added;
  - the 1000–1500 watch list, if `Window.lua` moved within the band.
- **`docs/module-map.md`:** the new files with kind, responsibility and position:
  - ChartsSetup: conventional;
  - InsightsFilters, InsightsStats and InsightsRows: conventional (call-time reads);
  - InsightsSections: conventional;
  - WindowInsights: **load-bearing** (after `Window.lua`, `RegisterTab` at load);
  - `WindowTabs.lua`, if peeled.
- **`docs/data-flow.md`:** an "Insights" section covering `H.Log() → Rows → Normalize/Options → Filter → Period → Compute → Rows builders → Charts ctx`, the cache key, and the log swaps.
- **`docs/schema.md`:** the entry fields `askedAt`, `offeredAt`, `settledAt`, `got`; the session-only `State.insightsFilters`.
- **`docs/scope.md`:** the Insights tab.
- **`docs/slash-dispatch.md`:** `/dw insights`.
- **`docs/performance.md`:** the two brackets and the offline scenario.
- **`docs/known-limitations.md`:**
  - legacy entries: asks and offers inferred from settled trades, success reads high, gains as last judged;
  - keys have no per-boss breakdown;
  - the data covers only the retention window, pruned per group;
  - collectibles before #13 read as equipment;
  - Insights names a group-recorded character that History's Character filter calls unrecorded.
- **`docs/test-cases.md`** is regenerated with `lua tests/run.lua --list`, and the README `[tests]` badge with it (testing-§5).
- **README** Usage: the Insights tab and `/dw insights`, with **a de-AI pass (anti-pattern #77)**.
- **`DEPENDENCIES.md`:** no change. It does not list the majors in use (checked: no Charts mention).
- **`docs/smoke-tests.md`:** a new `## Insights` section, an Index row `INSIGHT-1..7`, `DEGRADED-n`, and Pending sign-off rows:
  - **INSIGHT-1** the tab, its tooltip naming the period, and the strip caption; change retention to 14 and the caption follows;
  - **INSIGHT-2** the dropdowns: each lists only present values with counts; a pick that empties another dropdown falls back to All;
  - **INSIGHT-3** cards and sections on real history; a section with no data shows its line; no Sort in the footer;
  - **INSIGHT-4** ask a member, get the item by trade, equip it: Insights' gain still shows the pre-equip gain, and Asks sent, Items received and success move;
  - **INSIGHT-5** test mode: every section filled, and the amber strip sits under the tabs; turning it off restores the account's history;
  - **INSIGHT-6** `/dw sim` with a trade: Insights shows only the simulation's drops; stopping restores;
  - **INSIGHT-7** compact layout at 400 px (wrapped bar, 2-column cards); a skin switch repaints the charts and the class/quality colors; a resize re-lays out;
  - **DEGRADED-n** LibKa0s-Charts absent: the bar, the strip and the unavailable line.

---

## 8. Ordered breakdown

The run's resume tooling marks an item done when a commit whose subject opens with `<ID>: ` exists. The larger items are therefore split into sub-commits subjected `<ID>.<n>: ` (for example `DW-N2.1: `). The tooling does not count these as done. The item's **last** commit carries the plain `<ID>: ` prefix. The orchestrator adds the sub-rows to `items.tsv`/`RESUME.md` if it wants them tracked. The green gate (`lua tests/run.lua` plus the bounded `luacheck .`, 0/0) runs before every commit, sub-commits included.

### DW-N1: stats and filters (pure, tested)
- **DW-N1.1** History: `askedAt`/`offeredAt`/`settledAt`/`got`, `H.WasAsked`/`H.WasOffered` (published from `wasAsked`), the stamp's `HISTORY_CHANGED`, the header comment (`modules/History.lua`, about +30 lines, 757 to about 790); `tests/test_history.lua`; `docs/schema.md` (fields).
- **DW-N1:** the pure modules.
  - New: `modules/InsightsFilters.lua`, `modules/InsightsStats.lua`, `tests/test_insights_filters.lua`, `tests/test_insights_stats.lua`.
  - Edit: `DropWatcher.toc` (both modules after `modules\HistoryRetention.lua`, each with its TOC comment); `tests/run.lua`; `tests/perf.lua` (`insights.compute`).
- Depends on #13 (DW-C6) for `category` and the collectible verdict keys. Read them from #13's constants, falling back to `equipment`.

### DW-N2: tab shell, filter bar, cards, period caption
- **DW-N2.1** (only if needed) peel the tab registry to `modules/WindowTabs.lua` (§4.1).
- **DW-N2.2** Window plumbing:
  - `modules/Window.lua`: third tab, `ownBar`, function tooltip, per-pane layout, strip re-anchor, `Window.TabOwnsBar`;
  - `modules/WindowFilterBar.lua`: `HONORS.insights`, the Sync guard, the header note;
  - `modules/WindowFooter.lua`: Sort hidden on an `ownBar` tab;
  - `modules/CompactChrome.lua`: `SHORT_TAB`, `CloseFilters` on switching in;
  - `settings/Slash.lua` and `settings/SlashVerbs.lua` (doc comment): `/dw insights`;
  - `locales/enUS.lua` and `enUS_Tooltips.lua`: label, slash help, tooltip rows;
  - tests: `test_window_shell.lua`, `test_compact_chrome.lua`, `test_slash.lua`.

  Until DW-N2 lands, the tab shows its `TAB_PLACEHOLDER`.
- **DW-N2:** the tab body.
  - New: `core/ChartsSetup.lua`, `modules/InsightsRows.lua` (the cards, grid, bar plan and period part), `modules/WindowInsights.lua`, `locales/enUS_Insights.lua` (per Q8), `tests/test_insights_rows.lua` (that part), `tests/test_window_insights.lua` (shell).
  - Edit: `core/State.lua` (`insightsFilters`); `DropWatcher.toc` (ChartsSetup after WidgetsSetup; enUS_Insights after enUS_Tooltips; InsightsRows and WindowInsights after `modules\WindowHistory.lua`, each with its TOC comment, WindowInsights `LOAD-BEARING`); `tests/test_harness.lua`, `test_surface_parity.lua`, `tests/run.lua`.

### DW-N3: chart sections
- **DW-N3.1** sections A, M, N, B, C (bars, stacked bars, legends) and the empty-section path.
- **DW-N3.2** D, E (list panels, side by side or stacked), F (range and scale).
- **DW-N3:** G, H (strips), I..L (mixes), `tests/skin_switch_facts.lua`.
- Each step:
  - New, in DW-N3.1: `modules/InsightsSections.lua` (TOC between InsightsRows and WindowInsights).
  - Edit: `modules/InsightsRows.lua` (the section row builders); `modules/WindowInsights.lua` (calls the layout pass); `locales/enUS_Insights.lua`; `tests/test_insights_rows.lua`; `tests/test_window_insights.lua` (sections, empty lines, compact).

### DW-N4: test-mode and simulator data, smoke tests, docs
- **DW-N4.1** `modules/TestData.lua`: the history samples carry `askedAt`/`offeredAt`/`settledAt`/`got`, a member who traded twice, a mix of #13 categories, one legacy received entry, and at least one `encounter` group with an upgrade so C is not empty (about +25 lines, 823 to about 850). Tests: `tests/test_test_mode.lua`, `tests/test_sim_e2e.lua`.
- **DW-N4:** docs.
  - `docs/smoke-tests.md`, `docs/ARCHITECTURE.md`, `docs/module-map.md`, `docs/data-flow.md`, `docs/scope.md`, `docs/slash-dispatch.md`, `docs/performance.md`, `docs/known-limitations.md`;
  - `docs/test-cases.md` (regenerated);
  - `README.md` (badge and Usage, humanized).

### Line cap and CCN 15

| File | Estimate | Note |
|---|---|---|
| InsightsFilters | about 330 | |
| InsightsStats | about 420 | reducers and finalizers as one-concern functions |
| InsightsRows | about 450 | one builder per section; `CARD_FILL` as a function table |
| InsightsSections | about 380 | one layout function per section |
| WindowInsights | about 420 | bar, scroll, strip, refresh, bus |
| ChartsSetup | about 50 | |
| enUS_Insights | about 130 | |
| History | 757 → about 790 | |
| TestData | 823 → about 850 | |
| Window | 1025 → about 1060 | on notice (1000–1500); peel per §4.1 if it would pass about 1060 |

No file reaches the 1500-line cap (layout-§1). If `WindowInsights` passes about 600 lines, the bar moves to `modules/InsightsBar.lua`. Every function is planned at CCN 10 or less:
- **Options:** the `missedSlot` loop over a facet table, not seven `if`s.
- **Outcome-to-segment mapping:** lookup tables.
- **Difficulty order:** a rank function with a pattern table.

The `complexity` suite gates zero functions above 15.

---

## 9. Standard conformance (Ka0s WoW Addon Standard)

**None of this needs a deviation row as designed.** The items below are conformance notes, and two of them need confirmation.

1. **library-stack-§7 (adoption) and anti-pattern #47:** the tab is built on the vendored LibKa0s-Charts-1.0 with no private renderer. It is wired through one setup file (`core/ChartsSetup.lua`) that resolves `LibStub(major, true)`. The card grid, bar plan and layout pass are host layout, which the Charts contract assigns to the host ("What stayed in the addons: ... the layout pass").
2. **Degradation, for confirmation:**
   - Without the library, `NS.Charts` is nil, the setup file says so once (a debug line), and the tab shows its filters, its strip and an "unavailable" line.
   - There is no drawing stub: anti-pattern #73 and DPS Race's precedent. This is the same shape as DropWatcher's own `NS.MakeDropdown` answering nil.
   - `docs/ARCHITECTURE.md` says "each setup file holds a descriptor and a degradation stub". This is the nil-answer variant already used for Widgets.
   - **If the owner reads library-stack-§7's "falls back to its stub" as requiring a no-op `Charts` table, stop and decide** whether that is a deviation row or a standard clarification.
3. **layout-§1:** no file goes over 1500 lines (§8). `Window.lua` is already in the 1000–1500 band and grows within it: the watch list is updated, or the tab registry is peeled.
4. **localization-§6:** Insights-only strings go in a consumer-named topic file with a `LOAD-BEARING` TOC line. Shared keys stay with their first reader. **For confirmation (Q8):** whether a topic split below the 1000-line threshold is wanted.
5. **testing-§5:** the case inventory and badge are regenerated. **testing-§15:** luacheck runs through the bounded runner.
6. **performance-§2/§9:** the brackets cost nothing with capture off, and an offline scenario is added.
7. **preview-mode:** test mode shows sample data through `H.Log()`.
8. **documentation-§3/§5:** ARCHITECTURE and the topic docs are updated in the same change. **anti-pattern #77:** the README gets a de-AI pass.
9. **savedvariables:** the History entry fields are additive and optional, and legacy readers handle their absence, so there is no migration step (§1.2 flag).
10. **toc-file:** every new TOC line carries its comment, and `WindowInsights` and `enUS_Insights` are marked `LOAD-BEARING`.
11. **Not a standard rule, recorded as a design choice:** the Insights tab hides the shared filter bar (and the footer's Sort) and draws its own. DropWatcher's "grayed, never reflowed" bar convention (`WindowFilterBar.lua` header, from Loot History) gets a documented exception for a tab with `ownBar`.

---

## 10. Decisions taken, for the owner to confirm (Q)

- **Q1 (taken):** ask, offer and settle stamps (`askedAt`, `offeredAt`, `settledAt`) are added in DW-N1. For legacy data (no `settledAt`), a received item counts as an ask and a traded-away drop counts as an offer, so the real data reads 9 asks and 89% success, with a hover that says the legacy rate reads high. The alternative, with no History change, would get asks over time wrong and miss asks that later succeeded.
- **Q2 (taken):** `got` freezes the verdict at trade completion. For legacy received items, the gain shows the last-judged `me`, marked "as last judged" (all 8 real items read 0 or -7 because of the post-equip re-judge). The alternative is to hide legacy gains.
- **Q3 (rule kept; source to confirm):** old drops with no `category` default to `equipment`. The run plan's Decisions do not record this rule, so confirm it and record it there.
  - A possible refinement, not adopted: treat `equipLoc == INVTYPE_NON_EQUIP_IGNORE` as `tierToken`. That would correctly reclassify the 12 real tier tokens (they also fall outside `WC.SlotLabel`, which section K handles).
- **Q4 (proposed):** two extra cards, Offers sent and Traded away, for an even 4 × 2 grid. Drop them for the owner's exact six (then 4 + 2, with the last row stretched).
- **Q5 (proposed):** a `/dw insights` slash verb, in parity with `/dw history`.
- **Q6 (taken):** all seven dropdowns are single-select (the DPS Race #12 model), and their state is session-only. History's Character stays multi-select.
- **Q7 (taken):** sections H, M and N are added ("worth adding given real data"). Top instances is defined as upgrades per visit (2-visit floor) so it does not repeat section B; the issue's literal "top instances for upgrades" is otherwise B's ranking.
- **Q8 (new):** Insights-only strings go in `locales/enUS_Insights.lua` (a consumer topic), or in `enUS.lua` while that stays under 1000 lines.

---

## Critic notes

These are corrections made against the code at `655d19d` and against issue #12:

1. **Wrong site for `got`.** The design pointed at History.lua:671 as "the `received` branch". The trade application is `settle` (History.lua:667), which writes `outcome` directly and does not call `H.Advance`. §0 and §1.2 now say so.
2. **The legacy test was unsound for post-N1 data.**
   - `got == nil` as the legacy marker would misread a post-N1 received item with no ask, or with a nil `me`, as a legacy ask.
   - The `offered` legacy test ("really no `offeredAt`") would count every post-N1 direct trade-away as an offer forever.
   - Fix: a `settledAt` stamp on every settle, with legacy defined as `settledAt == nil`, and `got = { at }` when `me` is nil.
3. **A stale cache was missed.** `H.OnAskState` sends `HISTORY_CHANGED` only when `H.Advance` moves the outcome, so a stamp with no advance would leave Insights stale. It now sends on a stamp too.
4. **Duplicated rule.** The asked rule duplicated History's file-local `wasAsked`. It is published as `H.WasAsked`/`H.WasOffered` and reused. A parity test against `WindowFilterBar`'s file-local `upgradeForMe` was added.
5. **Charts contract details were wrong or missing:**
   - the bar, stacked, range and strip renderers *hide the header* on empty rows, so the host must branch before calling them;
   - `renderListPanel` returns a height, not a cursor;
   - `onReskin` receives `ctx`;
   - stacked-segment fracs are the caller's division;
   - labels are cut at 16 glyphs and lists capped at `K.LIST_MAX` 10;
   - `SECTION_GAP` is `NS.Charts.K`'s, not DropWatcher's `K`.
6. **Color APIs return the wrong shape for chart rows.** `NS.QualityColor` and `Compat.ClassColor` return `r, g, b` triples, and `WC.TRADE_TONE` returns tone names; rows now resolve them through `NS.Constants.TONE`. `WC.SlotLabel` answers nil for `INVTYPE_NON_EQUIP_IGNORE`, so a fallback was added.
7. **Unordered source.** `WF.SITUATION_LABEL` is a hash with no order. The order now comes from `NS.Constants.SITUATIONS`, and the ranges from `NS.HistoryRetention.DAYS`.
8. **Missing Window surfaces under `ownBar`:**
   - the test-mode and sim strips are anchored to `f.filterHost` and would mis-sit, so they are re-anchored;
   - the footer's Sort dropdown (`WF.AnchorSort`/`WF.Refresh`) would show grayed on Insights, so it is hidden;
   - `CompactChrome.paintFilters` reads `FB.HONORS[tab]` whenever the button's own shown flag is set, so the guard list is extended;
   - `CloseFilters` runs on switching in;
   - tests and smoke steps were added for each.
9. **The cache key could miss a log swap.** Test mode's log table is persistent while `.groups` is swapped, and test-mode off sends no `HISTORY_CHANGED`. The key now includes the `groups` identity and the mode flags.
10. **Widgets degradation.** `NS.MakeDropdown` answers nil without Widgets; the bar's degraded path and a test were added.
11. **Standard points:**
    - library-stack-§7 says the setup file "says once that the library is missing", so ChartsSetup emits one debug line; anti-pattern #73 is cited;
    - `Window.lua` is already in the layout-§1 1000–1500 band, so a peel trigger and a watch-list update were added;
    - localization-§6 placement: shared keys go with their first reader (`enUS.lua`, `enUS_Tooltips.lua`), the topic file gets a `LOAD-BEARING` TOC line, and the below-threshold split is flagged as Q8;
    - TOC comments for every new line.
12. **Items too large for one commit.** DW-N1, N2, N3 and N4 are split into `<ID>.<n>:` sub-commits, which the resume tooling's `<ID>: ` check does not count, with the plain ID on the last commit.
13. **Owner decisions:** every issue candidate is still built (the owner's "build every candidate"). Q3's "owner" attribution is not in the run plan's Decisions, so it is marked to confirm and record. A pre-flight was added to confirm the Charts minor after the DW-T1 re-vendor and the field name DW-C3 writes for `category`.
14. **Smaller fixes:**
    - `DEPENDENCIES.md` does not list majors, so it needs no change;
    - `State.insightsFilters` is declared in `core/State.lua`;
    - `FR.Button` with the declared `reset` icon is named for Reset filters;
    - the empty-log line handles retention 0;
    - F skips items with no `ilvlDelta` and counts them;
    - the TestData samples include an encounter-group upgrade so section C is exercised.
