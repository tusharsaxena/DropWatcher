# Proposed changes — Ka0s Drop Watcher (2026-11-28, second pass)

Standard resolved: **Ka0s WoW Addon Standard v2.122.0 (2026-11-28)**, network fetch of
`raw.githubusercontent.com/tusharsaxena/WowAddonStandards/master` (the index and its 32 section files).
The sibling checkout `../WowAddonStandards` at `b83f039` (v2.122.2) is ahead of `origin/master`
`1647801`, so it was not used. Re-check the two sections cited below against v2.122.2 once it is
pushed.

## HLD

### Theme A: one combat-end edge, no stray timers (F-001)

The skin notice and the first-run picker are one start, and both wait out combat. The picker already
waits on the `PLAYER_REGEN_ENABLED` edge (`pickerHeld`, consumed by `NS.SkinPickerCombatEnd`). The
notice polls every 5 s with an uncancelable `C_Timer.After`. The proposal moves the notice onto the
same edge: a `noticeHeld` flag that `NS.SkinPickerCombatEnd` consumes and `NS.HideSkinPicker` (which
the stand-down and every profile event already call) clears.

- **Rationale:** slash-commands-§7 (*"Every timer, ticker and `OnUpdate` is canceled"*), and the
  library's own contract for `O.SkinNotice` (*"the host asks again after it … No timer"*).
- **Rejected:** keeping the poll and storing its handle as a `C_Timer.NewTimer` to cancel at the
  stand-down. That still polls through a whole boss fight, and the combat edge already exists.
- **Trade-off:** none in behavior. The notice shows at combat end rather than up to 5 s after it.

### Theme B: the golden suite keeps Drop Watcher's half (F-002)

testing-§8: an addon on a shared library keeps an **integration** suite over its own wiring, not a copy
of the library's cases. The `golden me:` half is that integration (Drop Watcher's reads, feed and
gear). The `golden kernel:` half runs the library's own fixture through Drop Watcher's thin views.

- **Proposed (owner to rule):** drop the 48 kernel cases and the fixture's `cases` table, and keep the
  16 `golden me:` cases. Add, or point to, a few targeted view cases that pin what the views add: the
  client named (`withClient`) and the off-spec gate (`gated`). These are the only behaviors the kernel
  half covered that are Drop Watcher's.
- **Alternative (also compliant):** keep the fixture and add a kit vendor-sync style pin that the
  `cases` table equals the tag's. This keeps the duplicate, so it is a documented deviation
  (`docs/ARCHITECTURE.md` → `## Documented deviations`, Rule `testing-§8`). It is not recommended.
- **Rejected:** editing either fixture to make them agree. That edits one side of a duplicate, which
  the rule forbids.

### Theme C: re-raise with the stack (F-003)

Replace `pcall` + `error(err, 0)` with `xpcall` and a handler that appends `debugstack()` (or
`debug.traceback` in the headless kit) before the clean-up re-raises. The seven sites share the shape,
so a single local helper in `core/CoreSetup.lua` (`NS.Rethrowable(fn, ...)` → `ok, errWithStack`) is
justified: seven consumers, one meaning, and no per-site flags (anti-pattern #55 does not apply).

### Theme D: every refusal has words (F-004)

Add `collectible` and `badRequest` to the refusal tables, reusing the existing words
(`NS.CollectCells.NO_ASK` / `NO_OFFER`'s locale keys). Replace the `tostring(reason)` fallback with one
localized line that names the key in the debug log only. Make `A.Preview` refuse `collectible` as
`A.Request` does.

## Upstream change-set

| Finding | Repo | File | Change | Minor bump | Consumer re-vendor |
|---|---|---|---|---|---|
| F-005 | LibKa0s | `LibKa0s/DebugLogDiagnostics.lua` on the Feed branch (`feat/2026-11-27-feed`) | Take `DIAG_MINOR = 14` on top of v1.120.0's minor 13 (Verdict), with both Verdict and Feed in the running-majors list; release as the next version (v1.121.0) | `DIAG_MINOR` 13 → 14 | LootHistory re-vendors the release whole, as its own commit. Drop Watcher needs nothing until it next re-vendors |

No entry in this document targets a path under `libs/` or `tests/_kit/` in Drop Watcher.

## LLD

### C-001 (F-001): the notice waits on the combat edge

`core/SkinSetup.lua`, the notice section (`:592`–`:628`) and `NS.SkinPickerCombatEnd` (`:657`).

```lua
-- before
local NOTICE_RETRY = 5
local noticeWaiting = false
...
if why == "combat" and not noticeWaiting and type(_G.C_Timer) == "table" and _G.C_Timer.After then
    noticeWaiting = true
    _G.C_Timer.After(NOTICE_RETRY, function() noticeWaiting = false; NS.MaybeShowSkinNotice() end)
end

-- after
local noticeHeld = false   -- a notice refused in combat waits for the PLAYER_REGEN_ENABLED edge
...
noticeHeld = (why == "combat")
...
function NS.SkinPickerCombatEnd()
    if not (pickerHeld or noticeHeld) then return nil end
    pickerHeld, noticeHeld = false, false
    return NS.MaybeShowSkinPicker()   -- asks the notice first, then the picker
end
-- NS.HideSkinPicker also sets noticeHeld = false (the stand-down and every profile event run it).
```

- **Risk:** `NS.SkinPickerCombatEnd` is a `PLAYER_REGEN_ENABLED` feature-event handler, so it is down
  while stood down. That is the point: no ask happens while disabled. The fuse and the stand-up re-ask
  on the way back (`NS.ArmSkinPicker(true)` in `NS.StandUp`).
- **Tests (new cases; the count moves):** in `tests/test_skin_picker.lua`:
  (1) a notice refused in combat shows at `PLAYER_REGEN_ENABLED` and arms no timer (assert the mock's
  `C_Timer.After` count is unchanged; `-- red under: restore the NOTICE_RETRY poll`);
  (2) refused in combat, then `/dw disable`, then combat ends: nothing shows and `db.global.skinNotice`
  is unchanged (`-- red under: drop noticeHeld = false from NS.HideSkinPicker`).
  `docs/test-cases.md` and the README `[tests]` badge move in the same commit.
- **Standards:** slash-commands-§7. No new deviation.

### C-002 (F-002): the golden suite's kernel half (owner ruling first)

`tests/test_verdict_golden.lua` (`:57`–`:156`, the kernel half) and `tests/fixtures/verdict_golden.lua`
(its `cases` table). With the recommended ruling: delete the kernel loop and the `cases` table, and keep
`me`. Add 2–4 view cases to `tests/test_verdict_setup.lua`: `NS.Evaluate.Evaluate` names the client in
force, and on a profile where `C.FEATURE.offSpec` is false a candidate's `offSpecGear` never reaches the
kernel (the view-level `gated`).

- **Count:** −48 + n. The pass count drops on both profiles. `docs/test-cases.md` and the README badge
  move in the same commit.
- **Risk:** the kernel half was the Item Search split's move-time cross-check, and the move is done and
  tagged. The library's golden suite keeps the same table.
- **Standards:** testing-§8. With the alternative instead, the `## Documented deviations` row is
  mandatory (CLAUDE.md, *Standards compliance*).

### C-003 (F-003): re-raise with the stack

New `NS.Rethrowable` in `core/CoreSetup.lua`, which is loaded before every site:

```lua
local function withStack(err)
    local stack = (debugstack and debugstack(2)) or (debug and debug.traceback and debug.traceback("", 2)) or ""
    return tostring(err) .. "\n" .. stack
end
--- xpcall(fn, ...) with the stack kept in the error. Answers ok, ... | false, errWithStack.
function NS.Rethrowable(fn, ...) return xpcall(fn, withStack, ...) end
```

Lua 5.1's `xpcall` takes no varargs, so wrap with a closure (`xpcall(function() return fn(unpack(args, 1, n)) end, withStack)`).
Each site switches `pcall(` → `NS.Rethrowable(` and keeps `error(err, 0)`. Do not touch the secret
guard `NS.SafeToString(err)` in the debug line (`core/DropWatcher.lua:74`).

- **Risk:** `debugstack` is a client global that no authored file calls today. The kit's missing-globals
  gate (`test_client_globals`) judges it per client. It exists on both, so no allowlist should be needed.
  If the gate does flag it, the allowlist is `tests/client_globals_allow.lua`, which this addon does not
  carry yet. The test asserting
  `OnSharedFeatureEvent` (`tests/test_setup.lua:62`) asserts the message; extend it to assert the
  handler's name appears in the re-raised text.
- **Standards:** debug-logging is not touched, and no new deviation.

### C-004 (F-004): words for every refusal

`core/DropWatcher.lua` `ASK_REFUSAL` (`:315`) gains
`collectible = NS.L["Collectibles are judged for you alone."]` (the key already exists at `:457`) and
`badRequest = NS.L["That request could not be made."]`, a new key in `locales/enUS.lua`. The three
fallbacks (`:371`, `:431`, `:507`) become `NS.L["it could not be sent."]`, with the raw key going to
`NS.Debug("MSG", …)`. `modules/Asks.lua` `A.Preview` adds
`if NS.Collectibles.IsFeedOnly(rec) then return nil, "collectible" end` after the ML check.

- **Tests:** a case that `NS.PressAsk` on a feed-only test drop prints the worded line
  (`-- red under: remove collectible from ASK_REFUSAL`), and a `A.Preview` refusal case. The count moves
  by 2.
- **Standards:** localization (every user-facing string through `L`). No new deviation.

## Expected watch-list movement (for the next release's regeneration to confirm)

None of C-001..C-004 should raise any function above CCN 15. `NS.MaybeShowSkinNotice` loses one
branch.
