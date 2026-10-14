# Ka0s Drop Watcher: review + standards audit remediation (M24) — design

- **Date:** 2026-10-14
- **Inputs:** `docs/reviews/2026-10-14/` (dev-copilot:review, scope all) and `docs/audits/2026-10-14/`
  (dev-copilot:wow-standards-audit), collated, deduplicated and adversarially verified into
  `docs/superpowers/research/2026-10-14-review-audit/findings.md` (34 findings F01-F34, all confirmed
  real; 12 completeness-critic items X01-X12). That file holds every finding's evidence, verified fix
  and verifier notes, and is the authoritative per-item detail for this spec.
- **Scope:** fix every finding, in DropWatcher and upstream (WowAddonStandards, LibKa0s, dev-copilot).
- **Plan:** `docs/superpowers/plans/2026-10-14-drop-watcher-review-audit.md`.

## Goals

1. DropWatcher is clean against both reports: every finding fixed, or recorded as a ratified
   deviation where the owner's standard says so.
2. Every defect whose root cause is upstream is fixed upstream, released on a branch, and pulled back
   into DropWatcher by re-vendor (LibKa0s) or reference refresh (the standard). Nothing in `libs/` or
   `tests/_kit/` is patched in place.
3. The green gate holds after every commit in every repo: DropWatcher `lua tests/run.lua` +
   `luacheck .` 0/0; LibKa0s and WowAddonStandards and dev-copilot their own documented batteries.

## Non-goals

- **X03** — re-vendoring LibKa0s v1.72.0 into the other 13 roster addons. Out of this run's scope
  ("this repo"); the kit change is made non-breaking (decision D2) so they stay green on their current
  vendor and can adopt on their own schedule. Listed as a follow-up in the final report.
- **X11** — the open triaged feature issues (#1-#8 and the register-cited LibKa0s/WowAddonStandards
  issues). They are feature ideas, not review or audit findings.
- **X05's in-client half** — a live two-arm `/dw perf` capture needs the game client. The offline
  test lands; the in-client confirmation becomes a smoke check (FEED/PERF row) for the owner.
- DropWatcher's own version is not bumped (CLAUDE.md: never without an explicit instruction).

## Decisions taken

| # | Decision | Why |
|---|---|---|
| D1 | One run branch name in all four repos: `feat/2026-10-14-drop-watcher-review-audit`. | One changeset; resume script checks one ref per repo. |
| D2 | LibKa0s testkit `__fireUnconditional` gains reach to handlers registered under a method name after unregister (kit 39), but **keeps returning a count** (0 when nothing was reached) instead of raising. Consumers prove reach by asserting the count (slash-commands-§7 step 6, see F22). | X02: raising would turn other roster addons' suites red on their next re-vendor. A count assertion gives the same guarantee without a breaking contract change. |
| D3 | Perf 15 uses `false` as the "observed at top level" parent for `Perf.Note` (F20). DropWatcher passes `false` for evaluate/quality.gate outside Receive. | Already stored by today's code path; smallest contract that is truthful. |
| D4 | Upstream versions bump on the branches: WowAddonStandards minor (v2.81.0), LibKa0s minor (v1.72.0, Perf MINOR 15, kit 39), dev-copilot patch (2.3.5). **Tags are cut only after the owner approves the merge.** DropWatcher re-vendors from the LibKa0s branch head and records `v1.72.0` in its provenance line; the vendor-drift gate is checked against that head. | Owner allowed upstream bumps; tags on unmerged branches would publish a release that may still change. |
| D5 | The perf-hold refusal line is `Not available during a performance capture.` and the standard gains the matching rule (F27). | F01/X01/F10 need one wording; the standard is silent today. |
| D6 | ARCHITECTURE.md spill (F13) waits for the standard's spill/§5 reconciliation (F24/F25) so the hub is reshaped once, to the corrected rule. | Avoids reshaping twice. |
| D7 | TOC `Conventional:` comments (F15) are rewritten to the corrected toc-file-§5 definition (F23), and a harness test (X07) rejects a `Conventional:` comment that states a load-time read or handler order. | Same ordering logic as D6. |
| D8 | The 722 missing enUS keys (F07) are added mechanically from a scan of `NS.L[...]` / `L[...]` literals, with a test that fails on any routed string missing from enUS. | Mechanical, and the test keeps it closed. |

**Amendment (2026-10-14):** DropWatcher's vendor-sync test checks `libs/` and `tests/_kit/` against a LibKa0s *tag*, so D4 could not hold for LibKa0s. The owner approved cutting and pushing `v1.72.0` before the merge; WowAddonStandards and dev-copilot still tag on merge.

## Work by repo

The per-finding fix text is in `findings.md`; this section groups it into deliverables.

### WowAddonStandards (upstream, first)

- **slash-commands-§7 step 6** must require proof that the unconditional fire reached a handler
  (a returned count, per D2) — F22. **AUDIT.md** conformance check walks steps 1-10 — F29.
- **toc-file-§5** positional definition of load-bearing, including order on a shared event and on an
  ordered table; denominator paragraph fixed — F23.
- **documentation-§3 spill vs architecture-§5**: names spilled to `schema.md` count as named; canonical
  spill targets for every mandated hub section; AUDIT.md accepts it — F24, F25.
- **options-ui-§19**: reparenting an existing frame onto a pooled widget, and cleanup in the widget's
  OnRelease rather than the renderer — F26.
- **Perf-hold refusal wording** rule (slash-commands / lifecycle section that owns stand-down) — F27.
- **compat root header**: "names every family member" means every shim file — F28.
- Release ripple: version bump, CHANGELOG, index blurbs, context pack, playbooks, anti-pattern ranges —
  X09.

### LibKa0s (upstream)

- testkit `__fireUnconditional` reaches method-name handlers after unregister; returns the count (D2);
  self-tests; kit 39 + version doc — F19.
- `Perf.Note` top-level observation (`false`), nesting sentences, dump field; Perf MINOR 15 — F20.
- testkit helper for the slash-commands-§7 step-10 hold-ordering case — F21.
- Release v1.72.0 on the branch: CHANGELOG with the "versions in this release" list, README/docs
  api pages — X09. Tag after merge (D4).

### dev-copilot (upstream)

- Cross-addon slash census finds constant-driven `RegisterChatCommand` — F30.
- Audit prompt: disabled-state census excludes `tests/` for runtime claims; conformance bullet makes the
  auditor check steps 6, 8, 10 — F31, F32.
- Faithful-fetch `curl` gets a timeout and retry — F33; playbook shell snippets work under zsh — F34.
- Patch release 2.3.5 (plugin manifest + changelog per its own convention).

### DropWatcher

| Area | Findings |
|---|---|
| Re-vendor LibKa0s v1.72.0; re-check the Documented-deviations rows the re-vendor triggers | F17, X06 |
| Refresh the standard reference to v2.81.0 (TOC X-Standard, README badge, CLAUDE.md) | X09 ripple |
| `NS.StoodDownRefusal()` for the five refusal sites and the three Press* refusals; perf line | F01, F10, X01 |
| Fixed announce channel honours the not-in-a-group refusal (Post my tradeables too) | F02, X10 |
| Shared event dispatcher isolates each handler (pcall + error report), CCN ≤ 15 | F03, X12 |
| `evaluate` / `quality.gate` declared `within = "feed.add"`, truthful parent via Perf 15 | F06, X10, X12, X05 |
| Disabled-state conformance suite: step 6 proves reach, steps 7/8 complete, step 10 added | F04, F05, F18 |
| enUS carries every routed string; test enforces it | F07 |
| `.luacheckrc` world-API globals scoped; optional-addon probes go through Compat | F08, X10 |
| `NS.SetTestMode` doc block placement; When-to-show reparent cleaned up in OnRelease; Toast close degrades to nothing | F09, F11, F12 |
| TOC `Conventional:` → `LOAD-BEARING:` where a load-time read or handler order applies; harness gate | F15, X07 |
| ARCHITECTURE.md hub spill to topic docs; stale counts | F13, F14 |
| Topic docs, smoke checks (incl. in-client checks for each change and the perf capture), test-case list, README badge | X04, X05, X08 |
| Fresh automated-test bundle at the end | F16 |

## Acceptance

- Every F/X item in `findings.md` maps to a plan item that is landed (commit subject `DW-Pn: …` in the
  owning repo), or to a non-goal above.
- DropWatcher gate green; vendor-drift gate empty against the LibKa0s branch head; LibKa0s,
  WowAddonStandards and dev-copilot batteries green.
- A re-run of the standards audit's checks for the touched sections finds no new deviation.
- All four branches pushed; nothing merged until the owner says so.
