# Drop Watcher feedback-21 — Can't use in dim red, Trade's Can't use, the upgrade glow (and KickCD's glow knobs)

Resumable, checkpointed plan. Each task ends in a commit on its branch; the **Status ledger** below
is the checkpoint. To resume: read the ledger, `git log --oneline` on each branch, and start at the
first task not `done`. Never merge without the owner's go-ahead.

- DropWatcher branch: `feat/2026-10-18-feedback-21` (from master `64307d3`; first commit `28dd3dc` is the
  owner's feedback-20 work, committed as found by the owner's choice).
- KickCD branch: `feat/2026-10-18-feedback-21` (from master `970a728`).
- Green gate before every commit, in each repo, through the bounded runner:
  `/home/tushar/.claude/dev-copilot/bin/ka0s-bounded lua tests/run.lua` and
  `/home/tushar/.claude/dev-copilot/bin/ka0s-bounded luacheck .` (0/0).
- Never edit `libs/` or `tests/_kit/` (except the vendoring copy of a whole library folder).

## Status ledger

| Task | Repo | Status | Commit |
|---|---|---|---|
| G0 plan | DW | done | (this file) |
| G1 Can't use dim red + Trade's Can't use | DW | done | ee51fbd |
| G2 vendor LibCustomGlow-1.0 | DW | done | 4c13b84 |
| G3 glow settings (schema rows, defaults, Window › Upgrade glow tab) | DW | done | 9942772 |
| G4 glow module + the four surfaces | DW | done | 8b36aa3 |
| G6 tooltip readability pass (every tooltip as bulleted rows) | DW | done | 2bfef72 |
| G5 docs, smoke checks, test-cases, README badge | DW | done | 5a5283a |
| K1 KickCD per-style glow knobs | KickCD | done | `7307777` (KickCD) |
| R1 review + fixes (both repos) | both | done | `d8a74d8` (KickCD), `86fac39`, `8ffbac6` (DW) |
| P1 push both branches | both | done | DW `feat/2026-10-18-feedback-21`, KickCD `feat/2026-10-18-feedback-21` |
| S1 standard: how a locale file is split (WowAddonStandards, branch `feat/2026-10-18-feedback-21`) | WAS | done | `87bc0ef` (WAS) |
| G7 glow colors get the "Use class color" companion | DW | done | 927c410 |
| K2 KickCD lists LibCustomGlow-1.0 in OptionalDeps | KickCD | done | 313d2b1 |
| G8 DW cites the new locale-split rule | DW | done | ef05ed0 |
| R2 review S1, G7, K2, G8 | all | done | 5d120f0 (DW), `dd1fd71` (WAS); open: the three branch names are not versioning-git's `feat/<YYYY-MM-DD>-<topic>` (owner, at M1) |
| P2 push all three branches | all | done | all three on `feat/2026-10-18-feedback-21` (versioning-git; the old `feature/*` remote branches await the owner's OK to delete) |
| G9 the toast never glows | DW | done | b785c9f |
| G10 toast scale | DW | done | 4488c30 |
| G11 item icon style (zoom, border block, quality border) | DW | done | ea750d8 |
| R3 review G9, G10, G11 | DW | done | f3cafdb (stale Glow.lua TOC note fixed; borderSize floor 1 refuted: composer rows are retuned by hosts, CM floors at 1 too) |
| PF1 perf: G6's refresh allocation recovered | DW | done | 43bde2a |
| P3 push | DW | done | through PF1 |
| M1 merge (owner's go-ahead), delete branches/worktrees/stashes | all | blocked on owner | |

## What the owner asked (decided in conversation, 2026-10-18)

1. **Can't use in dim red.** The `cantUse` verdict's text reads dim red everywhere a verdict is drawn:
   the full table's Me and Them cells, the compact card's halves, the detail card's CAN'T USE badge,
   History's cells. `doesntWant` stays gray (`bad`).
2. **Trade's Can't use.** On another player's drop whose Trade would read Yes or Likely (the `good`
   tone), Trade reads **Can't use** instead when none of your specs can use it: main verdict
   `cantUse` and no off-spec part (`WindowCells.lua` `youCantUse`, already present). When an
   off-spec can use it, Trade keeps its Yes or Likely in its own green. Trade's Can't use is the same
   dim red; its tooltip keeps the trade reason and the existing "You can't use it, so there is
   nothing for you to ask for." line. This replaces feedback-20's `goodMuted` tone, which is removed.
   Unlikely / No / Unknown are unchanged.
3. **The upgrade glow.** An item icon glows when the drop is an upgrade for you:
   - two independent glows, each with its own settings: **main spec** (`me.verdict == "upgrade"`)
     and **off-spec** (`me.verdict == "cantUse"` whose off-spec part, `NS.OffSpec.Of(me)`, is an
     `upgrade`). Sidegrades, downgrades and your own drops never glow.
   - on all four surfaces: the full table's Drops row item icon, the compact card's icon, the
     detail card's header icon, the toast's icon. Not History, not the Offer panel, not the detail
     card's Replaces rows.
   - each glow: enabled, style (button, proc, pixel, autocast), color (RGBA), and its style's knobs;
     knobs of another style are dimmed (`disabledIf`), and everything is dimmed while it is off.
   - defaults: main **on, proc, the upgrade green** (`C.TONE.good`, a = 1); off-spec **on, pixel,
     the off-spec cyan** (`C.TONE.offspec`, a = 1).
   - settings live on a new **Window › Upgrade glow** tab; the main-spec and off-spec rows side by
     side where the panel's two-column renderer allows, else main first then off-spec.
   - library: **LibCustomGlow-1.0**, copied whole from KickCD's vendored `libs/LibCustomGlow-1.0/`
     (minor 24; library-stack-§3 "SHOULD copy from an existing Ka0s addon"), listed in the TOC before
     the addon's files, in `DEPENDENCIES.md`, in the debug log's library list (if the addon keeps one),
     and in README's credits/licenses line as the existing libs are.
4. **Tooltips as rows** (added mid-run, with a screenshot of Trade: Likely's tooltip as the
   example of what is unreadable). Every tooltip the addon draws is reworked from sentences into
   distinct rows, one per data point, each a bullet. Settings-panel descriptions (`desc` on schema
   rows) are prose and out of scope.
5. **KickCD** gets the same per-style knobs for each of its glow slots (primary, secondary per unit),
   with the same knob set, ranges and defaults as below, so both addons read the same.

## The glow knob set (shared by both addons)

LibCustomGlow-1.0 minor 24 signatures:
`PixelGlow_Start(r, color, N, frequency, length, th, xOffset, yOffset, border, key, frameLevel)`,
`AutoCastGlow_Start(r, color, N, frequency, scale, xOffset, yOffset, key, frameLevel)`,
`ButtonGlow_Start(r, color, frequency, frameLevel)`,
`ProcGlow_Start(r, { color, startAnim, duration, xOffset, yOffset, key, frameLevel })`.

| Knob | Style | Range / step | Default | Maps to |
|---|---|---|---|---|
| type | all | button, proc, pixel, autocast | per glow | which `_Start` |
| color | all | RGBA | per glow | `color` |
| pixelLines | pixel | 1–20 / 1 | 8 | `N` |
| pixelFrequency | pixel | 0.05–2 / 0.05 | 0.25 | `frequency` |
| pixelLength | pixel | 0–20 / 1 (0 = automatic) | 0 | `length` (nil when 0) |
| pixelThickness | pixel | 1–6 / 1 | 1 | `th` |
| pixelBorder | pixel | bool | true | `border` |
| autocastParticles | autocast | 1–12 / 1 | 4 | `N` |
| autocastFrequency | autocast | 0.05–2 / 0.05 | 0.125 | `frequency` |
| autocastScale | autocast | 0.5–3 / 0.1 | 1 | `scale` |
| buttonFrequency | button | 0.05–2 / 0.05 | 0.25 | `frequency` |
| procDuration | proc | 0.25–3 / 0.25 | 1 | `duration` |
| procStartAnim | proc | bool | true | `startAnim` |
| xOffset, yOffset | pixel, autocast, proc | -10–10 / 1 | 0 | offsets |

Each addon names the stored keys in its own convention (DropWatcher: `glow.main.<knob>`,
`glow.offSpec.<knob>`; KickCD: its `units.<unit>.icons.{primary,secondary}Glow<Knob>` pattern), but
the knob set, ranges and defaults are the table's.

Every default is the value LibCustomGlow-1.0 takes for nil (R1: pixelThickness was 2,
pixelBorder false and buttonFrequency 0.125, which changed KickCD's existing glows on upgrade;
button's nil throttle 0.01 is frequency 0.25 under `throttle = 0.25/frequency*0.01`).

## Tasks

### G1 — Can't use in dim red, Trade's Can't use (DW)

- `core/Constants.lua` `C.TONE`: add `redMuted` (a dim red, e.g. `{ r = 0.72, g = 0.36, b = 0.34 }`,
  read beside `red` and `bad`); remove `goodMuted` and its comment.
- `modules/WindowCells.lua`: VERDICT tone `cantUse = "redMuted"`; `WC.Trade` on `good` + `youCantUse`:
  text and title `Can't use` (`L["Can't use"]`, title `Trade: Can't use`), tone `redMuted`, the tip
  line kept. Check every other place a verdict tone is mapped (`DetailCells.lua` badge, compact
  cards' WORD_VERDICT halves, `WindowHistory`, `SideCells`, `OffSpecCells` main verdict, Offer
  panel candidates' `cantUse` status, filter bar) and make Can't use read dim red where the verdict
  is shown; where a tone is resolved to RGB, make sure `redMuted` resolves (grep `C.TONE[`).
- Tests: update every pinned `goodMuted` / `bad` expectation for cantUse; add cases: cantUse verdict
  tone, Trade's Can't use on a no-off-spec cantUse, Trade keeps Likely green with an off-spec part,
  Unlikely unchanged, your own drop unchanged.
- Commit.

### G2 — vendor LibCustomGlow-1.0 (DW)

- Copy `../KickCD/libs/LibCustomGlow-1.0/` whole into `libs/LibCustomGlow-1.0/`; add its xml to
  `DropWatcher.toc` with the other libs; `.luacheckrc` already excludes `libs/` (verify).
- `DEPENDENCIES.md`, README credits, and the debug log's library list (grep `LibSharedMedia` in
  `core/DebugLogSetup.lua` for the shape) name it.
- Commit.

### G3 — glow settings (DW)

- `defaults/Profile.lua`: `glow = { main = {...}, offSpec = {...} }` per the knob table.
- `settings/SchemaRows.lua`: a `glow()` builder on page `window`, group `L["Upgrade glow"]`, rows
  per glow in the knob table's order, color rows typed `color`, `disabledIf` for off / other style,
  `onChange` repainting the window and the toast (a shared `NS.Glow.Refresh()`).
- `settings/Pages.lua`: the Window page's reset tip names the glow.
- Locales: every new label and tooltip in `locales/enUS.lua`.
- Tests: rows exist with their defaults, validation refuses out-of-range values, `disabledIf` dims
  other styles' knobs.
- Commit.

### G4 — the glow module and the four surfaces (DW)

- New `modules/Glow.lua` (TOC before its users): `Glow.KindOf(drop)` → `"main"`, `"offSpec"` or nil
  (never your own drop; main = `me.verdict == "upgrade"`; offSpec = cantUse with `OffSpec.Of(me)`
  verdict `upgrade`); `Glow.Apply(button, drop)` starts the configured glow for that kind with
  a stable key (`"DropWatcherUpgrade"`), stops it for nil, and restarts when the kind or settings
  change (remember the applied signature on the button so repeated paints are free);
  `Glow.Stop(button)`; `Glow.Refresh()` repaints every surface. A missing LibCustomGlow (headless,
  or LibStub miss) makes Apply a no-op that still records the decision (`button.glowKind`) so suites
  can assert it.
- Wire in: full table Drops row (`WindowGroup` item cell's button, where `SetItem` is called for a
  drop row), compact group card (`CompactGroup.lua` `card.icon`), detail card header
  (`DetailCard.lua` `card.icon`), toast (`Toast.lua` `frame.icon`, using the toast's drop record).
  Pooled rows must stop the glow when released or reused for a non-glowing drop.
- Test mode's samples already include main-spec and off-spec upgrades, so `/dw test` shows both.
- Perf: Apply must cost nothing on a repaint where nothing changed (signature compare).
- Tests: KindOf on each verdict shape; Apply records/clears `glowKind`, honors each glow's
  `enabled`; each surface's icon gets the kind after a paint; a reused row loses it; a settings
  change re-applies.
- Commit.

### G6 — tooltip readability pass (DW), after G4, before G5

The rule: a tooltip is its title line (as now), then **one row per data point**, each a bullet:
`• <Label>: <value>`, the label in the idle gray (`C.IDLE`), the value plain or in its tone. No
multi-clause sentences; a reason that was a sentence becomes the rows of its facts. Free text rows
are allowed only for a short closing hint (e.g. "Shift-click to link it in chat"), unbulleted and
gray. Grids (TM.Grid, the gear lines) stay grids.

The worked example, Trade on another player's drop (today four sentences):

```
Trade: Likely
• Rule: personal loot
• This item: 311
• Alantie wears: 331, so it is not an upgrade for them
• For you: can't use, nothing to ask for
• Inspected: 29m ago
• Basis: an estimate (another player's drop)
```

- The bullet: the tooltip face lacks several glyphs (`modules/TipMarks.lua` header), so the bullet
  is a TipMarks helper (`TM.Bullet`/`TM.Row(label, value, tone)`) that draws an inline texture
  escape from a LibKa0s media icon if a dot-like one exists, else a character every face has
  (`-`). One helper, every tooltip uses it; test_tip_marks pins its strings.
- Inventory first: every tooltip builder in `modules/` (`.tip[...]`, `tip = {`, `AddLine`,
  `Window.AttachTooltip`, `TRADE_REASON`, `EXPLAIN`, verdict reasons, footer, filter bar, title
  bar, Offer panel, detail card chips and actions, History cells and cards, toast, compact halves,
  the simulator panel), then rewrite module by module. Locale keys: new label keys added, keys no
  longer read removed (the locale stays exactly what the code reads).
- Suites that pin tooltip text are updated deliberately; add test_tip_marks cases for the row
  helper and one case per rewritten builder family asserting the row shape.
- Commit (one per module family is fine).

### G5 — docs (DW)

- `docs/ARCHITECTURE.md` (module map row, documentation map if a doc is added), `docs/module-map.md`
  (Glow row, renumbered to the TOC), `docs/schema.md` (Window › Upgrade glow table),
  `docs/settings-panel.md`, `docs/data-flow.md` (tones: Can't use dim red, Trade's Can't use),
  `docs/smoke-tests.md` (new checks with blank Result lines and Pending sign-off rows: the glow on
  each surface, each style, off-spec glow, Trade's Can't use), `docs/testing.md`, README (feature
  lines, settings, FAQ if apt, test badge), `docs/test-cases.md` regenerated the way previous commits
  did (check `tests/` or `docs/testing.md` for the generator).
- Commit.

### K1 — KickCD per-style glow knobs (KickCD)

- Branch `feat/2026-10-18-feedback-21`. For each glow slot, add the knob table's per-style rows (keeping
  KickCD's interleaved primary | secondary two-column layout and its options-ui conventions), defaults,
  `disabledIf` for other styles and for trigger `never`, wire them into `Icon:UpdateGlow`
  (`modules/IconGrid_Render.lua`) so a change restarts the glow, locales, tests, and docs (its
  schema / settings docs, smoke checks with Pending rows, README). Commit(s) on its own gate.

### Owner decisions after R1 (2026-10-18)

1. **Locale split → the standard.** Keep `locales/enUS_Settings.lua` (enUS.lua passed the 1500-line
   cap) and add the rule for splitting a locale file to the standard upstream (WowAddonStandards,
   S1), following that repo's own process for a rule change; DropWatcher then cites it (G8).
2. **Glow colors get the class-color companion** (options-ui-§17), as KickCD's glow colors have
   (G7): `glow.<g>.useClassColor` (player-scoped), beside each swatch, the reviewer's exemption
   comment and schema note replaced.
3. **KickCD aligns**: `LibCustomGlow-1.0` joins `## OptionalDeps`, its DEPENDENCIES.md note
   updated (K2).

### Owner asks after R2 (2026-10-18)

- **G9 — the toast never glows.** A toast only ever shows an upgrade, so the glow there says
  nothing. Remove the toast from the glow's surfaces (code, tests, the Upgrade glow tab's and docs'
  wording, GLOW-1 now says the toast shows none); the three other surfaces keep it.
- **G10 — toast scale.** `toast.scale`, Window › Toast, a slider 50–200 % by 5 (stored 0.5–2.0 by
  0.05, default 1.0 = today's size), applied live to a toast on screen and to the toast's position
  anchor (its saved point unchanged). Row, default, schema doc, settings-panel doc, smoke check,
  tests.
- **G11 — item icon style.** One shared style for EVERY item icon the addon draws (all come from
  `NS.WindowGroup.ItemButton`: table rows, compact cards, detail card header and Replaces rows,
  toast, History, Offer panel, side-cell gear icons), on a new Window › Icons tab:
  - Zoom (texcoord crop, KickCD's shape: 0–0.25, default = today's crop so nothing changes).
  - The canonical border block, options-ui-§16 (LibKa0s `BorderGroup` shape, as ConsumableMaster
    builds it): Show border, Border style (LSM border), Border thickness, Border color, Use class
    color (player-scoped). Defaults reproduce today's look.
  - Color the border by item quality (the owner's "bells and whistles"; AuraMaster's dispel-color
    border is the precedent): when on, the border takes the item's quality color, overriding the
    swatch. Default off.
  - Applied live to every pooled and unpooled item button; the glow stays above the border; a
    repaint with no change costs nothing (signature, as the glow does); perf scenarios stay green.

### R1 — review

- Review both branches' diffs against master for correctness, standard conformance (flag, never
  silently deviate) and test coverage; adversarially verify findings; fix the confirmed ones; gate;
  commit.

### P1 — push

- `git push -u origin feat/2026-10-18-feedback-21` and `git push -u origin feat/2026-10-18-feedback-21`.

### M1 — merge (owner's go-ahead only)

- Merge each branch to master, push, delete the local and remote branches, and any worktrees or
  stashes this run created.
