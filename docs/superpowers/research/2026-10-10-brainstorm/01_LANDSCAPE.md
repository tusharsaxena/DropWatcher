# 01: Landscape

The evidence is in `inputs/`:
- `whogotloots-source-analysis.md`: a full source read of v1.8.2
- `doyouneedthat-and-wow-api-research.md`: the DoYouNeedThat source, comparable addons and the APIs
- `curseforge-market-survey.md`: 24 addons with URLs, dates and download counts

## 1. The two reference addons

### DoYouNeedThat (DYNT): the look you like

- **Status:** v1.1.7, last released 2020-11-23 (Interface 90002), about 26K downloads. Abandoned. Source at https://github.com/kraffslol/DoYouNeedThat. About 1,100 lines, no Ace3, uses LibInspect.
- **How it works.** It listens to `CHAT_MSG_LOOT` inside instances. It shows only drops that are useful to *you*: equippable for your class, with an ilvl at least your equipped ilvl minus a 0–30 slider. Each row shows the looter's equipped item in that slot. A **Whisper** button sends "Do you need [item]?". The list clears on each boss kill.
- **No tradeability check, no comms, no Pawn.** All three were on its TODO list.
- **What makes the look:**
  - a flat `WHITE8x8` backdrop, about 0.8 alpha black, with a 1px black border
  - a 24px header with a coral `#FF6B6B` title, a minimise `-` and a red `x`
  - Roboto Medium at 11, 12 and 14 pt with a drop shadow
  - columns Item | Ilvl | Looter | Looter Eq
  - 24px rows with a faint white tint and 20px item icons with quality-coloured borders
  - a blue `Whisper` pill and a red `x` dismiss button on every row
  - a slim skinned scrollbar
  - The style is dense and calm, and can be read at a glance.
- **Note:** most of this matches the Ka0s skin already (`LibKa0s Core.lua:90-105`: flat dark background, 1px black edge). The real difference is the title colour (coral vs Ka0s gold) and the font. JetBrains Mono is the only face Ka0s ships; everything else uses `GameFont*`.

### WhoGotLoots (WGL): the function you like

- **Status:** v1.8.2, Interface 120007, about 6,700 lines, no libraries.
- **Two surfaces.**
  - **Loot cards**, pooled, each with a 60s life that pauses on hover. A card shows:
    - the `ASK  YOU +19 / LOOTER -23` takeaway, with the looter's sign colour inverted
    - `YOU TRACK Champion 1/6 → Hero 3/6`
    - stat chips (`+130 Haste −119 Mastery`)
    - badges and a "Try Inspect" retry
  - **"Who could use this? Your drop"**: for your own drop that is not an upgrade, it shows each party member's `equipped > candidate` ilvl, a status pill and a trade button.
- **The best part is the inspect broker** (`CacheHandler.lua`):
  - one job per player identity, fanned out to many waiting cards
  - `NotifyInspect` spaced at least 2s apart, with timeouts and retries
  - it yields to other addons through `hooksecurefunc("NotifyInspect")`
  - roster warm-ups at 0.5, 2 and 5 seconds and then every 60 seconds
  - a 600s cache, invalidated on `UNIT_INVENTORY_CHANGED`
  - ilvl read from `C_TooltipInfo.GetInventoryItem` because inspected links show unscaled levels
- **The second best part is the slot replacement plan:**
  - single, lowest-of-two, or the average of main hand and off hand for 2H
  - the Titan's Grip special case
  - redirection for unique-equipped items
- **The trade helper:** find the exact bag slot by item GUID, then `PickupContainerItem` and `C_Item.DropItemOnUnit`.
- **Bugs and gaps to avoid:**
  - "Is BoP" actually calls `IsItemBindToAccountUntilEquip`.
  - There is no real trade-timer detection.
  - The cross-realm whisper on cards drops the realm.
  - Hard `error()` calls inside `ContinueOnItemLoad` kill cards for unspecced characters or unknown stat keys.
  - An off-hand compared against an empty off-hand slot (when the looter uses a 2H) shows a huge false upgrade.
  - Stat chips are always computed against *your* gear, even on someone else's card.
  - The group panel only works in parties, not raids.
  - Upgrade-track parsing is English-only, and there is no Devourer Demon Hunter spec.
  - The `CHAT_MSG_LOOT` text is never checked for secret values.

## 2. The wider market (Retail, Midnight 12.1.x)

| Addon | Downloads | Last update | Why it matters |
|---|---|---|---|
| Personal Loot Helper (PLH) | 2.71M | 2026-09-05 | The incumbent. Keep or Offer, Main/Off/Transmog requests, an addon-comms protocol and a one-whisper guard. Parses localised tooltips, so it breaks on es/de clients, and went 8 months without a Midnight update. |
| PersoLootRoll (PLR) | 303K | 2026-09-16 | The most complete: Need/Greed on tradeable loot, Pawn filter, transmog flag, follow-and-trade and an action list. Speaks PLH's protocol and falls back to whispers. Had a 3-month Midnight gap. |
| Personal Loot Trader | 67K | 2026-08-16 | Offers your own loot by /roll. Its comments confirm that the looter during an encounter is a **secret value**, causing taint, and that `CheckInteractDistance` is blocked in combat. |
| **Do You Need It?** (DYNI) | 849 | 2026-10-04 | The closest modern peer. **Four-state trade verdict** (Yes, Likely, Unknown, No), a "Cached" inspect label, `/dyni scan`, delayed auto-whisper off by default, history of 50 drops, a test mode and 10 locales. **Its licence demands reward sharing for substantial reuse, so borrow ideas, never code.** |
| Loot It Forward | 1.0K | 2026-08-12 | The offer direction: ranks party members your drop would upgrade, with Whisper and Trade buttons. Party only, no raids. |
| Loot Ratter | 406 | 2026-05 | An end-of-encounter summary showing the looter in red when they likely need the item. |
| Beggar | 22 | 2026-09 | A wishlist with a **minimum upgrade track**, and templates with `%item% %player% %track%`. |
| ZolLoot | 42 | 2026-09 | S, A and B marks on the season's loot, stat-pair filters, and an alert when a groupmate loots a marked item. |
| KeystoneLoot | 5.19M | 2026-10-03 | Five favourite tiers, Void Core (bonus roll) tracking, a loot-spec reminder and group-favourite suggestions. Commenters complain about scope creep and invasive defaults. |
| Easy Gear Upgrade | 5.0K | 2026-03 | Upgrade arrows, **sidegrades for on-use or on-equip items**, and weighted secondary stats. |
| Tradable | 110 | 2026-09 | Your highest ilvl per slot vs a target, answering "can I trade this?". Shows that trade eligibility depends on what you *own*, not only what you have equipped. |
| Midnight Upgrade Calculator | 2.0K | 2026-03 | A group tab built on inspect: each member's ilvl and missing upgrades. |
| LootPlanner | n/a | 2026-08-20 | Per-slot wishlist, with SimC and **Droptimizer** import (experimental). |
| Loothing | n/a | 2026-10-09 | A Midnight-only council that tracks trade timers and **queues messages during boss fights**, replaying them afterwards. |
| RCLootCouncil (+ wowaudit, cttLoot) | 33.9M | 2026-08-31 | The raid standard. `GetContainerItemTradeTimeRemaining` (locale-safe, all 11 locales) and `CommsRestrictions.lua` are the models to study. |
| Gargul, Better Loot Window, RPGLootFeed, Can I Mog It, Transmog Upgrade Master, Loon BiS, SpecBisTooltip | various | 12.1.0 | Adjacent: loot feeds, raid distribution, BiS and transmog state. |

The full list, with URLs, the classic-only and dead addons that were excluded, and comment-thread notes, is
in `inputs/curseforge-market-survey.md`.

## 3. Feature matrix (condensed)

Key: Y = yes, P = partial, N = no. **New** is the proposed addon.

| Feature | WGL | DYNT | PLH | PLR | DYNI | LIF | New |
|---|---|---|---|---|---|---|---|
| Group drop feed | Y | Y | P | Y | Y | N | **Y** |
| Your-upgrade check | Y | Y | Y | Y | P | N | **Y** |
| Looter-upgrade check (inspect) | Y | P (shows gear) | Y | Y | Y | Y | **Y** |
| Stat compare | Y (vs you only) | N | N | P | N | N | **Y (both sides)** |
| Stat weights or Pawn | N | N | N | Y (Pawn) | N | N | **Y** |
| Sidegrade verdict | N | N | N | N | N | N | **Y** |
| Upgrade-track compare | Y | N | N | N | N | N | **Y** |
| Equippability | Y | Y | Y | Y | Y | Y | **Y** |
| Trade estimate (honest states) | N | N | P | P | Y | P | **Y** |
| Exact trade countdown for own items | N | N | P | ? | N | N | **Y** |
| Ask (whisper) | Y | Y | Y | Y | Y | Y | **Y** |
| Offer own loot | Y (party) | N | Y | Y | N | Y (party) | **Y (party and raid)** |
| Queue around restrictions | N | N | N | P | P | N | **Y** |
| Addon comms | N | N | Y | Y | N | N | Later |
| History | N | N | N | P | Y | N | v1 |
| Wishlist, tier, catalyst, transmog | N | N | P (tmog) | P (tmog) | N | N | Later |

## 4. Gaps the new addon can own

1. **Robust on Midnight from day one.**
   - No localised string scraping: tooltip *line types*, GlobalString patterns and item-link data.
   - Every chat payload checked for secret values.
   - A headless test suite. Ka0s already has the harness for this.
2. **Honest eligibility.** Four states with the reason, and **separate rule sets for raid and M+**, because the two loot modes may trade differently.
3. **Both sides of the comparison**: stat and score deltas against *your* gear **and** the looter's. WGL computes stats against you only.
4. **Sidegrades**: the same ilvl but better under your weights, or a lower ilvl with a better score. No group-loot addon reports this.
5. **A live trade countdown** on your own tradeable items, with a warning before it expires. AdiBags-TradeableLoot used to do this and is dead.
6. **Offering in raids.** LIF and WGL stop at five-player groups.
7. **Encounter-aware messaging.** Only Loothing and RCLC queue sends, and they are council addons, not feeds.
8. **Low noise.** A quiet docked feed, with toasts opt-in and auto-whisper off. Commenters punish popup spam and invasive defaults hard.
9. **Visible self-diagnosis.** "Last loot seen", inspect queue state and restriction state, because silent failure was PLH's most damaging complaint.
