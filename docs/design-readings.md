# Design readings — Ka0s Drop Watcher

How the code reads the cases the design spec
([`superpowers/specs/2026-10-10-drop-watcher-v1-design.md`](superpowers/specs/2026-10-10-drop-watcher-v1-design.md))
leaves open, module by module, in the order a drop travels: the kernels, the edges, the feed, the
sends, then the window. Each reading is pinned by the module's suite (see [`testing.md`](testing.md)); what
only the client can confirm is named by its smoke-check id ([`smoke-tests.md`](smoke-tests.md)). The
limitations that follow from these readings are summarized in `ARCHITECTURE.md` → Known Limitations.

## The verdict kernel

The verdict kernel (`modules/Evaluate.lua`) reads a few cases the design leaves open as
follows. With the spec unknown, an item whose primary stat suits only some of the class's specs
is `unknown`, not `ok`. With a score, the verdict follows spec §5.2 step 4 to the letter: only
an ilvl and a score that agree in sign give that sign, so one inside its band and the other
outside is a sidegrade (`scoreDisagrees`); the band is in item levels, so the score's band is 0.
A candidate whose class is not known yet is `unknown` (`unknownClass`), even for a
class-restricted item. The track delta orders tracks by a numeric `tier` from ItemFacts and
falls back to the enUS track names, so a localized name with no tier leaves it unset. Bows
(`INVTYPE_RANGED`) and guns, crossbows and wands (`INVTYPE_RANGEDRIGHT`) fill both hands, so the
off-hand and one-hander plans compare against them as two-handers; a ranged drop compares like a
two-hander for hunters and against the main hand for everyone else. A unique-equipped drop at
its category's maximum compares against the lowest holder in its own slots when one of them
holds the category, else the lowest holder anywhere.

## Scoring

Scoring (DW-50, `modules/Scoring.lua`) settles how it reads design spec §5.4. The adapter in use
can differ from `comparison.scorer`: `auto` takes Pawn once it has **initialized**
(`PawnIsInitialized`, spec §5.4; a Pawn that is loaded but not yet initialized does not count, so
your weights are not displaced while it starts, DW-62), else your weights when any spec has one,
else none; `pawn` with Pawn absent or not yet initialized is none, and `weights` with no weight set is none. The
diagnostics' Scoring section prints both (`scorer=` and `inUse=`). For you, Pawn's "best visible
scale" is the one with the highest `PercentUpgrade` for the drop, else your spec's scale when the
drop upgrades nothing; the drop and its baseline are both valued on that scale
(`PawnGetSingleValueFromItem`), so `scoreDelta` is a value difference, not Pawn's percent. For a
looter it is `PawnFindScaleForSpec(classID, specID)`; with no scale for that spec there is no
score (item level alone), not a pending one. The kernel hands every scorer the drop beside the
item it values (`scorer(facts, candidate, drop)`). Weights are per spec and apply to anyone of
that spec, a looter included; a spec without weights is not scored. The Pawn scale string import
(the Weights tab's box) replaces the weights of the spec on screen, whatever `Class=` and `Spec=`
the string carries; Pawn keys it does not score (`Dps`, `Armor`, the `Is*` and socket keys) are
named in the chat line and left out, and a stored weight on a stat key it does not know counts 0,
logged once per key under `SCORE`.

## The minimum-quality gate

The minimum-quality gate (`modules/QualityGate.lua`) reads three cases the design leaves open.
A drop whose quality cannot be read passes (`qualityUnknown`), so the feed never hides what it
could not judge. With no baseline slot yet, `Dynamic per slot` takes the lowest quality across
the drop's slot plan, and the floor when any of those slots is empty. A per-situation `quality`
that names no mode (absent, `global` or unknown) means the global mode.

## The situation classifier

The situation classifier (`modules/Situations.lua`) confirms a difficulty id with
`GetDifficultyInfo` before trusting it, so a retired id falls back to the instance type (a party
instance reads as `dungeon`). It reads three cases the design leaves open: an instance of a type
the design does not name (a housing interior, say) is the open world (`solo` or
`openWorldGroup`); the Mythic Keystone difficulty is `mythicPlus` even before
`IsChallengeModeActive` turns true; and the delve and follower-dungeon inputs come from the
difficulty id. The check lives in the module's edge (`GetDifficultyInfo` is not version-variant).
The per-situation settings are the `situations.<key>.*` rows, read through `NS.Setting`. The
settings page drew them as one block per situation under its name (the plan's fallback for the
design's grid). **Superseded by feedback-8 (2026-10-13)** (feedback-8 spec §0, DW-H0): General › When
to show draws them as one table, a line per situation (Situation, Track, Auto-open, Quality), in Ka0s
Loot History's Price sources look; the rows are `skipRender` and the table writes through the seam
(docs/settings-panel.md).

## The class tables

The class tables (`core/ClassData.lua`) are a fallback for a candidate whose spec is not known
yet; an item's own spec list wins whenever it exists. Devourer Demon Hunter (spec 1480, from the
client's trait-tree data) is recorded as an Intellect dual wielder that takes no held off hand,
which is unconfirmed in game (FEED-7).

## The trade estimator

The trade estimator (`modules/TradeRules.lua`) reads four cases the design leaves open. The
looter check compares item levels (the evaluation's `ilvlDelta`), not the scored verdict, because
the game's rule is item level; an equal item level is not an upgrade, a drop the looter cannot use
is still judged on item level, and an empty slot on the looter is an upgrade for them. The trade
window's expiry is checked after the bind and legacy checks and before the looter check, so a
drop past its window is `no expired` whatever the looter's gear; a BoE never expires. BoE means
`OnEquip` or `OnUse`, and the account binds count as warbound. An unknown situation takes the
`personal` rule. The rule is item level against the looter's equipped gear only; whether the
game also counts their bags is TRADE-4. The raid rule is `personal` until TRADE-3 confirms it; the
`trade.rules.<situation>` rows default to the design's rule for each situation.

## The messaging core

The messaging core (`modules/Messaging.lua`) reads five cases the design leaves open. A known
token with no value reads `?` rather than an empty gap, and the preview lists it as missing;
token names are case-sensitive, so `{Player}` is unknown and left as it is. A gain prints with
one decimal at most. A gain into an empty slot has no item-level change, so it reads as the words
`an empty-slot upgrade` (`modules/Asks.lua`), and a `+` right before a token whose value is words
is dropped, so the default `It'd be +{mygain} for me` reads `It'd be an empty-slot upgrade for
me` (M6 review). The length limit counts the raw bytes, so an item link counts whole. An
ask that is queued, or handed to the sender and not yet reported, is never asked twice, even
with `messages.oneAsk` off; a failed one may be retried, and a canceled one leaves the registry,
so its button is ready again. The `messages.*` settings are rows, read by the edge through
`NS.Setting`.

## The restriction tracker

The restriction tracker (`modules/Restrictions.lua`) reads four cases the design leaves open.
Chat is stopped by the Encounter, ChallengeMode, PvPMatch and Chat restriction types and by the
chat lockdown; combat alone stops inspects and trades, not chat; the Map type, active for the
whole of a dungeon, stops nothing; a type the client adds later is reported under its enum name
and stops nothing. A type counts as active while the event's last word on it or the client's own
answer says so, so a lift counts only once both agree. The badge's reason is the first in effect
of encounter, challengeMode, pvpMatch, chat, chatLockdown, combat. Which types really stop a
whisper is COMBAT-2.

## The roster

The roster (`modules/Roster.lua`) reads five cases the design leaves open. A bare name is the
player's own realm's when that settles it, because chat names a same-realm player without a
realm; the classFile narrows a same-name tie first; a tie neither settles resolves to nothing.
Names and realms compare without case, and realms with spaces and hyphens dropped on both sides.
A unit with a secret or missing GUID is left out, a secret name leaves the member reachable by
GUID only, the client's `Unknown` placeholder counts as no name, and a secret online flag reads
as online. A failed resolve re-reads the client once. In a raid the player's token is its
`raidN`, with `isPlayer` set. The specID is written by the inspect broker (DW-26) through
`SetSpec` and kept across re-reads while the GUID stays. Whether chat's realm spelling matches
the normalized one is ROSTER-1.

## The item facts

The item facts (`modules/ItemFacts.lua`) read six cases the design leaves open. A track's tier
comes from its `trackStringID` through `C.TRACK_TIER_BY_STRING_ID`, which stays empty until
FEED-5 records the client's ids, so today every tier comes from the enUS track name and a
localized client leaves the track delta unset. A tier token is an item that names its classes
and has no slot plan; which slot it makes is not read, so its verdict is `unknown` for the slot
until the tier-token follow-up (spec §14). An item unique on its own takes `item:<itemID>` as
its category. `warbound` is set for warbound and for warbound-until-equipped items alike, with
`warboundUntilEquip` telling them apart. Rings, necks and trinkets carry no `transmogKnown`.
The cache holds 512 links; when it would pass that, the least recently used quarter is dropped
(`NS.ItemFacts.EVICT_SHARE`; a hit or a store marks a link used), so the gear read on every
judgment stays and old drops go; an item that has not
loaded after five `LoadItem` calls (about two seconds) is given up, with nil to every waiter, and
the next request starts afresh. The bonus-roll flag is the loot line's, so the drop record (DW-27)
carries it, not the cached facts. Whether `GetItemUpgradeInfo` answers for another player's link
is FEED-5; the item readers' shapes are ITEM-1.

## The gear snapshot

The gear snapshot (`modules/Gear.lua`) reads five cases the design leaves open. "Best owned per
slot" is a per-slot best, not a loadout planner: the slots fill in id order, each with the
highest-level item that fits it and is not placed already, so a pair holds your best two and one
item never fills two slots, but unique-equipped limits and a two-hander's claim on both hands are
not weighed. A one-hander may fill the off hand only for a dual wielder, a two-hander only with
Titan's Grip; with the spec unknown, the class answers when every spec agrees, else neither. Only
the backpack and the four bags are read: not the reagent bag, the bank or the warband bank. A
worn item's level is its tooltip's (scaling included), else its link's. A link the client has
not cached leaves its slot out (unknown, not empty) until it arrives; an item given up on stays
out until the next gear event. Whether the tooltip level matches the character sheet is GEAR-1.

## The loot parser

The loot parser (`modules/LootParser.lua`) hands each receipt to the feed's sink, and a parsed
line also shows as a `PARSE` debug line and in the diagnostics `feed` section. It reads `CHAT_MSG_LOOT` alone: the encounter and loot-history events are the feed's.
Roll lines ("selected Need", "won") are not receipts and are ignored, since the item arrives on
its own receipt line. A looter the roster cannot place takes the event's twelfth argument as
its GUID, which is assumed to be the looter's (FEED-1 confirms it). The `|4` and `|1` grammar
tokens are not expanded in loot patterns; no `LOOT_ITEM*` string is known to carry one in the
client languages the design names (LOC-1). Whether the line is readable, or arrives secret,
mid-encounter is COMBAT-1; a secret line is counted and dropped.

## The inspect broker

The inspect broker (`modules/Inspect.lua`) reads nine cases the design leaves open. `fresh` is a
read after an `INSPECT_READY` (ours or anyone's) and `cached` one taken at once because the
client already held every link (the fast path, which needs no incomplete slot and an item in each
slot only inspect data shows: neck, both rings and both trinkets, `NS.Inspect.HIDDEN_SLOTS`);
both are good for 600 seconds. A read after `INSPECT_READY` that finds no item at all, or whose
unit token no longer names the GUID, is no data (the inspect was cleared before the read, by
Blizzard's inspect window or another addon): it is retried like an incomplete one, then never
stored; the job in flight is re-queued like a timeout (`failed (empty)` once its sends are used),
and an unasked read is dropped with the entry left as it was. `READY_ATTEMPTS` is two sends in all, so one
retry. `CanInspect` answering false waits the range wait, as being out of range does; an
offline member or a GUID with no unit waits the identity wait. A slot is incomplete when the
client knows its item id but answers no link, or a nameless one; after three retries the read is
kept, the slot left out and the entry's reason `incomplete`. A foreign `NotifyInspect` re-queues
the job in flight at no cost in attempts, unless its data has already arrived. An
`UNIT_INVENTORY_CHANGED` within five seconds of a read is taken for the inspect's own echo and
ignored. The waits and the spacing are module constants (`NS.Inspect.SPACING` and its siblings):
spec §12.1 has no `inspect` setting. The queue's priority is the caller's to give: the feed
(DW-27) asks for looters and the Offer panel (DW-33) for its candidates; `Scan` is the window's
Scan group button (DW-30, through `NS.ScanGroup`) and `/dw scan` (DW-42). Whether the fast path, the spec read and the tooltip level hold
for an inspected unit in game is INSPECT-1..4.

## The feed

The feed (`modules/LootFeed.lua`) settles ten cases the design leaves open. Reports of one drop
merge for 120 seconds (`NS.LootFeed.DEDUPE_WINDOW`) when the item id and the looter match (the
GUID, or the name without its realm when a source has no GUID) and the source has not reported
it already, so two copies from one source stay two drops. An encounter's group stays open 120
seconds after a kill (`LOOT_GRACE`) and none after a wipe; a keystone run's group takes every
drop until 120 seconds after it completes, the chest included (whether the chest's
`ENCOUNTER_LOOT_RECEIVED` names an encounter is FEED-6). Your own `pushed` lines (quest rewards,
containers, purchases) are not drops; a member's are. The relative minimum item level is measured
against your average equipped level. A drop once shown stays shown: updates re-judge its verdicts
and its trade, never its gates. Your own drop's candidates are inspected (at the Offer panel's
priority) only while its trade estimate is not `no`, and asked for when it moves off `no`. The
trade estimate is made again over time: one shared ticker every 30 seconds
(`NS.LootFeed.TRADE_SWEEP`), alive while a group drop's trade is not `no`, turns a drop past its
rule's window `no expired`, and each `TradeTimerTick` re-estimates your own drops, whose estimate
folds in the trade timer (`LootFeed.FoldTimer`: `yes` with the `timer` basis and `expiresAt`
while the countdown is live, `no expired` once it is gone; a bind answer and a BoE entry keep the
rule's). A moved estimate sends `DropUpdated(id, "trade")`. A pending score is retried five times, one
second apart, on one shared timer, and a drop that used them up keeps its answer. Each feed keeps
200 drops (`MAX_DROPS`), the oldest dropped first; the stand-down keeps the drops and drops the
dedupe window, the encounter context and any item still loading. The feed reads its settings,
the `feed.*`, `comparison.*` and `trade.rules.*` rows, through `NS.Setting` (`LootFeed.Config`).
`/dw add` (DW-42) and `/dw offer` for a bag item the feed never saw reach it through `NS.LootFeed.Add`; `/dw clear` empties the live feed (`NS.LootFeed.Clear`).

## The trade timer

The trade timer (`modules/TradeTimer.lua`) settles eight cases the design leaves open. A bag item
is matched to one of your drops by its exact link first and its item id second, each drop taking
one item, so two copies of one drop each keep their own timer; test drops are never timed. A
BoE drop (its item facts' bind in `C.TRADE_BOE_BIND`) never carries a trade-time line and has no
window: its entry is `permanent`, never expired and never live, and the trade helper gives it. A
matched bind-on-pickup item whose tooltip has no trade-time line is `no expired` at once, so an item whose
tooltip has not loaded yet reads as expired until the next scan (a later bag event) reads the
line. The tooltip shows whole minutes, so a re-read within a minute of the stored expiry keeps
it and the countdown does not jump at each scan. An item that leaves the bags (traded, sold, equipped) drops its entry. The ticker runs
only while an entry is live: each second while the window is shown, each minute while it is
hidden, so the warning may come up to a minute late with the window closed. An item first read
with less than `trade.warnAt` left warns at once; `trade.warnAt` 0 turns the warning off, and it
is read through `NS.Setting` (600 by default). The stand-down keeps the entries, warned flags included, so
enabling again never repeats a warning.

## The trade helper

The trade helper (`modules/TradeHelper.lua`) settles five cases the design leaves open. The target
is a member's GUID, `Name-Realm` or bare name, resolved through the roster, so a stranger is
refused (`noTarget`) rather than traded with. The item is found by the trade timer's entry for the
drop, so a drop the timer has not matched is `notInBags` and one it read as `no expired` is
`expired`, never attempted; the entry's last slot is tried first and a walk of the bags second, so
an item moved since the last scan is still found. A busy cursor refuses (`cursorBusy`) instead of
being cleared, and a pickup with no `DropItemOnUnit` to follow is put back with `ClearCursor`.
`CanGive` and `CanTradeWith` run every guard without acting, for the buttons' disabled state and
tooltip (`ReasonText`). Only the calls that act count towards the diagnostics line.

**Superseded by feedback-7 (2026-10-13)** (feedback-7 spec §0): with the Offer panel's Trade button gone,
the give path is removed: `Give`, `CanGive`, `FindBagSlot`, the `notInBags`, `expired` and `cursorBusy`
reasons, `NS.GiveDrop` and the Compat wrappers only it used (`PickupBagItem`, `DropItemOnUnit`,
`CursorHasItem`, `ClearCursor`). The helper keeps `Open` (the detail card's Trade) and `CanTradeWith`, and
its diagnostics line counts opens and refusals only. The reading above stands as history.

## The messaging edge

The messaging edge (`modules/Asks.lua`) reads six cases the design leaves open. Design spec §4
puts the core and the edge in one file; they are two, so the core stays pure and its suite needs
no client. An ask is refused before the core when its recipient is not in the group, is you, or
is offline (`notInGroup`, `self`, `offline`); the registry files a whisper under the member's
Name-Realm, and an announce under `group`, one per drop whatever the channel. A raise inside the
sender is the failure's reason (a secret or empty one reads `error`); no sender is `noApi`, and an
announce outside a group `noChannel`. The first queued ask goes at once when a flush starts and
the rest every 1.5 seconds; a restriction back mid-flush stops it until the next trigger. Test
mode, and a test drop, print the text instead of sending, mark the ask sent and never queue it.
The stand-down drops the queued asks, because no trigger reaches them while down; the sent
registry is kept for the session. The `asked` history outcome (`offered` for an offer or announce) is
written by History (`modules/History.lua`) from `AskStateChanged`. The edit-first box is the detail card's Edit message (DW-32): it reads
`Preview` (the template filled in, nothing sent or filed) and passes the edited text in; with
`messages.editFirst` on, the Offer panel's Offer and Announce open it too. Whether a whisper really is blocked during an encounter is ASK-4.

## The transmog-known flag

The transmog-known flag (DW-53) settles how it reads design spec §4. Whether you have collected a
drop's look is CanIMogIt's `PlayerKnowsTransmog` when that optional addon is loaded (the look
known from any source; an item it calls not transmogable has no flag), else
`C_TransmogCollection.PlayerHasTransmogByItemInfo`; every CanIMogIt call is in `pcall` and an answer
that is not a boolean falls back to the client. The detail card's header shows `New look` or `Look
known`; an item with no look (a ring, neck or trinket) or an unknown answer shows no chip. The For
transmog ask is opt-in (`messages.transmogAsk`, off): with it on, the Ask button is also offered
on a drop that is no gain for you (not an upgrade or a sidegrade) whose look is known to be
missing (`false`, never `nil`), and not on one its looter can't trade. It is still an `ask`: the
same one-ask key, history outcome and button, filled from `messages.templates.transmog`. A gain
always takes the plain ask, the toast (upgrades only) never offers it and auto-ask (DW-54) never
sends it. Whether your class can collect that look at all (its armor type) is not checked beyond
what CanIMogIt's answer carries (TMOG-1).

## The history

The history (DW-51, `modules/History.lua` and the History tab, `modules/WindowHistory.lua`)
settles eight cases design spec §10 leaves open. **What is kept** is every live drop the feed
shows (it passed the gates), never a test drop, never a hidden one, with its verdicts and trade
estimate as last judged while it was in the feed; a group is one feed group of one session, so a
boss killed again tomorrow is a new group. **Outcomes** move forward only (seen, then asked or
offered, then expired, then received or traded away); an announce counts as `offered`; `declined`
is the player's and an automatic move never undoes it, but a completed trade does. **Which entry**
a live drop is lives in a session-only index, because drop ids restart each session, so after a
reload the old entries take no more outcomes from asks or the trade estimate; a completed trade
still matches them by item id. **A completed trade** is the client's "Trade complete."
(`UI_INFO_MESSAGE` with `LE_GAME_ERR_TRADE_COMPLETE`, the pattern RCLootCouncil and TradeLog use),
before `TRADE_CLOSED` or within 5 seconds after it; `TRADE_CLOSED` alone, even after both sides
accepted, is a cancel or a failure (out of range, a full bag) and completes nothing. The items are
read on every change and kept as the offer at every `TRADE_ACCEPT_UPDATE` with either side
accepted, because the second accept can complete the trade with no both-accepted update and the
window is empty by the end; an item change makes both sides accept again, so the last offer is the
one traded. The message's order against the close is HIST-1. **The match** for an item you got is the newest drop of that
item id that is someone else's and not yet received, the partner's own drop first; for an item you
gave, your own drop of that id; one entry per item. **The keeping** is by age (Keep history for,
feedback-2 spec §5): a group whose newest entry is older than the window goes, once per session and
when the window shrinks (after a confirmation when that deletes anything), with 50 drops per group
and a safety ceiling of 5,000 drops in all, the oldest first. **The tab** opens on View: All and Content: All
the first time each session (Content's This session and This instance then cut by time, and
`n days ago` names an older group); it is read-only but for the row menu (right-click: Mark as
declined or Clear declined, through the client's `MenuUtil`, or at once without it), and Clear
history asks first (a StaticPopup), then empties the log on every character and keeps the window.
**Account-wide:** one log for all your characters, as the Keep history for row says. That the log survives a
reload and the row menu opens in game is HIST-2.

## The toast

The toast (DW-52, `modules/Toast.lua`) settles what design spec §11.5 leaves open. **The gain**
is the item-level change for you (`me.ilvlDelta`), as the `toast.minGain` row says, whatever the
scorer; an upgrade into an empty slot has no change to measure and clears any least gain (DW-62:
spec §5.2 makes it an upgrade, so it is the clearest case), reading `empty` where the gain would
go; your own drops never toast. **Once per drop:** a drop is considered on `DropAdded` and on
each `DropUpdated` until it has toasted, so one whose trade turns `likely` after the looter's
inspect still toasts. **The queue** keeps the newest five; a drop asked for meanwhile, gone from the
feed or no longer qualifying is skipped when its turn comes. **Combat** holds the queue until
`PLAYER_REGEN_ENABLED`, and a toast on screen when combat starts goes back to the head of the
queue with its full duration. **The pause** keeps the seconds left while the pointer is over the
toast or its buttons, and resumes with them (at least one). **Test mode**'s placeholders toast
like live drops (with `toast.enabled` on); a test drop's toast has no countdown, so it stays to be
dragged into place until it is closed or test mode ends. Only in test mode can it be dragged, and
the Window's Reset position forgets its point too. **The sound** is SOUNDKIT's
`UI_EPICLOOT_TOAST`, else `RAID_WARNING`, on the Master channel (`Compat.PlayAlertSound`). That it
shows, pauses, places and sounds right in game is TOAST-1.

## Auto-ask

Auto-ask (DW-54, `modules/AutoAsk.lua`) settles what design spec §9.4 leaves open. **What qualifies** is the
toast's own test (`NS.Toast.Qualifies`) with `messages.autoAsk.minGain`: the item-level change for you,
whatever the scorer (an empty slot clears any least gain, and the ask's `{mygain}` then reads
`an empty-slot upgrade`, never the drop's item level, which is no gain), never your own drop, and an upgrade
only, so it always fills the plain `ask` template, never the transmog one. **Once per drop:** a drop is
considered on `DropAdded` and on each `DropUpdated` until it is scheduled, so one whose trade turns `likely`
after the looter's inspect still qualifies; a drop scheduled, sent or canceled is never scheduled again that
session. **Only new drops:** turned on, it counts only the drops the feed records from then on (all of a
session's drops when it was on at login), so turning it on never whispers for the drops already in the
table. A profile switch, copy or reset runs no row reaction, so `reloadProfile` (core/DropWatcher.lua) calls
`NS.AutoAsk.OnProfileReloaded`: an incoming profile that turns it on counts from that moment the same way,
one that turns it off cancels the waiting asks, and the one-time notice stays the row's alone. **The
timing** is the delay after the later of the drop and the last `ENCOUNTER_END`; while an encounter is in
progress (`ENCOUNTER_START` without its end) nothing is due, and the end makes every waiting ask due its
delay after that moment. A player who leaves mid-fight may never hear that end, so a loading screen or a new
zone (`PLAYER_ENTERING_WORLD`, `ZONE_CHANGED_NEW_AREA`) ends the hold the same way, unless the restriction
tracker still reports the Encounter restriction (DW-62); then the restriction's lifting
(`RestrictionChanged`) ends it, since the client may report that after the loading screen (M6 review). A
restriction change alone, with no world event since the encounter began, never ends a hold. A drop that
qualifies once its time has passed is asked at once. A keystone run has no `ENCOUNTER_END` for its chest, so
its drops are timed from the drop. **The send** is checked again when due (on, in the feed, qualifying,
never asked, not received, its looter in the group) and goes through the messaging edge's `Request`: guarded
by the one-ask registry, queued while chat is restricted, confirmed in chat, never through the edit-first
box; a refusal is logged under `MSG`, not said in chat. **Canceled** by any move of the drop's ask (a click
on Ask, the toast's or the card's), a `GROUP_ROSTER_UPDATE` that leaves its looter out of the group, the
history's `received`, turning it off, and the stand-down (until 2026-10-13 a dismissed row canceled it too;
feedback-4 spec §2, DW-D2, removed every dismiss). **Test mode**'s placeholders qualify like live drops and
are timed from when test mode put them in; their asks are printed, never sent. **The notice** is said once
per account (`global.notices.autoAsk`), the first time the row turns on through the seam (the panel,
`/dw set`); a profile switch or reset that turns it on says nothing. That it whispers in game after a boss
kill, and holds off on each cancel, is ASK-8.

## The window shell

The window shell (DW-30) settles four cases the design leaves open. **Interesting** (View) is the
brainstorm's union (03_FEATURES F1, board 01 note 5): someone else's drop that is an upgrade for
you, whatever its trade estimate, or one its looter has no use for (a downgrade, can't use or
doesn't want) whose estimate is `yes` or `likely`; and your own drop whose estimate is `yes` or
`likely`. **Own loot** stays out of Group drops unless `feed.showOwn` is on (design spec §6.3; it
goes to My drops). **This instance** (Content) is the drops since
the situation last changed (`SituationChanged`), so two dungeons of the same kind in a row, with
no other situation between them, read as one. **Auto-open** (since DW-83, feedback spec §3 FB-12,
replacing the M3 reading of once per situation on the first interesting drop) fires on every drop
added to the feed the window shows, your own included and whatever `feed.showOwn` says, while the
window is hidden; the drop has already passed the feed's gates (its situation tracked, the minimum
quality). Master `autoOpen` false, or the situation's own `autoOpen` false, turns it off. A
minimized window stays minimized, and every such drop counts toward `n new`. The frame holds no
protected frame, so it opens in combat too. **Usable by me** hides the drops whose verdict for you
is can't use or doesn't want; a drop not judged yet stays. **Upgrade for me** keeps only the
drops whose verdict for you is an upgrade. Both are the Group drops tab's alone. The **Quality** control writes `feed.quality.mode` through the write seam
(`NS.SetQualityMode`), the row the Feed page shares.
**Superseded by feedback-5 (2026-10-13)** (feedback-5 spec §2-§3, DW-E2, DW-E3): own loot is always
listed. The window has two tabs, Drops (the Group drops tab renamed, its key still `group`) and
History; `feed.showOwn` is retired (schema step 6 removes it), and a stored active tab of `mine`
opens Drops.
**Superseded by feedback-7 (2026-10-13)** (feedback-7 spec §4, DW-G4): the full layout's Scan group is no
longer in the title bar. It sits on the Drops strip, 8px left of Post my tradeables, and slides into Post's
slot while Post is hidden, so the full layout shows the strip on Drops always (its summary empty with nothing
tradeable). History has no Scan group (`/dw scan` stays). The compact layout keeps its title-bar icon, and
the restriction badge anchors to the layout toggle.

## The Group drops table

The Group drops table (DW-31) settles five cases the design leaves open. **Group order** is newest first
(oldest first under Sort: Oldest), and a group the player never toggled is open when it is the first one
shown and collapsed otherwise (board 01); the Sort orders the drops inside each group. The **header** names
the group, its situation (the feed's groups carry no difficulty), its age and its count. The M3 **compact
preset**, which changed the columns only, is retired: compact mode (M12) is a second layout of the whole
window, with its own size and cards in place of rows (see Compact mode below). **My eq** and **Their eq**
(DW-83, feedback spec §3) show both worn items for rings, trinkets and weapons (the hands the drop could go
in) as icons with their item levels (`300/296`), My eq read from your gear snapshot, Their eq from the
looter's inspect entry; a slot read as empty says `empty slot`, and Their eq's inspect age is in its tooltip
(`Inspected 2m ago.`, `From the inspect cache, read 6m ago.`), the cell keeping only a no-data state's word.
A **narrow window** sheds columns rather than clip them: while the fixed columns and the Item column's 150px
do not fit the row, Type goes first (since DW-D3), then Slot, Looter, My eq, Their eq, Ilvl, Them, Trade and
Me (My drops: Best candidates, Ilvl, For me, Trade window); Item and Actions never go, and the detail card
(or the Offer panel) still says what a shed column would. The **Ask button** asks at once, or, with
`messages.editFirst` on, opens the detail card's Edit message box first; it reads `Traded ✓` once the
history records the drop received from a completed trade (DW-51), and the detail card's Ask with it.
**Superseded 2026-10-13** (feedback-4 spec §0-§4, DW-D0..DW-D4): the Me and Them columns share one tone per
verdict (green upgrade, yellow sidegrade, red downgrade, gray can't use; Them is no longer inverted) with
the arrow before the number; the Ask is red while the move is yours, yellow while it waits and green once
traded; no row can be dismissed (its × is gone, and Actions holds only Ask); a Type column sits beside Slot;
the column labels are gold; and the window cannot be sized narrower than its default, 972 (compact 380), the
width where no tab sheds a column.
**Superseded by feedback-5 (2026-10-13)** (feedback-5 spec §0-§4, DW-E0..DW-E4): the table is Drops and lists
your own drops too; a Trade window column (104px, `window.columns.tradeWindow`, between Trade and Actions)
gives every drop its countdown over a bar, an estimate from when it dropped for another player's (`~1:42:10`),
and sheds after Their eq and before Them; Actions is 84px; every row is indented 12px under its header with a
muted-white chevron at its left (down, up while its detail card is open), and the header's chevron is gold;
on your own drop Trade counts its upgrades (`Yes (2)`), Them and Their eq read `(Multiple)` and Actions is
Offer. The least width is now 1132 (compact 440).
**Superseded by feedback-6 (2026-10-13)** (feedback-6 spec §0-§3, DW-F0..DW-F3): the Trade window column is
76px, its widest answer (`No limit (BoE)`) plus its bar's padding; My eq is merged into Me and Their eq into
Them, each cell `[icon(s)] [item level] [glyph][difference]` (`321/308 ▽8`, the difference unsigned, the
glyph and number in the verdict's tone, the item level plain; `Can't use` and `Not wanted` stay words; an empty
slot reads `empty`; a `?` is left out when the gear part already says why), 127px each, the tooltip the gear
lines then the verdict's; the `myEq` and `theirEq` toggles are retired (schema step 7); the shed order is
Type, Slot, Looter, Trade window, Ilvl, Them, Trade, Me; History's Me and Them are the verdict alone in the
unsigned form, since a kept entry holds no worn items. On your own drop Them reads `(Details)` (renamed from
`(Multiple)`), its tooltip one non-wrapping line per member it upgrades, ranked by gain: the name in class
color, `wears`, the item level and item in its quality color, a green arrow texture and the unsigned gain,
naming the lower of two worn items. Offer is cyan while it is your move. A verdict mark in any tooltip is an
inline texture, never a font glyph. The least width is now 1038 (compact 440).
**Superseded by feedback-7 (2026-10-13)** (feedback-7 spec §1-§3, DW-G1..DW-G3): on your own drop Them reads
`Upgrade for N` (green; `No upgrades`, muted, with none; `Hidden` under the keep? rule) where it read
`(Details)`, and Trade drops the count (`Yes`, not `Yes (2)`), the count moving to its tooltip. Trade's `No`
is the palette's red, not the gray `bad` tone. Your own drop's looter reads `Name [YOU]`, the mark in gold and
never cut. Ask carries the `chat` icon and Offer `export`. Every tooltip that lists worn gear against a drop
(Me, Them, `Upgrade for N`) lays it out as a grid, `[Name] [Item level] [Item name] [glyph and difference]`,
the glyph the table's monospace one with glyph and number in the verdict's tone; the `wears` lines and the
`Item level A against B` sentence give way to it.

## The detail card

The detail card (DW-32) settles five cases the design leaves open. **Expansion** is session-only and follows
the row: a row filtered out or folded under its header hides the card, and it comes back, still open, with
the row; Hide this item dismissed the row and closed the card until 2026-10-13, when it was removed
(feedback-4 spec §2, DW-D2). **Trade** on someone else's drop opens an empty trade with the looter, so they
can put the item in; it is off on your own drop (that is My drops' Offer, DW-33) and on a drop its looter
can't trade, and otherwise follows the trade helper's guards (combat, range, offline, not in the group), its
short reason on the button (`Trade · out of range`). **Superseded by feedback-5 (2026-10-13)**
(feedback-5 spec §2): on your own drop the card's Ask is Offer, which opens the Offer panel, and its Them row
reads `(Multiple)`; My drops is retired. **Superseded by feedback-6 (2026-10-13)** (feedback-6 spec §2-§3): the
Them row reads `(Details)` and the Offer is cyan while it is your move. **Superseded by feedback-7
(2026-10-13)** (feedback-7 spec §1-§3): the Them row reads `Upgrade for N`, the Looter row `Name [YOU]` (the mark
in gold), the trade chip's `NOT TRADEABLE` is red, Ask and Offer wear their state's icon, and the verdict
chips' tooltips list the gear as a grid. **Retry inspect** is off while the looter's read is
still good or already queued, since the broker would not inspect again, and queues them at the looter
priority otherwise. **Stats** are the four secondary stats' change against the replaced item, the largest
first; the primary stat, stamina, sockets and tertiary stats are the header's chips. The score line is
labeled by the scorer in use (**Pawn**, **Weights**, or **Score** with none) and shows its change; without
one it says why (not scored yet, or no scorer in use).

## The My drops tab and the Offer panel

**Superseded by feedback-5 (2026-10-13)** (feedback-5 spec §1-§3, DW-E1..DW-E3): the My drops tab is retired
and the readings below about the tab stand as history. Your own drops are Drops rows: the countdown is the
Trade window column every row has (`ending soon` is no longer drawn in the cell, only its amber, bold tone,
its amber bar and the tooltip's `Ending soon: …`), and it moves each second; Best candidates became Trade's
upgrade count and the `(Multiple)` tooltip, `Hidden` until the Offer panel is opened (the keep? rule); the
row's Offer opens the panel and there is no Announce in the table (Announce to group stays in the panel); the
summary and Post my tradeables are the strip under Drops, shown while one of your listed drops can be traded.
The Offer panel's readings hold.
**Superseded by feedback-6 (2026-10-13)** (feedback-6 spec §2-§3, DW-F2, DW-F3): `(Multiple)` is `(Details)`,
its tooltip one line per member it upgrades (name in class color, the worn item level and item in its quality
color, a green arrow texture and the unsigned gain), never wrapping; Offer, on the row and each candidate's in
the panel, is cyan while it is your move (Offered yellow, Traded green, Retry red); Announce to group is
unchanged.
**Superseded by feedback-7 (2026-10-13)** (feedback-7 spec §0-§2, §4, DW-G0..DW-G2, DW-G4): the Offer panel's
`Eq -> drop` and Status pill columns are merged into one **Their eq** column drawn as the Drops Them cell (the
worn icons, the item level, the monospace glyph and the unsigned difference in the verdict's tone; `Can't use`,
`…`, `Unavailable` and `empty` as words), the pill's explanation moving into the cell's tooltip, a gear grid.
The class stripe at each row's start is gone and every second row draws the main window's faint stripe. The
**Trade button is removed** (owner decision): Actions holds Offer alone, `K.PANEL_BTN_W` 72 with its icon;
the readings below about Trade stand as history (the give path `NS.GiveDrop` / `TradeHelper.Give` was
removed afterwards, see the trade helper's reading). `(Details)` is `Upgrade for N` and Trade's count is gone from the cell. Post my tradeables is the
footer Sort's size, directly above it, with Scan group beside it on the strip.

The My drops tab and the Offer panel (DW-33) settle nine cases the design leaves open. **The tab** lists
every drop of yours in the tab's feed, a drop that cannot be traded included (a dash and Hide, board 04's
last row); `My drops · n` counts only the tradeable ones, and Hide is session-only. Since 2026-10-13
(feedback-4 spec §2, DW-D2) there is no Hide: such a row shows the dash with its reason, and every drop of
yours stays listed. **The countdown** is exact once the trade timer has read the item (`trade.expiresAt`);
before that it is estimated from when the item dropped and the two-hour window and reads `~1:48:20`. It
repaints on every `TradeTimerTick` (each second while a timer is live and the window shown) and on the
footer's 5-second ticker, which is what moves an estimate. At `trade.warnAt` or less it reads `ending soon`,
in bold and amber; the chat warning is the trade timer's. A bind-on-equip drop reads `No limit (BoE)`.
**Best candidates** of an upgrade for you read `Hidden: an upgrade for you` until you open its Offer panel,
which reveals them for the session (AskFlow B2); Offer… stands out (gold) when someone gains and it is not
hidden. Since 2026-10-13 (feedback-4 spec §1, DW-D1) the gold is gone: Offer and Announce are red while the
move is yours, yellow once an offer or the announce is out, green once the drop was traded away. **The
ranking** is upgrades by gain, then EQUAL, NO UPGRADE, CAN'T USE, a judged member whose replaced item was
not read (UNAVAILABLE), CHECKING… and UNAVAILABLE, each tie by name; `eq → drop` reads `… → 305` while
checking and `– → 305` when nothing it would replace was read. **Offer and Trade** are shown for an upgrade
or an equal only; anyone else shows a dash with the reason. Trade is `NS.TradeHelper.Give` (the item placed
in the trade), disabled with the helper's reason (combat, range, offline, not in bags, expired, busy
cursor), read first through `CanGive`. **The panel** stays open across tabs, repaints with the window,
closes with its close mark or when its drop is gone, and docks right, else left, else floats over the
window's right half above its rows. **Announce** (a row's and the panel's Announce to group) is one announce
per drop, as the messaging edge files it. **Post my tradeables** lists the tradeable drops of yours in the
feed on show, whatever the tab's filter, prefixed `Up for trade, whisper me:`, cut at 255 bytes without
splitting a link; each line is its own announce, filed under `post:<n>:<i>`, so every press posts again.
**Not yet:** a drop of yours traded away is `tradedAway` in the history (DW-51), but its row does not say so
(board 04's `Traded to Séta`): once the item leaves your bags the trade timer drops its entry and the row
reads as expired.

## Five settings rows

Five rows settle how they act. **`feed.clearOnBossKill`** empties the live feed at a kill's
`ENCOUNTER_END` (never a wipe), before the boss's loot arrives, and repaints the window; queued
asks keep their text and still flush. **`comparison.heirloomProtect`** (on by default) is yours
alone: a drop whose baseline is an heirloom reads as a sidegrade for you (reason
`heirloomProtected`), while the looter's verdict stays plain, so a real upgrade for them is never
read as one they would give away. **`messages.editFirst`** routes every ask, offer and announce
press through the Edit message box (the detail card's, now one box for all three kinds); the box's
Send goes back through the same handler with the edited text, a press on a queued send still
cancels it, a press with the window closed sends as it stands, and Post my tradeables never opens
it (its lines are already cut to the chat limit). **`window.rowHeight`** and **`window.fontSize`**
size the drop tables' rows and their cells' text on all three tabs (feedback-2 spec §8, FB2-9: 18
pixels and the template's own size by default, like Ka0s Loot History's table; a My drops row adds
room for its countdown bar); the headers, the column labels and the buttons keep their own.
**Superseded by feedback-5 (2026-10-13):** two tabs, Drops and History; a Drops row adds the countdown
bar's room while the Trade window column shows.

## The compat seam

Three of the compat seam's (`core/Compat.lua`)
readings are unconfirmed in game and owed as COMPAT-1..3: the enum member names it resolves, the
shape of the trade-time and item-level tooltip lines (whether the `ItemLevel` line carries a
numeric field), and that `PawnIsInitialized` is a boolean flag. A secret chat-lockdown or
restriction answer reads as locked, a secret bind answer as not bound ([`midnight-quirks.md`](midnight-quirks.md)).

## Compact mode

Compact mode (M12, compact spec) settles four cases its spec leaves open. **The switch** carries the scroll
offset as the same fraction of the scroll range (`CompactGroup.CarryScroll`), since a card and a row differ
in height; the expanded detail card and the collapsed groups are the session tables both layouts read, so
they carry exactly (the hidden rows were too, until feedback-4 spec §2, DW-D2, removed them). **The run
override** ends on the situation edge, not on `CHALLENGE_MODE_COMPLETED` alone: a key's completion re-reads
the situation as a dungeon, and leaving the instance ends the rest; a shown window keeps its layout until it
is next hidden, so a run's end never resizes the window under the player. **The columns** (the Columns rows
and Row height) shape the full layout's tables only; a card carries every fact on its three lines and sizes
from its font (`window.fontSize`). **The Filters menu** is a small panel under the `Filters` button holding
the full bar's own Quality, Content and Character dropdowns and the footer's Sort, moved rather than copied,
so their choices and multi-select behavior cannot differ; it closes on a second click, minimize, close or a
switch to full, which puts each control back.
**Superseded by feedback-5 (2026-10-13)** (feedback-5 spec §0-§4): the tabs are Drops and History (no My drops
cards); a Drops card is indented under its header with the row's muted-white chevron before the item button,
its line 2 ends in the countdown and its bar for a drop with one (else the inspect freshness), your own card
carries Offer, the upgrade count and `(Multiple)`, the strip under the cards is shortened (`2 tradeable · next
0:08:41`, `Post`), and the least compact width is 440 so line 2's countdown is never cut.
**Superseded by feedback-6 (2026-10-13)** (feedback-6 spec §1-§3): line 3 reads as the table's merged Me and
Them without icons, `You 321/308 ▽8` and `Them 276 ▲12`, `Them (Details)` on your own card (History's cards
the verdict alone); Offer is cyan while it is your move; the least compact width stays 440, line 3's fullest
halves ending about 46px short of the card's edge.
**Superseded by feedback-7 (2026-10-13)** (feedback-7 spec §1-§4): your own card reads `Them Upgrade for 2`
where it read `Them (Details)`, its trade piece drops the count, your name carries a gold ` [YOU]`, Trade's
`No` is red, Ask and Offer wear their icons, and the compact layout keeps Scan group as its title-bar icon
while the full layout's moves to the Drops strip. The empty state's two buttons are centered as a pair.
