# Proposed changes

## HLD

**Theme A: a drop recorded after #13 always says what kind it is (F-001, F-002).** Today, a missing
`category` on a History entry stands for two different things: the drop is a legacy entry, or the
drop was forced onto the feed by the whitelist and has no kind. Record the second case explicitly.
Insights then keeps its legacy fallback for genuinely old entries and files forced items under a
kind of their own. The docs should also describe the fallback rule as it actually behaves.

- *Alternative rejected:* add a seventh entry `other` to `C.CATEGORIES`. That would also put an
  `other` item-kind switch on the settings page and under `feed.categories`, and the feed's filter
  would have to treat it as a watchable kind. It changes the schema and the migration for a
  stats-only problem.
- *Alternative rejected:* key the Insights fallback on `me.collect == true and me.category == nil`. That
  works for new entries without changing the snapshot. However, it relies on a side effect of the
  verdict shape, and anything else that reads History would need to rediscover it.

**Theme B: complexity (F-003).** Split `IF.Period` into two parts: resolving the period's start, and
scanning the rows.

No upstream change set. Nothing in this review targets `libs/` or `tests/_kit/`.

## LLD

### C-01 (F-001): record the forced kind, and read it in Insights

- `modules/History.lua` `H.Snapshot` (line 189). When the drop's `me` verdict has `collect == true` and
  the facts have no category, store `category = "watched"`. This is a History-only value, not a `C.CATEGORIES` key.
  ```lua
  category = type(facts.category) == "string" and facts.category
      or (type(rec.me) == "table" and rec.me.collect == true and "watched") or nil,
  ```
- `modules/InsightsFilters.lua` `IF.CategoryOf` already returns any stored string as it is, so no change is needed there.
  `options.category` orders by `C.CATEGORIES` positions, so `"watched"` needs to sort last. The label
  function at `:317` needs `"watched"` mapped to `L["Watched item"]` (an existing string, `CollectCells.DetailRows`).
- `modules/InsightsStats.lua` `slotKey`: `KindLabel("watched")` returns nil, so the result already falls back to `L["Other"]`. No change.
- Header comments in `History.lua` and `InsightsFilters.lua`: document the value.
- Risk: low. The change is additive, `v` stays 1, and legacy entries are unaffected.
- Test movement: add cases to `test_history` (snapshot of a forced, uncategorized drop) and to
  `test_insights_filters` (it reads as `watched` and is listed last). This moves the pass count, so
  `docs/test-cases.md` and the README badge move in the same change (testing-§7).

### C-02 (F-002): correct the legacy note

- `docs/known-limitations.md:107-108` and `modules/InsightsFilters.lua:11`: say that the fallback reads
  **any** pre-#13 entry whose slot is `INVTYPE_NON_EQUIP_IGNORE` as a tier token. On a profile that had
  Gear only off, that includes mounts, pets, toys and recipes. Add the in-client check to the smoke tests.

### C-03 (F-003): split `IF.Period`

- `modules/InsightsFilters.lua:174`: move the `from` resolution into a local `startOf(range, days,
  first, now)`, so the scan loop stays in `Period`. Behavior does not change, and
  `test_insights_filters`'s Period cases pin it. Expected movement: the watch list returns to 0
  warnings at the next release's regeneration.

## Standards conformance

- C-01 adds a History-only stored value. It adds no schema row, no new `C.CATEGORIES` entry and no migration.
  It writes through History's own snapshot, which is the only place History is written (architecture-§5 single write
  path). The string reuses an existing locale key.
- C-02 is docs only. C-03 is an internal refactor of a pure function. Neither introduces a deviation.
