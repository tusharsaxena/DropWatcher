Delta: LibKa0s v1.109.0 -> v1.113.0 (span: v1.109.0 v1.112.0 v1.113.0)

The consolidated span bundle `/dev-copilot:wow-revendor-libka0s` Step 3h asks for, written by item SF-DW-01 of Ka0sAddonsCommonTasks `docs/2026-11-25-SEEDS_AND_FOREVERDB/` beside this run's own bundle `2026-11-25-v1.114.0/`. Three tags this addon vendored after the store's newest single-tag bundle (`2026-11-20-v1.108.0`) were carried by sweeps that wrote no bundle of their own. v1.110.0 and v1.111.0 were never vendored here (`40ad997` rolled the line straight from v1.109.0 to v1.112.0), so they are not on the span line.

The vendored list (Step 3h's walk over `libs/LibKa0s`, `tests/_kit` and the `CLAUDE.md` provenance rolls since the store's first bundle, 2026-10-14):

```
v1.72.0 ... v1.108.0 (recorded), v1.109.0, v1.112.0, v1.113.0
```

The recorded list (every bundle folder's tag, a span bundle's line-1 tags), then the difference:

```
$ grep -vxF -f recorded.txt vendored.txt
v1.109.0
v1.112.0
v1.113.0
```

The commits that carried them:

```
3b09679 FU-RV-DW: Re-vendor LibKa0s v1.109.0 (kit revision 59) and standard v2.117.0 (per-client quirks files)
f242741 FU-RV-DW: Re-copy Compat.lua (minor 5) and Sim.lua (minor 4) from the re-cut v1.109.0 (their forever-quirks-§4 citations)
40ad997 FB-DW-01: Re-vendor LibKa0s v1.112.0 (kit revision 60)
8ad6063 FB2-DW-01: Re-vendor LibKa0s v1.113.0 (kit revision 60)
593d22b FB2-DW-02: Re-vendor the re-cut LibKa0s v1.113.0: a selected row is Ka0s Default's gold in every skin
```
