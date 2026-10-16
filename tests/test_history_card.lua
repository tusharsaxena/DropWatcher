-- tests/test_history_card.lua — the History tab's detail card (feedback-15 spec §4, DW-Q4): the card's
-- words drawn from a kept entry's snapshot (NS.HistoryCard.Model, pure: the header's chips, For you
-- at the time, For the group, the recorded trade estimate, when and where, the actions), then the card
-- built headless under the mock in both layouts: a row (or compact card) click expands it under the
-- row with the chevron up, one row at a time, the rows below moving down by its height; its actions
-- link the item, mark or clear declined and, while the drop is live, show it in the Drops tab.
-- red under: no NS.HistoryCard, no chevron on a History row, a row click expanding nothing.

local T = _G.DW_TEST
local test, assertEqual, assertTrue, assertFalse, assertNil =
    T.test, T.assertEqual, T.assertTrue, T.assertFalse, T.assertNil

local DAY = 86400

local function link(id) return ("|cffa335ee|Hitem:%d::|h[Item %d]|h|r"):format(id, id) end

local function entry(over)
    local e = { itemLink = link(500), itemID = 500, looter = "Brakk-Otherrealm", class = "WARRIOR", outcome = "seen",
        at = 1, seenBy = "Testchar-Testrealm", seenByClass = "MAGE", ilvl = 610, equipLoc = "INVTYPE_NECK", quality = 4,
        me = { verdict = "upgrade", ilvlDelta = 6, scoreDelta = 2.4 }, them = { verdict = "downgrade", ilvlDelta = -4 },
        trade = { state = "likely", reasonKey = "notUpgrade", basis = "inspect", args = { 610, 614 } } }
    for k, v in pairs(over or {}) do e[k] = v end
    return e
end

local GROUP = { key = "g@1", label = "Ulgrax", kind = "encounter", situation = "raid", instance = "Nerub-ar Palace",
    difficulty = "Heroic", seenBy = "Testchar-Testrealm", seenByClass = "MAGE" }

local function textOf(region) return region and region:GetText() end

local function byKey(list, key)
    for _, x in ipairs(list) do if x.key == key then return x end end
end

local function rowTexts(side)
    local out = {}
    for _, r in ipairs(side.rows) do out[#out + 1] = r.label .. "=" .. T.marks(r.text) end
    return table.concat(out, ", ")
end

local function model(NS, e, ctx)
    local d = NS.WindowHistory.AsDrop(e, 1, GROUP)
    ctx = ctx or {}
    ctx.nowEpoch = ctx.nowEpoch or 1 + 2 * DAY
    ctx.dateFn = ctx.dateFn or function(fmt, t) return fmt .. "@" .. tostring(t) end
    ctx.situationLabel = ctx.situationLabel or "Raid"
    return NS.HistoryCard.Model(d, ctx)
end

-- ── the words (pure) ────────────────────────────────────────────────────────────────────────

test("history card: the header's chips name slot, type, item level and the outcome in its tone", function()
    local NS = T.newAddon()
    local m = model(NS, entry({ outcome = "expired" }))
    local texts = {}
    for _, c in ipairs(m.chips) do texts[#texts + 1] = c.text end
    assertEqual(table.concat(texts, ","), "Neck,Jewelry,ilvl 610,Expired")
    assertEqual(m.chips[4].tone, "red", "the outcome's own tone")
    assertEqual(m.chips[4].tip[1], "Outcome: Expired")
    -- red under: a chip that keeps the table cell's right-click hint (the card has no row menu)
    for _, line in ipairs(m.chips[4].tip) do assertNil(tostring(line):find("Right%-click"), line) end
    for _, c in ipairs(m.chips) do assertTrue(#c.tip >= 1, c.text .. " has a tooltip") end
end)

test("history card: For you is the verdict then, with its deltas, marked at the time", function()
    local NS = T.newAddon()
    local m = model(NS, entry())
    assertEqual(m.me.title, "FOR YOU · AT THE TIME")
    assertEqual(T.marks(m.me.verdict.text), "[arrow-up] UPGRADE")
    assertEqual(rowTexts(m.me), "Item level=+6, Score=+2.4")
    assertEqual(byKey(m.me.rows, "ilvl").tone, "good")
    local none = model(NS, entry({ me = { verdict = "sidegrade" } }))
    assertEqual(rowTexts(none.me), "Item level=–, Score=–", "nothing kept says so")
    assertTrue(#byKey(none.me.rows, "score").tip >= 2)
end)

test("history card: For the group names the looter and the Them verdict with its deltas", function()
    local NS = T.newAddon()
    local m = model(NS, entry())
    assertEqual(m.them.title, "FOR THE GROUP")
    assertEqual(T.marks(m.them.verdict.text), "[arrow-down] DOWNGRADE")
    assertEqual(rowTexts(m.them), "Looter=Brakk, Item level=-4, Score=–")
    assertEqual(byKey(m.them.rows, "looter").classFile, "WARRIOR")
    local unread = model(NS, entry({ them = false }))
    assertEqual(unread.them.verdict.text, "UNKNOWN")
end)

test("history card: on your own drop the looter is you and the upgrade list is not kept", function()
    local NS = T.newAddon()
    local m = model(NS, entry({ isMine = true, looter = "Testchar-Testrealm", class = "MAGE", them = false }))
    local looter = byKey(m.them.rows, "looter")
    assertEqual(looter.text, "Testchar"); assertEqual(looter.you, "[YOU]")
    local them = byKey(m.them.rows, "them")
    assertEqual(them.text, "–")
    assertTrue(them.tip[2]:find("not kept", 1, true) ~= nil, them.tip[2])
end)

test("history card: the trade box is the recorded estimate in the Drops card's words", function()
    local NS = T.newAddon()
    local m = model(NS, entry())
    assertEqual(m.trade.chip.text, "LIKELY TRADEABLE")
    assertEqual(m.trade.text, "Personal loot: 610 is not an upgrade over the 614 Brakk wears, so they may trade it.")
    assertEqual(m.trade.meta, "Basis: inspect")
    local none = model(NS, entry({ trade = false }))
    assertEqual(none.trade.chip.text, "TRADE UNKNOWN")
end)

test("history card: when and where reads the time, the place and the character that saw it", function()
    local NS = T.newAddon()
    local m = model(NS, entry())
    assertEqual(m.where.title, "WHEN AND WHERE")
    assertNil(m.where.verdict, "no verdict chip")
    assertEqual(rowTexts(m.where), "When=%Y-%m-%d %H:%M@1 · 2 days ago, Where=Nerub-ar Palace · Ulgrax · Heroic, Seen by=Testchar")
    assertEqual(byKey(m.where.rows, "seenBy").classFile, "MAGE")
    local old = model(NS, entry({ seenBy = false, seenByClass = false }))
    assertEqual(byKey(old.where.rows, "seenBy").text, "Testchar", "the group's recorder")
end)

test("history card: the actions link, mark or clear declined, and show the drop while it is live", function()
    local NS = T.newAddon()
    local acts = model(NS, entry()).actions
    assertEqual(#acts, 3)
    assertEqual(byKey(acts, "link").text, "Link in chat"); assertTrue(byKey(acts, "link").enabled)
    assertEqual(byKey(acts, "declined").text, "Mark declined"); assertTrue(byKey(acts, "declined").enabled)
    local show = byKey(acts, "show")
    assertEqual(show.text, "Show in Drops"); assertFalse(show.enabled, "not live")
    assertTrue(#show.tip >= 2, "says why")
    assertTrue(byKey(model(NS, entry(), { liveId = 7 }).actions, "show").enabled)
    assertEqual(byKey(model(NS, entry({ outcome = "declined" })).actions, "declined").text, "Clear declined")
    assertFalse(byKey(model(NS, entry({ outcome = "received" })).actions, "declined").enabled, "a trade settled it")
    assertFalse(byKey(model(NS, entry({ itemLink = false })).actions, "link").enabled)
end)

-- ── the card, headless ──────────────────────────────────────────────────────────────────────

local function kept(NS, m)
    local now = m.time()
    local hist = NS.History.Store()
    hist.groups = {
        { key = "g@1", label = "Ulgrax", kind = "encounter", situation = "raid", at = now - 120,
          instance = "Nerub-ar Palace", difficulty = "Heroic", drops = {
            entry({ at = now - 120, itemLink = link(501), outcome = "asked" }),
            entry({ at = now - 100, itemLink = link(502), outcome = "seen" }),
        } },
    }
    return hist.groups[1]
end

local function shown(mode)
    local NS, _, m = T.enableAddon()
    m.normalizedRealm = "Testrealm"
    local g = kept(NS, m)
    NS.SetWindowMode(mode or "full")
    NS.ShowWindow()
    NS.Window.SelectTab("history")
    return NS, NS.WindowHistory.Drawn(), m, g
end

local function rowFor(drawn, e)
    for _, r in ipairs(drawn.rows) do if r.entry == e then return r end end
end

local function yOf(frame) return select(5, frame:GetPoint(1)) end
local function xOf(frame) return select(4, frame:GetPoint(1)) end

test("history card: a row click expands the card under it; the row below moves down; one at a time", function()
    local NS, drawn, _, g = shown()
    local HC = NS.HistoryCard
    local K = NS.Constants.WINDOW
    local a, b = g.drops[1], g.drops[2]
    assertFalse(drawn.card:IsShown(), "nothing expanded at first")
    local below = yOf(rowFor(drawn, a)) < yOf(rowFor(drawn, b)) and a or b
    local top = below == a and b or a
    local before = yOf(rowFor(drawn, below))
    assertEqual(rowFor(drawn, top).chevron:GetTexture(), NS.Icon("chevron-down"))
    rowFor(drawn, top):__fire("OnClick", "LeftButton")
    drawn = NS.WindowHistory.Drawn()
    assertTrue(drawn.card:IsShown()); assertTrue(drawn.cardEntry == top)
    assertTrue(NS.WindowHistory.Expanded() == top)
    assertEqual(xOf(drawn.card), K.ROW_INDENT, "indented with its row")
    assertEqual(yOf(drawn.card), yOf(rowFor(drawn, top)) - NS.WindowRows.ROW_H, "right under its row")
    assertEqual(yOf(rowFor(drawn, below)), before - HC.CARD_H, "the next row moves down")
    assertEqual(rowFor(drawn, top).chevron:GetTexture(), NS.Icon("chevron-up"))
    assertTrue(rowFor(drawn, top).selected:IsShown())
    rowFor(drawn, below).cells.trade:__fire("OnMouseUp", "LeftButton")
    drawn = NS.WindowHistory.Drawn()
    assertTrue(drawn.cardEntry == below, "a cell click is a row click; the card moves")
    rowFor(drawn, below):__fire("OnClick", "LeftButton")
    drawn = NS.WindowHistory.Drawn()
    assertFalse(drawn.card:IsShown()); assertNil(NS.WindowHistory.Expanded())
end)

test("history card: a right-click still opens the row menu and expands nothing", function()
    local NS, drawn, _, g = shown()
    local opened = 0
    NS.WindowHistory.OpenMenu = function() opened = opened + 1 end
    rowFor(drawn, g.drops[1]).cells.trade:__fire("OnMouseUp", "RightButton")
    rowFor(drawn, g.drops[1]):__fire("OnMouseUp", "RightButton")
    assertEqual(opened, 2)
    assertNil(NS.WindowHistory.Expanded())
end)

test("history card: the columns start after the row's indent and chevron, as on Drops", function()
    local NS, drawn, _, g = shown()
    local WG = NS.WindowGroup
    local r = rowFor(drawn, g.drops[1])
    assertEqual(xOf(r), NS.Constants.WINDOW.ROW_INDENT)
    assertEqual(xOf(r.cells.item), WG.CHEVRON_LEAD)
    assertEqual(xOf(drawn.pane.colHead.labels.item), WG.LEAD)
end)

test("history card: the card paints the snapshot, each part with a tooltip", function()
    local NS, _, _, g = shown()
    NS.WindowHistory.ToggleExpand(g.drops[1])
    local card = NS.WindowHistory.Drawn().card
    assertEqual(textOf(card.name), "Item 501"); assertEqual(card.icon.link, link(501))
    assertEqual(textOf(card.chips[4].text), "Asked")
    assertFalse(card.chips[5]:IsShown())
    assertEqual(textOf(card.me.title), "FOR YOU · AT THE TIME")
    assertEqual(textOf(card.them.rows[1].value), "Brakk")
    assertEqual(textOf(card.trade.chip.text), "LIKELY TRADEABLE")
    assertEqual(textOf(card.where.title), "WHEN AND WHERE")
    assertFalse(card.where.verdict:IsShown())
    assertEqual(textOf(card.where.rows[2].value), "Nerub-ar Palace · Ulgrax · Heroic")
    assertEqual(textOf(card.actions.show.label), "Show in Drops")
    for _, b in pairs(card.actions) do assertTrue(#NS.Window.TooltipOf(b) >= 1) end
end)

test("history card: Link in chat links the item; Mark declined marks it and reads Clear declined", function()
    local NS, _, m, g = shown()
    local linked
    NS.Compat.InsertChatLink = function(l) linked = l end
    NS.WindowHistory.ToggleExpand(g.drops[1])
    local card = NS.WindowHistory.Drawn().card
    card.actions.link:__fire("OnClick")
    assertEqual(linked, link(501))
    card.actions.declined:__fire("OnClick")
    assertEqual(g.drops[1].outcome, "declined")
    m.advance(0)
    card = NS.WindowHistory.Drawn().card
    assertEqual(textOf(card.actions.declined.label), "Clear declined")
    card.actions.declined:__fire("OnClick")
    assertEqual(g.drops[1].outcome, "asked", "the outcome it replaced")
end)

test("history card: Show in Drops selects the Drops tab, opens the drop's header and expands its card", function()
    local NS, _, _, g = shown()
    local e = g.drops[1]
    NS.WindowHistory.ToggleExpand(e)
    assertFalse(NS.WindowHistory.Drawn().card.actions.show.enabled, "not live")
    local rec = { id = 7, groupKey = "enc:9", link = link(501) }
    local realGet = NS.LootFeed.Get
    NS.LootFeed.Get = function(id) if id == 7 then return rec end return realGet(id) end
    NS.History.Adopt(7, e)
    assertEqual(NS.History.DropOf(e), 7)
    NS.State.windowGroup = { collapsed = { ["enc:9"] = true } }
    NS.Window.Refresh()
    local show = NS.WindowHistory.Drawn().card.actions.show
    assertTrue(show.enabled)
    show:__fire("OnClick")
    assertEqual(NS.Window.ActiveTab(), "group")
    assertEqual(NS.WindowGroup.Expanded(), 7)
    assertEqual(NS.State.windowGroup.collapsed["enc:9"], false)
end)

test("history card: compact cards expand the stacked card under the clicked card", function()
    local NS, drawn, _, g = shown("compact")
    local HC, K = NS.HistoryCard, NS.Constants.WINDOW
    assertTrue(drawn.compact == true)
    local a, b = g.drops[1], g.drops[2]
    local below = yOf(rowFor(drawn, a)) < yOf(rowFor(drawn, b)) and a or b
    local top = below == a and b or a
    local before = yOf(rowFor(drawn, below))
    assertFalse(drawn.card:IsShown())
    assertEqual(xOf(rowFor(drawn, top)), K.ROW_INDENT, "indented under its header, as on Drops")
    rowFor(drawn, top):__fire("OnClick", "LeftButton")
    drawn = NS.WindowHistory.Drawn()
    assertTrue(drawn.card:IsShown()); assertTrue(drawn.cardEntry == top)
    assertTrue(drawn.card.stacked == true)
    assertEqual(rowFor(drawn, top).chevron:GetTexture(), NS.Icon("chevron-up"))
    local width = drawn.card:GetWidth()
    assertEqual(drawn.card:GetHeight(), HC.StackedHeight(width))
    assertEqual(yOf(rowFor(drawn, below)), before - HC.StackedHeight(width) - NS.CompactGroup.GAP)
    rowFor(drawn, below).cells.trade.hit:__fire("OnMouseUp", "LeftButton")
    assertTrue(NS.WindowHistory.Drawn().cardEntry == below, "a piece's click is the card's")
    NS.SetWindowMode("full")
    drawn = NS.WindowHistory.Drawn()
    assertTrue(drawn.card:IsShown() and drawn.cardEntry == below, "the open card carries over to the table")
end)

test("history card: the stacked card's actions fit one line at the compact width", function()
    local NS = T.newAddon()
    local HC, K = NS.HistoryCard, NS.Constants.WINDOW
    local w = K.COMPACT_WIDTH - 2 * K.INSET - K.SCROLL_W - K.ROW_INDENT
    local _, lines = NS.DetailCard.FlowActions(w - 2 * K.CARD_PAD, HC.ACTION_KEYS, HC.ACTION_W)
    assertEqual(lines, 1)
    assertTrue(HC.CARD_H > 0 and HC.StackedHeight(w) > HC.CARD_H)
end)
