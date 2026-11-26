# Dependencies — Ka0s Drop Watcher

What you need installed to build, run, test or release this addon. Commands are for
**WSL2 / Ubuntu** (the collection's development environment). How to *verify* the addon once
you are set up is `docs/testing.md`; this file only covers *what to install*.

Every entry says what needs it and how that is known. Anything only plausibly required is
marked as such rather than listed as a requirement.

## Runtime (in-game) — what a player needs

- **World of Warcraft: Retail or WoW Forever.** One unsuffixed `DropWatcher.toc` carries both
  numbers, `## Interface: 120105, 16001` (Retail 12.1.5, WoW Forever 1.60.1), and no load-gating
  line (toc-file-§3, the roster's `Retail · Forever`). What one client lacks is gated per feature,
  in `docs/ARCHITECTURE.md`'s per-client feature table (clients-§4).
- **Nothing else.** Every library is vendored under `libs/` and committed (library-stack), so the
  player installs no separate library addon. `## OptionalDeps:` names the vendored libs for load
  ordering, not as things to download. `libs/LibCustomGlow-1.0/` (MIT, minor 24, copied whole from
  the KickCD sibling's vendored copy) draws the upgrade glow on item icons; its caller is
  LibKa0s-Glow-1.0 (the bundled LibKa0s payload, through `core/GlowSetup.lua`), which resolves it at
  every call.
  Ace3: WoWUIDev/Ace3@ac3d1225 (untagged master; LibKa0s#76).
- **Optional: Pawn (both clients) and CanIMogIt (Retail only).** Named in `## OptionalDeps:` so they
  load first when installed, and reached only through `core/Compat.lua` (their API is called under
  `pcall`, never copied).
  **Pawn**, once it has initialized (its `PawnIsReady()`), drives the `pawn` scorer
  (`modules/Scoring.lua`, design spec §5.4): `comparison.scorer` `auto` picks it then, and until
  then uses your weights. A nil answer from a ready Pawn reads `pending`, which the feed retries. Its scale strings can also be imported into your own weights.
  On WoW Forever (Pawn 2.14.1 there) Pawn has no specs and one Classic scale per talent tree, so you
  are scored with the scale of your top talent tree, and another player with the best of their
  class's scales (`modules/Scoring.lua`, Forever port design §4.3). **CanIMogIt** serves transmog, which
  WoW Forever lacks, so it is read on Retail alone (design §4.4); when loaded, it answers the transmog-known flag (design spec §4) before `C_TransmogCollection` does.
  Without Pawn, the comparison uses your own weights when any are set, else item level alone;
  without CanIMogIt, the transmog flag comes from the client API. Whether each is loaded is
  reported by `core/DropWatcher.lua` `logDependencies` and the diagnostics' `integrations` and
  Scoring sections (`modules/Diagnostics.lua`), the latter naming the scorer actually in use.
- **Optional: ForeverDB (WoW Forever only).** The WoW Forever data addon
  (<https://github.com/foreverfraddons/forever-db>, CurseForge `forever-db`). Named in
  `## OptionalDeps:` and under `.pkgmeta`'s `optional-dependencies`, never as a required dependency
  (clients-§11): no player needs it. It is read only through LibKa0s-ForeverDB-1.0
  (`core/ForeverDBSetup.lua`), whose first lookup loads it (LoadOnDemand, some 12 MB); this addon
  makes that lookup once a session for Item Search (`modules/ItemSearch.lua`, DropWatcher#17), about
  5 seconds after login and out of combat, and never while Item Search's tooltip block and window
  are both switched off. With it, every item tooltip and the Item Search window say which creatures,
  objects or containers drop an item, with their chances, who sells it, its quests and its name
  search. Without it, the tooltip shows nothing of Item Search, and the window searches by id and
  shows the recipes from the shipped table alone; on Retail there is no Item Search. Its data is GPL-3.0 and is
  never copied into this repo, tests included (the kit's `tests/_kit/mock_foreverdb.lua` is invented).
- **Optional: Auctionator (read on WoW Forever, where Item Search runs).** Named in `## OptionalDeps:`
  so it loads first when installed, and reached only through `core/CompatSearch.lua`
  (`Compat.AuctionatorLoaded`, `Compat.AuctionPrice`): its public API v1,
  `Auctionator.API.v1.GetAuctionPriceByItemLink` then `GetAuctionPriceByItemID`, asked as
  `"DropWatcher"` under `pcall` (its code is never copied). With it, the Item Search badge's Sell
  says Auction or Vendor (`modules/ItemSearchAuction.lua`, R5-DW-13..16); without it, every Sell says
  Vendor and the Auction prices rows are dimmed.
- **Optional: EllesmereUI.** Named in `## OptionalDeps:` so it loads first when installed (skinning-§5).
  When it can skin this addon, Settings → General → Skin offers it as the skin source, through
  LibKa0s-Skin-1.0's own EllesmereUI provider; this addon calls no EllesmereUI API. Without it the
  Ka0s skins are the only source.

## Development — the contributor toolchain

| Tool | Version | Needed for | Evidence |
|---|---|---|---|
| `lua5.1` (+ `luac`) | **5.1 exactly** | the headless suite, `lua tests/run.lua`, and the offline scenarios, `lua tests/perf.lua` | `tests/_kit/loader.lua` uses `setfenv` |
| `luacheck` | any recent | `~/.claude/dev-copilot/bin/ka0s-bounded luacheck .`, the other half of the green gate | `.luacheckrc` at the repo root |
| `~/.claude/dev-copilot/bin/ka0s-bounded` | the dev-copilot plugin's | bounds a run that loads no kit, `luacheck` above (testing-§15) | installed with the dev-copilot Claude Code plugin |
| `lizard` | any recent | the `complexity` suite of `tests/_kit/run-automated-tests.sh`, which runs it over a sanitized shadow and checks function-count parity, because `lizard` alone is blind in Lua (automated-tests-§3); also the headless suite's one end-to-end lizard case, which SKIPs when lizard is not on PATH | `tests/_kit/run-automated-tests.sh`, `tests/_kit/test_lizard_sighted.lua`, the case "lizard sighted: lizard lists every function of a hazard fixture once it is sanitized" |
| `git` | any recent | vendoring, the vendored-payload gate (`tests/test_vendor_sync.lua` reads the index and compares against the sibling `../LibKa0s` checkout) and the line-ending gate (`git check-attr`) | `tests/_kit/vendor_sync.lua`, `tests/_kit/test_eol.lua` |
| POSIX shell (`bash`) | any | `tests/_kit/run-automated-tests.sh` and the commands in this file | the runner's shebang |
| `python3` | **3.8+**, standard library only | the seed-validation tool `tools/seeds/seeds.py` and its cases (`docs/validate-seeds.md`); not needed to build, run or test the addon itself | `tools/seeds/seeds.py`'s imports; `pytest` is optional (`python3 -m unittest discover -s tools/seeds` runs the same cases) |
| network access to `wago.tools` | - | a new seed-validation run (`seeds.py status`, and `derive` without `--replay`), which reads `https://wago.tools/api/builds` and the build's DB2 tables as CSV; a `--replay` and the tests run offline | `seeds.py`'s `BUILDS_URL` and `CSV_URL` |

**Lua 5.1 is a requirement, not a preference.** The harness sandboxes each source file with
`setfenv`, which was removed in 5.2 — "5.2 will probably work" is false and costs an hour to
disprove.

```sh
# Lua 5.1 and luacheck
sudo apt-get update
sudo apt-get install -y lua5.1 luarocks
sudo luarocks install luacheck

# lizard — via pipx, NOT pip. Ubuntu 24.04 marks its Python EXTERNALLY-MANAGED (PEP 668),
# so `pip install lizard` fails; pipx installs it into its own venv and puts it on PATH.
sudo apt-get install -y pipx
pipx ensurepath          # then open a new shell, or: source ~/.bashrc
pipx install lizard

# verify — each of these must print a version
lua5.1 -v                # Lua 5.1.5 …   (if `lua` is not 5.1, use lua5.1 explicitly)
luacheck --version
lizard --version
git --version
```

Versions are pinned only where a version matters: `lua5.1` is hard, `luacheck` and `lizard` are
"any recent" and pinning them would be false precision.

## Release / assets

**One entry: Python 3 with Pillow**, and only for **regenerating** the logo TGAs —
`media/logos/dropwatcher.logo.128.tga` and `media/logos/dropwatcher.logo.tga` are committed, so
nothing is generated at package time. The recipe is layout-§4's, run by hand from the committed
2000×2000 source when the art changes:

```sh
sudo apt-get install -y python3-pil
python3 -c 'from PIL import Image; Image.open("media/logos/dropwatcher.logo.png").convert("RGBA").resize((128, 128), Image.LANCZOS).save("media/logos/dropwatcher.logo.128.tga", format="TGA")'
python3 -c 'from PIL import Image; Image.open("media/logos/dropwatcher.logo.png").convert("RGBA").resize((300, 300), Image.LANCZOS).save("media/logos/dropwatcher.logo.tga", format="TGA")'

# verify
python3 -c 'import PIL; print(PIL.__version__)'
```

**None of this group is required to build, run or test the addon.**

## Am I set up correctly?

```sh
lua tests/run.lua                                     # the suite — must be green
KA0S_KIT_CLIENT=forever lua tests/run.lua             # the same suite as WoW Forever — must be green too
lua tests/run.lua -j auto                             # same, fanned across CPUs (testing-§14)
# every run above is bounded by the vendored kit on load (testing-§15); KA0S_KIT_GUARD=off only under a debugger
~/.claude/dev-copilot/bin/ka0s-bounded luacheck .     # must be 0 warnings / 0 errors
bash tests/_kit/run-automated-tests.sh --suite complexity   # the sighted complexity report (release-time);
                                                      # never raw `lizard`, which is blind in Lua (automated-tests-§3)
```

See `docs/testing.md` for what those commands mean and when each is run.
