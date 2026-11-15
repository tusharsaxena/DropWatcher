-- tests/test_rolls_panel.lua — modules/RollsPanel.lua and modules/RollsPanelRows.lua, the Rolls
-- panel docked beside the window (rolls panel design §3.1, §3.2, §3.4, §3.5; plan RX-17): docked
-- flush right (or Left), flipped near the screen's edge; shown on a watched roll while the window is
-- shown, not on a filtered roll, not with the window closed; rows grouped Need, Greed, Disenchant
-- (Retail only), Pass, still to roll, highest first, `[YOU]` on yours; the winner washed gold and the
-- result line; finished rolls stay until every roll is over, then the panel closes after the linger
-- (0 at once), the pointer over the panel holds it; the window's auto-close waits while it lingers;
-- the setting off shows nothing; `/dw rolls` toggles. Raid mode (design §3.3, RX-18) folds Pass and
-- Waiting past five and repaints from the pools. Round 2 (2026-11-15 design part A, plan RX-21): the
-- test and sim strips under the title bar, item headers with a collapser, Expand all and Collapse
-- all, every item open by default, no verdict line, alternate row shading, every roll number,
-- tooltips, the title Rolls, the panel-level linger, gap 0, 290 wide (250 compact).
-- Rolls are a both-clients feature, so every case runs on both kit profiles.

local T = _G.DW_TEST
local test, assertEqual, assertTrue, assertFalse, assertNil = T.test, T.assertEqual, T.assertTrue, T.assertFalse, T.assertNil

local LINK = "|cnIQ4:|Hitem:300::::::::90:::::|h[Item 300]|h|r"
local LINK2 = "|cnIQ4:|Hitem:301::::::::90:::::|h[Item 301]|h|r"
local BRAKK, SETA, LYRA, TOR = "Player-1-0000000A", "Player-2-0000000B", "Player-3-0000000C", "Player-4-0000000D"

local function ring(ilvl, quality)
    return { name = "Item", quality = quality or 4, ilvl = ilvl, equipLoc = "INVTYPE_FINGER", classID = 4,
        subClassID = 0, bindType = 1, stats = {} }
end

local function info(name, guid, class, state, roll, isSelf)
    return { playerName = name, playerGUID = guid, playerClass = class, isSelf = isSelf == true, state = state,
        roll = roll, isWinner = false }
end

-- An open drop: Seta Need 12, Brakk Need 87, Lyra Greed 50, you Pass, Tor still to roll.
local function openRoll(link)
    return {
        itemHyperlink = link or LINK, playerRollState = 5, isTied = false, allPassed = false,
        startTime = 100, duration = 60,
        rollInfos = {
            info("Seta", SETA, "MAGE", 0, 12), info("Brakk", BRAKK, "WARRIOR", 0, 87),
            info("Lyra", LYRA, "PRIEST", 3, 50), info("Testchar", "Player-0-00000001", "PALADIN", 5, nil, true),
            info("Tor", TOR, "ROGUE", 4),
        },
    }
end

-- An enabled addon in a heroic dungeon (an auto-open situation on both clients).
local function inDungeon(over)
    local NS, _, m = T.enableAddon()
    for path, v in pairs(over or {}) do NS.SchemaRuntime.Set(path, v) end
    m.__context.inInstance, m.__context.instanceType, m.__context.inGroup = true, "party", true
    m.instance.difficultyID = 2
    m.__fire("PLAYER_ENTERING_WORLD")
    return NS, m
end

-- The window open by hand, placed at `left`..`right` on a 1920-wide screen, 400 tall.
local function shown(over, left, right)
    local NS, m = inDungeon(over)
    NS.ShowWindow()
    local win = NS.Window.Frame()
    win.GetLeft = function() return left or 200 end
    win.GetRight = function() return right or 800 end
    win.GetHeight = function() return 400 end
    m.UIParent.GetWidth = function() return 1920 end
    return NS, m, win
end

-- The roll opens: the drop enters the loot history and Pending admits it.
local function rollOpens(m, key, link, quality)
    m.addItem(link or LINK, ring(620, quality))
    local d = openRoll(link)
    m.lootHistory[key or "2900:1"] = d
    m.__fire("LOOT_HISTORY_UPDATE_ENCOUNTER", 2900)
    return d
end

-- Your roll popup `rollID` for `link` comes up (START_LOOT_ROLL), claimed by its pending item.
local function popup(m, rollID, link)
    m.lootRolls[rollID] = { link = link or LINK, quality = 4 }
    m.__fire("START_LOOT_ROLL", rollID, 60000)
end

-- Brakk wins drop `d` (key 2900:`n`).
local function win(m, d, n)
    d.winner = { playerName = "Brakk", playerGUID = BRAKK, playerClass = "WARRIOR", isSelf = false, roll = 87 }
    d.rollInfos[2].isWinner = true
    m.__fire("LOOT_HISTORY_UPDATE_DROP", 2900, n or 1)
end

local function plain(s)
    return (T.tipPlain((tostring(s or ""):gsub("|T.-|t", ""))):gsub("|cn[^:]*:", ""):gsub("^%s+", ""))
end

-- What the panel's lines say, in order: each line's text and its roll, `text=roll`.
local function lines(NS)
    local out = {}
    for _, f in ipairs(NS.RollsPanel.Drawn().lines) do
        local r = f.roll:GetText()
        out[#out + 1] = plain(f.text:GetText()) .. ((r and r ~= "") and ("=" .. r) or "")
    end
    return out
end

-- ── defaults and settings ───────────────────────────────────────────────────────────────────

test("rolls panel: the defaults are on, docked right, 10 seconds, fold in a raid", function()
    local NS = T.enableAddon()
    local d = NS.C.PROFILE.rolls.panel
    assertEqual(d.enabled, true); assertEqual(d.side, "right"); assertEqual(d.linger, 10); assertEqual(d.foldInRaid, true)
end)

test("rolls panel: four rows on Drops > Rolls > Panel, the sub-rows naming the switch they need", function()
    local NS = T.enableAddon()
    local S = NS.SchemaRuntime
    for _, path in ipairs({ "rolls.panel.enabled", "rolls.panel.side", "rolls.panel.linger", "rolls.panel.foldInRaid" }) do
        local row = S.FindRow(path)
        assertTrue(row ~= nil, path)
        assertEqual(row.page, "feed", path); assertEqual(row.group, "Rolls", path); assertEqual(row.subgroup, "Panel", path)
    end
    local linger = S.FindRow("rolls.panel.linger")
    assertEqual(linger.min, 0); assertEqual(linger.max, 60)
    assertEqual(linger.label, "Keep the panel open after the last roll", "a panel-level linger (RX-21)")
    assertFalse(linger.validate(61)); assertFalse(linger.validate(2.5)); assertTrue(linger.validate(0))
    for _, path in ipairs({ "rolls.panel.side", "rolls.panel.linger", "rolls.panel.foldInRaid" }) do
        local row = S.FindRow(path)
        assertTrue(row.tooltip:find("Needs Show the Rolls panel beside the window.", 1, true) ~= nil, path)
        S.Set("rolls.panel.enabled", false)
        assertTrue(row.disabledIf(), path .. " dims while the panel is off")
        S.Set("rolls.panel.enabled", true)
        assertFalse(row.disabledIf(), path)
    end
    assertEqual(S.FindRow("rolls.show").subgroup, "Window and popup", "the tab's first subject has its heading")
end)

-- red under: the panel's rows not naming Show rolls, whose Rolling now is the panel's list
test("rolls panel: every panel row dims while Show rolls is off, the switch naming the row it needs", function()
    local NS = T.enableAddon()
    local S = NS.SchemaRuntime
    local on = S.FindRow("rolls.panel.enabled")
    assertTrue(on.tooltip:find("Needs Show rolls.", 1, true) ~= nil, on.tooltip)
    for _, path in ipairs({ "rolls.panel.enabled", "rolls.panel.side", "rolls.panel.linger", "rolls.panel.foldInRaid" }) do
        local row = S.FindRow(path)
        assertFalse(row.disabledIf(), path .. " live while Show rolls is on")
        S.Set("rolls.show", false)
        assertTrue(row.disabledIf(), path .. " dims while Show rolls is off")
        S.Set("rolls.show", true)
    end
end)

-- ── showing ─────────────────────────────────────────────────────────────────────────────────

-- red under: no PendingChanged receiver (the panel never shows)
test("rolls panel: a watched roll shows it docked flush right of the shown window, titled Rolls, 290 wide", function()
    local NS, m, w = shown()
    assertFalse(NS.RollsPanel.IsShown(), "nothing before the roll")
    rollOpens(m)
    assertTrue(NS.RollsPanel.IsShown(), "the roll shows it")
    local p = NS.RollsPanel.Drawn().panel
    assertEqual(p:GetParent(), w, "a child of the window: it hides, scales and fades with it")
    assertEqual(p.dock, "right")
    local point, rel, relPoint, x, y = p:GetPoint(1)
    assertEqual(point .. ">" .. relPoint, "TOPLEFT>TOPRIGHT"); assertTrue(rel == w)
    assertEqual(x, 0, "flush: no gap (RX-21)"); assertEqual(y, 0, "top-aligned")
    assertEqual(p:GetWidth(), 290)
    assertEqual(p.title:GetText(), "Rolls")
    assertEqual(#NS.RollsPanel.Drawn().headers, 1, "one block")
    assertEqual(plain(NS.RollsPanel.Drawn().headers[1].name:GetText()), "Item 300")
end)

test("rolls panel: near the screen's right edge it flips left, and the Left setting docks left", function()
    local NS, m, w = shown(nil, 1500, 1800)
    rollOpens(m)
    local p = NS.RollsPanel.Drawn().panel
    assertEqual(p.dock, "left", "1800 + 290 is past 1920")
    local point, rel, relPoint, x = p:GetPoint(1)
    assertEqual(point .. ">" .. relPoint, "TOPRIGHT>TOPLEFT"); assertTrue(rel == w); assertEqual(x, 0, "flush")
    w.GetLeft = function() return 300 end
    w.GetRight = function() return 900 end
    NS.SchemaRuntime.Set("rolls.panel.side", "left")
    NS.RollsPanel.Refresh()
    assertEqual(p.dock, "left", "the setting")
    point, rel, relPoint = p:GetPoint(1)
    assertTrue(rel == w)
    assertEqual(point .. ">" .. relPoint, "TOPRIGHT>TOPLEFT")
    w.GetLeft = function() return 100 end
    w.GetRight = function() return 700 end
    NS.RollsPanel.Refresh()
    assertEqual(p.dock, "right", "no room on the left: the other side")
end)

test("rolls panel: the side flips on a window move, from the geometry seam", function()
    local NS, m, w = shown(nil, 200, 800)
    rollOpens(m)
    local p = NS.RollsPanel.Drawn().panel
    assertEqual(p.dock, "right")
    w.GetLeft = function() return 1500 end
    w.GetRight = function() return 1800 end
    NS.Window.ResetPosition()   -- a `move` notification
    assertEqual(p.dock, "left")
end)

test("rolls panel: a roll the feed's gates refuse shows nothing", function()
    local NS, m = shown()
    NS.addon.db.profile.feed.quality.fixed = 4
    local worn = "|cnIQ4:|Hitem:100::::::::90:::::|h[Item 100]|h|r"
    m.addItem(worn, ring(600))
    m.inventory.player[11], m.inventory.player[12] = worn, worn   -- two 600 rings: 590 is no upgrade
    m.addItem(LINK, ring(590, 2))
    m.lootHistory["2900:1"] = openRoll()
    m.__fire("LOOT_HISTORY_UPDATE_ENCOUNTER", 2900)
    assertEqual(NS.Pending.Count(), 0, "not in Rolling now")
    assertFalse(NS.RollsPanel.IsShown())
end)

test("rolls panel: with the window closed it stays hidden, and shows when the window opens", function()
    local NS, m = inDungeon({ autoOpen = false })
    rollOpens(m)
    assertFalse(NS.IsWindowShown())
    assertFalse(NS.RollsPanel.IsShown(), "never opens the window, never shows without it")
    assertTrue(NS.RollsPanel.HasBlocks(), "the roll is tracked")
    NS.ShowWindow()
    NS.Window.Frame():__fire("OnShow")   -- the client runs the frame's OnShow on Show
    assertTrue(NS.RollsPanel.IsShown(), "it returns with the window")
    NS.HideWindow()
    NS.Window.Frame():__fire("OnHide")
    assertFalse(NS.RollsPanel.IsShown())
end)

test("rolls panel: a minimized window hides it, and expanding brings it back", function()
    local NS, m = shown()
    rollOpens(m)
    NS.Window.SetMinimized(true)
    assertFalse(NS.RollsPanel.IsShown())
    NS.Window.SetMinimized(false)
    assertTrue(NS.RollsPanel.IsShown())
end)

test("rolls panel: the setting off shows nothing, and turning it on shows the roll", function()
    local NS, m = shown({ ["rolls.panel.enabled"] = false })
    rollOpens(m)
    assertFalse(NS.RollsPanel.IsShown())
    assertFalse(NS.RollsPanel.HasBlocks())
    NS.SchemaRuntime.Set("rolls.panel.enabled", true)
    NS.RollsPanel.Refresh()
    assertTrue(NS.RollsPanel.IsShown())
end)

-- ── the rows ────────────────────────────────────────────────────────────────────────────────

-- red under: the verdict line ("^ Upgrade +9") still drawn at a block's foot (RX-21, ruling A4)
test("rolls panel: rows grouped Need, Greed, Pass, still to roll, highest first, [YOU] on yours, no verdict line", function()
    local NS, m = shown()
    rollOpens(m)
    local got = lines(NS)
    assertEqual(got[1], "Brakk=87"); assertEqual(got[2], "Seta=12"); assertEqual(got[3], "Lyra=50")
    assertEqual(got[4], "Testchar [YOU]", "your Pass, with [YOU]")
    assertTrue(got[5]:find("Tor", 1, true) ~= nil, "still to roll last")
    assertEqual(#got, 5, "five players, and no verdict line")
    for _, g in ipairs(got) do assertTrue(g:find("Upgrade", 1, true) == nil, "no verdict: " .. g) end
    local hd = NS.RollsPanel.Drawn().headers[1]
    m.lootHistoryTime = 118
    NS.RollsPanel.Refresh()
    assertEqual(hd.time:GetText(), "0:42", "the time left")
    assertTrue(hd.bar:IsShown(), "the countdown bar under an open roll")
end)

-- red under: the kept rows read again only by table (a changed roll kept its old rows), or never
test("rolls panel: a changed roll repaints its rows, and an unchanged one keeps them", function()
    local NS, m = shown()
    local d = rollOpens(m)
    local first = NS.RollsPanel.Drawn().blocks[1].rows
    NS.RollsPanel.Refresh()
    assertTrue(NS.RollsPanel.Drawn().blocks[1].rows == first, "the same roll: the rows are kept")
    d.rollInfos[5].state, d.rollInfos[5].roll = 3, 44   -- Tor greeds 44
    m.__fire("LOOT_HISTORY_UPDATE_DROP", 2900, 1)
    local got = table.concat(lines(NS), " / ")
    assertTrue(got:find("Tor=44", 1, true) ~= nil, got)
end)

test("rolls panel: a Disenchant counts as Disenchant on Retail, as Greed on WoW Forever", function()
    local NS = T.enableAddon()
    local roll = { link = LINK, rolls = {
        { name = "Brakk", state = 3, roll = 40 }, { name = "Lyra", state = 6, roll = 70 },
    } }
    local rows = NS.RollsPanelRows.Rows(roll)
    if T.forever then
        assertEqual(rows[1].group, "greed"); assertEqual(rows[2].group, "greed")
        assertEqual(rows[1].roll, 70, "one Greed group, highest first")
    else
        assertEqual(rows[1].group, "greed"); assertEqual(rows[2].group, "disenchant")
    end
end)

-- red under: the panel reading the store's open items alone (a won roll leaves Pending at once)
test("rolls panel: a won roll washes the winner gold and reads the result line, then leaves after the linger", function()
    local NS, m = shown()
    local d = rollOpens(m)
    win(m, d)
    assertEqual(NS.Pending.Count(), 0, "the store closed it")
    assertTrue(NS.RollsPanel.IsShown(), "the block lingers")
    local hd = NS.RollsPanel.Drawn().headers[1]
    assertEqual(hd.time:GetText(), "done")
    assertFalse(hd.bar:IsShown())
    local washed
    for _, f in ipairs(NS.RollsPanel.Drawn().lines) do
        if f.winner then washed = f end
    end
    assertTrue(washed ~= nil and washed.wash:IsShown(), "the winner's row is washed")
    assertEqual(plain(washed.text:GetText()), "Brakk")
    local got = lines(NS)
    assertEqual(got[#got], "Won by Brakk (Need 87)")
    m.advance(9.9)
    assertTrue(NS.RollsPanel.IsShown())
    m.advance(0.2)
    assertFalse(NS.RollsPanel.IsShown(), "gone after 10 seconds, and the panel hides")
    assertFalse(NS.RollsPanel.HasBlocks())
end)

test("rolls panel: everyone passing reads Everyone passed; a linger of 0 removes it at once", function()
    local NS, m = shown({ ["rolls.panel.linger"] = 0 })
    local d = rollOpens(m)
    d.allPassed = true
    m.__fire("LOOT_HISTORY_UPDATE_DROP", 2900, 1)
    assertFalse(NS.RollsPanel.HasBlocks(), "0: at once")
    assertFalse(NS.RollsPanel.IsShown())
    local block = NS.RollsPanelRows.Block({ id = 1, link = LINK, state = "allPassed", roll = { allPassed = true, rolls = {} } })
    assertEqual(block.result.text, "Everyone passed")
end)

-- red under: a per-roll linger (a finished roll left while another still ran, RX-21 ruling A9)
test("rolls panel: two rolls are two blocks in the order they started; a finished one stays until both are over", function()
    local NS, m = shown()
    local d1 = rollOpens(m, "2900:1", LINK)
    m.advance(1)
    local d2 = rollOpens(m, "2900:2", LINK2)
    assertEqual(#NS.RollsPanel.Drawn().headers, 2)
    assertEqual(plain(NS.RollsPanel.Drawn().headers[1].name:GetText()), "Item 300")
    assertEqual(plain(NS.RollsPanel.Drawn().headers[2].name:GetText()), "Item 301")
    win(m, d1, 1)
    m.advance(30)
    assertEqual(#NS.RollsPanel.Drawn().headers, 2, "the won roll stays while the other runs")
    assertEqual(NS.RollsPanel.Drawn().headers[1].time:GetText(), "done")
    win(m, d2, 2)
    m.advance(9.9)
    assertTrue(NS.RollsPanel.IsShown(), "every roll over: the linger runs")
    assertEqual(#NS.RollsPanel.Drawn().headers, 2, "both still listed")
    m.advance(0.2)
    assertFalse(NS.RollsPanel.IsShown(), "then the panel closes with both")
    assertFalse(NS.RollsPanel.HasBlocks())
end)

-- red under: the countdown left running when a new roll starts (RX-21 ruling A9)
test("rolls panel: a new roll during the linger cancels the countdown", function()
    local NS, m = shown()
    local d1 = rollOpens(m, "2900:1", LINK)
    win(m, d1, 1)
    m.advance(6)
    local d2 = rollOpens(m, "2900:2", LINK2)
    m.advance(10)
    assertTrue(NS.RollsPanel.IsShown(), "the new roll keeps the panel")
    assertEqual(#NS.RollsPanel.Drawn().blocks, 2, "and the finished roll with it")
    win(m, d2, 2)
    m.advance(9.9)
    assertTrue(NS.RollsPanel.IsShown(), "a full linger from the last roll's end")
    m.advance(0.2)
    assertFalse(NS.RollsPanel.HasBlocks())
end)

-- red under: leave() not checking the pointer
test("rolls panel: the pointer over the panel holds a finished roll; leaving restarts its count", function()
    local NS, m = shown()
    local d = rollOpens(m)
    win(m, d)
    local p = NS.RollsPanel.Drawn().panel
    p.__mouseOver = true
    m.advance(15)
    assertTrue(NS.RollsPanel.IsShown(), "held while hovered")
    assertTrue(NS.RollsPanel.HasBlocks())
    p.__mouseOver = false
    p:__fire("OnLeave")
    m.advance(9.9)
    assertTrue(NS.RollsPanel.HasBlocks(), "a full count from the leave")
    m.advance(0.2)
    assertFalse(NS.RollsPanel.HasBlocks())
end)

-- red under: onLeave dropping blocks from the list it walks (a linger of 0 leaves at once, so the
-- walk skipped the block after each one that left, and that one stayed held with no timer)
test("rolls panel: with a linger of 0, leaving the panel lets every held roll go", function()
    local NS, m = shown({ ["rolls.panel.linger"] = 0 })
    local d1 = rollOpens(m, "2900:1", LINK)
    local d2 = rollOpens(m, "2900:2", LINK2)
    local p = NS.RollsPanel.Drawn().panel
    p.__mouseOver = true
    win(m, d1, 1)
    win(m, d2, 2)
    assertEqual(#NS.RollsPanel.Drawn().blocks, 2, "both held while hovered")
    p.__mouseOver = false
    p:__fire("OnLeave")
    m.advance(1)
    assertFalse(NS.RollsPanel.HasBlocks(), "both left")
    assertFalse(NS.RollsPanel.IsShown())
end)

-- red under: the Show rolls row repainting the window alone (the panel kept the roll Rolling now
-- no longer lists, then lingered it with its winner when the roll was won)
test("rolls panel: turning Show rolls off takes the panel's rolls away at once, and a win brings nothing back", function()
    local NS, m = shown()
    local d = rollOpens(m)
    assertTrue(NS.RollsPanel.IsShown())
    NS.SchemaRuntime.Set("rolls.show", false)
    assertFalse(NS.RollsPanel.HasBlocks(), "Rolling now lists nothing: the block leaves with no linger")
    assertFalse(NS.RollsPanel.IsShown())
    win(m, d)
    assertFalse(NS.RollsPanel.HasBlocks(), "the hidden roll's win adds nothing")
    assertFalse(NS.RollsPanel.IsShown())
end)

-- red under: the scroll body (which takes the pointer) leaving the panel without restarting the count
test("rolls panel: leaving the panel from its scroll body restarts a held roll's count", function()
    local NS, m = shown()
    local d = rollOpens(m)
    win(m, d)
    local p = NS.RollsPanel.Drawn().panel
    p.__mouseOver = true
    m.advance(15)
    assertTrue(NS.RollsPanel.HasBlocks(), "held while hovered")
    p.__mouseOver = false
    p.scroll:__fire("OnLeave")
    m.advance(10.1)
    assertFalse(NS.RollsPanel.HasBlocks(), "the body's leave restarted the count")
end)

test("rolls panel: the close button hides it until the next roll starts", function()
    local NS, m = shown()
    rollOpens(m, "2900:1", LINK)
    NS.RollsPanel.Close()
    assertFalse(NS.RollsPanel.IsShown())
    m.__fire("LOOT_HISTORY_UPDATE_DROP", 2900, 1)
    assertFalse(NS.RollsPanel.IsShown(), "a change to the same roll keeps it closed")
    rollOpens(m, "2900:2", LINK2)
    assertTrue(NS.RollsPanel.IsShown(), "the next roll shows it")
end)

-- red under: settle() lingering a test sample the store dropped, `left` keeping its recycled id, or
-- test mode not refreshing the panel (RX-19)
test("rolls panel: test mode's samples leave at once when it ends, and show again when it comes back", function()
    local NS, m = shown()
    m.seedGearJournal()
    local function quietly(fn)
        local p = m.print
        m.print = function() end
        fn()
        m.print = p
    end
    -- test mode fills the panel on its own (RX-19): no Refresh here
    quietly(function() NS.SetTestMode(true) end)
    assertTrue(NS.RollsPanel.IsShown(), "test mode shows the panel")
    local n = #NS.RollsPanel.Drawn().blocks
    assertTrue(n > 0, "test mode's samples fill the panel")
    quietly(function() NS.SetTestMode(false) end)
    assertFalse(NS.RollsPanel.HasBlocks(), "no linger for samples the store dropped")
    quietly(function() NS.SetTestMode(true) end)
    assertEqual(#NS.RollsPanel.Drawn().blocks, n, "the samples' recycled ids join again")
    quietly(function() NS.SetTestMode(false) end)
end)

local function quietTest(NS, m, on)
    local p0 = m.print
    m.print = function() end
    NS.SetTestMode(on)
    m.print = p0
end

-- red under: settle() looking at open blocks alone (RX-23: a finished live roll lingering when test
-- mode turned on stayed beside the samples, under the TEST strip, and the samples never finish, so
-- the linger never closed it)
test("rolls panel: a finished live roll still lingering leaves at once when test mode turns on", function()
    local NS, m = shown()
    m.seedGearJournal()
    local d = rollOpens(m)
    win(m, d)
    assertTrue(NS.RollsPanel.HasBlocks(), "the won roll lingers")
    quietTest(NS, m, true)
    for _, b in ipairs(NS.RollsPanel.Drawn().blocks) do
        assertTrue(b.item.test == true, "only test mode's samples under the TEST strip: " .. tostring(b.id))
    end
    quietTest(NS, m, false)
    assertFalse(NS.RollsPanel.HasBlocks(), "and the live roll does not come back")
end)

-- red under: the same gap for a simulation started during the linger (the live result under SIM)
test("rolls panel: a finished live roll still lingering leaves at once when a simulation starts", function()
    local NS, m = shown()
    local d = rollOpens(m)
    win(m, d)
    assertTrue(NS.RollsPanel.HasBlocks(), "the won roll lingers")
    local active = NS.Sim.IsActive
    NS.Sim.IsActive = function() return true end
    NS.RollsPanel.Refresh()
    NS.Sim.IsActive = active
    assertFalse(NS.RollsPanel.HasBlocks(), "the live result leaves, not shown under the SIM strip")
end)

-- red under: the panel's band still reading TEST MODE, or no strip of its own (preview-mode: a frame
-- with a title band is a window, and every display of placeholder data says so; RX-21 ruling A1)
test("rolls panel: in test mode a test strip sits directly under its title bar, with no header word", function()
    local NS, m = shown()
    m.seedGearJournal()
    quietTest(NS, m, true)
    local p = NS.RollsPanel.Drawn().panel
    assertTrue(NS.RollsPanel.IsShown())
    assertNil(p.testText, "no TEST MODE word in the band")
    local strip = p.testStrip
    assertTrue(strip ~= nil and strip:IsShown(), "the strip shows with the samples")
    assertEqual(strip.text:GetText(), "TEST: sample rolls. Nothing is sent; combat ends it.")
    local pt = strip.__points[1]
    -- red under: a strip anchored by hand on the panel (anti-pattern #118)
    assertEqual(pt[1], "TOPLEFT"); assertTrue(pt[2] == p.titleBar, "docked on the title band")
    assertEqual(pt[3], "BOTTOMLEFT"); assertEqual(pt[5], 0, "directly under it")
    local sp = p.scroll.__points[1]
    assertEqual(sp[5], -(NS.RollsPanel.TOP + strip:BodyOffset()), "the body moves down by the strip")
    assertEqual(strip:BodyOffset(), NS.TestStripHeight())
    assertTrue(T.tipPlainJoined(NS.Window.TooltipOf(strip)):find("Test mode", 1, true) ~= nil, "the strip has a tooltip")
    assertFalse(p.simStrip:IsShown())
    quietTest(NS, m, false)
    NS.addon:OnSlashCommand("rolls")   -- shown by hand, no samples
    assertTrue(NS.RollsPanel.IsShown())
    assertFalse(strip:IsShown(), "no strip outside test mode")
    assertEqual(p.scroll.__points[1][5], -NS.RollsPanel.TOP, "and the body back under the band")
end)

-- red under: no sim flavor (a simulation's rolls unmarked in the panel)
test("rolls panel: during a simulation the sim strip sits under its title bar instead", function()
    local NS, m = shown()
    rollOpens(m)
    local p = NS.RollsPanel.Drawn().panel
    assertFalse(p.simStrip:IsShown(), "no simulation, no strip")
    local active = NS.Sim.IsActive
    NS.Sim.IsActive = function() return true end
    NS.RollsPanel.Refresh()
    assertTrue(p.simStrip:IsShown(), "the sim strip")
    assertFalse(p.testStrip:IsShown())
    assertEqual(p.simStrip.text:GetText(), "SIM: simulated rolls. Nothing is sent. /dw sim stop ends it.")
    assertTrue(p.simStrip.__points[1][2] == p.titleBar, "docked under the title band")
    assertEqual(p.simStrip.__points[1][5], 0)
    assertTrue(T.tipPlainJoined(NS.Window.TooltipOf(p.simStrip)):find("SIM", 1, true) ~= nil)
    NS.Sim.IsActive = active
    NS.RollsPanel.Refresh()
    assertFalse(p.simStrip:IsShown())
end)

-- red under: test mode's sample roll carrying no numbers (RX-21 ruling A6)
test("rolls panel: test mode's sample roll shows a number on every Need and Greed row, none on Pass or Waiting", function()
    local NS, m = shown()
    m.seedGearJournal()
    quietTest(NS, m, true)
    local numbered, bare = 0, 0
    for _, f in ipairs(NS.RollsPanel.Drawn().lines) do
        local n = f.roll:GetText()
        if f.group == "need" or f.group == "greed" then
            assertTrue(tonumber(n) ~= nil, "a number on " .. plain(f.text:GetText()))
            numbered = numbered + 1
        elseif f.group == "pass" or f.group == "waiting" then
            assertEqual(n, "", "none on " .. plain(f.text:GetText()))
            bare = bare + 1
        end
    end
    assertTrue(numbered >= 5 and bare >= 1, ("numbered %d, bare %d"):format(numbered, bare))
    quietTest(NS, m, false)
end)

-- red under: the Rolls panel and the Offer panel docking on the same side at the same level, so
-- the two overlapped with an arbitrary draw order (RX-20)
local function offerOpen(NS, m)
    m.seedGearJournal()
    T.withPlayer(m)   -- someone to offer to (DW-07)
    local p0 = m.print
    m.print = function() end
    NS.SetTestMode(true)   -- the sample roll fills the Rolls panel; the sample drops include yours
    m.print = p0
    for _, d in ipairs(NS.LootFeed.Drops("test")) do
        if d.isMine and NS.OfferPanel.Open(d.id) then return d end
    end
end

test("rolls panel: the Offer panel docked on its side moves it to the other one, and back when it closes", function()
    local NS, m, w = shown(nil, 400, 1000)
    assertTrue(offerOpen(NS, m) ~= nil, "an Offer panel opened on a sample drop of yours")
    assertEqual(NS.OfferPanel.Drawn().panel.dock, "right", "Offer docks right")
    local p = NS.RollsPanel.Drawn().panel
    assertTrue(NS.RollsPanel.IsShown())
    assertEqual(p.dock, "left", "the Rolls panel takes the other side")
    local point, rel, relPoint = p:GetPoint(1)
    assertEqual(point .. ">" .. relPoint, "TOPRIGHT>TOPLEFT"); assertTrue(rel == w)
    NS.OfferPanel.Close()
    assertEqual(p.dock, "right", "the Offer panel closed: back on its own side")
end)

test("rolls panel: with no room on the other side it waits hidden while the Offer panel holds its side", function()
    local NS, m = shown(nil, 100, 700)   -- 100 - 3 - 250 is off the screen's left
    offerOpen(NS, m)
    assertEqual(NS.OfferPanel.Drawn().panel.dock, "right")
    assertFalse(NS.RollsPanel.IsShown(), "no side free: hidden, not over the Offer panel")
    assertTrue(NS.RollsPanel.HasBlocks(), "its roll is still tracked")
    NS.OfferPanel.Close()
    assertTrue(NS.RollsPanel.IsShown(), "back once the Offer panel closes")
    assertEqual(NS.RollsPanel.Drawn().panel.dock, "right")
end)

-- ── auto-close ──────────────────────────────────────────────────────────────────────────────

-- red under: WindowAutoClose's idle() not asking RollsPanel.HasBlocks
test("rolls panel: an auto-opened window waits while the panel lingers, then a full count", function()
    local NS, m = inDungeon()
    local d = rollOpens(m)
    popup(m, 11)   -- your popup opens the window (RX-16)
    assertTrue(NS.IsWindowShown(), "the roll opened the window")
    -- the client runs the frame's OnShow on the open: the panel follows the window, in either
    -- order of the two PendingChanged receivers
    NS.Window.Frame():__fire("OnShow")
    assertTrue(NS.WindowAutoClose.Armed(), "armed")
    assertTrue(NS.RollsPanel.IsShown(), "panel shown")
    NS.SchemaRuntime.Set("rolls.panel.linger", 30)
    win(m, d)
    m.advance(25)
    assertTrue(NS.IsWindowShown(), "the panel still holds the roll")
    m.advance(5.1)
    assertFalse(NS.RollsPanel.HasBlocks(), "the block left at 30 s")
    m.advance(9.8)
    assertTrue(NS.IsWindowShown(), "a full count from the block leaving")
    m.advance(0.3)
    assertFalse(NS.IsWindowShown())
end)

-- ── /dw rolls ───────────────────────────────────────────────────────────────────────────────

test("rolls panel: /dw rolls shows an empty panel by hand, which stays, and hides it again", function()
    local NS = shown()
    NS.addon:OnSlashCommand("rolls")
    assertTrue(NS.RollsPanel.IsShown(), "shown by hand with no roll")
    local p = NS.RollsPanel.Drawn().panel
    assertTrue(p.empty:IsShown()); assertEqual(p.empty:GetText(), "No rolls right now")
    NS.RollsPanel.Refresh()
    assertTrue(NS.RollsPanel.IsShown(), "a manual show stays")
    NS.addon:OnSlashCommand("rolls")
    assertFalse(NS.RollsPanel.IsShown())
end)

test("rolls panel: /dw rolls with the window closed, or the panel off, says why and shows nothing", function()
    local NS, m = inDungeon()
    m.prints = {}
    NS.addon:OnSlashCommand("rolls")
    assertFalse(NS.RollsPanel.IsShown())
    assertFalse(NS.IsWindowShown(), "it never opens the window")
    NS.SchemaRuntime.Set("rolls.panel.enabled", false)
    NS.addon:OnSlashCommand("rolls")
    local all = table.concat(m.prints, "\n")
    assertTrue(all:find("open the window first", 1, true) ~= nil, all)
    assertTrue(all:find("Drops > Rolls > Panel", 1, true) ~= nil, all)
end)

-- red under: Toggle showing an empty panel that no roll can fill while Show rolls is off
test("rolls panel: /dw rolls with Show rolls off says why and shows nothing", function()
    local NS, m = shown({ ["rolls.show"] = false })
    m.prints = {}
    NS.addon:OnSlashCommand("rolls")
    assertFalse(NS.RollsPanel.IsShown())
    local all = table.concat(m.prints, "\n")
    assertTrue(all:find("Show rolls on Drops > Rolls > Window and popup", 1, true) ~= nil, all)
end)

-- ── pure ────────────────────────────────────────────────────────────────────────────────────

test("rolls panel: Side keeps the wanted side that fits, else the other, and unknown geometry answers it", function()
    local RPR = T.enableAddon().RollsPanelRows
    assertEqual(RPR.Side("right", 200, 800, 250, 1920, 3), "right")
    assertEqual(RPR.Side("right", 1500, 1800, 250, 1920, 3), "left")
    assertEqual(RPR.Side("left", 300, 800, 250, 1920, 3), "left")
    assertEqual(RPR.Side("left", 100, 700, 250, 1920, 3), "right")
    assertEqual(RPR.Side("left", nil, nil, 250, 1920, 3), "left")
    assertEqual(RPR.Side(nil, 200, 800, 250, 1920, 3), "right")
    assertEqual(RPR.Side("right", 10, 1910, 250, 1920, 3), "right", "neither fits: the wanted side")
    assertEqual(RPR.Fraction(30, 60), 0.5); assertEqual(RPR.Fraction(nil, 60), nil); assertEqual(RPR.Fraction(70, 60), 1)
    -- beside the Offer panel (RX-20): its side taken, the other one if it fits, else none
    assertEqual(RPR.Beside("right", nil, 400, 1000, 250, 1920, 3), "right", "no Offer panel")
    assertEqual(RPR.Beside("right", "float", 400, 1000, 250, 1920, 3), "right", "a floating Offer panel takes no side")
    assertEqual(RPR.Beside("right", "right", 400, 1000, 250, 1920, 3), "left")
    assertEqual(RPR.Beside("left", "left", 400, 1000, 250, 1920, 3), "right")
    assertEqual(RPR.Beside("right", "right", 100, 700, 250, 1920, 3), nil, "no room on the left")
    assertEqual(RPR.Beside("left", "left", 1500, 1800, 250, 1920, 3), nil, "no room on the right")
    assertEqual(RPR.Beside("right", "right", nil, nil, 250, 1920, 3), "left", "unknown geometry: the other side")
end)

-- ── raid mode (rolls panel design §3.3, plan RX-18) ─────────────────────────────────────────

-- A group of `n` counting you (Compat.GroupSize answers n): a raid past five.
local function groupOf(m, n)
    local others = {}
    for i = 1, n - 1 do
        others[i] = { guid = ("Player-9-%08X"):format(i), name = "Raider" .. i, class = "Warrior", classFile = "WARRIOR" }
    end
    m.setGroup(others, n > 5)
end

local function linkOf(i) return ("|cnIQ4:|Hitem:%d::::::::90:::::|h[Item %d]|h|r"):format(300 + i, 300 + i) end

-- A roll: `need` Need (rolls 99 down), `greed` Greed (rolls 60 down), `pass` Pass and `wait` still
-- to roll (P1..), then you, on `mine` (Pass by default; 4 is still to roll).
local function bigRoll(link, need, greed, pass, wait, mine)
    local infos, n = {}, 0
    local function add(state, roll)
        n = n + 1
        infos[#infos + 1] = info("P" .. n, ("Player-8-%08X"):format(n), "MAGE", state, roll)
    end
    for i = 1, need do add(0, 100 - i) end
    for i = 1, greed do add(3, 61 - i) end
    for _ = 1, pass do add(5) end
    for _ = 1, wait do add(4) end
    infos[#infos + 1] = info("Testchar", "Player-0-00000001", "PALADIN", mine or 5, nil, true)
    return { itemHyperlink = link, playerRollState = mine or 5, isTied = false, allPassed = false,
        startTime = 100, duration = 60, rollInfos = infos }
end

local function rollWith(m, key, link, d)
    m.addItem(link, ring(620))
    m.lootHistory[key] = d
    m.__fire("LOOT_HISTORY_UPDATE_ENCOUNTER", 2900)
    return d
end

local function openHeaders(NS)
    local out = {}
    for _, h in ipairs(NS.RollsPanel.Drawn().headers) do
        if h.open then out[#out + 1] = plain(h.name:GetText()) end
    end
    return out
end

local function headerNamed(NS, name)
    for _, h in ipairs(NS.RollsPanel.Drawn().headers) do
        if plain(h.name:GetText()) == name then return h end
    end
end

local function foldOf(NS, key)
    for _, f in ipairs(NS.RollsPanel.Drawn().lines) do
        if f.fold == key then return f end
    end
end

-- red under: raid mode's one-open rule kept, or the title counting the blocks (RX-21 rulings A2, A8)
test("rolls panel: a group of 6 is raid mode, every block still open, titled Rolls; a group of 5 too", function()
    local NS, m = shown()
    groupOf(m, 6)
    rollOpens(m, "2900:1", LINK)
    rollOpens(m, "2900:2", LINK2)
    local d = NS.RollsPanel.Drawn()
    assertTrue(d.raid, "raid mode")
    assertEqual(d.panel.title:GetText(), "Rolls", "no count in the title")
    assertEqual(#openHeaders(NS), 2, "every block open in a raid")
    assertFalse(headerNamed(NS, "Item 301").counts:IsShown(), "an open header reads no count line")
    assertEqual(#lines(NS), 10, "both blocks' five players")
    groupOf(m, 5)
    NS.RollsPanel.Refresh()
    d = NS.RollsPanel.Drawn()
    assertFalse(d.raid, "five is a dungeon group")
    assertEqual(d.panel.title:GetText(), "Rolls")
    assertEqual(#openHeaders(NS), 2, "every block open")
end)

-- red under: no collapser on the item header (RX-21 ruling A2)
test("rolls panel: an item header collapses and expands its block on a click, and the collapse sticks", function()
    local NS, m = shown()
    local d1 = rollOpens(m, "2900:1", LINK)
    rollOpens(m, "2900:2", LINK2)
    local h = headerNamed(NS, "Item 300")
    assertTrue(h.open, "every item starts expanded")
    assertEqual(h.chevron:GetTexture(), NS.Icon("chevron-down"), "the open chevron")
    h:__fire("OnClick", "LeftButton")
    h = headerNamed(NS, "Item 300")
    assertFalse(h.open, "collapsed")
    assertEqual(h.chevron:GetTexture(), NS.Icon("chevron-right"), "the closed chevron")
    assertTrue(h.counts:IsShown() and h.counts:GetText() ~= "", "a collapsed header reads the count line")
    assertEqual(#lines(NS), 5, "only the other block's players")
    d1.rollInfos[5].state = 3
    d1.rollInfos[5].roll = 44
    m.__fire("LOOT_HISTORY_UPDATE_DROP", 2900, 1)
    NS.RollsPanel.Refresh()
    assertFalse(headerNamed(NS, "Item 300").open, "the manual collapse sticks while the roll is listed")
    rollOpens(m, "2900:3", "|cnIQ4:|Hitem:302::::::::90:::::|h[Item 302]|h|r")
    assertTrue(headerNamed(NS, "Item 302").open, "a new roll starts expanded")
    headerNamed(NS, "Item 300"):__fire("OnClick", "LeftButton")
    assertTrue(headerNamed(NS, "Item 300").open, "a second click expands it")
end)

-- red under: no Expand all / Collapse all on the panel's title bar (RX-21 ruling A2)
test("rolls panel: Expand all and Collapse all on the title bar open and close every item", function()
    local NS, m = shown()
    rollOpens(m, "2900:1", LINK)
    rollOpens(m, "2900:2", LINK2)
    local p = NS.RollsPanel.Drawn().panel
    assertTrue(p.expandButton ~= nil and p.collapseButton ~= nil, "both buttons")
    assertEqual(p.expandButton.art:GetTexture(), NS.Icon("chevron-down"))
    assertEqual(p.collapseButton.art:GetTexture(), NS.Icon("chevron-up"))
    p.collapseButton:__fire("OnClick", "LeftButton")
    assertEqual(#openHeaders(NS), 0, "every item collapsed")
    assertEqual(#lines(NS), 0)
    p.expandButton:__fire("OnClick", "LeftButton")
    assertEqual(#openHeaders(NS), 2, "every item expanded")
    local tip = T.tipPlainJoined(NS.Window.TooltipOf(p.expandButton))
    assertTrue(tip:find("Expand all", 1, true) ~= nil, tip)
    tip = T.tipPlainJoined(NS.Window.TooltipOf(p.collapseButton))
    assertTrue(tip:find("Collapse all", 1, true) ~= nil, tip)
end)

-- red under: the item header in the old plain look (no band, no chevron)
test("rolls panel: an item header is the section header's look: a band, a gold chevron, the icon and the name", function()
    local NS, m = shown()
    rollOpens(m)
    local h = NS.RollsPanel.Drawn().headers[1]
    assertTrue(h.fill ~= nil and h.fill:IsShown(), "the band")
    assertTrue(h.chevron ~= nil, "the chevron")
    assertTrue(h.icon:GetTexture() ~= nil, "the item icon")
    assertEqual(plain(h.name:GetText()), "Item 300")
end)

-- red under: every roller row in one wash (RX-21 ruling A5)
test("rolls panel: the roller rows alternate their shading", function()
    local NS, m = shown()
    rollOpens(m)
    local ls = NS.RollsPanel.Drawn().lines
    for i = 1, 5 do
        assertEqual(ls[i].stripe:IsShown(), i % 2 == 0, "row " .. i)
    end
end)

-- red under: a number shown on a Pass row (RX-21 ruling A6)
test("rolls panel: a roll number on Need and Greed, none on Pass or Waiting", function()
    local NS, m = shown()
    local d = openRoll()
    d.rollInfos[4].roll = 33   -- your Pass, with a number the history should not show
    m.addItem(LINK, ring(620))
    m.lootHistory["2900:1"] = d
    m.__fire("LOOT_HISTORY_UPDATE_ENCOUNTER", 2900)
    local got = lines(NS)
    assertEqual(got[1], "Brakk=87"); assertEqual(got[3], "Lyra=50")
    assertEqual(got[4], "Testchar [YOU]", "no number on a Pass")
    assertTrue(got[5]:find("=", 1, true) == nil, "none on Waiting")
end)

-- red under: no tooltips in the panel but the folds' (RX-21 ruling A7)
test("rolls panel: the item header shows the item and every roll, a row its player, choice, roll and class", function()
    local NS, m = shown()
    rollOpens(m)
    local h = NS.RollsPanel.Drawn().headers[1]
    m.tooltipLinks = {}
    h:__fire("OnEnter")
    assertEqual(m.tooltipLinks[1], LINK, "the item's own tooltip")
    local all = {}
    for _, l in ipairs(m.GameTooltip.__lines) do all[#all + 1] = plain(l.text) end
    local joined = table.concat(all, " / ")
    assertTrue(joined:find("Need", 1, true) ~= nil and joined:find("Brakk", 1, true) ~= nil, joined)
    assertTrue(joined:find("Click to collapse", 1, true) ~= nil, joined)
    h:__fire("OnLeave")
    local row = NS.RollsPanel.Drawn().lines[1]
    local tip = T.tipPlainJoined(NS.Window.TooltipOf(row))
    for _, want in ipairs({ "Brakk", "Need", "87", "Warrior" }) do
        assertTrue(tip:find(want, 1, true) ~= nil, want .. " in " .. tip)
    end
    local close = T.tipPlainJoined(NS.Window.TooltipOf(NS.RollsPanel.Drawn().panel.closeButton))
    assertTrue(close:find("Close the Rolls panel", 1, true) ~= nil, close)
end)

-- red under: Pass and Waiting listed a row per player in a raid
test("rolls panel: in a raid Pass and Waiting fold to a line each, hovering lists every name, a click unfolds", function()
    local NS, m = shown()
    groupOf(m, 8)
    rollWith(m, "2900:1", LINK, bigRoll(LINK, 2, 1, 3, 2))   -- you pass too: Pass 4
    local got = lines(NS)
    assertEqual(#got, 5, "two Need, one Greed, the Pass line, the Waiting line: " .. table.concat(got, " / "))
    local pass = foldOf(NS, "pass")
    assertTrue(pass ~= nil, "the Pass line")
    assertEqual(plain(pass.text:GetText()), "Pass 4 · P4, P5, P6…")
    assertTrue(foldOf(NS, "waiting") ~= nil, "the Waiting line")
    local tip = T.tipPlainJoined(NS.Window.TooltipOf(pass))
    for _, name in ipairs({ "P4", "P5", "P6", "Testchar" }) do
        assertTrue(tip:find(name, 1, true) ~= nil, name .. " in " .. tip)
    end
    pass:__fire("OnMouseUp", "LeftButton")
    got = lines(NS)
    assertEqual(#got, 8, "Pass unfolded: four rows in its place")
    assertTrue(foldOf(NS, "pass") == nil and foldOf(NS, "waiting") ~= nil, "Waiting stays folded")
    NS.SchemaRuntime.Set("rolls.panel.foldInRaid", false)
    NS.RollsPanel.Refresh()
    assertEqual(#lines(NS), 9, "the setting off lists all nine players")
    assertTrue(foldOf(NS, "waiting") == nil)
end)

-- red under: raid mode read from the group's size alone
test("rolls panel: a roll of more than five rollers is raid mode whatever the group's size reads", function()
    local NS, m = shown()
    groupOf(m, 5)
    rollWith(m, "2900:1", LINK, bigRoll(LINK, 2, 2, 1, 1))   -- six rollers, you among them
    local d = NS.RollsPanel.Drawn()
    assertTrue(d.raid, "six on the roll: a raid's")
    assertEqual(d.panel.title:GetText(), "Rolls")
    assertTrue(NS.RollsPanelRows.IsRaid(6) and not NS.RollsPanelRows.IsRaid(5))
    assertFalse(NS.RollsPanelRows.IsRaid(nil))
end)

test("rolls panel: a dungeon group never folds", function()
    local NS, m = shown()
    groupOf(m, 5)
    rollWith(m, "2900:1", LINK, bigRoll(LINK, 1, 1, 2, 0))
    assertTrue(foldOf(NS, "pass") == nil)
    assertEqual(#lines(NS), 5)
end)

-- red under: a frame made per repaint, or the panel growing past the window
test("rolls panel: 40 players on 6 items fit, all open, the body scrolls, and a repaint makes no frame", function()
    local NS, m = shown()
    groupOf(m, 40)
    for i = 0, 5 do rollWith(m, "2900:" .. (i + 1), linkOf(i), bigRoll(linkOf(i), 20, 10, 5, 4)) end
    local d = NS.RollsPanel.Drawn()
    assertEqual(#d.headers, 6)
    assertEqual(d.panel.title:GetText(), "Rolls")
    assertEqual(#openHeaders(NS), 6, "every item open in a 40-player group")
    assertEqual(#lines(NS), 6 * 32, "per item twenty Need, ten Greed and the two folded lines")
    assertTrue(d.panel:GetHeight() <= 400, "never taller than the window")
    assertTrue(d.panel.overflow, "the body scrolls")
    local made, create = 0, m.CreateFrame
    m.CreateFrame = function(...)
        made = made + 1
        return create(...)
    end
    for _ = 1, 3 do NS.RollsPanel.Refresh() end
    headerNamed(NS, "Item 303"):__fire("OnClick", "LeftButton")
    headerNamed(NS, "Item 303"):__fire("OnClick", "LeftButton")
    m.CreateFrame = create
    assertEqual(made, 0, "every header and line from the pools")
end)

test("rolls panel: the compact layout is 250 wide, the full one 290", function()
    local NS, m = shown()
    rollOpens(m)
    local p = NS.RollsPanel.Drawn().panel
    assertEqual(p:GetWidth(), 290)
    NS.SetWindowMode("compact")
    NS.RollsPanel.Refresh()
    assertEqual(p:GetWidth(), 250)
    NS.SetWindowMode("full")
    NS.RollsPanel.Refresh()
    assertEqual(p:GetWidth(), 290)
end)
