# CLAUDE.md — Ka0s Drop Watcher

**Ka0s WoW addon.** Adheres to the **Ka0s WoW Addon Standard** —
https://github.com/tusharsaxena/WowAddonStandards

## Standards compliance (read first)

This repo is built to the **Ka0s WoW Addon Standard** (URL above). All development here — features,
refactors, doc changes — MUST conform to it. The standard is the source of truth for layout, TOC
shape, the Ace substrate, schema-driven settings, slash/prefix conventions, locales, Compat,
tests/lint, and doc structure.

**If a change would deviate from the standard, STOP and flag the deviation explicitly.** Do not
silently deviate and do not silently "fix" to match. Surface it and let the user decide which of
two things it is:

1. **An accepted deviation** — this addon intentionally differs; record it as a row in
   `docs/ARCHITECTURE.md` -> `## Documented deviations`, shaped
   `| Rule | What differs | Why | Decided | Re-check trigger |`, where Rule is the `filename-§N`
   reference. That register is the single home: the reasoning may live in the issue-audit GitHub
   issue or an audit bundle and the row cites it, but a deviation not in the register is not ratified.
2. **A change to the standard itself** — the standard's definition should evolve; the update
   belongs upstream in the WowAddonStandards repo, after which this addon conforms to the new rule.

When in doubt, treat standard conformance as a hard requirement and ask.

Start here, then read the docs:

- **`docs/ARCHITECTURE.md`** — module map, settings schema, message bus, slash surface, event
  wiring, taint notes, known limitations, documented deviations. What this addon actually is.
- **`docs/testing.md`** — how to verify: the headless harness, lint, and the green commit gate.
- Topic detail in `docs/` as needed (`scope.md`, `module-map.md`, `schema.md`, `settings-panel.md`,
  `data-flow.md`, `common-tasks.md`, `smoke-tests.md`, …), registered in `docs/ARCHITECTURE.md` ->
  `## Documentation map`.
- **`DEPENDENCIES.md`** — the toolchain contract: what to install to build, run, test or release.
- The v1 design spec and its checkpointed plan live in `docs/superpowers/`.

Green gate before every commit: `lua tests/run.lua` and
`~/.claude/dev-copilot/bin/ka0s-bounded luacheck .` (0/0; the kit bounds the suite on load, and
`luacheck` loads no kit, so it runs through the bounded runner, testing-§15). Never edit `libs/` or
`tests/_kit/` (vendored; re-vendor instead). Never auto-stage/commit/push and never bump the version
without an explicit instruction.

Bundles [LibKa0s](https://github.com/tusharsaxena/LibKa0s) v1.77.0 (MIT).
LibKa0s icons: add, arrow-down, arrow-right, arrow-up, ban, cancel, chat, chevron-down, chevron-right, chevron-up, clear, clock, close, confirm, copy, edit, external-link, fullscreen-enter, fullscreen-exit, help, info, link-intact, lock, minimise, people, reset, speech-bubble, transfer.
