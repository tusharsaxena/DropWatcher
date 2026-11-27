# Summary: LibKa0s v1.118.0 -> v1.119.0

- **Moved:** v1.118.0 (base, from the CLAUDE.md provenance line) to v1.119.0, the release record
  on LibKa0s's `feat/2026-11-27-itemsearch-split` at `110e02be`, untagged until task G1. Minors: the
  eleven new Verdict files at 1, DebugLogDiagnostics 12 -> 13 (`01_DELTA.md`). No span bundle and no
  base correction.
- **Reached the addon for free:** DebugLogDiagnostics 13 (Verdict in its major list).
- **Contract blockers:** none in the bytes. The vendor-sync gate's two payload cases fail until the
  tag exists (`01_DELTA.md`, *Blockers*); the payload was proven against a throwaway local tag in a
  scratch clone.
- **Icons:** the `LibKa0s icons:` line kept; the prune removed the 362 sound files, as before. No
  README credit changed; no dead stub mirror.
- **Adopted** (decided by the plan, task C1 of `docs/superpowers/plans/2026-11-27-itemsearch-split.md`;
  no interview, no issue): `LibKa0s-Verdict-1.0`, whole, in slices.
  - `b3b324b` IS-C1.1: the re-vendor itself.
  - `62b7227` IS-C1.2: `core/VerdictSetup.lua` (the instance, its host and its stand-in) and
    `core/VerdictViews.lua`; the kernel readers (`NS.Evaluate`, `NS.ClassData`, `NS.OffSpec`,
    `NS.TierTokens`) onto the major; five files deleted.
  - `a628890` IS-C1.3: the item facts and item reads onto the instance.
  - `0657c24` IS-C1.4: your gear snapshot onto the instance (the first read kept lazy and quiet).
  - `800de04` IS-C1.5: the scorers.
  - `49fe0cc` IS-C1.6: the collection verdict and its events.
  - `2302033` IS-C1.7: the Comparison page from `V.Settings`; the seed tool reads the class lists
    from the vendored copy.
  - `cb660f9` IS-C1.8: the host's own suite (`tests/test_verdict_setup.lua`) and the code comments.
  - The docs sync follows in IS-C1.9.
- **Declined:** none. **Unreached:** none.
- **Gate at the end of the run** (both kit profiles, the two vendor-sync cases the only failures):
  Retail 2797 passed, 2 failed, 168 skipped; WoW Forever 2842 passed, 2 failed, 121 skipped;
  `ka0s-bounded luacheck .` 0 / 0 in 301 files; `pytest tools/seeds` 34 passed. The golden suite
  (`tests/test_verdict_golden.lua`, `tests/fixtures/verdict_golden.lua`) is byte-unchanged since
  A1 (`5dafd4e`) and green.
