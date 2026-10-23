# 02 — Candidates

Sources: `git -C ../LibKa0s log --oneline v1.75.2..v1.76.0`, the v1.76.0 block of
`../LibKa0s/CHANGELOG.md` at the tag (with its *What a consumer owes* list), and the API documents it
links: Sim `docs/api/Sim/version-2.3.5-docs.md` and Widgets `docs/api/Widgets/version-14.1.4.3.2-docs.md`.

The interview is not run here. The cross-repo bundle
(`Ka0sAddonsCommonTasks/docs/2026-10-23-SIM_PREVIEW_MODE_STRIPS/`, its `plan-data/items.json` and
`inputs/OWNER_SCOPE.md`) decided every candidate in advance, and the run files no GitHub issue. Each
adoption is its own later item.

## A. Delivered on the re-vendor alone

- **SimTimeline 3, SimPanel 5: a started simulation plays on its own.** `/dw sim start` and the
  panel's Start play at once; a typed `step`, a click on the ready row and a click ahead hold the
  run; `Resume` keeps `paused` when refused; the controls are Pause/Resume, Restart and Stop. The
  behavior reaches the addon on the copy; the suites it broke are re-trued at their minimum in this
  commit (`01_DELTA.md` 3g), and the strings and docs that name Run all are DW-01's.

## B. Host change required

| Candidate | Evidence | Decision |
|---|---|---|
| Auto-play: the ready line, the step-delay tooltip, the typed-start suites, the docs and smoke procedures | CHANGELOG v1.76.0 "SimTimeline minor 3 and SimPanel minor 5" and its *What a consumer owes*; Sim `version-2.3.5-docs.md` | decided in the cross-repo bundle: adopt (DW-01) |
| `W.TestStrip(parent, { kind = "sim" })`: a sim-flavor strip beside the test strip | CHANGELOG v1.76.0 "Widgets minor 14: W.TestStrip's simulation flavor"; Widgets `version-14.1.4.3.2-docs.md` | decided in the cross-repo bundle: adopt (DW-10) |

## C. Whole-module adoption

None. Every major in the payload is already looked up here (`01_DELTA.md` 3e).
