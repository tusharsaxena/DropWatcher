# Ka0s Drop Watcher: simulator feedback (M9 addendum)

- **Extends:** the simulator spec `2026-10-11-drop-watcher-simulator-design.md` and the M8 spec
  `2026-10-11-drop-watcher-ui-feedback-design.md`.
- **Source:** the owner's first in-game `/dw sim` run on 2026-10-11. The evidence is in
  `docs/superpowers/research/2026-10-11-sim-feedback/`: the chat log, a screenshot of the empty window, and the
  MultiMeters perf-run panel the owner wants copied.
- **Items:** DW-90..DW-92, milestone M9, on branch `feat/2026-10-10-drop-watcher-v1`, run after M8.

## 0. Bug first: a sim run shows nothing (DW-90)

**What happened.** The owner was solo and out of an instance. They ran `/dw sim start key`, then `/dw sim run`.
- Chat confirmed 4 members and 828 items, then printed steps 5, 8 and 11 of 11 and "timeline finished".
- The window stayed empty on Group drops ("No drops yet"), with View set to Interesting and Content to This instance.
- The footer read `Inspect: no group · Last loot 2m ago · Not tracking in Solo · change in settings · Pawn: off`.

So loot reached the feed's loot path, because "Last loot" moved. But the situation was still **Solo**, so the gate
dropped the loot, and the inspect broker saw **no group**. Two of the simulator's answers never reached the modules
that read them in the real client:
- the situation (`mythicPlus` for a key);
- the group (the roster).

The headless suites passed. The likely reason is that they answered through the mock, not through the path the client
takes. DW-70 itself recorded that Situations.ReadInputs, Roster, Inspect's IsInInstance and Restrictions'
InCombatLockdown still call bare client globals rather than Compat members. Bare globals are not seamed, so the
simulator cannot answer them.

**Fix the root cause, using systematic debugging.**
1. Reproduce it headless the way the client sees it. Any global the simulator must answer is left with its **real**
   solo answer in the mock: not in a group, not in an instance, and no instance difficulty. Then run a `key` scenario
   and assert that drops appear in the feed **and** pass the window's default filters.
2. Find every read the simulator must answer. That covers the situation inputs, group membership and units, unit
   names, GUIDs, classes and connected state, instance and difficulty, combat lockdown, and the `LOOT_ITEM*`
   GlobalStrings already flagged at the M7 review.
3. Route each of those reads through a Compat member, which SimSeam then covers automatically. Keep `core/Compat.lua`
   under 1000 lines by moving pure code out first, the way M8 did.

**What must be true afterwards.**
- A sim run fills the window under the **default** filters: View Interesting, Content This instance, Quality Rare+.
- During a run, the footer shows the simulated situation and group, for example `Simulating: Mythic+ · 4 members`
  and `Inspect: 4/4`.
- The chat log reports every step, not only some. Each step gets one line, such as `step 3 of 11: loot (2 drops)`.
  The panel in §1 makes this mostly a fallback.
- **Add an end-to-end regression test.** It runs every scenario in the solo, out-of-instance world described above. It
  asserts, for each scenario:
  - drops are in the feed;
  - verdicts exist for you and for the looter once the inspect finishes;
  - the window's Group drops list shows rows under the default filters;
  - My drops shows your simulated drops.
- Fix the M7 review's low findings about the same reads, because they share this root cause:
  - SimEvents reading `InCombatLockdown` and the `LOOT_ITEM*` strings directly;
  - `raid1` not aliased for the player in raid and LFR scenarios;
  - your own member shown offline in raid and LFR scenarios;
  - LFR never picking instance chat.

## 1. The simulation panel (DW-91)

**What the owner wants.** A step panel like MultiMeters' `/mm perf` run panel
(`research/2026-10-11-sim-feedback/01-perf-run-panel.png`). That panel is LibKa0s-Perf-1.0's
`LibKa0s/PerfPanel.lua`. Read it, and copy its look and its states exactly.

**Layout.** A small titled window, `Ka0s Drop Watcher - Simulation`, with the close button at the top right. Each row
has three columns:
- a status dot;
- the step's name (`Start: Mythic+ key`, `Pull: <boss>`, `Combat and chat lockdown`, `Kill: <boss>`,
  `Loot: 3 drops`, `Lockdown lifts`, …, `Key complete`, `Stop simulation`);
- the step's slash command, right-aligned (`/dw sim step`, `/dw sim pull`, …).

**States.** Each row's text and dot share a color:
- completed steps are dimmed, with a check;
- the current step is highlighted;
- the next clickable step looks interactive;
- steps further ahead are gray.

These match the colors PerfPanel uses.

**Rows are clickable.**
- Clicking the next step runs it.
- Clicking a later step runs every step up to and including it, in order. The steps are never skipped.
- Clicking a completed step does nothing, and its tooltip says when it ran.
- Each row's tooltip says what the step injects, for example "Two loot lines through the real loot handler".

**Run controls.** The panel's own controls:
- `Run all`, which runs the steps automatically, as `/dw sim run` does, highlighting each step as it goes;
- `Pause` and `Resume`;
- `Restart`, which stops the scenario and starts the same one again;
- `Stop`.

**Choosing a scenario.** With no simulation running, the panel shows a scenario choice: Key, Dungeon, Raid, LFR, Delve
and Open world, plus a member count for a raid. A `Start` button starts the chosen scenario.

**Opening the panel.**
- `/dw sim` with no argument opens it.
- `/dw sim start …` opens it.
- `/dw sim panel` toggles it.
- The panel remembers its position; that is window state, not a setting.

**Keeping things consistent.**
- The panel never changes the timeline. It calls the same functions the slash verbs call, so typing and clicking stay
  in step: a typed `/dw sim step` updates the panel too.

**Placement and structure.**
- The panel opens beside the Drop Watcher window, not over it.
- It is built from LibKa0s widgets: Core's frame skin and close button, plus Pool if rows are pooled.
- Draft a LibKa0s issue to generalize PerfPanel into a shared **step panel** widget that Perf and Drop Watcher would
  both use. Put it in `issues-to-file.md` and do not file it.
- Keep the panel's own code to one new file under 1000 lines.

## 2. Tests and smoke (in DW-90 and DW-91)

**Headless tests.**
- The panel builds; its rows track the timeline.
- Clicking a later row runs the steps in between.
- A typed `/dw sim step` updates the panel.
- Run all, pause and resume, restart and stop all work.
- The scenario picker starts the chosen scenario.
- §0's end-to-end regression passes.

**Smoke checks**, owed and never marked passed by an agent:
- a sim run in game fills the window under the default filters;
- the panel's highlight follows the run;
- clicking ahead runs the steps in between;
- restart and stop work.

## 3. Docs and bundle (DW-92)

Update the README's simulator section (the panel), ARCHITECTURE, module-map, slash-dispatch (`/dw sim panel`) and the
smoke-tests SIM theme. Regenerate test-cases. Run a fresh automated-test bundle: four suites, CCN ≤ 15, no authored
file over 1000 lines.
