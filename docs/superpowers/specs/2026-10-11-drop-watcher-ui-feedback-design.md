# Ka0s Drop Watcher: owner UI feedback, first in-game look (M8 addendum)

- **Extends:** the v1 spec `2026-10-10-drop-watcher-v1-design.md` and the simulator addendum
  `2026-10-11-drop-watcher-simulator-design.md`.
- **Source:** the owner's first in-game look at test mode on 2026-10-11, with four screenshots (Group drops, My drops,
  History, and the window beside Ka0s Loot History), then a bug report with two more (a real drop shown wrongly in My
  drops, and the real in-game tooltip). Their points are BUG-1..BUG-2 and FB-1..FB-11 below.
- **Items:** DW-80..DW-85, milestone M8, on branch `feat/2026-10-10-drop-watcher-v1`, run after M7.

## 0. Bug first: a real drop is read wrongly (DW-80)

**Evidence** (`research/2026-10-11-ui-feedback/05-my-drops-wrong-item.png`, `06-real-tooltip.png`): the owner's own
drop *Lustrous Golden Plumage* (item 159617; the in-game tooltip says Mythic+, Item Level 311/321, Hero 3/6, Epic)
shows in My drops as **ilvl 19, Rare (blue), For me −315, "Not tradeable: window…"**. 19 and Rare are the item's
*base* level and quality, so the record is judged from a link without its bonus and upgrade data, or from an API
answer that ignores them. The wrong trade state fits the same cause: no bag item matched the record.

**BUG-1, fix the root cause; do not paper over it.** Use systematic debugging: reproduce it headless first with a
realistic 12.x link (the `|cnIQ4:` color form, bonus ids, an upgrade-track modifier, a level-scaling item) and the
link shapes each loot source gives (`CHAT_MSG_LOOT`, `ENCOUNTER_LOOT_RECEIVED`, `C_LootHistory`, the bag). Hypotheses
to test, not assume:
1. De-duplication keeps the **first** source's link (`modules/LootFeed.lua`, the "also reported by" merge), and a
   source other than chat can give a bare or level-less link.
2. `C_Item.GetDetailedItemLevelInfo(link)` answers nil (or the base level) for this link shape, and
   `IF.Read` falls back to `GetItemInfo`'s base `itemLevel`; quality likewise comes from `GetItemInfo` instead of the
   link.
3. Own drops never match their bag item (`modules/TradeTimer.lua` matching), so the facts are never refreshed from
   the bag and the trade state falls to "no".

**Comparison with Ka0s Loot History (owner pointer).** Loot History records the same kind of item correctly, and it
reads it with the **same** client calls: `C_Item.GetDetailedItemLevelInfo(link)`, falling back to `GetItemInfo`'s
level, for weapons and armor only (`../LootHistory/core/Compat.lua` `GetItemExtras` / `GearItemLevel`), and
`GetItemInfo(link)` quality, falling back to the link's color through LibKa0s-Item-1.0 `QualityFromLink`. The
difference is the **source of the link**: Loot History reads only `CHAT_MSG_LOOT` (`NS.Util.ParseSelfLoot`), whose
link always carries the bonus and upgrade data, while Drop Watcher also takes `ENCOUNTER_LOOT_RECEIVED` and
`C_LootHistory`, and its merge keeps the first link it saw. That makes hypothesis 1 the lead; prove it first.

**Shape the fix for LibKa0s.** The owner suggests that the item read be shared by Loot History, Bank Ledger and Drop
Watcher. Following the run's standing decision (build in-addon first, promote later), write the reusable part as one
library-shaped file, `core/ItemRead.lua`, with no Drop Watcher state and the API the library would take:
`EffectiveItemLevel(linkOrLocation)` (gear only, detailed level, then base), `ItemLevelAt(bag, slot)` and quality at a
location (exact, through `ItemLocation`), `QualityOf(link)` (the client's answer for the full link, then the link's
color), `LinkDetail(link)` (how complete a link is: bonus ids, modifiers, upgrade data) and `BetterLink(a, b)`. Its
client calls stay behind Compat seams for now (compat-§1). Draft the promotion as a LibKa0s issue in
`docs/superpowers/plans/2026-10-10-drop-watcher-v1/issues-to-file.md`, naming LibKa0s-Item-1.0 as the home, Loot
History (`GetItemExtras`, `GearItemLevel`), Bank Ledger and Drop Watcher as adopters, and the loot-line parser as a
second candidate (Loot History's self-only `ParseSelfLoot` and Drop Watcher's every-looter `LootParser`). Do not file it.

Whatever the cause, the fix has these properties:
- A merge keeps the **most complete** link (the one carrying bonus and modifier data; chat's over the others).
- An own drop, once matched to its bag item, reads its level and quality from that **bag item**
  (`C_Item.GetCurrentItemLevel` / `GetItemQuality` on its `ItemLocation`, through Compat), which is always exact, and
  re-judges.
- Quality comes from the link (or the item location) before the base item's quality.
- Bag matching tolerates a link that differs only in non-identity fields.
- A `drops` diagnostics line per drop: id, source(s), the stored link's item string, ilvl and its source (detailed /
  current / base), quality and its source, bag match yes/no. Then the owner can paste it if this ever recurs.
- Regression tests for each confirmed cause.

**BUG-2, the real tooltip.** Hovering an item anywhere in the window (My drops, Group drops, the detail card, History,
the Offer panel, the toast, the equipment columns) shows the **real game tooltip**: `GameTooltip:SetBagItem` for an
own item matched to a bag slot (so the client's own "You may trade this item…" line appears), `SetInventoryItem` for
your equipped items, otherwise `SetHyperlink(link)`. Never a tooltip assembled from facts. Addon lines (shift-click to
link, ctrl-click to try on) go after the game's lines. One shared helper in Compat or the window, used everywhere.

## 1. Header: match Ka0s Loot History (DW-81)

- **FB-1 Remove the logo** from the title bar. The launcher and the TOC keep it.
- **FB-2 Center the title**, as `../LootHistory/modules/Browser.lua` does (`title:SetPoint("CENTER")` on the title
  bar, `GameFontNormal`).
- **FB-3 TEST MODE as Loot History shows it:** bright-red `GameFontNormalLarge` text (`1, 0.15, 0.15`) anchored
  `LEFT` of the title's `RIGHT` with a 10px gap. There is no boxed chip. The simulator's indicator (M7) uses the same
  style in its own color and says `SIMULATION`.
- **FB-4 Keep the yellow strip** under the filter bar exactly as it is; the owner likes it. LibKa0s#48 will offer it as
  a shared widget; until that ships it stays in-addon.
- Everything else in the title bar (the restriction badge, Scan group, minimize, close) keeps its place on the right.

## 2. Filter bar styling: match Loot History (DW-82)

- **FB-5** The search box and the checkbox currently look rounder than Loot History's. Build them the way
  `../LootHistory/modules/BrowserFilterBar.lua` does (its search `EditBox` on `BackdropTemplate` with a square
  backdrop, and its checkbox), so the two windows match side by side. Check the dropdowns against Loot History too, and
  align any that differ. Where Loot History uses a LibKa0s widget, use the same one; where it hand-builds, match it and
  note the shared need on LibKa0s#48 or a new LibKa0s issue drafted in `issues-to-file.md` (no GitHub write from the
  run).

## 3. Group drops: columns and filters (DW-83)

- **FB-6 A `My eq` column before `Their eq`.** It shows what you have equipped in the drop's slot: the item icon (two
  icons for rings, trinkets and one-hand weapons) and the item level, with the item tooltip on hover and "empty slot"
  when there is none. It reads your gear snapshot (`NS.Gear`), so it is always fresh.
- **FB-7 `Their eq` shows their item** the same way: icon(s) plus item level, item tooltip on hover. The inspect age
  (the current `2m`) moves into the cell's tooltip ("inspected 2m ago", "from cache", etc.); states with no data keep
  their reason text (`range`, `…`, `—`).
- Both columns obey `window.columns` (a new `myEq` key, default on) and the narrow-width column shedding order
  (`My eq` is shed before `Their eq`).
- **FB-8 Two filter checkboxes**, after `Likely tradeable only`:
  - `Usable by me`: hides drops whose verdict for you is `can't use` or `doesn't want` (your preferences).
  - `Upgrade for me`: shows only drops whose verdict for you is an upgrade.
  - Both are per-tab filter state like the existing checkbox, honored on Group drops and grayed where a tab does not
    use them, and both have settings rows (`feed.usableOnly`, `feed.upgradeOnly`, default off) so they persist.

- **FB-12 The window opens on every eligible drop.** Today auto-open fires once per situation and only for an
  "interesting" drop (an M3 interpretation). The owner wants the window to pop up **whenever** someone loots an eligible
  item, so the rule becomes: each live drop that passes the gates (situation tracked, minimum quality) and is added to
  the feed opens the window if it is hidden. That includes your own drops. The once-per-situation latch goes. The
  master `autoOpen` setting and each situation's `autoOpen` still turn it off. A window the player left minimized
  stays minimized and its `n new` count rises. Opening never happens in combat lockdown if the frame is protected
  there (it is not today: check, and if it would taint, defer to the combat end). Test-mode and simulator drops follow
  the same rule, so `/dw sim` exercises it. The settings tooltip and the README describe the new rule.

## 4. Test mode with real data (DW-84)

- **FB-9 Real items instead of placeholders.** Test mode's drops, your candidates and both equipment columns use real
  items, so icons, names, item levels and tooltips are real (today every icon is the red question mark, because the
  invented item ids do not exist). Source the items from the simulator's item pool (M7, DW-71: the Encounter Journal at
  the current season's difficulty, falling back to your own equipped and bag items), chosen per slot so each
  placeholder keeps its slot. Player names stay invented; nothing names a real player.
- Test mode still shows every state at once: its verdicts, trade, inspect and ask states remain the fixed spec values
  of `v1 §11.6` (it is a preview, not a simulation; `/dw sim` is the simulation). The item level shown is the real
  link's. If the pool is not ready when test mode turns on, the drops fill in when it is (the existing loading path),
  never with a question-mark icon left behind.
- **FB-10 History has test data.** While test mode is on, the History tab shows session-only placeholder entries, two
  groups covering every outcome (seen, asked, offered, expired, declined, received, traded away) with real items. They
  are never written to `DB.global.history` and leave when test mode turns off.
- **FB-11 Button labels lose the ellipsis.** `Offer…` becomes `Offer` (it opens the panel directly). Check every
  button and cell for a trailing `…` or truncated text, e.g. `Not tradeable: window…` in My drops: shorten the text or
  widen the column so it fits, and keep the full reason in the tooltip.

## 5. Tests and smoke

- Headless: the title bar has no logo and a centered title; the TEST MODE and SIMULATION text badges show and hide;
  the two new filters filter; `My eq` renders both cells and shed order; test-mode records carry real item ids from
  the pool (mocked) and never an unknown id; History in test mode has every outcome and writes nothing to the global
  history; no button label ends in `…`.
- Smoke (owed, never marked passed by an agent): a side-by-side check against Loot History (header, search box,
  checkbox, dropdowns); the new columns and filters; test mode with real icons; History in test mode.
