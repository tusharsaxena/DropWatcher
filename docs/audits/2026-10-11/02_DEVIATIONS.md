# Deviations: Ka0s Drop Watcher (standards audit, 2026-10-11)

**Verdict: compliant, with minor observations.** No MUST fails in a way a user, their SavedVariables
or their session can reach.

**Tallies.** There are no `derived from` dependents, so the headline tally (roots only) and the total
including dependents are the same: **2** entries.

| Grade | Entries | Of which fail a MUST |
|---|---|---|
| High | 0 | 0 |
| Medium | 0 | 0 |
| Low | 1 | 0 |
| Info | 1 | 0 |

The four rows of `## Documented deviations` were checked first. Each is **accepted**, citing its own
rule and its Decided date (2026-10-10). None of the cited rules has changed since. None of the
re-check triggers has fired at v1.71.0: no LibKa0s major carries a chat sender, a tooltip line
reader, a loot-line parser or a restriction tracker, and no second Ka0s addon needs any of them. The
evidence the rows promise (a LibKa0s promotion issue and a WowAddonStandards proposal issue) is still
to be filed, which DRW-02 records.

## Entries

### DRW-01: the toast's degraded close is a typed glyph

- **Section:** standalone-windows (the chrome degrades to nothing), library-stack-§8 (no one-off marks).
- **Grade:** Low. It is reachable only on an install missing LibKa0s (DEGRADED-1), and it is cosmetic.
- **Description:** when `NS.MakeCloseButton` answers nil (the Core stub), `modules/Toast.lua:164-166`
  draws its own text button with `"×"`. Every other close control in the addon degrades to nothing.
  The close-button grep is otherwise clean: the toast's first call goes through the wrapper
  (`modules/Toast.lua:163`).
- **Fix direction:** none needed now. The fallback is the only way to close a test-mode toast, which
  has no countdown, on that install. If it is kept, record a register row naming the degraded path,
  or have the toast time out on the degraded path so the fallback can go. *No register row today, so
  this is open, not accepted.*

### DRW-02: the register's promised issues are not filed yet

- **Section:** audit-review-history (every evidence id a register row cites resolves).
- **Grade:** Info.
- **Description:** three of the four `## Documented deviations` rows say "A LibKa0s promotion issue is
  filed at the end of the v1 run", and the chat-sending row promises "A WowAddonStandards proposal
  issue". Plan item DW-63 files them, and the owner has held every GitHub write for this run, so the
  rows point at issues that do not exist yet.
- **Fix direction:** DW-63 files the issues. Each row's `Why` then names its issue number.

## Checked and compliant (not entries)

- **Line endings:** canonical body, 0 strays, gate wired (line-endings-§1..§7).
- **Packaging:** no unaccounted dot-entry, no false conditional line (packaging).
- **Generators:** none. `git ls-files '*.py' '*.sh'` lists the vendored runner and two plan helpers
  (`docs/superpowers/plans/2026-10-10-drop-watcher-v1/resume-state.sh` and
  `…/orchestration/checkpoint.sh`). The helpers read git state and write no tracked file, so they are
  not generators (layout-§1).
- **Over-cap census:** heading present, nothing over 1500, `test_layout_cap` wired from the kit
  (layout-§1).
- **Re-vendor bundles:** no `docs/revendor/` store yet. The addon has vendored one tag (v1.71.0) since
  its scaffold, and the convention is measured from the next re-vendor (audit-review-history).
- **Bus:** no literal message names at call sites; all ten tails are PascalCase (architecture-§4).
- **Event registration:** one `pcall`ed helper per event, with a recorded rejected list reachable
  through `[Init]` and diagnostics (events-frames-taint-§1).
- **TOC annotations:** every load-bearing line names what resolves (toc-file-§5).
- **`## IconTexture`:** the addon's own 128×128 uncompressed 32-bit TGA (toc-file-§1, layout-§4).
- **Disabled state:** one latch, two holds, a registration-set conformance suite, and the reserved
  verbs answering while disabled (slash-commands-§2, §7).
- **Launcher:** one object, the menu entries match `ADDONS.md`, label `Ka0s Drop Watcher`, no
  broker toggle, `debug` and `debugAtEnable` passed (launcher).
- **Diagnostics:** one `COMMANDS` row, no alias, live while disabled, README section present
  (debug-logging-§14).
- **Write paths:** one seam; the state written outside it is named with its owner and every writer
  (architecture-§5).
- **Shared media:** no private copy of a shipped asset under `media/` (library-stack-§8).
- **Vendoring:** whole folder at the provenance tag; the kit sits under `tests/_kit/` (library-stack-§7).
- **Complexity:** sighted kit (revision 38), `blindFiles` 0, max CCN 13. One watch-list entry
  (`core/Compat.lua` in the 1000–1500 band), "accepted (DW-61)", on its first run, well short of the
  three-run rule (anti-pattern #53).
- **Docs shape:** Tier 1 complete; Tier 2 answered against the code; every `.md` under `docs/`
  registered once; hub 332 lines with no section over 60 (documentation-§3).
