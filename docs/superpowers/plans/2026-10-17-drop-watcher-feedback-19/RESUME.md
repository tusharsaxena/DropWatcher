# Resuming the feedback-19 run (M26, off-spec)

Run `./resume-state.sh -v` in this folder. Items land on `feat/2026-10-17-offspec`, in order
DW-O0 → DW-O5 (see the plan). Keep the green gate. Push after each milestone item; never merge without the
owner's go-ahead.

## Log
- 2026-10-17 — spec and plan written; branch cut from master `419bc1e`; suite green (1480/0/1), lint 0/0.
- 2026-10-17 — DW-O0 landed: the off-spec verdict (modules/OffSpec.lua, the Evaluate hook, Gear pool/OffSpecGear, Inspect worn off-spec gear); suite 1497/0/1, lint 0/0, perf green, max CCN 14.
- 2026-10-17 — DW-O0 review: Gear signature over sorted bag gear (a bag sort no longer re-judges the feed); suite 1498/0/1, lint 0/0, perf green, max CCN 14.
- 2026-10-17 — DW-O1 landed: how off-spec looks (offspec tone, modules/OffSpecCells.lua, Me cell gear half, marks, detail/History cards, History snapshot, filter bar, legends); suite 1518/0/1, lint 0/0, perf green, max CCN 14.
