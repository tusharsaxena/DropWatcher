-- tests/test_sim_report.lua — the simulator's loot step says where its drops went, and the window
-- reconciles with it (feedback-3 spec §0, DW-B0; modules/SimReport.lua). The owner's run read
-- `Loot: 2 drops` while the window showed one drop under `1 drop`: the second drop was yours, and
-- was listed apart from the others. Since feedback-5 spec §2 and §3 Drops lists your own drops too
-- (`feed.showOwn` and the separate tab are retired), so the step's drops are all on Drops. Then: the
-- pure report (Place, Summarize, TipLines), the owner's case end to end (the panel row, its
-- tooltip, the chat line, the header and the tab), `/dw sim loot`'s line, and the regression over
-- every scenario: the drops on Drops and hidden add up to each loot step's count, and Drops lists
-- the step's drops of yours.

local T = _G.DW_TEST
local test, assertEqual, assertTrue = T.test, T.assertEqual, T.assertTrue

local function link(id, ilvl)
    return ("|cnIQ4:|Hitem:%d::::::::90:::::%d|h[Item %d]|h|r"):format(id, ilvl or 0, id)
end

local function ring(ilvl)
    return { name = "Ring", quality = 4, ilvl = ilvl, equipLoc = "INVTYPE_FINGER", classID = 4,
        subClassID = 0, bindType = 1, stats = {} }
end

-- Item levels per difficulty in the journal the cases seed (as test_sim_e2e's).
local LEVEL = { [1] = 580, [2] = 590, [23] = 600, [8] = 610, [17] = 590, [14] = 600, [15] = 610, [16] = 620 }

local function seedJournal(m)
    local j = m.journal
    j.tiers = { { dungeons = { { id = 101, name = "Ashen Vault" }, { id = 102, name = "Tidewell" } },
        raids = { { id = 201, name = "The Spire" } } } }
    local function add(inst, d, n)
        local id = inst * 1000 + d * 10 + n
        local l = link(id, LEVEL[d])
        m.addItem(l, ring(LEVEL[d]))
        return { itemID = id, link = l, encounterID = 2000 + n }
    end
    for _, inst in ipairs({ 101, 102 }) do
        j.loot[inst] = {}
        for _, d in ipairs({ 1, 2, 23, 8 }) do j.loot[inst][d] = { add(inst, d, 1), add(inst, d, 2) } end
    end
    j.loot[201] = {}
    for _, d in ipairs({ 17, 14, 15, 16 }) do j.loot[201][d] = { add(201, d, 1), add(201, d, 2) } end
end

-- An enabled addon in the mock's solo world; the player wears two rings at `ilvl`.
local function addon(ilvl)
    local NS, _, m = T.enableAddon()
    m.addItem(link(100, ilvl), ring(ilvl))
    m.addItem(link(101, ilvl), ring(ilvl))
    m.inventory.player[11], m.inventory.player[12] = link(100, ilvl), link(101, ilvl)
    m.INVTYPE_FINGER = "Finger"
    seedJournal(m)
    return NS, m
end

local function printed(m, needle)
    local n = 0
    for _, line in ipairs(m.prints) do
        if line:find(needle, 1, true) then n = n + 1 end
    end
    return n
end

-- Play the started scenario's steps up to and including the next loot step; answers it.
local function toLoot(NS)
    while true do
        local step = NS.SimScenario.Step()
        if not step or step.kind == "loot" then return step end
    end
end

-- The panel's row for a timeline step, composed from the running timeline.
local function panelRow(NS, step)
    local SC, steps = NS.SimScenario, NS.SimScenario.Steps()
    local rows = NS.SimPanel.Compose({ running = true, ready = true, scenario = NS.Sim.Session().scenario,
        steps = steps, pos = SC.Status().pos, now = 0 })
    for i, s in ipairs(steps) do
        if s == step then return rows[i + 1] end
    end
    return nil
end

-- ---------------------------------------------------------------------------------------------
-- The owner's case, reproduced before the fix
-- ---------------------------------------------------------------------------------------------

test("sim report: the owner's key run: the second drop is yours, on Drops, nothing lost", function()
    local NS = addon(600)
    assertTrue(NS.SimScenario.Start("key", nil, { seed = 1 }))
    local step = toLoot(NS)
    local drops = NS.LootFeed.Drops("live")
    -- Root cause (proven): two lines, two drops in the feed, none hidden or merged; one is yours.
    assertEqual(#drops, 2)
    assertEqual(NS.State.feed.merged, 0); assertEqual(next(NS.State.feed.hidden), nil)
    assertTrue(drops[1].isMine and not drops[2].isMine, "the burst's first line is yours")
    assertTrue(not NS.WindowFilterBar.IsTradeableMine(drops[1]), "an upgrade for you: not tradeable")
    NS.Window.SelectTab("group"); NS.Window.Refresh()
    local header = NS.WindowGroup.Drawn().headers[1]
    assertEqual(NS.WindowCells.Entries(NS.LootFeed.Groups("live"), NS.LootFeed.Get, NS.Window.TabContext("group"),
        {})[1].count, 2, "Drops shows both, yours too (feedback-5 spec §2)")
    -- What says so: the step, the panel row and its tooltip, the chat line, the header, the tab.
    assertEqual(step.detail, "2 drops")
    local row = panelRow(NS, step)
    assertEqual(row.label, "Loot: 2 drops")
    assertEqual(row.tip[3], "Item 101081 (you): Drops")
    assertEqual(row.tip[4], "Item 101081 (Kaelis): Drops")
    assertTrue(header ~= nil)
    NS.Window.SelectTab("group"); NS.Window.Refresh()
    local text = NS.WindowGroup.Drawn().headers[1].text:GetText()
    assertTrue(text:find("· 2 drops ·", 1, true) ~= nil, text)
    assertTrue(text:find("yours", 1, true) == nil, "no `yours` suffix: " .. text)
    assertEqual(NS.Window.Frame().tabs.group.label:GetText(), "Drops", "no tab label count (feedback-5 spec §3)")
end)

test("sim report: the step's chat line says where its drops went", function()
    local NS, m = addon(600)
    NS.SimScenario.Start("key", nil, { seed = 1 })
    toLoot(NS)
    local st = NS.SimScenario.Status()
    assertEqual(printed(m, ("Simulation step %d of %d: loot: 2 drops."):format(st.pos, st.steps)), 1)
end)

test("sim report: /dw sim loot says where its drops went", function()
    local NS, m = addon(600)
    NS.SimScenario.Start("dungeon", nil, { seed = 1 })
    local member = NS.SimRoster.Get()[1]
    NS.addon:OnSlashCommand("sim loot 1 " .. member.name)
    assertEqual(printed(m, "Simulated loot: 1 drop."), 1)
    NS.addon:OnSlashCommand("sim loot 1 me")
    assertEqual(printed(m, "Simulated loot: 1 drop."), 2, "yours is on Drops too")
end)

-- ---------------------------------------------------------------------------------------------
-- The pure report
-- ---------------------------------------------------------------------------------------------

local function rec(id, over)
    local r = { id = id, state = "added", link = link(id), looter = { name = "Seta-Silverkeep" } }
    for k, v in pairs(over or {}) do r[k] = v end
    return r
end

test("sim report: each drop's place: Drops (yours too), hidden by its gate, loading, cleared", function()
    local R = T.newAddon().SimReport
    local feed = {}
    local function get(id) return feed[id] end
    local group, mine = rec(1), rec(2, { isMine = true })
    feed[1], feed[2] = group, mine
    assertEqual(R.Place(group, get), "group"); assertEqual(R.Place(mine, get), "group")
    local place, why = R.Place(rec(3, { state = "hidden", hidden = "quality" }), get)
    assertEqual(place, "hidden"); assertEqual(why, "quality")
    assertEqual(R.Place(rec(4, { state = "loading" }), get), "loading")
    assertEqual(R.Place(rec(5), get), "cleared", "a drop no longer in the feed")
end)

test("sim report: the detail counts the drops and says which are hidden or otherwise placed", function()
    local R = T.newAddon().SimReport
    local feed = {}
    local function get(id) return feed[id] end
    local function report(sent, drops, merged)
        for _, d in ipairs(drops) do if d.state == "added" and d.id < 10 then feed[d.id] = d end end
        return { sent = sent, drops = drops, merged = merged or 0 }
    end
    assertEqual(R.Summarize(report(1, { rec(1) }), get).text, "1 drop")
    assertEqual(R.Summarize(report(2, { rec(2, { isMine = true }), rec(3) }), get).text, "2 drops")
    local c = R.Summarize(report(3, { rec(4, { isMine = true }), rec(5), rec(6, { state = "hidden", hidden = "quality" }) }),
        get)
    assertEqual(c.text, "3 drops (1 hidden)")
    assertEqual(c.group + c.hidden, c.total)
    assertEqual(c.mine, nil, "no place of its own for yours")
    c = R.Summarize(report(4, { rec(7, { state = "loading" }), rec(11) }, 1), get)
    assertEqual(c.text, "4 drops (1 loading, 1 merged, 1 cleared, 1 refused)")
    assertEqual(R.Summarize(report(0, {}), get).text, "0 drops")
end)

test("sim report: the tooltip names each drop, its looter and its tab or gate", function()
    local R = T.newAddon().SimReport
    local feed = {}
    local function get(id) return feed[id] end
    local mine, group = rec(1, { isMine = true }), rec(2)
    feed[1], feed[2] = mine, group
    local lines = R.TipLines({ sent = 5, merged = 1, drops = { mine, group,
        rec(3, { state = "hidden", hidden = "minIlvl", looter = { name = "Vaela" } }) } }, get)
    assertEqual(lines[1], "Item 1 (you): Drops")
    assertEqual(lines[2], "Item 2 (Seta): Drops")
    assertEqual(lines[3], "Item 3 (Vaela): hidden: below the minimum item level")
    assertEqual(lines[4], "1 merged into an earlier drop")
    assertEqual(lines[5], "1 refused by the feed")
    assertEqual(#lines, 5)
end)

test("sim report: a Drops header no longer counts drops of yours apart", function()
    local WC = T.newAddon().WindowCells
    local g = { label = "Altar of Fangs", kind = "run" }
    assertEqual(WC.Header(g, 1, nil, nil, false, nil, nil, 1).text, "Altar of Fangs · 1 drop", "an extra argument is ignored")
    assertEqual(WC.Header(g, 2).text, "Altar of Fangs · 2 drops")
end)

-- ---------------------------------------------------------------------------------------------
-- The regression: every scenario's loot steps reconcile with the tabs
-- ---------------------------------------------------------------------------------------------

local SCENARIOS = { { "key" }, { "dungeon" }, { "raid", 12 }, { "lfr", 10 }, { "delve" }, { "world" } }

local function inReport(report)
    local set = {}
    for _, d in ipairs(report.drops) do set[d] = true end
    return set
end

-- The step's drops on Drops: the shown count of each header whose group holds them (one loot
-- step per group in every scenario), collapsed or not.
local function groupShown(NS, report)
    local keys = {}
    for _, d in ipairs(report.drops) do
        if d.groupKey then keys[d.groupKey] = true end
    end
    local n = 0
    local LF = NS.LootFeed
    for _, e in ipairs(NS.WindowCells.Entries(LF.Groups("live"), LF.Get, NS.Window.TabContext("group"), {})) do
        if e.kind == "header" and keys[e.group.key] then n = n + e.count end
    end
    return n
end

-- The step's drops of yours the feed took (each on Drops under the defaults).
local function yoursAdded(report)
    local n = 0
    for _, d in ipairs(report.drops) do
        if d.isMine and d.state == "added" then n = n + 1 end
    end
    return n
end

-- The step's drops of yours Drops lists (its filters applied, collapsed or not: what its strip counts).
local function mineShown(NS, report)
    local set, n = inReport(report), 0
    local ctx = NS.Window.TabContext("group")
    for _, d in ipairs(NS.DropsStrip.Own(NS.LootFeed.Drops("live"), ctx.matches)) do
        if set[d] then n = n + 1 end
    end
    return n
end

local function assertReconciles(NS, step, label)
    local report = step.report
    local c = NS.SimReport.Summarize(report, NS.LootFeed.Get)
    local shown = groupShown(NS, report)
    local mine = mineShown(NS, report)
    assertEqual(c.merged, 0, label .. ": no line merged"); assertEqual(c.refused, 0, label .. ": none refused")
    assertEqual(c.loading, 0, label .. ": none loading")
    assertEqual(shown + c.hidden, c.total, label .. ": Drops + hidden = " .. step.detail)
    assertEqual(shown, c.group, label .. ": Drops shows the step's drops, yours too")
    assertEqual(mine, yoursAdded(report), label .. ": Drops lists the step's drops of yours")
end

local function runAll(name, size, seed, ilvl, hideAll)
    local label = ("%s seed %d at %d%s"):format(name, seed, ilvl, hideAll and ", min ilvl gate" or "")
    local NS = addon(ilvl)
    if hideAll then
        assertTrue(NS.SchemaRuntime.Set("feed.minIlvlMode", "absolute"), label)
        assertTrue(NS.SchemaRuntime.Set("feed.minIlvl", 900), label)
    end
    assertTrue(NS.SimScenario.Start(name, size, { seed = seed }), label)
    local steps = 0
    while true do
        local step = toLoot(NS)
        if not step then break end
        steps = steps + 1
        assertReconciles(NS, step, label .. " step " .. steps)
        if hideAll then
            local c = NS.SimReport.Summarize(step.report, NS.LootFeed.Get)
            assertEqual(c.hidden, c.total, label .. ": the gate hid every drop")
            assertTrue(step.detail:find(("(%d hidden)"):format(c.total), 1, true) ~= nil, step.detail)
        end
    end
    assertTrue(steps > 0, label .. ": the scenario has a loot step")
    NS.Sim.Stop("stop")
end

for _, sc in ipairs(SCENARIOS) do
    test("sim report regression " .. sc[1] .. ": Drops + hidden = every loot step's drops", function()
        for _, ilvl in ipairs({ 600, 660 }) do
            for seed = 1, 3 do runAll(sc[1], sc[2], seed, ilvl) end
        end
        runAll(sc[1], sc[2], 1, 600, true)
    end)
end

-- ---------------------------------------------------------------------------------------------
-- M11 review leftovers (feedback-3 spec §5, DW-B5): the tabs and the panel agree beyond the defaults
-- ---------------------------------------------------------------------------------------------

test("sim report: a place lists yours on Drops and honors the feed the window shows", function()
    local R = T.newAddon().SimReport
    local feed = {}
    local function get(id) return feed[id] end
    local mine, group = rec(1, { isMine = true, feed = "live" }), rec(2, { feed = "live" })
    feed[1], feed[2] = mine, group
    assertEqual(R.Place(mine, get, { feed = "live" }), "group", "Drops lists yours (feedback-5 spec §2)")
    assertEqual(R.Place(mine, get, { feed = "live", showOwn = false }), "group", "a stale showOwn is ignored")
    assertEqual(R.Place(group, get, { feed = "test" }), "offscreen", "test mode shows its own feed")
    assertEqual(R.Place(mine, get, { feed = "test" }), "offscreen")
    local report = { sent = 2, merged = 0, drops = { mine, group } }
    assertEqual(R.Summarize(report, get, { feed = "live" }).text, "2 drops")
    assertEqual(R.Summarize(report, get, { feed = "test" }).text, "2 drops (2 not shown in test mode)")
    local lines = R.TipLines(report, get, { feed = "live" })
    assertEqual(lines[1], "Item 1 (you): Drops")
    assertEqual(lines[2], "Item 2 (Seta): Drops")
    lines = R.TipLines(report, get, { feed = "test" })
    assertEqual(lines[2], "Item 2 (Seta): not shown while test mode is on")
end)

test("sim report: View reads the feed the window shows; feed.showOwn is retired", function()
    local NS = addon(600)
    local v = NS.SimReport.View()
    assertEqual(v.feed, "live"); assertEqual(v.showOwn, nil)
    assertTrue(not NS.SchemaRuntime.Set("feed.showOwn", true), "no such setting any more")
    NS.addon.db.profile.feed.showOwn = false   -- a stored value is ignored
    NS.State.testMode = true
    v = NS.SimReport.View()
    assertEqual(v.feed, "test"); assertEqual(v.showOwn, nil)
    NS.State.testMode = false
end)

test("sim report: the owner's step lists yours on Drops, and the tabs agree", function()
    local NS = addon(600)
    NS.SimScenario.Start("key", nil, { seed = 1 })
    local step = toLoot(NS)
    assertEqual(step.detail, "2 drops")
    local row = panelRow(NS, step)
    assertEqual(row.label, "Loot: 2 drops")
    assertEqual(row.tip[3], "Item 101081 (you): Drops")
    local c = NS.SimReport.Summarize(step.report, NS.LootFeed.Get, NS.SimReport.View())
    local shown = groupShown(NS, step.report)
    assertEqual(shown, c.group); assertEqual(c.group + c.hidden, c.total)
end)
