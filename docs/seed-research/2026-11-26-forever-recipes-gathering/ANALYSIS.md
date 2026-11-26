# Analysis — WoW Forever recipe reagents with the gathering lines, 2026-11-26 (build 1.60.1.70938)

The third run of `tools/seeds/recipes.py` (`seeds.py recipes`, contract: `docs/validate-seeds.md` ->
`## Recipe reagents`), for R4-DW-03 (owner feedback round 4: "Why is Incense candle profession = '-'").
The generator's profession map now also keeps the gathering lines, Herbalism 182, Mining 186, Fishing
356 and Skinning 393, each optional (kept when the build has it). WoW Forever gives each of them a few
craftable recipes, and Item Search learned those only from the profession window, with no skill
levels. The build is the one the earlier bundles pinned, 1.60.1.70938, the class seeds' newest
bundle's (`2026-11-15-forever`); `recipes status` reports the live `wowf` build as 1.60.1.71139, and
moving to it stays a seed-validation run of its own, with the class seeds. Nothing is curated, so
nothing is ruled.

This bundle supersedes `2026-11-26-forever-recipes`, which is frozen as it was: the generator's map
grew, so the earlier bundles' extracts no longer regenerate the file.

## What the build says

| Check | Result |
| --- | --- |
| The crafting lines' rows | unchanged: every `SkillLine`, `SkillLineAbility`, `SpellReagents` and `SpellName` row of the previous extract is in this one; the 2,466 crafting recipes, their ranks, reagents, products and teaching items are the same |
| Lines present | 12: the 8 crafting lines and the 4 gathering lines; Jewelcrafting 755 absent |
| New recipes | 27: Herbalism 3, Mining 18 (15 smelts and 3 craftables), Fishing 3, Skinning 3 |
| Incense Candle (spell 1229705, makes 279962) | Herbalism, minimum 1, yellow 20, gray 20; Peacebloom ×1 and item 765 ×1 |
| A minimum rank above 1 | none of the 27 (the DB2's 1 is the trainer placeholder, so no orange start is drawn from it) |
| Taught by an item | 9 of the 27 (Herbalism 2, Mining 3, Fishing 2, Skinning 2); the other 18, the smelts among them, are a trainer's |
| Spells of the kept lines with no reagent row | 171 of 2,664 (122 of 2,588 before): the gathering spells, ranks and the like, left out |
| Totals | 2,493 recipes; 1,975 taught by an item (43 by more than one), 518 a trainer's |

## The ForeverDB cross-check (dev time)

Re-run over the whole table against ForeverDB v2026.11.24.46: 2,493 recipes, 2,493 in `sla`, yellow
and gray agree for 2,493, the minimum for 2,493, 0 disagree. Counts only; no ForeverDB value is in
this bundle or the repo (GPL-3.0).

## The generated file

1027 lines (1015 before; the 1500-line cap binds it, since it is TOC-loaded). The four new lines'
rows follow the crafting lines, in the profession map's order, so the crafting lines' rows and their
`byReagent` order are unchanged. Measured headless on Lua 5.1, the same way as the earlier runs: the
chunk holds about 618 KB until the first `Get()` (613 KB before), which builds the table in about 3 ms
into 2076 KB kept with its strings (2059 KB before); on Retail the builder is never made.

## What Item Search does with it

- The four gathering lines have names (`IST.ProfessionName`), so the window's Profession column, the
  tooltip's crafting row and the verdict's reason name Herbalism, Mining, Fishing or Skinning.
- A recipe of these lines now carries its breakpoints, so its Skill column, skill-up color, glyph and
  verdict points work like a crafting recipe's.
- A recipe still known only from the profession window shows its Skill as "?" (muted), and its row
  tooltip says "levels unknown: not in the shipped table".
- These lines count as professions you have: the ranks the profession filter reads already hold every
  skill line the client lists, gathering ones included.

## What a later run should re-check

- A new `wowf` build: compare the 27 gathering recipes and the 18 trainer's ones among them. A
  gathering recipe with a minimum above 1 would be the first orange start these lines draw.
- Smelting appears under an ore's Crafting section now (Copper Ore -> Smelt Copper). The owner's smoke
  row (R4-DW-SM3) checks that this reads well in game.
