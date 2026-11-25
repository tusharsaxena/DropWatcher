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
-- The scenarios grow with the hot paths: the window's repaint (the scaffold; in the compact layout
-- too, DW-C5), the loot parser's line (DW-25), the Insights tab's recompute over a full log
-- (issue #12, DW-N1), the Rolls panel's raid refresh (RX-18) and Item Search's tooltip block on a
-- cold and a warm hover (IS-DW-04). The questions are
-- performance-§9's: does each bracket cost nothing with capture off (zero overhead), and is the
-- stood-down show decision free.
--
-- CEILINGS (measured 2026-10-10, Lua 5.1.5). Pinned hard at 0 bytes: the stood-down early return
-- must allocate nothing. Raise one only by re-measuring and saying why; a rise is the finding.

-- The parse pair (measured 2026-10-11 at 664 bytes in both) allocates its captures, the loot record
-- and the roster lookup's lowercased name; its ceiling is that work, and the pair being equal is the
-- zero-overhead evidence.
-- The refresh pair was pinned at 0 when the scaffold's Refresh painted nothing. Re-measured
-- 2026-10-11 (DW-61) at 13456 bytes in both: the shown window's whole pass now does real work (the
-- tab labels' and the footer's formatted strings, the filter bar's labels, the tab's context and
-- its row predicate's closures, the Drops table's empty state), coalesced to at most one pass
-- a frame. Its ceiling is that work; the zero-overhead evidence is PAIRED below: capture off may
-- allocate nothing over capture on, and capture on no more than one note's PAIR_SLACK over off.
-- Raised to 14500 on 2026-10-11 (DW-A6, M10): the pass measured 17226 bytes once the filter bar
-- rebuilt its View and Character rows and selections on every sync; those are now built once and
-- written only on change, which leaves 14168, the M10 work itself (a group header's hidden-drop
-- predicates, DW-A0, and the Character dropdown's context, DW-A4) over the M9 figure of 13680.
-- The rolls UX round took it to 14736 (bisected 2026-11-14: RX-04's two item kinds grew the feed
-- config's kinds map +320, RX-09's footer line +128); the filter bar's quality readout now reads its
-- three settings instead of building that whole config each pass, which leaves 12624.
-- It grew again to 13552 (bisected 2026-11-16 across 2118228..b19707c, RX-27: UC-DW's bee9b9f +480,
-- RX-24's c5d9613 +448): every pass handed W.Footer its grip (foot:SetGrip), which lays the footer's
-- marks and both lines out again, the more so once RX-24 gave it marks. The footer is now told only
-- when the grip turns, and the panes are anchored only when their top moves, which leaves 11120
-- (the compact pair 6768, from 9200).
-- The compact refresh pair (DW-C5, compact spec §5) is the same pass in the compact layout: the
-- same window, the cards' pane in place of the table, its chrome (the short title, the Filters
-- button's count and tooltip, the one-line footer). Measured 2026-10-11 at 11065 bytes in both, under
-- the full pass's 14249 (no column labels or table to lay out); its ceiling is that work, and
-- the pair holds the same zero-overhead rule, paired.
-- The Insights recompute (DW-N1, Insights design spec §6) is the pure pass alone, Rows, Options,
-- Filter, Period and Compute, over a log at the safety ceiling (NS.History.CEILING drops): it builds
-- a row per drop (most of it: about 660 bytes a row) and the options and stats tables by design,
-- so its ceiling is that work: measured 2026-11-05 at 4956816 bytes (9567632 before the rows read
-- one calendar midnight per quarter hour). It has no bracket of its own (the tab's are DW-N2's), so
-- it notes nothing.
local INSIGHTS_CEILING = 5200000
-- The Rolls panel's raid refresh (rolls panel design §3.3, RX-18) is RollsPanel.Refresh over six
-- watched rolls of 40 players in a group of 40: the reconcile, each block's header and its rows and
-- folded lines, every frame from the pools. Its ceiling is that work: first measured 2026-11-15 at
-- 89376 bytes with one block open, the ceiling that plus a small margin. Round 2 (RX-21) opens all
-- six blocks (the one-open rule is gone), which measured 427136 bytes until the panel kept each
-- block's rows while its roll reads the same (RollsPanel's rowsOf) and left a pooled frame already
-- in place where it is: 79328 bytes, under the same ceiling, which is not raised.
local ROLLS_PANEL_RAID_CEILING = 95000
-- Item Search's tooltip block (Item Search spec §4.4; WoW Forever's alone): one item hover's post
-- call over the kit's ForeverDB fake, the item with every kind of source. COLD reads the database
-- again (the item's static facts emptied first); WARM is the hover the cache serves: the live reads
-- (quest states, known recipes, the skill ranks), the options and the lines. Their ceilings are that
-- work: measured 2026-11-25 (IS-DW-04) at 16080 and 5664 bytes, each ceiling that plus a margin.
-- The feedback run's ranking (every section sorted for the player, IS.Me per hover) took them to
-- 22336 and 10152 (ISF-DW-08); ISF-REV brought them back under the same ceilings, which are not
-- raised: a flat two-number sort key in scratch tables (no table per row, no comparator per call),
-- the spot memo (a source's maps read once, not lib.Spots' new tables per row per hover), the
-- hover's IS.Me filling one reused table, no capped copy per section, the options' order and
-- sections answered again while unchanged, one NPC read per vendor, and no merge pass under two
-- named objects: 17248 and 6144 bytes, measured 2026-11-25. On Retail the call is the inert early
-- return, pinned at 0.
local ITEM_SEARCH_TIP_COLD = 17500
local ITEM_SEARCH_TIP_WARM = 6500
local BYTE_CEILING = { refreshCaptureOff = 14500, refreshCaptureOn = 14500, showDecisionStoodDown = 0,
    parseCaptureOff = 700, parseCaptureOn = 700, refreshCompactCaptureOff = 11500,
    refreshCompactCaptureOn = 11500, insightsCompute = INSIGHTS_CEILING, rollsPanelRaid = ROLLS_PANEL_RAID_CEILING,
    itemSearchTipCold = ITEM_SEARCH_TIP_COLD, itemSearchTipWarm = ITEM_SEARCH_TIP_WARM, itemSearchTipInert = 0 }
-- Each bracketed path measured off and on: [off] = on. The bracket with capture off is one upvalue
-- read and one boolean test, so the off run allocates no more than the on run; the on run adds at
-- most PAIR_SLACK bytes (the note itself) per iteration. PAIR_NOISE absorbs the two loops'
-- incidental spread (a fraction of a byte per iteration, measured), nothing more.
local PAIRS = { refreshCaptureOff = "refreshCaptureOn", parseCaptureOff = "parseCaptureOn",
    refreshCompactCaptureOff = "refreshCompactCaptureOn" }
local PAIR_SLACK = 64
local PAIR_NOISE = 1
local NOTES_PER_ITER = { refreshCaptureOff = 0, refreshCaptureOn = 1, showDecisionStoodDown = 0,
    parseCaptureOff = 0, parseCaptureOn = 1, refreshCompactCaptureOff = 0, refreshCompactCaptureOn = 1,
    insightsCompute = 0, rollsPanelRaid = 0, itemSearchTipCold = 0, itemSearchTipWarm = 0, itemSearchTipInert = 0 }

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

-- The warm-up and the measured loop run through this one function, so both call `fn` at the same
-- stack depth: the measured loop never grows the Lua stack past the warm-up's high-water mark,
-- which once billed a one-time stack reallocation (about 1.8 KB) to whichever scenario ran first
-- (bisected 2026-10-11 to DW-C2's deeper refresh path; the refresh pair read 14249.9 off against
-- 14248.1 on, the off run's first iteration alone 1.8 KB over). The full collect shrinks the Lua
-- stack again, and how far depends on what the load left it at (two files more in the TOC took the
-- refresh pair to 13458.9 off against 13457.0 on, 2026-10-31), so one settling call runs with the
-- collector stopped, and the measured loop pays no regrowth.
local function loop(n, fn)
    for _ = 1, n do fn() end
end

--- Run `fn` n times after a warm-up, the collector stopped inside the loop.
local function measure(name, n, fn)
    loop(50, fn)
    collectgarbage("collect"); collectgarbage("collect")
    collectgarbage("stop")
    loop(1, fn)
    notes = 0
    local before = collectgarbage("count")
    local t0 = os.clock()
    loop(n, fn)
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

-- The same pair in the compact layout (compact spec §5): the same window repainting its cards'
-- pane and its compact chrome; the bracket is the same one, so the pair holds the same rule.
NS.SetWindowMode("compact")
check(NS.WindowCompact.Mode() == "compact", "the window did not switch to the compact layout")
NS.Perf.on = false
measure("refreshCompactCaptureOff", N, NS.Window.Refresh)
NS.Perf.on = true
measure("refreshCompactCaptureOn", N, NS.Window.Refresh)
NS.Perf.on = false
NS.SetWindowMode("full")

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

-- The Insights recompute over a log at the safety ceiling: 100 groups of 50 drops over 30 days, a
-- mix of outcomes, verdicts, places and recorders; capture off, so nothing is noted.
local function insightsLog(now)
    local groups, places = {}, { "Ruby Life Pools", "Altar of Fangs", "Temple", "Priory" }
    local outcomes = { "seen", "seen", "seen", "asked", "received", "expired", "tradedAway", "offered" }
    local verdicts = { "upgrade", "sidegrade", "downgrade", "cantUse" }
    for gi = 1, NS.History.CEILING / NS.History.MAX_DROPS do
        local at = now - (gi % 30) * 86400
        local g = { key = "g" .. gi, label = "Boss " .. (gi % 8), kind = gi % 3 == 0 and "encounter" or "run",
            instance = places[gi % 4 + 1], difficulty = "Mythic+ " .. (gi % 10 + 2), situation = "mythicPlus",
            at = at, seenBy = "Alt" .. (gi % 5) .. "-Realm", drops = {} }
        for di = 1, NS.History.MAX_DROPS do
            local o = outcomes[di % #outcomes + 1]
            g.drops[di] = { itemLink = "x", itemID = di, looter = "M" .. (di % 7) .. "-Realm", class = "WARRIOR",
                isMine = (o == "tradedAway" or o == "offered") or nil, outcome = o, at = at + di, quality = 4,
                equipLoc = "INVTYPE_HEAD", me = { verdict = verdicts[di % 4 + 1], ilvlDelta = di % 9 - 4 },
                trade = { state = "likely" }, settledAt = (o == "received") and at or nil }
        end
        groups[gi] = g
    end
    return groups
end
local IF, IS = NS.InsightsFilters, NS.InsightsStats
local insightsNow = os.time()
local insightsGroups = insightsLog(insightsNow)
local insightsF = { char = "all", instance = "all", difficulty = "all", situation = "all", date = "14",
    quality = "all", category = "all" }
local function insightsOnce()
    local rows = IF.Rows(insightsGroups)
    local f = IF.Normalize(rows, insightsF, insightsNow, nil, { days = 30 })
    local kept = IF.Filter(rows, f, insightsNow)
    IS.Compute(kept, IF.Period(kept, 30, f.date, insightsNow))
end
NS.Perf.on = false
measure("insightsCompute", 20, insightsOnce)

-- The Rolls panel's raid refresh (rolls panel design §3.3, RX-18): a group of 40 in a raid, six
-- watched rolls of 40 players each (20 Need, 10 Greed, 5 Pass, 4 still to roll, and you), the panel
-- docked beside the shown window: all six blocks open (RX-21), each with its rows and its two folded
-- lines. Its bytes are the pass's own tables and strings (the blocks, the time left); the rows are
-- kept from the first paint and the frames all come from the pools. No bracket, so it notes nothing.
do
    local others = {}
    for i = 1, 39 do
        others[i] = { guid = ("Player-9-%08X"):format(i), name = "Raider" .. i, class = "Warrior", classFile = "WARRIOR" }
    end
    mock.setGroup(others, true)
    mock.__context.inInstance, mock.__context.instanceType = true, "raid"
    mock.instance.difficultyID = 14
    mock.__fire("PLAYER_ENTERING_WORLD")
    NS.ShowWindow()
    mock.lootHistoryTime = 110
    for i = 1, 6 do
        local link = ("|cnIQ4:|Hitem:%d::::::::90:::::|h[Item %d]|h|r"):format(3000 + i, 3000 + i)
        mock.addItem(link, { name = "Item", quality = 4, ilvl = 620, equipLoc = "INVTYPE_FINGER", classID = 4,
            subClassID = 0, bindType = 1, stats = {} })
        local infos = {}
        local function add(n, state, roll, isSelf)
            infos[#infos + 1] = { playerName = n == 0 and "Testchar" or ("Raider" .. n),
                playerGUID = n == 0 and "Player-0-00000001" or ("Player-9-%08X"):format(n), playerClass = "WARRIOR",
                isSelf = isSelf == true, state = state, roll = roll, isWinner = false }
        end
        for n = 1, 39 do
            local state = n <= 20 and 0 or n <= 30 and 3 or n <= 35 and 5 or 4
            add(n, state, state <= 3 and (100 - n) or nil)
        end
        add(0, 5, nil, true)
        mock.lootHistory["2900:" .. i] = { itemHyperlink = link, playerRollState = 5, isTied = false, allPassed = false,
            startTime = 100, duration = 60 + i, rollInfos = infos }
    end
    mock.__fire("LOOT_HISTORY_UPDATE_ENCOUNTER", 2900)
    local drawn = NS.RollsPanel.Drawn()
    check(NS.RollsPanel.IsShown() and drawn ~= nil and drawn.raid and #drawn.headers == 6,
        "the Rolls panel did not show six raid blocks")
    NS.Perf.on = false
    measure("rollsPanelRaid", 200, NS.RollsPanel.Refresh)
end

-- Item Search's tooltip block (Item Search spec §4.4): the post call on an item hover, WoW Forever's
-- alone. On WoW Forever, against the kit's ForeverDB fake once its login load has run, a COLD hover
-- (the item's static facts emptied first, so the database is read again) and a WARM one (the facts
-- kept, only the live reads and the lines); the tooltip is cleared before each, as the client
-- clears it, so each iteration writes the block once. On Retail the call is the inert early return.
do
    local tip = { lines = 0 }
    function tip.AddLine(self) self.lines = self.lines + 1 end
    function tip.AddDoubleLine(self) self.lines = self.lines + 1 end
    function tip.GetName() return "GameTooltip" end
    function tip.IsShown() return false end
    function tip.HookScript(self, script, fn) self[script] = fn end   -- the block's OnHide / OnTooltipCleared
    local IST, ISM = NS.ItemSearchTip, NS.ItemSearch
    if NS.Constants.FEATURE.itemSearch then
        local FDB = dofile("tests/_kit/mock_foreverdb.lua")
        FDB.install(mock, { preset = "present" })
        mock.inCombat = false
        mock.fireEvent("PLAYER_ENTERING_WORLD", true, false)
        mock.advance(5)
        check(ISM.State() == "loaded", "ForeverDB's fake did not load for the tooltip scenarios")
        local data = { id = FDB.IDS.blade }
        local function clear() tip.lines = 0; if tip.OnTooltipCleared then tip.OnTooltipCleared(tip) end end
        check(IST.OnTooltip(tip, data), "the tooltip block was not written")
        measure("itemSearchTipCold", N, function() ISM.Invalidate(); clear(); IST.OnTooltip(tip, data) end)
        measure("itemSearchTipWarm", N, function() clear(); IST.OnTooltip(tip, data) end)
    else
        local data = { id = 990101 }
        measure("itemSearchTipInert", N, function() IST.OnTooltip(tip, data) end)
    end
end
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
