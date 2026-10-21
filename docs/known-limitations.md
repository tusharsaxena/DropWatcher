# Known limitations — Ka0s Drop Watcher

What the addon does not do yet, or cannot know without the client. Spilled from
`ARCHITECTURE.md` → Known Limitations (documentation-§3), which keeps a summary and links here. How
the code reads every case the design leaves open, module by module, is in
[`design-readings.md`](design-readings.md); the in-game checks named below by id are in
[`smoke-tests.md`](smoke-tests.md).

## For the player

- **Unconfirmed in game.** Nearly every in-game check in `smoke-tests.md` is owed: only
  STATE-6 and FEED-79 have a recorded client pass (2026-10-16). The readings most at risk are whether `CHAT_MSG_LOOT` is readable
  mid-encounter (COMBAT-1), whether a whisper goes out during an encounter (ASK-4), the raid trade
  rule (TRADE-3, `personal` until confirmed) and whether the game counts the looter's bags as well
  as their worn gear (TRADE-4, worn gear only today).
- **Localized clients.** Loot lines and the trade-time sentence are read with the client's own
  GlobalStrings, but an upgrade track's tier comes from its enUS name until FEED-5 records the
  client's track ids, so a non-English client shows no track change (LOC-1).
- **A delve's tier** is not in its group header: the header names the difficulty as the client
  gives it (GetInstanceInfo's difficultyName, else GetDifficultyInfo's), and neither is known to
  name the tier, so a delve reads `Delves` (feedback-3 spec §4 names `a delve tier`). FEED-30 records
  what the client gives.
- **Tier tokens** are recognized, but the slot a token makes is not read, so the verdict for one is
  `unknown` until the tier-token follow-up (design spec §14).
- **Your gear** is a per-slot best, not a loadout planner: unique-equipped limits and a
  two-hander's claim on both hands are not weighed, and the reagent bag, the bank and the warband
  bank are not read.
- **Off-spec** (feedback-19). A drop your current spec can't use is judged for the other specs of
  your class on item level alone: no scorer is asked for an off-spec, so a stat-weight preference
  never moves it, and its tooltip and the detail card say so. A looter's or a candidate's off-spec
  is judged on the gear they wear (their inspect read), never their bags, so an item they keep in
  their bags for that spec is not counted and an off-spec can read better for them than it is. Every
  other spec of the class counts, with no setting to leave one out. FEED-80, FEED-81, ASK-11 and
  TOAST-5 are the in-game checks.
- **A drop you traded away** is `tradedAway` in the history and its Offer button on Drops reads
  `Traded`, but its Trade window cell reads as expired rather than `Traded to …`.
- **A reload and a relog** (feedback-15 spec §0, DW-Q0). The session is the login: a `/reload`
  brings this session's drops back to the Drops tab from the History log (`modules/FeedRestore.lua`),
  linked to their entries, but a reload mid-key starts a new key header for the drops looted after
  it (the feed's open-run key is not kept across a reload), and a full relog starts an empty Drops
  tab. Drops cleared from the Drops tab (`/dw clear`, Clear on boss kill) stay cleared, and a drop
  you asked for still reads `Asked`, but the Asks book is not kept: your own drop's Offer and
  Announce read untoned again after a reload, and its Offer panel offers each candidate anew (the
  History keeps that it was `offered`, not to whom). An entry of an earlier session takes no more
  ask or trade-estimate outcomes (it is in no live feed); a completed trade still matches it by item id. HIST-2 and HIST-5 are the in-game
  checks.
- **The History tab's detail card** (feedback-15 spec §4, DW-Q4) draws only what an entry keeps:
  the verdicts and their item-level and score deltas, the trade estimate's state, reason and basis,
  the place and who saw it. It has no stats, worn item, track or trade rule to show, and on your own
  drop it says who it was an upgrade for is not kept. Show in Drops is off for an entry no longer in
  the Drops tab (an earlier session's, or after Clear), and the Drops tab's own filters may still
  hide the drop it opens. HIST-7 is the in-game check.
- **The trade-time warning** can arrive up to a minute late while the window is closed (the ticker
  slows to once a minute).
- **A keystone chest** has no `ENCOUNTER_END`, so auto-ask times its drops from the drop itself.
- **Compact mode** (M12, compact spec) is a second layout of the same window, unconfirmed in game
  like the rest (COMPACT-1..7). A switch carries the scroll offset as the same fraction of the
  scroll range, so the drop at the top can move by a card or two; the Columns rows and Row height
  shape the full layout's tables only. The run override reads the situation edge, so a run ends
  when the situation moves off the one it began in (a key's completion re-reads it as a dungeon),
  not on a boss kill or a wipe.

## The simulator

- **The simulator** (milestone M7) runs end to end: `/dw sim start <scenario> [size]` builds the
  pool and the group, `run` and `step` play the scenario's timeline, and the `SIMULATION` title text, the footer's
  `Simulating` line, the `sim` diagnostics section and the `SIM` debug tag show it (DW-73). The
  timeline's steps are event drivers only; the engine computes every verdict, estimate and inspect.
  A key's bosses drop nothing: its loot comes with the completion, as the end-of-run chest's does.
  Since the owner's first run (DW-90, sim feedback §0) a run fills the window under the default
  filters in every scenario: the group wears the content's items 1 to 12 levels above it (so its
  drops are spare for their looters whatever you wear; the M7 band around your own level left a
  group naked of content you outgear, and nothing read as Interesting), each random burst has a
  line of yours and a member's plain loot line, a simulation tracks the situation it simulates
  whatever its row says (the delve and the open world are untracked by default), and every step
  prints its line. So a simulation does not exercise a situation's tracking switch.
- **A simulated member's spec** stays unknown: the inspect broker reads the spec after it has
  cleared its own inspect (its flight ends first), and the simulator lets the inspect data go on
  `ClearInspectPlayer`, as the client does. Whether the live client still answers
  `GetInspectSpecialization` after the clear is unconfirmed (SIM-4); the headless mock keeps it.
- **A simulated loot line** carries no `ENCOUNTER_LOOT_RECEIVED` or `C_LootHistory` twin, so the
  feed's de-duplication across sources is not exercised by a simulation (`test_feed` covers it).
- **The simulator's item pool** reads the newest Encounter Journal tier, which is the current
  season's on a live client; a season whose dungeons sit in older tiers is read only as far as the
  newest tier lists them. Its difficulty ids are the journal's (Mythic Keystone 8 for a key); an
  instance without one of its side's difficulties repeats another difficulty's links, which the pool
  de-duplicates. A pool built with `loot for me` lists your class's items only, so members of
  another armor type draw fewer slots from it.

## Internal readings and the build

- **Which source handed the bare link** in the owner's BUG-1 report (ui spec §0) is not proven
  offline: the headless reproduction shows that a first report without bonus data read the drop at
  its base level and quality, and the fix keeps the most complete link and reads your own drops from
  their bag item whatever the source. ITEM-3 and the `drops` diagnostics line record it in game.
- **The Situations table** (General › When to show's until feedback-24; since DW-H0, feedback-8 spec §0) is the page's own editor
  (`settings/PageEditors.lua`), not a library composer: LibKa0s-Options has no grid composer for
  mixed controls. A LibKa0s issue asking for one is filed as
  [LibKa0s#50](https://github.com/tusharsaxena/LibKa0s/issues/50).
- **The Profiles page** builds only where AceDBOptions and AceConfigDialog resolve, which the
  headless mock does not model; PROFILE-1 is its in-game check.
- **The logo** is a placeholder generated for the scaffold; the owner may replace the art
  (regenerate the TGAs with the recipe in `DEPENDENCIES.md`).
