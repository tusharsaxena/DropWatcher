# 05 — Summary: the consolidated span v1.75.1 to v1.75.2

Written 2026-10-23 by `DW-RV`. A records-only back-fill: no code, library or kit file moved because
of it, and nothing was pushed. The span's previous base is v1.75.0.

## Per tag

- v1.75.1: carried by its own re-vendor commit (`a28a9ac`), SimPanel 3 delivered on the copy, nothing adopted
- v1.75.2: carried by its own re-vendor commit (`3414a82`), SimPanel 4 delivered on the copy, nothing adopted

Both re-vendors moved only `SimPanel.lua`. Neither tag offered a host-change candidate, so no
interview or issue was owed. The step-delay default change merged beside v1.75.2 (`25dc3ad`) is
this addon's own setting, not a library adoption.

## Checks

- Step 3h's "vendored minus recorded" listing, run after this folder and
  `docs/revendor/2026-10-23-v1.76.0/` were written: prints nothing.
