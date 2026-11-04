# Candidates

Sources: `git -C ../LibKa0s log --oneline v1.85.0..dab6407`, the CHANGELOG blocks v1.86.0 and v1.87.0 at `dab6407`, and the API documents of the majors that moved (Toast 3 -> 4, DebugLog key 22.6.1.4 -> 22.7.1.4, IconBrowser new). No interview was held and no issue was filed (the run's instruction for `DW-T1`); every candidate is listed here instead, and adoption is decided by the run plan (`docs/superpowers/plans/2026-11-05-issues-10-14/items.tsv`).

The Toast stub's three members are a blocker (`01_DELTA.md`), not a candidate, and are fixed in the re-vendor commit.

## Class A: delivered on the copy, no host change

- **A hold drops no payload.** A toast sent back from the screen to wait goes to the head of the queue and drops nothing; version 3 trimmed the newest waiting payload (CHANGELOG `dab6407:CHANGELOG.md:21`, `docs/api/Toast/version-4-docs.md:28`). This addon's combat hold (`modules/Toast.lua:593`, `Toast.OnCombatStart`) now keeps every drop it held.
- **`Attach` before the first `Show`** builds the first frame hidden and wires the control (`CHANGELOG.md:22`, `version-4-docs.md:138`). This addon attaches from its builder (`modules/Toast.lua:359-360`), so behavior is unchanged; it is the safer shape for free.
- **Without a `stack` field, the toast is version 3's** (`version-4-docs.md:22`): one frame, one toast, every member answering as before. Nothing else moves for this addon until it opts in.
- **Diagnostics' `LibKa0s running:` line names `IconBrowser`** (DebugLogDiagnostics minor 7, `CHANGELOG.md:45`). No member moves.

## Class B: host change required

1. **Toast minor 4's stack** (`CHANGELOG.md:21`; `version-4-docs.md:24-26`, descriptor rows `:118-120`, instance rows `SetStack` `:140`, `Visible` and `FrameFor` after `Current`, `Stats` fields). Descriptor `stack`, `stackGrow`, `stackGap` (value or getter), `lib.STACK_GAP`, instance `SetStack(n, grow)`, `Visible()`, `FrameFor(key)`, `Stats()` gaining `visible`, `visibleKeys`, `stack`, `grow`. Files it would touch: `modules/Toast.lua` (descriptor, frame lookups by key, Prune/Dismiss/Ask per toast), `defaults/Profile.lua` and `settings/Schema*.lua` (`toast.stack` 1-5 default 3, `toast.stackGrow` down/up), locales, diagnostics, tests, a smoke step. **Recommendation: adopt.** It is issue #14's whole ask and the reason v1.87.0 exists. Blast radius: additive at the shell (no `stack` is version 3), but the host's single-toast assumptions (`Current()`, `Frame()`, the Ask on "the" toast) are code it owns and must move to per-key lookups. **Decided by the plan: adopt, as `DW-T2`** (the next item), not in this item.

## Class C: whole-module adoption

1. **`LibKa0s-IconBrowser-1.0`** (new at v1.86.0; `CHANGELOG.md:44`, `:49`; `docs/api/IconBrowser/version-1.1.1-docs.md`). A host-configured icon browser window with tabbed sources (markers, game icons, glyphs), plus glyph and color helpers. Files it would touch: a new `core/IconBrowserSetup.lua`, the TOC, a settings row to open it, and the icon line (`all (icon browser).`, which would ship the whole catalog). **Recommendation: never, structurally.** This addon has no setting where the player chooses an icon: every mark it draws is fixed in code (`NS.Icon` calls and its declared 32). Blast radius: additive, but it would grow the shipped payload by the full icon catalog for no surface. `gh issue list --search "IconBrowser"` and `grep -rn 'IconBrowser' docs`: no recorded decision yet. **Not adopted in this run; not filed (no issue filing in `DW-T1`).**
