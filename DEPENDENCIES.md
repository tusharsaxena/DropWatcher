# Dependencies — Ka0s Drop Watcher

What you need installed to build, run, test or release this addon. Commands are for
**WSL2 / Ubuntu** (the collection's development environment). How to *verify* the addon once
you are set up is `docs/testing.md`; this file only covers *what to install*.

Every entry says what needs it and how that is known. Anything only plausibly required is
marked as such rather than listed as a requirement.

## Runtime (in-game) — what a player needs

- **World of Warcraft (Retail).** Single `## Interface: 120105` line in `DropWatcher.toc` — Retail
  only.
- **Nothing else.** Every library is vendored under `libs/` and committed (library-stack), so the
  player installs no separate library addon. `## OptionalDeps:` names the vendored libs for load
  ordering, not as things to download. `libs/LibCustomGlow-1.0/` (MIT, minor 24, copied whole from
  the KickCD sibling's vendored copy) draws the upgrade glow on item icons.
- **Optional: Pawn and CanIMogIt.** Named in `## OptionalDeps:` so they load first when installed,
  and reached only through `core/Compat.lua` (their API is called under `pcall`, never copied).
  **Pawn**, once it has initialized (its `PawnIsReady()`), drives the `pawn` scorer
  (`modules/Scoring.lua`, design spec §5.4): `comparison.scorer` `auto` picks it then, and until
  then uses your weights. A nil answer from a ready Pawn reads `pending`, which the feed retries. Its scale strings can also be imported into your own weights. **CanIMogIt**,
  when loaded, answers the transmog-known flag (design spec §4) before `C_TransmogCollection` does.
  Without Pawn, the comparison uses your own weights when any are set, else item level alone;
  without CanIMogIt, the transmog flag comes from the client API. Whether each is loaded is
  reported by `core/DropWatcher.lua` `logDependencies` and the diagnostics' `integrations` and
  Scoring sections (`modules/Diagnostics.lua`), the latter naming the scorer actually in use.

## Development — the contributor toolchain

| Tool | Version | Needed for | Evidence |
|---|---|---|---|
| `lua5.1` (+ `luac`) | **5.1 exactly** | the headless suite, `lua tests/run.lua`, and the offline scenarios, `lua tests/perf.lua` | `tests/_kit/loader.lua` uses `setfenv` |
| `luacheck` | any recent | `luacheck .`, the other half of the green gate | `.luacheckrc` at the repo root |
| `lizard` | any recent | the `complexity` suite of `tests/_kit/run-automated-tests.sh`, which runs it over a sanitized shadow and checks function-count parity, because `lizard` alone is blind in Lua (automated-tests-§3); also the headless suite's one end-to-end lizard case, which SKIPs when lizard is not on PATH | `tests/_kit/run-automated-tests.sh`, `tests/_kit/test_lizard_sighted.lua:187` |
| `git` | any recent | vendoring, the vendored-payload gate (`tests/test_vendor_sync.lua` reads the index and compares against the sibling `../LibKa0s` checkout) and the line-ending gate (`git check-attr`) | `tests/_kit/vendor_sync.lua`, `tests/_kit/test_eol.lua` |
| POSIX shell (`bash`) | any | `tests/_kit/run-automated-tests.sh` and the commands in this file | the runner's shebang |

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
lua tests/run.lua -j auto                             # same, fanned across CPUs (testing-§14)
# every run above is bounded by the vendored kit on load (testing-§15); KA0S_KIT_GUARD=off only under a debugger
luacheck .                                            # must be 0 warnings / 0 errors
bash tests/_kit/run-automated-tests.sh --suite complexity   # the sighted complexity report (release-time);
                                                      # never raw `lizard`, which is blind in Lua (automated-tests-§3)
```

See `docs/testing.md` for what those commands mean and when each is run.
