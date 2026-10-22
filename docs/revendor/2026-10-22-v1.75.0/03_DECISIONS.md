# 03 — Decisions

Every decision below was made before this re-vendor, by the owner, in the cross-repo bundle
`Ka0sAddonsCommonTasks/docs/2026-10-22-LIBKA0S_ISSUES_45_58/` (`plan-data/items.json`,
`inputs/OWNER_SCOPE.md`). The interview did not run (DC-01 B1.7), and no GitHub issue is filed for a
decline in this milestone.

| Candidate | Decision | Owner / reason |
|---|---|---|
| `W.SearchBox` | adopt | a later DW item of this run (DW-01..DW-09) |
| `W.TestStrip` | adopt | a later DW item of this run (DW-01..DW-09); `info` stays declared |
| launcher-§6 binding | adopt | a later DW item of this run (DW-01..DW-09) |
| `LibKa0s-Glow-1.0` | adopt | DW-08 |
| `LibKa0s-Sim-1.0` (and its private step panel) | adopt | DW-02 and the Sim items after it; the done tick stays host-passed `confirm` |
| `Item.BonusIDsFromLink` | not adopted in this run | OWNER_SCOPE A.#51 names BankLedger and LootHistory only; this addon keeps its modifier walk |
| `O.Drawer` | not adopted in this run | no consumer need |
| `Media.ICON_SETS`, `Media.IconAuthor` | not adopted in this run | no icon chooser, no Game-icons mark |
| `Kit.assertLatchHoldOrder` | not adopted in this run | no new latch case owed |

Blockers are not decisions; they were fixed in the re-vendor commit (`01_DELTA.md`, 3g).
