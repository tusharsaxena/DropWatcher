#!/usr/bin/env python3
"""tools/seeds/seeds.py — re-validate Drop Watcher's item enum literals and recipe skill lines
against a wago.tools build.

WHAT THIS IS
    core/Constants.lua mirrors the client's item class and subclass enums as fallback literals
    (C.ITEM_CLASS, C.WEAPON_SUBCLASS, C.ARMOR_SUBCLASS, C.RECIPE_SUBCLASS, C.MISC_SUBCLASS) and maps
    each recipe subclass to its profession's skill line (C.RECIPE_SKILL_LINE), and
    modules/CollectCells.lua names each profession by its skill line (PROFESSION). None of it turns
    red when a patch moves it. This tool re-checks every one of those rows against ONE pinned build
    of the client's own DB2 data on wago.tools (clients-§10: product `wow` for Retail, `wowf` for
    Forever, never one filtered from the other) and turns what it finds into FLAGS, each of which
    needs a ruling recorded as data. A ruling is keyed by what it ruled on, never by build, so a
    re-run on a later build shows only what is new.

    The class lists (class ids, armor, weapons, specs and talent trees, Titan's Grip, shields, dual
    wield, relics) and the gear classes are LibKa0s-Verdict-1.0's (VerdictClassData.lua,
    VerdictFacts.lua), vendored here: their seed contract is LibKa0s's tools/seeds/classseeds.py,
    flavors retail-classes and forever-classes of its docs/validate-seeds.md (LibKa0s#109).

    Flags (key `shipped:<kind>:<subject>`, ruled keep or fix), over every shipped row:
        enum             a Constants fallback literal the build has not, or names otherwise
        skill-line       a recipe skill line the build has not, or names otherwise
    `fix` means a hand edit is owed: `apply` refuses while one is raised. The contract,
    docs/validate-seeds.md, is the procedure and the precedent.

THE STEPS
    python3 tools/seeds/seeds.py status [--flavor retail|forever]
    python3 tools/seeds/seeds.py derive --flavor F --bundle docs/seed-research/<date>-F --date <date> [--build V] [--replay]
    python3 tools/seeds/seeds.py check  --bundle B
    python3 tools/seeds/seeds.py rule   --tsv <scratch>/rulings.tsv --bundle B
    python3 tools/seeds/seeds.py report --bundle B --date <date>
    python3 tools/seeds/seeds.py apply  --bundle B --date <date>

    `derive` pins one build (the live one of the flavor's product, or --build), downloads each table
    once into tools/seeds/.cache/ (git-ignored), freezes the gzipped tables it read into the
    bundle's raw/ and writes SOURCES.md and candidates.json. `--replay` re-derives from raw/ alone,
    with no network. The rulings live in tools/seeds/<flavor>_rulings.json, and `rule` is their only
    writer. `check` exits 1 while anything is unruled. `report` writes RULINGS.md. `apply` is the
    gate: it refuses while anything is unruled or a hand edit is owed, and writes nothing (every
    edit these checks can ask for is a hand edit). The date is always an argument; the tool never
    reads the clock.

    The shape follows AuraMaster's tools/spell-research/retail.py (copied as a pattern, never
    imported across repos). Whether the build pin, the cache, the bundle and the rulings become one
    shared helper, and where it lives, is LibKa0s#91.

Python 3.8+ and its standard library only.
"""

from __future__ import annotations

import argparse
import csv
import gzip
import json
import re
import shutil
import sys
import urllib.error
import urllib.request
from pathlib import Path

HERE = Path(__file__).resolve().parent
REPO = HERE.parent.parent
RESEARCH = REPO / "docs" / "seed-research"

BUILDS_URL = "https://wago.tools/api/builds"
CSV_URL = "https://wago.tools/db2/{table}/csv?build={build}"
# wago.tools answers HTTP 403 to urllib's default agent (clients-§10): identify the tool.
USER_AGENT = "ka0s-dropwatcher-seed-validation"
DOWNLOAD_CHUNK = 1 << 20
DATE_RE = re.compile(r"^\d{4}-\d{2}-\d{2}$")
NEWLINE = "\r\n"  # .gitattributes pins the working tree CRLF (`* text=auto eol=crlf`)

# The tables each flavor reads, and why. Only these are frozen into a bundle's raw/.
COMMON_TABLES = (
    ("SkillLine", "the recipe skill lines' names"),
    ("ItemClass", "item class ids and names, for the Constants fallback literals"),
    ("ItemSubClass", "item subclass ids and names, for the Constants fallback literals"),
)
FLAVORS = {
    "retail": {"product": "wow", "title": "Retail", "tables": COMMON_TABLES},
    "forever": {"product": "wowf", "title": "WoW Forever", "tables": COMMON_TABLES},
}
CONSTANTS = "core/Constants.lua"
COLLECT_CELLS = "modules/CollectCells.lua"
SEED_FILES = (CONSTANTS, COLLECT_CELLS)

# The coverage gate: rows the build must have, chosen from the game, not from this tool's output
# (the item classes the gear verdicts rest on, and two professions both clients have).
SENTINELS = {"item_classes": {2: "Weapon", 4: "Armor"}, "skill_lines": {164: "Blacksmithing", 197: "Tailoring"}}

# The Constants fallback tables -> the DB2 item class they mirror (None: ItemClass itself).
ENUM_TABLES = {"ITEM_CLASS": None, "WEAPON_SUBCLASS": 2, "ARMOR_SUBCLASS": 4,
               "RECIPE_SUBCLASS": 9, "MISC_SUBCLASS": 15}
# An enum member whose DB2 name differs by design.
ENUM_ALIASES = {"GENERIC": ("miscellaneous",)}

FLAG_RULINGS = ("keep", "fix")
KEY_RE = re.compile(r"^shipped:(?P<kind>[a-z-]+):(?P<subject>[A-Za-z0-9_:]+)$")


def log(msg: str) -> None:
    print(msg, file=sys.stderr, flush=True)


def write_repo_text(path: Path, text: str) -> None:
    """Write a text file with CRLF terminators, as bytes (the repo is pinned eol=crlf)."""
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_bytes(text.replace("\r\n", "\n").replace("\n", NEWLINE).encode("utf-8"))


def write_json(path: Path, doc) -> None:
    write_repo_text(path, json.dumps(doc, indent=1, sort_keys=True, ensure_ascii=False) + "\n")


# ---------------------------------------------------------------------------
# wago.tools: the build pin, the cache, the bundle's raw/
# ---------------------------------------------------------------------------

def http_get(url: str, accept: str = "*/*"):
    req = urllib.request.Request(url, headers={"User-Agent": USER_AGENT, "Accept": accept})
    try:
        return urllib.request.urlopen(req, timeout=300)
    except urllib.error.HTTPError as err:
        raise SystemExit("HTTP %s fetching %s: %s" % (err.code, url, err.reason))
    except urllib.error.URLError as err:
        raise SystemExit("Could not reach %s: %s (a new run needs network access)" % (url, err.reason))


def live_build(product: str) -> str:
    """The newest build of `product` on the builds API (newest first per product)."""
    data = json.load(http_get(BUILDS_URL, accept="application/json"))
    builds = data.get(product) or []
    if not builds:
        raise SystemExit("The builds API lists no '%s' build; pass --build." % product)
    return builds[0]["version"]


def fetch_table(table: str, build: str, cache_dir: Path) -> tuple[Path, str]:
    """`(cached CSV, provenance)`: the table of `build`, streamed into the cache once. Always with
    `?build=`: without it the site serves the PTR (clients-§10)."""
    cache_dir.mkdir(parents=True, exist_ok=True)
    dest = cache_dir / ("%s-%s.csv" % (table, build))
    if dest.exists():
        return dest, "cache"
    url = CSV_URL.format(table=table, build=build)
    tmp = dest.with_suffix(".csv.part")
    log("  %-22s fetching %s" % (table, url))
    with http_get(url, accept="text/csv") as response, tmp.open("wb") as handle:
        served = response.headers.get("Date", "")
        shutil.copyfileobj(response, handle, DOWNLOAD_CHUNK)
    tmp.replace(dest)
    return dest, served


def freeze(source: Path, member: Path) -> None:
    """Gzip `source` into the bundle's raw/ (mtime 0, so a re-freeze of one build is byte-stable)."""
    member.parent.mkdir(parents=True, exist_ok=True)
    with source.open("rb") as src, member.open("wb") as raw:
        with gzip.GzipFile(filename="", mode="wb", fileobj=raw, compresslevel=9, mtime=0) as dst:
            shutil.copyfileobj(src, dst, DOWNLOAD_CHUNK)


def iter_csv(path: Path):
    """Each row as a dict, streamed (gzip or plain); columns are read by header name."""
    if path.suffix == ".gz":
        with gzip.open(path, "rt", encoding="utf-8", newline="") as handle:
            yield from csv.DictReader(handle)
        return
    with path.open("r", encoding="utf-8", newline="") as handle:
        yield from csv.DictReader(handle)


def as_int(value) -> int:
    try:
        return int(value or 0)
    except ValueError:
        return int(float(value))


# ---------------------------------------------------------------------------
# The build's facts
# ---------------------------------------------------------------------------

class Build:
    """What one build says, read from `{table: path}`."""

    def __init__(self, paths: dict[str, Path], flavor: str):
        self.flavor = flavor
        self.skill_names = {as_int(r["ID"]): r["DisplayName_lang"] for r in iter_csv(paths["SkillLine"])}
        self.item_class = {as_int(r["ClassID"]): r["ClassName_lang"] for r in iter_csv(paths["ItemClass"])}
        self.subclass = {(as_int(r["ClassID"]), as_int(r["SubClassID"])): (r["DisplayName_lang"], r["VerboseName_lang"])
                         for r in iter_csv(paths["ItemSubClass"])}


def check_sentinels(build: Build, sentinels=SENTINELS) -> None:
    """The coverage gate. A failure is a SystemExit: the pipeline needs fixing, not the rulings."""
    missing = ["item class %d %s" % (cid, name) for cid, name in sentinels["item_classes"].items()
               if build.item_class.get(cid) != name]
    missing += ["skill line %d %s" % (sid, name) for sid, name in sentinels["skill_lines"].items()
                if build.skill_names.get(sid) != name]
    if missing:
        raise SystemExit("Coverage gate FAILED: %s. Fix the tool before ruling anything." % "; ".join(missing))


# ---------------------------------------------------------------------------
# The seed files
# ---------------------------------------------------------------------------

def lua_block(text: str, opener: str) -> tuple[int, int] | None:
    """`(start, end)` of the body between the `{` that ends `opener` and its matching `}`; a
    `--` comment and a string are skipped while matching."""
    at = text.find(opener)
    if at < 0:
        return None
    i = at + len(opener)
    start, depth = i, 1
    while i < len(text):
        c = text[i]
        if text.startswith("--", i):
            nl = text.find("\n", i)
            i = len(text) if nl < 0 else nl
            continue
        if c in "\"'":
            j = i + 1
            while j < len(text) and text[j] != c:
                j += 2 if text[j] == "\\" else 1
            i = j + 1
            continue
        if c == "{":
            depth += 1
        elif c == "}":
            depth -= 1
            if depth == 0:
                return start, i
        i += 1
    raise SystemExit("Unbalanced braces after %r" % opener)


def block(text: str, opener: str) -> str:
    span = lua_block(text, opener)
    return text[span[0]:span[1]] if span else ""


def read_enums(constants: Path, collect_cells: Path) -> dict:
    """The fallback literals: {table: {TOKEN: (enum member, literal)}}, plus RECIPE_SKILL_LINE
    ({TOKEN: skill line}) and PROFESSION ({skill line: name})."""
    text = constants.read_bytes().decode("utf-8").replace("\r\n", "\n")
    out = {}
    for name in ENUM_TABLES:
        m = re.search(r"C\.%s = fromEnum\([\w.]+, \{" % name, text)
        body = block(text, m.group(0)) if m else ""
        rows = re.findall(r"(\w+)\s*=\s*\{\s*\"(\w+)\",\s*(\d+)\s*\}", body)
        out[name] = {k: (member, int(v)) for k, member, v in rows}
    out["RECIPE_SKILL_LINE"] = {k: int(v) for k, v in
                                re.findall(r"\[RS\.(\w+)\]\s*=\s*(\d+)", block(text, "C.RECIPE_SKILL_LINE = {"))}
    cells = collect_cells.read_bytes().decode("utf-8")
    out["PROFESSION"] = {int(k): v for k, v in re.findall(r'\[(\d+)\]\s*=\s*L\["([^"]+)"\]', block(cells, "local PROFESSION = {"))}
    for name in ENUM_TABLES:
        if not out[name]:
            raise SystemExit("%s: C.%s did not parse; the tool and the file disagree." % (constants, name))
    return out


# ---------------------------------------------------------------------------
# Flags
# ---------------------------------------------------------------------------

def norm(text: str) -> str:
    return re.sub(r"[^a-z0-9]", "", (text or "").lower())


def enum_names_match(token: str, member: str, db_names) -> bool:
    """Whether an enum key or member names the DB2 row: equal, a plural, or a prefix (FIST and
    "Fist Weapons", AXE_1H and "Axe"), or a recorded alias (GENERIC is "Miscellaneous")."""
    ours = {norm(re.sub(r"_?[12]H$", "", token)), norm(member), norm(re.sub(r"[12]H$", "", member))}
    ours |= set(ENUM_ALIASES.get(token, ()))
    theirs = set()
    for name in db_names:
        n = norm(name)
        if n:
            theirs |= {n, n[:-1] if n.endswith("s") else n}
    return any(a and b and (a == b or b.startswith(a)) for a in ours for b in theirs)


class Findings:
    def __init__(self):
        self.flags: list[dict] = []

    def flag(self, kind: str, subject: str, shipped: str, build: str, notes=()) -> None:
        self.flags.append({"key": "shipped:%s:%s" % (kind, subject), "kind": kind, "subject": subject,
                           "shipped": shipped, "build": build, "notes": list(notes)})


def check_enums(enums: dict, db: Build, out: Findings) -> None:
    for table, item_class in ENUM_TABLES.items():
        for token, (member, literal) in sorted(enums[table].items()):
            if item_class is None:
                names = [db.item_class[literal]] if literal in db.item_class else []
            else:
                names = list(db.subclass.get((item_class, literal), ()))
            subject = "%s:%s" % (table, token)
            if not names:
                out.flag("enum", subject, "%s = %d" % (member, literal), "absent")
            elif not enum_names_match(token, member, names):
                out.flag("enum", subject, "%s = %d" % (member, literal), " / ".join(n for n in names if n))
    for token, skill in sorted(enums["RECIPE_SKILL_LINE"].items()):
        have = db.skill_names.get(skill)
        if norm(have) != norm(token):
            out.flag("skill-line", "RECIPE_SKILL_LINE:%d" % skill, token, have or "absent")
    for skill, name in sorted(enums["PROFESSION"].items()):
        have = db.skill_names.get(skill)
        if norm(have) != norm(name):
            out.flag("skill-line", "PROFESSION:%d" % skill, name, have or "absent")


def derive_findings(paths: dict[str, Path], flavor: str, repo: Path = REPO, sentinels=SENTINELS) -> tuple[dict, dict]:
    """`(findings document, counts of shipped rows checked)` for one flavor."""
    db = Build(paths, flavor)
    check_sentinels(db, sentinels)
    enums = read_enums(repo / CONSTANTS, repo / COLLECT_CELLS)
    out = Findings()
    check_enums(enums, db, out)
    checked = {"enum literals": sum(len(enums[t]) for t in ENUM_TABLES),
               "skill lines": len(enums["RECIPE_SKILL_LINE"]) + len(enums["PROFESSION"])}
    # No candidates: these mirror the client's enums and are not a curated list. The key stays, so a
    # bundle reads as the class-list bundles before it did.
    return {"candidates": [], "flags": out.flags}, checked


# ---------------------------------------------------------------------------
# Bundles and rulings
# ---------------------------------------------------------------------------

def rulings_path(flavor: str, tool_dir: Path = HERE) -> Path:
    return tool_dir / ("%s_rulings.json" % flavor)


def load_rulings(path: Path) -> dict:
    return json.loads(path.read_text(encoding="utf-8")) if path.exists() else {}


def save_rulings(path: Path, rulings: dict) -> None:
    write_repo_text(path, json.dumps(rulings, indent=2, sort_keys=True, ensure_ascii=False) + "\n")


def load_doc(bundle: Path) -> dict:
    path = bundle / "candidates.json"
    if not path.exists():
        raise SystemExit("%s has no candidates.json: run seeds.py derive first." % bundle)
    return json.loads(path.read_text(encoding="utf-8"))


def all_keys(doc: dict) -> list[str]:
    return [c["key"] for c in doc.get("candidates", ())] + [f["key"] for f in doc["flags"]]


def unruled(doc: dict, rulings: dict) -> list[str]:
    return [k for k in all_keys(doc) if k not in rulings]


def set_ruling(rulings: dict, key: str, ruling: str, reason: str) -> None:
    if not KEY_RE.match(key or ""):
        raise SystemExit("%r is not shipped:<kind>:<subject>." % key)
    if ruling not in FLAG_RULINGS:
        raise SystemExit("the ruling for %s must be %s; got %r." % (key, " or ".join(FLAG_RULINGS), ruling))
    reason = (reason or "").strip()
    if not reason or "\n" in reason:
        raise SystemExit("the reason for %s must be one non-empty line." % key)
    rulings[key] = {"ruling": ruling, "reason": reason}


def read_tsv(path: Path) -> list[tuple[str, str, str]]:
    out = []
    for line in path.read_text(encoding="utf-8").splitlines():
        if not line.strip() or line.startswith("#"):
            continue
        parts = line.split("\t")
        if len(parts) != 3:
            raise SystemExit("%s: a ruling line is key<TAB>ruling<TAB>reason; got %r" % (path, line))
        out.append(tuple(p.strip() for p in parts))
    return out


def bundles(flavor: str, root: Path = RESEARCH) -> list[Path]:
    return sorted(p for p in root.glob("*-" + flavor) if (p / "candidates.json").exists())


def status_line(live: str, found: list[Path]) -> str:
    """`CURRENT <build> (<bundle>)`, else `NEW <build> ...`; the first word is what
    /dev-copilot:validate-seeds reads."""
    if not found:
        return "NEW %s (no bundle yet)" % live
    last = found[-1]
    built = load_doc(last)["build"]
    if built == live:
        return "CURRENT %s (%s)" % (live, last.name)
    return "NEW %s (last ruled %s, %s)" % (live, built, last.name)


def bundle_tables(flavor: str, bundle: Path, build: str, replay: bool, cache_dir: Path) -> tuple[dict, dict]:
    """`({table: raw member}, {table: provenance})`, fetched into the cache and frozen into raw/,
    or with `replay` read from raw/ alone (a missing member is fatal)."""
    paths, served = {}, {}
    for table, _why in FLAVORS[flavor]["tables"]:
        member = bundle / "raw" / ("%s.csv.gz" % table)
        if replay:
            if not member.exists():
                raise SystemExit("--replay: %s is missing raw/%s.csv.gz." % (bundle, table))
            served[table] = "replayed from raw/"
        else:
            source, served[table] = fetch_table(table, build, cache_dir)
            freeze(source, member)
        paths[table] = member
    return paths, served


def format_sources(doc: dict, flavor: str) -> str:
    spec = FLAVORS[flavor]
    lines = ["# Sources — Drop Watcher seed validation, %s (%s)" % (doc["date"], spec["title"]), "",
             "Generated by `tools/seeds/seeds.py derive`. Frozen: this directory is never edited after the "
             "run, apart from the hand-written `ANALYSIS.md`.", "",
             "| Field | Value |", "| --- | --- |",
             "| Flavor | `%s` (%s, wago product `%s`) |" % (flavor, spec["title"], spec["product"]),
             "| Build | `%s` |" % doc["build"], "| Date | %s (the run's argument) |" % doc["date"],
             "| Builds API | <%s> |" % BUILDS_URL,
             "| Seed files | %s |" % ", ".join("`%s`" % f for f in doc["seedFiles"]), "",
             "## Tables", "", "| Table | Why | Served | URL |", "| --- | --- | --- | --- |"]
    for table, why in spec["tables"]:
        url = CSV_URL.format(table=table, build=doc["build"])
        lines.append("| `%s` | %s | %s | <%s> |" % (table, why, doc["served"].get(table, "") or "-", url))
    lines += ["", "The gzipped exports are in `raw/`; `seeds.py derive --replay` re-derives this bundle from them "
              "offline. A new run needs network access to wago.tools.", "",
              "## Shipped rows checked", "", "| List | Rows |", "| --- | --- |"]
    lines += ["| %s | %d |" % (k, v) for k, v in doc["checked"].items()]
    lines += ["", "%d flags." % len(doc["flags"]), ""]
    return "\n".join(lines)


def _cell(text) -> str:
    return str(text or "").replace("|", "\\|")


def format_rulings(doc: dict, rulings: dict, date: str) -> str:
    tally: dict[str, int] = {}
    for key in all_keys(doc):
        r = rulings.get(key, {}).get("ruling", "unruled")
        tally[r] = tally.get(r, 0) + 1
    lines = ["# Rulings — Drop Watcher seed validation, %s (%s, build %s)" % (doc["date"], doc["flavor"], doc["build"]), "",
             "Generated by `tools/seeds/seeds.py report` on %s from this bundle's `candidates.json` and "
             "`tools/seeds/%s_rulings.json`. Do not edit by hand." % (date, doc["flavor"]), "",
             "%d flags: %s." % (len(doc["flags"]), ", ".join("%d %s" % (n, r) for r, n in sorted(tally.items())) or "none"), ""]
    missing = unruled(doc, rulings)
    if missing:
        lines += ["## Unruled — %d" % len(missing), ""] + ["- `%s`" % k for k in missing] + [""]
    lines += ["## Shipped-row flags — %d" % len(doc["flags"]), ""]
    if doc["flags"]:
        lines += ["| Key | Shipped | Build | Evidence | Ruling | Reason |", "| --- | --- | --- | --- | --- | --- |"]
        for f in doc["flags"]:
            r = rulings.get(f["key"], {})
            lines.append("| `%s` | %s | %s | %s | %s | %s |" % (f["key"], _cell(f["shipped"]), _cell(f["build"]), _cell("; ".join(f["notes"])),
                                                         r.get("ruling", "**unruled**"), _cell(r.get("reason"))))
    else:
        lines.append("None.")
    lines.append("")
    return "\n".join(lines)


# ---------------------------------------------------------------------------
# Apply: the gate
# ---------------------------------------------------------------------------

def plan_apply(doc: dict, rulings: dict) -> list[str]:
    """What apply would write: nothing, since every edit these checks ask for is a hand edit.
    Refuses while anything is unruled, or a hand edit is owed (a flag ruled fix)."""
    missing = unruled(doc, rulings)
    if missing:
        raise SystemExit("apply refused: %d key(s) unruled (seeds.py check lists them)." % len(missing))
    owed = [f["key"] for f in doc["flags"] if rulings[f["key"]]["ruling"] == "fix"]
    if owed:
        raise SystemExit("apply refused: a hand edit is owed for %s. Edit the file, re-derive with --replay, "
                         "then apply." % ", ".join(owed))
    return []


# ---------------------------------------------------------------------------
# Commands
# ---------------------------------------------------------------------------

def _date(value: str) -> str:
    if not DATE_RE.match(value):
        raise argparse.ArgumentTypeError("a date is YYYY-MM-DD; got %r" % value)
    return value


def cmd_status(args) -> int:
    for flavor in ([args.flavor] if args.flavor else list(FLAVORS)):
        line = status_line(live_build(FLAVORS[flavor]["product"]), bundles(flavor, args.root))
        print(line if args.flavor else "%s: %s" % (flavor, line))
    return 0


def cmd_derive(args) -> int:
    flavor = args.flavor
    if args.replay:
        build = args.build or load_doc(args.bundle)["build"]
    else:
        build = args.build or live_build(FLAVORS[flavor]["product"])
    log("Deriving %s against build %s into %s" % (flavor, build, args.bundle))
    paths, served = bundle_tables(flavor, args.bundle, build, args.replay, args.cache_dir)
    found, checked = derive_findings(paths, flavor, args.repo)
    if args.replay and (args.bundle / "candidates.json").exists():
        served = load_doc(args.bundle).get("served", served)
    doc = {"flavor": flavor, "product": FLAVORS[flavor]["product"], "build": build, "date": args.date,
           "tool": "tools/seeds/seeds.py derive", "served": served, "checked": checked,
           "seedFiles": list(SEED_FILES)}
    doc.update(found)
    write_json(args.bundle / "candidates.json", doc)
    write_repo_text(args.bundle / "SOURCES.md", format_sources(doc, flavor))
    missing = unruled(doc, load_rulings(rulings_path(flavor, args.tool_dir)))
    log("%d flags, %d unruled" % (len(doc["flags"]), len(missing)))
    return 0


def cmd_rule(args) -> int:
    doc = load_doc(args.bundle)
    todo = [(k, args.ruling, args.reason) for k in (args.key or ())]
    if args.tsv:
        todo += read_tsv(args.tsv)
    if not todo:
        raise SystemExit("rule needs --key (with --ruling and --reason) or --tsv.")
    known = set(all_keys(doc))
    path = rulings_path(doc["flavor"], args.tool_dir)
    rulings = load_rulings(path)
    for key, ruling, reason in todo:
        if key not in known:
            raise SystemExit("%s is not a flag in %s/candidates.json." % (key, args.bundle))
        set_ruling(rulings, key, ruling, reason)
    save_rulings(path, rulings)
    log("Recorded %d ruling(s) in %s" % (len(todo), path))
    return 0


def cmd_check(args) -> int:
    doc = load_doc(args.bundle)
    missing = unruled(doc, load_rulings(rulings_path(doc["flavor"], args.tool_dir)))
    if not missing:
        print("OK: every flag in %s is ruled." % args.bundle.name)
        return 0
    rows = {r["key"]: r for r in doc["flags"]}
    print("%d unruled:" % len(missing))
    for key in missing:
        row = rows[key]
        print("  %s  %s -> %s" % (key, row["shipped"], row["build"]))
    return 1


def cmd_report(args) -> int:
    doc = load_doc(args.bundle)
    write_repo_text(args.bundle / "RULINGS.md", format_rulings(doc, load_rulings(rulings_path(doc["flavor"], args.tool_dir)), args.date))
    log("Wrote %s" % (args.bundle / "RULINGS.md"))
    return 0


def cmd_apply(args) -> int:
    doc = load_doc(args.bundle)
    changed = plan_apply(doc, load_rulings(rulings_path(doc["flavor"], args.tool_dir)))
    log("%d change(s) to write (%s): every ruled edit here is a hand edit" % (len(changed), args.date))
    return 0


def parse_args(argv):
    parser = argparse.ArgumentParser(description="Re-validate Drop Watcher's enum literals and recipe skill lines against a wago.tools build.",
                                     epilog="The procedure is docs/validate-seeds.md.")
    parser.add_argument("--repo", type=Path, default=REPO, help=argparse.SUPPRESS)
    parser.add_argument("--tool-dir", type=Path, default=HERE, help=argparse.SUPPRESS)
    parser.add_argument("--cache-dir", type=Path, default=HERE / ".cache", help="the per-build download cache")
    sub = parser.add_subparsers(dest="command", required=True)
    status = sub.add_parser("status", help="is there a live build newer than the newest bundle?")
    status.add_argument("--flavor", choices=sorted(FLAVORS))
    status.add_argument("--root", type=Path, default=RESEARCH, help=argparse.SUPPRESS)
    derive = sub.add_parser("derive", help="flags into the bundle's candidates.json")
    derive.add_argument("--flavor", choices=sorted(FLAVORS), required=True)
    derive.add_argument("--bundle", type=Path, required=True)
    derive.add_argument("--date", type=_date, required=True)
    derive.add_argument("--build", help="pin this build instead of the live one")
    derive.add_argument("--replay", action="store_true", help="read only the bundle's raw/, no network")
    rule = sub.add_parser("rule", help="record rulings (the only writer of the rulings file)")
    rule.add_argument("--bundle", type=Path, required=True)
    rule.add_argument("--tsv", type=Path, help="key<TAB>ruling<TAB>reason lines")
    rule.add_argument("--key", action="append")
    rule.add_argument("--ruling")
    rule.add_argument("--reason")
    for name, text in (("check", "exit 1 while anything is unruled"), ("report", "write the bundle's RULINGS.md"),
                       ("apply", "the gate: refuse while anything is unruled or a hand edit is owed")):
        cmd = sub.add_parser(name, help=text)
        cmd.add_argument("--bundle", type=Path, required=True)
        if name != "check":
            cmd.add_argument("--date", type=_date, required=True)
    return parser.parse_args(argv)


def main(argv=None) -> int:
    args = parse_args(argv)
    return {"status": cmd_status, "derive": cmd_derive, "rule": cmd_rule, "check": cmd_check,
            "report": cmd_report, "apply": cmd_apply}[args.command](args)


if __name__ == "__main__":
    sys.exit(main())
