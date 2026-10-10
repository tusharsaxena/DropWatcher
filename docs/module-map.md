# Module map — Ka0s Drop Watcher

Every non-vendored file, its responsibility, and the TOC load order. `libs/` (Ace3, LibSharedMedia,
LibDataBroker, LibDBIcon, LibKa0s v1.71.0 whole) and `tests/_kit/` are vendored and never edited.

## Load order (the TOC)

| # | File | Kind | Responsibility |
|---|---|---|---|
| 1 | `locales/enUS.lua` | data | `NS.L`, the metatable fallback; the key is the English string |
| 2 | `core/Namespace.lua` | data | name, version, brand, the cyan `[DW]` tag, the slash and its alias |
| 3 | `core/CoreSetup.lua` | setup | LibKa0s-Core: the printer, the secret-safe stringifier, the SafeRegister family, the skin, the close-button wrapper, the resize grip |
| 4 | `core/MediaSetup.lua` | setup | LibKa0s-Media: `NS.Icon`, `NS.MediaFont`, the one RegisterLSM call |
| 5 | `core/Constants.lua` | data | `FONT_MONO`, the window geometry, the gold |
| 6 | `core/State.lua` | state | session-only state: debug flag, test mode, the player's window choice |
| 7 | `core/EnvSetup.lua` | setup | LibKa0s-Env: `NS.Meta`, `NS.Version` |
| 8 | `core/PoolSetup.lua` | setup | LibKa0s-Pool: `NS.Pool` (rows, from the feature items) |
| 9 | `core/ItemSetup.lua` | setup | LibKa0s-Item: `NS.Item` (item facts, from the feature items) |
| 10 | `core/Bus.lua` | setup | LibKa0s-Bus: `NS.MSG` (the strict catalog) and `NS.Bus` (tracked receivers) |
| 11 | `core/LifecycleSetup.lua` | setup | LibKa0s-Lifecycle: the stand-down latch, `NS.IsStoodDown` |
| 12 | `core/PerfSetup.lua` | setup | LibKa0s-Perf: `NS.Perf`, the declared buckets |
| 13 | `core/DebugLogSetup.lua` | setup | LibKa0s-DebugLog: the console, `NS.Debug` and its gates, the diagnostics descriptor |
| 14 | `core/DropWatcher.lua` | lifecycle | AceAddon registration, `NS.StandDown` / `NS.StandUp`, the shared host handlers, profile callbacks |
| 15 | `core/Database.lua` | data | the schemaVersion migration runner |
| 16 | `core/LauncherSetup.lua` | setup | LibKa0s-Launcher: the one LDB object, registered twice |
| 17 | `defaults/Profile.lua` | data | every default value (`NS.C`) |
| 18 | `modules/Window.lua` | UI | the main window's shell and its show decision |
| 19 | `modules/Diagnostics.lua` | sections | the addon's sections of `/dw diagnostics` |
| 20 | `settings/SchemaSetup.lua` | setup | LibKa0s-Schema, or the host's documented stub of it |
| 21 | `settings/Schema.lua` | settings | the rows, the write seam, the shared reactions, the defaults tree, the global reset |
| 22 | `settings/OptionsSetup.lua` | setup | LibKa0s-Options: the panel descriptor |
| 23 | `settings/Panel.lua` | settings | the landing page and the General page (Master controls) |
| 24 | `settings/Slash.lua` | setup | `NS.COMMANDS` and the LibKa0s-Slash descriptor |
| 25 | `settings/Profiles.lua` | settings | the Profiles page (AceDBOptions) |

Why each position is load-bearing or conventional is written beside its line in `DropWatcher.toc`
(toc-file-§5). The planned feature modules and the files they add are listed in design spec §4.

## Tests

| File | What it is |
|---|---|
| `tests/run.lua` | the load list, the three factories, the kit facts and the suite list |
| `tests/loader.lua` | the instance factory: TOC files plus `LibKa0s.xml`'s files, isolated per case |
| `tests/wow_mock.lua` | the thin extender over `tests/_kit/mock_base.lua` |
| `tests/test_*.lua` | one suite per subject (see [`testing.md`](testing.md)) |
| `tests/perf.lua` | the offline scenarios, outside the gate |
