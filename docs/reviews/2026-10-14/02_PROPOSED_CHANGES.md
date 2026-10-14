# Proposed changes: Ka0s Drop Watcher review (2026-10-14)

Derived from `01_FINDINGS.md`. **Standard resolved:** Ka0s WoW Addon Standard v2.80.0 (2026-10-13),
fetched from `raw.githubusercontent.com/tusharsaxena/WowAddonStandards/master`. Sections that had not
arrived yet were read from the local checkout at `8aad69d`, which is the same version. No entry below
targets `libs/` or `tests/_kit/`.

## HLD

### Theme A: Make the disabled-state conformance test able to fail (F-001, upstream F-009 and F-011)

- **Rationale.** The suite is the standard's proof that disable is total (slash-commands-§7). One of
  its eight cases fires nothing (probe P1). The shipped code is inert (probe P2), so the fix is all
  in the test plus the kit underneath it.
- **Approach.** Drive every declared `NS.FEATURE_EVENTS` row after the disable. Assert that the
  number of rows reached equals the number declared. Assert zero SavedVariables writes, zero printer
  calls and no newly shown frame. Name the mutation that turns it red.
- **Once kit F-009 lands and is re-vendored,** switch the delivery to `m.__fireUnconditional` over
  `R_on` and assert each return is at least 1. That is the literal form of slash-commands-§7 step 6.
- **Alternative rejected: delete the case.** It would leave step 6 uncovered (testing-§12: an absent
  test is better than a vacuous one, but the step is a MUST).
- **Alternative rejected: patch `tests/_kit/mock_record.lua` here.** That is a vendored path
  (testing-§1, library-stack-§5).

### Theme B: One announce rule on every path (F-002)

- **Rationale.** The send path and the queue-cancel path disagree about whether an announce needs a
  group.
- **Approach.** `A.AnnounceChannel()` answers a fixed channel only when the player is in a group that
  has it. Otherwise it answers nil, which `send` already turns into the `noChannel` refusal and its
  existing chat line.
- **Alternative rejected: fall back to the automatic pick.** It would post to a channel the player
  explicitly did not choose.

### Theme C: Isolate the shared dispatcher (F-003)

- **Rationale.** This is the same isolation the addon already gives `Sim.Fire` and the parser's
  sinks, applied to the client path.
- **Approach.** Call each handler under `pcall`, run them all, then re-raise the first error with
  `error(err, 0)` after the loop. The client's error reporting still sees it, and the headless suite
  still fails on it.
- **Alternative rejected: swallow and log under a debug tag.** An error has to stay visible
  (debug-logging: a hidden failure is the worse defect).
- **Alternative rejected: `geterrorhandler()`.** It needs a new lint global and mock, and the
  re-raise gives the same visibility.

### Theme D: Perf nesting that the record can confirm (F-004, upstream F-010)

- **Approach.** Declare `within = "feed.add"` on `evaluate` and `quality.gate`. Pass the observed
  parent at both call sites: `"feed.add"` while `LF.Receive` is on the stack, and `false` (top level,
  F-010's additive) otherwise.
- **Ordering.** This depends on the LibKa0s release that carries F-010. Until it ships, Perf minor 14
  would store `false` itself as the observed parent (its check is `parentKey ~= nil`), which is a
  false claim in the record. **Do not land C-04 before the re-vendor.**
- **Alternative rejected: split each bucket into `feed.evaluate` and `evaluate`.** That doubles the
  report rows and still needs a declaration. performance-§3 says to correct the parent, not to
  restructure around it.

### Theme E: Seam and lint hygiene (F-006)

- **Approach.** Add `Compat.IsAddOnLoaded`, and have both probes call it. Fence the world reads into
  a `files["core/Compat*.lua"]` stanza. compat-§1 *Fencing (MAY)* allows the family pattern and
  forbids reaching any file outside the family.

### Theme F: Text and naming (F-005, F-007, F-008)

- **F-005.** Fill in `locales/enUS.lua` so it is the complete catalog, and add a gate case so it
  stays complete.
- **F-007.** Move the stranded doc block.
- **F-008.** Route every disabled refusal through the dispatcher's one line, or the brand.

### Upstream change-set (separate repos; nothing here edits `libs/` or `tests/_kit/`)

| ID | Repo / file | Fix | Version | Consumer step |
|---|---|---|---|---|
| U-1 (F-009) | `LibKa0s` `testkit/mock_record.lua` `__fireUnconditional` | Keep `__everHandlers[event]` per target, written on every register and never cleared on unregister. Reach a handler through it after the existing lookups. Raise `"__fireUnconditional: nothing registered <event> on this target"` instead of returning 0 when nothing is reachable. Add kit self-tests for a method-named handler and for the raise | `Kit.VERSION` 38 → 39; LibKa0s minor release | Re-vendor `tests/_kit/` (whole folder) as its own commit, in this addon and every consumer |
| U-2 (F-010) | `LibKa0s` `LibKa0s/Perf.lua` `P.Note` and the nesting note | Accept `parentKey == false` as "observed at top level": store it as the sentinel `"(top)"` and feed it to `observedMixed`, so the report reads `observed inside feed.add and at top level`. Additive: nil keeps today's meaning | Perf file minor 14 → 15; LibKa0s minor release | Re-vendor `libs/LibKa0s/` (whole folder) as its own commit, then C-04 |
| U-3 (F-011) | `WowAddonStandards` `standards/standards/slash-commands.md` §7 step 6 (and `AUDIT.md` if it restates the step) | Add: "each unconditional fire **MUST** be shown to reach at least one handler (assert `__fireUnconditional`'s return); the assertion **SHOULD** carry a `-- red under:` line (testing-§12)" | Standard minor bump, with the date and version line at the top of `STANDARDS.md` | None beyond C-01 |
| U-4 (F-012) | `dev-copilot` `profiles/wow/agent-review.md` class-1 census (`:363`) | Add a second pass that reads `NS.SLASH` / `NS.SLASH_ALIAS` literals from each addon's TOC-loaded files (`grep -hoE 'NS\.SLASH(_ALIAS)? *= *"/[a-z]+"'`), merged into the roots file before `uniq -d`. Document why | Plugin patch release | None |

## LLD

**C-01 (F-001): `tests/test_disabled.lua` "disabled 3"**

Replace the case body. It keeps its name, so the pass count does not move.

```lua
test("disabled 3: no SavedVariables write, line or frame from any declared handler while disabled", function()
    -- red under: add `NS.addon.db.profile.locked = true` to DW.OnCombatStart (core/DropWatcher.lua)
    local NS, _, m = T.enableAddon()
    NS.addon:OnSlashCommand("disable")
    m.__resetSvWrites(); m.prints = {}
    local shown = #m.__shownFrames()
    local reached = 0
    for _, row in ipairs(NS.FEATURE_EVENTS) do
        local fn = NS.addon[row[2]]
        assertTrue(type(fn) == "function", row[2] .. " is declared but missing")
        fn(NS.addon, row[1]); reached = reached + 1
    end
    assertEqual(reached, #NS.FEATURE_EVENTS, "every declared row was driven")
    assertEqual(#m.__svWrites(), 0, "no SavedVariables write")
    assertEqual(#m.prints, 0, "no printed line")
    assertEqual(#m.__shownFrames(), shown, "no frame shown")
end)
```

- **Risk.** A handler that raises with no event arguments would turn the case red. Probe P2 shows
  none does today.
- **After U-1 is re-vendored.** Add the `__fireUnconditional` loop over `R_on` with
  `assertTrue(m.__fireUnconditional(NS.addon, ev) >= 1, ev)`. Same case, so the count still does not
  move.
- The renamed case title changes one `docs/test-cases.md` row. Regenerate it with `--list` in the
  same commit.

**C-02 (F-002): `modules/Asks.lua` `A.AnnounceChannel`, plus the header at `:25-28`**

```lua
-- A fixed channel is used only where the player has it; else nil (noChannel), as outside a group.
local HAS = {
    INSTANCE_CHAT = function(C) return C.InGroup(C.InstanceGroupCategory()) end,
    RAID          = function(C) return C.InRaid() end,
    PARTY         = function(C) return C.InGroup() end,
}
function A.AnnounceChannel()
    local want, Compat = A.Settings().announceChannel, NS.Compat
    if want ~= "auto" then return HAS[want](Compat) and want or nil end
    ...  -- automatic pick unchanged
end
```

- `HAS` is a file-scope upvalue, not built per call (anti-pattern #52 does not apply).
- **Tests (`tests/test_asks.lua`), +3 cases.**
  - Solo with `PARTY`: refused `noChannel`, nothing sent, the state is not `sent`.
  - A party (not a raid) with `RAID`: refused.
  - An instance group with `INSTANCE_CHAT`: sent.
- Move `docs/test-cases.md` and the README badge (`1402` → `1405`) in the same commit.
- Update `docs/data-flow.md`'s sends section if it states the channel rule.

**C-03 (F-003): `core/DropWatcher.lua` `DW:OnSharedFeatureEvent`**

```lua
function DW:OnSharedFeatureEvent(event, ...)
    local first
    for _, method in ipairs(sharedHandlers[event] or {}) do
        local ok, err = pcall(self[method], self, event, ...)
        if not ok then
            first = first or err
            NS.Debug("Init", "%s: %s raised: %s", event, method, tostring(err))
        end
    end
    if first then error(first, 0) end   -- reported once, after every handler ran
end
```

- **Risk.** `pcall` loses the error's traceback. The debug line names the method, so the trace can
  be recovered.
- **Test (`tests/test_setup.lua`, +1 case).** Replace `NS.addon.OnSituationEvent` with a raiser for
  the duration of the case. Fire `GROUP_ROSTER_UPDATE` through the mock and assert three things:
  `NS.addon.OnRosterEvent` still ran (the roster refreshed), the fire raised the raiser's message,
  and restoring the method restores normal dispatch.
  - `-- red under: revert to the bare loop`.
- Badge and inventory +1 in the same commit.

**C-04 (F-004): `core/PerfSetup.lua` and `modules/LootFeed.lua`. Blocked on U-2.**

```lua
{ key = "evaluate",     within = "feed.add" },
{ key = "quality.gate", within = "feed.add" },
```

```lua
local receiving = false            -- true while LF.Receive is on the stack
function LF.Receive(r)
    local t0 = Perf.on and debugprofilestop()
    receiving = true
    local id, status = receive(r)
    receiving = false
    if t0 then Perf.Note("feed.add", debugprofilestop() - t0) end
    return id, status
end
-- at :225 and :266
if t0 then Perf.Note("evaluate", debugprofilestop() - t0, receiving and "feed.add" or false) end
```

- **Bracket hygiene (performance-§2).** It is one boolean upvalue write and read, with no allocation
  or call while capture is off.
- **Check.** `refreshCaptureOff` / `parseCaptureOff` in `tests/perf.lua` should not move, and the
  pairs must still match.
- **Risk.** If `receive` raises, `receiving` stays true. Wrap it as
  `local ok, id, status = pcall(receive, r); receiving = false; if not ok then error(id, 0) end`.
  The alternative is to accept the risk, since `receive` has no known raise. Prefer the `pcall`.
- **Test (`tests/test_setup.lua`, +1 case).** With capture on, `LF.Receive` a drop and an inspect
  re-judge, then read the record: `evaluate` is observed mixed (inside `feed.add` and at top level).
  Badge +1.

**C-05 (F-005): `locales/enUS.lua`, plus a new gate suite `tests/test_locale.lua`**

- **Catalog.** Add the 722 missing keys, grouped under one comment heading per source file, in the
  file's existing shape: `L["x"] = "x"`, with long keys wrapped as today.
- **Gate case.** Add `tests/test_locale.lua` with one case. It walks the TOC-derived load list
  (`Loader.tocFiles`, testing-§9), collects every `L["…"]` literal and asserts each has an `enUS`
  entry. Its failure names the file:line.
  - `-- red under: delete any one entry from locales/enUS.lua`.
- localization-§3 already forbids keys nothing reads, and this gate makes the reverse direction
  checkable too.
- Badge and inventory +1. Add the suite to `tests/run.lua`'s suite list.

**C-06 (F-006): `core/CompatWorld.lua`, `core/DropWatcher.lua:523-527`, `modules/Diagnostics.lua:366`, `.luacheckrc`**

- **`Compat.IsAddOnLoaded(name)`.** Add it to `core/CompatWorld.lua`, so it is wrapped by
  `core/SimSeam.lua` like every member, which loads after it. It answers
  `C_AddOns and C_AddOns.IsAddOnLoaded and C_AddOns.IsAddOnLoaded(name) == true`.
- **The two probes** call `NS.Compat.IsAddOnLoaded`. Also have `logDependencies` and Diagnostics share
  one `NS.Compat` read, rather than each holding a local copy.
- **`.luacheckrc`.** Move `GetInstanceInfo`, `GetDifficultyInfo`, `IsInInstance`, `IsInGroup`,
  `IsInRaid`, `C_ChallengeMode`, `GetNumGroupMembers`, `UnitGUID`, `UnitName`, `UnitClass`,
  `UnitIsConnected`, `UNKNOWNOBJECT`, `LE_PARTY_CATEGORY_INSTANCE` and `UnitAffectingCombat` from the
  top-level `read_globals` into a `files["core/Compat*.lua"]` stanza (compat-§1 Fencing).
  - Keep `InCombatLockdown`, `C_AddOns` and `C_Item` at the top level only where `luacheck .`
    proves a non-family file needs them: the Env and Item degradation stubs read `C_AddOns` and
    `C_Item`.
  - Before committing, `luacheck .` must stay 0/0.
- **Test (`tests/test_compat.lua`, +1 case).** `IsAddOnLoaded` answers true or false from the mock's
  `C_AddOns` and false without it. Badge +1.

**C-07 (F-007): `core/DropWatcher.lua:107-111`**

Move the five-line `--- Turn test mode on or off …` block, with its `@param` / `@return`, to sit
directly above `function NS.SetTestMode(on)`. Comment only.

**C-08 (F-008): `core/DropWatcher.lua` `NS.PressAsk`, `NS.PressOffer`, `NS.PressAnnounce`; `modules/TradeHelper.lua:31`; `modules/DetailCard.lua:60` and `:66`**

- **Chat refusals.** When `reason == "disabled"`, print `NS.SlashCommands:DisabledLine()` in place of
  `Not asked: The addon is disabled.`. Remove `ASK_REFUSAL.disabled`.
- **Tooltip and reason fragments.** `L["%s is disabled."]:format(NS.BRAND)` for the trade tooltip,
  and `L["%s is disabled"]:format(NS.BRAND)` in the detail card's reason sentence. Retire the three
  old keys and add the two new ones to `enUS.lua` (localization-§3: no dead keys).
- **Test (`tests/test_disabled.lua`, +1 case).** While disabled, `NS.PressAsk(id)` prints exactly the
  dispatcher's line.
  - `-- red under: restore ASK_REFUSAL.disabled`.
  - Badge +1.

## Count and badge movement

- **This repo (C-01 .. C-08):** C-02 +3, C-03 +1, C-04 +1, C-05 +1, C-06 +1, C-08 +1, so **+8**:
  `1402` → `1410`. C-01 renames one case without changing the count.
- **Each commit moves `docs/test-cases.md` and the README badge with it** (testing-§5).
- **The re-vendor commit for U-1** may add kit self-cases that this repo's runner lists. Its own
  `--list` regeneration says how many.

## Watch-list note for the next release

None of these changes is expected to push a function past CCN 15. `DW:OnSharedFeatureEvent` gains two
decisions (from about 2 to about 4). The next release's regeneration confirms it. Do not regenerate
the record here.

## Standards conformance

| Change | Conformance |
|---|---|
| C-01 | slash-commands-§7 step 6 and testing-§12 (`red under`). Touches no vendored file |
| C-02 | Introduces no new channel. Never SAY or YELL (the documented deviation row for addon-sent chat is unchanged) |
| C-03 | The error stays visible (re-raised). No new global. events-frames-taint registration helpers are untouched |
| C-04 | performance-§3 (`within` declared and observed). performance-§2 gate shape kept. Lands only after the U-2 re-vendor (library-stack-§5: never patch `libs/`) |
| C-05 | localization-§1/§3 (the English string is the key; no dead keys). testing-§9 (TOC-derived list) |
| C-06 | compat-§1 Fencing (MAY) via the family pattern. lint (no top-level blanket ignore) |
| C-07 | Comment only |
| C-08 | slash-commands-§7 (one refusal string from the dispatcher). architecture NS.BRAND rule (no hard-coded brand) |
