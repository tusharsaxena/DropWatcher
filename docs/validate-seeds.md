# Seed validation — Drop Watcher

The seed-validation contract `/dev-copilot:validate-seeds DropWatcher <flavor>` runs. The command
supplies the loop (clean tree, one date, status, derive, rule, apply, gate, hand-back) and its
standing rules. This file supplies Drop Watcher's procedure: the tool, the files it writes, the
precedent a ruling follows and the nuances of each client. The headings below are the interface
the command reads, so keep their names.

The seeds are the class lists (clients-§5), LibKa0s-Verdict-1.0's since the Item Search split
(DropWatcher#19): `libs/LibKa0s/VerdictClassData.lua`, the vendored copy, holds Retail's
(`RETAIL`) and WoW Forever's (`FOREVER`) lists, each built by `CD.Build`. This repo checks them
read-only: a ruled edit is the library's, made in LibKa0s's `LibKa0s/VerdictClassData.lua` and
re-vendored, and `apply` refuses to write under `libs/`. Every run also checks the
item enum fallback literals in `core/Constants.lua` (`C.ITEM_CLASS`, `C.WEAPON_SUBCLASS`,
`C.ARMOR_SUBCLASS`, `C.RECIPE_SUBCLASS`, `C.MISC_SUBCLASS`), the recipe skill lines
(`C.RECIPE_SKILL_LINE`, `modules/CollectCells.lua`'s `PROFESSION`) and the library's `VerdictFacts.lua`
`IR.GEAR_CLASSES`. These are name and existence checks only, with no candidates: they mirror the
client's enums and are not a curated list. Nothing else in `core/` or `modules/` is a seed: the
inventory slots (`C.SLOT`) are FrameXML constants that no DB2 table holds, `C.TIER_TOKENS` and
`C.TRACK_TIER_BY_STRING_ID` are empty, and `core/CompatJournal.lua`, `modules/TestData.lua` and the
simulator's files hold reads or invented test data, not game ids.

Each run ends in a frozen bundle under `docs/seed-research/<date>-<flavor>/`. The tool is
`tools/seeds/seeds.py`, and its docstring is the reference for every candidate and flag kind. The
first runs are `docs/seed-research/2026-11-15-retail/` and `docs/seed-research/2026-11-15-forever/`.

WoW Forever has one more seed, **recipe reagents** (`core/RecipeReagentsForever.lua`, Item Search,
DropWatcher#17). It is generated, not curated: `tools/seeds/recipes.py`, which `seeds.py recipes`
drives, writes it whole from the `wowf` DB2, with no candidates and no rulings. Its own section,
`## Recipe reagents` below, holds its facts; the `forever` flavor's steps run it beside the class
seeds, into a bundle of its own, `docs/seed-research/<date>-forever-recipes/`.

It also has one **hand-curated list with no tool**, the gathering nodes (`core/GatherNodes.lua`, Item
Search round 3). No DB2 table or static client read holds a node's required skill, so the list is
outside the seed loop: `## Gathering nodes` below says how it is kept.

## Flavors

| Flavor | Source | Seed files | Tools |
| --- | --- | --- | --- |
| `retail` | wago.tools product `wow` (Retail live) | `libs/LibKa0s/VerdictClassData.lua`'s `RETAIL` (hand-curated in LibKa0s, tool-checked here; the ruled `RETAIL.WEAPONS` edit is made in LibKa0s), plus the shared literals above (checked only) | `tools/seeds/seeds.py --flavor retail` |
| `forever` | wago.tools product `wowf` (WoW Forever) | `libs/LibKa0s/VerdictClassData.lua`'s `FOREVER` (hand-curated in LibKa0s, tool-checked here; the ruled `FOREVER.WEAPONS` edit is made in LibKa0s), plus the shared literals above (checked only), and `core/RecipeReagentsForever.lua` (generated whole, recipe reagents) | `tools/seeds/seeds.py --flavor forever`, `tools/seeds/seeds.py recipes` (`tools/seeds/recipes.py`) |

## Rules

- **Only `apply` writes a WEAPONS set**, and only for an accepted `weapon:` candidate or a
  `weapon-unlisted` flag ruled `remove`. Since the Item Search split the lists are vendored here
  (`libs/LibKa0s/`), so `apply` stops with the edit it would make and the edit is made in LibKa0s
  and re-vendored; the rulings stay this repo's. Every other row (class ids, armor, specs, trees, relics,
  flags such as `D`, `T`, `S`) is a hand edit. An accepted hand candidate or a flag ruled `fix` makes
  `apply` refuse until the file carries the edit and a `derive --replay` stops raising it.
- **Rulings are data.** They live in `tools/seeds/retail_rulings.json` and
  `tools/seeds/forever_rulings.json`, written only by `seeds.py rule`. A ruling is keyed
  `<group>:<subject>` for a candidate or `shipped:<kind>:<subject>` for a flag, never by build, and it
  holds until the thing it ruled on stops being proposed.
- **Precedent, in this order, never re-litigated:**
  1. a ruling already in the flavor's rulings file;
  2. the seed file's own header and comments. The one that decides most weapon candidates is
     the class list file's note above `RETAIL.WEAPONS` (LibKa0s's `VerdictClassData.lua`): a skill the class has but no loot of its
     primary stat drops for is left out, so a ranged weapon reads as the hunter's alone (its own
     example is a warrior's bow). Devourer's weapon and off-hand rules stay a known limitation until
     smoke-checked (FEED-7);
  3. `docs/design-readings.md` (the class tables are a fallback: an item's own spec list wins when it
     exists) and `docs/known-limitations.md`;
  4. the Forever port's research and design, `docs/superpowers/research/2026-11-13-forever-port/`
     (`04_DW_FOREVER_EXPOSURE.md` §5, the vanilla proficiencies) and
     `docs/superpowers/specs/2026-11-13-drop-watcher-forever-port-design.md` §4.2. Those rows are
     marked INFERRED until probed, so a build row that contradicts them is the owner's call, not
     the tool's;
  5. the assertions in LibKa0s's `tests/test_verdict_classdata.lua`, which pin today's lists. A ruling that
     contradicts one goes to the owner.
- **What "accept" means here.** Accept a proficiency only when the build grants it
  (`SkillRaceClassInfo`, with `SkillLineAbility` as a second witness), the loot-relevance rule
  admits it, and nothing above records otherwise. When in doubt, reject with
  `needs owner review: <why>`. A rejection like that is meant to come back to the owner, not to
  settle the question.
- **Evidence.** The bundle's `raw/*.csv.gz`: `SkillRaceClassInfo` (`SkillID`, `ClassMask`,
  `MinLevel`; a row with no race in either race mask is skipped), `SkillLineAbility` (the
  proficiency spells' `ClassMask`), `ChrClasses` (`ArmorTypeMask`: bits 1 to 4 the armor types,
  6 shields, 7 to 9 the relics), `ChrSpecialization` (`OrderIndex`, `PrimaryStatPriority`),
  `SpecializationSpells` (Titan's Grip, 46917) and, on Forever, `TalentTab`. DB2 says what a class
  can learn, not what a player wears, so a surprising row is checked in game before it ships.
- **Privacy.** No player name, realm or GUID goes into a bundle, a ruling or a commit.

## Flavor: retail

### Status

```sh
python3 tools/seeds/seeds.py status --flavor retail
```

Prints `CURRENT <build> (<bundle>)`, or `NEW <build> (last ruled <build>, <bundle>)`, comparing the
live `wow` build with the newest `*-retail` bundle.

### Freeze and derive

```sh
python3 tools/seeds/seeds.py derive --flavor retail --build <build> --bundle docs/seed-research/<date>-retail --date <date>
```

It downloads eight small tables (about 1 MB, cached in `tools/seeds/.cache/`) and runs the coverage
gate: the sentinel classes (Warrior 1, Rogue 4, Mage 8) and skill lines must be there, and every
mapped armor and weapon skill line must still carry its name. **If the gate fails, stop**: fix the
tool's map, not the rulings. Report the candidate and flag counts and the unruled count.

### Rule

```sh
python3 tools/seeds/seeds.py check --bundle docs/seed-research/<date>-retail
python3 tools/seeds/seeds.py rule --tsv <scratchpad>/rulings.tsv --bundle docs/seed-research/<date>-retail
```

`check` lists every unruled key and exits 1, and must print `OK` after `rule`.

- **Candidates** (`accept` or `reject`): `weapon:<CLASS>:<SUB>` (written by `apply`), and the hand
  candidates `class:`, `spec:` and `titanGrip:`.
  - A warrior's or a rogue's bow, gun or crossbow is rejected under the loot-relevance note.
  - A new spec (`spec:<id>`) needs its stat and its four flags, which DB2 cannot give: accept it
    only with all of them known, and add its `SPEC_INDEX` row too.
- **Flags** (`keep`, `fix` or `remove`): `class-id`, `armor`, `weapon-unlisted`, `spec-missing`,
  `spec-class`, `spec-name`, `spec-index`, `spec-stat`, `titan-grip`, `shield`, `enum` and
  `skill-line`. `remove` is legal on `weapon-unlisted` alone.
- Retail's dual wield is not checked: it comes from spec passives that the skill tables do not
  carry (Frost's 674 is the one `SpecializationSpells` row), so the `D` flags stay hand-kept.

### Apply

```sh
python3 tools/seeds/seeds.py report --bundle docs/seed-research/<date>-retail --date <date>
python3 tools/seeds/seeds.py apply  --bundle docs/seed-research/<date>-retail --date <date>
```

`report` comes before `apply`, so `RULINGS.md` is written while the candidates still include what
is about to be applied. `apply` refuses while anything is unruled or a hand edit is owed, rewrites
only the changed `set(...)` entries (CRLF and the column wrap kept), and a second `apply` changes
nothing.

### After

- Roll any assertion in LibKa0s's `tests/test_verdict_classdata.lua` (and the other suites that read the list) that
  pins a row the run changed.
- Write the bundle's `ANALYSIS.md` by hand, in the 2026-11-15 bundles' shape: what the build
  says, what was proposed, accepted and rejected and why, and what a later run should re-check.
- Add a smoke check to `docs/smoke-tests.md` for every list that changed, with its
  *Pending sign-off* note. A run that changes nothing adds none.
- Re-resolve any `libs/LibKa0s/VerdictClassData.lua:N` citation the docs suite flags.

### Stage

`tools/seeds/retail_rulings.json` (the list's edit is LibKa0s's), `docs/seed-research/<date>-retail`, plus any
test, smoke or citation edits. Commit message: `Seeds (retail): re-validated against <build> (<date>)`.

## Flavor: forever

### Status

```sh
python3 tools/seeds/seeds.py status --flavor forever
```

Prints `CURRENT <build> (<bundle>)` or `NEW <build> (...)`, comparing the live `wowf` build with the
newest `*-forever` bundle.

```sh
python3 tools/seeds/seeds.py recipes status
```

Prints `CURRENT <build> (...)` or `NEW <build> (generated from <build>)`, comparing the live `wowf`
build with the `Build:` line of `core/RecipeReagentsForever.lua`. The recipe reagents follow the
class seeds' build: a run on a new build regenerates both.

### Freeze and derive

```sh
python3 tools/seeds/seeds.py derive --flavor forever --build <build> --bundle docs/seed-research/<date>-forever --date <date>
```

The same gate as Retail. Forever's own tables are `TalentTab` in place of `SpecializationSpells`;
`ChrSpecialization` holds one class-wide spec row per class there, which the list does not seed (its
rows are keyed `"<classFile>:<tree>"`).

```sh
python3 tools/seeds/seeds.py recipes derive --build <build> --bundle docs/seed-research/<date>-forever-recipes --date <date>
```

It downloads seven tables whole (about 6 MB, cached in `tools/seeds/.cache/`), runs the recipe
coverage gate (every crafting profession of `## Recipe reagents` in `SkillLine` under its name, with
at least one `SkillLineAbility` row; Jewelcrafting may be absent), and freezes the extract into the
bundle's `raw/`. **If the gate fails, stop** and fix `recipes.py`'s map. Report the recipe count, the
spells left out for want of a reagent row, the recipes an item teaches (the rest are a trainer's),
and the skill lines present and absent.

### Rule

```sh
python3 tools/seeds/seeds.py check --bundle docs/seed-research/<date>-forever
python3 tools/seeds/seeds.py rule --tsv <scratchpad>/rulings.tsv --bundle docs/seed-research/<date>-forever
```

Nuances:

- **Candidates:** `weapon:`, plus the hand candidates `class:`, `tree:<CLASS>:<n>`, `relic:`,
  `dualWield:` and `armorEarly:`. **Flags:** the Retail kinds that apply, plus `armor-early`,
  `armor-level`, `armor-lower`, `tree-missing`, `tree-name`, `relic` and `dual-wield`.
- **The level-40 switch is data.** The heavier armor line's `MinLevel` is the switch: Plate Mail and
  Mail answer 40 on 1.60.1, which is `ARMOR_LEVEL`.
- **The vanilla proficiencies are INFERRED.** A build row that adds one (a druid's polearm, a rogue's
  axe on 1.60.1) contradicts the research and LibKa0s's `tests/test_verdict_classdata.lua`, so it goes to the owner
  (`needs owner review`) and is not accepted by a run.
- **The shared literals are Retail's.** `core/Constants.lua` and `C.RECIPE_SKILL_LINE` are one table
  for both clients. A Retail-only subclass or skill line (Jewelcrafting, Inscription, Mount
  Equipment) is absent on Forever and is kept, because no Forever item ever carries it.
- **The recipe reagents take no rulings.** Nothing in them is proposed: the generator writes every
  recipe of the crafting lines that has a reagent row.

### Apply

```sh
python3 tools/seeds/seeds.py report --bundle docs/seed-research/<date>-forever --date <date>
python3 tools/seeds/seeds.py apply  --bundle docs/seed-research/<date>-forever --date <date>
```

As for Retail: `report` first, then `apply`, which refuses on anything unruled or owed by hand.

```sh
python3 tools/seeds/seeds.py recipes apply --bundle docs/seed-research/<date>-forever-recipes
python3 tools/seeds/seeds.py recipes check
```

`apply` rewrites `core/RecipeReagentsForever.lua` whole from the bundle (CRLF), and a second `apply`
changes nothing. `check` prints `OK` when the file equals the generator's output for the bundle its
header names, and exits 1 otherwise.

### After

- Roll any LibKa0s's `tests/test_verdict_classdata.lua` assertion that pins a changed row, under both kit profiles.
- Write the bundle's `ANALYSIS.md` by hand, in the 2026-11-15 bundles' shape.
- Add a FOREVER smoke check (or a `docs/forever-probes.md` probe) for every list that changed, with
  its *Pending sign-off* note.
- Recipe reagents: cross-check the skill-up ranks against ForeverDB at dev time (`## Recipe
  reagents` -> *The ForeverDB cross-check*) and write the counts into the recipes bundle's
  hand-written `ANALYSIS.md`. Roll the generated file's line count in `docs/ARCHITECTURE.md`'s
  census note if it moved, and the README badge and `docs/test-cases.md` if a suite changed.

### Stage

`tools/seeds/forever_rulings.json` (the list's edit is LibKa0s's), `docs/seed-research/<date>-forever`,
`core/RecipeReagentsForever.lua` and `docs/seed-research/<date>-forever-recipes`, plus any test,
smoke or citation edits. Commit message:
`Seeds (forever): re-validated against <build> (<date>)`.

## Recipe reagents

WoW Forever's recipe-reagent table, the lookup Item Search makes from a reagent to the recipes that
use it (the 2026-11-25 Item Search spec §4.2). ForeverDB has no reagent lists, so the table is the
client's own DB2. It is generated, so the precedent rules above have nothing to rule here.

- **The join.** `SkillLineAbility` (`Spell`, `SkillLine`, `MinSkillLineRank`,
  `TrivialSkillLineRankLow` as yellow, `TrivialSkillLineRankHigh` as gray), `SpellReagents` (up to
  eight reagents and counts), `SpellEffect` effect 24 `CREATE_ITEM` (`EffectItemType`, the item
  made, when there is one) and `SpellName` (the recipe's name). `SkillLine` names the professions for
  the coverage gate.
- **The teaching item** (ISR3-DW-08: the window's Crafting tab says where a recipe you don't know is
  learned). The build has no `ItemEffect.ParentItemID`: `ItemXItemEffect` maps an `ItemEffectID` to
  its `ItemID`. An item teaches a recipe when one of its `ItemEffect` rows has `TriggerType` 6
  (`LEARN_SPELL_ID`) and `SpellID` the recipe spell, or (any trigger) a `SpellID` whose `SpellEffect`
  effect 36 `LEARN_SPELL` has `EffectTriggerSpell` the recipe spell: an item that teaches several
  recipes at once. A `TriggerType` 0 row whose `SpellID` is the recipe itself (an item that casts it on
  use, 180 on 1.60.1.70938) teaches nothing. On 1.60.1.70938, 1,975 of the 2,493 recipes (79.2%) have a
  teaching item, 43 of them more than one; the 3 items that teach several recipes at once (effect 36)
  add 2 recipes the direct rule misses. The other 518 are a trainer's. Every
  `ItemEffect` row with a teaching `SpellID` has an `ItemXItemEffect` row.
- **Coverage by profession** (teaching item / recipes, 1.60.1.70938): Alchemy 150/196,
  Blacksmithing 416/506, Enchanting 195/262, Engineering 202/275, Leatherworking 498/592, Tailoring
  369/470, Cooking 119/133, First Aid 17/32; the gathering lines (round 4) Herbalism 2/3, Mining 3/18,
  Fishing 2/3, Skinning 2/3.
- **The professions.** Alchemy 171, Blacksmithing 164, Enchanting 333, Engineering 202,
  Leatherworking 165, Tailoring 197, Cooking 185 and First Aid 129, plus Jewelcrafting 755 if the
  build has it, and (round 4, R4-DW-03) the gathering lines Herbalism 182, Mining 186 (its smelting),
  Fishing 356 and Skinning 393 when the build has them: WoW Forever gives each a few craftable recipes
  (Incense Candle is Herbalism's). Their gathering spells have no reagent row, so only the recipes
  arrive. On 1.60.1.70938 all twelve are present and Jewelcrafting is absent.
- **What is left out.** A spell of those lines with no `SpellReagents` row: on 1.60.1.70938, 171 of
  2,664, the profession ranks and specializations among them, and some recipes the client's DB2 does
  not carry (they have no `SpellName` row either). Item Search's profession-window fallback learns
  such a recipe in game (spec §4.2 B); with no skill levels, its Skill cell reads "?" and its row
  tooltip says the levels are unknown (round 4).
- **Shape.** `NS.RecipeReagents.Get()` answers `{ build, recipes, byReagent }`:
  `recipes[spell] = { skillLine, min, yellow, gray, made, name, taught, reagents = { [item] = count } }`
  (`made` and `name` nil when the build has none, `taught` the teaching item of the lowest id, nil for
  a trainer's recipe), plus `skillLines` on the one recipe two professions teach, `taughtBy` (every
  teaching item, ascending) on a recipe more than one item teaches, and
  `byReagent[item] = { spell, ... }`, built from the rows in the file's order. The rows sit
  in a builder made only on WoW Forever (`NS.Compat.ClientKey()`, read at load) and run on the first
  `Get()`, which then lets the builder go; on Retail `Get()` answers nil and nothing is built.
- **The header** records the build, the date, the sha256 of the bundle's frozen extract (`Inputs:`)
  and the bundle. The whole tables' sha256s and row counts as served are in the bundle's
  `SOURCES.md` and `MANIFEST.json`.
- **The bundle** keeps the extract only (about 130 KB gzipped): the seven tables' headers and the
  professions' rows (and the teaching items' `ItemEffect`, `ItemXItemEffect` and effect 36 rows).
  The first bundle, `2026-11-25-forever-recipes`, holds five tables and is frozen as it was: the
  generator now reads seven, so it no longer regenerates the file, and `2026-11-26-forever-recipes`
  (the same build, the same reagent rows byte for byte) superseded it. `2026-11-26-forever-recipes-gathering`
  (round 4, the same build again, with the gathering lines; every row of the crafting lines is the same)
  supersedes that one in turn: the generator's profession map grew, so the older bundles no longer
  regenerate the file. `recipes derive --replay` re-derives the manifest from it offline.
- **The 1500-line cap binds the file** (layout-§1): it is TOC-loaded, so the generated-data
  carve-out does not exempt it. The generator packs its rows (`recipes.WRAP`) to stay under it.

### The gate test

`tools/seeds/test_recipes.py`'s `TestGate` regenerates the file from the bundle its header names and
requires the shipped bytes to equal the output, and the header's build, date and `Inputs:` digest to
equal the bundle's. A hand edit of the file or of the bundle's `raw/` turns `python3 -m pytest -q
tools/seeds` red (mutation-checked 2026-11-25). The headless suite's `tests/test_recipe_reagents.lua`
pins the load on each kit profile: built once on WoW Forever, with every reagent indexed; nil on
Retail.

### The ForeverDB cross-check

Yellow and gray are expected to match ForeverDB's `sla[spell]` positions 3 and 4 (position 1 the
skill line, 2 the minimum rank). ForeverDB is GPL-3.0 evidence, so the check runs at dev time only
and records counts, never a value (clients-§10):

```sh
python3 tools/seeds/seeds.py recipes crosscheck --bundle docs/seed-research/<date>-forever-recipes --foreverdb <cache>/foreverdb.json
```

`<cache>` is the folder dev-copilot's `scripts/foreverdb.py fetch` prints. A disagreement is
reported by spell id and goes to the owner; the DB2 value ships either way, because DB2 is the
source and ForeverDB the witness.

| Date | Build | ForeverDB | Recipes | In `sla` | Yellow and gray agree | Minimum agrees | Disagree |
| --- | --- | --- | --- | --- | --- | --- | --- |
| 2026-11-25 | 1.60.1.70938 | v2026.11.24.46 (6e0a34b) | 2,466 | 2,466 | 2,466 | 2,466 | 0 |
| 2026-11-26 | 1.60.1.70938 (with the gathering lines) | v2026.11.24.46 | 2,493 | 2,493 | 2,493 | 2,493 | 0 |

The spec (§4.2) asks for a sample; the whole table was checked, since that costs the same.

## Gathering nodes

`core/GatherNodes.lua` (Item Search round 3 spec §4.3, ISR3-DW-03) is `NS.GatherNodes[name] =
{ prof = "herbalism" | "mining", skill = n }`: the herb, vein and deposit nodes the Gathered from tab
and tooltip section name a minimum skill for. It is **hand-curated**, with no tool, no candidates and
no rulings file:

- **Provenance.** Each value is the client's own "Requires Herbalism N" or "Requires Mining N" line on
  the live node's tooltip, typed in from the classic values. It is a game fact, not a ForeverDB row:
  ForeverDB's object rows carry a name and no skill (its `oskill` and `fish` tables are empty), and
  its data is GPL-3.0 evidence that is never copied (clients-§10). **Verify in game**: smoke row
  ITEM-SEARCH-37 checks the values on WoW Forever.
- **What it holds** (2026-11-26): 28 herbs, 15 veins and deposits, and the 6 "Ooze Covered" variants
  the build has, each at its base vein's value. Fishing has no per-node skill on this client, so no
  fishing node is listed and the Skill cell is a dim dash.
- **The build check.** Every name was checked against the objects ForeverDB v2026.11.25.48 has, by
  counts only, with a scratch script in no repo: every listed name is an object that drops something;
  9 Ooze Covered names the spec listed are no object in the build and were left out; 6 object names
  the classification catches (four Thorium or Iron variants and two herbs this client adds) are not in
  the list and show "?". Repeat the check when a ForeverDB build adds nodes, and add a node only with
  its in-game value.
- **The classification** is not data: `NS.ItemSearch.GatherKind` (`modules/ItemSearchModel.lua`) files
  an object as fishing, mining or herbalism by its name, and only the herbs need this list.

## Gate

```sh
~/.claude/dev-copilot/bin/ka0s-bounded lua tests/run.lua
KA0S_KIT_CLIENT=forever ~/.claude/dev-copilot/bin/ka0s-bounded lua tests/run.lua
~/.claude/dev-copilot/bin/ka0s-bounded luacheck .
python3 -m pytest -q tools/seeds
```

luacheck must report 0 warnings and 0 errors, and every suite 0 failed. Without pytest,
`python3 -m unittest discover -s tools/seeds` runs the same cases. The pytest run includes the recipe
reagents' gate test (`## Recipe reagents` -> *The gate test*), which needs no network: it reads the
bundle's frozen extract.

## Notes

- **Bundle size.** A bundle's `raw/` is about 200 KB (Retail) and 80 KB (Forever): only the tables
  read, gzipped.
- **The open owner questions of the first run** are each a `needs owner review` rejection in the
  rulings files: the Retail Demon Hunter's daggers, and on Forever the druid's polearms, the rogue's
  one-handed axes and the shaman's dual wield. The 2026-11-15 bundles' `ANALYSIS.md` gives the
  in-game check for each. Once the owner rules, re-rule the key (a new `rule` line replaces the old
  one) and apply.
- **A ruling outlives its candidate.** After `apply`, an accepted id stops being proposed. Its
  ruling stays in the file as provenance, and that is not an error.
- **A shared helper** for the build pin, the cache, the bundle and the rulings is LibKa0s#91's to
  decide; until then the tool copies AuraMaster's pattern and imports nothing across repos.
