# In-client smoke tests

Pre-flight: retail, `## Interface: 120105`. Run `/console scriptErrors 1`. Before you log in, re-run
`lua tests/run.lua` and `~/.claude/dev-copilot/bin/ka0s-bounded luacheck .`, and confirm both are green.

## C-01: a whitelisted non-gear drop reads as "Watched item" in Insights

- **Setup:** the default profile in a group (or test with `/dw add`). Pick a reagent's item ID (any
  stackable trade good) and run `/dw whitelist add <id>`.
- **Steps:**
  1. Loot the item, or run `/dw add <link>`, and check that it shows in Drops.
  2. Run `/dw insights`. Open the Category dropdown.
  3. Read the Drops by category and Drops by slot sections.
- **Expected:** the Category dropdown lists "Watched item" (count 1), placed last. Drops by category
  has a "Watched item" row. Nothing counts the item under Tier tokens or Equipment.
- **Pass/Fail:** pass when the reagent is not counted under Tier tokens or Equipment anywhere on the tab.

## C-02: what the client reports for a non-gear item's slot (settles F-002's unverified claim)

- **Steps:** `/dump select(9, C_Item.GetItemInfo(<a mount item id>))` and the same for a recipe.
- **Expected:** record the string printed. If it is `INVTYPE_NON_EQUIP_IGNORE`, C-02's corrected wording stands.
- **Pass/Fail:** pass when the note in `docs/known-limitations.md` matches what the dump printed.

## C-03: Insights date ranges, unchanged after the split

- **Steps:** with test mode on (`/dw test`), open Insights. Choose Date: All, Today, then each Last N days. Read the period caption.
- **Expected:** the caption names the same period it did before the change. There are no Lua errors.

## Regression

- `/reload` is clean. A toast stack of 3 in test mode grows down, then up after switching the direction row.
- Enter combat: the toasts on screen are held, and they show again when combat ends.
- `/dw whitelist list` and `/dw blacklist list` print their lists. Adding an ID that is on the other list is refused.

## Sign-off

| ID | Tested? | Pass/Fail | Notes |
|---|---|---|---|
| C-01 | | | |
| C-02 | | | |
| C-03 | | | |
