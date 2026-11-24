# 02 — Candidates: LibKa0s v1.113.0 -> v1.114.0

Sources: `git log --oneline v1.113.0..v1.114.0` (8 commits) and the v1.114.0 CHANGELOG block at the tag.

## Class A: reached the addon on the re-vendor alone
- The diagnostics report names `LibKa0s-ForeverDB-1.0` among the running majors and prints one ForeverDB line (present, loaded, version; build and hash when loaded), DebugLogDiagnostics minor 12. It never loads ForeverDB.
- Kit revision 62's regenerated Forever name set, read by the client-globals suite.

## Class B: host change required
- None.

## Class C: whole-module adoption
- **`LibKa0s-ForeverDB-1.0`** (`docs/api/ForeverDB/version-1-docs.md`, *Lib-level surface* and *Adopting it*): the WoW Forever reader of the optional ForeverDB data addon. Additive: nothing the addon owns is replaced. Pre-decided by the run (spec §8 answer 1, §9 row SF-DW-01): the detail card shows where the item drops (up to three sources with chances), the world-drop minimum level and who sells it, through `ItemSources` and `NPC`.

No other new surface arrived in this range.
