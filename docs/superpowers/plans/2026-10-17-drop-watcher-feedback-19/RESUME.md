# Resuming the feedback-19 run (M26, off-spec)

Run `./resume-state.sh -v` in this folder. Items land on `feat/2026-10-17-offspec`, in order
DW-O0 → DW-O5 (see the plan). Keep the green gate. Push after each milestone item; never merge without the
owner's go-ahead.

## Log
- 2026-10-17 — spec and plan written; branch cut from master `419bc1e`; suite green (1480/0/1), lint 0/0.
- 2026-10-17 — DW-O0 landed: the off-spec verdict (modules/OffSpec.lua, the Evaluate hook, Gear pool/OffSpecGear, Inspect worn off-spec gear); suite 1497/0/1, lint 0/0, perf green, max CCN 14.
- 2026-10-17 — DW-O0 review: Gear signature over sorted bag gear (a bag sort no longer re-judges the feed); suite 1498/0/1, lint 0/0, perf green, max CCN 14.
- 2026-10-17 — DW-O1 landed: how off-spec looks (offspec tone, modules/OffSpecCells.lua, Me cell gear half, marks, detail/History cards, History snapshot, filter bar, legends); suite 1518/0/1, lint 0/0, perf green, max CCN 14.
- 2026-10-17 — DW-O1 review: History off-spec tooltip names the compared level, not an empty slot (snapshots keep no baseline); suite 1519/0/1, lint 0/0, perf green, max CCN 14.
- 2026-10-17 — DW-O2 landed: off-spec ask (askOffSpec template, row, editor, {mygain} via OffSpec.EvalFor, Ask tooltip), toast third value and title, auto-ask lag and main-first re-arm; suite 1533/0/1, lint 0/0, perf green, max CCN 14.
- 2026-10-17 — DW-O2 review: auto-ask re-reads off-spec at fire time (a re-judged drop keeps main spec first); suite 1534/0/1, lint 0/0, perf green, max CCN 14.
- 2026-10-17 — DW-O3 landed: Offer for off-spec (two candidate statuses ranked after main-spec equals, offerable, gain sort, cyan Their eq with the spec name, Upgrade for N main-spec only); suite 1545/0/1, lint 0/0, perf green, max CCN 14.
- 2026-10-17 — DW-O4 landed: off-spec test-mode samples and showcase (22 drops, 5 groups), testOffGear, docs synced, FEED-80/81, ASK-11, TOAST-5 pending; suite 1549/0/1, lint 0/0, perf green, max CCN 14.
