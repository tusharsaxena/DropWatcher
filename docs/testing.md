# Testing — Ka0s Drop Watcher

## The green commit gate

Both MUST pass before every commit (testing-§4):

```sh
lua tests/run.lua      # the headless suite, Lua 5.1
luacheck .             # 0 warnings / 0 errors
```

No authored `.lua` file may pass 1500 lines (layout-§1); the kit's `test_layout_cap` reads the
census in [`ARCHITECTURE.md`](ARCHITECTURE.md). Toolchain: [`DEPENDENCIES.md`](../DEPENDENCIES.md).
The suite needs a sibling `../LibKa0s` checkout for the vendor gate's two payload cases (they SKIP
without it).

## The harness

`tests/run.lua` on the vendored LibKa0s kit (`tests/_kit/`, revision 38, never edited).
`tests/loader.lua` builds a fresh, isolated addon per case from the TOC's own file list and the
library files `libs/LibKa0s/LibKa0s.xml` names; `tests/wow_mock.lua` extends the kit's base mock with
what this addon reads (combat state, the client's addon list, the chat sink, the launcher's two
libraries, the main window's geometry, and the client APIs `core/Compat.lua` wraps: the tooltip
data, the chat sender and lockdown, the restriction state, `C_Item`'s upgrade, bind and GUID
answers, the trade actions, the enums it resolves by name and the enUS GlobalStrings it parses).
Suites that need a secret value use `T.secret(v)` and install the kit's `issecretvalue` on the
mock (`m.issecretvalue = function(v) return T.isSecret(v) end`).

Suites reach the harness as `local T = _G.DW_TEST` and build instances with the three factories,
each taking an `opts` table (`skip`, `mock`, `inCombat`) and returning `(NS, env, mock)`:

- `T.newAddon(opts)` — every file loaded.
- `T.bootAddon(opts)` — plus `OnInitialize` (the database, the migrations, the chat commands).
- `T.enableAddon(opts)` — plus `OnEnable` (events, settings category, launcher, the latch).

`opts.skip = T.loadAddon.libFiles` loads the addon with the whole LibKa0s payload absent, which is how
every degradation stub is tested: by a real load, never by a hand-written stub (testing-§8).

Named suites the standard requires: `test_surface_parity` (testing-§8), `test_vendor_sync`
(testing-§11, delegating to the kit), `test_disabled` (slash-commands-§7). The addon's own:
`test_harness` (the load and the repository's shape), `test_setup` (each adopted module's wiring),
`test_database`, `test_schema`, `test_slash`, `test_window`, `test_compat` (the compat seam: the
secret guards on both load paths, the localized duration decoder in three client languages, the
tooltip line reader and each shim's fallback with its API absent), `test_constants` and
`test_class_data`
(the game-data tables and their lookups), `test_evaluate` (the verdict kernel, table-driven over
every slot plan and every equippability path, plus nil and garbage inputs), `test_quality_gate`
(the minimum-quality gate: each mode, the floor, empty slots, ties, both overrides),
`test_situations` (the situation classifier's truth table for every key, the per-situation settings
and their spec defaults, the six re-evaluation events and the stand-down), `test_trade_rules` (the
trade estimator: every row of the Estimate table in order, the trade window, the rule per situation
and the owner's override map), `test_messaging` (the messaging core: token expansion, the length
limit, the one-ask guard, queueing under restriction, the flush order, cancel and a failed send's
retry), `test_restrictions` (the restriction tracker: each restriction type's reason and what it
blocks, the priority order, the chat lockdown, the combat edges ahead of the client's flag, the
event's numeric, boolean and secret payloads, `RestrictionChanged` and the stand-down), `test_roster` (the roster: solo, party and raid
tokens, the realm normalization, resolving by GUID, Name-Realm and bare name, the same-name tie
settled by classFile and by the player's realm, the re-read on a miss, the shared
`GROUP_ROSTER_UPDATE`, secret unit answers and the stand-down), `test_item_facts` (the item facts: every field of a
cached item, the track tier by string id and by name, the tooltip track, uniqueness, tier tokens and
class gear, the link-color quality, the facts feeding the verdict kernel, the cache and its cap, the
appearance event, the load with its retries, the give-up, a client that cannot load, and the
stand-down),
`test_diagnostics`. Kit suites,
declared by directory: `test_eol`, `test_prose`, `test_layout_cap`, `test_diagnostics_contract`,
`test_lizard_sighted`.

Write tests first for pure logic. Extend `tests/wow_mock.lua` for a new client API, never
`tests/_kit/`.

`lua tests/run.lua --list` prints the case inventory; it is committed as
[`test-cases.md`](test-cases.md), and its Total is the README's `[tests]` badge. Regenerate both in
the change that moves the count (testing-§5).

## The four suites, and which checkpoint each gates

| Suite | Command | Commit / run | Release (the tag) |
|---|---|---|---|
| `lint` | `luacheck .` | **gates** | gates |
| `tests` | `lua tests/run.lua` | **gates** | gates |
| `perf` | `lua tests/perf.lua` (offline scenarios; see [`performance.md`](performance.md)) | recorded, never fails a run or blocks a commit | gates |
| `complexity` | `bash tests/_kit/run-automated-tests.sh --suite complexity` (the sighted shadow) | recorded, never fails a run or blocks a commit | gates, with zero functions above CCN 15 and `blindFiles` 0 |

The release gate is evaluated by `/dev-copilot:bump-version` from the run's `manifest.json`
(automated-tests-§3). The record itself: [`automated-tests/README.md`](automated-tests/README.md).
For long batteries run through the bounded runner, `~/.claude/dev-copilot/bin/ka0s-bounded`.

## In game

[`smoke-tests.md`](smoke-tests.md) — the checks the headless suite cannot make. They are the owner's
to run; an agent never marks one passed.
