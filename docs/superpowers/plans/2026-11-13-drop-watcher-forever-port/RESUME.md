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
- 2026-11-13 — M2 landed (Forever class data, armor by level, ranged slot, Pawn by talent tree, score-first verdicts); Forever profile now 0 failed. Carried forward: DW-FP09 adds S.RANGED to the sim roster gear order and a Forever PLAYER_LEVEL_UP gear rebuild; DW-FP12 adds the ranged-slot and score-first rows to the feature table, puts S.ScoreFor in testing.md's suites-only table, and notes verdictMode in design-readings; DW-FP15 shows which scale scored a looter (S.ScoreFor how) and words a score-led upgrade at lower ilvl; DW-FP21 probes which secondary stats the Forever weights editor should offer.
- 2026-11-13 — M3 landed: Retail-only systems absent on Forever, Forever trade model, the port lands (dual TOC, feature table), roster row on WowAddonStandards. Carried to DW-FP21: hide or rename the Drops Trade window column on Forever; drop Forever-unread defaults (transmogAsk, askOffSpec, glow.offSpec) and Glow.KINDS offSpec; gate the auto-ask diagnostics offSpec word; feature-table rows use only retail/forever/both tokens (split the "Each its own" rows); README Usage marks Retail-only situations; split mixed RETAIL_ONLY cases so Forever covers their shared halves. Carried to DW-FP22: audit the 123 Forever skips.
