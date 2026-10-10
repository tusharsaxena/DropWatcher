# Ka0s Drop Watcher: v1 design spec

- **Date:** 2026-10-10.
- **Status:** approved for build.
- **Owner:** add1kted2ka0s.
- **Inputs:**
  - `docs/superpowers/research/2026-10-10-brainstorm/`: the research, the high-level design and the
    owner's decisions.
  - `…/wireframes/`: the approved wireframes.

**Scope of this run.** The **MVP plus the v1 tier** from the brainstorm's `03_FEATURES.md`, plus two features
the owner added after approving the wireframes: **Situations** and **Dynamic minimum quality**. Later-tier
features are out of scope and are filed as GitHub issues (§14).

**Identity.**

| Field | Value |
|---|---|
| Name | Ka0s Drop Watcher |
| Folder | `DropWatcher` |
| Slash | `/dw` (alias `/dropwatcher`) |
| Saved variables | `DropWatcherDB`, `DropWatcherPerfDB` |
| Author | add1kted2ka0s |
| Licence | MIT |
| Libraries | Ace3, LibKa0s v1.71.0 |
| Interface | 120100 |
| Standard | Ka0s WoW Addon Standard v2.78.2 |

---

## 1. Goals and non-goals

**Goals**

1. Show every relevant drop the group receives. Each one gets a verdict for you and a verdict for the looter
   (upgrade, sidegrade, downgrade, can't use or unknown), an honest trade estimate, and a one-click polite ask.
2. Show your own tradeable drops, with an exact trade countdown and the members each drop would upgrade. Offer a
   one-click offer or trade, in parties **and** raids.
3. Respect Midnight's addon restrictions. Asks queue while chat sending is restricted. Every payload that can be
   secret is guarded.
4. Be quiet by default: a docked feed, with auto-ask, toasts and sound all opt-in.
5. Be fully compliant with the Ka0s standard from the first commit.

**Non-goals in v1:**
- loot council, voting and rolls
- wishlist, BiS, tier and catalyst flags, Droptimizer
- addon comms between users, and PLH/PLR interop
- Void Core tracking
- loot-spec nudges

These are GitHub issues (§14).

---

## 2. Owner decisions in force

| Decision | Value |
|---|---|
| Styling | Ka0s skin. The window chrome follows Ka0s Loot History: a 30px title bar, a 26px tab strip with a gold active tab and gold underline, a filter bar, the table and a footer. |
| Standalone vs LootHistory | A standalone addon |
| Raid trade rule | Data-driven; verified in game before release (§7.3) |
| Scope | MVP + v1 |
| Shared pieces | Built in-addon first: the loot parser, the restriction tracker, the chat sender and the tooltip line reader. Each is recorded as a documented deviation, and a LibKa0s promotion issue is filed (§14). |
| Minimum quality modes | All three are offered: Fixed, Dynamic per slot and Dynamic whole character (§6.2) |
| GitHub repo | `tusharsaxena/DropWatcher`, public |

---

## 3. Architecture overview

```
 CHAT_MSG_LOOT ─┐                         ┌─> Window (Group drops / My drops / History)
 ENCOUNTER_LOOT ├─> LootParser ─> LootFeed ┼─> DetailCard, OfferPanel, Toast
 LOOT_HISTORY  ─┘        │            │    └─> History (DB.global, capped)
                         │            │
   Situations ───gate────┘            ├─> ItemFacts ─> Evaluate (pure) ─> verdicts
   QualityGate ──gate─────────────────┤     Roster ─┐      ▲
                                      │     Inspect ┴─> candidate gear/spec
                                      │     Gear (me) ┘
                                      ├─> TradeRules (pure) ─> trade estimate
                                      └─> TradeTimer (own bag items)
 Restrictions ──> Messaging queue ──> Compat.ChatSender (pcall)   TradeHelper ──> DropItemOnUnit
```

**Pure kernels** take plain tables and make no WoW calls, so the headless suite can test them exhaustively:
`Evaluate`, `TradeRules`, `QualityGate` (its decision half), `Situations` (its classifier half) and
`Messaging` (template expansion and the queue state machine).

**Edges** are where all WoW API calls live, and nowhere else. Version-variant or deprecated APIs go through
`core/Compat.lua`.

**The bus.** Modules talk over `LibKa0s-Bus-1.0`, with each message named `Ka0s_DropWatcher_<Event>`. The UI
modules only listen; they never call the engine modules directly.

| Message | Sender |
|---|---|
| `DropAdded` | LootFeed |
| `DropUpdated` | LootFeed |
| `InspectDone` | Inspect |
| `GearChanged` | Gear |
| `RestrictionChanged` | Restrictions |
| `SituationChanged` | Situations |
| `AskStateChanged` | Messaging |
| `TradeTimerTick` | TradeTimer |
| `TradeTimerExpiring` | TradeTimer |
| `HistoryChanged` | History |

---

## 4. Module map

The layout follows layout-§1. These are the planned files; the scaffold may add the standard core files
around them.

| Path | Kind | Responsibility |
|---|---|---|
| `core/Compat.lua` | edge | **The only caller of version-variant APIs:** `GetItemUpgradeInfo`, `C_TooltipInfo` line-type reads, `ChatSender` (`C_ChatInfo.SendChatMessage` with a global fallback), `IsSecret`/`CanAccess` via `LibKa0s-Compat-1.0`, the restriction APIs, Pawn presence, `C_Item` bind helpers and `DropItemOnUnit`. |
| `core/Constants.lua` | data | Slot ids, equip-location → slot plan table, quality ids, trade-rule table, defaults for templates. |
| `core/ClassData.lua` | data | Class armor type and weapon proficiencies, dual-wield specs, Titan's Grip spec, shield and off-hand users, and the spec → primary stat map. **Includes the Devourer Demon Hunter spec.** Pure data plus lookups. |
| `modules/Restrictions.lua` | edge | Tracks the `ADDON_RESTRICTION_STATE_CHANGED`, `C_ChatInfo.InChatMessagingLockdown()` and `InCombatLockdown()` state. Exposes `CanSendChat()`, `CanInspect()`, `CanTrade()` and `ActiveReason()`. Sends `RestrictionChanged`. |
| `modules/Situations.lua` | classifier + edge | Classifies the current context into a situation key (§6.1) and answers whether tracking and the window are active. Sends `SituationChanged`. |
| `modules/Roster.lua` | edge | Group members: GUID, Name-Realm, unit token, classFile, specID (known after an inspect) and online state. Resolves a name or GUID to a member. |
| `modules/LootParser.lua` | edge | Compiles GlobalString patterns once (rebuilding them when the globals change): `LOOT_ITEM`, `LOOT_ITEM_SELF`, `*_MULTIPLE`, `LOOT_ITEM_BONUS_ROLL*`, `LOOT_ITEM_PUSHED*`. Rejects `CHANGED_OWN_ITEM` and crafting echoes. Every field is secret-guarded. Returns `{looterName, looterGUID, link, qty, kind}`. |
| `modules/ItemFacts.lua` | edge (cached) | Turns a link into facts: ilvl, equipLoc, classID/subClassID, quality, bindType, warbound, bonus-roll flag (from the parser), track (`trackString`, `currentLevel`, `maxLevel`, `trackRank`), stats, specs list, setID, unique category and transmog-known. Loads uncached items through `LibKa0s-Item-1.0` `LoadItem` with retry. |
| `modules/Evaluate.lua` | **pure** | The verdict kernel (§5). |
| `modules/QualityGate.lua` | pure + edge | Applies the minimum-quality mode (§6.2). The decision function is pure, and the inputs come from Gear. |
| `modules/Gear.lua` | edge | Your own snapshot: equipped items per slot (facts plus the current ilvl) and the best item you own per slot, bags included. Invalidated on `PLAYER_EQUIPMENT_CHANGED` and `BAG_UPDATE_DELAYED`, with a throttle. Sends `GearChanged`. |
| `modules/Inspect.lua` | edge | The inspect broker (§8). |
| `modules/TradeRules.lua` | **pure** | The trade estimator (§7). |
| `modules/TradeTimer.lua` | edge | Trade countdowns on your own bag items, read from the `TradeTimeRemaining` tooltip line type (§7.4). |
| `modules/TradeHelper.lua` | edge | Finds an item's bag slot by GUID, then `PickupContainerItem` and `DropItemOnUnit`. Also `InitiateTrade`. Guards range and combat. |
| `modules/Scoring.lua` | adapters | `Pawn` (optional dependency), `Weights` (your own weights) and `None` (§5.4). |
| `modules/Messaging.lua` | pure + edge | Templates, tokens, the one-ask guard, the restriction queue, and the `pcall` send (§9). |
| `modules/LootFeed.lua` | orchestrator | Merges the loot sources, dedupes, groups by encounter, applies the situation and quality gates, runs evaluations, owns the drop records, and sends `DropAdded` and `DropUpdated`. |
| `modules/History.lua` | owner of recorded data | A capped log in `DropWatcherDB.global.history` (§10). |
| `modules/AutoAsk.lua` | edge | Opt-in delayed ask after an encounter ends (§9.4). |
| `modules/Window.lua` | UI | The window shell: skin, title bar, tabs, filter bar, footer, minimise, resize, position and `UISpecialFrames` (§11). |
| `modules/WindowGroup.lua` | UI | The Group drops table and its rows. |
| `modules/WindowMine.lua` | UI | The My drops table and its rows. |
| `modules/WindowHistory.lua` | UI | The History tab. |
| `modules/DetailCard.lua` | UI | The expanded row. |
| `modules/OfferPanel.lua` | UI | The "Who could use this?" panel. |
| `modules/Toast.lua` | UI | The opt-in alert. |
| `modules/TestMode.lua` | data + UI hook | Placeholder drops covering every state. |
| `modules/Diagnostics.lua` | sections | The diagnostics report sections (§13). |
| `settings/*.lua` | settings | The Schema, Slash, OptionsSetup, one file per page, and Profiles. |

**Line cap.** Any file that grows past about 1000 lines is split before it reaches the 1500 cap.

---

## 5. Evaluation kernel (`modules/Evaluate.lua`, pure)

### 5.1 Inputs

```lua
facts     = { itemID, ilvl, equipLoc, classID, subClassID, quality, specs = {specID=true,...}|nil,
              stats = {STAT_KEY = n}, track = {name, rank, max, tier}|nil, unique = {cat, max}|nil,
              isTierToken = bool, classes = {classFile=true}|nil }
candidate = { classFile, specID|nil, dualWield = bool|nil, titanGrip = bool|nil,
              gear  = { [slot] = facts|false },            -- equipped; false = empty
              owned = { [slot] = facts }|nil,              -- best owned per slot (me only)
              prefs = { undesired = { [subClassKey] = true } }|nil }
opts      = { sidegradeBand = 0, compareOwned = false, scorer = fn|nil }
```

### 5.2 Steps

**1. Equippability → `ok | cant | doesntWant | unknown`.**
- **Spec known and `facts.specs` present:** the item is `ok` if the spec is in the list, otherwise `cant`. This covers armor type, weapon type, shield, off hand and primary stat in one check.
- **Spec unknown:** fall back to `ClassData`.
  - Check armor type: cloak, neck, ring and trinket are universal.
  - Check weapon subclass proficiency, shields (classes that can use them), and off-hand holdables (caster classes).
  - Check the primary stat when every spec of the class shares one.
  - If the result is still ambiguous, return `unknown`.
- **Tier tokens:** use `classes`.
- **Preferences:** if the item is usable but its subClass is in `prefs.undesired`, return `doesntWant`.

**2. Slot plan.** The kinds come from `Constants.SLOT_PLAN[equipLoc]`:

| Kind | Applies to | How it compares |
|---|---|---|
| `single` | one-slot items | Against that slot. |
| `pair` | ring, trinket | Against the lower of the two slots. |
| `weapon1H` | one-hand weapons | Main hand only. For `dualWield` specs, against the lower of main hand and off hand. |
| `weapon2H` | two-hand weapons | Against the average of main hand and off hand. If the off hand is empty, use main hand alone. With `titanGrip`, as `pair` over both hands. |
| `offhand` | off hand, shield | If the candidate currently wields a 2H (main hand is 2H and off hand is empty), against the 2H's ilvl. This fixes the false "upgrade" WhoGotLoots shows. |
| `ranged` | ranged weapons | Treated like `weapon2H` for hunters. |
| `unique` | unique-equipped items | If an equipped item shares the unique category and the maximum is reached, compare against **that** item, with the reason `uniqueEquipped`. |

When `opts.compareOwned` is set and `owned` is present, the baseline is the best of equipped and owned for
each slot.

**3. Deltas.**
- `ilvlDelta` is the candidate ilvl minus the baseline ilvl.
- `trackDelta` is computed when both items have a track: a track tier order (Adventurer < Veteran < Champion < Hero < Myth, keyed by `trackStringID` where available), then rank.
- `scoreDelta` is computed when `opts.scorer` returns numbers for both items.

**4. Verdict.**
- `cant` maps to `cantUse`.
- `doesntWant` is reported as `doesntWant`.
- `unknown` equippability or a missing baseline maps to `unknown`.
- Otherwise:

| Scoring | Condition | Verdict |
|---|---|---|
| off | `ilvlDelta > band` | `upgrade` |
| off | `ilvlDelta < -band` | `downgrade` |
| off | otherwise | `sidegrade` |
| on | ilvl and score agree in sign | Use that sign. |
| on | they disagree, or both are within the band | `sidegrade` |

- An **empty baseline slot** counts as an upgrade with the reason `emptySlot`, except in the `offhand` vs 2H case.

**5. Output.**

```lua
{ verdict, ilvlDelta, trackDelta, scoreDelta, baselineSlot, baseline = facts|nil,
  reasons = { {key="uniqueEquipped"}, ... }, equip = "ok|cant|doesntWant|unknown" }
```

**Rule:** the kernel never throws. Any nil or unexpected input yields `verdict = "unknown"` with a reason.

### 5.3 Who it runs for

- **For me:** always, using the Gear snapshot.
- **For the looter:** once the looter's inspect snapshot exists. Until then the verdict is `unknown` and the
  inspect state is shown.
- **For each group member:** only for your own drops, feeding the Offer panel and the Best candidates column.
  Members without an inspect snapshot show `CHECKING…` or `UNAVAILABLE`.

### 5.4 Scoring (v1)

- **`Pawn` adapter.** Present only when `PawnIsInitialized` is true.
  - **For me:** `PawnIsItemAnUpgrade(PawnGetItemData(link))`, which gives `PercentUpgrade` per visible scale. Use the best visible scale.
  - **For a looter:** `PawnFindScaleForSpec(classID, specID)` and `PawnGetSingleValueFromItem` on the drop and on their item.
  - **Nil answers:** a call that returns nil means "not ready". The adapter returns `pending`, and LootFeed retries on one shared 1s timer, up to 5 times.
  - **Seam:** all Pawn calls go through `core/Compat.lua`.
- **`Weights` adapter.** You enter per-spec weights `{STAT_KEY = weight}` in Settings › Comparison. There is also an import string, in the `( Pawn: v1: "name": Key=val, ... )` format. The score is the sum of stat times weight.
- **`None` adapter.** No score; ilvl only.
- **Unknown stat keys** contribute 0 and are logged once per key through `NS.DebugOnce`. They never cause an error.

---

## 6. Gating: situations and quality

### 6.1 Situations (owner addition)

**What a situation is.** A situation answers *where* Drop Watcher is active. The classifier is pure. It takes
`{inInstance, instanceType, difficultyID, isChallengeModeActive, isDelve, isFollowerDungeon, inGroup, inRaid,
isPvP}` and returns one key:

| Key | Detection | Default `track` | Default `autoOpen` |
|---|---|---|---|
| `mythicPlus` | `C_ChallengeMode.IsChallengeModeActive()` or an M+ difficulty | on | on |
| `dungeon` | instanceType `party`, not M+, not a follower dungeon (Normal, Heroic, Mythic 0, Timewalking) | on | on |
| `followerDungeon` | follower-dungeon difficulty | off | off |
| `raidLFR` | instanceType `raid` with an LFR difficulty | on | off |
| `raid` | instanceType `raid`, any other difficulty | on | on |
| `delve` | delve difficulty | off | off |
| `scenario` | instanceType `scenario`, not a delve | off | off |
| `pvp` | instanceType `pvp` or `arena` | off | off |
| `openWorldGroup` | not in an instance, in a group | off | off |
| `solo` | not in an instance, not in a group | off | off |

**Implementation notes.**
- Difficulty IDs live in `Constants.DIFFICULTY` and are resolved through `Compat` with `GetDifficultyInfo` checks, never hard-coded in the logic.
- **Re-evaluation** happens on `PLAYER_ENTERING_WORLD`, `ZONE_CHANGED_NEW_AREA`, `CHALLENGE_MODE_START`, `CHALLENGE_MODE_COMPLETED`, `GROUP_ROSTER_UPDATE` and `PLAYER_DIFFICULTY_CHANGED`.

**Per-situation settings:**

| Setting | Effect |
|---|---|
| `track` | When off, LootFeed ignores loot events in that situation and Inspect does no warm-ups. The window stays as it is. |
| `autoOpen` | Opens the window on the first interesting drop in that situation. |
| `quality` (optional) | Overrides the minimum-quality mode for that situation. Absent means the global mode. |

**Where the settings live:** Settings › General › **When to show**, as one row per situation with
`Track` and `Auto-open` checkboxes and a `Quality` dropdown. The dropdown offers `Use global` or any mode.

**Where the current situation shows:**
- the window footer: `Situation: Mythic+`
- the diagnostics report
- `/dw situation`, which prints the classifier inputs and the result

**When tracking is off,** the footer reads `Not tracking in <situation> · change in settings`.

**Test mode** ignores the situation gate.

### 6.2 Minimum quality (owner addition)

**Modes** (`feed.quality.mode`):

| Mode | Threshold |
|---|---|
| `fixed` (default) | `feed.quality.fixed` (default Rare = 3) |
| `dynamicSlot` | The quality of the item the drop would replace in its slot (the slot plan's baseline item, the lower of a pair), floored at `feed.quality.floor` (default Uncommon = 2). An empty slot uses the floor. |
| `dynamicCharacter` | The most common quality across your equipped gear, ignoring shirt, tabard and empty slots. Ties go to the lower quality. Floored at `feed.quality.floor`. |

**Override.** `feed.quality.upgradeOverride` (default **on**): a drop below the threshold is still shown when
its verdict **for me** is an upgrade. This matches WhoGotLoots' `ShowUpgradesBelowMinQuality`.

**The decision function.** It is `QualityGate.Passes(dropQuality, mode, ctx)`, which returns
`pass, threshold, reasonKey`. It is pure and table-tested. `ctx` carries the gear snapshot's per-slot
qualities and the slot plan.

**Where the threshold shows:**
- the filter bar: `Quality: Rare+`, `Quality: Match slot` or `Quality: Match gear (Epic+)`
- each hidden drop's debug line
- the diagnostics report

**Ordering.** The quality gate runs **before** the inspect request, so drops that are filtered out never cost
an inspect. The upgrade-override check needs the verdict for me, which uses only your own gear.

### 6.3 Other feed filters

| Filter | Setting | Default |
|---|---|---|
| Gear only | `feed.gearOnly` | on: armor, weapons, jewelry, trinkets |
| Tier tokens | `feed.includeTokens` | on |
| Minimum ilvl | `feed.minIlvlMode = off \| absolute \| relative`, with `feed.minIlvl` and `feed.relativeIlvl` | off |
| Skip cosmetic and heirloom | — | always |
| Show own loot in Group drops | `feed.showOwn` | off; own loot goes to My drops |

---

## 7. Trade estimate

### 7.1 States

| State | Meaning |
|---|---|
| `yes` | Tradeable for certain |
| `likely` | Passes the rule, judged on inspect data |
| `unknown` | Not enough information |
| `no` | Not tradeable |

Each state carries `reasonKey` plus arguments, `basis` (`inspect` with an age, `bind`, `timer` or `rule`), and
`expiresAt` (timer cases only).

### 7.2 Rules (`TradeRules.lua`, pure)

```lua
RULES = {
  personal = { window = 7200, ilvlRule = "notUpgradeForLooter" },
  group    = { window = 7200, ilvlRule = "none" },
  legacy   = { tradeable = false },
}
CONTENT_RULE = { mythicPlus = "personal", dungeon = "personal", followerDungeon = "legacy",
                 raid = "personal", raidLFR = "personal", delve = "personal", scenario = "personal",
                 openWorldGroup = "personal", solo = "personal", pvp = "legacy" }
```

`CONTENT_RULE.raid` defaults to `personal` (the conservative choice), and the owner can override it in
Settings › Trade. The value is confirmed in game before release; see smoke check TRADE-3.

`Estimate(facts, looterEval, ctx)` checks these in order:

| Check | Result |
|---|---|
| Warbound or account-bound | `no warbound` |
| Bonus roll | `no bonusRoll` |
| BoE | `yes boe` |
| Legacy rule | `no legacy` |
| `ilvlRule == none` | `likely groupLoot` |
| `notUpgradeForLooter` and the looter's evaluation is known and is not an upgrade | `likely notUpgrade(ilvl, theirIlvl)` |
| …and it **is** an upgrade | `no upgradeForLooter` |
| Looter unknown | `unknown noInspect(reason)` |

If the age since the drop exceeds `window`, the result is `no expired`.

### 7.3 Owner override

Settings › Trade lists each situation's rule (`personal`, `group` or `legacy`). Each one can be overridden, and
a reset restores the defaults. This lets the raid rule be corrected without a new release.

### 7.4 Own items: exact timer (`TradeTimer.lua`)

- **Scan.** On `BAG_UPDATE_DELAYED` (throttled to 1 per 2s) and on `LOOT_CLOSED`, scan bag slots whose item matches one of your recorded drops (by itemID and link).
- **Read.** Use `C_TooltipInfo.GetBagItem` and find the `Enum.TooltipDataLineType.TradeTimeRemaining` line.
  - **Fallback:** match the `BIND_TRADE_TIME_REMAINING` pattern and decode the duration with the localized `INT_SPELL_DURATION_HOURS/MIN/SEC` and `TIME_UNIT_DELIMITER` globals, re-implemented in Compat.
- **Store.** Keep `expiresAt` keyed by item GUID (`C_Item.GetItemGUID`).
- **Tick.** One shared `C_Timer.NewTicker(1)` runs only while at least one timer is live and the window is shown. Otherwise the ticker is 60s.
- **Warn.** Send `TradeTimerExpiring` once per item at `trade.warnAt` (default 600s). The warning is printed to chat, and the row goes bold.
- **No timer line** on an item that is BoP, or past its window, means `no expired`.

---

## 8. Inspect broker (`modules/Inspect.lua`)

**State per GUID:**

```lua
{ status = pending|fresh|cached|outOfRange|combatParked|failed, at, gear, specID, reason, gen }
```

**Queue rules**

- One `NotifyInspect` in flight at a time, spaced at least `inspect.spacing` apart (2.0s).
- **Gates:** `CanInspect(unit)`, `CheckInteractDistance(unit, 1)` (an out-of-range check does not use up a retry), `not InCombatLockdown()`, and `not (InspectFrame and InspectFrame:IsShown())`.
- **Priority:** looters of drops awaiting a verdict come first, then Offer-panel candidates, then warm-up jobs.

**Reading**

- On `INSPECT_READY(guid)` for the job in flight, wait 0.15s, then read slots 1–17 with `GetInventoryItemLink`.
- **ilvl** comes from the `ItemLevel` line of `C_TooltipInfo.GetInventoryItem(unit, slot)`, through Compat, with the link's ilvl as a fallback.
- **Spec** comes from `GetInspectSpecialization`.
- **Incomplete links:** retry up to 3 times, 0.3s apart.
- **Clean-up:** call `ClearInspectPlayer()` only if this addon started the inspect.

**Timeouts**

| Wait | Limit | On timeout |
|---|---|---|
| `INSPECT_READY` | 2.5s | Retry (2 attempts) |
| Range | 25s | `outOfRange` |
| Identity resolution | 10s | `failed` |

**Courtesy to other addons and the player**

- `hooksecurefunc("NotifyInspect")` with a self-guard. A foreign inspect re-queues the job in flight.
- An `INSPECT_READY` for any group GUID, from anyone's inspect, is read opportunistically.

**Cache**

- Memory only, with a 600s TTL.
- Invalidated on `UNIT_INVENTORY_CHANGED` for group units: the entry is marked stale and re-queued at low priority.

**Warm-up**

- Inspect the whole group 2s after `GROUP_ROSTER_UPDATE` or entering an instance, when the situation is tracked and the queue is idle.
- `/dw scan` and the Scan group button do the same on demand.

**Combat.** On `PLAYER_REGEN_DISABLED` the queue parks, and the job in flight finishes or times out. On
`PLAYER_REGEN_ENABLED` it resumes.

**Fast path.** If all 17 link reads succeed without an inspect (data already cached client-side), the job
completes immediately.

**Debug.** One summary line per job, with no per-tick lines (#91).

---

## 9. Messaging

### 9.1 Templates

- **Tokens:** `{player}`, `{item}`, `{ilvl}`, `{slot}`, `{track}`, `{gain}` (the looter's or candidate's gain) and `{mygain}`.
- **Unknown tokens** are left as they are, and the settings preview flags them.
- **Templates** (all of them edited in Settings › Messages):

| Template | Default |
|---|---|
| `ask` | "Hi {player}, if you don't need {item}, could I have it? It'd be +{mygain} for me. No worries if not!" |
| `offer` | "Hi {player}, {item} is tradeable and looks like +{gain} for you. Want it?" |
| `announce` | "{item} is up for grabs, whisper me." |

### 9.2 Send pipeline

`Messaging.Request(kind, target, dropID)` runs these steps in order:

1. **Guard.** Each `(dropID, target, kind)` is sent once (`messages.oneAsk`, default on). A repeat is refused with the reason `alreadyAsked`.
2. **Expand.** Fill in the tokens, then check the length against 255. If the message is too long, refuse with `tooLong`; the settings preview shows the count.
3. **Restriction check.** If `Restrictions.CanSendChat()` is false, the message is **queued**. The ask state becomes `queued`, and `AskStateChanged` is sent.
4. **Send.** Call `Compat.ChatSender()(msg, "WHISPER", nil, NameRealm)` inside `pcall`.
   - **Success:** the state becomes `sent`, and the history outcome becomes `asked`.
   - **Failure or throttle:** the state becomes `failed`, with the reason. Retry is allowed.
5. **Flush.** The queue empties when a `RestrictionChanged` to "can send" arrives, or on `ENCOUNTER_END` or `CHALLENGE_MODE_COMPLETED`. One message is sent every 1.5s. Hardware-event rules allow whispers from timers; `announce` to PARTY, RAID or INSTANCE also works from a timer.
6. **Cancel.** Clicking a queued button cancels the ask. Queued asks to a looter are also dropped when that looter leaves the group.

**Announce channel** (`messages.announceChannel`): `auto` picks INSTANCE_CHAT, then RAID, then PARTY. It never
uses SAY or YELL, which need a hardware event and are blocked outdoors.

**Edit before sending** (`messages.editFirst`, default off): opens a small skinned edit popup prefilled with the
expanded text, with Send and Cancel.

### 9.3 Chat confirmation

One printed line per send through `NS.Print`: `Whispered Séta: [item]`. Debug logs the reason for every
failure.

### 9.4 Auto-ask (v1, opt-in)

- **Setting:** `messages.autoAsk.enabled`, default **off**.
- **Trigger:** a drop whose verdict for me is an upgrade with a gain of at least `autoAsk.minGain` (default 5) and whose trade state is `likely` or `yes`.
- **Timing:** the ask is scheduled `autoAsk.delay` seconds (default 10, range 3–30) after the later of `ENCOUNTER_END` or the drop.
- **Cancelled** when you ask manually, the looter leaves, the row is dismissed, or the item is received.
- The first time auto-ask is enabled, a one-time chat notice explains what it does.

---

## 10. History (v1)

- **Owner module:** `modules/History.lua` writes `DropWatcherDB.global.history`, outside the settings schema.
- **Shape:**

  ```lua
  history = { v = 1, groups = { { key, label, situation, at, drops = { {itemLink, looter, me, them, trade, outcome, at} } } } }
  ```

- **Capped** at `history.maxGroups` groups (default 20) and 50 drops per group.
- **Outcomes:** `seen`, `asked`, `offered`, `received`, `tradedAway`, `expired`, `declined` (set by hand from the row menu).
- **Received:** a trade that completes (`TRADE_CLOSED` after the `TRADE_ACCEPT_UPDATE` both-accepted state) with an item matching a drop's itemID marks that drop `received` or `tradedAway`.
- **The History tab:** collapsible groups by encounter or run, the same row style as Group drops, read-only, with a `Clear history` button behind a confirmation.

---

## 11. UI

The approved wireframes are the visual specification. The relevant boards are listed against each part below.

### 11.1 Window (boards 01, 04, 06)

**Frame.**
- `CreateFrame("Frame", "DropWatcherWindow", UIParent, "BackdropTemplate")`, movable and clamped.
- `NS.ApplySkin` applied, plus `NS.MakeCloseButton` and `NS.MakeResizable` (min 520×260).
- Position and size are stored in the profile, the window is in `UISpecialFrames`, and lock is honored.

**Title bar (30px).**
- logo
- title in gold
- the restriction badge, shown only while restricted, with a catalog lock icon and `Encounter · n queued`
- Scan group
- minimise
- close

**Tab strip (26px).** Gold for the active tab, gray for idle ones, after LootHistory's pattern. The tabs are
`Group drops`, `My drops · n` and `History`.

**Filter bar.**

| Control | Values |
|---|---|
| View | Interesting or All |
| Quality | Mode dropdown and threshold label |
| Content | This instance, This session or All |
| Checkbox | Likely tradeable only |
| Search | Looter or item |

The filter bar keeps a separate state for each tab.

**Table.**
- Rows are pooled through `LibKa0s-Pool-1.0`.
- Encounter group headers collapse.
- Default columns: Item, Ilvl, Slot, Looter, Their eq, Me, Them, Trade, Actions.
- **Compact preset:** Item and looter, Ilvl, Their eq, Me, Ask.

**Footer.** Inspect freshness, last loot seen, the situation, Pawn status, sort, and a resize grip.

**Minimise.** Collapses the window to the title bar and shows `n new`.

**Empty state.** Text plus `Preview with test data` and `Scan group` buttons.

**Item icons** are real item buttons:
- hover shows `GameTooltip:SetHyperlink`
- shift-click links the item in chat (`ChatEdit_InsertLink`)
- ctrl-click opens dress-up (`DressUpItemLink`)

### 11.2 Rows and states (boards 01, 03)

**Verdict glyphs.** ▲ upgrade, ≈ sidegrade, ▽ downgrade. Text colors come from Constants:
- an upgrade for me is green; a downgrade for me is gray
- the Them column is inverted: the looter's upgrade is amber, and their downgrade is green

**Trade chips.** Yes, Likely, Unknown or No, with the reason tooltip.

**Ask button lifecycle.** Ask → Queued ⏱ → Asked ✓, with Retry ↻ on failure and Traded ✓ once received. It
shows a dash when no ask is offered.

**Every cell has a tooltip** with the reason. Nothing is ever blank.

### 11.3 Detail card (board 02)

Clicking a row expands it inline, and only one row is expanded at a time. The card holds:
- a header of chips: slot, armor type, bind, track and rank, primary stat, socket and tertiary stats
- **For you** and **For the looter** columns, each with what it replaces, the ilvl change, the track change, stats and Pawn or score
- the trade estimate box
- the actions: Ask, Edit message, Link in chat, Retry inspect, Trade (disabled with its reason), Hide this item

### 11.4 My drops and the Offer panel (board 04)

**My drops columns:**

| Column | Contents |
|---|---|
| Item | |
| Ilvl | |
| For me | Shows "keep?" when the drop is an upgrade |
| Trade window | Countdown and bar |
| Best candidates | The top 3 |
| Actions | Offer… and Announce |

The footer shows the tradeable count, the next expiry, and a `Post my tradeables` button.

**The Offer panel:**
- a frame docked to the window's right edge (it floats when there is no room)
- an item header with your change and the countdown
- a sorted list of candidates with a class stripe and `eq → drop`
- a status pill: `+n UPGRADE`, `EQUAL`, `NO UPGRADE`, `CAN'T USE`, `CHECKING…` or `UNAVAILABLE`
- Offer and Trade buttons per candidate
- `Announce to group`
- it scrolls in raids

**Post my tradeables** sends one announce line listing every tradeable item, cut at 255 characters into
several lines.

### 11.5 Toast (v1, board 06)

- **Off by default** (`toast.enabled`).
- **Fires on** an upgrade for me of at least `toast.minGain` (default 10) with a trade state of `likely` or `yes`.
- **One at a time,** queued. It dismisses after `toast.duration` (8s) and pauses while hovered.
- **Not shown in combat** unless `toast.inCombat` is set.
- **Position:** movable in test mode and saved.
- **Sound:** optional (`toast.sound`, default off), played from `SOUNDKIT`.

### 11.6 Test mode (board 06)

**What it does.**
- It is the session-only Master controls checkbox, and the same handler drives the launcher entry and `/dw test`.
- It injects placeholder drops covering every verdict, trade, inspect and ask state into a separate test feed.
- The window shows a `TEST MODE` chip and banner.
- No message is ever sent; sends are routed to a print instead.

**What ends it.** Combat (`PLAYER_REGEN_DISABLED`).

**What it ignores.** The situation and quality gates.

---

## 12. Settings, slash and launcher

### 12.1 Schema (profile unless noted)

| Group | Keys |
|---|---|
| general | `enabled`, `visible`, `scale`, `alpha`, `locked`, `debug`, (global) `minimap.shown`, `autoOpen` (master) |
| situations | `situations.<key>.track`, `situations.<key>.autoOpen`, `situations.<key>.quality` (`global`, `fixed`, `dynamicSlot` or `dynamicCharacter`) |
| feed | `view`, `quality.mode`, `quality.fixed`, `quality.floor`, `quality.upgradeOverride`, `gearOnly`, `includeTokens`, `minIlvlMode`, `minIlvl`, `relativeIlvl`, `showOwn`, `clearOnBossKill`, `sort`, `content` |
| comparison | `scorer` (`auto`, `pawn`, `weights` or `none`), `weights.<specID>`, `sidegradeBand`, `compareOwned`, `heirloomProtect`, `undesired.<specID>` |
| trade | `rules.<situation>`, `warnAt`, `likelyOnly` |
| messages | `templates.ask`, `templates.offer`, `templates.announce`, `editFirst`, `oneAsk`, `announceChannel`, `autoAsk.enabled`, `autoAsk.delay`, `autoAsk.minGain` |
| window | `columns.<col>`, `compact`, `rowHeight`, `fontSize`, `point`, `size`, `minimized` |
| toast | `enabled`, `minGain`, `duration`, `inCombat`, `sound`, `point` |
| history (global) | `maxGroups` |

**Database.** `schemaVersion = 0` at birth, with the migration runner in place.

**Profiles.** Per-situation profiles are not used, because per-situation settings live inside one profile; the
Profiles page is still shipped. The decision is recorded in `docs/profiles.md`.

### 12.2 Options pages (LibKa0s Options)

| Page | Contents |
|---|---|
| Landing | Logo, TOC notes, slash rows |
| General | Tabs `Master controls` (the standard ten, in order) and `When to show` (the situation grid of §6.1, plus the master auto-open) |
| Feed | Tabs `Quality` (mode, fixed, floor, upgrade override, with a live "current threshold" readout) and `Filters` |
| Comparison | Tabs `Scoring`, `Weights` and `Preferences` |
| Trade | Tabs `Rules` and `Timers` |
| Messages | Tabs `Templates` (token chips, three editors with counters, a live preview), `Sending` and `Auto-ask` |
| Window | Tabs `Columns`, `Layout` and `Toast` |
| Profiles | AceDBOptions |

### 12.3 Slash verbs

- **Reserved verbs** (all standard): `help get set list reset resetall config version debug enable disable perf diagnostics lock unlock profile`.
- **Addon verbs:**

| Verb | Effect |
|---|---|
| `show`, `hide`, `toggle` | Window visibility |
| `test` | Toggle test mode |
| `scan` | Inspect the whole group |
| `clear` | Clear the feed (session drops) |
| `history` | Open the History tab |
| `mine` | Open the My drops tab |
| `compact` | Toggle the compact preset |
| `situation` | Print the situation classifier report |
| `offer <link>` | Open the Offer panel for a bag item |
| `add <link> [player]` | Inject a drop, for development and smoke testing; uses no inspect if the player is not in the group |

With more than 8 commands, `docs/slash-dispatch.md` is required.

### 12.4 Launcher

| Interaction | Effect |
|---|---|
| Left-click | Opens settings |
| Right-click | Menu: Enabled · Locked · Test mode · Show window |

The `ADDONS.md` row is the same.

---

## 13. Diagnostics, perf, debug

**Diagnostics sections** in `modules/Diagnostics.lua`:

| Section | Contents |
|---|---|
| State | Enabled, situation (with inputs), test mode, restriction state, queued sends |
| Feed | Drop count per tab, last loot seen (age plus source), parser hits and misses since login, quality mode with its current threshold per slot (compact) |
| Inspect | Queue length, the job in flight, per-member status and age |
| Gear | Your slots with ilvl and quality |
| Trade | Live timers |
| Scoring | Scorer in use, Pawn presence and scale, pending retries |
| Messaging | Templates' lengths, the one-ask registry size |

**Perf buckets:**
- `parse`
- `feed.add`
- `evaluate`
- `inspect.read`
- `tradeTimer.scan`
- `window.refresh`
- `quality.gate`

Hot paths use Shape A, and multi-exit regions use Shape B.

**Debug tags:** `PARSE`, `FEED`, `EVAL`, `INSPECT`, `TRADE`, `MSG`, `SIT`, `QUAL`, `UI`, `SCORE`. Logging follows
debug-logging-§8.

---

## 14. Deviations and follow-ups

**Documented deviations,** each with a row in ARCHITECTURE.md's `## Documented deviations`:

- The loot parser, the restriction tracker and `Compat.ChatSender` are in-addon, not in LibKa0s (anti-pattern #47 risk). A LibKa0s promotion issue is filed.
- Whispers and addon-sent chat have no standard rule yet. A WowAddonStandards proposal issue is filed.

**GitHub issues to file at the end of the run,** throttled:
- wishlist and BiS tiers
- tier and catalyst flags
- Void Core awareness
- addon comms
- PLH/PLR interop
- Droptimizer import
- loot-spec nudge
- the LootHistory "traded from" link
- the LibKa0s promotion of the loot parser, restriction tracker, ChatSender and tooltip line reader (filed on LibKa0s)
- the standards proposal for chat sending (filed on WowAddonStandards)

---

## 15. Testing strategy

**Headless suites** run under `tests/run.lua` on the vendored kit:

| Suite | Coverage |
|---|---|
| `test_evaluate` | Every equipLoc and slot plan, Titan's Grip, dual wield, the off hand vs 2H case, unique redirection, an empty slot, unknown spec, prefs, the sidegrade band, score disagreement, nil safety |
| `test_quality_gate` | All three modes, the floor, an empty slot, ties, the upgrade override, per-situation override |
| `test_situations` | The classifier truth table for every key, plus the re-evaluation events |
| `test_trade_rules` | Every row in §7.2, plus the owner override and expiry |
| `test_loot_parser` | Every GlobalString variant, cross-realm names, multiple items, bonus roll, pushed, upgrade echo rejected, secret text, PrettyChat-rewritten globals rebuilt |
| `test_messaging` | Token expansion, the length limit, the one-ask guard, queueing under restriction, the flush order, cancel, pcall failure → retry |
| `test_inspect` | The state machine with a mocked clock: spacing, the range wait, timeouts, retries, the foreign-inspect hook, the combat park, cache TTL and invalidation |
| `test_trade_timer` | Line-type read, the localized duration decoder fallback, the warn threshold, the ticker lifecycle |
| `test_feed` | Dedupe across the three sources, encounter grouping, gate ordering (quality before inspect), DropAdded and DropUpdated |
| `test_history` | Caps, outcomes, trade-completion matching |
| `test_scoring` | Pawn adapter with stubbed Pawn (nil → pending → value), the weights import parser, unknown stats |

**Plus** the standard suites: `test_schema`, `test_surface_parity`, `test_vendor_sync`, `test_disabled`, the
migrations, and the kit's `test_eol`, `test_prose`, `test_layout_cap`, `test_diagnostics_contract` and
`test_lizard_sighted`.

**The gate:** `lua tests/run.lua` passes, and `luacheck .` reports 0 warnings and 0 errors.

**The release gate:** the four-suite automated run, plus no function above CCN 15.

**In-game checks** go in `docs/smoke-tests.md`. They are the owner's to run, and are never marked passed by an
agent. The themes:

| Prefix | Theme |
|---|---|
| INSTALL | Installation and load |
| SLASH | Slash commands |
| PANEL | Settings panel |
| PROFILE | Profiles |
| STATE | Enable, disable and state |
| COMBAT | Combat, restrictions, secret values, M+ |
| DIAG | Diagnostics |
| DEGRADED | Degraded mode (no LibKa0s) |
| FEED | The feed |
| INSPECT | Inspection |
| TRADE | Trading, including TRADE-3 for the raid rule |
| ASK | Asking and offering |
| SIT | Situations |
| QUAL | Quality gating |
| LOC | `LOC-1` covers the GlobalString parsing on a deDE or frFR client, the trade-timer decode, and track names coming from the API, not from parsing |

**In-game checks that cover the brainstorm's open questions** (§C of `06_OPEN_QUESTIONS.md`):

| Check | Question |
|---|---|
| COMBAT-1 | Is `CHAT_MSG_LOOT` readable mid-encounter? |
| ASK-4 | Does a whisper from a click work during an encounter? |
| TRADE-3 | The raid rule |
| TRADE-4 | Equipped vs owned for the trade rule |
| FEED-5 | `GetItemUpgradeInfo` on a link that isn't yours |
| FEED-6 | `ENCOUNTER_LOOT_RECEIVED` for the M+ chest |
| INSPECT-4 | Is the tooltip ilvl still needed? |
