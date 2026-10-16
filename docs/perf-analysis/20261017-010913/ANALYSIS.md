# Analysis — 20261017-010913

- **Addon:** DropWatcher 0.1.0 (record schema 2, client interface 120105)
- **Captured:** 2026-10-17 01:04 local, label `2026-10-17 01:04`
- **Who / where:** Sacrìlege-Frostmourne, level 90 Protection Paladin · Murder Row (no subZone) · party (5) / party
- **Delta:** -2.35 ms/frame. The sign is backwards (the suspended arm was slower), so this is not a reading of the addon
- **Previous capture:** none, this is the first

## Headline

Two short pulls in Murder Row with a five-player party: arm A ran 19.1 s with the addon active and
arm B ran 15.0 s with it suspended. **No bucket fired in either window**, so this capture measured
no DropWatcher code at all. The record's `buckets` is `{}`. The frame-time delta is large, but it
runs the wrong way, with the suspended arm 2.35 ms/frame slower. That means the two pulls differed,
and it says nothing about the addon. There is nothing in the addon to act on from this capture.
It also does not satisfy smoke check DIAG-4: no boss kill and no loot landed inside the clean arm.

## The arms

Both figures come from [`dump.json`](dump.json)'s `fps` block; the rounded forms are in
[`report.md`](report.md).

| Arm | Seconds | Frames | Avg fps | ms/frame |
|---|---|---|---|---|
| active (addon running) | 19.0510 | 1357 | 71.2299 | 14.0391 |
| suspended (addon inert) | 14.9660 | 913 | 61.0049 | 16.3921 |
| **delta** | | | | **-2.3531** |

The delta is well past the ±0.3 ms/frame floor in size, but its sign is the tell: an addon that
was doing nothing (arm B) cannot make the frame slower than an addon that was running (arm A). The
second pull was simply heavier on the client, perhaps a bigger pack, more spell effects or a
different spot. Both arms are also far shorter than the 60–80 s that floor is quoted for, at 19.1 s
and 15.0 s, so even a delta with the right sign would be noisier than usual. The arms are unequal
in duration too, by 4.1 s. Combat gating sets each arm's length by when the pull ends, not by
anything that makes the two pulls alike.

## The buckets — what the addon actually cost

Every figure from [`dump.json`](dump.json)'s `buckets`; `ms/s` is `totalMs` over the **active** arm's
seconds, as [`report.md`](report.md) computes it. Buckets nest — **do not sum the column**.

| Bucket | Calls | Total ms | ms/s | Max ms | Parent |
|---|---|---|---|---|---|
| *(none — `buckets` is `{}`)* | | | | | |

Total accounted cost per second of combat: **0 ms/s**. No bucket was noted inside either recording
window. That is a result about what the run exercised, not a claim that the addon is free.

All eight buckets declared in `core/PerfSetup.lua` are absent, and each one is absent for a reason
that matches a trash pull:

- `parse` and `feed.add`: no loot line arrived inside a window, so no receipt reached the feed.
- `evaluate` and `quality.gate`, both declared `within = "feed.add"`: they never ran. Their declared
  parent was **not observed**. This capture neither confirms nor contradicts that nesting.
- `inspect.read`: the addon does not inspect in combat, and both windows were all combat.
- `gear.rebuild` and `tradeTimer.scan`: no change to worn or bag items during either pull.
- `window.refresh`: nothing triggered a window repaint during either pull.

The brackets record only while an arm is recording, and the harness opens and closes each arm on
the player's combat state (`libs/LibKa0s/PerfSampler.lua`, `openWindow` and `closeWindow`). So only
work that happens **during** combat can appear in a capture. Most of DropWatcher's work comes from
loot and inspects, and those mostly happen between pulls.

## What the capture did not hold constant

- **The pull.** The run log has arm A recording 01:04:49–01:05:08 and arm B 01:08:54–01:09:09.
  Arm B started 3 min 46 s after arm A ended, so these were two different pulls. Nothing in the report records what was
  pulled, and the backwards delta says the second was heavier.
- **Duration.** 19.1 s against 15.0 s.
- **Held constant:** the character, the zone (Murder Row both times), the group (party of 5) and the
  session. The run log shows `addon SUSPENDED` at 01:08:45, before arm B was armed, and
  `addon RESUMED` only after `run finished`, so arm B really was suspended for its whole window. No
  `/reload` lands between the arms: one run from `run started` to `run finished`, with no
  `[Init]` line.
- **Other addons:** the record does not say which other addons were loaded. Protocol step 1 asks for
  the addon under test and the stock UI only.

## What moved

First capture, so there is nothing to diff against. It is not a useful baseline either: with no
bucket fired, the only figures are frame times from two unlike pulls.

## Actions

1. **DIAG-4 is still owed** (`docs/smoke-tests.md`, DIAG-4, review C-04). This capture does not
   discharge it. It had no boss kill and no loot in the clean arm, and the bucket table is empty, so
   neither `evaluate` nor `quality.gate` was observed inside `feed.add` or at top level.
2. **New here: DIAG-4's recipe may not be reachable as written.** Because the arms are
   combat-gated, `feed.add` appears only if a loot line arrives **while the player is still in
   combat**. Boss loot often lands as combat ends, which may be after the arm has closed. A capture
   that does observe it probably needs back-to-back pulls, so that one pack's loot is looted while
   the next is engaged, or a dungeon key where trash loot keeps arriving mid-fight. Whether that is
   practical, or whether DIAG-4's wording (or the harness's gating) should change, is the owner's
   decision. If it is the gating, that is a LibKa0s question, not one for this addon.
3. **For the next capture:** hold the arms closer together. Use similar packs, longer pulls (the
   floor is quoted for 60–80 s arms), and the addon under test with the stock UI only.
