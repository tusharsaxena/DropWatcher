# 03 — DropWatcher loot pipeline: the code map

Research note for the WoW Forever port (branch `feat/2026-11-13-forever-port`, 2026-11-13).
It maps the seams. It does not propose a design.

Read-only on all code. Paths are repo-relative unless they start with `/`.
Evidence tags: **MEASURED** (seen in source or docs, cited), **REPORTED** (third party),
**INFERRED** (my reading; check before relying on it).

The five things a designer will add, and where this note covers each:

| Want | Sections |
|---|---|
| (a) live and final roll data per drop, both clients | 3, 4, 6, 7 |
| (b) a pending "awaiting master looter" state with an "Ask the master looter" send | 8, 9 |
| (c) a Forever trade model (BoP soulbound, BoE only) | 10 |
| (d) score-first verdicts on Forever | 11 |
| (e) an annotation on Blizzard's roll popup | 12 |

---

## 1. The pipeline at a glance

- Three live sources feed one module, `modules/LootFeed.lua`. **MEASURED** (`modules/LootFeed.lua:22-28`).
  - `chat`: CHAT_MSG_LOOT, through `modules/LootParser.lua`'s sink (`LootFeed.lua:1002-1007`, sink wired at `:1034`).
  - `encounter`: ENCOUNTER_LOOT_RECEIVED (`LootFeed.lua:1010-1016`).
  - `history`: LOOT_HISTORY_UPDATE_DROP, through `NS.Compat.LootHistoryDrop` (`LootFeed.lua:1019-1030`).
- Two more doors: `manual` (`LF.Add`, `/dw add`, `:737-743`) and `restore` (`LF.Restore`, after a `/reload`, `:722-728`). Test mode uses `LF.AddTest` (`:751-758`). **MEASURED**.
- The feed's events are rows in `NS.FEATURE_EVENTS`, with a handler on `NS.addon` (`LootFeed.lua:1041-1051`). Core dispatches them (`core/DropWatcher.lua:20-113`, `NS.DeliverEvent` at `:88`). **MEASURED**.
- The feed never touches the client directly. Every client read goes through `NS.Compat` (`core/Compat*.lua`). **MEASURED** (`docs/data-flow.md` "The feed"; `core/SimSetup.lua:1-12`).
- No code today reads the loot method, the master looter, START_LOOT_ROLL, GetLootRollItemInfo, rollInfos or GroupLootFrame. A repo-wide grep finds none (only `LOOT_CLOSED` in `modules/TradeTimer.lua:381`). **MEASURED**. Rolls and master loot are greenfield.
- No code today asks which client it runs on. `IsForever`/`WOW_PROJECT_ID` appear nowhere in `core/`, `modules/` or `settings/`. **MEASURED**. The helpers exist in the vendored library: `LibKa0s-Compat-1.0` `IsForever`, `IsRetail`, `ClientKey`, `ForClient` (`libs/LibKa0s/Compat.lua:106-170`). **MEASURED**. `core/Compat.lua:15` already resolves that library as `CompatLib`, but wires only the secret guards and the spec readers (`core/Compat.lua:17-19`). **MEASURED**.

---

## 2. Receive, merge, update: where a drop is born and changed

All in `modules/LootFeed.lua` unless noted. **MEASURED**.

1. `LF.Receive(r)` (`:709-718`) wraps `receive(r)` (`:688-702`) in pcall and the `feed.add` perf bucket.
2. `receive` refuses `stoodDown`, then a missing item link or a missing looter **table** (`notItem`, `:690-691`). A drop with no looter cannot enter the feed today.
3. It prunes the dedupe window (`prune`, `:638-644`, `LF.DEDUPE_WINDOW = 120`, `:93`).
4. Unless `manual`, it looks for a merge: `FeedRecords.FindRecent` matches the same `itemID`, the same looter (`SameLooter`: GUID, else short name) and a source not yet seen on that drop (`modules/FeedRecords.lua:28-46`).
5. A hit goes to `merge(rec, r)` (`:656-679`). It adds the source, may learn the looter's GUID, keeps the better link, and sends `DropUpdated(id, "source")` (or re-runs gates, or `LF.Refresh`).
6. A miss makes `newRecord(s, r)` (`:622-635`) and calls `start(rec)` (`:598-613`): situation gate, `ItemFacts.Request` (may set `rec.state = "loading"`), then `judge(rec, facts)` (`:581-596`): filters, `judgeMe`, quality gate, `judgeLooter`, then `add(rec)` (`:548-565`).
7. `add` puts the drop in its group (`FeedRecords.Materialize`, `FeedRecords.lua:136-156`), sets `rec.state = "added"`, trims to `MAX_DROPS = 200`, and sends `DropAdded(id)` (`:563`).

`rec.state` takes four values today: `new` (`:634`), `loading` (`:609`), `hidden` (`modules/FeedCounts.lua:31`, with `rec.hidden = why`), `added` (`:552`). **MEASURED**. There is no `pending` or `rolling` state.

Updates. Each re-judge sends `DropUpdated(id, cause)` (`LootFeed.lua:56-63`). **MEASURED**.

| Cause | Sender |
|---|---|
| `source` | `merge` (`:677`) or `LF.Refresh(rec, "source")` (`:675`) |
| `inspect` | `LF.OnInspectDone` (`:854-867`) |
| `gear` | `LF.OnGearChanged` (`:931-944`) |
| `score` | the shared score retry (`:438-455`) |
| `trade` | `LF.SweepTrade` (`:478-490`), 30 s ticker (`LF.TRADE_SWEEP`, `:98`) |
| `bag` | `LF.ApplyBagItem` / `ReadBagItems` (`:902-929`) |
| `collection` | `modules/Collectibles.lua` through `LF.Refresh` |

`rejudge(rec, facts, cause)` (`:870-879`) is the one re-judge path: `judgeMe`, `judgeLooter(rec, cfg, false)`, `notePending`, then `DropUpdated`. **MEASURED**.

A new cause (say `roll`) needs no receiver change. The window repaints on any `DropUpdated` (`modules/Window.lua:1034`). History refreshes on any (`modules/History.lua:867`). The toast and auto-ask re-consider on any (`modules/Toast.lua:781`, `modules/AutoAsk.lua:415`). **MEASURED**.

---

## 3. The feed record shape

Header doc: `modules/LootFeed.lua:6-20`. Built by `newRecord` (`:622-635`) and stamped by `NS.CharFilter.Stamp` (`seenBy`, `seenByClass`). **MEASURED**.

| Field | Meaning | Set at |
|---|---|---|
| `id` | per-load sequence (`s.seq`) | `:623`, `:631` |
| `feed` | `"live"` or `"test"` | `:630` |
| `link`, `itemID`, `qty`, `kind` | the item; kind `loot`/`bonus`/`pushed` | `:630-631` |
| `bonusRoll` | `kind == "bonus"` | `:631` |
| `looter` | `{ name, guid, classFile, isSelf }` | `:632`, resolved by `resolveLooter` `:183-189` |
| `isMine` | `looter.isSelf == true` | `:632` |
| `at` | `GetTime()` at receipt (restore back-dates it) | `:624`, `:632` |
| `situation` | `Situations` key | `:632` |
| `encounterID` | when the source named one | `:633` |
| `sources`, `source` | `{ [source] = 1 }`, first source | `:633`, merge `:659` |
| `group` | `{ key, label, kind, encounterID, mapID, instance, difficulty }` | `:634`, `groupSpec` `:236` |
| `groupKey` | the feed group's key after `add` | `:552` |
| `state` | `new` / `loading` / `hidden` / `added` | see §2 |
| `sim`, `test`, `force` | origin flags | `:630`, `:634` |
| `facts` | ItemFacts cache table (read only) | `judge` `:582` |
| `forced` | Always-watch pass | `:588-591` |
| `me`, `them` | `NS.Evaluate` answers | `judgeMe` `:279-289`, `judgeLooter` `:395-416` |
| `inspect` | `{ status, reason, at, specID, gear }` | `inspectState` `:309-314` |
| `trade` | `NS.TradeRules` estimate, folded | `estimate` `:316-330` |
| `quality` | `{ mode, threshold, reason }` | `qualityGate` `:301` |
| `candidates` | own drops only, `[guid] = { guid, name, classFile, status, eval }` | `judgeCandidates` `:377-389` |
| `scoreTries` | score retry count | `notePending` |

Test records have extra fields (`testAsk`, `testInspect`, `testGear`, `testOffGear`, `testLeft`). They are built by an explicit field list in `FeedRecords.TestRecord` (`modules/FeedRecords.lua:179-195`). **MEASURED**. A new field on a test drop must be added to that list.

There is no `rolls`, `lootListID`, `rollState`, `winner` or `pending` field. `encounterID` is kept, but `lootListID` from the `history` source is used only for the seen-key and is then dropped (`LootFeed.lua:1022-1030`). **MEASURED**.

---

## 4. The history entry shape

Header doc: `modules/History.lua:6-14`, with field notes to `:60`. **MEASURED**.

```
history = { retentionDays, v = 1, groups = {
  { key, label, kind, situation, at, instance, difficulty, seenBy, seenByClass,
    roster = { { name, realm, class, me }, ... }, drops = {
      { itemLink, itemID, looter, class, isMine, ilvl, equipLoc, quality, seenBy, seenByClass,
        category, tokenSlot, tokenUsers,
        me = { verdict, ilvlDelta, scoreDelta, offSpec?, collect?, category?, count?, limit?, reasonKey? },
        them = { ... } | nil,
        trade = { state, reasonKey, basis, args }, outcome, before, beforeExpired, at, sim?,
        askedAt?, offeredAt?, settledAt?, got? } } } } }
```

- `H.Snapshot(rec, now)` (`History.lua:197-214`) copies an **explicit field list** from the feed record. Unknown feed fields are not kept. **MEASURED**.
- `H.Refresh(e, rec)` (`:288-294`) re-takes `me`, `them`, `trade` (`takeSnaps`, `:274-279`) and link, ilvl, quality (`takeItem`, `:264-272`). It answers `changed` only when a snapshot differs (`sameSnap`, `:238-252`, one level deep plus `args`/`offSpec`). **MEASURED**. A new kept field needs its own take/compare step, or `HistoryChanged` will not fire for it.
- Fields are additive and `v` stays 1 (`:36`, `:51`). **MEASURED**. So a new optional `rolls` field fits the stated convention without a migration. **INFERRED** from that stated rule.
- `at` is `time()` (epoch), never `GetTime()` (`:16`). **MEASURED**. A roll's time would need the same treatment to survive a reload. **INFERRED**.
- Recording happens only on `DropAdded` of a live drop (`H.OnDropAdded`, `:665-675`). Test drops are never recorded. Sim drops go to the sim's log (`H.LogFor`, `:547-551`). **MEASURED**.
- The entry index is per load (`index[dropId]`, `H.Adopt`/`EntryOf` `:581-593`). **MEASURED**.
- Outcomes: `seen`, `asked`, `offered`, `expired`, `declined`, `received`, `tradedAway`, ranked by `H.RANK` (`:118-119`); sent asks map through `SENT_OUTCOME = { ask, offer, announce }` (`:686-695`). **MEASURED**.
- Size: 50 drops a group, 5,000 in all (`H.MAX_DROPS`, `H.CEILING`, `:115-116`). **MEASURED**. A per-entry roll list (up to 40 raiders) would multiply SavedVariables size. **INFERRED**; a designer should bound it.

The History tab reads entries through `WindowHistory.AsDrop(e, id, group)` (`modules/WindowHistory.lua:172-181`). It is another **explicit field list**. **MEASURED**.

---

## 5. The bus and the event surface

- Catalog: `core/Bus.lua:21-32`, ten messages, one named sender each. With LibKa0s-Bus it is a strict catalog, so a mistyped key raises (`core/Bus.lua:52`; `docs/ARCHITECTURE.md` "Message Bus"). **MEASURED**.

| Message | Sender | Receivers relevant here |
|---|---|---|
| `DROP_ADDED` | LootFeed | History, Toast, AutoAsk, TradeTimer, Window |
| `DROP_UPDATED` | LootFeed | History, Toast, AutoAsk, Window |
| `ASK_STATE_CHANGED` | Asks | History, Toast, AutoAsk, Window |
| `HISTORY_CHANGED` | History | WindowHistory, WindowInsights, AutoAsk |
| `INSPECT_DONE`, `GEAR_CHANGED`, `TRADE_TIMER_TICK` | Inspect, Gear, TradeTimer | LootFeed (`:1057-1066`), Window |

Receiver lines: `modules/History.lua:866-868`, `modules/Toast.lua:780-781`, `modules/AutoAsk.lua:414-415`, `modules/TradeTimer.lua:399`, `modules/Window.lua:1033-1034`. **MEASURED**.

- `tests/test_disabled.lua:11-22` pins every game event the addon registers, as sorted literals. Lines `:24-40` pin every bus registration, one per receiver. **MEASURED**. A new event (START_LOOT_ROLL, CANCEL_LOOT_ROLL, LOOT_ROLLS_COMPLETE, PARTY_LOOT_METHOD_CHANGED, ...) or a new receiver must be added there.
- A new message would be an 11th catalog row and a pinned literal. The docs claim "All ten messages are sent today" (`docs/ARCHITECTURE.md` Message Bus). **MEASURED**.

---

## 6. The `history` source today, and what it drops

`LF.OnLootHistoryDrop(encounterID, lootListID)` (`modules/LootFeed.lua:1019-1030`). **MEASURED**:

1. Calls `NS.Compat.LootHistoryDrop(encounterID, lootListID)`.
2. Nil → refused `noWinner` (counted, `modules/FeedCounts.lua:9-10`).
3. Key `encounterID .. ":" .. lootListID` in the session set `store().history` (`LootFeed.lua:125`). Already seen → refused `seen`.
4. Marks it seen, resolves the winner, and sends one receipt with `source = "history"`, `qty = 1`, `kind = "loot"`.

`Compat.LootHistoryDrop` (`core/Compat.lua:409-435`). **MEASURED**:

- Calls `C_LootHistory.GetSortedInfoForDrop(encounterID, lootListID)`.
- Keeps only `itemHyperlink` and `winner` (`playerName`, `playerGUID`, `playerClass`, `isSelf`) through `lootWinner` (`:410-417`), each secret-guarded.
- Answers nil while there is no winner: rolls open, all passed, no API, or a secret answer (`:419-424`).
- Ignores `rollInfos`, `currentLeader`, `isTied`, `allPassed`, `playerRollState`, `startTime`, `duration`.

So every LOOT_HISTORY_UPDATE_DROP that fires while a roll is open is refused `noWinner` today. **MEASURED** (the code path). That is the first seam for live rolls. A roll reader that keeps `rollInfos` would sit beside this function in `core/Compat.lua`.

The Forever API has the same table. **MEASURED** in the Forever 1.60.1 (70888) generated docs at
`/tmp/claude-1000/-mnt-d-Profile-Users-Tushar-Documents-GIT-DropWatcher/8e7a7246-e9bd-4614-aaea-6144aa02c981/scratchpad/wus-forever/Interface/AddOns/Blizzard_APIDocumentationGenerated/LootHistoryDocumentation.lua`:

- `C_LootHistory.GetSortedInfoForDrop(encounterID, lootListKey)` (`:59-71`). The second argument is named `lootListKey` there; DW calls it `lootListID`.
- Events `LOOT_HISTORY_UPDATE_DROP(encounterID, lootListKey)` (`:106-113`), `LOOT_HISTORY_UPDATE_ENCOUNTER`, `LOOT_HISTORY_ONE_HUNDRED_ROLL`, `LOOT_HISTORY_CLEAR_HISTORY`, `LOOT_HISTORY_GO_TO_ENCOUNTER` (`:79-123`).
- `EncounterLootDropInfo`: `lootListKey`, `itemHyperlink`, `playerRollState`, `currentLeader`, `isTied`, `winner`, `allPassed`, `rollInfos`, `startTime`, `duration` (`:147-160`).
- `EncounterLootDropRollInfo`: `playerName`, `playerGUID`, `playerClass`, `isSelf`, `state`, `isWinner`, `roll` (nilable) (`:164-174`).
- `EncounterLootDropRollState`: NeedMainSpec 0, NeedOffSpec 1, Transmog 2, Greed 3, NoRoll 4, Pass 5 (`:131-143`).

Other Forever facts near this seam. **MEASURED** (same docs folder):

- `C_PartyInfo.GetLootMethod()` answers `method`, `masterLootPartyID`, `masterLooterRaidID` (`PartyInfoDocumentation.lua:287-294`). `Enum.LootMethod` has Freeforall 0, Roundrobin 1, Masterlooter 2, Group 3, Needbeforegreed 4, Personal 5 (`LootConstantsDocumentation.lua:6-18`). `GetLootMethodStyle` exists (`PartyInfoDocumentation.lua:298`), with `LootMethodStyles` Mainline 0 / Vanilla 1 (`LootConstantsDocumentation.lua:22-30`).
- `MasterLootQualityThreshold = 4` (`LootConstants_MainlineDocumentation.lua:43`).
- Loot events include START_LOOT_ROLL, CANCEL_LOOT_ROLL, CANCEL_ALL_LOOT_ROLLS, LOOT_ROLLS_COMPLETE, LOOT_ITEM_ROLL_WON, MAIN_SPEC_NEED_ROLL, OPEN_MASTER_LOOT_LIST, UPDATE_MASTER_LOOT_LIST, ENCOUNTER_LOOT_RECEIVED (`LootDocumentation.lua:93-426`).
- Roll chat lines are GlobalStrings with a `|HlootHistory:%d|h` link, e.g. `LOOT_ROLL_NEED`, `LOOT_ROLL_ROLLED_NEED`, `LOOT_ROLL_WON`, `LOOT_ROLL_ALL_PASSED`, plus `LOOT_MASTER_LOOTER`, `MASTER_LOOTER`. Seen in Ketho/BlizzardInterfaceResources `forever` branch, `Resources/GlobalStrings/enUS.lua` lines 13884-13940, 14230 (https://github.com/Ketho/BlizzardInterfaceResources/blob/forever/Resources/GlobalStrings/enUS.lua). These arrive on CHAT_MSG_LOOT. `LootParser` matches only `LOOT_ITEM*` shapes and ignores the rest (`modules/LootParser.lua:69-85`, `:226-228` "no match ... ignored"). **MEASURED** for the parser; **INFERRED** that roll lines reach it as CHAT_MSG_LOOT on Forever.

Retail shape. DW already reads `winner.playerName/playerGUID/playerClass/isSelf` and `itemHyperlink` on Retail 12.1.5 (`core/Compat.lua:410-433`). **MEASURED**. That `rollInfos` and the roll states are the same on Retail is **INFERRED**; no live clone was read for this note.

The test mock: `M.lootHistory["encounterID:lootListID"]` is the whole answer of `GetSortedInfoForDrop` (`tests/wow_mock.lua:921-927`). **MEASURED**. It can carry `rollInfos` with no mock change. Cases: `tests/test_compat.lua:830-856`, `tests/test_feed.lua:226-313`, `:945`, `tests/test_feed_counts.lua`.

---

## 7. Where a `rolls` field would have to flow

Each hop below copies or composes fields explicitly. A new field reaches the next hop only if that hop's list names it. **MEASURED** for each cited list.

| Hop | Seam | File:line |
|---|---|---|
| client read | a new roll reader beside `LootHistoryDrop`; it must be added before `core/SimSetup.lua` loads so the sim seam wraps it | `core/Compat.lua:409-435`; `core/SimSetup.lua:6-12` |
| event | a `FEATURE_EVENTS` row and an `NS.addon` handler, like the six in `EVENTS` | `modules/LootFeed.lua:1041-1051` |
| feed record | `newRecord` sets fields from the receipt; `merge` decides what a second source adds | `LootFeed.lua:622-635`, `:656-679` |
| feed update | `DropUpdated(id, cause)`; the window repaints on any cause | `LootFeed.lua:141-143`; `Window.lua:1034` |
| Drops table cell | `WG.COLUMNS` (data), `BUILDERS`, `paintRow`, `SIMPLE` text cells; each column gets a `window.columns.<key>` schema row by loop | `modules/WindowGroup.lua:114-158`, `:639`, `:894`, `:906-931`; `settings/SchemaRows.lua:450-455`; default `defaults/Profile.lua:152` |
| cell text | pure composers in `NS.WindowCells` (the `cell = { text, glyph, tone, tip }` shape) | `modules/WindowCells.lua:19-21` |
| detail card | pure `DetailCells` composers (`Chips`, `ForYou`, `ForLooter`, `TradeBox`, `Actions`), painted by `DCard.Paint` | `modules/DetailCells.lua:252`, `:467`, `:531`, `:571`, `:701`; `modules/DetailCard.lua:582-606` |
| compact card | `CompactCards` four-line card built from the full cells | `modules/CompactCards.lua:15-30`, `:295`, `:341` |
| toast | `Toast.Compose` four rows (CCN 14) | `modules/Toast.lua:231` |
| history write | `H.Snapshot` field list; `H.Refresh`/`takeSnaps` compare | `modules/History.lua:197-214`, `:264-294` |
| history read | `WindowHistory.AsDrop` field list; `HistoryCard.Model` | `modules/WindowHistory.lua:172-181`; `modules/HistoryCard.lua:208` |
| insights | `InsightsFilters.rowOf` keeps `e` whole; `InsightsStats.REDUCERS` / `FINALIZERS` lists | `modules/InsightsFilters.lua:112-122`; `modules/InsightsStats.lua:240`, `:400` |
| restore after `/reload` | `FeedRestore.Receipt` field list; the restored drop is judged again as new | `modules/FeedRestore.lua:99-108`, `:121-134` |
| test mode | `FeedRecords.TestRecord` field list; `TestData` builds sample rows and the sample history log | `modules/FeedRecords.lua:179-195`; `modules/TestData.lua:746`, `:908`; `modules/TestMode.lua:173-225` |
| sim | see §13 | |
| diagnostics | per-drop dump | `modules/Diagnostics.lua:307` |

Notes on restore. **MEASURED** unless tagged:

- `FR.Receipt` gives `source = "restore"`, `force = true` and the History group (`FeedRestore.lua:99-108`). Rolls kept on the History entry would reach the feed only if `Receipt` copies them.
- The seen-set `store().history` is session memory (`LootFeed.lua:125`). It is empty after a reload. If the client re-fires LOOT_HISTORY_UPDATE_DROP for older drops after a reload, they pass `seen` again. Their dedupe against the restored drop depends on `FindRecent`: a restored drop has `sources = { restore = 1 }` and an `at` back-dated to its real time, so a re-fire more than 120 s later is a new drop. **INFERRED** from `FeedRecords.lua:39-46` and `LootFeed.lua:638-644`. Whether C_LootHistory survives a reload is an open probe.

---

## 8. A pending / rolling drop: what today's code assumes

These are the constraints a `pending` (rolling, or awaiting master looter) record would meet. **MEASURED** unless tagged.

- **A looter is required.** `receive` refuses a receipt whose `looter` is not a table (`LootFeed.lua:691`). Many readers dereference `rec.looter.name/guid` with no guard (e.g. `LF.OnInspectDone` `:858`, `judgeLooter` `:404`, `WindowCells.looterName` `:182`, `NS.AskTargetOf` `core/DropWatcher.lua:318-322`).
- **Dedupe is by item and looter.** `FindRecent` needs the same looter (`FeedRecords.lua:39-46`). A drop first seen with no winner and later won by X would not match X's chat or encounter receipt. Only the `encounterID:lootListID` key ties the two, and the feed does not keep it on the record today (§3).
- **History records at DropAdded, once.** `H.OnDropAdded` returns early if `index[id]` exists (`History.lua:667`). A pending drop shown in Drops would be recorded as `seen` at once, with whatever looter it had. A later winner reaches the entry only through `H.Refresh`, which does not re-take `looter` or `class` (`:264-294`).
- **Every consumer treats an added drop as looted.** The toast (`Toast.Qualifies` `Toast.lua:176-185`: not mine, an upgrade, trade `likely`/`yes`), auto-ask (`AutoAsk.blocker` `AutoAsk.lua:146-155`: needs `NS.AskTargetOf`), the trade timer (own drops, `TradeTimer.lua:18-27`), the glow (`Glow.lua:63`), Post my tradeables (`WindowFilterBar.IsTradeableMine` `:356-360`), the window's auto-open and new-count (`Window.lua:995-1005`).
- **Trade estimate needs a looter's eval.** `estimate` reads `rec.them` and `rec.inspect` (`LootFeed.lua:316-330`); no looter means `noInspect` (`TradeRules.lua:102-106`).
- **The ask target is the looter.** `NS.AskTargetOf` answers the looter's name or GUID, nil for your own drop (`core/DropWatcher.lua:318-322`). `NS.PressAsk` asks that target (`:343-366`). A master-loot drop's target would be the master looter, not a looter.
- **Hidden vs shown.** The gates (`hide`, `LootFeed.lua:569-572`) and `FeedCounts` (`modules/FeedCounts.lua:30-43`) handle "not shown". A pending drop that should show is a new axis, not a hidden reason. **INFERRED**.
- **Merge on a learned looter.** `merge` already re-runs `judgeLooter(rec, cfg, true)` when the looter's GUID is learned (`LootFeed.lua:661-662`, `:673`). That is the nearest existing "the looter became known later" path. **MEASURED**.

Who is the master looter. Nothing reads it today (§1). On Forever, `C_PartyInfo.GetLootMethod()` gives a party or raid index (§6). It would go through a new `NS.Compat` member in `core/CompatWorld.lua` (the group readers live there, `:25-171`), so `SimWorld` can answer it. **MEASURED** for where group reads live; the member is new.

---

## 9. Sends: the one-ask registry, the queue, the templates

Split. `modules/Messaging.lua` is the pure core; `modules/Asks.lua` is the edge with the one book. **MEASURED** (`Asks.lua:6-10`; `Messaging.lua:4-18`).

- Kinds `C.MESSAGE_KINDS = { "ask", "offer", "announce" }` (`core/Constants.lua:561`). Templates `C.MESSAGE_TEMPLATES = { "ask", "transmog", "askOffSpec", "offer", "announce" }` (`:567`). Tokens `C.MESSAGE_TOKENS` (`:569`). **MEASURED**.
- Defaults: `defaults/Profile.lua:123-139` (`messages.templates.*`, `oneAsk`, `editFirst`, `announceChannel`, `autoAsk`). **MEASURED**.
- One-ask key: `M.Key(kind, target, dropID)` (`Messaging.lua:134-136`). The guard is per (kind, target, drop). **MEASURED**.
- `A.Request(kind, target, dropID, opts)` (`Asks.lua:340-353`): stood down → refused; collectible → refused; recipient (`:168-174`; `whisperRecipient` `:159-165` refuses `notInGroup`, `self`, `offline`); template `A.TemplateFor` (`:125-128`); tokens `context` (`:218-228`); then `M.Request` → send / queue / refuse (`act`, `:323-335`). **MEASURED**.
- Route: an `announce` goes to a group channel; anything else is a WHISPER to `a.target` (`route`, `:253-256`). Send is `pcall(ChatSender(), text, chatType, nil, to)` (`:259-267`). **MEASURED**.
- Queue and flush: queued under `NS.Restrictions.CanSendChat()` (`coreOpts`, `:316-320`); flushed on restriction lift, ENCOUNTER_END, CHALLENGE_MODE_COMPLETED (`C.MESSAGE_FLUSH_TRIGGERS`, `Constants.lua:573`), one per 1.5 s (`Asks.lua:421-455`). Roster change cancels asks to a member who left (`A.OnRosterChanged`, `:490-506`). **MEASURED**.
- Confirmation line and `ASK_STATE_CHANGED(dropID, state, kind, target, reason)` (`Asks.lua:240-243`, `:275-282`). **MEASURED**.

Two precedents for a new wording. **MEASURED**:

1. **A template under an existing kind.** `transmog` and `askOffSpec` are sent as kind `ask`, picked by `M.AskTemplate` (`Messaging.lua:65-74`, CCN 13). They share the ask's one-ask key (drop + looter). `tests/test_offspec_ask.lua:77-78` asserts "no new kind: it is sent as an ask".
2. **A new kind.** Only `ask`, `offer`, `announce` exist. A kind is the key's first part, so a new kind gets its own one-ask slot per drop and target.

What an `askML` send touches (either way). **MEASURED** for each site:

| Site | Why |
|---|---|
| `core/Constants.lua:561`, `:567` | the kind and/or template list (order = Settings › Messages order) |
| `defaults/Profile.lua:124-130` | the default template text |
| `settings/SchemaRows.lua:413-424` | one `text(...)` row per template |
| `settings/Editors.lua:221-227`, `:235-238`, `:290-310` | `TEMPLATE_LABEL`, `KIND_NAME`, the preview sample picker per template |
| `modules/Asks.lua:125-128`, `:168-174`, `:204-216`, `:253-256` | template pick, recipient (the ML, not the looter), token context (`theirEval` assumes ask → `rec.them`), route |
| `modules/Messaging.lua:31-36`, `:65-74` | the `KIND`/`TEMPLATE` sets; `AskTemplate` |
| `modules/History.lua:686-695` | `SENT_OUTCOME`: a sent kind not listed there stamps nothing |
| `core/DropWatcher.lua:306-366` | `ASK_REFUSAL` words, `NS.AskTargetOf`, `NS.PressAsk` (one press handler per kind: `PressAsk` `:343`, `PressOffer` `:456`, `PressAnnounce` `:487`) |
| `modules/WindowCells.lua:833-958` | `noAskReason`, `ASK_LOOK`, `askTip`, `WC.Ask` (the Actions cell and its tooltip; `askTip` names "Whispers <looter>") |
| `modules/DetailCells.lua:606-619`, `:701-709` | `askAction` ("Ask <looter>"), `DC.Actions` |
| `modules/DetailCard.lua:703-744` | the Edit message box title and preview per kind |
| `modules/AutoAsk.lua:146-155`, `:220-248` | auto-ask fires `Asks.Request("ask", looter, id)` |
| `modules/Diagnostics.lua:357` | lists every template |
| `locales/enUS*.lua` | every new `L[...]` key; `test_locale` checks both directions (`docs/testing.md:640-650`) |
| tests | `test_messaging.lua:45` (`#C.MESSAGE_KINDS == 3`), `test_offspec_ask.lua:77-78`, `test_transmog.lua:96`, `test_schema_rows.lua:676` (template defaults pinned), `test_asks`, `test_auto_ask`, `test_detail_card`, `test_window_group` |

The guarded sim sender prints `[sim] WHISPER <target>: <text>` for any kind (`core/SimSetup.lua:46-56`). **MEASURED**.

The standard has no rule for addon-sent chat; DW's register row holds it to design spec §9, one send per click (`docs/ARCHITECTURE.md` Documented deviations, row 2). **MEASURED**. A new whisper kind sits under that row. Whether it needs the row reworded is a standards call (CLAUDE.md "Standards compliance").

---

## 10. The trade estimate, and where a Forever branch belongs

The estimator is pure: `modules/TradeRules.lua` (`:1-25`). **MEASURED**.

- Inputs `facts = { ilvl, bindType, warbound, bonusRoll }`, `looterEval`, `ctx = { situation, rules, now, droppedAt, inspectAge, inspectReason, collectible }` (`:10-13`). Built in `LootFeed.estimate` (`LootFeed.lua:316-330`).
- Order in `estimate` (`TradeRules.lua:129-142`, CCN 12): `bindCheck` first (`:83-90`: warbound → `no warbound`; bonus roll → `no bonusRoll`; BoE → `yes boe`), then `rule.tradeable == false` → `no legacy`, then the window (`expiryCheck`, `:93-100`), then `ilvlRule == "none"` → `likely groupLoot`, then collectible, then `looterCheck` (`:109-127`).
- Rules are data: `C.TRADE_RULES = { personal, group, legacy }` (`core/Constants.lua:548-552`); names `C.TRADE_RULE_NAMES` (`:545`); default `personal` (`:546`); window `C.TRADE_WINDOW = 14400` (`:542`). Per-situation defaults `defaults/Profile.lua:113-118` (all `personal` but `pvp = "legacy"`). Owner overrides are `trade.rules.<situation>` rows (`LootFeed.tradeRules`, `:151-155`).
- BoE set `C.TRADE_BOE_BIND = { OnEquip, OnUse }` (`Constants.lua:536`). `bindType` comes from `C_Item.GetItemInfo` (`core/Compat.lua:516-530`, into `ItemFacts.lua:215`).

What this means for Forever's model (BoP soulbound, BoE free). **MEASURED** code behavior; mapping is **INFERRED**:

- BoE already wins first: `bindCheck` answers `yes boe` before any rule, even under `legacy`.
- Under the `legacy` rule, a non-BoE drop is `no legacy` ("Loot from this content can't be traded." `WindowCells.lua:347`). That is the nearest existing answer to "BoP is soulbound". Its words and short reason (`Legacy loot`, `:463`) are Retail's.
- `personal` and `group` both assume a 4-hour window. `group` answers `likely groupLoot` ("its winner may trade it for four hours", `:348`).
- A per-client branch can live in three places: the rule data (`C.TRADE_RULES` / the defaults per situation), the order in `TradeRules.estimate`, or the `ctx` that `LootFeed.estimate` builds. The module is pure and takes no client flag today.

Your own drop's fold. `LF.FoldTimer` (`LootFeed.lua:343-359`, CCN 14) overlays the trade timer's read unless `est.basis == "bind"`. **MEASURED**. On Forever, the trade timer would see a BoP item with no trade-time line and mark it `expired` with `hadWindow` false (`TradeTimer.lua:303-324`). FoldTimer then answers `no upgradeForYou` ("the game took it as an upgrade for you"). **INFERRED** from that code; the words would be wrong on Forever. An answer with `basis = "bind"` passes through FoldTimer untouched (`:345`). **MEASURED**.

Readers of the estimate. **MEASURED**:

- Words: `TRADE_REASON` (`WindowCells.lua:344-356`), `TRADE_ROWS` (`:408-436`), `TRADE_SHORT` (`:461-466`, also read by a column-width test). A new `reasonKey` needs an entry in each, else it prints the raw key (`:449-451`, `:460-462`, `:478`).
- Ask gating: `noAskReason` refuses when `trade.state == "no"` (`WindowCells.lua:836-838`).
- Offer panel: `OfferPanel.lua:303-311`, `:361`.
- Tradeables: `WindowFilterBar.IsTradeableMine` (`:356-360`), used by `NS.PostTradeables` (`core/DropWatcher.lua:516-546`).
- Toast and auto-ask: `TRADE_WORD[t]` must be `likely` or `yes` (`Toast.lua:182-183`).
- Glow: `Glow.lua:63`. Detail card: `DetailCells.lua:571-588`, `:681`.
- History: `tradeSnap` (`History.lua:167-178`); `no expired` → outcome `expired` (`:288-294`).
- Insights: `InsightsStats.lua:235`.

Situations. `C.SITUATIONS` has ten keys, Retail-shaped (`mythicPlus`, `delve`, `followerDungeon`, `raidLFR`, ...) (`core/Constants.lua:461-465`). Each has a trade-rule default. Which ones Forever can reach is outside this note.

---

## 11. Verdicts, and where score-first would go

The kernel is pure: `modules/Evaluate.lua` (`:1-37`). **MEASURED**.

- `E.Evaluate(facts, candidate, opts)` (`:522-526`) → `run` (`:472-500`) → `compare` fills `ilvlDelta`, `trackDelta`, `scoreDelta` (`:432-456`) → `verdictOf` (`:419-429`) → `decide(out, band)` (`:410-417`).
- `decide` is item-level-led. With no score, the ilvl sign decides. With a score, the verdict takes the sign only when ilvl and score agree; any disagreement is a `sidegrade` with reason `scoreDisagrees`. **MEASURED**. "Score-first, item level a tiebreak" is a different rule in exactly this function. **INFERRED**.
- Options reach it as `opts = { sidegradeBand, compareOwned, heirloomProtect, scorer }` (`:15-16`), built in `LootFeed.evalOpts(cfg)` (`LootFeed.lua:246-248`) from `LF.Config()` (`:167-179`). A client flag or verdict mode would ride on `opts`. **MEASURED** for the path.
- Other readers of the ilvl-only rule: `E.ItemVerdict(delta, band)` (`:504-509`, the tooltip's per-item marks), `TradeRules.looterCheck` reads `ilvlDelta`, not the verdict (`TradeRules.lua:18-20`, `:109-127`), `Toast.Qualifies` tests the ilvl gain (`gainPasses`), auto-ask `minGain` is in item levels (`defaults/Profile.lua:136-138`). **MEASURED**. A score-first verdict leaves these ilvl-based. **INFERRED**.
- Words: `VERDICT_MEANS.upgrade = "a higher item level (and score, when scored)"`, `sidegrade = "within the sidegrade band, or level and score disagree"` (`WindowCells.lua:55-62`). **MEASURED**.

Scoring. `modules/Scoring.lua` (`:1-25`): `auto | pawn | weights | none`. Pawn's scale is chosen by spec (`specScale`, `:177`; `Compat.PawnScaleForSpec`, `core/Compat.lua:757`). Weights are per spec: `comparison.weights[specID]` (`:13-14`). **MEASURED**. The Forever client profile has no spec globals (`tests/_kit/README.md:29`, `mock_client.lua` "the spec and talent globals ... gone"). **MEASURED** for the kit. So both scorers are keyed by something Forever may not answer. **INFERRED**; the spec port is another note's subject.

A tier token skips the scorer (`Evaluate.lua:452-453`). A pending score retries five times, one second apart (`LootFeed.lua:96-97`, `:418-455`). **MEASURED**.

---

## 12. Decorating a Blizzard frame: what precedent exists

- DW decorates no Blizzard frame today. The one client hook is `hooksecurefunc("NotifyInspect", fn)` in `Compat.HookNotifyInspect` (`core/Compat.lua:396-405`). **MEASURED**.
- `HookScript` is used only on DW's own frames (`modules/Window.lua:267-269`, `modules/Sim.lua:326-329`). **MEASURED**.
- No `TooltipDataProcessor`, `OnTooltipSetItem` or GameTooltip post-hook exists (grep). **MEASURED**.
- The nearest "add lines to a game tooltip" helper is `RowTooltip.AddKindRows(tip, link)` (`modules/RowTooltip.lua:149-157`): `tip:AddLine` with the skin's `gtip.value` color. **MEASURED**.
- Taint notes: the window and toast are plain frames; the only secure-adjacent calls are wrapped and click-driven (`docs/ARCHITECTURE.md` Taint Notes). **MEASURED**. A hook on Blizzard's roll frame is a new taint surface to document there.

Blizzard's roll popup on Forever. **MEASURED** in the widened sparse clone,
`/tmp/claude-1000/-mnt-d-Profile-Users-Tushar-Documents-GIT-DropWatcher/8e7a7246-e9bd-4614-aaea-6144aa02c981/scratchpad/wus-forever/Interface/AddOns/Blizzard_UIPanels_Game/Mainline/GroupLootFrame.lua`:

- `NUM_GROUP_LOOT_FRAMES = 4` (`:1`). Frames carry `frame.rollID` (`:166`).
- `GroupLootFrame_SetupItemDisplay(self)` reads `GetLootRollItemInfo(self.rollID)`: texture, name, count, quality, bindOnPickUp, canNeed, canGreed, canDisenchant, reasons, deSkillRequired, canTransmog (`:312-317`).
- `GroupLootFrame_OnShow` (`:371`), `GroupLootFrame_OnHide` (`:383`), `GroupLootFrame_OnEvent` (`:404-418`), `GroupLootContainer_AddRoll` (`:156`).
- The file sits under a `Mainline/` folder in the Forever tree. The frame XML is `GroupLootFrame.xml` beside it.
- The link for the item is not in the frame code read; `GetLootRollItemLink(rollID)` is the usual source. **INFERRED**; not checked in this clone.

Kit gate: `test_client_globals` fails an unguarded call to a global a client lacks (`tests/_kit/README.md:32`). `GroupLootContainer_*` and `GroupLootFrame_*` names appear in the Forever global set (`tests/_kit/client_globals_forever.lua:29`). **MEASURED**.

---

## 13. Sim mode and test mode: how drops are faked

Sim. **MEASURED** (`modules/SimEvents.lua:1-48`, `docs/data-flow.md` "The simulator"):

- The sim never writes a verdict, estimate or inspect. It answers `NS.Compat` calls through the seam and fires real events (`docs/data-flow.md` simulator block, last paragraph).
- The seam wraps every `NS.Compat` member defined before `core/SimSetup.lua` loads (`core/SimSetup.lua:6-12`, `:87`). `tests/test_sim_e2e.lua` asserts `Unwrapped()` is empty. A new Compat member is wrapped for free if it is added in a `core/Compat*.lua` file above SimSetup.
- Providers live in `modules/SimWorld.lua` as `P.<CompatName>(fallback, ...)` and are registered by loop (`:284-511`). A roll reader or a loot-method reader would need a provider here, or the live client answers during a sim.
- Loot today is chat only. `deliverLine` writes a `LOOT_ITEM*` line and fires `CHAT_MSG_LOOT` (`SimEvents.lua:401-413`). Your own drop is first put in the sim bags with a trade window (`NS.SimWorld.AddBagItem`, `:408`; `E.TRADE_WINDOW = 4h`, `:55`).
- `E.Plan(n, members, drops, rnd, who, ownRealm, extras)` is pure and seeded (`:226`). `burst` delivers a plan (`:428-445`). `E.Loot` and `E.Drop` are the drivers (`:449-472`).
- The timeline is pure: steps `pull`, `lockdownOn`, `kill`, `loot`, `lockdownOff`, `runStart`, `runEnd` (`modules/SimScenario.lua:86-110`). Verbs: `settings/SimVerbs.lua:26-117` (`pull kill loot drop lockdown trade`).
- The loot report counts the feed's receipts since a mark (`modules/SimReport.lua:50-76`) and summarizes where each went (`:122`).
- What faking rolls needs, by the same pattern. **INFERRED**: a provider answering the roll table for an invented `encounterID:lootListID`; `Sim:Fire("LOOT_HISTORY_UPDATE_DROP", ...)` (and START_LOOT_ROLL or roll chat lines, if the design reads them) once per roll update; a seeded roll plan in the style of `E.Plan`; a timeline step and/or verb; and a `SimReport` line. For master loot, a `C_PartyInfo.GetLootMethod`-shaped provider in `SimWorld`.

Test mode. **MEASURED**:

- `TM.Populate` adds sample drops with `LF.AddTest(spec)` (`modules/TestMode.lua:223`), built by `TestData.Placeholders` (`modules/TestData.lua:746`). Every sample's verdicts, trade and inspect are given, never judged (`LootFeed.lua:745-750`).
- `FeedRecords.TestRecord` copies a fixed field list (`FeedRecords.lua:179-195`).
- The sample History log is `TestData.History` into `TM.HistoryLog()` (`TestMode.lua:173`, `:225`; `TestData.lua:908`).
- Test mode and the sim refuse each other (`docs/data-flow.md` simulator block).

---

## 14. The tests that cover each module

From `tests/` names and greps. **MEASURED**.

| Module | Suites |
|---|---|
| `LootFeed` | `test_feed` (sources, dedupe, groups, `LOOT_HISTORY_UPDATE_DROP` at `:226-313`), `test_own_drops`, `test_collect_feed`, `test_debug_coverage` |
| `LootParser` | `test_loot_parser` |
| `FeedRecords` | `test_feed`, `test_item_read` |
| `FeedRestore`, `Session` | `test_feed_restore` |
| `FeedFilter` | `test_feed` |
| `FeedCounts` | `test_feed_counts` |
| `History` | `test_history` |
| `HistoryRetention` | `test_history_retention` |
| `HistoryCard` | `test_history_card` |
| `DetailCard`, `DetailCells` | `test_detail_card` |
| `WindowCells`, `WindowGroup`, `WindowRows` | `test_window_group`, `test_drops_layout`, `test_table_font`, `test_window` |
| `CompactCards` | `test_compact_cards`, `test_compact_group`, `test_compact_history` |
| `RowTooltip` | `test_row_tooltip` |
| `TradeRules` | `test_trade_rules` |
| `TradeTimer`, `TradeHelper` | `test_trade_timer`, `test_trade_helper` |
| `ItemFacts` | `test_item_facts` |
| `Evaluate`, `Scoring`, `OffSpec` | `test_evaluate`, `test_scoring`, `test_offspec*` |
| `Asks`, `Messaging`, `AutoAsk` | `test_asks`, `test_messaging`, `test_auto_ask`, `test_offspec_ask`, `test_transmog` |
| `Restrictions`, `Situations` | `test_restrictions`, `test_situations` |
| `Toast` | `test_toast`, `test_toast_stack` |
| Sim | `test_sim_core`, `test_sim_e2e`, `test_sim_events`, `test_sim_panel`, `test_sim_pool`, `test_sim_report`, `test_sim_scenario` |
| `TestMode`, `TestData` | `test_test_mode` |
| Insights | `test_insights_filters`, `test_insights_rows`, `test_insights_sections`, `test_insights_stats`, `test_window_insights` |
| Bus, events, constants, Compat | `test_disabled` (pinned events and receivers), `test_constants`, `test_compat` (`LootHistoryDrop` at `:830-856`), `test_schema_rows` (pinned defaults) |
| locale | `test_locale` (every `L[...]` key in both directions) |
| client | kit `test_client_globals` (missing-global gate, Forever set only on a 16xxx `## Interface`) |

Harness facts. **MEASURED**:

- `KA0S_KIT_CLIENT=forever lua tests/run.lua` runs the whole suite under the Forever client profile (`tests/_kit/README.md:29`).
- `tests/wow_mock.lua` mocks `C_LootHistory` from `M.lootHistory` (`:921-927`). There is no mock for `C_PartyInfo.GetLootMethod`, `GetLootRollItemInfo`, START_LOOT_ROLL or GroupLootFrame (grep).
- The toc is Retail only today: `## Interface: 120105` (`DropWatcher.toc:1`).

---

## 15. Conventions a change must keep

**MEASURED** unless tagged.

- **Pure kernels, thin edges.** Parsers, rules, verdicts, cells and records are pure and take plain tables (e.g. `TradeRules.lua:4-6`, `Evaluate.lua:4-7`, `Messaging.lua:4-8`, `WindowCells.lua:7-11`, `FeedRecords.lua:8-9`, `History.lua:96-102`). The edge reads state, the client (through `NS.Compat` only) and settings.
- **Client calls only in `core/Compat*.lua`**, secret-guarded, plain values out (`core/Compat.lua:409-435` is the model).
- **Events** are `NS.FEATURE_EVENTS` rows so stand-down unregisters them (`core/DropWatcher.lua:4-20`). Bus receivers are tracked targets (`LootFeed.lua:1053-1080`).
- **Never throws**: kernels pcall their public entry (`TradeRules.lua:146-151`, `Evaluate.lua:522-526`).
- **Settings** go through the schema seam (`NS.Setting`, `NS.SchemaRuntime.Set`); a new path needs a `defaults/Profile.lua` default and a `settings/SchemaRows.lua` row (`docs/schema.md` "The write seam").
- **History is additive**, `v` stays 1 (`History.lua:36`, `:51`).
- **Complexity**: the gate is zero functions above CCN 15 (`docs/testing.md:705`). Near the limit now (lizard `-C 11`, run 2026-11-13 through `ka0s-bounded`): `judgeLooter` 14 (`LootFeed.lua:395`), `LF.FoldTimer` 14 (`:343`), `Toast.Compose` 14 (`Toast.lua:231`), `memberRow` 14 (`DetailCells.lua:493`), `M.AskTemplate` 13 (`Messaging.lua:65`), `trackRow` 13, `scoreRow` 13 (`DetailCells.lua:336`, `:402`), TradeRules `estimate` 12 (`TradeRules.lua:129`), Evaluate `usable` 12 (`Evaluate.lua:168`). A new branch in any of these needs a helper split. lizard counts every `and`/`or` (`docs/automated-tests/RESULTS.md`, closing paragraph).
- **File size**: hard cap 1500 lines (layout-§1; `docs/testing.md:12`); the cap census lives in `docs/ARCHITECTURE.md` "Files over the 1500-line cap". Files in the 1000-1500 band, with the owner's recorded split trigger (`docs/automated-tests/RESULTS.md`, "Files by layout-§1 band"):
  - `modules/LootFeed.lua` 1080: split the re-judge path out if it passes 1100.
  - `modules/WindowCells.lua` 1177: move the Trade composers out before 1250.
  - `modules/WindowGroup.lua` 1157: split the action buttons out before 1250.
  - `modules/Window.lua` 1064: move the tab strip out before 1100.
  - `tests/wow_mock.lua` 1017 now (1000 at that run): "the next API family goes into a file of its own", as `tests/wow_mock_collect.lua` did.
  - Big suites on notice: `test_compat` 1053, `test_window_group` 1065, `test_test_mode` 1158, `test_window_shell` 1074, `test_settings_pages` 1062.
  - Module headers repeat the softer aim: "the plan keeps under 1000 lines" (`FeedRecords.lua:9`, `FeedFilter.lua:8-9`).
  - So a roll reader, roll cells, ML state and the askML action cannot all land in `LootFeed`, `WindowCells` or `WindowGroup` as they stand. **INFERRED** from the triggers.
- **Deviations** go in `docs/ARCHITECTURE.md` "Documented deviations" (CLAUDE.md). The parser (`LootParser`) is already a registered library-stack-§7 deviation; a roll-line parser would extend it. **MEASURED** for the row; the extension is **INFERRED**.
- **Locale**: every `L[...]` string has an enUS entry, checked both ways (`docs/testing.md:640-650`).

---

## 16. Open probes (in-game only)

Each is a line to type in the client, and what to look for.

1. Does Forever fire LOOT_HISTORY_UPDATE_DROP while a Need/Greed roll is open, and does `rollInfos` fill live?
   `/run local f=CreateFrame("Frame") f:RegisterEvent("LOOT_HISTORY_UPDATE_DROP") f:SetScript("OnEvent",function(_,_,e,k) local i=C_LootHistory.GetSortedInfoForDrop(e,k) print(e,k,i and #i.rollInfos, i and i.winner and i.winner.playerName, i and i.allPassed) end)`
   Look for: several prints per item while rolling, `#rollInfos` > 0 before a winner, then a winner name.
2. What one roll entry holds mid-roll (is `roll` nil until the roll ends; is `state` NoRoll until chosen)?
   `/dump C_LootHistory.GetSortedInfoForDrop(<encounterID>, <lootListKey>)` during an open roll, then again after.
3. What `encounterID` is for trash loot on Forever (0, nil, or a pseudo id)?
   `/dump C_LootHistory.GetAllEncounterInfos()` after a trash roll.
4. Does C_LootHistory survive `/reload`, and does LOOT_HISTORY_UPDATE_DROP re-fire after it?
   Roll on an item, `/reload`, then `/dump C_LootHistory.GetSortedDropsForEncounter(<encounterID>)` and watch probe 1's frame (re-registered) for fires.
5. The loot method and master looter, and whether the event that marks a change exists.
   `/dump C_PartyInfo.GetLootMethod()` under group loot, then under master loot; `/dump C_PartyInfo.GetLootMethodStyle()`. Register PARTY_LOOT_METHOD_CHANGED (in the Forever docs, `PartyInfoDocumentation.lua:797`) and print on fire.
6. Under master loot, what reaches the addon for an Epic drop before it is given out: any CHAT_MSG_LOOT line, ENCOUNTER_LOOT_RECEIVED, or LOOT_HISTORY entry? And for a below-threshold drop?
   `/etrace` filtered to LOOT and CHAT_MSG_LOOT while the boss is looted by the master looter and then given away.
7. Does ENCOUNTER_LOOT_RECEIVED fire on Forever at all, and with which payload?
   `/etrace` on a boss kill under group loot; compare its `playerName` with the roll winner.
8. The roll chat lines on Forever, and whether a `|HlootHistory:%d|h` link id equals `lootListKey`.
   `/run ChatFrame1:AddMessage(LOOT_ROLL_NEED)` for the format; then copy one real line from chat during a roll.
9. The roll popup: does `GroupLootFrame1..4` exist, does `frame.rollID` match `GetLootRollItemLink(rollID)`, and can it be hooked out of combat and in combat?
   `/run hooksecurefunc("GroupLootFrame_OnShow",function(f) print(f:GetName(), f.rollID, GetLootRollItemLink(f.rollID)) end)` then wait for a roll.
10. A BoP group-loot item on Forever: no trade-time tooltip line, and `bindType` 1.
    `/dump C_Item.GetItemInfo(<link>)` (14th return) and hover the bag item; look for no "You may trade this item..." line.
11. A BoE drop on Forever: `bindType` 2 and freely tradeable.
    Same `/dump` on a BoE; open a trade with it.
12. Does Pawn on Forever value items with no spec, and what does `comparison.scorer` `auto` pick?
    `/dw diagnostics` and read the Scoring section; `/dump PawnIsReady and PawnIsReady()`.
