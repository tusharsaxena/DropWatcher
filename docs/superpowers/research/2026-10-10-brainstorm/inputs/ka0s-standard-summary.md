# What "a Ka0s addon with all bells and whistles" means, for a group loot tracker

**In short:** a new Ka0s addon is an Ace3 addon with a fixed modular layout. It consumes nearly every shared subsystem from the vendored LibKa0s library instead of writing its own: the debug console, slash dispatcher, options panel, launcher, perf harness, lifecycle latch, skin, close button and icons. It ships one fixed set of docs, and its tests are a headless Lua 5.1 suite. As of 2026-10-10:

- **Standard:** v2.78.2 (2026-10-10).
- **LibKa0s:** latest tag v1.71.0 (2026-10-07), with testkit revision 38. Every roster addon vendors v1.71.0.
- **Roster:** 12 addons.
- **Interface:** `120100` in every roster TOC.

`/dev-copilot:wow-new-addon` scaffolds all of this, and you finish by adding a row to `ADDONS.md`.

**Where things live.** Paths are written short below:

| Short form | Full path |
|---|---|
| `S/` | `/mnt/d/Profile/Users/Tushar/Documents/GIT/WowAddonStandards/standards/standards/` (the section files) |
| `WAS/` | `/mnt/d/Profile/Users/Tushar/Documents/GIT/WowAddonStandards/` |
| `LK/` | `/mnt/d/Profile/Users/Tushar/Documents/GIT/LibKa0s/LibKa0s/` (the shipped payload) |
| `LKD/` | `/mnt/d/Profile/Users/Tushar/Documents/GIT/LibKa0s/docs/api/<Major>/` (the latest `version-*-docs.md` per module) |

**Key references:**
- Index: `WAS/standards/STANDARDS.md`
- One-page summary: `WAS/standards/EXECUTIVE_SUMMARY.md`
- Playbook: `WAS/NEW_ADDON.md`
- Context pack, to fetch and read but never copy into the addon: `WAS/standards/NEW_ADDON_CONTEXT.md`. Its starter tree is at :101, the TOC snippet at :178, the hard rules at :1503 and the Definition of Done at :1607.

---

## 1. Mandatory structure

### Identity (`WAS/NEW_ADDON.md` "Identity")
- **Folder:** PascalCase, for example `GroupLoot`.
- **TOC Title:** `Ka0s <Human Name>`.
- **Author:** `add1kted2ka0s`.
- **License:** MIT, always.
- **Substrate:** Ace3, Retail only.
- **Slash:** 2–3 lowercase characters, plus the full lowercase name as an alias.
- **SavedVariables:** `<Addon>DB` and `<Addon>PerfDB`, and no others (savedvariables-§4).

### Folder layout and load order (`S/layout.md`, layout-§1)
- **Folders:** `core/ defaults/ settings/ locales/ modules/ media/ libs/ tests/ docs/`. There is no flat variant, and nothing loose at the root.
- **Load order:** `libs → locales → core → defaults → modules → settings`. The TOC's `#` section headers repeat that order (toc-file-§5).
- **Inside `core/`:** dependency-correct order, with no numeric prefixes. Each load-bearing line is annotated in the TOC.
- **Starter `core/` files** (context pack :101-175):
  - `Namespace.lua`, `Compat.lua` (only if needed), `MediaSetup.lua`, `Constants.lua`, `State.lua`
  - Setup files: `EnvSetup`, `CoreSetup`, `PoolSetup`, `ItemSetup`, `PerfSetup`, `DebugLogSetup`, `LauncherSetup`, `LifecycleSetup`, and `Bus.lua` once there are 2 or more feature modules
  - `<Addon>.lua` (AceAddon registration) and `Database.lua` (AceDB plus the migration runner)
- **Settings files:** `settings/Schema.lua`, `Slash.lua`, `OptionsSetup.lua`, one file per `<Page>.lua`, and `Profiles.lua`.
- **Diagnostics:** `modules/Diagnostics.lua` is required (debug-logging-§14).
- **Every authored file** opens with `local addonName, NS = ...`, then a header comment naming its own path (architecture-§1, documentation-§9).
- **Casing:** subfolders lowercase; Lua files PascalCase.lua (layout-§2).
- **Media:** typed subfolders (layout-§3). Two logo files are required (layout-§4):
  - `media/logos/<addon>.logo.128.tga`: 128×128, uncompressed 32-bit, made with Pillow LANCZOS.
  - `media/logos/<addon>.logo.tga`: shown at 300 on the landing page.
  - The 2000×2000 `.png` source is committed but `.pkgmeta`-ignored.
- **File cap:** 1500 lines on every authored `.lua`, `tests/` included; 1000–1500 lines is "on notice".
  - Required census heading `Files over the 1500-line cap` in ARCHITECTURE.md, under `## Documented deviations`, reading "Nothing is over the cap today".
  - Kit gate: `tests/_kit/test_layout_cap.lua`.

### TOC (`S/toc-file.md`, toc-file-§1–§5; context pack :185-200)
- **Field order is exact:** Interface, Title, Notes, Author, Version, IconTexture, SavedVariables, OptionalDeps, DefaultState, Category-enUS, X-License, X-Standard, X-Curse-Project-ID, then optionally X-Wago-ID / X-WoWI-ID.
- **Interface:** a single latest-Retail value, today `120100`. No multi-flavor TOCs and no `WOW_PROJECT_ID` (toc-file-§3).
- **IconTexture:** `Interface\AddOns\<Folder>\media\logos\<addon>.logo.128.tga`. Never a Blizzard icon or a file id (anti-pattern #82).
- **X-Standard:** `https://github.com/tusharsaxena/WowAddonStandards`.
- **X-Curse-Project-ID while unpublished:** omit the field and leave `# X-Curse-Project-ID: not published on CurseForge yet` in its place. Never a placeholder id.
- **OptionalDeps:** `Ace3, LibStub, CallbackHandler-1.0, LibSharedMedia-3.0` (roster addons add LibDataBroker-1.1 and LibDBIcon-1.0). No hard `Dependencies`; Pawn and similar addons must be optional and presence-guarded (anti-patterns #13/#29).
- **Libraries block:** lists the vendored libs directly, with no addon `embeds.xml` (#38). LibKa0s is one line, `libs\LibKa0s\LibKa0s.xml`, after Ace3.
- **Worked examples:**
  - `/mnt/d/Profile/Users/Tushar/Documents/GIT/AuraMaster/AuraMaster.toc`
  - `/mnt/d/Profile/Users/Tushar/Documents/GIT/WhatGroup/WhatGroup.toc`

### Libraries (`S/library-stack.md`)
- **Always:** LibStub, CallbackHandler-1.0, AceAddon-3.0, AceDB-3.0, LibDataBroker-1.1, LibDBIcon-1.0.
- **When reached:** AceEvent, AceTimer, AceConsole and AceGUI. AceGUI is effectively always needed, because the Options library reaches it.
- **Optional:** LibSharedMedia-3.0, plus AceDBOptions and AceConfig for the Profiles sub-page only (library-stack-§1/§2).
- **Vendoring:** everything is committed under `libs/`, with no externals. Vendor only what is reached (library-stack-§3).
- **LibKa0s** is vendored whole and byte-identical from the LibKa0s repo's `LibKa0s/` folder into `libs/LibKa0s/`. Copying only part of it is anti-pattern #48 (library-stack-§7).
- **Testkit:** `testkit/` goes into `tests/_kit/`, never into `libs/`.
- **Comms libraries:** no Ka0s addon vendors AceComm, AceSerializer or ChatThrottleLib today.

### Docs (`S/documentation.md`)
- **Root:** exactly `README.md`, `CLAUDE.md` (a stub), `DEPENDENCIES.md` and `LICENSE`. A `CHANGELOG.md` is forbidden in an addon (documentation-§1).
- **README** (player-facing; bullets only, no numbered lists, no logo, no library list):
  - Section order: title, then 5 badges, then description, then the sections below.
  - The badges are WoW, CF (after publishing), `License-MIT-orange`, `Ka0s-WoW_Addon_Standard-yellow` (never wrapped in a link) and `Tests-X%2FY_passing-green`.
  - Sections: Screenshots, Usage (prose, no tables), How it works, FAQ, Troubleshooting, Reporting a bug (verbatim text at documentation.md:82-90), Issues and feature requests, Version History, optional Credits.
- **CLAUDE.md stub** (documentation-§2):
  - Identity line.
  - `## Standards compliance (read first)`, in the canonical wording at documentation.md:548-571.
  - Docs pointers.
  - Green-gate line.
  - The provenance line `Bundles [LibKa0s](https://github.com/tusharsaxena/LibKa0s) vX.Y.Z (MIT).`, which `tests/_kit/vendor_sync.lua` reads.
  - Verbatim exemplar: `/mnt/d/Profile/Users/Tushar/Documents/GIT/WhatGroup/CLAUDE.md`.
- **DEPENDENCIES.md** (documentation-§7): runtime / development / release, each with WSL2/Ubuntu install commands and a verify command. Lua 5.1 is required; install lizard with pipx.
- **`docs/` trio:** `ARCHITECTURE.md`, `testing.md`, `smoke-tests.md`.
  - ARCHITECTURE.md has ten sections: Overview, Module Map, Settings Schema, Message Bus, Slash Commands, Event Subscriptions, Taint Notes, Known Limitations, `## Documentation map`, `## Documented deviations`.
- **Tier 1, always required:** `scope.md`, `module-map.md`, `schema.md`, `settings-panel.md`, `data-flow.md`, `common-tasks.md`.
- **Tier 2, when triggered:**
  - `debug.md` (always, because of diagnostics)
  - `slash-dispatch.md` (8 or more commands)
  - `midnight-quirks.md`
  - `compat-layer.md` (3 or more shims)
  - `message-bus.md` (more than 10 messages)
  - `profiles.md`
  - `perf-analysis/README.md` (when perf is wired)
- **Verification and record:** `test-cases.md` (generated), `performance.md`, `automated-tests/README.md`, `automated-tests/RESULTS.md`.
- **Frozen dated bundle stores:** `docs/audits/`, `docs/reviews/`, `docs/revendor/`, `docs/automated-tests/`, `docs/perf-analysis/`.
- **Backlog:** no TODO.md once released; GitHub issues are the backlog.

### Tests, lint, complexity, packaging, line endings
- **Commit gate:** `lua tests/run.lua` green and `luacheck .` at 0/0 (testing-§4).
- **`tests/run.lua`:**
  - dofiles `_kit/framework.lua` and `loader.lua`
  - loads the LibKa0s files in XML order, then the addon files via `Loader.tocFiles`
  - publishes `Kit.expose` as `<ADDON>_TEST`
  - calls `Kit.run{...}`
- **Mock:** `tests/wow_mock.lua` extends `_kit/mock_base.lua`.
- **Named suites, required from day one:**
  - `test_surface_parity.lua` (testing-§8)
  - `test_vendor_sync.lua`, which delegates to the kit (testing-§11)
  - `test_disabled.lua` (slash-commands-§7)
  - the kit suites `test_eol`, `test_prose`, `test_layout_cap`, `test_diagnostics_contract` and `test_lizard_sighted`
- **Offline perf runner:** `tests/perf.lua`, outside the gate.
- **Release gate** (`S/automated-tests.md` §3):
  - Run with `bash tests/_kit/run-automated-tests.sh` (mode 100755 via `git update-index --chmod=+x`).
  - It writes `docs/automated-tests/<YYYYMMDD-HHMMSS>/` and updates `RESULTS.md`.
  - Lint and tests gate the run; perf and complexity only record.
  - A tag needs all four suites passing, zero functions above CCN 15 and `blindFiles` 0. Never run raw `lizard`.
- **`.luacheckrc`** (`S/lint.md`):
  - `std="lua51"`, `max_line_length=false`, `codes=true`.
  - Excludes `libs/`, `tests/_kit/`, `docs/audits/`, `docs/reviews/`, `docs/revendor/` and `_dev/`.
  - `ignore={"212/self","212/event"}`.
  - `globals={"<Addon>DB","<Addon>PerfDB"}`.
  - `files["tests/"]={globals={"<ADDON>_TEST"}}`.
  - Add `debugprofilestop` to `read_globals`.
- **`.pkgmeta`** (`S/packaging.md`):
  - `package-as: <Addon>`, no externals.
  - Ignores the dotfiles, `docs`, `tests`, `_dev`, `*.bak`, `media/logos/*.png|jpg`, and `.claude` / `.superpowers` / `tools` only if they exist.
- **`.gitattributes`:** the first file in the repo (`S/line-endings.md` §2-§5).
  - `* text=auto eol=crlf`, `*.sh text eol=lf`, `*.py text eol=lf`, and the full binary list.
  - Copied verbatim from the context pack.
- **Versioning** (`S/versioning-git.md`): semver; the TOC, badges and README Version History move together.

---

## 2. Mandatory runtime features and the LibKa0s surface for each

**The setup-file pattern.** Each module the addon adopts gets one `core/<X>Setup.lua`. It does `LibStub("LibKa0s-<X>-1.0", true)`, builds `:New(descriptor)`, and installs a degradation stub if the library is absent. The stub must answer every member the addon calls, and `test_surface_parity` pins that. Hand-rolling any of these subsystems is anti-pattern #47.

| Feature | Rule | LibKa0s surface (major, minor) |
|---|---|---|
| Printer / secret-safe output | slash-commands-§4, events-frames-taint-§8 | `LibKa0s-Core-1.0` (10): `lib:New{prefix=fn}.Print`, `SafeToString`, `IsConcatSafe`. Prefix is `NS.PREFIX="\|cff00ffff[XY]\|r"`, cyan. Reclaim `NS.Print` after `NewAddon` (AceConsole clobbers it, anti-pattern #36). Never a bare `print()`. |
| Event registration | events-frames-taint-§1 | Core `SafeRegisterEvent` / `SafeRegisterUnitEvent` / `SafeRegisterEvents`. The host keeps a `rejected` list that the `debug` verb shows (LootHistory: `NS.RejectedEvents`, `/lh debug events`). |
| Version / TOC metadata / zone | — | `LibKa0s-Env-1.0` (2): `Version`, `GetAddOnMetadata`, `GetZone`, `GetPlayerMapID` |
| Media / icons / font | library-stack-§8 | `LibKa0s-Media-1.0` (4): `NS.Icon(name)=Media.Icon(addonName,name)`, `NS.MediaFont("JetBrains Mono")`, `Media.RegisterLSM(addonName)`. 113-icon catalog. A missing icon is added upstream, never drawn locally. |
| Enable/disable latch | slash-commands-§7 | `LibKa0s-Lifecycle-1.0` (3): `HOLD_DISABLED` and `HOLD_PERF` are two holds on one latch. Disabled means: unregister every event, message and bucket; cancel every timer; hide every frame; no SavedVariables writes. Tested by `tests/test_disabled.lua`. |
| Message bus | architecture-§4; MUST with 2+ feature modules | `LibKa0s-Bus-1.0` (2): `bus:NewTarget()`, `StandDown/StandUp`, optional `Catalog`. Names are `NS.MSG.X="Ka0s_<Addon>_<Event>"`, declared once, one sender each. |
| Settings schema | architecture-§5 | `LibKa0s-Schema-1.0` (2), optional adoption: `Get` / `Set` (the single write seam) / `ApplyDefault` / `Bulk*`. A loot log is "recorded data" and is written outside the schema by a named owner module. |
| Pooled rows | events-frames-taint-§6 | `LibKa0s-Pool-1.0` (3): `Acquire` / `ReleaseAll`, plus a keyed variant |
| Items | — | `LibKa0s-Item-1.0` (2): `ItemIDFromLink`, `QualityFromLink`, `QualityLabel`, `LoadItem(id,cb)`. The callback means "retry", not "data arrived"; uncached-item policy stays with the host. |
| Debug console | debug-logging-§1-§14 | `LibKa0s-DebugLog-1.0` (19.2.1). Detailed below. |
| Diagnostics | debug-logging-§14 | DebugLog `RunDiagnostics` via `NS.DebugLog:DebugVerb(rest)`. Detailed below. |
| Slash commands | slash-commands-§1-§8 | `LibKa0s-Slash-1.0` (20.2). Detailed below. |
| Settings UI | options-ui | `LibKa0s-Options-1.0` (28.x). Detailed below. |
| Launcher | launcher-§1-§4 | `LibKa0s-Launcher-1.0` (5). Detailed below. |
| Perf | performance | `LibKa0s-Perf-1.0` (14.x). Detailed below. |
| Profiles | options-ui-§3 | AceDBOptions + AceConfigDialog Profiles sub-page; `profilesPage=true` in the Options descriptor; the Slash `profile` verb (`CliProfile` / `ProfileSwitch`). Reset all = `db:ResetProfile()` with the verbatim confirm text (options-ui-§12). |
| Localization | `S/localization.md` | `NS.L` with a key-returning metatable. English-string keys; AceLocale strict mode is forbidden; non-enUS files are gated by `GetLocale()`. US English everywhere (kit `test_prose`). |
| Compat | `S/compat.md` | `core/Compat.lua` is the only caller of any deprecated or version-variant API, and is created only if needed. It may route through `LibKa0s-Compat-1.0` (1): `IsSecret`, `CanAccess`, `IsSafeKey`, spell and spec readers. Compat has **no item, loot, inspect or chat members.** |
| Census | — | Not a runtime feature. `LibKa0s/docs/api/CONSUMERS.md` is the library's export-usage census (422 exports; v1.71.0, 2026-10-07). |

### Debug console (`LibKa0s-DebugLog-1.0`)
- **Descriptor:** `name`, `title`, `font`, `addonName`, `isEnabled` / `setEnabled`, `brandName`, `diagnostics`.
- **Sink:** `NS.Debug(tag, fmt, ...)`, gated.
- **Gates:** `NS.DebugOnce`, `DebugChanged`, `DebugAtEnable`.
- **Window:** 700×344, with a 3000-line buffer.
- **What to log** (diagnosis checklist, debug-logging-§8): state edges, deferred work, refusals naming the guard, and caught errors once. One summary line per pass; no per-tick spam (#91).

### Diagnostics
- **Two forms only:** `/<slash> diagnostics` and `/<slash> debug diagnostics`. No aliases.
- **Sections:** the addon's own sections come from `modules/Diagnostics.lua`.
- **Documentation:** `docs/debug.md`.

### Slash commands (`LibKa0s-Slash-1.0`)
- **Setup:** an ordered `NS.COMMANDS` of `{name, desc, handler}`, plus the descriptor (`slash`, `slashAliases`, `get` / `set` / `findRow` / `allRows` / `applyDefault`, `isEnabled`, `brandName`, `debug`). AceConsole `RegisterChatCommand` for the short and long names, both calling `Sl:OnSlash`.
- **Reserved verbs:** `help get set list reset resetall config version debug enable disable perf diagnostics`. `lock` / `unlock` are added if the addon has a lock.
- **Live verbs:** `LIVE_VERBS` (`LK/Slash.lua:123`) keep answering while the addon is disabled.
- **Behavior:** bare `/<slash>` opens the panel; an unknown verb prints the help.
- **Window verbs:** standalone windows SHOULD get `show` / `hide` / `toggle` (LootHistory does).

### Settings UI (`LibKa0s-Options-1.0`)
- **Descriptor** in `settings/OptionsSetup.lua`: `parentTitle`, `mainPanelName`, `addonName`, `get` / `set` / `applyDefault`, `rowsForPage`, `allRows`, `skipRestoreAll`, `resetProfile`, `profilesPage`, `buildMain`, `debug`.
- **Registration:** `CreateOptionsPanel` eagerly at PLAYER_LOGIN; the body is built lazily. Opening is refused in combat, and a shown page is covered by a combat lock (options-ui-§2).
- **Landing page:** `buildMain=function(ctx) NS.Helpers.BuildLandingPage(ctx, NS.LANDING) end`.
  - It holds the logo (300), the TOC Notes, and a "Slash Commands" heading over `NS.Slash:LandingRows()`.
  - No tab strip. Never hand-draw a logo (#93). There is no separate About page; the landing page is that page.
- **General page:** its first tab is exactly `Master controls`, built by `H.MasterControls{...}`, in this order:
  - Enable | General visibility
  - Scale | Alpha
  - Lock frame | Debug console
  - Minimap button | Test mode
  - Reset position | Reset all settings
- **Tabs:** every page uses `RenderTabbedSchema`, one tab per row `group`, including single-section pages.
- **Nav rail:** `NavRail(ctx,{entries,value,onSelect})`, only for a page that edits one instance among many (options-ui-§13). It is two levels at most. Example: `/mnt/d/Profile/Users/Tushar/Documents/GIT/AuraMaster/settings/Containers.lua:239,601`.
- **Composers:** `ColorPair`, `FontGroup`, `BorderGroup`, `BarGroup`. Every color row has a class-color companion (options-ui-§17). Reorderable lists use Widgets `ReorderList` (options-ui-§18).
- **Id lists:** `IdInput` / `IdList` handle spell, item and currency lists, which would suit an item watch list.

### Launcher (`LibKa0s-Launcher-1.0`)
- **One LDB object** registered for both the minimap button and broker displays.
- **Descriptor:** `name`, `icon` (the 128 logo), `label="Ka0s <Name>"`, `minimap=db.global.minimap`, `openSettings`, `isEnabled` / `setEnabled`, and where the addon has them `isLocked` / `toggleLock`, `isTestMode` / `toggleTestMode`, `isWindowShown` / `toggleWindow`. Also `version`, `debug`, `debugAtEnable`.
- **Clicks:** left-click opens settings; right-click opens the menu (Enabled · Locked · Test mode · Show window).
- **Tooltip:** drawn by the library. Never set `OnTooltipShow` yourself (#89).
- **Minimap button row:** reads schema path `global.minimap.shown`, stored inverted at LibDBIcon's own `minimap.hide`, and vetoed out of both resets.
- **Addon compartment:** not provided by LibKa0s and not required by the standard.
- **Examples:** `/mnt/d/Profile/Users/Tushar/Documents/GIT/WhatGroup/core/LauncherSetup.lua` and LootHistory's (both have a window toggle).

### Perf (`LibKa0s-Perf-1.0`)
- **Descriptor:** `sv="<Addon>PerfDB"`, `lifecycle`, declared `buckets{key,within}`.
- **Brackets:**
  - Shape A on hot paths: `local t0=Perf.on and debugprofilestop() ... Perf.Note(key, ...)`.
  - Shape B, `Open` / `Close`, for multi-exit regions.
- **Verb:** `perf start | measure a | measure b | finish | report | cancel`, with a step panel.
- **Exemption:** only if the addon runs no code in combat (performance-§12). A loot tracker listening to `CHAT_MSG_LOOT` in combat does not qualify.

### Preview / test mode (`S/preview-mode.md`)
- A positionable window shows placeholder data in test mode.
- It is a session-only checkbox, ended by combat.
- The launcher's Test mode entry calls the same handler.

---

## 3. The Ka0s look

### Window skin (`LK/Core.lua:90-105`, `lib.SKIN`; normative in `S/standalone-windows.md`)
- **bg / edge:** `bgFile` and `edgeFile` are both `Interface\Buttons\WHITE8x8`, `edgeSize=1`, insets 1.
- **bg** `{0.06,0.06,0.08,0.92}` (:97)
- **border** `{0,0,0,1}` (:98), a hard black 1px line
- **innerBorder** `{0.24,0.24,0.27,0.85}` (:102), a 1px inner highlight child inset by 1 (`Core.lua:139-152`)
- **divider** `{0.24,0.24,0.27,0.85}` (:103)
- **title** gold `{1.0,0.82,0.0}` (:104)
- Set `frame.title` and `frame.divider` first, then `NS.ApplySkin(frame)`; it tints both (`ACCENTS`, :110-113).

### Close button (`LK/Core.lua:203-210`)
- 18px with 12px art, from the Media `close` icon.
- Rest `{0.7,0.7,0.72}`, hover red `{1,0.3,0.3}`.
- MUST be wrapped once in `core/CoreSetup.lua` as `NS.MakeCloseButton=function(p,f) return lib.MakeCloseButton(p,f,addonName) end`, and every close control goes through that wrapper.

### Shared accent and title bars
- **Gold accent** `1,0.82,0` is used for selection highlight (alpha 0.15), nav-rail labels (`LK/OptionsNav.lua:52`), the tab rule `{1,0.82,0,0.16}` (`LK/OptionsTabs.lua:179`) and reorder/drag affordances.
- **Title bars:** 26px for the debug console and copy window (`LK/DebugLog.lua:167`, `LK/Widgets.lua:533`), 24px for the perf panel (`LK/PerfPanel.lua:36`). Title font `GameFontNormal`, centered.
- **Options header:** `GameFontNormalHuge` breadcrumb, "Ka0s X ▸ Page".

### Flat widgets
- **Dropdown** (`LK/Widgets.lua:296-299`): bg `{0.1,0.1,0.12,0.9}`, border `{0.24,0.24,0.27,0.9}`.
- **Popup menu** (:181-183): bg `{0.06,0.06,0.08,0.98}`.
- **Row text:** `{0.9,0.9,0.9}`, `GameFontHighlightSmall`.
- **Line chart:** `LK/WidgetsLineChart.lua:50`.

### Fonts
- The only shipped face is **JetBrains Mono** (`LK/Media.lua:147-148`), for the console, copy windows and glyph columns.
- Everything else uses Blizzard `GameFont*` objects.

### Chat colors
- Slash commands: key yellow `|cFFFFFF00`, value white (`LK/Slash.lua:137,143`).
- List header `|cff33ff99`, group `|cff3399ff` (:41-42).
- Debug timestamp `|cff6f8faf`, tag `|cffc9a66b` (`LK/DebugLog.lua:161`).

### How a standalone window is built (standalone-windows; reference `/mnt/d/Profile/Users/Tushar/Documents/GIT/LootHistory/modules/Browser.lua` `EnsureFrame` ~:840)
- Plain `CreateFrame("Frame",name,UIParent,"BackdropTemplate")`, movable and clamped, with no combat gate.
- A 30px title bar acting as the drag handle, `frame.divider`, and `NS.MakeCloseButton`.
- `NS.MakeResizable` (Core, with `minWidth` / `minHeight` / `onResizeStop`) and `NS.ApplySkin`.
- Position and size persisted in SavedVariables. Added to `UISpecialFrames`. Rows pooled.
- Title-bar controls use catalog icons; a wide button keeps its label with the icon beside it.
- LootHistory's tab strip uses gold for the active tab and gray for idle ones.
- **Widgets available:** `LibKa0s-Widgets-1.0` (12.1.4.3.2), wired via `core/WidgetsSetup.lua` (LootHistory):
  - `Dropdown`, `CopyWindow`, `ReorderList`, `DragHandle`
  - `LineChart`
  - `Autocomplete`, useful for a player-name filter

---

## 4. Rules that matter for a loot / inspect / whisper addon

### Events (events-frames-taint-§1)
- AceEvent only, through `SafeRegisterEvent`. No per-module event frames.
- One allowed exception is a private `RegisterUnitEvent` frame for one or two units. It is held on `NS` and unregistered on disable.
- `CHAT_MSG_LOOT` can fire in combat, so instrumentation on it must be gated (#43).

### Matching loot (localization-§4, MUST; anti-pattern #37)
- Match on itemID, classFile, GUID-derived ids, encounterID and `Enum.*`, never on localized names.
- Parse loot chat through GlobalString patterns (`LOOT_ITEM`, `LOOT_ITEM_MULTIPLE`, `LOOT_ITEM_SELF*`, ...), never English literals.
- Precedent: LootHistory's parser.
  - Code: `/mnt/d/Profile/Users/Tushar/Documents/GIT/LootHistory/core/Util.lua:197`, with patterns compiled once and rebuilt when the globals change (PrettyChat rewrites them).
  - Registration: `modules/Collector.lua:344`; unregister at :373.
  - Attribution: `modules/Attribution.lua` (`LOOT_OPENED`, `ENCOUNTER_START`/`END`, a ~1.5s context TTL).
- **LootHistory parses self loot only.** Its `ParseSelfLoot` drops other players' lines, so parsing other players' loot is new code.

### Combat and taint (events-frames-taint-§2-§6)
- Secure writes are gated on `InCombatLockdown()` and replayed on `PLAYER_REGEN_ENABLED`. Never use `UnitAffectingCombat("player")` as that gate.
- Hook Blizzard functions with `hooksecurefunc` only. Reparent Blizzard frames to a hidden parent instead of calling `:Hide()` on them (#11).
- Prefer Lua `CreateFrame` over XML. Any protected API goes through one firewall module.
- The main window is non-secure, so no combat gate is needed, but the settings panel refuses to open in combat.
- `ShowUIPanel(InspectFrame)` and protected trade calls are not on any precedent path. Keep whisper and trade actions on plain buttons.

### Secret values / Midnight 12.x (events-frames-taint-§8)
- Never pass a possibly-secret value to `table.concat`, `string.format` or `print`, and never `tonumber` or compare it.
- Output goes through Core's `SafeToString` and printer.
- Use the Compat guards `IsSecret`, `CanAccess`, `IsSafeKey` before comparing.
- Item and loot APIs are not on the protected trigger list today, but unit health and threat are.
- Any client workaround of your own makes `docs/midnight-quirks.md` required.

### Chat, whispers, addon comms and throttling
- **No standard rule exists** for `SendChatMessage`, whispers, AceComm or `C_ChatInfo.SendAddonMessage`, and no addon in the collection uses AceComm or addon messages. Your design breaks new ground, so record the choice in your docs, and consider proposing it upstream.
- **Applicable precedent:** MultiMeters.
  - `Compat.ChatSender()`: `/mnt/d/Profile/Users/Tushar/Documents/GIT/MultiMeters/core/Compat.lua:754-770`. It resolves `C_ChatInfo.SendChatMessage` at call time and falls back to the deprecated global; that call belongs in `core/Compat.lua`.
  - Throttling: `modules/Export.lua:695-735`. Rule 1 is flood (~800 CPS after a 4000-byte burst; stagger lines). Rule 2 is the hardware event: SAY, YELL and CHANNEL need one, and lines sent from a `C_Timer` callback are silently dropped. WHISPER, PARTY and RAID are unrestricted, so a whisper button sent inside its click is fine.

### SavedVariables (`S/savedvariables.md`)
- AceDB `<Addon>DB` with `schemaVersion = 0` in defaults and `NS.SCHEMA_VERSION` as the runner target.
- The migration runner in `core/Database.lua` runs before anything reads the profile. Profile-scoped steps run for every stored profile; steps are idempotent; migration tests are written red-first (savedvariables-§1).
- Defaults live only in `defaults/Profile.lua` (and `Global.lua`) (savedvariables-§2).
- Default with `== nil`, never `or` (savedvariables-§5, #54).
- A group addon SHOULD consider per-zone profiles (party/raid) (savedvariables-§3).
- No third SavedVariables global, so loot history lives in `<Addon>DB.global` (savedvariables-§4).
- Example: `/mnt/d/Profile/Users/Tushar/Documents/GIT/LootHistory/defaults/Global.lua:18`, runner at `core/Database.lua:390-407`.

### Inspect
- **There is no precedent anywhere in the collection:** no `NotifyInspect`, no `INSPECT_READY`, no `ClearInspectPlayer`. The inspect queue, its throttle and its cache are greenfield and host-owned.
- Under anti-pattern #55 it is a single-consumer pattern, so it stays out of LibKa0s.

### Item APIs available today
- **LibKa0s:** `LibKa0s-Item-1.0`, listed in section 2.
- **LootHistory's `core/Compat.lua` patterns:**
  - `C_Item.GetItemInfoInstant` / `GetItemInfo`
  - `GetDetailedItemLevelInfo` (:339, :530)
  - `GetInventoryItemLink` (:665, player only)
  - tooltip bind scan via `C_TooltipInfo.GetHyperlink` (:242-320)
- **ConsumableMaster:** `core/TooltipCache.lua:439-445` caches tooltips and retries empty lines.
- **Tradeability:** no addon detects the trade window. The `BIND_TRADE_TIME_REMAINING` tooltip-line scan through `C_TooltipInfo` is new. Match the GlobalString pattern, not English text.

### Pawn
- Mentioned only in a comment, at `LootHistory/modules/BrowserTable.lua:183`.
- Must be an OptionalDep, presence-guarded and degrade gracefully (#13/#29). Its calls belong behind one seam, the compat-style module.

### Other anti-patterns to watch
- #85: "disable" used only as a draw gate instead of real teardown.
- #47: hand-rolling any LibKa0s subsystem.
- #63: private copies of icons the library ships.
- #80: Test mode as a button instead of a checkbox.
- #83: the minimap row reset by Reset all or Defaults.
- #88: closing Settings in combat.
- #91: per-tick log spam.

---

## 5. Current versions

- **Standard:** v2.78.2, 2026-10-10 (`WAS/standards/STANDARDS.md` line 1). The standards repo has no tags.
- **LibKa0s:** latest tag v1.71.0 (cb274a4, 2026-10-07; built to standard v2.77.0); testkit revision 38. 15 majors across 34 files: Core 10, Env 2, Compat 1, Lifecycle 3, Bus 2, Schema 2, Pool 3, Item 2, Media 4, Widgets 12.1.4.3.2, DebugLog 19.2.1, Slash 20.2, Launcher 5, Options 28.2.34.2.4.8.1.7.4.2, Perf 14.1.1.6.
- **Roster:** 12 addons in `WAS/standards/ADDONS.md`, plus LibKa0s and two documentation/tooling repos. PGFE joined 2026-10-10.
- **Interface:** `120100` in every roster TOC.
- **Side note:** a non-roster `GIT/Outfitter/` exists with no X-Standard line. It is out of scope.

---

## 6. Process for a new addon (`WAS/NEW_ADDON.md`)

1. Create the repo (`master` branch). The first commit is `.gitattributes` alone (Step 0).
2. Run `/dev-copilot:wow-new-addon` in it. It fetches `NEW_ADDON.md` and `NEW_ADDON_CONTEXT.md` to a temp directory. The pack is never stored in the addon (#49).
3. Scaffold the Ace3 skeleton, the layout and the MIT LICENSE. Vendor `libs/` from LibKa0s's own folders (not a sibling addon's copy) and `testkit/` into `tests/_kit/`. Put the provenance line in CLAUDE.md.
4. Write the setup files and starters:
   - descriptors and stubs, the TOC, locale and Database
   - the schema with Master controls and the landing page
   - the launcher with its menu entries; a window addon owes Enabled · Locked? · Test mode · Show window
   - enable/disable on the Lifecycle latch, the diagnostics row and `modules/Diagnostics.lua`
5. Write the tests first, including the three named suites. The gate is `lua tests/run.lua` + `luacheck .`.
6. Write the README to its canonical sections, the CLAUDE.md stub, the docs trio plus all of Tier 1 plus the Tier 2 decisions, the ARCHITECTURE Documentation map, and DEPENDENCIES.md.
7. Generate the logos (128 TGA and 300 TGA from a 2000px PNG).
8. Run the first `tests/_kit/run-automated-tests.sh --release 0.1.0` bundle, and write its `ANALYSIS.md` and `RESULTS.md` by hand. Ship `docs/perf-analysis/README.md` with an empty capture index.
9. Walk the Definition of Done (context pack :1607) before tagging v0.1.0.
10. Add a row to `WAS/standards/ADDONS.md`: name, folder, repo URL and the Launcher menu entries column.

Afterwards, keep it compliant with:
- `/dev-copilot:wow-standards-audit`
- `/dev-copilot:review`
- `/dev-copilot:sync-docs`
- `/dev-copilot:wow-automated-tests`
- `/dev-copilot:bump-version` (the CCN 15 release gate)
- `/dev-copilot:wow-bump-interface`
- `/dev-copilot:wow-revendor-libka0s`
- `/dev-copilot:wow-perf-analysis`

---

## Gaps your design will have to cover
- **Comms, whispers and throttling:** no standard rule exists; MultiMeters' `Export.lua` is the only precedent.
- **Inspect queue:** greenfield.
- **Group-member loot parsing:** greenfield; LootHistory parses self loot only.
- **Trade-window detection:** greenfield.
- **Pawn integration:** optional and guarded.
- **Addon compartment:** not provided by LibKa0s.
- **Window vs test mode:** whether your loot window counts as a "positionable display". The preview-mode text implies yes, so plan a Test mode with placeholder drops.

Record each decision in `docs/ARCHITECTURE.md` (Taint Notes, Known Limitations), and add a row to `## Documented deviations` wherever you depart from a rule.
