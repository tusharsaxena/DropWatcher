# 02 — Candidates

Sources: `git -C ../LibKa0s log --oneline v1.71.0..v1.72.0`, the v1.72.0 block of `../LibKa0s/CHANGELOG.md`,
`docs/api/Perf/version-15.1.1.6-docs.md` against `version-14.1.1.6-docs.md`, and `testkit/README.md`.

The interview (Steps 5 to 7) is **not run here**. Run DW-P22 does the re-vendor only. Plan items
DW-P24 and DW-P25 already decide adoption for both class-B candidates, so they are listed with the
item that owns each decision. This bundle has no `03_DECISIONS.md` and no `04_EXECUTION_PLAN.md`.

## A. Delivered on the re-vendor alone

- **Perf minor 15's report wording.** A mixed observation names both parents ("first: X, then:
  Y"). The nesting footer is printed only when a bucket actually nests. This reaches the perf report
  with no host change.
- **Kit revision 39's `__fireUnconditional` reach.** The reach calls in `tests/test_disabled.lua:103-104` now reach
  method-name and function handlers after unregister.

## B. Host change required

| Candidate | Evidence | Touches | Blast radius | Owner |
|---|---|---|---|---|
| `Perf.Note(key, ms, parentKey)` with a real parent (or `false`) for `evaluate` and `quality.gate`, which run inside `feed.add` | `LibKa0s/Perf.lua` `P.Note` doc comment (minor 15); Perf API doc `version-15.1.1.6-docs.md` "What changed at this version" | `modules/LootFeed.lua`, `core/PerfSetup.lua` descriptor `within` | Additive | DW-P24 (F06 X05 X12) |
| `Kit.assertLatchHoldOrder` for slash-commands-§7 step 10, and asserting `__fireUnconditional`'s count | `testkit/latch.lua`; `testkit/README.md` "The step-10 latch helper"; `testkit/mock_record.lua` `M.__fireUnconditional` doc | `tests/test_disabled.lua` | Additive (tests only) | DW-P25 (F04 F05 F18) |

## C. Whole-module adoption

None. v1.72.0 adds no major. The payload majors this addon does not look up are unchanged from
v1.71.0, so the reasons recorded earlier for not adopting them still stand.
