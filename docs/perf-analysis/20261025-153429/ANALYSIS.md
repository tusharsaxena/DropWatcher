# Analysis — 20261025-153429

- **Addon:** DropWatcher 1.0.0 (record schema 2, client interface 120105)
- **Captured:** 2026-10-25 15:30 local, label `2026-10-25 15:30`
- **Who / where:** Sacrìlege-Frostmourne, level 90 Protection Paladin · Murder Row (no subZone) · party (5) / party
- **Delta:** -0.47 ms/frame. Unresolved: it is inside the 0.5 ms/frame floor, and its sign is backwards (the suspended arm was slower)
- **Previous capture:** [`20261017-010913`](../20261017-010913/ANALYSIS.md)

## Headline

Two pulls in Murder Row with a five-player party: arm A ran 62.0 s with the addon active, arm B 69.3 s
with it suspended. In a minute of combat the addon ran one piece of measured code once: a single
`tradeTimer.scan` costing 0.0154 ms, about 0.00025 ms per second of combat. The frame-time delta
resolves nothing. It is smaller than the floor, and it points the wrong way. There is nothing in the
addon to act on, and smoke check DIAG-4 is still not discharged: no loot entered the feed inside the
clean arm.

## The arms

Both figures come from [`dump.json`](dump.json)'s `fps` block; the rounded forms are in
[`report.md`](report.md).

| Arm | Seconds | Frames | Avg fps | ms/frame |
|---|---|---|---|---|
| active (addon running) | 62.0160 | 3353 | 54.0667 | 18.4957 |
| suspended (addon inert) | 69.3430 | 3656 | 52.7234 | 18.9669 |
| **delta** | | | | **-0.4712** |

The delta is unresolved. At 0.47 ms/frame it is under the roughly 0.5 ms/frame below which the
instrument cannot see the addon, and its sign is backwards: arm B, with the addon inert, rendered
frames more slowly than arm A with it running. That is the environment moving between the pulls,
not the addon. Unlike the first capture, both arms are now inside the 60–80 s length the floor is
quoted for, so the noise is the usual amount rather than worse. They are unequal by 7.3 s; combat
gating sets each arm's length by when its pull ends.

## The buckets — what the addon actually cost

Every figure from [`dump.json`](dump.json)'s `buckets`; `ms/s` is `totalMs` over the **active** arm's
seconds, as [`report.md`](report.md) computes it. Buckets nest — **do not sum the column**.

| Bucket | Calls | Total ms | ms/s | Max ms | Parent |
|---|---|---|---|---|---|
| `tradeTimer.scan` | 1 | 0.0154 | 0.00025 | 0.0154 | none declared |

Total accounted cost per second of combat: **0.00025 ms/s** (0.0154 ms over 62.0160 s). One call, so
ms per call is the same 0.0154 ms and the max equals the total.

What fired it: `modules/TradeTimer.lua` scans on `BAG_UPDATE_DELAYED`, `LOOT_CLOSED` and a
`DropAdded` for one of your own drops (its header comment). `feed.add` never fired, so no drop
reached the feed and it was not a `DropAdded`. Something changed your bags or closed a loot window
during arm A.

Seven of the eight buckets declared in `core/PerfSetup.lua` are absent, so they never fired inside a
recording window:

- `parse` and `feed.add`: no loot line arrived in either window, so no receipt reached the feed.
- `evaluate` and `quality.gate`, both declared `within = "feed.add"`: they never ran, so their
  declared parent was **not observed**. This capture neither confirms nor contradicts that nesting.
- `inspect.read`: the addon does not inspect in combat, and both windows were combat.
- `gear.rebuild`: no rebuild of your worn and bag items, even though `BAG_UPDATE_DELAYED` is shared
  with the trade timer. The record cannot say whether a bag event arrived and the rebuild found
  nothing to do, or the scan came from `LOOT_CLOSED` instead.
- `window.refresh`: nothing repainted the window during either pull.

## What the capture did not hold constant

- **The pull.** Arm A recorded 15:30:39–15:31:41 and arm B 15:33:15–15:34:24 (the run log in
  [`report.md`](report.md)). Arm B started 1 min 34 s after arm A ended, so these were different
  pulls, and the backwards delta says the second was heavier on the client.
- **Duration.** 62.0 s against 69.3 s.
- **Held constant:** the character, the zone (Murder Row), the group (party of 5) and the session.
  The run log shows `addon SUSPENDED` at 15:33:08, before arm B was armed, and `addon RESUMED` only
  after `run finished`, so arm B was suspended for its whole window. No `/reload` landed between the
  arms: one run from `run started` to `run finished`, with no `[Init]` line.
- **Other addons:** the record does not say which other addons were loaded. Protocol step 1 asks
  for the addon under test and the stock UI only.

## What moved

Against [`20261017-010913`](../20261017-010913/ANALYSIS.md) (DropWatcher 0.1.0):

- **Buckets:** that capture noted none (`buckets` was `{}`). This one noted one `tradeTimer.scan`, at
  0.00025 ms/s. That is a difference in what the pulls did (a bag change or a closed loot window in
  arm A), not a change in the addon's cost.
- **Arm length:** 19.1 s and 15.0 s then, 62.0 s and 69.3 s now. This is the first capture whose arms
  sit inside the length the floor is quoted for.
- **Delta:** -2.35 ms/frame then, -0.47 ms/frame now. Both are backwards; this one is also inside
  the floor. Neither reads the addon.
- **Not moved:** the place and group (Murder Row, party of 5), the client interface (120105), the
  record schema (2), and the seven buckets that never fire on a trash pull.

## Actions

1. **DIAG-4 is still owed** (`docs/smoke-tests.md`, DIAG-4, review C-04). No loot entered the feed in
   the clean arm, so neither `evaluate` nor `quality.gate` was observed inside `feed.add`. This is
   the second capture to miss it, which supports the previous capture's action 2: with combat-gated
   arms, `feed.add` shows only when a loot line arrives while the player is still in combat, and
   that question (DIAG-4's wording, or the harness's gating as a LibKa0s matter) is still open with
   the owner.
2. None for the addon's code. Its one measured cost in a minute of combat is 0.0154 ms.
