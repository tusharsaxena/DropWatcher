# 04: High-level design

The working name in this document is **`<Addon>`**, with slash `/<x>`. The name is chosen in `05_NAMES.md`.
Everything below conforms to the Ka0s WoW Addon Standard (v2.78.2), and LibKa0s v1.71.0 is the vendored
library. The compliance details are in `inputs/ka0s-standard-summary.md`.

## 1. Principles

1. **The kernel is pure; the edges hold the WoW calls.** Evaluation, the trade estimate and template
   expansion are plain Lua over plain tables, so headless tests can cover them exhaustively.
2. **Never throw on game data.** Every unknown (spec, stat key, secret value, uncached item) maps to an
   `Unknown` state that carries a reason.
3. **Be honest in the UI.** Every verdict has a reason on hover. The UI shows how old the inspect data is
   and whether chat sends are currently restricted.
4. **Stay quiet by default.** A docked feed. Toasts, auto-ask and sound are opt-in.
5. **Work in every locale.** Use GlobalString patterns, tooltip *line types*, item-link data and IDs. Never
   match English text.

## 2. Module map

The folder layout follows layout-§1. Load order: libs, then locales, core, defaults, modules, settings.

```
core/      Namespace, Compat, MediaSetup, Constants, State, EnvSetup, CoreSetup, PoolSetup, ItemSetup,
           PerfSetup, DebugLogSetup, LauncherSetup, LifecycleSetup, WidgetsSetup, Bus, <Addon>.lua, Database
defaults/  Profile.lua, Global.lua
modules/
  Restrictions.lua   ADDON_RESTRICTION_STATE_CHANGED, InChatMessagingLockdown, InCombatLockdown → one state + bus msgs
  Roster.lua         group members: GUID, Name-Realm, classFile, unit token, spec (once inspected); GROUP_ROSTER_UPDATE
  LootParser.lua     GlobalString patterns → {looterGUID, name, link, qty, kind=normal|bonus|pushed|upgradeEcho}
  LootFeed.lua       merges CHAT_MSG_LOOT + ENCOUNTER_LOOT_RECEIVED + C_LootHistory; dedupe; encounter/run grouping
  Inspect.lua        the inspect broker (§4)
  Gear.lua           my equipped + owned-best-per-slot snapshot; cached, invalidated on PLAYER_EQUIPMENT_CHANGED/BAG_UPDATE_DELAYED
  ItemFacts.lua      link → facts {ilvl, equipLoc, classID/subclassID, bindType, warbound, track, stats, specs, setID, unique}
  Evaluate.lua       PURE kernel: equippability, slot plan, deltas, verdict (§3)
  Scoring.lua        adapters: PawnAdapter | WeightsAdapter | NoneAdapter → score(itemFacts, specKey)
  TradeRules.lua     PURE: data-driven eligibility estimator by content type (§5)
  TradeTimer.lua     own items' TradeTimeRemaining via C_TooltipInfo line type; ticking countdowns; expiry warnings
  TradeHelper.lua    bag slot by GUID → PickupContainerItem + DropItemOnUnit; InitiateTrade; range/combat guards
  Messaging.lua      templates, tokens, one-ask guard, restriction queue, pcall send via Compat.ChatSender
  History.lua        capped session/run log in <Addon>DB.global (owner module for recorded data)
  Window.lua         main table window (§6)
  DetailCard.lua     expanded row: tracks, stat lines both sides, verdict reasons
  OfferPanel.lua     "Who could use this?" for my drops (party + raid)
  Toast.lua          opt-in alert (v1)
  TestMode.lua       placeholder drops covering every state
  Diagnostics.lua    required diagnostics sections
settings/  Schema, Slash, OptionsSetup, General, Feed, Comparison, Trade, Messages, Window, Profiles
locales/   enUS.lua (+ gated others)
media/     logos/, (icons come from the LibKa0s catalog)
tests/     run.lua, wow_mock.lua, test_*.lua, perf.lua, _kit/
docs/      ARCHITECTURE.md, testing.md, smoke-tests.md, Tier 1 set, debug.md, midnight-quirks.md, compat-layer.md, ...
```

**Bus messages,** named `Ka0s_<Addon>_<Event>`, one sender each:

| Message | Sent when |
|---|---|
| `DropAdded` | A drop enters the feed |
| `DropUpdated` | A verdict, inspect result or trade state changes |
| `InspectDone` | An inspect job completes |
| `GearChanged` | Your own gear changes |
| `RestrictionChanged` | A restriction turns on or off |
| `AskQueued` / `AskSent` | An ask is queued, then sent |
| `TradeTimerTick` | A trade countdown ticks |
| `TradeTimerExpiring` | A trade countdown nears expiry |

The UI modules only listen to the bus. They never call the engine modules directly.

## 3. The evaluation kernel (`Evaluate.lua`, pure)

**Input**

```lua
Evaluate.Run(itemFacts, candidate, opts)
-- candidate = { classFile, specID|nil, gear = {[slot]=itemFacts|false}, owned = {[slot]=itemFacts}|nil,
--               dualWield=bool, titanGrip=bool, prefs = {undesired = {...}} }
-- opts      = { sidegradeBand = 0, scorer = fn|nil, compareOwned = bool }
```

**Steps**

1. **Equippability.**
   - If the spec is known, check that `itemFacts.specs` contains the specID.
   - If the spec is unknown, check the class proficiency table.
   - Separately, check the owner's preferences ("Doesn't want").
   - Possible results: `ok`, `cant`, `doesntWant` or `unknown`.
2. **Slot plan.**
   - `single`.
   - `lowest` for rings, trinkets, and one-handers for dual-wield specs.
   - `aggregate` for a 2H against main hand plus off hand.
   - `vsTwoHand` for an off hand or shield when the candidate wields a 2H.
   - A unique-equipped redirect.
3. **Deltas.** Compute `ilvlDelta`, `trackDelta` (track rank across tracks) and `scoreDelta` (only if a scorer is present).
4. **Verdict.**
   - Possible verdicts: `upgrade`, `sidegrade`, `downgrade`, `cantUse` or `unknown`.
   - Each verdict carries `reasons = {...}`, a list of locale keys plus arguments, rendered by the UI.

**Outputs that matter downstream**

- `forMe`: Evaluate.Run(item, me).
- `forLooter`: Evaluate.Run(item, looter).
- `candidates`: for each group member, Evaluate.Run(item, member). Used only for your own drops and the Offer panel.

The kernel is fully covered by table-driven tests:
- every equip location, including the 2H and off hand edge cases
- Titan's Grip
- unique-equipped redirection
- an unknown spec
- an empty slot
- secret-value inputs

## 4. Inspect broker (`Inspect.lua`)

This adopts WhoGotLoots' design and fixes its gaps. There is no Ka0s precedent for an inspect broker.

- **Jobs.** One job per GUID, fanned out to every row waiting on it. The job's generation token cancels stale callbacks.
- **Queue.**
  - One `NotifyInspect` in flight at a time, spaced at least 2s apart.
  - Gated by `CanInspect`, by range, and by `not InCombatLockdown()`.
  - **Parked during combat** and resumed on `PLAYER_REGEN_ENABLED`.
  - Not called while the player's own Inspect frame is open.
- **Reading.**
  - After `INSPECT_READY(guid)`, read slots 1–17 with `GetInventoryItemLink`.
  - Take the ilvl from the tooltip's ItemLevel line.
  - Take the spec from `GetInspectSpecialization`.
  - Retry while links are incomplete.
  - Finish with `ClearInspectPlayer`, but only if this addon started the inspect.
- **Courtesy.** `hooksecurefunc("NotifyInspect")` re-queues the addon's job when another addon or the player inspects. When that foreign inspect returns `INSPECT_READY`, the addon reads the data opportunistically.
- **Cache.**
  - Snapshots are keyed by GUID with a timestamp and kept in memory only.
  - TTL is 10 minutes.
  - Invalidated on `UNIT_INVENTORY_CHANGED` for group units.
- **Warm-up.**
  - After a roster change, and on entering an instance, inspect the whole group when idle.
  - The **Scan group** verb and button do the same on demand.
- **Status per job:** `fresh`, `cached(age)`, `pending`, `outOfRange`, `combatParked` or `failed(reason)`. The UI shows it.
- **Fast path.** If the link data for the unit is already client-cached, the job completes with no inspect.

## 5. Trade estimator (`TradeRules.lua`, pure) and own timers

**The rules table** is keyed by content type and loot mode:

```lua
RULES = {
  personal = { window = 7200, ilvlRule = "notUpgradeForLooter", compareOwned = "equipped" },
  group    = { window = 7200, ilvlRule = "none" },          -- to be verified for Midnight raids
  legacy   = { tradeable = false },
}
```

**`Estimate(itemFacts, looterEval, context)`** returns `{state = Yes|Likely|Unknown|No, reason, expiresAt|nil}`.

- `No`: warbound or account-bound, bonus roll, a looter upgrade under `notUpgradeForLooter`, or past the window.
- `Yes`: BoE, an own item with a tooltip timer, or (later) confirmed through comms.
- `Likely`: passes the rule, but only on inspect data.
- `Unknown`: no inspect, no rule for the content type, or a secret input.

**Own items.** `TradeTimer.lua` scans your bags on `BAG_UPDATE_DELAYED`, throttled, and reads the
`TradeTimeRemaining` line type. It keeps `expiresAt` per item GUID, refreshed every minute on one shared
`C_Timer` ticker that runs only while at least one timer is live. At the warning threshold it sends
`TradeTimerExpiring`.

## 6. UI

### Main window: DoYouNeedThat layout with the Ka0s skin

```
┌──────────────────────────────────────────────────────────────────────────────┐
│ ◆ <Addon>        [Group drops] [My drops]       🔒2 queued  ⟳ scan   –  ×    │  30px title bar, gold title
├──────────────────────────────────────────────────────────────────────────────┤
│ Item  Ilvl  Looter        Their eq    Me       Them      Trade     ▸ Actions │
│ [▣]   311   Séta          [▣]         +19 ▲    −23 ▽     Likely    [Ask]  ×  │  24px rows, pooled
│ [▣]   298   Littlewolfe   [▣][▣]      +4  ≈    +12 ▲     No        [ — ]  ×  │
│ [▣]   305   Uniquerogue   [?] 3m      can't    —         Unknown   [Ask]  ×  │
│ ── Boss: Xal'thar the Venomous (Heroic) ─────────────────────────────────────│  encounter separator
│ …                                                                            │
└──────────────────────────────────────────────────────────────────────────────┘
```

- **Skin.**
  - `NS.ApplySkin` gives a flat dark background, a 1px black border, an inner highlight and a gold title.
  - The 30px title bar is the drag handle and holds a divider.
  - The close button is `NS.MakeCloseButton`, and it can be resized with `NS.MakeResizable`.
  - Position and size persist, and the window is registered in `UISpecialFrames`.
- **DoYouNeedThat traits kept:**
  - dense 24px rows with a faint row tint
  - item icons with quality-coloured borders that act as real item buttons: tooltip, shift-click to link, ctrl-click to dress up
  - class-coloured looter names
  - "their equipped" icons, two for rings, trinkets and dual wield
  - a blue Ask pill and a red dismiss `×`
  - a minimise control that collapses the window to the title bar
- **Columns.** The verdict columns show a short signed number plus a glyph: ▲ upgrade, ≈ sidegrade, ▽ downgrade.
  - When scoring is on, the hover shows `+2.4%` or the score.
  - The looter's colours are inverted.
  - Columns can be toggled from the Window settings page, with a **compact** preset (Item, Ilvl, Looter, Their eq, Ask) that matches DYNT exactly.
- **Rows.**
  - Clicking a row expands its **detail card** inline (WGL information):
    - the tracks for you and the looter
    - stat lines for both sides
    - the reason for each verdict
    - the trade reason
    - the inspect age
    - a Retry inspect action
  - Sort by newest first (the default), by gain for me, or by ilvl.
- **Restriction badge.** A lock icon plus the number of queued sends, with a tooltip that explains which restriction is active.
- **My drops tab.** Columns: Item, Ilvl, For me, Trade timer (live countdown), and Best candidates (the top three class-coloured names with their gains). The actions are **Offer…** (opens the Offer panel), **Announce** and **Trade** (shown when a candidate is selected and in range).

### Offer panel ("Who could use this?")

- Anchored to the window or floating.
- Item header showing your ilvl delta and the trade countdown.
- One row per candidate: class stripe, name, `equipped → candidate`, a status pill (UPGRADE +14, EQUAL, NO UPGRADE, CAN'T USE, CHECKING…, UNAVAILABLE), **Whisper offer** and **Trade**.
- Works in raids: rows scroll, and the list is sorted by gain and then by inspect freshness.

### Toast (v1, opt-in)

- One small skinned frame: "Big upgrade for you: [item] looted by Séta (+19, Likely tradeable). [Ask] [×]".
- One at a time, with the rest queued. It is never shown in combat unless the owner opts in.

### Visual tokens

Everything comes from LibKa0s:
- the skin colours (`Core.lua:90-105`)
- gold accents
- `GameFont*`, with JetBrains Mono only for any monospace numbers column if wanted
- icons from the catalog: lock, refresh, close, chevrons and so on. Any missing icon is added upstream in LibKa0s (#63).

The coral DYNT title is shown only if the owner chooses it (06 §B1).

## 7. Settings (LibKa0s Options)

**Landing page:** the logo, the TOC Notes and the slash-command rows.

**Pages**, each built with `RenderTabbedSchema`:

| Page | Tabs and settings |
|---|---|
| **General** | **Master controls**: Enable, General visibility, Scale, Alpha, Lock frame, Debug console, Minimap button, Test mode, Reset position, Reset all. A **When to show** tab: party, raid, LFR, delves, open world, and auto-open on loot. |
| **Feed** | Thresholds: quality, ilvl floor, gear only, tier tokens. Content filters. View mode (All or Interesting). Lifetime and clear on boss kill. Sort. |
| **Comparison** | Scoring source (Pawn, weights or none). Weights editor and import. Sidegrade band. Compare against owned items. Heirloom protection. Undesired types per spec (an `IdList`-style editor). |
| **Trade** | Rule table view (read-only plus overrides). Countdown warning threshold. Trade-button behaviour. |
| **Messages** | Ask, Offer and Announce templates with a token legend and a live preview. Auto-ask (off) with its delay. Announce channel. |
| **Window** | Column toggles, compact preset, row height, font size. Toast (v1). |
| **Profiles** | AceDBOptions. Per-content profiles are a SHOULD for group addons (savedvariables-§3). |

## 8. Slash commands (LibKa0s Slash)

- **Short and long forms:** `/<x>` and `/<addonname>`. The bare command opens settings.
- **Reserved verbs:** `help get set list reset resetall config version debug enable disable perf diagnostics lock unlock profile`.
- **Addon verbs:**

  | Verb | Effect |
  |---|---|
  | `show`, `hide`, `toggle` | Window visibility |
  | `test` | Test mode |
  | `scan` | Inspect the whole group |
  | `clear` | Clear the feed |
  | `history` | Show the history view |
  | `offer <link>` | Open the Offer panel for an item |
  | `add <link> [player]` | Inject a fake drop, for development and smoke testing |

  With 8 or more verbs the Tier-2 doc `docs/slash-dispatch.md` is required.

## 9. Ka0s compliance and upstream opportunities

**Launcher.** Enabled · Locked · Test mode · Show window. Left-click opens settings; right-click opens the
menu. This is also the row added to `ADDONS.md`.

**Saved variables.**
- Only `<Addon>DB` and `<Addon>PerfDB`.
- History lives in `<Addon>DB.global`, capped, for example the last 20 encounters or runs.
- `schemaVersion = 0`, with the migration runner in `core/Database.lua`.

**Perf.** `CHAT_MSG_LOOT` and `UNIT_INVENTORY_CHANGED` run in combat, so the addon is **not** exempt.
Use Perf buckets for:
- `parse`
- `evaluate`
- `inspect.read`
- `tradeTimer.scan`
- `window.refresh`

**Required docs.**
- The usual set: README, CLAUDE.md stub, DEPENDENCIES.md, the `docs/` trio and Tier 1.
- Tier 2 docs triggered by this addon: `debug.md`, `slash-dispatch.md`, `midnight-quirks.md` (restrictions and secret values) and `compat-layer.md`.
  - `compat-layer.md` is triggered by `ChatSender`, the tooltip line-type fallbacks and the Pawn seam.
- `message-bus.md` only if there are more than 10 messages.

**Tests.**
- The kit's mandatory suites.
- Table-driven suites for `Evaluate`, `TradeRules`, `LootParser` (every GlobalString variant, cross-realm names, upgrade echoes, bonus roll, secret text) and `Messaging` (tokens, length, the queue under restriction).
- Suites for the `Inspect` broker state machine (timeouts, the foreign-inspect hook, combat park) and `TradeTimer` (decoding, expiry).

**New ground with no standard rule yet.** Record each of these in ARCHITECTURE.md, and propose them upstream in WowAddonStandards:
- whisper and chat sending under restrictions
- the inspect broker
- addon comms (later)

**LibKa0s promotion candidates.** Each now has two or more consumers, or is likely to:

| Candidate | Why |
|---|---|
| A **loot-chat parser** (LootHistory's self-loot parser, generalised to any looter) | Two consumers. Possible surface: `LibKa0s-Loot-1.0`, or an extension of `Item-1.0`. |
| A **restriction-state tracker** (`ADDON_RESTRICTION_STATE_CHANGED` plus chat lockdown) | Useful to MultiMeters, PrettyChat and others. Could live in `Compat-1.0` or a new module. |
| **`Compat.ChatSender`** | MultiMeters already has it, and this addon would be the second consumer. |
| A **tooltip line-type reader** | Used for the trade timer, the upgrade track and the ilvl line. LootHistory and ConsumableMaster scan tooltips too. |

Per anti-pattern #47, the addon should consume these from LibKa0s rather than copy them. The recommended
order is to land the parser and the restriction tracker in LibKa0s first, as a small cross-repo bundle in
this repository, and then scaffold the addon.

## 10. Risks

| Risk | Mitigation |
|---|---|
| Loot chat becomes secret mid-encounter | `issecretvalue` guards; fall back to `ENCOUNTER_LOOT_RECEIVED` and `C_LootHistory`; buffer and resolve after `ENCOUNTER_END`. |
| Whispers blocked mid-encounter | The queue, plus the badge. |
| Raid trade rule wrong | The rules table is data; verify in game before v1; the Unknown state is honest. |
| Inspect starvation in a 20-player raid | Prioritise looters of interesting drops over warm-up jobs; a cache; opportunistic reads of foreign inspects. |
| Pawn is slow or returns nil | Retry on a timer; show "…" until the result arrives; budget calls. |
| Scope creep (the KeystoneLoot lesson) | Tiered roadmap; every new behaviour opt-in. |
| Licensing | Borrow *ideas* from DYNI (attribution and reward licence) and Pawn (CC BY-NC-ND), never code. RCLC's licence was not checked: treat its locale duration decoder as an idea to re-implement, not code to copy. |
