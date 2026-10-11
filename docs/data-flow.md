# Data flow — Ka0s Drop Watcher

## The loot pipeline (design spec §3)

```
 CHAT_MSG_LOOT ─┐                         ┌─> Window (Group drops / My drops / History)
 ENCOUNTER_LOOT ├─> LootParser ─> LootFeed ┼─> DetailCard, OfferPanel, Toast
 LOOT_HISTORY  ─┘                     │    └─> History
   Situations ──gate──────────────────┤
   QualityGate ──gate─────────────────┼─> ItemFacts ─> Evaluate ─> verdicts
                                      │     Roster ─┐      ▲
                                      │     Inspect ┴─> candidate gear/spec
                                      │     Gear (me) ┘
                                      ├─> TradeRules ─> trade estimate
                                      └─> TradeTimer (own bag items)
 Restrictions ──> Messaging queue ──> Compat.ChatSender (pcall)   TradeHelper ──> DropItemOnUnit
```

Modules talk over the `NS.MSG` catalog in `core/Bus.lua`, one sender per message; the UI only
listens. Each stage is drawn in its own section below. The README's `## How the loot watching works`
is the same pipeline told for players.

## A setting changes

```
panel checkbox ─┐
/dw set|lock ───┼─> NS.SchemaRuntime.Set(path, v) ─> store ─> [Set] line ─> row.onChange ─> announce
launcher entry ─┘                                                   │                    │
                                                    Settings.REACTIONS[path]       panel refresh
                                                    (enabled → latch, visibility/scale/alpha/locked
                                                     → Window.ApplySettings)
```

## The window's show decision

`Window.UpdateVisibility` reads one ladder: stood down → hidden; `visibility` says no (never, or the
combat condition fails) → hidden; the player opened it → shown. Turning test mode on opens a closed
window and remembers that it did, and turning it off closes the window again only in that case, so
Close, Toggle and Escape always win over test mode. It runs on every open and close, on test mode,
on both combat edges (`PLAYER_REGEN_DISABLED` / `_ENABLED`, which pass the edge itself rather than
re-reading `UnitAffectingCombat`), on the stand-down and stand-up, and on a profile change. The
frame's `OnShow` and `OnHide`, by whatever path, tell each `Window.AddVisibilityListener` listener
(today the trade timer, which paces its ticker by the window); the window calls no engine module.

## What the window repaints on

```
RestrictionChanged(reason) ─> the badge (`Encounter · n queued`, hidden while reason is nil)
AskStateChanged ───────────> the badge's queued count (NS.Asks.Queued, read); shown: the active
                             tab's body (each row's Ask button)
SituationChanged ──────────> "This instance" starts now; footer, Quality label
DropAdded(id) ─────────────> NS.LootFeed.Get(id) (read); a drop of the feed shown (live, or test
                             mode's while it is on):
                               ├─> hidden, in an auto-open situation: opens it (every drop, your
                               │   own included; no latch; DW-83, FB-12)
                               ├─> minimized: stays minimized, `n new` counts it
                               └─> shown: tabs (`My drops · n`), filter bar, footer, active body
DropUpdated ───────────────> shown: the same repaint
GearChanged ───────────────> shown: the same repaint (the My eq column; DW-83)
InspectDone ───────────────> shown: the footer's inspect freshness
TradeTimerTick ────────────> shown and expanded: the My drops tab while it is active, the Offer
                             panel while it is open; nothing else
TradeTimerExpiring ────────> shown: the whole repaint
footer ticker (5s) ────────> shown and expanded: the footer ("Last loot 12s ago"), then what
                             TradeTimerTick repaints
filter bar / Sort ─────────> NS.WindowFilterBar.Set(tab, key, v) ─> the active tab's body
Scan group ────────────────> NS.ScanGroup ─> NS.Inspect.Scan       (the host handler, not the engine)
Quality ───────────────────> NS.SetQualityMode ─> feed.quality.mode (the next drops)
resize (grip released) ────> the whole repaint (the table's columns take the new width)
minimize ──────────────────> the Offer panel and the Edit message box close; the anchor moves to
                             the top-left corner first, so the title bar stays where it is
```

Every bus repaint above but InspectDone's and the countdowns' is batched: a message marks the window
and one repaint runs on the next frame (`C_Timer.After(0)`), so a burst (test mode's placeholders,
a Scan group's `DropUpdated` per drop) costs one pass. A player's own click repaints at once.

The tab's body (DW-31, DW-33, DW-51) is handed `Window.TabContext(tab)`: its feed (`test` in test
mode), its filter state, the controls it honors, `matches(drop)` and `compare(a, b)`.

## The Group drops table

```
Window.Refresh ─> the group body's refresh(pane, TabContext("group"))
  ├─> WindowGroup.Columns(profile.window.columns)                          (pure; the layout)
  ├─> WindowGroup.Layout(columns, the rows' width)                          (pure)
  ├─> WindowCells.Entries(NS.LootFeed.Groups(feed), NS.LootFeed.Get, ctx,   (pure: groups newest
  │                       NS.State.windowGroup)                              first, filtered, sorted)
  │     each header: the shown drops, every drop the tab lists (ctx.belongs), and the hidden ones with
  │     the control that hid each (ctx.hiddenBy = WindowFilterBar.HiddenBy) ─> WindowCells.Header:
  │     `2 drops · 1 shown`, the tooltip naming each hidden drop and its filter (feedback-2 spec §0);
  │     a group the View hid whole keeps its header, `n drops · 0 shown`; one Search, Content or a
  │     Character choice hid whole is left out (WindowCells.KeepsHeader); your own drops the tab
  │     leaves to My drops (no `feed.showOwn`) and My drops lists (ctx.onMine = WindowMine.ListsNow:
  │     not hidden with Hide nor by My drops' filters) are counted, `· 1 yours on My drops`
  │     (feedback-3 §0, §5); the tab label `My drops · n` counts the same (WindowMine.ListedCount)
  ├─> NS.Pool.ReleaseAll(rows), ReleaseAll(headers) ─> Acquire in order (each row built once)
  └─> each row: NS.WindowCells.Item / Ilvl / Slot / Looter / MyEq / TheirEq / Me / Them / Trade / Ask
                  reads: NS.Gear.Snapshot().equipped (My eq; its icons show your inventory slot's
                  own tooltip), NS.TestMode.InspectOf(drop).gear (Their eq: NS.Inspect.Get(looter guid),
                  or a sample's own entry), NS.TestMode.AskState(drop, NS.Asks.StateOf("ask", …))
                  client: Compat.ItemIcon, Compat.ClassColor, ITEM_QUALITY_COLORS

header click ──> WindowGroup.ToggleGroup ─> State.windowGroup.collapsed ─> repaint
× ─────────────> WindowGroup.Dismiss ─> State.windowGroup.dismissed ─> repaint
Ask ───────────> NS.PressAsk(id) ─> NS.Asks.Press("ask", looter, id) ─> AskStateChanged ─> repaint
item button ───> hover: GameTooltip:SetHyperlink; shift-click: Compat.InsertChatLink;
                 ctrl-click: Compat.DressUpItem; a plain click expands the row
row hover ─────> a cell, button or header: Window.AttachTooltip ("row") ─> GameTooltip:Show() ─>
                 RowTooltip.Place: BOTTOMLEFT at the row's top, outside the window's right edge (else
                 BOTTOMRIGHT outside its left edge); the item button the same (feedback-3 §2, DW-B2)
NS.SetWindowMode ─> SchemaRuntime.Set("window.mode") ─> WindowCompact.OnModeChanged ─> Apply
row click ─────> WindowGroup.ToggleExpand(id) ─> State.windowGroup.expanded ─> repaint
no drop at all > the empty state: Preview with test data ─> NS.SetTestMode(true); Scan group ─> NS.ScanGroup
```

In the compact layout (`WindowGroup.IsCompact()`, compact spec §2) the same refresh computes the
same entries and hands them over instead of drawing the table:

```
WindowGroup refresh ─> CompactGroup.Refresh(pane, entries, compact)   (the table's scroll hidden)
  ├─> CompactGroup.Metrics(WindowRows.FontSize(window.fontSize))     (pure: line, card height, icon)
  ├─> NS.Pool.ReleaseAll(cards), ReleaseAll(headers) ─> Acquire in order (each card built once)
  ├─> each header: WindowGroup.NewHeader, painted with CompactCards.Header (the short form)
  └─> each card: CompactCards.Group(drop, { now, your gear, the looter's gear, WindowGroup.AskState,
                  messages.transmogAsk, Compat.NormalizedRealm }) ─> three lines of pieces
card click ────> WindowGroup.ToggleExpand(id) (the same state) ─> DetailCard.Paint(stacked card)
piece hover ───> Window.AttachTooltip ("row") ─> RowTooltip.Place at the card's top right
switch ────────> the scroll offset carried over (CompactGroup.CarryScroll)
```

## Test mode (design spec §11.6, ui spec §4)

```
Master controls checkbox ─┐
launcher menu entry ──────┼─> NS.SetTestMode(on) (refused stood down, in combat or while a simulation runs)
/dw test, Preview button ─┘     ├─> on:  TestMode.Populate()
                                │          ├─> LootFeed.Clear("test"); State.testHistory = an empty log
                                │          ├─> the Group drops tab's View ─> All (the old value kept)
                                │          └─> SimPool.BuildInto(State.testPool, …)   (the journal at Mythic
                                │                Keystone, your own gear as the fallback; meanwhile the tab
                                │                says "Gathering real items for test mode.")
                                │                └─> ready ─> TestData.Placeholders(GetTime(), you, src)  (pure)
                                │                      ├─> LootFeed.AddTest(spec) each ─> the test feed ─> DropAdded
                                │                      └─> TestData.History(time(), you, src) ─> State.testHistory
                                │                            ─> HistoryChanged (History.Log() answers it while on)
                                ├─> off: TestMode.Clear() ─> the pool's timers canceled, LootFeed.Clear("test"),
                                │          State.testHistory = nil, the View put back
                                └─> Window.OnTestModeChanged ─> the TEST MODE title text and banner, the test feed drawn
PLAYER_REGEN_DISABLED ─> NS.SetTestMode(false) ─> "Test mode ended: you entered combat."
NS.StandDown ─> State.testMode = false; TestMode's stand-down row ─> TestMode.Clear()
Ask, Offer, Announce, Post my tradeables on a sample ─> NS.Asks ─> printed ("Test mode, not sent: …")
```

A placeholder is never judged, re-estimated or inspected: its verdicts, trade, inspect entry
(`testInspect`) and ask state (`testAsk`) are the data's. The ask state shows only while the
messaging edge holds none for it, so a click on Ask moves it like a live row's.

## The simulator (simulator spec §1, §2, §4, §5, §6)

```
NS.Sim.Start(opts) ─> refused (printed): stood down, already running, test mode, combat,
                      an instance, a real group (the real world read through NS.Sim.Live)
                  └─> State.sim = { sim = true, … }; NS.Sim.active = true
every NS.Compat call ─> core/SimSeam.lua's wrap ─> NS.Sim.Answer(name, live, …) while active
                          ├─> a provider (the simulator's invented answer, else the live member)
                          └─> guarded: ChatSender prints "[sim] …"; inspect and trade calls do nothing
NS.Sim.Fire(event, …) ─> every handler NS.FEATURE_EVENTS declares for it, in row order
NS.Sim.SetRestriction(name, on) ─> answered active ─> Fire(ADDON_RESTRICTION_STATE_CHANGED, type, on)
NS.Sim.SetLockdown(on) ─> InChatMessagingLockdown answered ─> NS.Restrictions.Refresh
DropAdded of a drop made while active (rec.sim) ─> History.Log() = the session log, never global.history
NS.Sim.Stop(reason) ─> its timers canceled ─> NS.Asks.CancelQueued (seam still on)
                   ─> NS.Sim.active = false ─> the cleanup steps ─> its restrictions lifted (event)
                   ─> its drops' automatic asks ─> LootFeed.RemoveWhere(sim, context reset)
                   ─> Inspect.Forget(its GUIDs) ─> Roster.Refresh ─> History.ReleaseLog
                   ─> TradeTimer.Scan ─> Situations.Refresh ─> the open window repainted
GROUP_ROSTER_UPDATE, PLAYER_ENTERING_WORLD, ZONE_CHANGED_NEW_AREA ─> OnSimWorldEvent (first)
                   ─> a real group or an instance ─> Stop("group" | "instance")
NS.StandDown ─> Sim's stand-down row (first) ─> Stop("standDown")
NS.SimPool.Build(opts, done) ─> the journal's frame shown? ─> look again every RETRY seconds
                            ─> ReadJournal: save the selection ─> the newest tier's dungeons or raids,
                               every difficulty of the side, under the class filter ─> restore it
                            ─> entries still loading ─> EJ_LOOT_DATA_RECIEVED (settled) ─> read again
                            ─> all loaded or TIMEOUT ─> State.sim.pool (journal), else own gear (fallback)
NS.SimRoster.Create(opts) ─> Members (pure, seeded) ─> Gear per member from the pool's gear entries,
                          each worn at a level inside the band above the content's (ContentLevel: the
                          pool's drops' median; the inspect answers it) ─> NS.Sim.MarkGUID
                          ─> State.sim.members
NS.SimEvents.Join() ─> Fire(GROUP_ROSTER_UPDATE), Fire(PLAYER_ENTERING_WORLD) ─> the roster, the situation
                   and the inspect warm-up read the group and the place NS.SimWorld answers through
                   NS.Compat (core/CompatWorld.lua: the group, a unit, the instance, combat); the
                   simulated situation is tracked whatever its row says (Situations.IsTracking)
NS.SimEvents.Loot(n, who) ─> Plan (pure, seeded) ─> your own drop: NS.SimWorld.AddBagItem (its trade window)
                         ─> WriteLine from LOOT_ITEM* (Compat.GlobalString) ─> Fire(CHAT_MSG_LOOT, …)
                         ─> the real parser ─> the feed ─> BAG_UPDATE_DELAYED (your own) ─> the trade timer
the broker's NotifyInspect (guarded) ─> NS.SimWorld schedules INSPECT_READY(guid) after a seeded delay
                         ─> the broker reads the member's slots and spec (answered until ClearInspectPlayer)
NS.SimEvents.Pull() ─> Fire(ENCOUNTER_START) ─> Combat(true): PLAYER_REGEN_DISABLED + Combat restriction
                   ─> SetRestriction(Encounter, on) ─> an ask now is queued
NS.SimEvents.Kill() ─> Fire(ENCOUNTER_END, …, 1) ─> Combat(false) ─> SetRestriction(Encounter, off)
                   ─> RestrictionChanged (chat allowed) ─> the queue flushes, printed "[sim] …"
NS.SimEvents.RunStart() / RunEnd() ─> CHALLENGE_MODE_START / COMPLETED with the ChallengeMode restriction
NS.SimEvents.Trade(dropID) ─> NS.SimWorld.SetTrade ─> TRADE_SHOW, the item change, TRADE_ACCEPT_UPDATE,
                   TRADE_CLOSED, UI_INFO_MESSAGE ─> History settles received or tradedAway in the session log
/dw sim <verb> ─> NS.SimVerbs.Parse (pure) ─> no simulation running: "No simulation is running" (but start)
/dw sim start <scenario> [size] ─> NS.SimScenario.Start ─> NS.Sim.Start (refusals) ─> Timeline (pure)
                   ─> NS.SimPool.Build ─> ready: SimRoster.Create ─> SimEvents.Join ─> the window opens
/dw sim step ─> NS.SimScenario.Step ─> the next step's driver: RunStart, Pull, SetLockdown(on), Kill,
                   Loot(burst), SetLockdown(off), RunEnd (waits while the pool builds) ─> its chat
                   line (StepLine), typed or played
the loot step and `/dw sim loot` ─> NS.SimReport.Loot: Mark (the feed's receipt sequence and merge
                   count) ─> SimEvents.Loot ─> Collect (the records made since: added, loading or
                   hidden by a gate) ─> kept on the step; Summarize (pure) ─> `loot: 2 drops (1 yours)`
                   in chat and `Loot: 2 drops (1 yours)` on the panel row, TipLines (pure) ─> the
                   row's tooltip: each drop, its looter, its tab or the gate that hid it (feedback-3 §0);
                   each place honors `feed.showOwn` and the feed the window shows (SimReport.View =
                   Window.FeedView + WindowMine.LeftOutNow: yours on Group drops too, not on My drops when its
                   Hide or its own filters leave it out, or not shown in test mode; §5)
/dw sim run ─> a step now, then one every SimScenario.StepDelay() seconds (`sim.stepDelay`, 2 by
                   default, read as each next step is set) on NS.Sim.After (the stop ends it)
/dw sim pause | resume | restart ─> NS.SimScenario.Pause (the timer canceled) | Resume (Run) | Restart
                   (NS.Sim.Stop, then Start with the same scenario and size)
every move of the timeline (start, ready, step, run, pause, the end, the stop) ─> NS.SimScenario.Notify
                   ─> NS.SimPanel.Refresh: Compose (pure) ─> the rows' states, Controls (pure) ─> the buttons
the step panel's row click ─> SimPanel.ClickRow (re-composed) ─> Start: SimVerbs.Run("start …") |
                   a later step: RunTo ─> SimVerbs.Run("step") until it is reached | Stop: SimVerbs.Run("stop")
the panel's Run all, Pause / Resume, Restart, Stop, picker Start ─> SimVerbs.Run(the typed verb)
the SIMULATION title text, the footer's "Simulating: …" and the `sim` diagnostics section read NS.Sim.Status,
                   NS.SimRoster.Get, NS.SimPool.Status and NS.SimScenario.Status
```

The simulator never writes a verdict, a trade estimate or an inspect state: what it invents enters
at the client seam and through the event handlers, and the engine computes the rest. Test mode and
the simulator are exclusive: each refuses while the other is on.

## The detail card

```
the group body's refresh, the open row drawn ─> DetailCard.Paint(card, drop, width, now)
  ├─> DetailCells.Chips(drop)                                   (pure: the header's chips)
  ├─> DetailCells.ForYou(drop, Scoring.InUse())                 (pure)
  ├─> DetailCells.ForLooter(drop, NS.Inspect.Get(guid), Compat.SpecName(specID), now)   (pure)
  ├─> DetailCells.TradeBox(drop, the situation's label)         (pure)
  └─> DetailCells.Actions(drop, { NS.Asks.StateOf("ask", …), the inspect entry,
                                  NS.TradeHelper.CanTradeWith(looter) })                  (pure)

Ask ───────────> NS.PressAsk(id) ─> NS.Asks.Press ─> AskStateChanged ─> repaint
                 (messages.editFirst on, window shown, not queued: ─> DetailCard.OpenEditor(id, "ask"))
Edit message ──> DetailCard.OpenEditor(id) ─> NS.Asks.Preview("ask", looter, id) (nothing sent)
                   Send ─> NS.PressAsk(id, { text = edited }) ─> NS.Asks.Press
Link in chat ──> Compat.InsertChatLink(link)
Retry inspect ─> NS.RetryInspect(id) ─> NS.Inspect.Request(looter guid, PRIORITY.looter)
                   ─> InspectDone ─> LootFeed re-judges ─> DropUpdated ─> repaint
Trade ─────────> NS.TradeWithLooter(id) ─> NS.TradeHelper.Open(looter) (its guards; a refusal printed)
Hide this item ─> WindowGroup.Dismiss(id) ─> State.windowGroup.dismissed, expanded cleared ─> repaint
```

## The My drops tab and the Offer panel

```
Window.Refresh ─> the mine body's refresh(pane, TabContext("mine"))
  ├─> WindowGroup.Layout(WindowMine.COLUMNS, the rows' width)              (pure)
  ├─> WindowMine.Entries(NS.LootFeed.Drops(feed), ctx, NS.State.windowMine) (pure: your own drops,
  │                                                                           filtered, sorted)
  ├─> WindowMine.Rows(Groups, Drops, Get, ctx, NS.State.windowMine) (pure: WindowCells.Entries over
  │     your drops, every group open until toggled; a drop in no group last, with no header)
  ├─> NS.Pool.ReleaseAll(rows, headers) ─> Acquire in order (each built once); each header:
  │     WindowCells.Header(group, shown, now, …): `Instance · Boss · Difficulty · 6m ago · n drops · You`
  ├─> each row: WindowCells.Item / Ilvl, MineCells.ForMe / TradeWindow(drop, now, TradeTimer.WarnAt())
  │             / BestCandidates(drop, revealed) / Actions(drop, best, AnnounceButton(…))
  │               reads: NS.Asks.StateOf("announce", nil, id)
  └─> MineCells.Summary(rows, now) ─> the summary strip; Post my tradeables enabled when any
  └─> then OfferPanel.Refresh() (open: its drop, else nothing)
        ├─> MineCells.DockSide(window left, right, panel width, screen width)   (pure)
        ├─> MineCells.PanelHeader(drop, now, warnAt), MineCells.Candidates(drop)   (pure)
        └─> each candidate: MineCells.OfferButton(NS.Asks.StateOf("offer", member, id)),
                            MineCells.TradeButton(NS.TradeHelper.CanGive(id, member))

Offer ────────────> OfferPanel.Open(id) ─> State.offerPanel.dropId, WindowMine.Reveal(id) ─> repaint
Announce ──────────> NS.PressAnnounce(id) ─> NS.Asks.Press("announce", nil, id) ─> AskStateChanged
Hide ──────────────> WindowMine.Dismiss(id) ─> State.windowMine.dismissed ─> repaint
Post my tradeables ─> NS.PostTradeables() ─> MineCells.PostLines(your tradeable links)
                        ─> NS.Asks.Request("announce", nil, "post:<n>:<i>", { text }) per line
panel Offer ───────> NS.PressOffer(id, member) ─> NS.Asks.Press("offer", member, id) ─> AskStateChanged
panel Trade ───────> NS.GiveDrop(id, member) ─> NS.TradeHelper.Give (its guards; a refusal printed)
Announce to group ─> NS.PressAnnounce(id)
close mark ────────> OfferPanel.Close() ─> State.offerPanel = nil

messages.editFirst on: panel Offer ─> DetailCard.OpenEditor(id, "offer", member), Announce and
Announce to group ─> DetailCard.OpenEditor(id, "announce"); the box's Send ─> NS.PressOffer(id,
member, { text }) / NS.PressAnnounce(id, { text }) ─> NS.Asks.Press(…, { text })
```

## Enable and disable

`enabled = false` → `Lifecycle:Set("disabled", true)` → `NS.StandDown`: feature events unregistered,
tracked bus registrations taken down, test mode ended, each module's teardown, window hidden. The
stand-up re-registers and re-applies the window from current settings. The perf harness's suspend
takes the same latch's `perf` hold.

## The situation

```
six events (PLAYER_ENTERING_WORLD, ZONE_CHANGED_NEW_AREA, CHALLENGE_MODE_START,
            CHALLENGE_MODE_COMPLETED, GROUP_ROSTER_UPDATE, PLAYER_DIFFICULTY_CHANGED)
  └─> DW.OnSituationEvent ─> Situations.Refresh
        ├─> ReadInputs: GetInstanceInfo, IsInInstance, C_ChallengeMode, IsInGroup / IsInRaid,
        │               GetDifficultyInfo (an unknown id reads as nil)
        ├─> Classify (pure) ─> key
        └─> key changed? ─> NS.State.situation ─> SituationChanged (key, previousKey)
```

`IsTracking`, `ShouldAutoOpen` and `QualityOverride` resolve the current key against
`profile.situations.<key>`, falling back to the spec defaults. The stand-down clears the key; the
stand-up re-reads the client and announces where the player is.

## The roster

```
GROUP_ROSTER_UPDATE ─> DW:OnSharedFeatureEvent ─> DW.OnSituationEvent (above), then
  └─> DW.OnRosterEvent ─> Roster.Refresh
        ├─> tokens: raid1..N, or player + party1..N-1, or player alone
        ├─> per token: UnitGUID (secret or missing: skipped), UnitName (secret or Unknown: no
        │              name), UnitClass, UnitIsConnected; same-realm realm from
        │              Compat.NormalizedRealm
        ├─> NS.State.roster = { byGUID, list }, each member's specID carried over
        └─> changed: the change sinks ─> GroupRoster.Grow
              └─> LootFeed.OpenGroup (the live group a drop now would join, if it exists)
                    ─> GroupRoster.Merge(its roster, GroupRoster.Current()) ─> grew:
                    History.GrowRoster (its History group, HistoryChanged) + Window.ScheduleRepaint

Roster.Resolve(GUID | "Name-Realm" | "Name", classFile?)
  ├─> GUID hit, else name (+ realm) match without case, realms normalized
  ├─> a tie: classFile narrows, then (bare name) the player's own realm
  └─> a miss: Refresh once, then try again; still none or still a tie: nil
```

The roster sends no message: a module that needs the fresh group declares `GROUP_ROSTER_UPDATE`
below `modules/Roster.lua` in the TOC and hears it after the roster's handler. The one exception is
the group's roster snapshot (feedback-2 spec §3): `modules/GroupRoster.lua` is told through
`Roster.AddChangeSink`, only when the re-read changed the group. Each feed group also takes the
members with every drop it receives (`GroupRoster.Note`, from the feed's add; a test drop takes its
spec's roster), so the snapshot grows with a mid-run joiner and never shrinks. The stand-down drops
the roster; the stand-up re-reads it.

## The item facts

```
ItemFacts.Get(link) ─> the cache, else ItemFacts.Read(link):
  Compat.GetItemInfo (nil: uncached) ─> name, base ilvl, equipLoc, classID, subClassID, bindType, setID
  ItemRead.QualityOf ─> quality + qualitySource (the client's for the link `item`, else its color `link`)
  ItemRead.EffectiveItemLevel ─> ilvl + ilvlSource (gear: `detailed`, else `base`;
                                 anything else: the detailed level all the same, else the base)
  Compat.GetItemUpgradeInfo ─> track (+ tier)
  Compat.GetItemStats ─> stats                 Compat.GetItemSpecs ─> specs
  Compat.GetItemUniqueness ─> unique           Compat.IsItemBindToAccount* ─> warbound
  Compat.ItemClassRestriction ─> classes, isTierToken
  Compat.PlayerHasTransmog ─> transmogKnown  (CanIMogIt when loaded, else C_TransmogCollection)

ItemFacts.Request(link, cb) ─> facts now ("ready"), else one shared load per link:
  NS.Item.LoadItem(id, retry) ─> retry reads again ─> facts: every waiter called back
                                                  └─> still uncached: LoadItem again, up to 5,
                                                      then every waiter with nil
```

`TRANSMOG_COLLECTION_UPDATED` re-reads `transmogKnown` on the cached facts. The stand-down drops the
cache and the loads; a load that answers after it is ignored.

## The gear snapshot

```
PLAYER_EQUIPMENT_CHANGED ─┐
BAG_UPDATE_DELAYED ───────┼─> Gear.Schedule ─> one 0.5 s timer (later events join it)
PLAYER_SPECIALIZATION_    │                          │
  CHANGED ("player") ─────┤                          v
an item load answering ───┘   Gear.Refresh ─> Gear.Read:
                                UnitClass, Compat.PlayerSpecID ─> classFile, specID
                                ClassData ─> dualWield, titanGrip
                                every slot: Compat.InventoryItemLink ─> ItemFacts.Request
                                  ─> a copy at Compat.InventoryItemLevel (else the facts' ilvl)
                                bags 0-4: Compat.BagSlotCount / BagItemLink ─> ItemFacts.Request
                                  ─> kept when Evaluate.Equippability says "ok"
                                owned: each slot in id order takes the best unplaced item fitting it
                              ─> State.gear; signature moved ─> GearChanged
Gear.Candidate() ─> { classFile, specID, dualWield, titanGrip, gear, owned }   (Evaluate, for you)
Gear.Qualities() ─> { [slot] = quality | false }                             (QualityGate ctx.gear)
```

A link the client has not cached is requested and its slot left out (unknown, not empty); its
arrival arms the same timer. The first read, made lazily by a caller, announces nothing. The
stand-down cancels the timer and drops the snapshot; the stand-up rebuilds it and announces it.

## The loot parser

```
CHAT_MSG_LOOT (text, ..., guid) ─> LootParser.Parse   [Perf bucket `parse`]
  text secret ─> dropped, counted `secret`
  LOOT_ITEM* globals changed (rawequal against the strings the set was built from) ─> Rebuild
  first matching pattern, in order:
    CHANGED_OWN_ITEM, LOOT_ITEM_CREATED_SELF*, CREATED_ITEM* ─> rejected
    self:  bonus, pushed, loot (each *_MULTIPLE first) ─> looter = the player
    other: bonus, pushed, loot (each *_MULTIPLE first) ─> looter = Roster.Resolve(name),
                                                          else the name and the event's GUID
    no match, or a link that is not an item ─> ignored
  ─> { looterName, looterGUID, link, qty, kind, isSelf } ─> every sink (the feed), pcall'd
  ─> State.lootParser: hits, ignored, rejected, secret, the last loot seen
```

The counters are kept for the session, across a stand-down; the stand-down unregisters the event.

## Inspecting a member

```
Inspect.Request(guid, priority) ─> entry still good (fresh or cached, not stale, < 600s)? ─> answer it
  else queue it (looter 1 < offer 2 < warm-up 3, then arrival); a queued job may be raised
Pump (one timer; nothing in flight, not parked, 2.0s since the last NotifyInspect, inspect window shut)
  first job whose gates pass:
    no online unit for the GUID ──── 10s ─> failed (identity)
    CanInspect false or out of range ── 25s ─> outOfRange   (no attempt used)
  every link readable already ─> read now, `cached`            [Perf bucket `inspect.read`]
  else NotifyInspect(unit), 2.5s timeout ─> re-queue once, then failed (timeout)
INSPECT_READY(guid), the job's or any member's ─> 0.15s ─> read slots 1-17   [`inspect.read`]
  incomplete slot ─> retry 0.3s apart, three times, then keep it (reason incomplete)
  ─> entry { status fresh, gear (link + tooltip ilvl per slot), specID, gen+1 } ─> Roster.SetSpec
  ─> ClearInspectPlayer (ours only) ─> the items' facts loaded ─> InspectDone(guid)
NotifyInspect by anyone else (hook) ─> spacing reset; the job in flight re-queued, free
PLAYER_REGEN_DISABLED ─> parked (the job in flight ends or times out); ENABLED ─> resumes
UNIT_INVENTORY_CHANGED(group unit), 5s after the read ─> stale, re-queued as warm-up
GROUP_ROSTER_UPDATE, or PLAYER_ENTERING_WORLD inside an instance ─> 2s ─> Scan, when tracked and idle
Inspect.Candidate(guid) ─> { classFile (roster), specID, hand flags, gear (facts at the read level) }
```

The state is memory only (`State.inspect`) and is dropped by the stand-down, which also cancels
every timer and clears an inspect the broker started.

## The feed

```
CHAT_MSG_LOOT ─> LootParser sink ─> source `chat` (your own `pushed` lines skipped)
ENCOUNTER_LOOT_RECEIVED(encounterID, itemID, link, qty, name, classFile) ─> source `encounter`
LOOT_HISTORY_UPDATE_DROP(encounterID, lootListID) ─> Compat.LootHistoryDrop ─> a winner? once ─> `history`
LootFeed.Add(link, looter, opts) ─> source `manual` (skips the situation gate; opts.test skips every gate)
  every payload secret-guarded; the looter resolved through the roster
LootFeed.Receive   [Perf bucket `feed.add`]
  same item id + same looter (GUID, else name without realm) within 120s, not yet from this source
    ─> merged: sources += source, a learned GUID asks for the inspect,
       the more complete link kept (FeedRecords.PreferredLink: more bonus ids and modifiers, chat's on
       a tie; ui spec §0): a shown drop re-reads its facts (LootFeed.Refresh), a loading one loads the
       new link, a hidden one runs the gates again ─> DropUpdated(id, "source")
  else a new drop, its group fixed now:
    keystone run (until 120s after CHALLENGE_MODE_COMPLETED) ─> the run's group
    else the encounter it names, else the encounter in progress or killed < 120s ago
    else the area's group (instance name or "Open world")
  Situations.IsTracking(situation)? no ─> hidden `notTracking` (nothing loaded, no inspect)
  ItemFacts.Request ─> loading? wait for the load, then go on
  FeedFilter.Filter (heirloom, cosmetic, tokens, gear only, minimum item level) ─> hidden with its reason
  Evaluate(facts, your candidate)                       [Perf bucket `evaluate`]   ─> drop.me
    (opts.scorer = Scoring.Scorer(): Pawn, your weights or none, read per judgment)
  QualityGate.Passes(quality, mode, { gear, baseline slot, your verdict })   [`quality.gate`]
    ─> hidden `quality` (one FEED line with the reason, one QUAL line with the threshold), before any inspect
  someone else's drop: Inspect.Request(looter, looter priority)
      ─> Evaluate(facts, Inspect.Candidate(looter)) once read ─> drop.them
      ─> TradeRules.Estimate(bind facts + bonus roll, drop.them, situation rule) ─> drop.trade
  your own drop:  TradeRules.Estimate(…, drop.me) ─> drop.trade
      ─> every other member: Evaluate when their read exists, else checking / unavailable
         (their inspects asked for at offer priority while the trade is not `no`)
  ─> State.feed.live (200 drops, oldest out) ─> DropAdded(id)
InspectDone(guid) ─> that looter's drops and your drops' candidate re-judged ─> DropUpdated(id, "inspect")
GearChanged ─> you re-judged on every drop (and your drops' trade) ─> DropUpdated(id, "gear")
TradeTimerTick ─> LootFeed.ReadBagItems: each own drop the timer matched, read from its bag item
    (the bag item's link when more complete; ItemRead.ItemLevelAt / QualityAt, exact, laid over the
    cached facts as `current` / `location`) ─> re-judged ─> DropUpdated(id, "bag") when it moved
a scorer answering "pending" ─> one shared 1s timer, five tries per drop ─> DropUpdated(id, "score")
ENCOUNTER_START / ENCOUNTER_END, CHALLENGE_MODE_START / COMPLETED ─> the grouping context
```

The stand-down unregisters the events and the bus receivers, cancels the score timer, and drops the
dedupe window, the context and any drop still loading; the recorded drops are kept for the session.

## Your own drops' trade timer (design spec §7.4)

```
BAG_UPDATE_DELAYED / LOOT_CLOSED / DropAdded(id) for your own drop
  ─> TradeTimer.Schedule (one scan per 2s; the asks inside share it)
  ─> TradeTimer.Scan: your own live drops (never test drops)
      ─> each bag item matched to a drop: the exact link first, then its identity (item id and
         bonus ids: ItemRead.IdentityKey), then the item id; one item per drop
      ─> NS.Compat.TradeTimeRemaining(bag, slot): the TradeTimeRemaining line, or the
         BIND_TRADE_TIME_REMAINING sentence decoded with the duration globals
      ─> State.tradeTimer.timers[itemGUID] = { dropID, expiresAt | expired, warned }
      ─> an item that left the bags drops its entry
  ─> warn: remaining <= trade.warnAt (600s), once per item
         ─> TradeTimerExpiring(dropID, guid, remaining) and one chat line
  ─> TradeTimerTick
  ─> the shared ticker retuned: 1s while the window is shown, 60s while it is hidden, off with
     nothing live; each tick expires, warns and sends TradeTimerTick
Window OnShow / OnHide (NS.Window.AddVisibilityListener) ─> the ticker retuned
```

The stand-down cancels the ticker and the pending scan and keeps the entries (their warned flags
with them); the stand-up scans again.

## Handing your drop over (design spec §4)

```
a click (My drops tab / Offer panel, DW-33)
  ─> TradeHelper.Give(dropID, target)            TradeHelper.Open(target)
      ─> the guards, in order: stoodDown, combat (Restrictions.CanTrade), noTarget
         (Roster.Resolve: a GUID, Name-Realm or Name), self, offline, range (Compat.InTradeRange)
      ─> TradeTimer.ForDrop(dropID): notInBags / expired
      ─> FindBagSlot(guid): the entry's slot, then every bag (Compat.GetBagItemGUID)
      ─> cursorBusy (Compat.CursorHasItem)
      ─> Compat.PickupBagItem ─> Compat.DropItemOnUnit(member.unit)    ─> Compat.InitiateTrade
         (no drop API: Compat.ClearCursor, noApi)
  <─ ok, or false and the reason; ReasonText(reason) is the button's tooltip
```

Nothing is sent on the bus; the trade itself is the client's. Stood down, every call refuses with
`stoodDown`.

## Asking, offering and announcing (design spec §9.2-§9.3)

```
a click (row button, Offer panel, DW-33) or auto-ask (DW-54)
  ─> Asks.Request(kind, target, dropID, opts)       Asks.Press: a queued ask is canceled instead
      ─> stoodDown: refused disabled
      ─> recipient: an announce is "group"; a test drop or test mode takes the name as given;
         else Roster.Resolve ─> notInGroup / self / offline, or the member's Name-Realm
      ─> tokens from the drop: item, ilvl, slot, track, gain (the looter's, or the candidate's
         for an offer), mygain (yours); into an empty slot a gain is the words `an empty-slot upgrade`;
         opts.ctx laid over them, opts.text replaces the template
      ─> Messaging.Request (pure): alreadyAsked / tooLong / badRequest, or queue, or send
         canSend = test or Restrictions.CanSendChat()
  queue ─> AskStateChanged(dropID, "queued", kind, target)
  send  ─> pcall(Compat.ChatSender(), text, "WHISPER", nil, Name-Realm)
           (announce: INSTANCE_CHAT, else RAID, else PARTY; noChannel outside a group)
           test: NS.Print("Test mode, not sent: ...") instead
        ─> Messaging.MarkSent, "Whispered Name: [item]"      or Messaging.MarkFailed(reason)
        ─> AskStateChanged(dropID, "sent" | "failed", kind, target, reason)

RestrictionChanged(reason, canSendChat = true) ─┐
ENCOUNTER_END ─> Restrictions.Refresh ──────────┼─> Asks.Flush(trigger)
CHALLENGE_MODE_COMPLETED ─> Restrictions.Refresh┘     Messaging.ShouldFlush ─> one ask now, then one
                                                      every 1.5s (C_Timer); stops while chat is
                                                      restricted again
GROUP_ROSTER_UPDATE (after the roster re-read) ─> Asks.OnRosterChanged
  ─> Messaging.CancelTarget for each member who left (and "group" outside a group)
  ─> AskStateChanged(dropID, "ready", kind, target, "left")
```

The stand-down cancels the flush timer and drops the queued asks; the sent registry is kept.

## The history

```
DropAdded(id) ─────────> History.OnDropAdded ─> Snapshot(rec, time()) ─> Record(global.history,
                          (live drops only)        group = feed group @ session; Trim: 50 a group,
                                                   CEILING 5,000 drops in all, the oldest first)
first PLAYER_ENTERING_WORLD, or the stand-up after a disabled start
                          ─> 5s (canceled by the stand-down) ─> HistoryRetention.LoginPrune:
                          groups whose newest entry is older than retentionDays ─> HistoryChanged
Keep history for row ─> HistoryRetention.OnChanged ─> deletes nothing: taken | deletes: StaticPopup
                          ─> Yes: PruneAll (account + shown session log) | No: the agreed value back
                          (HistoryRetention.Answer: only the latest pending choice; a later change
                          retires the open popup)
DropUpdated(id) ───────> History.OnDropUpdated ─> Refresh: verdicts, trade; `no expired` ─> expired
                          (HistoryChanged only when the entry changed)
AskStateChanged(sent) ─> History.OnAskState ───> asked (ask) / offered (offer, announce)
TRADE_SHOW ─> partner, items ─> *_ITEM_CHANGED (re-read, accept off) ─> TRADE_ACCEPT_UPDATE(either
          side 1: the offer) ─> UI_INFO_MESSAGE "Trade complete." (before TRADE_CLOSED, or within
          5s after it) ─> MatchTrade(offer): got ─> received, gave ─> tradedAway
          TRADE_CLOSED alone ─> nothing (a cancel or a failed trade)
row right-click ─> Compat.ContextMenu ─> History.SetEntryDeclined
Clear history ─> StaticPopup ─> History.Clear
every change ─> HistoryChanged ─> WindowHistory ─> Window.ScheduleRepaint: one pass next frame,
                                   shared with DropUpdated's
                                   (the History tab; a received drop's Ask reads Traded)
```

The History tab's body reads `NS.History.Groups()` (oldest first) through the pure
`WindowHistory.Entries`, filtered by the tab's state with This instance and This session turned
into `time()` marks (`WindowHistory.Context`); each entry is painted with the Group drops table's
cell composers over a drop-shaped copy (`WindowHistory.AsDrop`).

## The toast

```
DropAdded(id) / DropUpdated(id) ─> Toast.Consider: toast.enabled? not toasted yet?
    ─> Qualifies(rec, toast.minGain): not yours, me = upgrade by >= minGain (or into an empty
       slot, whatever minGain), trade likely / yes
    ─> queue (newest 5) ─> Pump: nothing on screen, not held (combat without toast.inCombat)
    ─> next still wanted (in the feed, qualifying, not asked) ─> show: Compose, sound?
    ─> C_Timer toast.duration (none for a test drop) ─> Dismiss ─> Pump
hover ─> Pause (seconds left kept)      leave ─> Resume
PLAYER_REGEN_DISABLED ─> the shown toast back to the queue's head   PLAYER_REGEN_ENABLED ─> Pump
Ask ─> NS.PressAsk(id) (a drop already gone: the toast goes, nothing asked)
AskStateChanged / DropUpdated of the shown drop ─> repaint Ask
LootFeed.Clear / the cap's trim ─> removal sink ─> Toast.Prune: gone drops leave the queue, a gone
    shown drop's toast goes ─> Pump
NS.DismissDrop(id) (row ×, card Hide) ─> Toast.Forget(id): out of the queue, off the screen
toast.enabled off (the row's reaction) / a profile with it off ─> the toast goes, the queue empties
drag (test mode only) ─> profile.toast.point     Reset position ─> Toast.ResetPosition
```

## Auto-ask (design spec §9.4)

```
DropAdded(id) / DropUpdated(id) ─> AutoAsk.Consider: messages.autoAsk.enabled? not considered yet?
    ─> Toast.Qualifies(rec, autoAsk.minGain), the looter known, the ask still ready, not received,
       recorded after auto-ask was turned on ─> pending (one C_Timer each)
    ─> due = DueAt(drop, last ENCOUNTER_END, autoAsk.delay)   (held while an encounter is in progress)
ENCOUNTER_START ─> timers stopped        ENCOUNTER_END ─> every waiting ask due delay after now
PLAYER_ENTERING_WORLD / ZONE_CHANGED_NEW_AREA, held, no Encounter restriction ─> as ENCOUNTER_END
due ─> AutoAsk.Fire: checked again (on, in the feed, qualifying, never asked, not received, looter in
       the group) ─> Asks.Request("ask", looter, id)   (guard, queue under a restriction, send, confirm)
cancel: AskStateChanged(id, _, "ask") (you asked)   GROUP_ROSTER_UPDATE (looter left)
        NS.DismissDrop(id) (row ×, card Hide)        HistoryChanged + received
        the row turned off                           the stand-down
first turned on ─> one-time notice ─> global.notices.autoAsk = true
```
