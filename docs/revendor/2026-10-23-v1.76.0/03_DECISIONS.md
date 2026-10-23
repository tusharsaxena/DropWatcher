# 03 — Decisions

Every decision below was made before this re-vendor, by the owner, in the cross-repo bundle
`Ka0sAddonsCommonTasks/docs/2026-10-23-SIM_PREVIEW_MODE_STRIPS/` (`plan-data/items.json`,
`inputs/OWNER_SCOPE.md`). The interview did not run, and no GitHub issue is filed.

| Candidate | Decision | Owner / reason |
|---|---|---|
| Auto-play re-true (ready line, step-delay tooltip, typed-start suites, docs, smoke) | adopt | DW-01; this commit carries only the minimum suite adjustment that keeps the gate green |
| `W.TestStrip` `kind = "sim"` | adopt | DW-10; `info` stays declared |

The suite adjustment is a blocker fix, not a decision (`01_DELTA.md`, 3g).
