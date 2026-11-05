# Final summary (written as if the proposed changes landed and passed)

**Headline.** The whole-run review of issues #10 to #14 found the branch sound. The items work
together correctly: no collectible reaches the toast stack, AutoAsk or an ask, the step-13 migration
holds, and the toast stub covers every method the addon calls. The review found one gap at the seam
between #13 and #12. An item that the Always watch list lets through, but that belongs to no kind,
was recorded with no category, so Insights counted it as a tier token or as equipment. These changes
record it as a watched item and correct the legacy note.

**Counts.** Critical fixed: 0, High fixed: 0, Medium fixed: 1 (F-001), Low fixed: 2 (F-002, F-003).

## Changes by theme

- **Every drop recorded after #13 says what kind it is.** A forced item of no kind is stored as
  `watched`, and Insights shows it as "Watched item". Why it mattered: whitelisted reagents and quest
  items inflated the Tier tokens count. F-001 and F-002, C-01 and C-02. Files: `modules/History.lua`,
  `modules/InsightsFilters.lua`, `docs/known-limitations.md`, and the tests.
- **Complexity.** `IF.Period` is split in two. F-003, C-03. File: `modules/InsightsFilters.lua`.

## API / behavior changes

- History entries can carry `category = "watched"`. The change is additive and `v` stays 1.
- The Insights Category dropdown can list "Watched item".

## Migration notes

None needed. Existing entries keep their legacy reading.

## Test movement

The pass count rises by the new C-01 cases from 2212. `docs/test-cases.md` and the README badge move
in the same commit. The next release's regeneration is expected to drop the complexity watch-list
entry for `IF.Period`.

## Known follow-ups

- Owner's call (plan, #12 Q3): whether the `INVTYPE_NON_EQUIP_IGNORE` → tier token fallback stays, once
  the C-02 dump shows what the client reports.

## Verification

`03_SMOKE_TESTS.md` with its sign-off table filled in, plus the DW-FIN1 commits on `feat/2026-11-05-issues-10-14`.

```
DW-FIN1: Whole-run review fixes (F-001..F-003)

A whitelisted item of no kind is recorded as a watched item, so Insights no longer counts it as a
tier token or equipment. The legacy note describes the slot fallback as it is. IF.Period's start is
resolved apart from its scan.
```
