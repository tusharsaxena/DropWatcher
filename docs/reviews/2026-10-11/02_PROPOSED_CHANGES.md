# Proposed changes: Ka0s Drop Watcher v1 review (2026-10-11)

Standard resolved: **v2.78.3** (2026-10-10), read from the local `WowAddonStandards` checkout at
`c1f1cdc`. Every change below was checked against it as a guardrail. None introduces a new
deviation.

## HLD

### Theme A: the toast follows its drop and its switch (F-001, F-004)

A toast is a view of one feed record and of one setting. When either goes away, the toast goes
with it.

- **Removal sink, not an eleventh message.** `LootFeed` gets `LF.AddRemovalSink(fn)`, the shape the
  loot parser already uses for its own consumer (`NS.LootParser.AddSink`). It calls every sink with
  the feed's name after `LF.Clear` and after the cap trims. The toast registers one sink, and it
  prunes its queue and takes down a toast whose drop is gone.
  *Alternative rejected:* a new bus message (`DropsRemoved`). The bus has exactly ten messages
  today, and an eleventh fires documentation-§3's `docs/message-bus.md` trigger ("more than ten").
  That means a new Tier 2 doc and a hub spill, all to carry one notification with one consumer. The
  sink keeps the bus at ten and matches an existing seam.
  *Alternative rejected:* the toast re-checking its drop only when Ask is pressed. That fixes the
  button but leaves the stale toast on screen.
- **Dismiss goes through the host handler.** `NS.DismissDrop` already cancels the drop's auto-ask.
  It now also calls `NS.Toast.Forget(id)`, so a dismissed drop leaves the toast and its queue.
- **The switch has a reaction.** `toast.enabled` gets an `onChange` (`Toast.OnEnabledChanged`). Turned
  off, it empties the queue and takes the toast down. The profile reload calls
  `Toast.OnProfileReloaded`, which does the same when the incoming profile has toasts off. This
  mirrors what auto-ask already does in `AA.OnEnabledChanged` and `AA.OnProfileReloaded`.

### Theme B: an empty slot qualifies (F-002)

`Toast.Qualifies` passes the gain test when the verdict for you carries the `emptySlot` reason,
whatever `minGain` is. An upgrade with no gain and no `emptySlot` reason still fails, so the kernel's
other nil-gain cases are unchanged. `Toast.Compose` reads `empty` in place of `+0` for such a drop,
the same word the Me column uses (`modules/WindowCells.lua`, `verdictText`). Auto-ask inherits the fix
because it reuses the qualifier.

### Theme C: Pawn counts once it is initialized (F-003)

`Scoring.InUse` resolves with `NS.Compat.PawnIsReady()` alone, which is spec §5.4's "present only
when `PawnIsInitialized` is true". `Compat.PawnIsLoaded` then has no caller and is removed. A dead
export in Compat is a doc-count to keep honest (`docs/compat-layer.md`, the 62-shim count in
`docs/ARCHITECTURE.md`).
*Alternative rejected:* keeping "loaded" for an explicit `pawn` setting. The spec draws no such
line, and a scorer that answers `pending` forever is worse than no scorer.

### Theme D: auto-ask lets go of an encounter it cannot see end (F-005)

AutoAsk declares `PLAYER_ENTERING_WORLD` and `ZONE_CHANGED_NEW_AREA` rows, both shared events the
dispatcher already fans out. When either fires while `inEncounter` is set and the restriction tracker
no longer reports the `encounter` restriction (`NS.Restrictions.ActiveSet().encounter`), the module
treats the encounter as over: it clears the flag, stamps `endedAt` and re-arms the waiting asks, as
`ENCOUNTER_END` would. While the restriction still holds (a zone line crossed inside the fight), the
hold stays.
*Alternative rejected:* a timeout. No encounter length is safe to assume.

### Theme E: popups ask for slot 3 (F-006)

Both `StaticPopupDialogs` entries set `preferredIndex = 3`.

### Not changed

- **F-007** (the toast's degraded `×`) is kept. It is the only way to close a test-mode toast on an
  install missing LibKa0s, and it is reachable only there. It is recorded in the audit as a Low
  observation.

## Upstream change-set

None. No entry in this document targets `libs/` or `tests/_kit/`.

## LLD

| Change | Findings | Files | Sketch |
|---|---|---|---|
| C-01 | F-001 | `modules/LootFeed.lua` | `local removalSinks = {}`; `function LF.AddRemovalSink(fn)`; `notifyRemoved(name)` called at the end of `LF.Clear` and after the trim loop in `add` when it removed anything. Sinks run under `pcall`, because a sink's error must not stop the feed. |
| C-02 | F-001, F-004 | `modules/Toast.lua` | `Toast.Prune()` drops queued ids `NS.LootFeed.Get` no longer answers, and dismisses a shown toast whose drop is gone. `Toast.Forget(id)` drops one id from the queue and dismisses it if shown. `Toast.OnEnabledChanged(on)`: off empties the queue and dismisses; on pumps. `Toast.OnProfileReloaded()` does the same from the stored setting. `OnTestModeChanged(false)` becomes `Prune()`. `Toast.Ask` dismisses when its drop is gone. The header's lifecycle paragraph says what does each. |
| C-03 | F-001 | `core/DropWatcher.lua` | `NS.DismissDrop` adds `if NS.Toast then NS.Toast.Forget(dropID) end`; `reloadProfile` adds `if NS.Toast then NS.Toast.OnProfileReloaded() end`. |
| C-04 | F-004 | `settings/SchemaRows.lua` | `toast.enabled` gets `onChange = function(v) NS.Toast.OnEnabledChanged(v) end`. |
| C-05 | F-002 | `modules/Toast.lua` | In `Qualifies`, `local gain = num(me.ilvlDelta)`; if there is no gain and the reasons carry `emptySlot`, the gain test passes. `Compose` uses `L["empty"]` for that line. |
| C-06 | F-003 | `modules/Scoring.lua`, `core/Compat.lua` | `S.InUse` uses `NS.Compat.PawnIsReady()` alone; `Compat.PawnIsLoaded` is deleted. The header comment for `auto` says "initialized". |
| C-07 | F-005 | `modules/AutoAsk.lua` | Two `EVENTS` rows, `PLAYER_ENTERING_WORLD` and `ZONE_CHANGED_NEW_AREA`, both to `AA.OnWorldChanged`: `if inEncounter and not NS.Restrictions.ActiveSet().encounter then AA.OnEncounterEnd() end`. |
| C-08 | F-006 | `modules/WindowHistory.lua`, `settings/Schema.lua` | `preferredIndex = 3` in both popup tables. |
| C-09 | all | docs | `docs/ARCHITECTURE.md` (Event Subscriptions: the two AutoAsk rows; the toast's lifecycle under DropAdded's consumers; the shim count), `docs/compat-layer.md` (PawnIsLoaded gone), `docs/data-flow.md` (the toast and auto-ask section), `docs/module-map.md` (Toast and AutoAsk lines), `docs/smoke-tests.md` (TOAST-2 and ASK-9, owed), `docs/test-cases.md` regenerated, and the README tests badge. |

**Regression pressure.** C-02, C-05, C-06 and C-07 add cases to `tests/test_toast.lua`,
`tests/test_scoring.lua` and `tests/test_auto_ask.lua`, and they change two existing assertions:
the qualifier table row that pinned F-002, and the `InUse` case that pinned F-003. Those two
assertions encode the behavior the spec rules out. They are corrected in the same commit as the
code, with the spec section cited, and not weakened to make anything pass. `docs/test-cases.md` and
the README `[tests]` badge move in the same change as the count.

**Watch list.** No change here touches a function near CCN 15. `Toast.Qualifies` gains one
decision.

## Standards conformance (per change)

- C-01/C-02: the sink is a plain function registry, not an event or bus registration, so the
  stand-down census (`slash-commands-§7`) is unaffected. The toast's own stand-down already empties
  its queue. A removal while stood down only prunes an already empty queue.
- C-04: a row reaction is the standard's shared-reaction seam (options-ui-§1). No second write path
  is introduced.
- C-06: deleting a Compat shim lowers the `compat-layer.md` trigger count from 62 to 61, still far
  above three. The doc map row's number moves with it.
- C-07: both events join `NS.FEATURE_EVENTS`, so the stand-down unregisters them like every other
  row. `test_disabled`'s expected registration set already lists both event names, because
  Situations and Inspect declare them, so the set of names does not change.
- C-08: no standard rule. A precaution the collection already uses.
