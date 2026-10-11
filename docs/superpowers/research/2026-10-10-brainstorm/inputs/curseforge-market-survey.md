# Survey: loot, upgrade and trade addons outside WhoGotLoots and DoYouNeedThat (WoW Retail Midnight 12.x, as of 2026-10-10)

## Method and access notes

- **CurseForge:** search pages and project pages fetched fine. I ran these searches: "loot", "trade loot", "upgrade", "whisper loot", "bis", "loot tracker", "personal loot", "loot history" and "group loot".
- **Comments:** the comment tabs only render in a real browser, so I read them with Playwright. That covered PLH, PersoLootRoll, Personal Loot Trader and KeystoneLoot. Do You Need It? and Do You Need That? showed no comment text.
- **Wago Addons:** it is a JavaScript app and its search could not be driven, so I have no Wago-only finds. The addons I saw there are the same ones that are on CurseForge.
- **WoWInterface:** search worked and surfaced RPGLootFeed, LootWhatIWant, Loot Spec Icon and SimpleLootCouncil.
- **Download counts** are CurseForge totals unless noted. "12.1.x" means the addon has a file for the current Midnight patch (12.1.0 is live and 12.1.5 is on the PTR).
- **Not covered:** the reference set (WhoGotLoots, DoYouNeedThat, RCLootCouncil, Pawn) is kept brief, as asked.
- **Your own addon showed up:** *Ka0s Loot History (Retail)* came up in the "loot history" search (166 downloads, Oct 9 2026). It is your addon, so it is not counted as a competitor.

---

## 1. Catalogue: 24 relevant addons

### A. Direct competitors: watch group drops, then ask or offer (Retail, Midnight)

1. **Personal Loot Helper (PLH)**: https://www.curseforge.com/wow/addons/personal-loot-helper
   - Status: 2.71M downloads, v2.47, Sep 5 2026, 12.1.0. Ten years old with 649 comments.
   - Purpose: tells you when a drop isn't an upgrade for the looter but is one for somebody else.
   - Features:
     - When a PLH user gets tradeable loot, they choose KEEP or OFFER TO GROUP. Other PLH users who can equip the item can then request it as main spec, off spec or transmog.
     - The looter sees each requester's reason, their ilvl difference and an internal roll.
     - Players without the addon get a WHISPER button, limited to one whisper per item per player.
     - Requesters who are turned down are only told the item is "no longer available", not whether it was kept or given away.
     - It uses an addon-comms protocol (prefix "PLH") that PersoLootRoll can speak.
   - Weakness found in the comments: it parses localized tooltip text, such as the trade-time pattern `BIND_TRADE_TIME_REMAINING_PATTERN` and the transmog-unknown patterns. A Spanish-client error (`table index is nil`, about 29 days ago) shows how fragile this is. It also needed fixing for the `C_PartyInfo.GetLootMethod` change, and Midnight users asked for an update for 8 months.
2. **PersoLootRoll (PLR)**: https://www.curseforge.com/wow/addons/persolootroll
   - Status: 303K downloads, v25.03, Sep 16 2026, 12.1.0.
   - Purpose: Need/Greed/Pass for other people's tradeable personal loot, plus a Keep/Greed/GiveAway flow for your own.
   - Features:
     - Sends requests over addon comms when the owner runs PLR or PLH, and falls back to whispers (timing and wording are configurable) when they don't.
     - Filters on tradeability, your ilvl and party members' ilvl, class restrictions and trinket type.
     - Pawn integration and a "transmog missing" flag.
     - Follows the winner, opens the trade window when in range and places the item.
     - An on-screen "action list" of pending asks, trades and votes.
     - Masterloot and loot council, EPGP, and auto-replies to requests for items you keep.
   - It is the most feature-complete direct competitor, but it is Ace-heavy, and a Feb 2026 Midnight API break (`GetCompletionInfo`) took the author 3 months to ship.
3. **Personal Loot Trader (PLT)**: https://www.curseforge.com/wow/addons/personal-loot-trader
   - Status: 67K downloads, v2.55, Aug 16 2026, 12.1.0.
   - Purpose: run a roll for your own tradeable item.
   - Features:
     - Rolls go through the real /roll, so players without the addon can join. Addon users get /roll 200 plus 100 for each other addon user.
     - A Pick Winner window, then a follow-and-trade button.
     - Parses group chat for phrases like "anyone need?".
   - Midnight lessons from its comments:
     - Who looted an item during a boss encounter is a *secret value*, which caused taint errors and meant no popup could be shown.
     - `CheckInteractDistance` is blocked in combat.
     - Chat roll-string capture broke on deDE clients.
4. **Do You Need It? (DYNI)**: https://www.curseforge.com/wow/addons/do-you-need-it
   - Status: 849 downloads, v0.6.3, Oct 4 2026, 12.1.5. It is the newest serious entrant.
   - Purpose: shows tradeable M+ and raid drops next to the looter's equipped item.
   - Features:
     - A four-state eligibility verdict: **Yes** (trade timer detected), **Likely** (BoE, or personal loot whose ilvl is no higher than the looter's inspected item), **Unknown** and **No**. The page openly says another player's eligibility can't be known for certain.
     - Inspect results are labelled "Cached" when they are old. `/dyni scan` inspects the group before a pull.
     - Separate tooltip targets for rings, trinkets and paired weapons.
     - Auto-whisper is **off by default**. When on, it waits 10 seconds by default (adjustable from 3 to 30) and is cancelled if you click Ask, clear the rows, or the looter leaves the group.
     - A `{item}` placeholder in the whisper. The row shows an error if the message is too long.
     - A "New loot" button that scrolls you back to the latest drops.
     - History of 50 drops and 10 boss or run groups, a `/dyni test` preview, and 10 languages.
5. **Loot It Forward**: https://www.curseforge.com/wow/addons/loot-it-forward
   - Status: 1.0K downloads, v1.2.1, Aug 12 2026, 12.1.0, MIT.
   - Purpose: the **offer-my-loot** direction. When you get gear that isn't an upgrade for you, it lists the party members it would upgrade.
   - Features:
     - Checks armor type, weapon type, primary stat and that the ilvl gain is meaningful.
     - Skips heirlooms for players who are still levelling.
     - Shows class-coloured candidates with their current ilvl in the slot and the gain.
     - Hover comparison against the candidate's gear, plus Whisper and Trade buttons for each candidate.
   - Raids are explicitly not supported.
6. **Loot Ratter**: https://www.curseforge.com/wow/addons/loot-ratter
   - Status: 406 downloads, v1.0.2, May 9 2026, 12.0.7 (one patch behind).
   - Purpose: an end-of-encounter summary of wearable loot with an Ask button.
   - Features: upgrades are shown in green for you, and the looter is shown in red when their equipped ilvl is lower (meaning they probably need it). Auto-whisper or manual.
7. **PeaversNeedThat**: https://www.curseforge.com/wow/addons/peaversneedthat
   - Status: 200 downloads, v1.0.9, Aug 11 2026, 12.1.0.
   - Purpose: M+ only. Opens a "polite whisper" dialog when a drop is an upgrade for you.
8. **Beggar (QFXBeggar)**: https://www.curseforge.com/wow/addons/beggar
   - Status: 22 downloads, v1.0.25, Sep 3 2026, 12.1.0. Author is Chinese.
   - Purpose: wishlist-driven requests.
   - Features:
     - Star items in the Adventure Guide and set a **minimum upgrade track** (Adventurer, Veteran, Champion, Hero or Myth).
     - Wishlist items can be requested even when they are below your equipped ilvl.
     - Separate auto-whisper toggles for M+ wishlist, M+ upgrades and raid wishlist. In raid, an Ask button appears after the roll.
     - Templates with `%item%`, `%player%` and `%track%`.
     - Ignores warbound items and bonus-roll loot.
9. **ZolLoot**: https://www.curseforge.com/wow/addons/zolloot
   - Status: 42 downloads, v1.5.0, Sep 22 2026, 12.1.5.
   - Purpose: a season loot browser built from the Adventure Guide, filtered to tradeable gear for your spec.
   - Features:
     - **S, A and B mark tiers.**
     - A secondary-stat filter for one stat or an exact pair, with a bulk-mark button.
     - A draggable alert with a Whisper button when a groupmate loots a marked item, and an optional upgrades-only mode.
     - Your mark tier shows in tooltips in bags, the Adventure Guide and chat links.
10. **Loot Whisperer**: https://www.curseforge.com/wow/addons/loot-whisperer
    - Status: 35 downloads, v1.0.0, Apr 13 2026, 12.0.1 (stale).
    - Purpose: a feed of party and raid loot that isn't soulbound. Click an entry to whisper the looter. Filters on quality and class usability.
11. **LootSpotter**: https://www.curseforge.com/wow/addons/lootspotter
    - Status: 9 downloads, Apr 15 2026, 12.0.5.
    - Purpose: a loot feed built from `CHAT_MSG_LOOT`, with ilvl min/max filters and a class-usable filter. Its Ask button posts to group or instance chat rather than whispering.
12. **Mythic Plus Loot (Midnight)**: https://www.curseforge.com/wow/addons/mythicplusloot-midnight
    - Status: 7.2K downloads, v1.4.1, Sep 7 2026, 12.1.0.
    - Purpose: an end-of-run window showing who looted what, with a Whisper button for each entry.

### B. Loot planning, BiS, wishlists and loot spec

13. **KeystoneLoot**: https://www.curseforge.com/wow/addons/keystoneloot
    - Status: 5.19M downloads, v2.18.3, Oct 3 2026, 12.1.0.
    - Purpose: M+, raid and Catalyst loot browser filtered to your class and spec.
    - Features:
      - **Five favourite tiers**: Nice to have, Must have, BiS, Transmog and Catalyst. Saved per character and spec, with export and import strings.
      - **Void Core (bonus roll) tracking**, which fills in past loot automatically on install.
      - A **loot spec reminder** when you enter a key, and a **group favourites reminder** that suggests a loot spec from your groupmates' favourites.
      - Drop notifications with whisper support.
    - Scope creep: it now also does teleports, `!keys` and auto role check.
14. **ADHD BiS**: https://www.curseforge.com/wow/addons/adhdbis-best-in-slot-loot-tracker
    - Status: 7.4K downloads, v1.8.3, May 25 2026, 12.0.7.
    - Purpose: BiS lists with a bag scanner that sorts items into BiS equipped, BiS upgradeable, BiS in bags and missing.
    - Features: LootRadar, a live drop tracker, a wishlist, a sound when BiS drops, a Great Vault advisor, trinket tiers and talent strings. Data comes from Icy Veins and Wowhead and needs an external companion app.
15. **Loon Best In Slot**: https://www.curseforge.com/wow/addons/loon-best-in-slot
    - Status: 7.19M downloads, v1.1.3, Aug 31 2026, 12.1.0.
    - Purpose: Wowhead BiS lists in tooltips and a browser, with an upgrade-track ilvl selector.
16. **SpecBisTooltip**: https://www.curseforge.com/wow/addons/specbistooltip
    - Status: 3.2M downloads, Oct 3 2026, 12.1.0.
    - Purpose: shows "is BiS for spec" on tooltips.
17. **Midnight BiS List S2**: https://www.curseforge.com/wow/addons/midnight-bis-list
    - Status: 98K downloads, Aug 14 2026, 12.1.0. A Wowhead-based BiS guide.
18. **Loot Spec Icon** (WoWInterface): https://www.wowinterface.com/downloads/search.php?search=loot
    - Status: 627 downloads, Mar 2026.
    - Purpose: shows your current loot spec. I found it in the WoWInterface search results but did not open its own page.

### C. Upgrade, transmog and tradeability helpers (single player)

19. **Easy Gear Upgrade**: https://www.curseforge.com/wow/addons/easy-gear-upgrade
    - Status: 5.0K downloads, Mar 21 2026, 12.0.5.
    - Purpose: ilvl numbers and **upgrade arrows** on items in bags, loot windows and loot rolls.
    - Features:
      - A green dash for **sidegrades with on-use or on-equip effects**.
      - Tooltip lines that explain the ilvl or stat difference.
      - BoE, WuE and WB binding labels, and an uncollected-transmog marker.
      - Armor, stat and weapon filters, and weighted secondary-stat priority.
      - Sets up defaults for your class and spec from your gear on first login.
20. **Transmog Upgrade Master**: https://www.curseforge.com/wow/addons/transmog-upgrade-master
    - Status: 85K downloads, Aug 12 2026, 12.1.0.
    - Purpose: tells you whether upgrading or catalysing an item teaches a new appearance. For BoE and warbound items it lists which classes would learn it.
21. **Can I Mog It**: https://www.curseforge.com/wow/addons/can-i-mog-it
    - Status: 6.95M downloads, Sep 22 2026, 12.1.0.
    - Purpose: marks items whose transmog you haven't collected. It is the de facto source of transmog state.
22. **Tradable**: https://www.curseforge.com/wow/addons/tradable
    - Status: 110 downloads, Sep 18 2026, 12.1.0.
    - Purpose: the reverse of the problem. It scans your equipped gear, bags and bank for your highest ilvl in each slot and tells you which slots fall short of a target ilvl. Presets: M0, +7, +10, Vault and Mythic.
    - Can post the slots that fall short to group chat.
    - It exists because trade eligibility depends on the highest ilvl you own in a slot, not just what is equipped.
23. **Midnight Upgrade Calculator**: https://www.curseforge.com/wow/addons/midnight-upgrade-calculator
    - Status: 2.0K downloads, Mar 17 2026, 12.0.1.
    - Purpose: upgrade-track and crest cost per slot.
    - Features: a **Group tab built on inspect**, showing each member's ilvl, max ilvl and missing upgrades, with sortable columns.

### D. Loot feeds, history and raid distribution (adjacent)

24. **Better Loot Window**: https://www.curseforge.com/wow/addons/better-loot-window
    - Status: 8.1K downloads, Aug 15 2026, 12.1.0.
    - Purpose: a feed of encounter, roll and personal loot.
    - Features: sockets and tertiary stats at a glance, class-coloured names, merged duplicates, a blacklist, per-entry lifetime, and placement through Edit Mode.
- **RPGLootFeed** (WoWInterface): https://www.wowinterface.com/downloads/info26799
  - Status: v1.39.1, Oct 2026, 12.1.0.
  - Purpose: a scrolling loot feed that the changelog says also shows **party loot**, matching senders by full name or GUID. It has a history view and Auctionator and TSM values.
- **Gargul**: https://www.curseforge.com/wow/addons/gargul
  - Status: 20.7M downloads, v8.0.1, Oct 3 2026, 12.1.0.
  - Purpose: rolls, SoftRes, TMB and DFT wishlist import, PackMule auto-loot rules, GDKP and trade announcements. It is built for raid leaders.
- **RCLootCouncil**: https://www.curseforge.com/wow/addons/rclootcouncil
  - Status: 33.9M downloads, v3.23.3, Aug 31 2026, 12.1.0.
  - Plugins: **RCLootCouncil – wowaudit** (507.7K downloads, Raidbots droptimizer and wishlists in the voting frame), **GroupGear** (767.9K), **cttLoot** (Raidbots DPS gain for each drop) and **RCLootCouncil – BIS**.
- **LootRaffle**: https://www.curseforge.com/wow/addons/lootraffle
  - Status: 11.3K downloads, **dead since Jan 2023** (10.0.5).
  - Purpose: raffles your loot to whoever can use it.
  - Features: auto-detects class proficiencies, filters class set pieces, relic types and trinket main stat, handles distance and retries trades, and ends early once everyone has rolled or passed.
- Raid-ledger loot history tools: **LootHoard** (CSV export, 12.0.1), **RaidLootTracker** (12.1.0, winners, rolls and reassignment) and **Show Us Your Loot** (12.1.0, loot fairness analytics for guilds using Group Loot).
  - From the "loot tracker" and "group loot" search results: https://www.curseforge.com/wow/search?search=loot%20tracker
- Checked and Classic-only or out of scope:
  - **LootReserve**: 3.5M downloads, Classic.
  - **AtlasLoot**: maintained only in its Classic forks.
  - **BiS-Tracker**: Classic, Nov 2024.
  - **LootAppraiser** and **LootAppraiser GroupLoot**: gold value, not upgrades. GroupLoot's last update was 2018.
  - **AdiBags – TradeableLoot**: a bag section for items with a trade timer, stale since 2024.
  - **XLoot**: on WowAce, not checked further.

---

## 2. Comparison matrix

Key: Y = yes, P = partial or basic, N = no, ? = not stated on the page.

Columns:
- **PLH** = Personal Loot Helper; **PLR** = PersoLootRoll; **PLT** = Personal Loot Trader
- **DYNI** = Do You Need It?; **LIF** = Loot It Forward; **Rat** = Loot Ratter
- **Beg** = Beggar; **Zol** = ZolLoot; **KSL** = KeystoneLoot; **EGU** = Easy Gear Upgrade
- **ADHD** = ADHD BiS; **RCLC** = RCLootCouncil; **Garg** = Gargul

| Feature | PLH | PLR | PLT | DYNI | LIF | Rat | Beg | Zol | KSL | EGU | ADHD | RCLC | Garg |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| Group drop feed | P | Y | N | Y | N | Y | P | P | P | N | Y | Y | Y |
| My-upgrade check | Y | Y | N | P | N | Y | Y | Y | N | Y | P | P | N |
| Looter-upgrade check (inspect) | Y | Y | N | Y | Y | P | N | N | N | N | N | P (GroupGear) | N |
| ilvl compare | Y | Y | N | Y | Y | Y | Y | Y | N | Y | P | Y | N |
| Stat compare / weights | N | P | N | N | N | N | N | P (stat filter) | N | Y | N | N | N |
| Pawn integration | N | Y | N | N | N | N | N | N | N | N | N | N | N |
| Tradeability detection | Y (tooltip) | Y | Y | Y (4-state) | Y | ? | Y | Y | N | P (bind labels) | N | Y | P |
| Trade timer shown | P | ? | N | P (detects only) | N | N | N | N | N | N | N | N | Y (roll timer) |
| Equippability check | Y | Y | N | Y | Y | Y | Y | Y | Y | Y | Y | Y | N |
| Whisper / ask buttons | Y | Y | N | Y | Y | Y | Y | Y | Y | N | N | N | N |
| Offer my loot | Y | Y | Y | N | Y | N | N | N | N | N | N | Y | Y |
| Addon comms between users | Y | Y | Y | N | N | N | N | N | P | N | N | Y | Y |
| Loot history log | N | P | N | Y | N | N | N | N | Y (Void Core) | N | Y | Y | Y |
| BiS / wishlist | N | N | N | N | N | N | Y | Y | Y | N | Y | P (plugins) | Y (TMB/SR) |
| Tier set awareness | N | N | N | N | N | N | N | Y (tier mark) | P | N | N | N | N |
| Catalyst / vault awareness | N | N | N | N | N | N | N | N | Y (catalyst) | N | Y (vault) | N | N |
| Loot spec helper | N | N | N | N | N | N | N | N | Y | N | N | N | N |
| Raid and M+ support | Y/Y | Y/Y | Y/Y | Y/Y | N/Y | ?/Y | Y/Y | Y/Y | Y/Y | n/a | Y/Y | Y/N | Y/N |
| Transmog awareness | Y | Y | N | N | N | N | N | N | Y (fav tier) | Y | N | N | N |

**Reading the matrix:** no addon combines all four of these: a feed of group drops, inspect of the looter, your own upgrade calculated with stat weights or Pawn, and a trade window you can see counting down. PLR comes closest, but it is built around rolling, not around a feed you read.

---

## 3. Gaps in the market (Midnight 12.x specifics)

1. **Robustness for Midnight.** The two big incumbents both broke in 12.0:
   - PLH users asked for a Midnight update for 8 months.
   - PLR had a 3-month gap after `GetCompletionInfo` was removed.
   - PLT hit taint from secret values when a looter is resolved during an encounter, and had `CheckInteractDistance` blocked in combat.
   - The new small addons (DYNI, Beggar, ZolLoot, LIF) are reliable but have under 1K installs each. The market leader in this niche is effectively unmaintained or fragile, so there is room for a carefully built addon.
2. **Detecting eligibility without the locale.** PLH, PLT and others scrape localized tooltip and chat strings, and break on esES and deDE clients. Nobody advertises using `C_TooltipInfo` line types, `C_Item.IsBound`, the bind type from `GetItemInfo` and the bonus IDs in item links in a way that doesn't depend on the locale.
3. **Honest eligibility states.** Only DYNI says "you cannot know the other player's eligibility for certain" and models it as Yes, Likely, Unknown or No.
   - Midnight complicates the rule. Raids use **mandatory group loot**, and **ilvl restrictions on trading inside Midnight raids are lifted** (per the Icy Veins S1 guide: https://www.icy-veins.com/wow/midnight-season-1-raid-guide), while M+ still uses the personal-loot "ilvl ≤ your highest" rule.
   - No addon models different trade rules for raid and for M+.
4. **A live trade-window countdown.** Nobody shows the 2-hour countdown on a received item or warns when an offer is about to expire. AdiBags-TradeableLoot, which grouped such items in the bags, has been dead since 2024.
5. **Sidegrades judged by stats.** Only EGU (bag arrows, not group loot) and PLR (Pawn as a filter) look past ilvl. Nobody says something like "same ilvl but +Haste/Mastery for your weights" or "the looter's equipped item is higher ilvl but has bad stats, so they may give it away."
6. **The other side of the trade.** LIF does "offer my loot", but **not in raids**. Tradable does "which of my slots block trading", but has no group integration. Nobody combines this for a single drop: what is tradeable from me, to whom it's an upgrade, the ilvl gain, and a Trade button.
7. **Behaviour in combat and during encounters.** Chat-send lockdown during encounters and secret loot strings mean asks must be **queued until `ENCOUNTER_END` or leaving combat**. DYNI's delayed whisper is the only partial answer.
8. **Linking wishlists to the trade loop.** KeystoneLoot, ZolLoot and Beggar have wishlists or marks. Only ZolLoot and Beggar raise an alert when a groupmate loots a wishlisted item. Nobody pulls in a Raidbots droptimizer or wowaudit wishlist outside RCLC.
9. **Tier, Catalyst and Void Core awareness in the feed.** Nobody tells you in the drop feed that a drop gives you a 2- or 4-piece tier bonus, that it can be catalysed into tier, or that you've already used a Void Core on that boss.
10. **Low noise.** Players complain about popups (see section 4). There is no "quiet feed with an optional toast" design that is noisy only for a real upgrade or BiS.

---

## 4. Ranked extra feature ideas (22)

| # | Idea | Rationale | Inspired by |
|---|---|---|---|
| 1 | **Four-state eligibility per row (Yes, Likely, Unknown, No) with the reason on hover** | Honest about what the API can't tell you, so fewer pointless whispers. | DYNI |
| 2 | **Separate trade rules for raid and for M+** | Midnight raids lift the ilvl trade limit and M+ doesn't, so a single rule mislabels one of them. | Gap (Icy Veins S1 guide) |
| 3 | **Delayed and queued whispers**: send after N seconds or after `ENCOUNTER_END` or leaving combat; cancel if you ask manually, the looter leaves, or the item is traded | Avoids chat lockdown during encounters and "begging mid-pull". | DYNI, PLT secret-value errors |
| 4 | **Detection that doesn't depend on the locale** (`C_TooltipInfo` line types, bind type, bonus IDs) | Avoids PLH and PLT style crashes on non-English clients. | PLH and PLT comments |
| 5 | **Live trade-window countdown** on received tradeable items, with a warning at 10 minutes | Nobody shows it, and an expired window means lost gear. | Gap (AdiBags-TradeableLoot, dead) |
| 6 | **Offer-my-loot panel**: candidates ranked by ilvl gain, with Whisper and Trade buttons, **raids included** | LIF proved demand but left out raids. | Loot It Forward, PLH |
| 7 | **Speak the PLH and PLR addon-comms protocol** (read-only at first) | Instant interop with an installed base of 3M; asks resolve without whispers. | PersoLootRoll |
| 8 | **Inspect cache with an age badge and a "scan group" button** | Inspect is range- and combat-limited, so show how fresh the data is. | DYNI `/dyni scan`, MUC Group tab |
| 9 | **Sidegrade logic**: same ilvl but better stats under your weights or Pawn scale, plus on-use and on-equip effects | Upgrades that aren't about ilvl are invisible elsewhere. | EGU, PLR (Pawn) |
| 10 | **"Looter likely won't keep it" score**: their ilvl in the slot, their stat fit and a duplicate unique-equipped item | Prioritise who to ask. | Loot Ratter (red looter label), PLH |
| 11 | **Wishlist tiers (S, A, B or Must, Nice, BiS, Transmog) and a sound or toast when a groupmate loots one** | The most valued planning feature. | KeystoneLoot, ZolLoot, Beggar |
| 12 | **Minimum upgrade-track filter** (Champion, Hero, Myth) for wishlist asks | A Veteran-track copy of a BiS item isn't worth begging for. | Beggar |
| 13 | **Tier and catalyst flag**: "gives you 2- or 4-piece" or "catalyse into tier" on the row | Tier pieces outvalue raw ilvl. | ZolLoot, KeystoneLoot catalyst viewer |
| 14 | **Transmog flag** (uses Can I Mog It's API if present) and a "Transmog" ask type | PLH and PLR request types include transmog, and people ask for it. | PLH, PLR, CanIMogIt, TUM |
| 15 | **Void Core (bonus roll) awareness**: don't auto-ask for items you could secure with a bonus roll; mark bonus-roll loot | Bonus-roll loot can't be traded and confuses feeds. | KeystoneLoot, Beggar, DYNI 0.3.0 |
| 16 | **Loot-spec nudge on entering an instance**, based on wishlist and group favourites | Cheap, and liked in KeystoneLoot. | KeystoneLoot |
| 17 | **Separate jewelry, trinket and paired-weapon comparison** (two ring slots, main hand plus off hand vs 2H) | The common comparison bugs live here. | DYNI |
| 18 | **"Can I trade this?" self-check**: your highest ilvl per slot vs a target, with a one-click "post my tradeable list" | Lets you advertise loot ahead of time. | Tradable |
| 19 | **Session history grouped by boss or run**, with a "New loot" jump button | Feed history must not jump while you read. | DYNI, Mythic Plus Loot, Better Loot Window |
| 20 | **Optional Raidbots, Droptimizer or wowaudit import** for the "% DPS gain" column | The best signal beyond weights; RCLC-only today. | RCLC-wowaudit, cttLoot |
| 21 | **Integration with bag and tooltip addons**: arrows or tier on bag items and Adventure Guide tooltips | Keeps upgrade info consistent everywhere. | EGU, ZolLoot, Loon BiS |
| 22 | **Announce to the group instead of whispering**, e.g. "Roll for X, it looks like an upgrade for A and B" | A PLH user explicitly asked to "never whisper". | PLH comment (moolric), LootSpotter, PLT |

---

## 5. UI and UX patterns from comments and descriptions

**Praised**
- "Slick", low-friction flows. A PLT user called it "a slick addon", and PLR is described as "more polished" than PLH.
- Interop instead of competition. Players want an addon that works with groupmates running PLH or PLR, because "it would be nice to have both installed for others who have one or the other" (PLR comments).
- Manual overrides for automation that fails. KeystoneLoot users were happy to learn an item could be **manually marked** "Void Core used" when the automatic rescan missed it.
- Configurable options that are on by default only when harmless, and multi-filter options that users can find in settings (KeystoneLoot's "Multiple Slot Filtering").
- Recommending a target, not starting a vote. A PLT commenter said: "I would rather just hand the loot to whoever has the lowest ilvl gear in that slot that can use it… players can't be relied on to know whether they should roll." In other words, show the best candidate.

**Complained about**
- **Popup spam.** One user feared "pop-ups like late 90's websites in a hectic run through a PUG" if two loot addons ran together. Default to a docked feed and make toasts opt-in.
- **Invasive features on by default.** KeystoneLoot's auto role check triggered a long thread: "don't assume the users want it enabled by default… bad UX", and "seems like it's getting bloated."
  - The lesson: keep scope tight, make new behaviour opt-in, and announce it in game once.
- **Silent failure.** PLH users reported "no popup occurs… no lua error" across a whole patch. Add a visible status or self-test (DYNI's `/dyni test`) and a "last loot seen" diagnostic.
- **Lua errors on non-English clients** (PLH in Spanish, PLT in German) and **taint and secret-value errors in encounters** (PLT, PLR). Players paste long BugSack dumps into the comments.
- **Slow updates after patches** ("is this dead with 12.0?"). This is a maintenance signal that newer addons use to win users.
- **Auto-whisper etiquette.** Every new addon ships auto-whisper **off** or delayed (DYNI, Loot Ratter, Beggar's separate toggles). Players treat unsolicited instant whispers as rude, so a delay and cancel-on-trade are expected.

**Design takeaways for your addon**
- A quiet docked feed (Edit Mode positioning, like Better Loot Window), with each row showing looter, item, ilvl and the eligibility verdict.
- Tooltips that compare **both** your gear and the looter's gear. Handle ring, trinket and dual-wield slots explicitly.
- One-click Ask and Offer that queue safely around encounters.
- Template placeholders: `{item}`, `{player}`, `{track}`, `{ilvlgain}`.
- A test mode, a "scan group" control and an "inspect age" indicator.
- Localized from day one, with no tooltip-string scraping.

---

### Key sources
- CurseForge searches: https://www.curseforge.com/wow/search?search=trade%20loot, …?search=loot, …?search=upgrade, …?search=whisper%20loot, …?search=bis, …?search=loot%20tracker, …?search=personal%20loot, …?search=loot%20history, …?search=group%20loot
- Comment pages read:
  - https://www.curseforge.com/wow/addons/personal-loot-helper/comments
  - https://www.curseforge.com/wow/addons/persolootroll/comments
  - https://www.curseforge.com/wow/addons/personal-loot-trader/comments
  - https://www.curseforge.com/wow/addons/keystoneloot/comments
- WoWInterface search: https://www.wowinterface.com/downloads/search.php?search=loot
- Midnight raid loot rules: https://www.icy-veins.com/wow/midnight-season-1-raid-guide. I saw this only as a search-result snippet; the article on addon limits returned 403.
- Unverified: the encounter chat lockdown and secret chat values come from community reports in search snippets. The secret-looter taint is confirmed by the PLT author's own reply in the comments.

No files were written outside the scratchpad. Playwright saved page snapshots under `.playwright-mcp/`.
