# Analysis — WoW Forever recipe reagents, 2026-11-25 (build 1.60.1.70938)

The first run of `tools/seeds/recipes.py` (`seeds.py recipes`, contract: `docs/validate-seeds.md` ->
`## Recipe reagents`), for Drop Watcher's Item Search (DropWatcher#17, IS-DW-02). It generates
`core/RecipeReagentsForever.lua` from the WoW Forever client's own DB2 on wago.tools (product `wowf`),
pinned to 1.60.1.70938, the build of the class seeds' newest bundle (`2026-11-15-forever`). Nothing is
curated, so nothing is ruled.

## What the build says

| Check | Result |
| --- | --- |
| The crafting professions in `SkillLine` | Alchemy 171, Blacksmithing 164, Enchanting 333, Engineering 202, Leatherworking 165, Tailoring 197, Cooking 185 and First Aid 129, each under its name; Jewelcrafting 755 is absent |
| Their spells in `SkillLineAbility` | 2,588 |
| With a `SpellReagents` row (shipped) | 2,466: First Aid 32, Blacksmithing 506, Leatherworking 591, Alchemy 196, Cooking 133, Tailoring 471, Engineering 275, Enchanting 262 |
| Without one (left out) | 122: the profession ranks, the specializations and the recipes the client's DB2 lacks (no `SpellName`, `SpellEffect` or `SpellReagents` row either) |
| Making an item (`SpellEffect` effect 24) | 2,282; the other 184 are enchantments and the like |
| Taught by two professions | 1 (Tailoring and Leatherworking, the same ranks); one more spell has two `SkillLineAbility` rows of one line |
| Reagent anomalies (a zero count, a repeated reagent) in the shipped recipes | none; the generator refuses one |

Some well-known vanilla recipes are among the 122: the client's DB2 has their `SkillLineAbility` row
but no spell rows, so the server alone knows their reagents. That is the case the profession-window
fallback (spec §4.2 B) exists for, and a later run should not read their absence as a tool bug.

## The ForeverDB cross-check (dev time)

`seeds.py recipes crosscheck` against ForeverDB v2026.11.24.46 (commit 6e0a34b, read from the
dev-copilot helper's cache), counts only: of 2,466 recipes, 2,466 have an `sla` row for their skill
line, and all 2,466 agree on yellow and gray (positions 3 and 4) and on the minimum rank (position 2).
No disagreement goes to the owner. No ForeverDB value is in this bundle or the repo (GPL-3.0).

## The generated file

913 lines (the 1500-line cap binds it: it is TOC-loaded), three recipes a line. Measured headless on
Lua 5.1: on WoW Forever the chunk holds about 560 KB until the first `Get()`, which builds the table in
about 4 ms into about 1.9 MB and lets the builder go; on Retail the builder is never made and the file
holds about 1 KB.

## What a later run should re-check

- A new `wowf` build: run `recipes derive` on it with the class seeds, and compare the recipe count and
  the 122. A large change in either is a DB2 export change to read before shipping.
- Jewelcrafting 755: if a build adds it, the generator keeps it with no edit.
- The cross-check on the then-current ForeverDB tag.
