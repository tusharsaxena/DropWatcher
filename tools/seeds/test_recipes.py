#!/usr/bin/env python3
"""tools/seeds/test_recipes.py — recipes.py against tiny invented tables, and the recipe-reagents gate.

The fixture cases write invented CSVs (ids in the 990000s, made-up names; never a ForeverDB row,
which is GPL-3.0) into a temporary download cache, so `derive` reads them as a pinned build with no
network. The GATE case at the bottom regenerates core/RecipeReagentsForever.lua from the bundle its
own header names and requires the shipped bytes to equal it, so a hand edit of the data file (or of
the bundle's raw/) turns the commit gate red. Run: python3 -m pytest -q tools/seeds.

Mutation-checked: changing one count in core/RecipeReagentsForever.lua makes
test_gate_shipped_file_equals_generator_output fail (checked 2026-11-25, then restored).
"""

from __future__ import annotations

import csv
import gzip
import io
import json
import sys
import tempfile
import unittest
from pathlib import Path

HERE = Path(__file__).resolve().parent
if str(HERE) not in sys.path:
    sys.path.insert(0, str(HERE))

import recipes  # noqa: E402
import seeds  # noqa: E402

BUILD = "9.9.9.99999"
DATE = "2026-01-02"
LINES = {line: name for line, (name, required) in recipes.PROFESSIONS.items() if required}

SLA_HEADER = ["ID", "SkillLine", "Spell", "MinSkillLineRank", "TrivialSkillLineRankHigh", "TrivialSkillLineRankLow"]
REAGENT_HEADER = ["ID", "SpellID"] + ["Reagent_%d" % i for i in range(8)] + ["ReagentCount_%d" % i for i in range(8)]
EFFECT_HEADER = ["ID", "DifficultyID", "EffectIndex", "Effect", "EffectItemType", "EffectTriggerSpell", "SpellID"]
ITEM_EFFECT_HEADER = ["ID", "TriggerType", "SpellID"]
ITEMX_HEADER = ["ID", "ItemEffectID", "ItemID"]


def csv_of(header, rows) -> str:
    out = io.StringIO()
    w = csv.writer(out, lineterminator="\n")
    w.writerow(header)
    for r in rows:
        w.writerow(r)
    return out.getvalue()


def reagent_row(rid, spell, pairs):
    items = [p[0] for p in pairs] + [0] * (8 - len(pairs))
    counts = [p[1] for p in pairs] + [0] * (8 - len(pairs))
    return [rid, spell] + items + counts


def fixture_tables(extra_sla=(), extra_reagents=(), skill_names=None, drop_lines=()):
    """Invented tables: one recipe per required profession (spell 990100 + i), a second Tailoring
    recipe shared with Leatherworking, a recipe with no reagent row, an Enchanting recipe making
    nothing, a Mining smelt (186, a gathering line the table keeps since round 4) and noise rows of a
    line outside PROFESSIONS (633, Lockpicking) that the extract must drop. The teaching items
    (ISR3-DW-08): item 992000 teaches First Aid's recipe (TriggerType 6), items 992001 and 992002 both
    teach Blacksmithing's, item 992003 teaches the shared suit through a learning spell (990600, Effect
    36), item 992004 merely casts Leatherworking's recipe on use (trigger 0: not a teacher) and the rest are a
    trainer's; item 992009 teaches the Mining smelt, and item 992011 the Lockpicking spell, which the
    extract drops."""
    names = dict(LINES)
    names.update(skill_names or {})
    skill = [["DisplayName_lang", "ID"]] + [[n, line] for line, n in names.items() if line not in drop_lines]
    skill.append(["Mining", 186])
    skill.append(["Lockpicking", 633])
    sla, reag, eff, spellname = [], [], [], []
    sid = 1
    for i, line in enumerate(sorted(LINES)):
        if line in drop_lines:
            continue
        spell = 990100 + i
        sla.append([sid, line, spell, 1, 60 + i, 20 + i]); sid += 1
        reag.append(reagent_row(sid, spell, [(990900 + i, 2), (990999, 1)]))
        if line != 333:
            eff.append([sid, 0, 0, 24, 991000 + i, 0, spell])
        eff.append([sid + 500, 0, 1, 6, 0, 0, spell])  # an aura effect: not CREATE_ITEM
        spellname.append([spell, "Fixture \"Recipe\" %d" % i])
    # Tailoring 197 and Leatherworking 165 share one recipe, same ranks.
    sla += [[sid, 197, 990200, 5, 50, 30], [sid + 1, 165, 990200, 5, 50, 30]]; sid += 2
    reag.append(reagent_row(sid, 990200, [(990999, 3)]))
    spellname.append([990200, "Fixture Suit"])
    # A Cooking spell without a reagent row (left out), a Mining smelt (kept: a gathering line's recipe),
    # and a Lockpicking spell with a reagent (dropped: not a PROFESSIONS line).
    sla.append([sid, 185, 990300, 1, 0, 0]); sid += 1
    sla.append([sid, 186, 990400, 1, 30, 10]); sid += 1
    reag.append(reagent_row(sid, 990400, [(990998, 1)])); sid += 1
    sla.append([sid, 633, 990450, 1, 30, 10]); sid += 1
    reag.append(reagent_row(sid, 990450, [(990997, 1)]))
    sla += list(extra_sla)
    reag += list(extra_reagents)
    # The teaching items (see the docstring), and a learning spell's Effect 36.
    eff.append([7000, 0, 0, 36, 0, 990200, 990600])
    item_eff = [[8000, 6, 990100], [8001, 6, 990101], [8002, 6, 990101], [8003, 0, 990600], [8004, 0, 990102],
                [8009, 6, 990400], [8010, 6, 777777], [8011, 6, 990450]]
    itemx = [[1, 8000, 992000], [2, 8001, 992002], [3, 8002, 992001], [4, 8003, 992003], [5, 8004, 992004],
             [6, 8009, 992009], [7, 8010, 992010], [8, 8011, 992011]]
    return {
        "SkillLine": csv_of(skill[0], skill[1:]),
        "SkillLineAbility": csv_of(SLA_HEADER, sla),
        "SpellReagents": csv_of(REAGENT_HEADER, reag),
        "SpellEffect": csv_of(EFFECT_HEADER, eff),
        "SpellName": csv_of(["ID", "Name_lang"], spellname),
        "ItemEffect": csv_of(ITEM_EFFECT_HEADER, item_eff),
        "ItemXItemEffect": csv_of(ITEMX_HEADER, itemx),
    }


def write_cache(cache: Path, tables: dict) -> None:
    cache.mkdir(parents=True, exist_ok=True)
    for table, text in tables.items():
        (cache / ("%s-%s.csv" % (table, BUILD))).write_text(text, encoding="utf-8", newline="")


def model_of(tables: dict) -> dict:
    full = {t: recipes.read_rows_text(text) for t, text in tables.items()}
    return recipes.build_model(recipes.parse_extract(recipes.extract(full)))


class Fixture(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.root = Path(self.tmp.name)
        self.repo = self.root / "repo"
        (self.repo / "core").mkdir(parents=True)
        self.cache = self.root / "cache"
        self.bundle = self.repo / "docs" / "seed-research" / ("%s-forever-recipes" % DATE)

    def tearDown(self):
        self.tmp.cleanup()

    def derive(self, tables=None, replay=False):
        if not replay:
            write_cache(self.cache, tables or fixture_tables())
        return recipes.derive(self.bundle, DATE, BUILD, replay, self.cache, self.repo)

    def cli(self, *argv) -> int:
        return seeds.main(["--repo", str(self.repo), "--cache-dir", str(self.cache), "recipes"] + list(argv))


class TestModel(Fixture):
    def test_extract_keeps_the_professions_rows_only(self):
        self.derive()
        texts = recipes.read_extract(self.bundle)
        rows = recipes.parse_extract(texts)
        lines = {r["SkillLine"] for r in rows["SkillLineAbility"]}
        self.assertNotIn("633", lines)
        self.assertIn("186", lines, "a gathering line's rows are kept (round 4)")
        self.assertNotIn("990450", {r["SpellID"] for r in rows["SpellReagents"]}, "the Lockpicking spell's reagents")
        self.assertIn("990400", {r["SpellID"] for r in rows["SpellReagents"]}, "the smelt's reagents")
        self.assertEqual({r["Effect"] for r in rows["SpellEffect"]}, {"24", "36"})
        self.assertNotIn("Lockpicking", texts["SkillLine"])
        self.assertIn("Mining", texts["SkillLine"])
        self.assertEqual({r["ItemID"] for r in rows["ItemXItemEffect"]},
                         {"992000", "992001", "992002", "992003", "992004", "992009"},
                         "the Lockpicking spell's and a stranger's dropped")
        self.assertEqual(len(rows["ItemEffect"]), 6)

    def test_the_join(self):
        m = model_of(fixture_tables())
        r = m["recipes"]
        first = r[990100]  # the lowest required line, 129 First Aid
        self.assertEqual((first["skillLine"], first["min"], first["yellow"], first["gray"]), (129, 1, 20, 60))
        self.assertEqual(first["reagents"], {990900: 2, 990999: 1})
        self.assertEqual(first["made"], 991000)
        self.assertEqual(first["name"], 'Fixture "Recipe" 0')
        enchant = next(s for s, x in r.items() if x["skillLine"] == 333)
        self.assertIsNone(r[enchant]["made"], "an enchantment makes no item")
        self.assertEqual(r[990200]["skillLines"], [197, 165])
        self.assertNotIn(990300, r, "no reagent row: left out")
        self.assertEqual(r[990400]["skillLine"], 186, "a gathering line's recipe is kept (round 4)")
        self.assertNotIn(990450, r, "a line outside PROFESSIONS is not")
        s = m["stats"]
        self.assertEqual((s["recipes"], s["noReagents"], s["shared"], s["makesNoItem"]), (len(LINES) + 2, 1, 1, 3))

    def test_the_teaching_items(self):
        m = model_of(fixture_tables())
        r = m["recipes"]
        self.assertEqual(r[990100]["taught"], [992000], "TriggerType 6 teaches its SpellID")
        self.assertEqual(r[990101]["taught"], [992001, 992002], "two items, ascending")
        self.assertEqual(r[990200]["taught"], [992003], "a learning spell's Effect 36 teaches its trigger")
        self.assertEqual(r[990102]["taught"], [], "a trigger-0 cast of the recipe itself teaches nothing")
        s = m["stats"]
        self.assertEqual((s["taught"], s["taughtByMore"]), (4, 1))

    def test_the_coverage_gate(self):
        with self.assertRaises(SystemExit):
            self.derive(fixture_tables(drop_lines=(171,)))
        with self.assertRaises(SystemExit):
            self.derive(fixture_tables(skill_names={202: "Gnomish Tinkering"}))
        # Jewelcrafting and the gathering lines are optional: absent is recorded, not refused.
        m = self.derive()
        self.assertEqual(m["professions"]["absent"], [182, 356, 393, 755])
        self.assertEqual(m["professions"]["present"], sorted(list(LINES) + [186]))

    def test_a_reagent_or_rank_it_has_no_rule_for_is_refused(self):
        with self.assertRaises(SystemExit):
            model_of(fixture_tables(extra_sla=[[9001, 171, 990500, 1, 10, 5]],
                                    extra_reagents=[reagent_row(9002, 990500, [(990901, 0)])]))
        with self.assertRaises(SystemExit):
            model_of(fixture_tables(extra_sla=[[9001, 171, 990500, 1, 10, 5], [9002, 164, 990500, 1, 12, 5]],
                                    extra_reagents=[reagent_row(9003, 990500, [(990901, 1)])]))

    def test_lua_strings_and_packing(self):
        self.assertEqual(recipes.lua_string('a "b" \\ c\n'), '"a \\"b\\" \\\\ c\\n"')
        lines = recipes.pack(["x" * 100] * 7, "    ")
        self.assertTrue(all(len(line) <= recipes.WRAP for line in lines))
        self.assertEqual(sum(line.count("x" * 100) for line in lines), 7)

    def test_crosscheck_answers_counts_only(self):
        m = model_of(fixture_tables())
        sla = {"990100": [[129, 1, 20, 60, 0]], "990101": [[164, 1, 99, 99]], "990102": [[999, 1, 1, 1]]}
        c = recipes.crosscheck(m, sla)
        self.assertEqual((c["inSla"], c["match"], c["minMatch"], c["noLineRow"]), (3, 1, 2, 1))
        self.assertEqual(c["mismatch"], [990101])


class TestCli(Fixture):
    def test_derive_apply_check_round_trip_and_a_hand_edit(self):
        self.derive()
        self.assertEqual(self.cli("apply", "--bundle", str(self.bundle)), 0)
        out = self.repo / recipes.OUTPUT
        data = out.read_bytes()
        self.assertIn(b"\r\n", data, "the repo is pinned CRLF")
        text = data.decode("utf-8")
        self.assertIn("-- Build:   %s" % BUILD, text)
        self.assertIn("-- Bundle:  docs/seed-research/%s-forever-recipes" % DATE, text)
        self.assertIn('r(990100, 129, 1, 20, 60, 991000, "Fixture \\"Recipe\\" 0", 992000, 990900, 2, 990999, 1)', text)
        self.assertIn('r(990102, 165, 1, 22, 62, 991002, "Fixture \\"Recipe\\" 2", nil, 990902, 2, 990999, 1)', text)
        self.assertIn("shared(990200, 197, 165)", text)
        self.assertIn("teachers(990101, 992001, 992002)", text)
        self.assertIn("4 recipes are taught by an item (1 by more than one); the other 6 are a trainer's.", text)
        self.assertEqual(self.cli("check"), 0)
        # A second apply changes nothing.
        self.assertEqual(self.cli("apply", "--bundle", str(self.bundle)), 0)
        self.assertEqual(out.read_bytes(), data)
        # A hand edit is caught.
        out.write_bytes(data.replace(b"990900, 2", b"990900, 3"))
        self.assertEqual(self.cli("check"), 1)

    def test_replay_reproduces_the_manifest_and_a_tampered_extract_is_refused(self):
        first = self.derive()
        again = self.derive(replay=True)
        self.assertEqual(first, again)
        manifest = json.loads((self.bundle / "MANIFEST.json").read_text(encoding="utf-8"))
        self.assertEqual(manifest["extractSha256"], recipes.digest(recipes.read_extract(self.bundle)))
        self.assertTrue((self.bundle / "SOURCES.md").read_bytes().count(b"\r\n") > 5)
        member = self.bundle / "raw" / "SpellName.csv.gz"
        recipes.freeze_text(gzip.open(member, "rt", encoding="utf-8").read().replace("Suit", "Coat"), member)
        with self.assertRaises(SystemExit):
            recipes.generate(self.bundle, self.repo)

    def test_the_frozen_extract_is_byte_stable(self):
        self.derive()
        raw = {p.name: p.read_bytes() for p in (self.bundle / "raw").iterdir()}
        self.derive()
        self.assertEqual(raw, {p.name: p.read_bytes() for p in (self.bundle / "raw").iterdir()})


class TestGate(unittest.TestCase):
    """The recipe-reagents seed's gate (docs/validate-seeds.md -> Recipe reagents)."""

    def test_gate_shipped_file_equals_generator_output(self):
        ok, msg = recipes.check(seeds.REPO)
        self.assertTrue(ok, msg)

    def test_gate_header_names_the_bundle_build_and_digest(self):
        text = (seeds.REPO / recipes.OUTPUT).read_text(encoding="utf-8")
        fields = recipes.header_fields(text)
        bundle = seeds.REPO / fields["Bundle"]
        manifest = json.loads((bundle / "MANIFEST.json").read_text(encoding="utf-8"))
        self.assertEqual(manifest["product"], "wowf")
        self.assertEqual(fields["Build"], manifest["build"])
        self.assertEqual(fields["Date"], manifest["date"])
        self.assertEqual(fields["Inputs"], recipes.digest(recipes.read_extract(bundle)))
        self.assertIsNotNone(seeds.DATE_RE.match(fields["Date"]))


if __name__ == "__main__":
    unittest.main()
