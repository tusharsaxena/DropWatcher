-- tests/test_rolls_panel.lua — modules/RollsPanel.lua and modules/RollsPanelRows.lua, the Rolls
-- panel docked beside the window (rolls panel design §3.1, §3.2, §3.4, §3.5; plan RX-17): docked
-- right (or Left), flipped near the screen's edge; shown on a watched roll while the window is shown,
-- not on a filtered roll, not with the window closed; rows grouped Need, Greed, Disenchant (Retail
-- only), Pass, still to roll, highest first, `[YOU]` on yours; the winner washed gold and the result
-- line; a block leaves after the linger (0 at once), the pointer over the panel holds it; the
-- window's auto-close waits while it lingers; the setting off shows nothing; `/dw rolls` toggles.
-- Raid mode (design §3.3, RX-18): a group past five opens one block (a click, your pending roll, the
-- soonest ending), titles `Rolls · N`, folds Pass and Waiting, scrolls, and repaints from the pools;
-- the compact layout is 220 wide.
-- Rolls are a both-clients feature, so every case runs on both kit profiles.

local T = _G.DW_TEST
local test, assertEqual, assertTrue, assertFalse = T.test, T.assertEqual, T.assertTrue, T.assertFalse

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

-- ── showing ─────────────────────────────────────────────────────────────────────────────────

-- red under: no PendingChanged receiver (the panel never shows)
test("rolls panel: a watched roll shows it docked right of the shown window, titled Rolls", function()
    local NS, m, w = shown()
    assertFalse(NS.RollsPanel.IsShown(), "nothing before the roll")
    rollOpens(m)
    assertTrue(NS.RollsPanel.IsShown(), "the roll shows it")
    local p = NS.RollsPanel.Drawn().panel
    assertEqual(p:GetParent(), w, "a child of the window: it hides, scales and fades with it")
    assertEqual(p.dock, "right")
    local point, rel, relPoint, x, y = p:GetPoint(1)
    assertEqual(point .. ">" .. relPoint, "TOPLEFT>TOPRIGHT"); assertTrue(rel == w); assertEqual(x, 3); assertEqual(y, 0)
    assertEqual(p:GetWidth(), 250)
    assertEqual(p.title:GetText(), "Rolls")
    assertEqual(#NS.RollsPanel.Drawn().headers, 1, "one block")
    assertEqual(plain(NS.RollsPanel.Drawn().headers[1].name:GetText()), "Item 300")
end)

test("rolls panel: near the screen's right edge it flips left, and the Left setting docks left", function()
    local NS, m, w = shown(nil, 1500, 1800)
    rollOpens(m)
    local p = NS.RollsPanel.Drawn().panel
    assertEqual(p.dock, "left", "1800 + 3 + 250 is past 1920")
    local point, rel, relPoint, x = p:GetPoint(1)
    assertEqual(point .. ">" .. relPoint, "TOPRIGHT>TOPLEFT"); assertTrue(rel == w); assertEqual(x, -3)
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

test("rolls panel: rows grouped Need, Greed, Pass, still to roll, highest first, [YOU] on yours, verdict at the foot", function()
    local NS, m = shown()
    rollOpens(m)
    local got = lines(NS)
    assertEqual(got[1], "Brakk=87"); assertEqual(got[2], "Seta=12"); assertEqual(got[3], "Lyra=50")
    assertEqual(got[4], "Testchar [YOU]", "your Pass, with [YOU]")
    assertTrue(got[5]:find("Tor", 1, true) ~= nil, "still to roll last")
    assertEqual(#got, 6, "five players and the foot")
    assertTrue(got[6]:find("Upgrade", 1, true) ~= nil, "your verdict at the foot: " .. got[6])
    local hd = NS.RollsPanel.Drawn().headers[1]
    m.lootHistoryTime = 118
    NS.RollsPanel.Refresh()
    assertEqual(hd.time:GetText(), "0:42", "the time left")
    assertTrue(hd.bar:IsShown(), "the countdown bar under an open roll")
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
    assertEqual(got[#got - 1], "Won by Brakk (Need 87)")
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

test("rolls panel: two rolls are two blocks in the order they started; the first leaving keeps the second", function()
    local NS, m = shown()
    local d1 = rollOpens(m, "2900:1", LINK)
    m.advance(1)
    rollOpens(m, "2900:2", LINK2)
    assertEqual(#NS.RollsPanel.Drawn().headers, 2)
    assertEqual(plain(NS.RollsPanel.Drawn().headers[1].name:GetText()), "Item 300")
    assertEqual(plain(NS.RollsPanel.Drawn().headers[2].name:GetText()), "Item 301")
    win(m, d1, 1)
    m.advance(10.1)
    assertEqual(#NS.RollsPanel.Drawn().headers, 1)
    assertEqual(plain(NS.RollsPanel.Drawn().headers[1].name:GetText()), "Item 301")
    assertTrue(NS.RollsPanel.IsShown())
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

-- red under: settle() lingering a test sample the store dropped, and `left` keeping its recycled id
test("rolls panel: test mode's samples leave at once when it ends, and show again when it comes back", function()
    local NS, m = shown()
    m.seedGearJournal()
    local function quietly(fn)
        local p = m.print
        m.print = function() end
        fn()
        m.print = p
    end
    -- RX-19 wires test mode to the panel; here any later PendingChanged reads the samples in
    quietly(function() NS.SetTestMode(true) end)
    NS.RollsPanel.Refresh()
    local n = #NS.RollsPanel.Drawn().blocks
    assertTrue(n > 0, "test mode's samples fill the panel")
    quietly(function() NS.SetTestMode(false) end)
    assertFalse(NS.RollsPanel.HasBlocks(), "no linger for samples the store dropped")
    quietly(function() NS.SetTestMode(true) end)
    NS.RollsPanel.Refresh()
    assertEqual(#NS.RollsPanel.Drawn().blocks, n, "the samples' recycled ids join again")
    quietly(function() NS.SetTestMode(false) end)
end)

-- ── auto-close ──────────────────────────────────────────────────────────────────────────────

-- red under: WindowAutoClose's idle() not asking RollsPanel.HasBlocks
test("rolls panel: an auto-opened window waits while the panel lingers, then a full count", function()
    local NS, m = inDungeon()
    local d = rollOpens(m)
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

-- red under: no raid mode (every block open, the title `Rolls`)
test("rolls panel: a group of 6 is raid mode (one block open, titled Rolls · N); a group of 5 opens every block", function()
    local NS, m = shown()
    groupOf(m, 6)
    rollOpens(m, "2900:1", LINK)
    rollOpens(m, "2900:2", LINK2)
    local d = NS.RollsPanel.Drawn()
    assertTrue(d.raid, "raid mode")
    assertEqual(d.panel.title:GetText(), "Rolls · 2")
    assertEqual(#openHeaders(NS), 1, "exactly one block open")
    local closed = headerNamed(NS, "Item 301")
    assertFalse(closed.open)
    assertTrue(closed.counts:IsShown() and closed.counts:GetText() ~= "", "a closed header reads the count line")
    assertEqual(#lines(NS), 6, "the open block's five players and its foot; the closed one has no lines")
    groupOf(m, 5)
    NS.RollsPanel.Refresh()
    d = NS.RollsPanel.Drawn()
    assertFalse(d.raid, "five is a dungeon group")
    assertEqual(d.panel.title:GetText(), "Rolls")
    assertEqual(#openHeaders(NS), 2, "every block open")
    assertFalse(headerNamed(NS, "Item 301").counts:IsShown())
end)

-- red under: the open block picked by start order alone, or a click not sticking
test("rolls panel: raid mode opens your pending roll, else the soonest ending; a clicked header sticks until it resolves", function()
    local NS, m = shown()
    groupOf(m, 6)
    m.lootHistoryTime = 110
    local d1 = rollOpens(m, "2900:1", LINK)           -- ends at 160
    local d2 = openRoll(LINK2)
    d2.duration = 30                                  -- ends at 130: the soonest
    rollWith(m, "2900:2", LINK2, d2)
    assertEqual(openHeaders(NS)[1], "Item 301", "nothing pending for you: the soonest ending")
    d1.playerRollState, d1.rollInfos[4].state = 4, 4
    m.__fire("LOOT_HISTORY_UPDATE_DROP", 2900, 1)
    assertEqual(openHeaders(NS)[1], "Item 300", "the one you still have to roll on")
    headerNamed(NS, "Item 301"):__fire("OnMouseUp", "LeftButton")
    assertEqual(openHeaders(NS)[1], "Item 301", "the clicked header opens")
    m.lootHistoryTime = 112
    NS.RollsPanel.Refresh()
    assertEqual(openHeaders(NS)[1], "Item 301", "and stays open")
    win(m, d2, 2)
    assertEqual(openHeaders(NS)[1], "Item 300", "resolved: the rule picks again")
    local done = headerNamed(NS, "Item 301")
    assertTrue(done.dim, "a resolved block is a dimmed header")
    assertEqual(plain(done.counts:GetText()), "Won by Brakk (Need 87)", "showing the winner and the roll")
    assertEqual(done.time:GetText(), "done")
    headerNamed(NS, "Item 301"):__fire("OnMouseUp", "LeftButton")
    assertEqual(openHeaders(NS)[1], "Item 300", "a resolved header does not open")
end)

-- red under: Pass and Waiting listed a row per player in a raid
test("rolls panel: in a raid Pass and Waiting fold to a line each, hovering lists every name, a click unfolds", function()
    local NS, m = shown()
    groupOf(m, 8)
    rollWith(m, "2900:1", LINK, bigRoll(LINK, 2, 1, 3, 2))   -- you pass too: Pass 4
    local got = lines(NS)
    assertEqual(#got, 6, "two Need, one Greed, the Pass line, the Waiting line, the foot: " .. table.concat(got, " / "))
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
    assertEqual(#got, 9, "Pass unfolded: four rows in its place")
    assertTrue(foldOf(NS, "pass") == nil and foldOf(NS, "waiting") ~= nil, "Waiting stays folded")
    NS.SchemaRuntime.Set("rolls.panel.foldInRaid", false)
    NS.RollsPanel.Refresh()
    assertEqual(#lines(NS), 10, "the setting off lists all nine players")
    assertTrue(foldOf(NS, "waiting") == nil)
end)

test("rolls panel: a dungeon group never folds", function()
    local NS, m = shown()
    groupOf(m, 5)
    rollWith(m, "2900:1", LINK, bigRoll(LINK, 1, 1, 2, 0))
    assertTrue(foldOf(NS, "pass") == nil)
    assertEqual(#lines(NS), 6)
end)

-- red under: a frame made per repaint, or the panel growing past the window
test("rolls panel: 40 players on 6 items fit, the body scrolls, and a repaint makes no frame", function()
    local NS, m = shown()
    groupOf(m, 40)
    for i = 0, 5 do rollWith(m, "2900:" .. (i + 1), linkOf(i), bigRoll(linkOf(i), 20, 10, 5, 4)) end
    local d = NS.RollsPanel.Drawn()
    assertEqual(#d.headers, 6)
    assertEqual(d.panel.title:GetText(), "Rolls · 6")
    assertEqual(#openHeaders(NS), 1)
    assertEqual(#lines(NS), 33, "twenty Need, ten Greed, the two folded lines and the foot")
    assertTrue(d.panel:GetHeight() <= 400, "never taller than the window")
    assertTrue(d.panel.overflow, "the body scrolls")
    local made, create = 0, m.CreateFrame
    m.CreateFrame = function(...)
        made = made + 1
        return create(...)
    end
    for _ = 1, 3 do NS.RollsPanel.Refresh() end
    headerNamed(NS, "Item 303"):__fire("OnMouseUp", "LeftButton")
    m.CreateFrame = create
    assertEqual(made, 0, "every header and line from the pools")
end)

test("rolls panel: the compact layout is 220 wide, the full one 250", function()
    local NS, m = shown()
    rollOpens(m)
    local p = NS.RollsPanel.Drawn().panel
    assertEqual(p:GetWidth(), 250)
    NS.SetWindowMode("compact")
    NS.RollsPanel.Refresh()
    assertEqual(p:GetWidth(), 220)
    NS.SetWindowMode("full")
    NS.RollsPanel.Refresh()
    assertEqual(p:GetWidth(), 250)
end)

test("rolls panel: PickOpen keeps a live click, then your pending roll, then the soonest ending", function()
    local RPR = T.enableAddon().RollsPanelRows
    assertFalse(RPR.IsRaid(5)); assertTrue(RPR.IsRaid(6)); assertFalse(RPR.IsRaid(nil))
    local list = {
        { id = "a", left = 50 }, { id = "b", left = 20 }, { id = "c", left = 40, pending = true },
        { id = "d", done = true, left = 1 },
    }
    assertEqual(RPR.PickOpen(list, nil), "c", "your pending roll")
    list[3].pending = false
    assertEqual(RPR.PickOpen(list, nil), "b", "the soonest ending")
    assertEqual(RPR.PickOpen(list, "a"), "a", "a click sticks")
    assertEqual(RPR.PickOpen(list, "d"), "b", "not on a resolved block")
    assertEqual(RPR.PickOpen({ { id = "x" }, { id = "y", left = 9 } }, nil), "y", "a known time before none")
    assertEqual(RPR.PickOpen({ { id = "x" }, { id = "y" } }, nil), "x", "no times: the first")
    assertEqual(RPR.PickOpen({ { id = "x", done = true } }, nil), nil, "all resolved: none open")
end)
