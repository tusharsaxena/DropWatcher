Delta: LibKa0s v1.95.0 -> v1.95.0 (span: v1.95.0)

Written 2026-11-15 by RX-13, beside `../2026-11-15-v1.102.0/`. A records-only back-fill: the one tag this
addon vendored without a bundle. No code, library or kit file moved because of it.

## Listing

```sh
horizon=$(ls -1 docs/revendor | sort | head -1 | cut -c1-10)    # 2026-10-14
# the audit's walk over libs/LibKa0s and tests/_kit, plus the CLAUDE.md commits that roll the line
# -> vendored.txt: v1.72.0 v1.75.0 v1.75.1 v1.75.2 v1.76.0 v1.77.0 v1.80.0 v1.81.0 v1.82.0 v1.83.0
#    v1.84.0 v1.85.0 v1.87.0 v1.88.0 v1.89.0 v1.90.0 v1.91.0 v1.92.0 v1.93.0 v1.95.0
grep -vxF -f recorded.txt vendored.txt
```

Output:

```
v1.95.0
```

v1.95.0 was vendored by `006e2e5` (DW-FP01: Re-vendor LibKa0s v1.95.0 (kit 54)), base v1.93.0, under the
WoW Forever port, whose run kept no revendor bundle.
