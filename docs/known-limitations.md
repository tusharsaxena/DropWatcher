# Known limitations — Ka0s Drop Watcher

What the addon does not do yet, or cannot know without the client. Spilled from
`ARCHITECTURE.md` → Known Limitations (documentation-§3), which keeps a summary and links here. How
the code reads every case the design leaves open, module by module, is in
[`design-readings.md`](design-readings.md); the in-game checks named below by id are in
[`smoke-tests.md`](smoke-tests.md).

## For the player

- **Confirmed in game, apart from a few.** The owner has recorded a client pass for nearly every
  in-game check in `smoke-tests.md`, among them COMBAT-1 (`CHAT_MSG_LOOT` mid-encounter), ASK-4 (a
  whisper during an encounter), TRADE-3 (the raid rule, kept at `personal`) and TRADE-4 (worn gear
  only). Nine are marked passed only provisionally (2026-11-05), not yet run in the client and
  tracked in issue #15: ITEM-6 and ITEM-7 (reopened by TT-1), SKIN-3, SKIN-15, SKIN-32 and
  SKIN-45, and SKIN-14, SKIN-38 and SKIN-40 (failed 2026-11-02, re-opened as R3-L3).
- **Localized clients.** Loot lines and the trade-time sentence are read with the client's own
  GlobalStrings, but an upgrade track's tier comes from its enUS name until FEED-5 records the
  client's track ids, so a non-English client shows no track change (LOC-1), and a tier token's slot
  is read in English words (below).
- **A delve's tier** is not in its group header: the header names the difficulty as the client
  gives it (GetInstanceInfo's difficultyName, else GetDifficultyInfo's), and neither is known to
  name the tier, so a delve reads `Delves` (feedback-3 spec §4 names `a delve tier`). FEED-30 records
  what the client gives.
- **Tier tokens** are judged as the piece they make, by item level alone, never by a scorer, and the
  History keeps the slot it made, not its classes. The slot is read from the token's own text against
  English words in the enUS locale table (TT-1; a documented localization-§4 deviation): its Use text
  (`... set hand item appropriate for your class.`), else a tooltip line that is exactly a slot's name,
  else a slot noun in its item name. A token none of these reads, and every token on a non-English
  client, is judged in its best tier slot (`Token: any slot`), never a wrong one. An omni Curio is
  told by its name ending in `Curio` (an epic Miscellaneous or Reagent item), so on a non-English
  client an unlisted Curio is not seen as a token. Legion's cloak tokens are not a tier slot here: a
  cloak noun names no slot, and such a token reads `any`. `C.TIER_TOKENS` overrides any of this per
  item id, and ships empty (categories design spec §7, DW-CAT4).
- **Collectibles** (issue #13). A caged battle pet arrives as a `|Hbattlepet:` link and is never
  watched; only companion items are. A recipe's "known" state is the client's `ITEM_SPELL_KNOWN`
  tooltip line: under an addon restriction that line can read secret, and the drop then reads
  `collectUnknown` until it is read again when combat ends. Someone else's bound collectible reads
  trade `unknown`; your own reads the trade timer's exact answer once its bag item is matched
  (COLL-6). The collection APIs' answers were confirmed in game on 2026-11-05 (COLL-1).
- **Item kinds and item lists apply to drops from then on.** Turning an item kind off, or putting an
  item on Always watch or Never watch, filters the drops that arrive after; a drop already in the
  feed stays, and a drop restored after a `/reload` is not filtered by a Never watch entry added
  since it dropped. History entries recorded before issue #13 have no item kind and read as
  Equipment, or as Tier token when their slot is `INVTYPE_NON_EQUIP_IGNORE` (see Insights below).
  An item on Always watch that has no kind (a reagent, a quest item) is kept as Watched item, its
  own entry in the Insights Category filter.
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
- **The toast without LibKa0s** (AT-A2). The toast's shell is LibKa0s-Toast-1.0; an install
  missing LibKa0s shows no toast at all (the seam's stub), where before it drew one without its
  close mark. The shell is shared: when another addon registered an earlier copy of the same minor
  first, that copy runs both, and the
  diagnostics' `toast: queue` reads empty; a drop gone from the feed still leaves the queue
  (`Prune` tries every drop toasted this session), and on a copy without `Hold(true)` turning
  `toast.inCombat` off mid-combat sends the toast on screen back to the queue. TOAST-7 and
  DEGRADED-3 are the in-game checks.
- **No Offer without another player** (DW-07, Addendum 08). Your own drop is offered only while
  another player is in your group: solo, in a delve with only a companion (Brann) and in a follower
  dungeon (its party all followers) its Actions reads No action, the Offer panel will not open, the
  Drops strip hides Post my tradeables, and Offer, Announce, Post my tradeables and `/dw offer`
  refuse; an announce queued under a restriction is canceled once the last other player leaves. A player is a unit the client answers
  `UnitIsPlayer` for; where that answer is secret, the GUID's kind decides (`Player-` is a player). A
  player in your group who is offline still counts, so the Offer stays while they are away. A test
  drop keeps its Offer (it judges its own spec roster). ASK-13 is the in-game check.
- **A drop you traded away** is `tradedAway` in the history and its Offer button on Drops reads
  `Traded`, but its Trade window cell reads as expired rather than `Traded to …`.
- **A reload and a relog** (feedback-15 spec §0, DW-Q0). The session is the login: a `/reload`
  brings this session's drops back to the Drops tab from the History log (`modules/FeedRestore.lua`),
  linked to their entries, but a reload mid-key starts a new key header for the drops looted after
  it (the feed's open-run key is not kept across a reload), and a full relog starts an empty Drops
  tab. Drops cleared from the Drops tab (`/dw clear`, Clear this session's drops on boss kill) stay cleared, and a drop
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
- **Compact mode** (M12, compact spec) is a second layout of the same window (COMPACT-1..7 passed
  in game, 2026-10-23). A switch carries the scroll offset as the same fraction of the
  scroll range, so the drop at the top can move by a card or two; the Columns rows and Row height
  shape the full layout's tables only. The run override reads the situation edge, so a run ends
  when the situation moves off the one it began in (a key's completion re-reads it as a dungeon),
  not on a boss kill or a wipe.
- **Insights** (issue #12) reads only the kept history (INSIGHT-1..8 passed in game, 2026-11-05):
  - **Legacy entries.** An entry settled before the ask, offer and settle stamps existed (before
    DW-N1.1) keeps no record of an ask or offer that a trade replaced. Insights counts someone
    else's drop you received as an ask, and your own drop traded away as an offer, so Asks sent and
    Offers sent include them and Ask success reads high (every such ask succeeded); the hovers say
    how many were inferred. A legacy item received shows the item level gain as last judged, which
    after you equipped it is usually 0 or a downgrade, marked "as last judged". From DW-N1.1 on, the
    gain is the verdict frozen when the trade completed (`got`).
  - **Mythic+ keys** are kept as one group per run, labeled with the dungeon, so Upgrades for me by
    boss counts encounter groups only (raids, and dungeons run without a key).
  - **The period** is the retention window (`history.retentionDays`). Retention prunes a whole group
    once its newest drop is older than the window, so the first day shown can be older than the
    window's start; the counts are what the kept groups hold.
  - **Item kinds.** A drop recorded before issue #13 has no category and reads as equipment, except
    one whose slot is `INVTYPE_NON_EQUIP_IGNORE`, which reads as a tier token (the run plan's #12
    Q3). The retail client gives every item you cannot equip that slot, not tier tokens alone, so a
    mount, pet, toy or recipe recorded before then reads as a tier token too; a cosmetic, which has
    a real slot, reads as equipment. This only touches players who ran with Gear only off and still
    keep such drops in the retention window; INSIGHT-8 checks the slot the client reports. An item
    on Always watch that has no kind (a reagent, a quest item) is recorded as Watched item and
    counted as itself, after every category, never as equipment.
  - **Character.** Insights names a drop's character from the drop, else from its group's recorder,
    so a drop only the group recorded counts under that character. History's Character filter reads
    the drop's recorder alone and calls the same drop Not recorded.
- **The roll popup mark** (Forever port design §7, DW-FP20) is drawn only over Blizzard's four roll
  popups, `GroupLootFrame1..4`. In WoW Forever's gamepad mode the client lists rolls in
  `GamepadGroupLootRollFrame` instead, and the mark is skipped while `InputUtil.IsGamepadUIEnabled()`
  is true. Its `Need so far` line needs the drop to be pending (the Drops tab's own gates, design
  §11.1); a drop those gates refuse is still marked with your verdict, but has no second line. The
  score part of the gain is the score's difference, not a percentage. None of it is confirmed in
  game yet (FOREVER-13 and ROLLS-4).
- **Everyone's rolls** (Forever port design §5, DW-FP13 to DW-FP17) come from the client's loot
  history, `C_LootHistory`, on both clients. When a player's number appears, and whether the history
  fires once per choice or only at the close, is unconfirmed (probes P-R1 and P-R2 in
  [`forever-probes.md`](forever-probes.md)); the Rolling now row's time left reads the roll's
  `startTime` and `duration` on the history's own clock, whose units are probe P-R4's. A trash or
  open-world roll is keyed by whatever encounter the client files it under (P-R3). Nothing of a roll
  is saved across a reload: an open roll comes back from the client (`PLAYER_ENTERING_WORLD`).
- **Master-loot pending** (Forever port design §6, DW-FP18) holds an Epic only when the loot window
  you opened lists it, and whether a raider who is not the master looter sees those slots at all is
  probe P-ML1; if not, nothing is ever held and the drop arrives as a plain receipt when it is given.
  An item is keyed by its corpse and item ID (`sourceGUID:itemID`), so **two copies of one item on
  one corpse collapse to one awaiting item**; the second copy's receipt arrives as a plain drop. On
  Retail the method exists only under Guild Master Loot (design §11.2). The Ask master looter
  button's tooltip names the master looter by the short name the window shows, while the whisper
  goes to the whole `Name-Realm` (on WoW Forever the whole name, which has no realm); the two are
  the same player.
- **WoW Forever** (the Forever port, DW-FP01 to DW-FP21). Mythic+, delves, follower dungeons, Raid
  Finder, scenarios, transmog, upgrade tracks, off-spec, the Encounter Journal pool and the trade
  countdown are absent there by design (`ARCHITECTURE.md` → Per-client features); a bound-on-pickup
  drop is soulbound once looted, so only a bind-on-equip drop is ever tradeable, and the Drops table
  has no Trade window column. Verdicts there are score-first. The class data, the armor level rule,
  the ranged slot, Pawn by talent tree and the names have no recorded client pass yet: the FOREVER
  smoke theme and the probe sheet ([`forever-probes.md`](forever-probes.md)) are the owner's to run.

## The simulator

- **Master loot in the simulator and test mode** (Forever port design §8). `/dw sim ml` plays one
  master-loot drop on demand, but no scenario's timeline has an `ml` step, the status line counts
  rolls and not master-loot items, and test mode has no awaiting-master-looter sample (its Rolling
  now section shows one open roll). Declared out of scope for the port (DW-FP21): the verb drives
  the whole path (the loot method, the loot window, the awaiting item, the ask and the assignment),
  and SIM and FOREVER smoke checks run it.

- **The simulator** (milestone M7) runs end to end: `/dw sim start <scenario> [size]` builds the
  pool and the group, `run` and `step` play the scenario's timeline, and the `SIM` title text, the footer's
  `Simulating` line, the `sim` diagnostics section and the `SIM` debug tag show it (DW-73). Since
  DW-02..DW-04 the session, the timeline's step machine, the `/dw sim` grammar and the step panel
  are LibKa0s-Sim-1.0's (LibKa0s#54); this addon supplies the scenarios, the world, the event
  drivers, the restrictions and eight verbs (`roll` and `ml` since DW-FP17 and DW-FP18), and the panel's position lasts the session only. The
  timeline's steps are event drivers only; the engine computes every verdict, estimate and inspect.
  A key's bosses drop nothing: its loot comes with the completion, as the end-of-run chest's does.
  Since the owner's first run (DW-90, sim feedback §0) a run fills the window under the default
  filters in every scenario: the group wears the content's items 1 to 12 levels above it (so its
  drops are spare for their looters whatever you wear; the M7 band around your own level left a
  group naked of content you outgear, and nothing read as Interesting), each random burst has a
  line of yours and a member's plain loot line, a simulation tracks the situation it simulates
  whatever its row says (PvP and the open-world group are untracked by default), and every step
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
- **The simulator's item kinds** (issue #13) come from the journal's own mounts, pets, toys,
  recipes and tier tokens; a kind the journal lists none of falls back to
  `NS.SimPool.COLLECTIBLE_SAMPLES`, curated ids that ship empty until each is checked in the client
  (COLL-8). Until then `/dw sim drop <kind>` answers that the simulation has no item of that kind,
  and test mode's sample of that kind is another pool item standing in for it.

## Internal readings and the build

- **Which source handed the bare link** in the owner's BUG-1 report (ui spec §0) is not proven
  offline: the headless reproduction shows that a first report without bonus data read the drop at
  its base level and quality, and the fix keeps the most complete link and reads your own drops from
  their bag item whatever the source. ITEM-3 and the `drops` diagnostics line record it in game.
- **The Situations table** (General › When to show's until feedback-24, a Drops tab since item 020; since DW-H0, feedback-8 spec §0) is the tab's own editor
  (`settings/PageEditors.lua`), not a library composer: LibKa0s-Options has no grid composer for
  mixed controls. [LibKa0s#50](https://github.com/tusharsaxena/LibKa0s/issues/50) was rejected at one
  consumer; the table stays the tab's own editor.
- **The Profiles page** builds only where AceDBOptions and AceConfigDialog resolve, which the
  headless mock does not model; PROFILE-1 is its in-game check.
- **The logo** is a placeholder generated for the scaffold; the owner may replace the art
  (regenerate the TGAs with the recipe in `DEPENDENCIES.md`).
