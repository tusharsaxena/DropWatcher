# Seed validation — Drop Watcher

The seed-validation contract `/dev-copilot:validate-seeds DropWatcher <flavor>` runs. The command
supplies the loop (clean tree, one date, status, derive, rule, apply, gate, hand-back) and its
standing rules. This file supplies Drop Watcher's procedure: the tool, the files it writes, the
precedent a ruling follows and the nuances of each client. The headings below are the interface
the command reads, so keep their names.

The seeds are the class lists (clients-§5): `core/ClassData.lua` for Retail and
`core/ClassDataForever.lua` for WoW Forever, each built by `CD.Build`. Every run also checks the
item enum fallback literals in `core/Constants.lua` (`C.ITEM_CLASS`, `C.WEAPON_SUBCLASS`,
`C.ARMOR_SUBCLASS`, `C.RECIPE_SUBCLASS`, `C.MISC_SUBCLASS`), the recipe skill lines
(`C.RECIPE_SKILL_LINE`, `modules/CollectCells.lua`'s `PROFESSION`) and `core/ItemRead.lua`'s
`IR.GEAR_CLASSES`. These are name and existence checks only, with no candidates: they mirror the
client's enums and are not a curated list. Nothing else in `core/` or `modules/` is a seed: the
inventory slots (`C.SLOT`) are FrameXML constants that no DB2 table holds, `C.TIER_TOKENS` and
`C.TRACK_TIER_BY_STRING_ID` are empty, and `core/CompatJournal.lua`, `modules/TestData.lua` and the
simulator's files hold reads or invented test data, not game ids.

Each run ends in a frozen bundle under `docs/seed-research/<date>-<flavor>/`. The tool is
`tools/seeds/seeds.py`, and its docstring is the reference for every candidate and flag kind. The
first runs are `docs/seed-research/2026-11-15-retail/` and `docs/seed-research/2026-11-15-forever/`.

## Flavors

| Flavor | Source | Seed files | Tools |
| --- | --- | --- | --- |
| `retail` | wago.tools product `wow` (Retail live) | `core/ClassData.lua` (hand-curated, tool-checked; `apply` writes `RETAIL.WEAPONS` only), plus the shared literals above (checked only) | `tools/seeds/seeds.py --flavor retail` |
| `forever` | wago.tools product `wowf` (WoW Forever) | `core/ClassDataForever.lua` (hand-curated, tool-checked; `apply` writes `FOREVER.WEAPONS` only), plus the shared literals above (checked only) | `tools/seeds/seeds.py --flavor forever` |

## Rules

- **Only `apply` writes a WEAPONS set**, and only for an accepted `weapon:` candidate or a
  `weapon-unlisted` flag ruled `remove`. Every other row (class ids, armor, specs, trees, relics,
  flags such as `D`, `T`, `S`) is a hand edit. An accepted hand candidate or a flag ruled `fix` makes
  `apply` refuse until the file carries the edit and a `derive --replay` stops raising it.
- **Rulings are data.** They live in `tools/seeds/retail_rulings.json` and
  `tools/seeds/forever_rulings.json`, written only by `seeds.py rule`. A ruling is keyed
  `<group>:<subject>` for a candidate or `shipped:<kind>:<subject>` for a flag, never by build, and it
  holds until the thing it ruled on stops being proposed.
- **Precedent, in this order, never re-litigated:**
  1. a ruling already in the flavor's rulings file;
  2. the seed file's own header and comments. The one that decides most weapon candidates is
     `core/ClassData.lua`'s note above `RETAIL.WEAPONS`: a skill the class has but no loot of its
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
  5. the assertions in `tests/test_class_data.lua`, which pin today's lists. A ruling that
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

- Roll any assertion in `tests/test_class_data.lua` (and the other suites that read the list) that
  pins a row the run changed.
- Write the bundle's `ANALYSIS.md` by hand, in the 2026-11-15 bundles' shape: what the build
  says, what was proposed, accepted and rejected and why, and what a later run should re-check.
- Add a smoke check to `docs/smoke-tests.md` for every list that changed, with its
  *Pending sign-off* note. A run that changes nothing adds none.
- Re-resolve any `core/ClassData.lua:N` citation the docs suite flags.

### Stage

`core/ClassData.lua`, `tools/seeds/retail_rulings.json`, `docs/seed-research/<date>-retail`, plus any
test, smoke or citation edits. Commit message: `Seeds (retail): re-validated against <build> (<date>)`.

## Flavor: forever

### Status

```sh
python3 tools/seeds/seeds.py status --flavor forever
```

Prints `CURRENT <build> (<bundle>)` or `NEW <build> (...)`, comparing the live `wowf` build with the
newest `*-forever` bundle.

### Freeze and derive

```sh
python3 tools/seeds/seeds.py derive --flavor forever --build <build> --bundle docs/seed-research/<date>-forever --date <date>
```

The same gate as Retail. Forever's own tables are `TalentTab` in place of `SpecializationSpells`;
`ChrSpecialization` holds one class-wide spec row per class there, which the list does not seed (its
rows are keyed `"<classFile>:<tree>"`).

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
  axe on 1.60.1) contradicts the research and `tests/test_class_data.lua`, so it goes to the owner
  (`needs owner review`) and is not accepted by a run.
- **The shared literals are Retail's.** `core/Constants.lua` and `C.RECIPE_SKILL_LINE` are one table
  for both clients. A Retail-only subclass or skill line (Jewelcrafting, Inscription, Mount
  Equipment) is absent on Forever and is kept, because no Forever item ever carries it.

### Apply

```sh
python3 tools/seeds/seeds.py report --bundle docs/seed-research/<date>-forever --date <date>
python3 tools/seeds/seeds.py apply  --bundle docs/seed-research/<date>-forever --date <date>
```

As for Retail: `report` first, then `apply`, which refuses on anything unruled or owed by hand.

### After

- Roll any `tests/test_class_data.lua` assertion that pins a changed row, under both kit profiles.
- Write the bundle's `ANALYSIS.md` by hand, in the 2026-11-15 bundles' shape.
- Add a FOREVER smoke check (or a `docs/forever-probes.md` probe) for every list that changed, with
  its *Pending sign-off* note.

### Stage

`core/ClassDataForever.lua`, `tools/seeds/forever_rulings.json`, `docs/seed-research/<date>-forever`,
plus any test, smoke or citation edits. Commit message:
`Seeds (forever): re-validated against <build> (<date>)`.

## Gate

```sh
~/.claude/dev-copilot/bin/ka0s-bounded lua tests/run.lua
KA0S_KIT_CLIENT=forever ~/.claude/dev-copilot/bin/ka0s-bounded lua tests/run.lua
~/.claude/dev-copilot/bin/ka0s-bounded luacheck .
python3 -m pytest -q tools/seeds
```

luacheck must report 0 warnings and 0 errors, and every suite 0 failed. Without pytest,
`python3 -m unittest discover -s tools/seeds` runs the same cases.

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
