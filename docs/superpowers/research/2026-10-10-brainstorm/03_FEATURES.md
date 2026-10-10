# 03: Features

Each feature is tagged with the tier it belongs to:

| Tier | Meaning |
|---|---|
| **MVP** | v0.1, the first build the owner can play with |
| **v1** | The first public release |
| **Later** | A backlog candidate |

## Part A: the owner's nine features

### F1. Track and show every group drop, with thresholds (MVP)

- **Sources:** `CHAT_MSG_LOOT` first, then `ENCOUNTER_LOOT_RECEIVED`, then `C_LootHistory` winners, merged by the dedupe key.
- **Thresholds:**
  - Minimum quality (default Rare).
  - Minimum ilvl, either absolute or "within N of my equipped item".
  - Gear only (armour, weapons, jewellery and trinkets), with an option to include tier tokens.
  - Content filter: party, raid, LFR and open world, each toggled separately (WGL had raid and LFR switches).
  - "Hide items nobody can use", "only show upgrades for me" and "only show what is likely tradeable".
- **Two view modes:**
  - **All drops**: the whole feed.
  - **Interesting**: upgrades for you, plus drops where the looter has a downgrade and the item can be traded.
- **Lifetime:** rows persist for the session and are grouped by encounter or run. Dismissing a row is per row. *Clear on boss kill* is optional; DYNT does this.

### F2. Compare with your equipment (MVP)

- **Slot plan** (the WGL design, fixed):
  - single slot
  - lowest of two for rings, trinkets and one-handers for dual-wield specs
  - average of main hand and off hand for a 2H
  - Titan's Grip
  - unique-equipped redirection
  - **Off hand or shield for a 2H user** is compared against the 2H, not against an empty slot. This fixes WGL's false "upgrade".
- **Owned, not just equipped.** Optionally compare against your best *owned* item for the slot, bags included. This makes "is it an upgrade" honest, and it matches the trade rule (Tradable's insight).
- Heirloom protection while levelling (WGL).

### F3. Compare with the looter's equipment (MVP)

- The inspect broker (see `04_HIGH_LEVEL_DESIGN.md` §4).
- Verdict for the looter: **Upgrade / Sidegrade / Downgrade / Can't use / Unknown**.
- **Colours are inverted for the looter**, as in WGL: their downgrade is good news for you, so it shows green.
- **Inspect age label:** fresh, cached 3m, or unavailable with a reason such as "out of range".
- A **Scan group** button and verb inspect the whole group before a pull (DYNI).

### F4. Upgrade verdict by item level (MVP)

- `delta = candidate ilvl − replaced ilvl`.
- **Sidegrade band:** |delta| ≤ *N* (default 0). With scoring on (F5) the band is widened by score.
- Also show the **track delta**, for example `Champion 6/6 → Hero 2/6`. The ilvl may be the same while the upgrade ceiling is higher. A change of rank *within* one track is shown too; WGL hides it.

### F5. Stats, optional, with comparison (v1)

- A stat line on the detail card shows `+130 Haste −119 Mastery`, **for both you and the looter** (WGL shows only yours).
- **Scoring source**, chosen in this order:
  1. Pawn, if installed and a scale is visible.
  2. Built-in weights per spec, with editable presets and an import string.
  3. None, which means ilvl only.
- **Score verdict:**
  - The verdict becomes `+2.4%` (Pawn) or `+38 score`.
  - A **sidegrade** is shown when the ilvl difference is ≤ 0 but the score difference is > 0, or when the ilvl rises but the score falls.
- Effects, sockets and tertiary stats (Leech, Avoidance, Speed, Indestructible) are flagged, not scored, unless the weights cover them.

### F6. Your own drops: an upgrade for you, or for someone in the group? (MVP)

- **The My drops tab:** one row per drop you looted in this session.
  - If the drop is **not** an upgrade for you, it lists the group members it would upgrade, ranked by gain.
  - Each candidate shows class colour, `equipped → candidate` and a status pill.
- **The Offer panel:** a WGL "Who could use this?" panel, extended to **raids**. It shows the top N candidates and can be scrolled.
- **Gated by tradeability:** if your copy has no trade timer, the panel says so and offers nothing.

### F7. Whether the looter can trade it (MVP; exact timer v1)

- **Someone else's drop:** an estimate in four states with the reason on hover.

  | State | When | Example reason |
  |---|---|---|
  | **Yes** | BoE, or confirmed by comms (Later) | "Bind on equip" |
  | **Likely** | BoP under personal loot and the drop is ≤ the looter's ilvl in that slot | "Not an upgrade for Séta (311 ≤ 324)" |
  | **Unknown** | No inspect, or the rule is unknown for this content | "Couldn't inspect: out of range" |
  | **No** | Warbound, bonus roll, an upgrade for the looter under personal loot, or past 2 hours | "Bonus roll loot is never tradeable" |

- **Your own drop:** the **exact countdown** from the tooltip line type, plus a warning when it reaches 10 minutes (configurable).

### F8. Quick messages: ask for a trade, offer your loot (MVP)

- **Templates** with tokens: `{player}`, `{item}`, `{ilvl}`, `{slot}`, `{track}`, `{gain}`, `{mygain}`.
- **Three default templates:**
  - Ask: "Hi {player}, if you don't need {item}, could I have it? It'd be +{mygain} for me. No worries if not!"
  - Offer, sent to a person: "Hi {player}, {item} is tradeable and looks like +{gain} for you. Want it?"
  - Announce, sent to group chat: "{item} is up for grabs, whisper me."
- **Guards:**
  - One ask per item per looter. The button changes to "Asked ✓" afterwards.
  - Asks and offers are **queued while restricted**: "Queued: sends after the encounter."
  - Every send goes through `pcall`, and a failed send stays retryable.
  - Messages are length-checked against 255.
  - Cross-realm whispers use Name-Realm (WGL bug fixed).
- **Auto-ask is off by default (v1).** When on, it waits N seconds after the encounter ends and is cancelled if the looter leaves or if you asked manually.
- **Trade button:** shown when in range and out of combat.
  - On your own drop, it finds the bag slot by GUID, then picks up the item and calls `DropItemOnUnit` (WGL).
  - On someone else's drop it shows "Trade" (`InitiateTrade`), so they can place the item.

### F9. Equippability (MVP)

- **Primary check:** `C_Item.GetItemSpecInfo(link)` must contain the candidate's spec. This covers armour type, weapon type, shields, off hands and primary stat in one call.
- **Fallback before the looter's spec is known:** a class table for armour type and weapon proficiency. This is the same table used for the pre-inspect gate.
- **Your own preferences:** "undesired types" per spec, for example a Fury warrior who never wants a 1H, or a caster who wants no off hand because they use a staff. The check reports *can't* and *won't* separately: "Can't use" vs "Doesn't want".
- Tier tokens map to the class list given by `IsItemSpecificToPlayerClass` or spec info.
- **Must never throw.** An unknown or unspecced character gives "Unknown", never `error()`.

## Part B: extra features worth adding

The ranking reflects value and fit, highest first.

| # | Feature | Tier | Why | Inspired by |
|---|---|---|---|---|
| X1 | **Restriction indicator and send queue** | MVP | Without it, Ask fails silently mid-encounter. | Loothing, RCLC, PLT comments |
| X2 | **Test mode** with placeholder drops in every state | MVP | Required by the Ka0s preview-mode rule, and the best way to check the UI. | WGL `/wgl test`, DYNI |
| X3 | **Scan group** and the inspect age badge | MVP | Inspect is range- and combat-limited, so freshness should be visible. | DYNI, Midnight Upgrade Calculator |
| X4 | **Diagnostics section**: last loot seen, parser hits and misses, inspect queue, restriction state, Pawn status | MVP | Silent failure is the top complaint about PLH. | PLH comments |
| X5 | **Separate trade rules for raid and M+** | MVP | Raid and M+ may trade differently. | Survey gap |
| X6 | **Trade countdown on your own items, plus a bag-wide "tradeable now" list** | v1 | Nobody shows it, and an expired window loses the item. | AdiBags-TradeableLoot (dead) |
| X7 | **"Looter likely to give" score**: their ilvl in the slot, stat fit, a duplicate unique item, already-owned copies | v1 | Sorts the feed by who is most worth asking. | Loot Ratter, PLH |
| X8 | **History grouped by encounter or run**, with outcomes (asked, received, declined, expired) | v1 | Context afterwards. Stored capped in `DB.global`. | DYNI, LootHistory |
| X9 | **Toast** for a big upgrade or a wishlisted item, opt-in, with a sound | v1 | One loud signal in an otherwise quiet feed. | ZolLoot, KeystoneLoot |
| X10 | **Transmog flag and a "for transmog" ask** (Can I Mog It API if present, otherwise `C_TransmogCollection`) | v1 | PLH and PLR request types include transmog, and players ask for it. | PLH, PLR, CIMI |
| X11 | **Tier and catalyst flag** ("gives 2-piece", "can be catalysed to tier") | Later | Tier is worth more than raw ilvl. | ZolLoot, KeystoneLoot |
| X12 | **Wishlist** with tiers (BiS, Need, Nice, Mog), a minimum track, an alert when a groupmate loots one, and Adventure Guide stars | Later | The most valued planning feature in the survey. | KeystoneLoot, Beggar, ZolLoot |
| X13 | **Droptimizer or SimC import** for a "% DPS" column | Later | The strongest signal beyond weights. | LootPlanner, RCLC-wowaudit, cttLoot |
| X14 | **Addon comms** between users of this addon: confirmed trade timers, "I'll trade it", and asks that resolve without whispers | Later | Turns *Likely* into *Yes*. Blocked during encounters, so queue it. | PLH, PLR |
| X15 | **PLH or PLR protocol interop**, read-only at first | Later | Instant reach into an installed base of about 3M. Legal check on licences needed. | PLR |
| X16 | **Void Core and bonus-roll awareness** | Later | Bonus-roll loot can't be traded, so it confuses feeds. | KeystoneLoot, Beggar |
| X17 | **Loot-spec nudge** on entering an instance | Later | Cheap, and liked by KeystoneLoot users. Risk of scope creep. | KeystoneLoot |
| X18 | **"Post my tradeables"**: one click lists what you can trade, in group chat | v1 | Lets you advertise loot ahead of time. | Tradable, PLT |
| X19 | **Ka0s LootHistory link**: received trades are recorded as "Traded from X" | Later | A synergy within the collection. | — |
| X20 | **Mute when solo or in open world** | MVP (setting) | Low noise. | WGL raid and LFR toggles |

**Deliberately out of scope:**
- Loot council, voting, EPGP and GDKP: that is RCLC's and Gargul's territory.
- Auto role check, teleports and other scope creep: KeystoneLoot's comments show how badly that goes down.

## Part C: tier summary

- **MVP (v0.1):** F1, F2, F3, F4, F6, F7 (estimate), F8 (manual plus queue), F9; X1–X5, X20; the full Ka0s scaffold.
- **v1 (public):** F5 (stats, Pawn and weights, sidegrades), F7 (exact own timer), auto-ask, X6–X10, X18.
- **Later:** X11–X17, X19.
