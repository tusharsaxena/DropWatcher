-- tests/test_detail_card.lua — the detail card (design spec §11.3, board 02): the item header's
-- chips, the For you and For the looter comparisons, the trade estimate box and the actions
-- (modules/DetailCells.lua, pure) state by state, then the card built headless under the mock: a
-- row click expands it inline under its row and moves the rows below, one row at a time; every
-- line has a reason tooltip; each action goes through its host handler; the Edit message box.

local T = _G.DW_TEST
local test, assertEqual, assertTrue, assertFalse, assertNil =
    T.test, T.assertEqual, T.assertTrue, T.assertFalse, T.assertNil

local LINK = "|cffa335ee|Hitem:212::|h[Crown of Roaring Storms]|h|r"
local RING = "|cffa335ee|Hitem:213::|h[Band of Embers]|h|r"
local OLD = "|cffa335ee|Hitem:300::|h[Old Helm]|h|r"
local THEIRS = "|cffa335ee|Hitem:301::|h[Their Helm]|h|r"

local NONE = {}

local SETA = "Player-1-0000000A"

-- A judged drop as the feed records it (board 02): a cloth Hero helm, an upgrade for you over a
-- Champion helm, a downgrade for Seta against her Myth helm, likely tradeable in a key.
local function drop(over)
    local d = {
        id = 1, at = 100, link = LINK, isMine = false, sources = { chat = 1 }, situation = "mythicPlus",
        looter = { name = "Seta-Realm", guid = SETA, classFile = "PRIEST" },
        facts = { ilvl = 311, equipLoc = "INVTYPE_HEAD", quality = 4, classID = 4, subClassID = 1, bindType = 1,
            track = { name = "Hero", rank = 2, max = 6 },
            stats = { ITEM_MOD_INTELLECT_SHORT = 900, ITEM_MOD_HASTE_RATING_SHORT = 330,
                ITEM_MOD_MASTERY_RATING_SHORT = 120, EMPTY_SOCKET_PRISMATIC = 1, ITEM_MOD_CR_LIFESTEAL_SHORT = 50 } },
        me = { verdict = "upgrade", ilvlDelta = 19, scoreDelta = 2.4, reasons = {}, trackDelta = { tier = 1, rank = -4, sign = 1 },
            baseline = { link = OLD, ilvl = 292, track = { name = "Champion", rank = 6, max = 6 },
                stats = { ITEM_MOD_HASTE_RATING_SHORT = 200, ITEM_MOD_MASTERY_RATING_SHORT = 239 } } },
        them = { verdict = "downgrade", ilvlDelta = -13, reasons = {}, trackDelta = { tier = -1, rank = 1, sign = -1 },
            baseline = { link = THEIRS, ilvl = 324, track = { name = "Myth", rank = 1, max = 6 },
                stats = { ITEM_MOD_CRIT_RATING_SHORT = 80, ITEM_MOD_HASTE_RATING_SHORT = 235, ITEM_MOD_MASTERY_RATING_SHORT = 120 } } },
        trade = { state = "likely", reasonKey = "notUpgrade", args = { 311, 324 }, basis = "inspect", age = 40, rule = "personal" },
        inspect = { status = "fresh", at = 60 },
    }
    for k, v in pairs(over or {}) do
        if v == NONE then d[k] = nil else d[k] = v end
    end
    return d
end

local function DC() return T.newAddon().DetailCells end

local function texts(list)
    local out = {}
    for _, c in ipairs(list) do out[#out + 1] = c.text end
    return table.concat(out, ",")
end

local function byKey(list, key)
    for _, x in ipairs(list) do if x.key == key then return x end end
end

-- ── the header's chips ──────────────────────────────────────────────────────────────────────

test("cells: the header's chips name slot, armor, bind, track and rank, primary stat, socket and tertiary", function()
    local D = DC()
    local chips = D.Chips(drop())
    assertEqual(texts(chips), "Head,Cloth,BoP,Hero 2/6 · 311,Int,Socket,Leech")
    for _, c in ipairs(chips) do assertTrue(#c.tip >= 2, c.text .. " explains itself") end
    local warbound = D.Chips(drop({ facts = { ilvl = 311, equipLoc = "INVTYPE_FINGER", warbound = true } }))
    assertEqual(texts(warbound), "Finger,Jewelry,Warbound,311", "a ring's type is Jewelry (feedback-4 §3)")
    local bare = D.Chips(drop({ facts = NONE }))
    assertEqual(texts(bare), "–", "the slot always shows, even unread")
    assertTrue(bare[1].tip[2]:find("not loaded") ~= nil)
end)

-- ── the comparisons ─────────────────────────────────────────────────────────────────────────

test("cells: StatChange lists the secondary stats gained and lost, the largest first", function()
    local D = DC()
    local d = drop()
    assertEqual(D.StatChange(d.facts.stats, d.me.baseline.stats), "+130 Haste -119 Mastery")
    assertEqual(D.StatChange(d.facts.stats, d.them.baseline.stats), "+95 Haste -80 Crit")
    assertNil(D.StatChange({ ITEM_MOD_STAMINA_SHORT = 5 }, {}), "no secondary stat")
end)

test("cells: For you shows what it replaces, the ilvl, track and stat change, and Pawn's score", function()
    local D = DC()
    local side = D.ForYou(drop(), true)
    assertEqual(side.title, "FOR YOU")
    assertEqual(side.verdict.text, "▲ UPGRADE"); assertEqual(side.verdict.tone, "good")
    assertEqual(texts(side.rows), "Old Helm · 292,292 → 311 · +19,Champion 6/6 → Hero 2/6 ▲,+130 Haste -119 Mastery,+2.4")
    assertEqual(byKey(side.rows, "replaces").link, OLD)
    assertEqual(byKey(side.rows, "ilvl").tone, "good")
    for _, r in ipairs(side.rows) do assertTrue(#r.tip >= 2 and r.text ~= "", r.key) end
end)

test("cells: For you without a score says why: no scorer, Pawn or your weights not scored yet", function()
    local D = DC()
    local d = drop({ me = { verdict = "upgrade", ilvlDelta = 19, reasons = {}, baseline = { link = OLD, ilvl = 292 } } })
    local off = byKey(D.ForYou(d, "none").rows, "score")
    assertEqual(off.text, "–"); assertTrue(off.tip[2]:find("No scorer is in use") ~= nil)
    assertTrue(byKey(D.ForYou(d, false).rows, "score").tip[2]:find("No scorer is in use") ~= nil)
    assertTrue(byKey(D.ForYou(d, true).rows, "score").tip[2]:find("not scored it yet") ~= nil)
    local w = byKey(D.ForYou(d, "weights").rows, "score")
    assertEqual(w.label, "Weights"); assertTrue(w.tip[2]:find("Your weights") ~= nil)
    assertEqual(byKey(D.ForYou(d, "pawn").rows, "score").label, "Pawn")
    local track = byKey(D.ForYou(d, true).rows, "track")
    assertEqual(track.text, "Hero 2/6"); assertTrue(track.tip[2]:find("worn item's track") ~= nil)
end)

test("cells: an empty slot and an unread baseline each say so, never blank", function()
    local D = DC()
    local empty = D.ForYou(drop({ me = { verdict = "upgrade", reasons = { { key = "emptySlot" } } } }), true)
    assertEqual(byKey(empty.rows, "replaces").text, "Empty slot")
    local unread = D.ForYou(drop({ me = { verdict = "unknown", reasons = { { key = "noBaseline" } } } }), true)
    assertEqual(texts(unread.rows), "–,311,Hero 2/6,–,–")
    assertEqual(unread.verdict.text, "UNKNOWN")
    for _, r in ipairs(unread.rows) do assertTrue(#r.tip >= 2, r.key) end
end)

test("cells: For the looter compares their inspected gear and names their spec and the read's age", function()
    local D = DC()
    local side = D.ForLooter(drop(), { status = "fresh", at = 60 }, "Discipline", 100)
    assertEqual(side.title, "FOR SETA (LOOTER)")
    assertEqual(side.verdict.text, "▽ DOWNGRADE"); assertEqual(side.verdict.tone, "red", "one tone per verdict")
    assertEqual(texts(side.rows), "Their Helm · 324,324 → 311 · -13,Myth 1/6 → Hero 2/6 ▽,+95 Haste -80 Crit,Discipline · inspected 40s ago")
    local unread = D.ForLooter(drop({ them = NONE, inspect = { status = "pending" } }), nil, nil, 100)
    assertEqual(unread.verdict.text, "UNKNOWN")
    assertEqual(byKey(unread.rows, "spec").text, "spec unknown")
    assertTrue(byKey(unread.rows, "spec").tip[2]:find("not been inspected") ~= nil)
end)

test("cells: on your own drop the looter's side is FOR THE GROUP, its Them row (Multiple)", function()
    local D = DC()
    local function cand(name, gain, base)
        return { guid = "G-" .. name, name = name .. "-Realm", status = "ready",
            eval = { verdict = "upgrade", ilvlDelta = gain, baseline = base, reasons = {} } }
    end
    local list = { a = cand("Butterz", 11, { ilvl = 300, name = "Bloodthorn Treads" }), b = cand("Seta", 4, { ilvl = 307 }) }
    local down = { verdict = "downgrade", ilvlDelta = -5, reasons = {} }
    local mine = D.ForLooter(drop({ isMine = true, them = NONE, me = down, candidates = list }), nil, nil, 100)
    assertEqual(mine.title, "FOR THE GROUP")
    assertEqual(mine.verdict.text, "(Multiple)"); assertEqual(mine.verdict.tone, "good")
    assertEqual(mine.rows[1].tip[2], "Your own drop: Offer shows who it would help.")
    local them = byKey(mine.rows, "them")
    assertEqual(them.text, "(Multiple)"); assertEqual(them.label, "Them")
    assertEqual(them.tip[2], "Butterz ▲ +11 · wears 300 (Bloodthorn Treads)", "ranked by gain")
    assertEqual(them.tip[3], "Seta ▲ +4 · wears 307")
    -- The keep? rule: an upgrade for you reads Hidden until revealed.
    local kept = D.ForLooter(drop({ isMine = true, them = NONE, candidates = list }), nil, nil, 100)
    assertEqual(byKey(kept.rows, "them").text, "Hidden")
    local revealed = D.ForLooter(drop({ isMine = true, them = NONE, candidates = list }), nil, nil, 100, true)
    assertEqual(byKey(revealed.rows, "them").text, "(Multiple)")
end)

-- ── the trade box ───────────────────────────────────────────────────────────────────────────

test("cells: the trade box says the state, the reason, the rule in force and how fresh the data is", function()
    local D = DC()
    local b = D.TradeBox(drop(), "Mythic+")
    assertEqual(b.chip.text, "LIKELY TRADEABLE"); assertEqual(b.chip.tone, "good")
    assertEqual(b.text, "Personal loot: 311 is not an upgrade over the 324 Seta wears, so they may trade it.")
    assertEqual(b.meta, "Rule: personal loot, Mythic+ · Basis: inspect 40s ago")
    assertTrue(#b.tip >= 2)
    local boe = D.TradeBox(drop({ trade = { state = "yes", reasonKey = "boe", basis = "bind" } }), nil)
    assertEqual(boe.chip.text, "TRADEABLE"); assertEqual(boe.meta, "Basis: the item's bind")
    local none = D.TradeBox(drop({ trade = NONE }), nil)
    assertEqual(none.chip.text, "TRADE UNKNOWN"); assertEqual(none.text, "Not estimated yet.")
    local no = D.TradeBox(drop({ trade = { state = "no", reasonKey = "legacy", basis = "rule", rule = "legacy" } }), "PvP")
    assertEqual(no.chip.tone, "bad"); assertEqual(no.meta, "Rule: legacy loot, PvP · Basis: the content's rule")
end)

-- ── the actions ─────────────────────────────────────────────────────────────────────────────

local OK_TRADE = { ok = true }
local FAR = { ok = false, reason = "range", text = "That player is out of trade range." }

test("cells: the actions, ready: Ask Seta, Edit message, Link in chat, Trade; Retry waits on a fresh read", function()
    local D = DC()
    local acts = D.Actions(drop(), { askState = "ready", inspect = { status = "fresh", at = 60 }, now = 100, trade = OK_TRADE })
    assertEqual(texts(acts), "Ask Seta,Edit message,Link in chat,Retry inspect,Trade")
    local on = {}
    for _, a in ipairs(acts) do on[#on + 1] = a.key .. "=" .. tostring(a.enabled) end
    assertEqual(table.concat(on, ","), "ask=true,edit=true,link=true,retry=false,trade=true")
    assertTrue(byKey(acts, "retry").tip[2]:find("read 40s ago") ~= nil)
    for _, a in ipairs(acts) do assertTrue(#a.tip >= 2, a.key .. " says why") end
end)

test("cells: a disabled action says why: Trade out of range, Retry already queued, Edit once asked", function()
    local D = DC()
    local acts = D.Actions(drop(), { askState = "sent", inspect = { status = "pending" }, now = 100, trade = FAR })
    local trade = byKey(acts, "trade")
    assertEqual(trade.text, "Trade · out of range"); assertFalse(trade.enabled)
    assertEqual(trade.tip[2], "That player is out of trade range.")
    assertFalse(byKey(acts, "retry").enabled); assertTrue(byKey(acts, "retry").tip[2]:find("already queued") ~= nil)
    assertEqual(byKey(acts, "ask").text, "Asked"); assertFalse(byKey(acts, "ask").enabled)
    assertFalse(byKey(acts, "edit").enabled); assertEqual(byKey(acts, "edit").tip[2], "The ask is already asked.")
    local failed = D.Actions(drop(), { askState = "failed", inspect = { status = "failed", reason = "timeout" }, now = 100, trade = FAR })
    assertTrue(byKey(failed, "retry").enabled, "a failed inspect may be retried")
    assertTrue(byKey(failed, "edit").enabled, "a failed ask may be edited and sent again")
    assertEqual(byKey(failed, "ask").text, "Retry")
end)

test("cells: on your own drop Offer takes the Ask's place; Edit, Retry and Trade are off, each with its reason", function()
    local D = DC()
    local acts = D.Actions(drop({ isMine = true, them = NONE }), { askState = "ready", now = 100, trade = OK_TRADE })
    local offer = byKey(acts, "ask")
    assertTrue(offer.offer and offer.enabled, "Offer opens the Offer panel (feedback-5 spec §2)")
    assertEqual(offer.text, "Offer"); assertEqual(offer.state, "ready")
    for _, key in ipairs({ "edit", "retry", "trade" }) do
        local a = byKey(acts, key)
        assertFalse(a.enabled, key); assertTrue(#a.tip >= 2 and a.tip[2] ~= "", key)
        assertTrue(a.tip[2]:find("My drops", 1, true) == nil, key .. ": no word of My drops")
    end
    assertEqual(byKey(acts, "edit").tip[2], "Your own drop: Offer shows who it would help.")
    local sent = D.Actions(drop({ isMine = true, them = NONE }), { now = 100, offerTone = "sent" })
    assertEqual(byKey(sent, "ask").text, "Offered"); assertEqual(byKey(sent, "ask").state, "sent")
    local dead = D.Actions(drop({ isMine = true, them = NONE, trade = { state = "no", reasonKey = "bonusRoll" } }), { now = 100 })
    assertFalse(byKey(dead, "ask").enabled, "a drop of yours that cannot be traded")
    assertTrue(byKey(acts, "hide") == nil, "no Hide this item (feedback-4 spec §2)")
    local legacy = D.Actions(drop({ trade = { state = "no", reasonKey = "legacy" } }), { askState = "ready", now = 100, trade = OK_TRADE })
    assertFalse(byKey(legacy, "trade").enabled, "an item its looter can't trade")
end)

-- ── the card, headless ──────────────────────────────────────────────────────────────────────

local function seed(NS, groups, drops)
    local byId = {}
    for _, d in ipairs(drops) do byId[d.id] = d end
    NS.LootFeed.Groups = function() return groups end
    NS.LootFeed.Get = function(id) return byId[id] end
    NS.LootFeed.Drops = function() return drops end
end

local GROUP = { key = "run:1", label = "Ara-Kara", kind = "run", situation = "mythicPlus", at = 90, drops = { 1, 2 } }

local function shownTable()
    local NS, _, m = T.enableAddon()
    m.__now = 100
    local d2 = drop({ id = 2, link = RING, looter = { name = "Littlewolf-Realm", guid = "Player-1-0000000B", classFile = "ROGUE" },
        facts = { ilvl = 298, equipLoc = "INVTYPE_FINGER", quality = 4 },
        me = { verdict = "sidegrade", ilvlDelta = 4, reasons = {} }, them = NONE, inspect = { status = "outOfRange" },
        trade = { state = "unknown", reasonKey = "noInspect", args = { "outOfRange" } } })
    seed(NS, { GROUP }, { drop(), d2 })
    NS.Inspect.Get = function(guid)
        if guid == SETA then return { status = "fresh", at = 60, specID = 256, gear = {} } end
    end
    NS.TradeHelper.CanTradeWith = function() return false, "range" end
    NS.WindowFilterBar.Set("group", "view", "all")
    NS.ShowWindow()
    return NS, NS.WindowGroup.Drawn(), m
end

local function rowFor(drawn, id)
    for _, r in ipairs(drawn.rows) do if r.dropId == id then return r end end
end

local function yOf(frame) return select(5, frame:GetPoint(1)) end

local function textOf(region) return region and region:GetText() end

test("card: a row click expands it inline; the rows below move down by the card's height", function()
    local NS, drawn = shownTable()
    local K = NS.Constants.WINDOW
    assertFalse(drawn.card:IsShown(), "nothing expanded at first")
    -- The lower row on screen (the more negative offset) is the one the card pushes down.
    local below = yOf(rowFor(drawn, 1)) < yOf(rowFor(drawn, 2)) and 1 or 2
    local before = yOf(rowFor(drawn, below))
    local top = below == 2 and 1 or 2
    rowFor(drawn, top):__fire("OnClick", "LeftButton")
    drawn = NS.WindowGroup.Drawn()
    assertTrue(drawn.card:IsShown()); assertEqual(drawn.cardDropId, top)
    assertEqual(NS.WindowGroup.Expanded(), top)
    -- a row is the bar's room taller while Trade window shows (feedback-5 spec §1)
    assertEqual(yOf(drawn.card), yOf(rowFor(drawn, top)) - NS.WindowRows.MineRowHeight(NS.WindowRows.ROW_H), "right under its row")
    assertEqual(yOf(rowFor(drawn, below)), before - K.CARD_H, "the next row moves down")
    assertEqual(rowFor(drawn, top).chevron:GetTexture(), NS.Icon("chevron-up"), "the open row's chevron points up")
    assertEqual(rowFor(drawn, below).chevron:GetTexture(), NS.Icon("chevron-down"), "a closed row's points down")
    rowFor(drawn, top):__fire("OnClick", "LeftButton")
    drawn = NS.WindowGroup.Drawn()
    assertFalse(drawn.card:IsShown()); assertNil(NS.WindowGroup.Expanded())
    assertEqual(yOf(rowFor(drawn, below)), before)
end)

test("card: one row at a time; a click on a cell or the item button opens it too", function()
    local NS, drawn = shownTable()
    rowFor(drawn, 1).cells.slot:__fire("OnMouseUp", "LeftButton")
    assertEqual(NS.WindowGroup.Drawn().cardDropId, 1, "a cell click is a row click")
    rowFor(NS.WindowGroup.Drawn(), 2).cells.item.button:__fire("OnClick", "LeftButton")
    drawn = NS.WindowGroup.Drawn()
    assertEqual(drawn.cardDropId, 2, "the card moves: one row at a time")
    assertEqual(rowFor(drawn, 1).chevron:GetTexture(), NS.Icon("chevron-down"), "the row it left points down again")
end)

test("card: the header, both comparisons and the trade box are painted, each with a reason", function()
    local NS = shownTable()
    NS.WindowGroup.ToggleExpand(1)
    local card = NS.WindowGroup.Drawn().card
    local W = NS.Window
    assertEqual(textOf(card.name), "Crown of Roaring Storms"); assertEqual(card.icon.link, LINK)
    assertEqual(textOf(card.chips[1].text), "Head"); assertEqual(textOf(card.chips[4].text), "Hero 2/6 · 311")
    assertTrue(card.chips[7]:IsShown()); assertFalse(card.chips[8]:IsShown())
    assertEqual(textOf(card.me.title), "FOR YOU"); assertEqual(textOf(card.me.verdict.text), "▲ UPGRADE")
    assertEqual(textOf(card.me.rows[2].value), "292 → 311 · +19")
    assertEqual(card.me.rows[1].item.link, OLD); assertTrue(card.me.rows[1].item:IsShown())
    assertEqual(textOf(card.them.title), "FOR SETA (LOOTER)")
    assertEqual(textOf(card.them.rows[5].value), "Discipline · inspected 40s ago")
    assertEqual(textOf(card.trade.chip.text), "LIKELY TRADEABLE")
    assertEqual(textOf(card.trade.meta), "Rule: personal loot, Mythic+ · Basis: inspect 40s ago")
    for _, c in ipairs(card.chips) do
        if c:IsShown() then assertTrue(#W.TooltipOf(c) >= 2) end
    end
    for _, side in ipairs({ card.me, card.them }) do
        assertTrue(#W.TooltipOf(side.verdict) >= 2)
        for _, r in ipairs(side.rows) do
            if r:IsShown() then
                assertTrue(#W.TooltipOf(r) >= 2, r.key .. " explains itself")
                assertTrue((textOf(r.value) or "") ~= "", r.key .. " is not blank")
            end
        end
    end
    assertTrue(#W.TooltipOf(card.trade) >= 3)
    assertTrue(card.nameTip.showItem and card.nameTip.itemButton.link ~= nil, "the name shows the real item tooltip")
end)

test("card: the actions go through their host handlers; Trade is off with its reason", function()
    local NS, _, m = shownTable()
    NS.WindowGroup.ToggleExpand(1)
    local a = NS.WindowGroup.Drawn().card.actions
    local asked, inspected, opened = {}, {}, 0
    NS.Asks.Press = function(kind, target, id, opts) asked[#asked + 1] = { kind, target, id, opts }; return "sent" end
    NS.Inspect.Request = function(guid, priority) inspected[#inspected + 1] = { guid, priority }; return "pending" end
    NS.TradeHelper.Open = function() opened = opened + 1; return true end
    assertEqual(textOf(a.ask.label), "Ask Seta")
    a.ask:__fire("OnClick")
    assertEqual(table.concat({ asked[1][1], asked[1][2], asked[1][3] }, ","), "ask,Seta-Realm,1")
    a.link:__fire("OnClick")
    assertEqual(m.chatLinks[#m.chatLinks], LINK)
    assertFalse(a.retry:IsEnabled(), "a fresh read is not retried")
    NS.RetryInspect(1)
    assertEqual(inspected[1][1], SETA); assertEqual(inspected[1][2], NS.Inspect.PRIORITY.looter)
    assertFalse(a.trade:IsEnabled()); assertEqual(textOf(a.trade.label), "Trade · out of range")
    assertEqual(NS.Window.TooltipOf(a.trade)[2], "That player is out of trade range.")
    NS.TradeHelper.CanTradeWith = function() return true end
    NS.Window.Refresh()
    a = NS.WindowGroup.Drawn().card.actions
    assertTrue(a.trade:IsEnabled())
    a.trade:__fire("OnClick")
    assertEqual(opened, 1)
    for _, b in pairs(a) do assertTrue(#NS.Window.TooltipOf(b) >= 2, b.key .. " has a tooltip") end
end)

test("card: the card has no Hide this item; its row stays", function()
    local NS = shownTable()
    NS.WindowGroup.ToggleExpand(1)
    local drawn = NS.WindowGroup.Drawn()
    assertTrue(drawn.card.actions.hide == nil)
    assertTrue(drawn.card:IsShown()); assertTrue(rowFor(drawn, 1) ~= nil)
end)

test("card: a filtered-out or collapsed row hides its card; it comes back with the row", function()
    local NS = shownTable()
    NS.WindowGroup.ToggleExpand(1)
    NS.WindowFilterBar.Set("group", "search", "littlewolf")
    assertFalse(NS.WindowGroup.Drawn().card:IsShown())
    NS.WindowFilterBar.Set("group", "search", "")
    assertTrue(NS.WindowGroup.Drawn().card:IsShown(), "the row is back, and still expanded")
    NS.WindowGroup.Drawn().headers[1]:__fire("OnClick")
    assertFalse(NS.WindowGroup.Drawn().card:IsShown())
end)

test("card: Edit message opens the box with the ask filled in; Send asks with the edited text", function()
    local NS = shownTable()
    NS.WindowGroup.ToggleExpand(1)
    local asked
    NS.Asks.Preview = function(kind, target, id)
        assertEqual(kind .. "," .. target .. "," .. id, "ask,Seta-Realm,1")
        return { text = "Hi Seta, could I have it?", length = 25 }
    end
    NS.Asks.Press = function(_, _, _, opts) asked = opts; return "sent" end
    NS.WindowGroup.Drawn().card.actions.edit:__fire("OnClick")
    local e = NS.DetailCard.Editor()
    assertTrue(e:IsShown())
    assertEqual(textOf(e.title), "Edit message to Seta")
    assertEqual(e.box:GetText(), "Hi Seta, could I have it?")
    assertEqual(textOf(e.counter), "25 / 255 bytes"); assertTrue(e.send:IsEnabled())
    e.box:SetText(string.rep("x", 256))
    e.box:__fire("OnTextChanged")
    assertFalse(e.send:IsEnabled(), "over the chat limit")
    e.box:SetText("Could I have it?")
    e.box:__fire("OnTextChanged")
    e.send:__fire("OnClick")
    assertEqual(asked.text, "Could I have it?")
    assertFalse(e:IsShown())
    assertTrue(#NS.Window.TooltipOf(e.send) >= 2 and #NS.Window.TooltipOf(e.cancel) >= 2)
end)

test("card: with Edit before sending on, the row's Ask opens the box; its Send asks; a queued ask still cancels", function()
    local NS = shownTable()
    local pressed = {}
    NS.Asks.Preview = function() return { text = "Hi Seta, could I have it?", length = 25 } end
    NS.Asks.Press = function(kind, _, _, opts) pressed[#pressed + 1] = { kind = kind, opts = opts }; return "sent" end
    assertEqual(NS.PressAsk(1), "sent", "off by default: the press sends")
    NS.SchemaRuntime.Set("messages.editFirst", true)
    assertEqual(NS.PressAsk(1), "editing")
    assertEqual(#pressed, 1, "nothing sent yet")
    local e = NS.DetailCard.Editor()
    assertTrue(e:IsShown()); assertEqual(textOf(e.title), "Edit message to Seta")
    e.send:__fire("OnClick")
    assertEqual(#pressed, 2); assertEqual(pressed[2].opts.text, "Hi Seta, could I have it?")
    assertFalse(e:IsShown(), "the box's own send does not open it again")
    NS.Asks.StateOf = function() return "queued" end
    NS.PressAsk(1)
    assertEqual(#pressed, 3, "a queued ask is pressed through, to cancel it")
    assertTrue(pressed[3].opts == nil)
end)

test("card: the Edit message box says why when the ask would be refused, and Cancel closes it", function()
    local NS = shownTable()
    NS.Asks.Preview = function() return nil, "offline" end
    local e = NS.DetailCard.OpenEditor(1)
    assertEqual(textOf(e.counter), "Can't ask: the looter is offline.")
    assertFalse(e.send:IsEnabled())
    e.cancel:__fire("OnClick")
    assertFalse(e:IsShown())
end)

-- ── the host handlers ───────────────────────────────────────────────────────────────────────

test("card: RetryInspect and TradeWithLooter say why they did nothing", function()
    local NS, _, m = T.enableAddon()
    seed(NS, { GROUP }, { drop({ isMine = true }) })
    assertNil(NS.RetryInspect(1))
    assertTrue(m.prints[#m.prints]:find("Nobody to inspect") ~= nil)
    local ok, reason = NS.TradeWithLooter(1)
    assertFalse(ok); assertEqual(reason, "noTarget")
    assertTrue(m.prints[#m.prints]:find("No trade: That player is not in your group.", 1, true) ~= nil)
    seed(NS, { GROUP }, { drop() })
    NS.TradeHelper.Open = function() return false, "combat" end
    NS.TradeWithLooter(1)
    assertTrue(m.prints[#m.prints]:find("You cannot trade in combat.", 1, true) ~= nil)
    NS.SchemaRuntime.Set("enabled", false)
    assertNil(NS.RetryInspect(1))
end)
