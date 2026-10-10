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
-- The scenarios grow with the hot paths. At the scaffold there is one bracketed pass, the window's
-- repaint, and the two questions it answers are performance-§9's: does the bracket cost nothing
-- with capture off (zero overhead), and is the stood-down show decision free.
--
-- CEILINGS (measured 2026-10-10, Lua 5.1.5). Pinned hard at 0 bytes: the gated bracket and the
-- stood-down early return must allocate nothing. Raise one only by re-measuring and saying why; a
-- rise is the finding.

local BYTE_CEILING = { refreshCaptureOff = 0, refreshCaptureOn = 64, showDecisionStoodDown = 0 }
local NOTES_PER_ITER = { refreshCaptureOff = 0, refreshCaptureOn = 1, showDecisionStoodDown = 0 }

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
NS.Perf.Note = realNote

for _, r in ipairs(results) do
    local ceiling = BYTE_CEILING[r.name]
    check(ceiling ~= nil and r.bytesPerIter <= ceiling,
        ("%s allocated %.1f bytes/iter, over its %s-byte ceiling"):format(r.name, r.bytesPerIter, tostring(ceiling)))
    local want = NOTES_PER_ITER[r.name]
    check(want ~= nil and math.abs(r.notesPerIter - want) < 1e-9,
        ("%s noted %.2f times/iter, pinned at %s"):format(r.name, r.notesPerIter, tostring(want)))
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
