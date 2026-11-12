# Resuming the Forever port run

Run `./resume-state.sh -v` in this folder. The plan is
[`../2026-11-13-drop-watcher-forever-port.md`](../2026-11-13-drop-watcher-forever-port.md), the design
[`../../specs/2026-11-13-drop-watcher-forever-port-design.md`](../../specs/2026-11-13-drop-watcher-forever-port-design.md).
DropWatcher items land on `feat/2026-11-13-forever-port`; WowAddonStandards (`WS-*`) and LibKa0s (`LK-*`) on
`feat/2026-11-13-dropwatcher-forever-port`. Gate: both kit profiles and luacheck 0/0. Push after each milestone;
never merge without the owner's go-ahead.

## Log
- 2026-11-13 — research (5 notes, 2 skeptic passes), design, builder check (4 questions, all settled as Claude's calls, design §11), plan written. Branch cut from master `924435f`. Baseline: retail 2242/0/1, forever 2234/8/1 (spec), lint 0/0.
- 2026-11-13 — M1 groundwork landed (LibKa0s v1.95.0, CompatClient, default skin per client, names). Carry into M2: a Forever-profile PlayerTalentTree case against the real Role.Groups (FP02 review); CharacterKey can be nil when the library is absent.
