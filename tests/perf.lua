#!/usr/bin/env lua
-- tests/perf.lua — the offline performance scenarios (performance-§9).
--
--   lua tests/perf.lua [--out <path>] [--label <text>]
--
-- OUTSIDE THE GREEN GATE: `lua tests/run.lua` never runs it, and no commit depends on it. It asserts
-- only deterministic quantities, bytes allocated per iteration and bracket notes, each measured loop
-- isolated by a full collect on either side with the collector stopped inside it. Timings are
-- printed for orientation only: compare scenarios within a run, never across runs or machines.
--
-- The scenarios grow with the hot paths: the window's repaint (the scaffold) and the loot parser's
-- line (DW-25). The questions are performance-§9's: does each bracket cost nothing with capture off
-- (zero overhead), and is the stood-down show decision free.
--
-- CEILINGS (measured 2026-10-10, Lua 5.1.5). Pinned hard at 0 bytes: the stood-down early return
-- must allocate nothing. Raise one only by re-measuring and saying why; a rise is the finding.

-- The parse pair (measured 2026-10-11 at 664 bytes in both) allocates its captures, the loot record
-- and the roster lookup's lowercased name; its ceiling is that work, and the pair being equal is the
-- zero-overhead evidence.
-- The refresh pair was pinned at 0 when the scaffold's Refresh painted nothing. Re-measured
-- 2026-10-11 (DW-61) at 13456 bytes in both: the shown window's whole pass now does real work (the
-- tab labels' and the footer's formatted strings, the filter bar's labels, the tab's context and
-- its row predicate's closures, the Group drops table's empty state), coalesced to at most one pass
-- a frame. Its ceiling is that work; the zero-overhead evidence is PAIRED below: capture off may
-- allocate nothing over capture on, and capture on no more than one note's PAIR_SLACK over off.
local BYTE_CEILING = { refreshCaptureOff = 14000, refreshCaptureOn = 14000, showDecisionStoodDown = 0,
    parseCaptureOff = 700, parseCaptureOn = 700 }
-- Each bracketed path measured off and on: [off] = on. The bracket with capture off is one upvalue
-- read and one boolean test, so the off run allocates no more than the on run; the on run adds at
-- most PAIR_SLACK bytes (the note itself) per iteration. PAIR_NOISE absorbs the two loops'
-- incidental spread (a fraction of a byte per iteration, measured), nothing more.
local PAIRS = { refreshCaptureOff = "refreshCaptureOn", parseCaptureOff = "parseCaptureOn" }
local PAIR_SLACK = 64
local PAIR_NOISE = 1
local NOTES_PER_ITER = { refreshCaptureOff = 0, refreshCaptureOn = 1, showDecisionStoodDown = 0,
    parseCaptureOff = 0, parseCaptureOn = 1 }

local N = 1000
local USAGE = "usage: lua tests/perf.lua [--out <path>] [--label <text>]\n"

local opts = { out = nil, label = "offline" }
do
    local i = 1
    while arg and arg[i] do
        local a = arg[i]
        if a == "--out" and arg[i + 1] then opts.out = arg[i + 1]; i = i + 2
        elseif a == "--label" and arg[i + 1] then opts.label = arg[i + 1]; i = i + 2
        else
            io.stderr:write("unknown argument: " .. tostring(a) .. "\n")
            io.stderr:write(USAGE)
            os.exit(2)
        end
    end
end

-- ── environment ─────────────────────────────────────────────────────────────────────────────

local mockf = dofile("tests/wow_mock.lua")
local loadAddon = dofile("tests/loader.lua")(".", mockf)
local NS, mock = loadAddon()
NS.addon:OnInitialize()
NS.addon:OnEnable()

local failures = {}
local function check(ok, msg) if not ok then failures[#failures + 1] = msg end end

check(NS.Perf.BuildRecord ~= nil, "NS.Perf is the degradation stub: every scenario would measure a stub")

-- Count the bracket's notes without allocating: a counter, not a list.
local notes = 0
local realNote = NS.Perf.Note
NS.Perf.Note = function(key, ms, parent)
    notes = notes + 1
    return realNote(key, ms, parent)
end

local results = {}

--- Run `fn` n times after a warm-up, the collector stopped inside the loop.
local function measure(name, n, fn)
    for _ = 1, 50 do fn() end
    notes = 0
    collectgarbage("collect"); collectgarbage("collect")
    collectgarbage("stop")
    local before = collectgarbage("count")
    local t0 = os.clock()
    for _ = 1, n do fn() end
    local t1 = os.clock()
    local after = collectgarbage("count")
    collectgarbage("restart")
    local r = {
        name = name, iterations = n, totalMs = (t1 - t0) * 1000, msPerIter = (t1 - t0) * 1000 / n,
        notesPerIter = notes / n, bytesPerIter = math.max(0, (after - before) * 1024 / n),
    }
    results[#results + 1] = r
    return r
end

-- ── scenarios ───────────────────────────────────────────────────────────────────────────────

NS.ShowWindow()
check(NS.IsWindowShown(), "the window did not open")

-- Zero overhead (performance-§2/§9): with capture off, the bracketed repaint notes nothing and
-- allocates nothing.
NS.Perf.on = false
measure("refreshCaptureOff", N, NS.Window.Refresh)

-- With capture on, one note per pass and the bracket's own cost only.
NS.Perf.on = true
measure("refreshCaptureOn", N, NS.Window.Refresh)
NS.Perf.on = false

-- The stood-down show decision: step 0 of the ladder returns before any work.
NS.Lifecycle:Hold(NS.HOLD_PERF)
measure("showDecisionStoodDown", N, NS.Window.UpdateVisibility)
NS.Lifecycle:Release(NS.HOLD_PERF)

-- The loot parser on a third-person line (the common case in a group): the bracket notes nothing
-- with capture off and once with it on; the bytes are the parse's own (its captures and the loot
-- record), the same in both, so the bracket adds none.
local LOOT_LINE = "Brakk receives loot: |cnIQ4:|Hitem:2001::::::::90:::::|h[Band]|h|r."
mock.setGroup({ { guid = "Player-1-0000000A", name = "Brakk", class = "Warrior", classFile = "WARRIOR" } })
NS.Roster.Refresh("perf")
local function parseOnce() NS.LootParser.Parse(LOOT_LINE) end
NS.Perf.on = false
measure("parseCaptureOff", N, parseOnce)
NS.Perf.on = true
measure("parseCaptureOn", N, parseOnce)
NS.Perf.on = false
NS.Perf.Note = realNote

for _, r in ipairs(results) do
    local ceiling = BYTE_CEILING[r.name]
    check(ceiling ~= nil and r.bytesPerIter <= ceiling,
        ("%s allocated %.1f bytes/iter, over its %s-byte ceiling"):format(r.name, r.bytesPerIter, tostring(ceiling)))
    local want = NOTES_PER_ITER[r.name]
    check(want ~= nil and math.abs(r.notesPerIter - want) < 1e-9,
        ("%s noted %.2f times/iter, pinned at %s"):format(r.name, r.notesPerIter, tostring(want)))
end

local byName = {}
for _, r in ipairs(results) do byName[r.name] = r end
for offName, onName in pairs(PAIRS) do
    local off, on = byName[offName], byName[onName]
    check(off ~= nil and on ~= nil, ("the pair %s / %s was not measured"):format(offName, onName))
    if off and on then
        check(off.bytesPerIter <= on.bytesPerIter + PAIR_NOISE,
            ("%s allocated %.1f bytes/iter, more than %s's %.1f: the off bracket is not free"):format(
                offName, off.bytesPerIter, onName, on.bytesPerIter))
        check(on.bytesPerIter <= off.bytesPerIter + PAIR_SLACK,
            ("%s allocated %.1f bytes/iter, over %s's %.1f by more than %d"):format(
                onName, on.bytesPerIter, offName, off.bytesPerIter, PAIR_SLACK))
    end
end

-- ── report ──────────────────────────────────────────────────────────────────────────────────

print(("Ka0s Drop Watcher \226\128\148 offline perf  (v%s, label '%s')"):format(tostring(NS.version), opts.label))
print()
-- Five columns, exactly: tests/_kit/run-automated-tests.sh counts scenarios structurally as the
-- five-field rows under this header.
print(("%-24s %8s %11s %10s %11s"):format("scenario", "iters", "ms/iter", "notes/iter", "bytes/iter"))
for _, r in ipairs(results) do
    print(("%-24s %8d %11.5f %10.2f %11.1f"):format(
        r.name, r.iterations, r.msPerIter, r.notesPerIter, r.bytesPerIter))
end
print()
print("timings are for orientation only \226\128\148 compare scenarios within a run, never across machines")
if #failures > 0 then
    print()
    print(("%d assertion%s FAILED:"):format(#failures, #failures == 1 and "" or "s"))
    for _, f in ipairs(failures) do print("  - " .. f) end
end

-- ── the record ──────────────────────────────────────────────────────────────────────────────

local function writeRecord(path)
    local buckets = {}
    for _, r in ipairs(results) do
        buckets[r.name] = { calls = r.iterations, totalMs = r.totalMs, maxMs = r.msPerIter,
                            notesPerIter = r.notesPerIter, bytesPerIter = r.bytesPerIter }
    end
    local fh, err = io.open(path, "w")
    if not fh then
        io.stderr:write("cannot write " .. path .. ": " .. tostring(err) .. "\n")
        os.exit(2)
    end
    fh:write(NS.Perf.EncodeJSON({
        schema = 1, addon = "DropWatcher", source = "offline",
        version = tostring(NS.version), interface = 0, timestamp = os.time(),
        label = opts.label, buckets = buckets, failures = failures,
    }), "\n")
    fh:close()
    print("wrote " .. path)
end

if opts.out then writeRecord(opts.out) end
assert(mock ~= nil)

os.exit(#failures == 0 and 0 or 1)
