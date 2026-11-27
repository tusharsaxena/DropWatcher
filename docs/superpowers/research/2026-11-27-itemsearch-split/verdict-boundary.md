# Verdict engine boundary map (2026-11-27, DropWatcher @ 7c36f40)

Research for the Item Search split (design: `../../specs/2026-11-27-itemsearch-split-design.md`).
Read-only map of what answers "my verdict for item link X", fixed before any code moves. Line numbers
are at `7c36f40`; "~" marks an approximate one.

## Entry points

- Item Search consumes the engine through `modules/ItemSearchVerdict.lua` `judgeOf(link)` (788-798:
  `NS.ItemFacts.Get(link)` then `NS.LootFeed.JudgeMe(facts, false)`) and `gearSignature()` (772-776,
  `IVD.GearSignature` 837), plus `NS.MSG.GEAR_CHANGED` in `modules/ItemSearchVerdictPanel.lua:425`.
- The engine's public entry is `LF.JudgeMe(facts, forced)` (`modules/LootFeed.lua:321`) →
  `judgeMe(rec, LF.Config())` (281-287): `NS.Collectibles.Verdict(facts, forced)` first (non-nil ends
  it), else `NS.Evaluate.Evaluate(facts, myCandidate(cfg), evalOpts(cfg))` (via `evaluate`, 255).
- `myCandidate` (264-271): `NS.Gear.Candidate()` + `undesired` prefs, spec key by `NS.ClassData.SpecKey`.
- `evalOpts` (250-253): `{sidegradeBand, compareOwned, scorer = NS.Scoring.Scorer(), verdictMode = LF.VERDICT_MODE}`;
  `LF.VERDICT_MODE` (102) is `scoreFirst` on Forever, `ilvlFirst` on Retail.
- Group-side judging calls the same kernel with another player's candidate: `modules/Inspect.lua:523`
  (`NS.Evaluate.Evaluate`), and the roster / candidates / roll cells read `NS.ClassData`,
  `NS.OffSpec`, `NS.TierTokens`.

Result: `me = {verdict, equip, reasons = {{key, detail}}, ilvlDelta, scoreDelta, baseline, led, offSpec, ...}`;
verdicts upgrade, sidegrade, downgrade, cantUse, doesntWant, unknown, newCollect and the collectible
words; `scorePending` is a reason key (`Evaluate.lua:425`).

## Files, by kind

| File | Kind | Reads / notes |
|---|---|---|
| `modules/Evaluate.lua` (580) | pure kernel | `NS.Constants` (SLOT, ITEM_CLASS, ARMOR_SUBCLASS, UNIVERSAL_EQUIPLOC, ARMOR_TYPED_EQUIPLOC, TRACK_TIER, QUALITY.HEIRLOOM), `NS.ClassData`; calls `TierTokens.Fold` (536), `OffSpec.Attach` (546); exports `Evaluate`, `Equippability`, `ItemVerdict` (556), `TrackDelta`; pcall at 576 |
| `modules/OffSpec.lua` (~170) | pure | Retail-only, gated by `C.FEATURE.offSpec` (38) at load; `Initialized/Who/WornGear/Attach/Of/EvalFor` |
| `modules/TierTokens.lua` (~210) | pure | vocab from `NS.L`, `NS.TextParse` (pure); `C.TIER_TOKENS`; `TT.SlotOf(facts, readTooltip)` takes the reader as a callback |
| `core/ClassData.lua` (361), `core/ClassDataForever.lua` (107) | pure data | `Build`, `Install`, `SpecKey`, `DualWieldFor`, `TitanGripFor`, `SPECS`, `STAT`; `Compat.ClientKey()` at file load picks the list |
| `core/TextParse.lua` | pure | token parsers |
| `modules/Collectibles.lua` (~335) | pure + reads + DW | pure `Verdict` (181), `CategoryOf` (97), `IsCollectible` (114), `judge`/`kindVerdict` (157); reads `Read` (252)/`probeOf` (195); **feed refresh 290-335 is DW-only** |
| `modules/Scoring.lua` (~390) | pure + reads | pure `ParseImport`, `ImportInto`, `WeightsScore`, `HasWeights`, `Resolve`, `WeightsFor`, `WeightsScorer`; Pawn reads; **`NS.Setting` at 351, 361, 383** (`comparison.scorer`, `comparison.weights`); `ScoreFor` reaches `NS.ItemFacts` (381) |
| `core/ItemRead.lua` (~170) | pure + reads | pure `ItemString`, `LinkDetail`, `BetterLink`, `IdentityKey`; reads `EffectiveItemLevel`, `QualityOf`, `ItemLevelAt`, `QualityAt` |
| `modules/ItemFacts.lua` (~395) | reads + cache | `Get` (277), `Read` (207), `Request` (332), `RereadCollections` (386), `TrackTier` (110); events TRANSMOG_COLLECTION_UPDATED, SPELL_TEXT_UPDATE (361-363); **transmog handler calls `NS.Collectibles.Changed()`** |
| `modules/Gear.lua` (~445) | player state | `Snapshot` (350), `Candidate` (358), `OffSpecGear` (384), `Qualities` (395, **feed gate input, DW-only**), `Refresh` (298), `Schedule` (314), `OnEvent` (329); sends `GEAR_CHANGED` (308); `Restrictions.InCombat` (330, DW); throttle 0.5 s; events PLAYER_EQUIPMENT_CHANGED, BAG_UPDATE_DELAYED, PLAYER_SPECIALIZATION_CHANGED (Retail), TRAIT_CONFIG_UPDATED / CHARACTER_POINTS_CHANGED / PLAYER_LEVEL_UP (Forever), PLAYER_REGEN_ENABLED (405-415) |
| `modules/FeedFilter.lua` | DW | not in the verdict; `AverageIlvl` pure, gate-only |
| `modules/LootFeed.lua` | DW + seam | `LF.Config` (171-182) mixes feed/trade config with the verdict's; `judgeMe` 281 |

DW-only, stays: `NS.Roster`, `Inspect` (its request/queue; the kernel call moves to the library
member), `Situations`, `QualityGate`, `Pending`, `TradeRules`, `Restrictions.InCombat`, `LootFeed`
records/`Drops`/`Refresh`, `GroupRoster`/`GroupPlace`, History, `Gear.Qualities`, Collectibles' feed
refresh, `rec.forced`/whitelist handling.

## Settings the verdict reads

`comparison.sidegradeBand`, `comparison.compareOwned`, `comparison.undesired` (`[specKey] -> {SubClassKey=true}`),
`comparison.heirloomProtect`, `comparison.scorer` (auto/pawn/weights/none), `comparison.weights`
(`[specKey] -> {STAT=n}`). Rows: `settings/SchemaRows.lua:443-453`; editors: weights in
`settings/PageEditors.lua`, undesired in `settings/ListEditors.lua`; defaults `defaults/Profile.lua:159`.
`VERDICT_MODE` is a client constant, host-provided.

## Client reads the engine makes (today's Compat members)

- `core/Compat.lua`: IsSecret, ClientKey, InventoryItemLevel, InventoryItemLink, GetItemUpgradeInfo,
  PlayerSpecID, BagSlotCount, BagItemLink, IsItemBindToAccount, IsItemBindToAccountUntilEquip,
  ItemEquipLoc, CanRequestItemLoad, GetItemInfo, GetItemStats, GetItemSpecs, GetItemUniqueness,
  PlayerHasTransmog, ItemClassRestriction, ItemPrimaryStats, GetDetailedItemLevel; Pawn: PawnIsReady,
  PawnItemData, PawnUpgradeInfo, PawnScaleForSpec, PawnVisibleScale, PawnCustomScale, PawnClassScales,
  PawnItemValue.
- `core/CompatClient.lua`: PlayerTalentTree, PlayerRole. `core/CompatWorld.lua`: UnitClass, UnitLevel.
  `core/CompatItem.lua`: BagItemLevelQuality. `core/CompatCollect.lua`: MountCollected, PetCollected,
  ToyCollected, RecipeKnown, ProfessionSkillLines, TierTokenSlot, ItemOpens, ItemUseText,
  CanRequestSpellLoad, RequestSpellLoad.
- Support: `NS.Item` (`ItemIDFromLink`, `LoadItem`; LibKa0s Item), `NS.Constants` subset, `NS.L`,
  `NS.Debug`, `NS.Perf`, `NS.State`, stand-down, `NS.FEATURE_EVENTS`, `NS.MSG`.
- Item Search's own reads outside the engine: ItemInfoByID, AuctionPrice, AuctionatorLoaded, CoinText,
  HookItemTooltips, and `core/CompatSearch.lua`'s.

## Tangles cut before the move (task A2)

1. `LF.Config` / `judgeMe`: carve a verdict-only config (the six `comparison.*` + verdict mode).
2. `Scoring` reads `NS.Setting` directly: inject `scorer`/`weights`.
3. `Collectibles`: split pure verdict + read from the feed refresh (290-335).
4. `ItemFacts` transmog handler → a change callback, not `Collectibles.Changed()`.
5. `Gear`: `Qualities` and the `InCombat` defer become host-side.
6. `ClassData` / `OffSpec`: client from the instance, not file load.

## Tests covering it

Kernel: test_evaluate, test_offspec, test_tier_token, test_class_data, test_scoring, test_collectibles.
State: test_gear. Reads: test_item_facts, test_item_read, test_compat, test_compat_client,
test_compat_collect, test_compat_loot. Integration: test_collect_feed, test_item_lists,
test_collect_surfaces, test_collect_cells, test_offspec_ask, test_offspec_cells, test_offspec_offer.
Item Search seams: test_item_search_verdict, test_item_search_panel (362-367 stub IF.Get,
LF.JudgeMe, G.Snapshot).
