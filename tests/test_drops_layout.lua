-- tests/test_drops_layout.lua — the Drops table's geometry (feedback-4 spec §4, feedback-5 spec §0
-- and §4): the least width at which no tab sheds a column, the search box's anchors, the gold column
-- labels, the Actions width, each drop row's muted-white chevron and indent under its header, and
-- the header's gold chevron. Built headless under the mock. Split from test_window_group.lua, which
-- covers the cells, the column sets, the entry order and the table's behavior.

local T = _G.DW_TEST
local test, assertEqual, assertTrue = T.test, T.assertEqual, T.assertTrue

local LINK = "|cffa335ee|Hitem:212::|h[Crown of Roaring Storms]|h|r"
local RING = "|cffa335ee|Hitem:213::|h[Band of Embers]|h|r"

-- An override that removes a field.
local NONE = {}

-- A judged drop as the feed records it (test_window_group's): an upgrade for you, a downgrade for
-- its looter, likely tradeable, the looter inspected 40s before t = 100.
local function drop(over)
    local d = {
        id = 1, at = 100, link = LINK, isMine = false, sources = { chat = 1 },
        looter = { name = "Seta-Realm", guid = "Player-1-0000000A", classFile = "PRIEST" },
        facts = { ilvl = 311, equipLoc = "INVTYPE_HEAD", quality = 4, track = { name = "Hero", rank = 2, max = 6 } },
        me = { verdict = "upgrade", ilvlDelta = 19, reasons = {} },
        them = { verdict = "downgrade", ilvlDelta = -13, reasons = {} },
        trade = { state = "likely", reasonKey = "notUpgrade", args = { 311, 324 }, basis = "inspect", age = 40 },
        inspect = { status = "fresh", at = 60 },
    }
    for k, v in pairs(over or {}) do
        if v == NONE then d[k] = nil else d[k] = v end
    end
    return d
end

-- Answer `drops` (each group listing its ids) from the feed, for every feed name.
local function seed(NS, groups, drops)
    local byId = {}
    for _, d in ipairs(drops) do byId[d.id] = d end
    NS.LootFeed.Groups = function() return groups end
    NS.LootFeed.Get = function(id) return byId[id] end
    NS.LootFeed.Drops = function() return drops end
end

local GROUP = { key = "enc:3", label = "Boss 3", kind = "encounter", situation = "dungeon", at = 90, drops = { 1, 2 } }

local function shownTable()
    local NS, _, m = T.enableAddon()
    m.__now = 100
    local d2 = drop({ id = 2, link = RING, looter = { name = "Littlewolf-Realm", guid = "Player-1-0000000B", classFile = "ROGUE" },
        facts = { ilvl = 298, equipLoc = "INVTYPE_FINGER", quality = 4 },
        me = { verdict = "sidegrade", ilvlDelta = 4, reasons = {} }, them = NONE, inspect = { status = "outOfRange" },
        trade = { state = "unknown", reasonKey = "noInspect", args = { "outOfRange" } } })
    seed(NS, { GROUP }, { drop(), d2 })
    NS.WindowFilterBar.Set("group", "view", "all")
    NS.ShowWindow()
    return NS, NS.WindowGroup.Drawn(), m
end

local function rowFor(drawn, id)
    for _, r in ipairs(drawn.rows) do if r.dropId == id then return r end end
end

-- ── the least width, the search box and the headers (feedback-4 spec §4) ────────────────────

test("layout: at the least width no tab sheds a column, and one pixel less would shed on Drops", function()
    local NS = T.newAddon()
    local K = NS.Constants.WINDOW
    assertEqual(K.MIN_WIDTH, K.WIDTH, "the least width is a new profile's width")
    assertEqual(K.COMPACT_MIN_W, K.COMPACT_WIDTH, "in both layouts")
    local row = K.MIN_WIDTH - 2 * K.INSET - K.SCROLL_W
    -- Drops' columns start after the row's indent and chevron (feedback-5 spec §0).
    local lead = { WindowGroup = NS.WindowGroup.LEAD, WindowHistory = 0 }
    for _, tab in ipairs({ "WindowGroup", "WindowHistory" }) do
        local cols = NS[tab].COLUMNS
        assertEqual(#NS.WindowGroup.Fit(cols, row - lead[tab]), #cols, tab .. " keeps every column")
    end
    local groupRow = row - NS.WindowGroup.LEAD
    assertTrue(#NS.WindowGroup.Fit(NS.WindowGroup.COLUMNS, groupRow - 1) < #NS.WindowGroup.COLUMNS,
        "the least width is the tightest that fits Drops")
    assertTrue(NS.WindowFilterBar.SearchWidth(K.MIN_WIDTH) >= 200, "the search box has room to type")
end)

-- Every answer the Trade window cell can give (MineCells.TradeWindow): each short reason in
-- NO_SHORT on your drop and another player's, the reason it has no short word for, bind on
-- equip, not estimated yet, and the longest countdown, exact and estimated.
local function tradeWindowAnswers(MC, C)
    local now, texts = 1000, {}
    local function add(over) texts[#texts + 1] = MC.TradeWindow(drop(over), now, 600).text end
    local keys = {}
    for key in pairs(MC.NO_SHORT) do keys[#keys + 1] = key end
    for key in pairs(MC.NO_SHORT_THEIRS) do keys[#keys + 1] = key end
    keys[#keys + 1] = "someReasonWithNoShortWord"
    for _, key in ipairs(keys) do
        for _, mine in ipairs({ true, false }) do
            add({ isMine = mine, trade = { state = "no", reasonKey = key, basis = "rule", args = { 311 } } })
        end
    end
    add({ trade = { state = "yes", reasonKey = "boe", basis = "bind" } })
    add({ trade = NONE })
    add({ isMine = true, at = now, trade = { state = "yes", reasonKey = "timer", basis = "timer",
        expiresAt = now + C.TRADE_WINDOW } })
    add({ at = now })
    return texts
end

test("layout: the Trade window column is its widest answer plus its bar's padding (feedback-6 spec §0)", function()
    local NS = T.newAddon()
    local WG, MC, CHAR = NS.WindowGroup, NS.MineCells, 5   -- the harness's character measure
    local seen, widest, widestText = {}, 0, nil
    for _, text in ipairs(tradeWindowAnswers(MC, NS.Constants)) do
        seen[text] = true
        if #text * CHAR > widest then widest, widestText = #text * CHAR, text end
    end
    for _, want in ipairs({ "~2:00:00", "2:00:00", "Their upgrade", "Your upgrade", "No limit (BoE)", "Bonus roll",
        "Window passed", "Legacy loot", "Warbound", "Not loaded", "Checking", "Not tradeable" }) do
        assertTrue(seen[want], want .. " is one of its answers")
    end
    assertEqual(widestText, "No limit (BoE)", "the widest answer")
    for _, col in ipairs(WG.COLUMNS) do
        if col.key == "tradeWindow" then
            assertEqual(col.width, widest + WG.TRADE_WINDOW_PAD, "no empty margin, nothing cut")
        end
    end
end)

test("layout: the search box spans from the bar's gap after Character to the bar's right edge", function()
    local NS = shownTable()
    local FB, K = NS.WindowFilterBar, NS.Constants.WINDOW
    local c = FB.Controls()
    assertEqual(c.search.__points[1][1], "LEFT"); assertEqual(c.search.__points[1][2], c.char)
    assertEqual(c.search.__points[1][4], 8)
    assertEqual(c.search.__points[2][1], "RIGHT"); assertEqual(c.search.__points[2][2], c.host)
    assertEqual(FB.SearchWidth(K.MIN_WIDTH + 300) - FB.SearchWidth(K.MIN_WIDTH), 300, "it takes all the width gained")
    assertTrue(c.search:IsShown())
end)

test("layout: the column labels are gold on both full tables", function()
    local NS = shownTable()
    local G = NS.Constants.GOLD
    local function gold(label) return select(2, label.text:GetTextColor()) == G.g end
    assertTrue(gold(NS.WindowGroup.Drawn().pane.colHead.labels.item), "Drops")
    NS.Window.SelectTab("history")
    assertTrue(gold(NS.Window.Frame().panes.history.colHead.labels.item), "History")
end)

-- ── the expand indicator, the indent and the Actions width (feedback-5 spec §0) ─────────────

local function xOf(frame) return select(4, frame:GetPoint(1)) end

test("layout: Actions is 84 pixels, the Ask button's width, so every state's icon and word fits", function()
    local NS = T.newAddon()
    local K = NS.Constants.WINDOW
    assertEqual(K.ASK_W, 84)
    for _, col in ipairs(NS.WindowGroup.COLUMNS) do
        if col.key == "actions" then assertEqual(col.width, K.ASK_W, "the column is the button's width") end
    end
end)

test("rows: each row draws the header's chevron at its left, muted white, down while closed and up while open", function()
    local NS, drawn = shownTable()
    local K, C = NS.Constants.WINDOW, NS.Constants
    local row = rowFor(drawn, 1)
    assertTrue(row.expander == nil, "the right-edge mark is gone")
    local ch = row.chevron
    assertEqual(ch:GetTexture(), NS.Icon("chevron-down"), "collapsed")
    assertEqual(ch.__points[1][1], "LEFT"); assertEqual(ch.__points[1][2], row)
    assertEqual(ch.__points[1][4], K.CHEVRON_X, "at the row's left edge, as the header's")
    local r, g, b, a = ch:GetVertexColor()
    assertEqual(table.concat({ r, g, b, a }, ","), table.concat({ C.CHEVRON_ROW.r, C.CHEVRON_ROW.g,
        C.CHEVRON_ROW.b, C.CHEVRON_ROW.a }, ","))
    assertTrue(r == 1 and g == 1 and b == 1 and a > 0.4 and a < 0.7, "white at about 55%")
    row:__fire("OnClick", "LeftButton")
    ch = rowFor(NS.WindowGroup.Drawn(), 1).chevron
    assertEqual(ch:GetTexture(), NS.Icon("chevron-up"), "open")
    assertEqual(select(4, ch:GetVertexColor()), C.CHEVRON_ROW.a, "the same tint while open")
end)

test("rows: the Item cell starts after the chevron and a 4px gap; the chevron is no column", function()
    local NS, drawn = shownTable()
    local K, WG = NS.Constants.WINDOW, NS.WindowGroup
    assertEqual(WG.CHEVRON_LEAD, K.CHEVRON_X + K.ROW_CHEVRON + 4)
    assertEqual(WG.LEAD, K.ROW_INDENT + WG.CHEVRON_LEAD)
    assertEqual(xOf(rowFor(drawn, 1).cells.item), WG.CHEVRON_LEAD)
    for _, col in ipairs(WG.COLUMNS) do assertTrue(col.key ~= "chevron", "not a column") end
    assertTrue(drawn.pane.colHead.labels.chevron == nil, "no label")
end)

test("rows: every drop row and its detail card sit ROW_INDENT in from the header; the labels shift over their cells", function()
    local NS, drawn = shownTable()
    local K = NS.Constants.WINDOW
    assertEqual(K.ROW_INDENT, 12)
    local h = drawn.headers[1]
    assertEqual(xOf(h), 0, "the header keeps the full width")
    local row = rowFor(drawn, 1)
    assertEqual(xOf(row), K.ROW_INDENT)
    assertEqual(row:GetWidth(), h:GetWidth() - K.ROW_INDENT, "the row ends where the header does")
    local labels = drawn.pane.colHead.labels
    for _, key in ipairs({ "item", "slot", "looter", "trade", "actions" }) do
        assertEqual(xOf(labels[key]), K.ROW_INDENT + xOf(row.cells[key]), key .. "'s label over its cell")
    end
    NS.WindowGroup.ToggleExpand(1)
    drawn = NS.WindowGroup.Drawn()
    assertEqual(xOf(drawn.card), K.ROW_INDENT, "the detail card indents with its row")
    assertEqual(drawn.card:GetWidth(), rowFor(drawn, 1):GetWidth())
end)

test("headers: a group header's chevron is gold, as its text, collapsed or open", function()
    local NS, drawn = shownTable()
    local G = NS.Constants.GOLD
    local h = drawn.headers[1]
    local r, g, b = h.chevron:GetVertexColor()
    assertEqual(table.concat({ r, g, b }, ","), table.concat({ G.r, G.g, G.b }, ","))
    h:__fire("OnClick", "LeftButton")
    h = NS.WindowGroup.Drawn().headers[1]
    assertEqual(h.chevron:GetTexture(), NS.Icon("chevron-right"), "collapsed")
    assertEqual(select(2, h.chevron:GetVertexColor()), G.g, "still gold")
end)
