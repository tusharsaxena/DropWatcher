# Drop Watcher: rolls UX round (design)

Date: 2026-11-14. Owner's in-game smoke of the WoW Forever port (merged `086482e`) produced this round. The mockups
the owner approved for questioning are at https://claude.ai/artifact/NjGQ37oty6U3yF4yXHoFyv (sections 1–9). One
codebase, both clients: Retail 12.1.5 (120105) and WoW Forever 1.60.1 (16001).

## 1. Intent

Make the roll moment readable at a glance on both clients, stop two-word Forever names from running under the row
buttons, let lockboxes and other rolled items reach the window, and tidy the window chrome (lock, footer,
auto-close). Fix the two defects the smoke exposed: the roll time left (2717:57) and master-loot pending holding
Epic+ only.

## 2. Owner rulings (2026-11-14)

1. **Roll side card** sits to the right of each Blizzard roll frame, top-aligned, and flips to the left when the
   frame is too close to the screen's right edge. Skin colors. Line 1 the verdict; line 2 the counts as icons:
   Need (dice) · Greed (coin) · Disenchant (Retail only) · Pass · still to roll (hourglass). Every roll in a tooltip.
2. **Rolling now** (main window and compact) uses the same icon count line and the same tooltip. The resolved drop's
   Rolls box and History use the same icon line.
3. **Lockboxes**: a new item kind "Lockboxes and containers" (on by default) plus an "Everything else that is rolled
   on" catch-all (off by default). A non-gear item shows its kind (e.g. "Lockbox") where gear shows a verdict;
   never "Unknown".
4. **Auto-close**: closes only a window that opened by itself, X seconds (default 10, range 5–120) after nothing is
   rolling and no new drop has arrived; hovering the window restarts the count; on by default on both clients.
5. **Line-2 caps** on both clients: looter name, slot and armor type each get a maximum width and cut with "…";
   the `[YOU]` mark is never cut and always shows when the drop is yours. The row's action button (No action, Ask,
   Offer, Ask ML) draws above the row's text.
6. **Master-loot pending** holds items at or above the group's loot threshold (`GetLootThreshold()`), not
   `MasterLootQualityThreshold` (which only gates Blizzard's distribution-confirm popup).
7. **Forever defaults** (Retail unchanged): Open world group tracked and auto-opens; minimum quality Fixed: Uncommon.
   Auto-open master on, Always show upgrades on (already so).
8. **Header lock** button bound to the existing Lock frame setting (`locked`, `/dw lock`); locked hides the resize
   grip as well as refusing the resize.
9. **One footer line**: the status bar's text (inspect, group, situation, sim) folds into the footer row after the
   tradeable count; the grip moves into the footer's corner.

## 3. Behaviour detail

### 3.1 Line-2 caps (ruling 5)
- Caps in the window's layout unit (scale with font): name 96, slot 56, armor type 52; the name gives up width first.
- Order on line 2: `Name [YOU] · Slot · Type`. `[YOU]` is drawn after the cut name, gold, never truncated.
- Full text of a cut piece is already in the row tooltip (looter, slot, type).
- Applies to the full Drops rows, the compact cards, History cards and the Offer list wherever line 2 is drawn.
- Action buttons (and their hit areas) at a frame level above the row's text frames.

### 3.2 Roll count line and tooltip (rulings 1, 2)
- One shared renderer (RollCells): counts from the roll table (`rolls` states 0–5 per CompatLoot). Icons: the
  client's own group-loot button textures (`Interface\Buttons\UI-GroupLoot-Dice-Up`, `-Coin-Up`, `-DE-Up`,
  `-Pass-Up`) and an hourglass for waiting. Disenchant shows on Retail only (clients-§4). If the standard requires
  icons through LibKa0s media, the implementer stops and flags it.
- Tooltip: item name, then players grouped by choice (Need, Greed, Disenchant, Pass), highest roll first within a
  group, then "Waiting" players; class colors, `[YOU]` on yours; the verdict line at the foot. Secret or unreadable
  names degrade row by row (never keyed on, never printed raw).

### 3.3 Roll side card (ruling 1)
- One owned card per GroupLootFrame1..4 (as RollPopup builds today), re-anchored: card LEFT to frame RIGHT (gap 4),
  TOP to TOP. Flip when the frame's right edge plus card width exceeds the screen: card RIGHT to frame LEFT.
- Skinned with the skin's panel/edge/text tokens (not the grey box today).
- Line 1 verdict (non-gear: the item kind, neutral color). Line 2 the count line. "Need so far" goes.
- Mouse-over the card shows the 3.2 tooltip. Hooks stay one-way (HookScript OnShow/OnHide), nothing written to
  Blizzard frames.
- Sim: `/dw sim roll` shows the stand-in frame with the side card; running it twice stacks two, to show placement.

### 3.4 Roll time left (defect)
- Your own popup's roll: `GetLootRollTimeLeft(rollID)` (milliseconds) is the source.
- A roll with no claimed popup: derive from `startTime/duration` only if the result is plausible (0 < left ≤ 5 min);
  otherwise show no time. Record in the probe sheet what units were observed.

### 3.5 Lockboxes and the catch-all (ruling 3)
- New category `container` (item class Container, or Miscellaneous/Junk items that open, i.e. lockboxes); on by
  default on both clients. New category `other` for anything rolled on with no kind; off by default. Both appear on
  Drops › Items.
- The feed, Rolling now, History and Insights read the kind; Insights treats them as "other loot" where it lists
  kinds.
- Non-gear verdict text is the kind word (Lockbox, Container, Item) in the neutral color, on the side card and in
  the rows; no Me/Them gain.

### 3.6 Auto-close (ruling 4)
- Settings: `window.autoClose = { enabled = true, seconds = 10 }`, rows under Drops › Situations "Auto-open the
  window" (indented; disabled when auto-open is off).
- Arms only when the current show was an auto-open. Countdown starts when Rolling now is empty and the feed has had
  no new drop for X s; any new drop, roll or pending item resets it; hover pauses and restarts it; a manual show,
  a drag, or a click inside cancels auto-close for that show. Combat does not matter (closing is a Hide on an owned,
  non-protected frame).

### 3.7 Header lock (ruling 8) and footer (ruling 9)
- Lock button at the left of the title bar (full and compact), icon `lock`/unlock state from LibKa0s icons, tooltip
  "Lock the window" / "Unlock the window"; toggles `locked`. Locked hides `resizeGrip`.
- The status text moves into the footer row's left side after the tradeable count, cut with "…"; its tooltip is
  kept. The footer row grows the grip in its bottom-right corner. The separate status bar goes.

## 4. Non-goals
- No change to the Blizzard roll frame itself (no buttons, no protected state).
- No new LibKa0s surface in this run (the header-button standardisation is LibKa0s #86, separate).
- No version bump or tag.

## 5. Constraints
- Ka0s WoW Addon Standard: deviations STOP and are flagged (CLAUDE.md).
- Gate per commit: both kit profiles 0 failed, luacheck 0/0; docs/test-cases.md and the README badge in step.
- clients-§4: no Retail-only word (Disenchant) on Forever.
