-- tests/test_window_group.lua — the Drops table (design spec §11.1-§11.2, boards 01, 03 and
-- 06): every cell's text, glyph, tone and reason tooltip (modules/WindowCells.lua, pure), the
-- column sets and the entry order (modules/WindowGroup.lua's pure halves), then the table built
-- headless under the mock: pooled rows, encounter headers that collapse, item buttons, the Ask
-- button, the compact layout's hand-off, the filters and the empty state.

local T = _G.DW_TEST
local test, assertEqual, assertTrue, assertFalse = T.test, T.assertEqual, T.assertTrue, T.assertFalse

local LINK = "|cffa335ee|Hitem:212::|h[Crown of Roaring Storms]|h|r"
local RING = "|cffa335ee|Hitem:213::|h[Band of Embers]|h|r"
local OLD1 = "|cffa335ee|Hitem:300::|h[Old Band]|h|r"
local OLD2 = "|cffa335ee|Hitem:301::|h[Older Band]|h|r"

-- An override that removes a field.
local NONE = {}

-- A judged drop as the feed records it: an upgrade for you, a downgrade for its looter, likely
-- tradeable, the looter inspected 40s before t = 100.
local function drop(over)
    local d = {
        id = 1, at = 100, link = LINK, isMine = false, sources = { chat = 1 },
        looter = { name = "Seta-Realm", guid = "Player-1-0000000A", classFile = "PRIEST" },
        facts = { ilvl = 311, equipLoc = "INVTYPE_HEAD", quality = 4, track = { name = "Hero", rank = 2, max = 6 } },
        me = { verdict = "upgrade", ilvlDelta = 19, reasons = {}, baseline = { link = OLD1, ilvl = 292 } },
        them = { verdict = "downgrade", ilvlDelta = -13, reasons = {} },
        trade = { state = "likely", reasonKey = "notUpgrade", args = { 311, 324 }, basis = "inspect", age = 40 },
        inspect = { status = "fresh", at = 60 },
    }
    for k, v in pairs(over or {}) do
        if v == NONE then d[k] = nil else d[k] = v end
    end
    return d
end

local function WC() return T.newAddon().WindowCells end

local function joined(tip) return table.concat(tip, " | ") end

-- ── the verdict cells ───────────────────────────────────────────────────────────────────────

test("cells: Me shows ▲ ≈ ▽ and the signed change, green up, yellow side, red down (feedback-4 §0)", function()
    local W = WC()
    local up = W.Me(drop())
    assertEqual(up.text, "+19"); assertEqual(up.glyph, "▲"); assertEqual(up.tone, "good")
    local side = W.Me(drop({ me = { verdict = "sidegrade", ilvlDelta = 0.4, reasons = {} } }))
    assertEqual(side.text, "+0"); assertEqual(side.glyph, "≈"); assertEqual(side.tone, "yellow")
    local down = W.Me(drop({ me = { verdict = "downgrade", ilvlDelta = -13, reasons = {} } }))
    assertEqual(down.text, "-13"); assertEqual(down.glyph, "▽"); assertEqual(down.tone, "red")
end)

test("cells: a verdict with no glyph says a word, and every verdict's tooltip says why", function()
    local W = WC()
    local cant = W.Me(drop({ me = { verdict = "cantUse", reasons = { { key = "armorType" } } } }))
    assertEqual(cant.text, "Can't use"); assertTrue(cant.glyph == nil); assertEqual(cant.tone, "bad")
    assertEqual(cant.tip[1], "For you: Can't use")
    assertTrue(joined(cant.tip):find("wrong armor type for the class") ~= nil)
    local unk = W.Me(drop({ me = NONE }))
    assertEqual(unk.text, "?"); assertEqual(unk.tone, "muted")
    assertTrue(#unk.tip >= 2, "never a bare title")
    local up = W.Me(drop())
    assertTrue(joined(up.tip):find("Item level 311 against 292 %(Old Band%): %+19") ~= nil, joined(up.tip))
    local empty = W.Me(drop({ me = { verdict = "upgrade", reasons = { { key = "emptySlot" } } } }))
    assertEqual(empty.text, "empty"); assertEqual(empty.glyph, "▲")
end)

test("cells: the Them column takes the Me tones: their upgrade green, their downgrade red, can't use gray", function()
    local W = WC()
    local down = W.Them(drop(), 100)
    assertEqual(down.text, "-13"); assertEqual(down.glyph, "▽"); assertEqual(down.tone, "red")
    assertEqual(down.tip[1], "For Seta: Downgrade")
    local up = W.Them(drop({ them = { verdict = "upgrade", ilvlDelta = 12, reasons = {} } }), 100)
    assertEqual(up.tone, "good")
    local cant = W.Them(drop({ them = { verdict = "cantUse", reasons = {} } }), 100)
    assertEqual(cant.tone, "bad", "gray, as in the Me column")
end)

test("cells: Them is a dash on your own drop and `?` with the inspect's reason while unread", function()
    local W = WC()
    local mine = W.Them(drop({ isMine = true, them = NONE }), 100)
    assertEqual(mine.text, "–"); assertEqual(mine.tip[2], "Your own drop: Offer shows who it would help.")
    local cases = {
        pending = "Waiting to inspect Seta", outOfRange = "out of range", combatParked = "combat to end",
        unavailable = "not in your group",
    }
    for status, words in pairs(cases) do
        local c = W.Them(drop({ them = NONE, inspect = { status = status } }), 100)
        assertEqual(c.text, "?", status)
        assertTrue(c.tip[2]:find(words, 1, true) ~= nil, status .. ": " .. c.tip[2])
    end
    local failed = W.Them(drop({ them = NONE, inspect = { status = "failed", reason = "timeout" } }), 100)
    assertTrue(failed.tip[2]:find("no answer came") ~= nil)
end)

-- ── the Trade column ────────────────────────────────────────────────────────────────────────

test("cells: Trade shows Yes, Likely, Unknown or No with board 03's reasons", function()
    local W = WC()
    local likely = W.Trade(drop())
    assertEqual(likely.text, "Likely"); assertEqual(likely.tone, "good")
    assertEqual(likely.tip[2], "Personal loot: 311 is not an upgrade over the 324 Seta wears, so they may trade it.")
    assertEqual(likely.tip[3], "Inspected 40s ago.")
    local function reason(t) return W.Trade(drop({ trade = t })).tip[2] end
    assertEqual(reason({ state = "yes", reasonKey = "boe", basis = "bind" }), "Bind on equip: anyone can trade this.")
    assertEqual(reason({ state = "no", reasonKey = "bonusRoll", basis = "bind" }), "Bonus roll loot can't be traded.")
    assertEqual(reason({ state = "no", reasonKey = "warbound", basis = "bind" }), "Warbound: it can't be traded.")
    assertEqual(reason({ state = "no", reasonKey = "legacy", basis = "rule" }), "Loot from this content can't be traded.")
    assertEqual(reason({ state = "likely", reasonKey = "groupLoot", basis = "rule" }), "Group loot: its winner may trade it for two hours.")
    assertEqual(reason({ state = "no", reasonKey = "expired", args = { 8000, 7200 } }), "The trade window (2h) has passed.")
    assertEqual(reason({ state = "yes", reasonKey = "timer", args = { 7140 } }), "Your own item: 1h 59m left to trade it.")
    assertEqual(reason({ state = "no", reasonKey = "upgradeForLooter", args = { 311, 298 } }),
        "311 is an upgrade over the 298 Seta wears, so the game won't let them trade it.")
    assertEqual(reason({ state = "no", reasonKey = "upgradeForLooter", args = { 311 } }),
        "It fills an empty slot for Seta, so the game won't let them trade it.")
    assertTrue(reason({ state = "unknown", reasonKey = "noInspect", args = { "outOfRange" } }):find("out of range") ~= nil)
    local none = W.Trade(drop({ trade = NONE }))
    assertEqual(none.text, "Unknown"); assertEqual(none.tip[2], "Not estimated yet.")
    assertEqual(W.Trade(drop({ trade = { state = "no", reasonKey = "legacy" } })).tone, "bad")
end)

-- ── the gear halves (WC.TheirEq, WC.MyEq; NS.SideCells puts them before the verdict) ────────

-- Feedback spec §3 (FB-7): the worn item levels in the cell, the read's age in its tooltip.
test("cells: Their eq shows both rings' levels for a ring, one for a helm, and the read's age in the tooltip", function()
    local W = WC()
    local gear = { [1] = { link = OLD1, ilvl = 324 }, [11] = { link = OLD1, ilvl = 300 }, [12] = { link = OLD2, ilvl = 296 } }
    local helm = W.TheirEq(drop(), gear, 100)
    assertEqual(#helm.items, 1); assertEqual(helm.text, "324"); assertEqual(helm.tone, "plain")
    assertEqual(helm.items[1].slot, 1, "each item names its slot")
    assertEqual(helm.tip[1], "Seta wears")
    assertEqual(helm.tip[2], "Old Band (324)")
    assertEqual(helm.tip[3], "Inspected 40s ago.")
    local ring = W.TheirEq(drop({ facts = { ilvl = 311, equipLoc = "INVTYPE_FINGER" }, link = RING }), gear, 100)
    assertEqual(#ring.items, 2, "rings compare with both worn rings")
    assertEqual(ring.text, "300/296")
    local cached = W.TheirEq(drop({ inspect = { status = "cached", at = 40 } }), gear, 100)
    assertEqual(cached.tip[#cached.tip], "From the inspect cache, read 1m ago.")
    local none = W.TheirEq(drop(), nil, 100)
    assertEqual(#none.items, 0); assertEqual(none.text, "–")
    assertTrue(joined(none.tip):find("Nothing read") ~= nil)
    local empty = W.TheirEq(drop(), { [1] = false }, 100)
    assertEqual(empty.text, "empty slot"); assertTrue(joined(empty.tip):find("Empty slot.", 1, true) ~= nil)
end)

-- Feedback spec §3 (FB-6): what you wear, from your gear snapshot.
test("cells: My eq shows what you wear in the drop's slot, both rings for a ring, and empty slot", function()
    local W = WC()
    local equipped = { [1] = { link = OLD1, ilvl = 292 }, [11] = { link = OLD1, ilvl = 300 }, [12] = false,
        [13] = { link = OLD1, ilvl = 289 }, [14] = { link = OLD2, ilvl = 301 } }
    local helm = W.MyEq(drop(), equipped)
    assertEqual(helm.text, "292"); assertEqual(helm.tone, "plain"); assertEqual(#helm.items, 1)
    assertEqual(helm.tip[1], "You wear"); assertEqual(helm.tip[2], "Old Band (292)")
    local ring = W.MyEq(drop({ facts = { ilvl = 311, equipLoc = "INVTYPE_FINGER" } }), equipped)
    assertEqual(ring.text, "300", "one ring worn, the other slot empty")
    assertTrue(joined(ring.tip):find("Empty slot.", 1, true) ~= nil)
    local trinket = W.MyEq(drop({ facts = { ilvl = 311, equipLoc = "INVTYPE_TRINKET" } }), equipped)
    assertEqual(trinket.text, "289/301"); assertEqual(#trinket.items, 2)
    local cloak = W.MyEq(drop({ facts = { ilvl = 311, equipLoc = "INVTYPE_CLOAK" } }), { [15] = false })
    assertEqual(cloak.text, "empty slot"); assertEqual(#cloak.items, 0)
    local loading = W.MyEq(drop(), {})
    assertEqual(loading.text, "…"); assertTrue(joined(loading.tip):find("still loading") ~= nil)
    local notGear = W.MyEq(drop({ facts = { ilvl = 311 } }), equipped)
    assertEqual(notGear.text, "–"); assertTrue(#notGear.tip >= 2)
    assertEqual(W.MyEq(drop({ isMine = true }), equipped).text, "292", "your own drop too")
end)

test("cells: Their eq says pending, range, combat or failed beside the icons, and a dash on your own", function()
    local W = WC()
    local want = { pending = "…", outOfRange = "range", combatParked = "combat", failed = "!" }
    for status, text in pairs(want) do
        local c = W.TheirEq(drop({ inspect = { status = status } }), nil, 100)
        assertEqual(c.text, text, status); assertEqual(c.tone, "muted")
        assertTrue(#c.tip >= 3, status .. ": the reason is in the tooltip")
    end
    local mine = W.TheirEq(drop({ isMine = true }), nil, 100)
    assertEqual(mine.text, "–")
end)

-- ── the Ask button ──────────────────────────────────────────────────────────────────────────

test("cells: Ask moves Ask -> Queued -> Asked, with Retry on a failure", function()
    local W = WC()
    local ready = W.Ask(drop(), "ready")
    assertTrue(ready.offered and ready.enabled); assertEqual(ready.text, "Ask"); assertTrue(ready.icon == nil)
    assertTrue(ready.tip[2]:find("Whisper Seta") ~= nil)
    local queued = W.Ask(drop(), "queued")
    assertEqual(queued.text, "Queued"); assertEqual(queued.icon, "clock"); assertTrue(queued.enabled, "a click cancels it")
    local sent = W.Ask(drop(), "sent")
    assertEqual(sent.text, "Asked"); assertEqual(sent.icon, "confirm"); assertFalse(sent.enabled)
    local failed = W.Ask(drop(), "failed", "throttled")
    assertEqual(failed.text, "Retry"); assertEqual(failed.icon, "reset")
    assertTrue(failed.tip[2]:find("throttled") ~= nil)
end)

test("cells: no Ask is offered on your own drop, an untradeable one or one that is no use to you", function()
    local W = WC()
    local mine = W.Ask(drop({ isMine = true }), "ready")
    assertFalse(mine.offered); assertEqual(mine.text, "–")
    assertEqual(mine.tip[2], "Your own drop: Offer shows who it would help.", "reworded (feedback-5 spec §2)")
    local no = W.Ask(drop({ trade = { state = "no", reasonKey = "bonusRoll" } }), "ready")
    assertFalse(no.offered); assertTrue(no.tip[2]:find("Bonus roll") ~= nil)
    local down = W.Ask(drop({ me = { verdict = "downgrade", ilvlDelta = -5, reasons = {} } }), "ready")
    assertFalse(down.offered); assertEqual(down.tip[2], "It is not an upgrade for you.")
    assertTrue(W.Ask(drop({ me = { verdict = "sidegrade", ilvlDelta = 1, reasons = {} } }), "ready").offered)
end)

-- ── the other cells and the header ──────────────────────────────────────────────────────────

test("cells: Item, Ilvl, Slot and Looter are never blank, each with a reason tooltip", function()
    local W = WC()
    local bare = { id = 9, looter = {}, facts = NONE }
    for _, fn in ipairs({ W.Item, W.Ilvl, W.Slot, W.Looter, W.Me, W.Trade }) do
        local c = fn(bare)
        assertTrue(type(c.text) == "string" and c.text ~= "", "a cell's text")
        assertTrue(#c.tip >= 2, "a cell's reason: " .. tostring(c.tip[1]))
    end
    assertEqual(W.Ilvl(drop()).text, "311")
    assertEqual(W.Ilvl(drop()).tip[2], "Upgrade track: Hero 2/6.")
    assertEqual(W.Slot(drop()).text, "Head")
    assertEqual(W.Slot(drop({ facts = { equipLoc = "INVTYPE_TRINKET" } })).tip[2], "Compared with the lower of the two items that could be replaced.")
    local lc = W.Looter(drop())
    assertEqual(lc.text, "Seta"); assertEqual(lc.classFile, "PRIEST"); assertEqual(lc.tip[3], "Reported by chat.")
    assertEqual(W.Item(drop()).text, "Crown of Roaring Storms")
end)

test("cells: an encounter header reads `Label · Situation · age · n drops`", function()
    local W = WC()
    local g = { key = "enc:1", label = "Boss 3", kind = "encounter", at = 100 }
    local h = W.Header(g, 4, 220, "Dungeon", false)
    assertEqual(h.text, "Boss 3 · Dungeon · 2m ago · 4 drops")
    assertEqual(h.tip[2], "Drops from one boss encounter.")
    assertEqual(h.tip[3], "Click to collapse this group.")
    local c = W.Header(g, 1, 220, nil, true)
    assertEqual(c.text, "Boss 3 · 2m ago · 1 drop (collapsed)")
    assertEqual(c.tip[3], "Click to expand this group.")
end)

-- ── the columns and the order (pure) ────────────────────────────────────────────────────────

local function keys(cols)
    local out = {}
    for _, c in ipairs(cols) do out[#out + 1] = c.key end
    return table.concat(out, ",")
end

test("table: the default columns, and a column the profile turns off", function()
    local WG = T.newAddon().WindowGroup
    assertEqual(keys(WG.Columns()), "item,ilvl,slot,armorType,looter,me,them,trade,tradeWindow,actions")
    assertEqual(keys(WG.Columns({ slot = false, item = false, them = true })),
        "item,ilvl,armorType,looter,me,them,trade,tradeWindow,actions", "Item never hides")
    assertEqual(keys(WG.Columns({ me = false })),
        "item,ilvl,slot,armorType,looter,them,trade,tradeWindow,actions", "`window.columns.me` turns Me off, gear and all")
    assertEqual(keys(WG.Columns({ myEq = false, theirEq = false })), keys(WG.Columns()),
        "a retired toggle names no column (feedback-6 spec §1)")
    assertEqual(keys(WG.Columns({ tradeWindow = false })),
        "item,ilvl,slot,armorType,looter,me,them,trade,actions", "`window.columns.tradeWindow` turns it off")
    assertTrue(T.newAddon().C.PROFILE.window.columns.tradeWindow == true, "on by default")
end)

test("table: the Item column takes the slack, never less than its minimum", function()
    local NS = T.newAddon()
    local WG, K = NS.WindowGroup, NS.Constants.WINDOW
    local cols = WG.Columns({ slot = false, armorType = false, looter = false, them = false, trade = false,
        tradeWindow = false })
    local wide = WG.Layout(cols, 600)
    local fixed = 40 + 127 + K.ASK_W + 4 * K.CELL_GAP   -- Actions is the Ask button alone (feedback-4 §2)
    assertEqual(wide.item.w, 600 - fixed)
    assertEqual(wide.ilvl.x, wide.item.w + K.CELL_GAP)
    assertEqual(WG.Layout(cols, 100).item.w, K.ITEM_MIN)
end)

test("table: a row too narrow for every column sheds Type, Slot, Looter, Trade window and Ilvl, in that order", function()
    local NS = T.newAddon()
    local WG = NS.WindowGroup
    local cols = WG.Columns(false)
    local shed, have = {}, {}
    for _, c in ipairs(cols) do have[c.key] = true end
    for w = 1200, 0, -2 do
        local kept = {}
        for _, c in ipairs(WG.Fit(cols, w)) do kept[c.key] = true end
        for key in pairs(have) do
            if not kept[key] then shed[#shed + 1] = key; have[key] = nil end
        end
    end
    assertEqual(table.concat(shed, ","), "armorType,slot,looter,tradeWindow,ilvl,them,trade,me",
        "Trade window goes after Looter, and Me and Them where the verdict columns sat (feedback-6 spec §1)")
    assertEqual(keys(WG.Fit(cols, 0)), "item,actions", "Item and Actions never go")
    for _, w in ipairs({ 300, 500, 700, 900 }) do
        local layout, kept = WG.Layout(cols, w)
        assertTrue(layout.actions.x + layout.actions.w <= w, "Actions inside the row at " .. w)
        if #kept < #cols then assertTrue(layout.armorType == nil, "a shed column has no place") end
    end
end)

local function ctxOf(pass, sort)
    return { matches = pass or function() return true end, filter = { sort = sort or "newest" },
        compare = function(a, b) return a.id > b.id end }
end

test("table: groups newest first, the first open and older ones collapsed; a group the View hid whole keeps a header", function()
    local Cells = T.newAddon().WindowCells
    local byId = { [1] = drop({ id = 1 }), [2] = drop({ id = 2 }), [3] = drop({ id = 3 }), [4] = drop({ id = 4 }) }
    local groups = {
        { key = "a", drops = { 1 } }, { key = "b", drops = { 2, 3 } }, { key = "c", drops = { 4 } },
    }
    local get = function(id) return byId[id] end
    local e = Cells.Entries(groups, get, ctxOf(function(d) return d.id ~= 4 end), {})
    -- red under: a group the filter hides whole is left out, with nothing saying its drop exists
    assertEqual(e[1].kind, "header"); assertEqual(e[1].group.key, "c", "c's drop is hidden, not lost")
    assertEqual(e[1].count, 0); assertEqual(e[1].total, 1); assertFalse(e[1].collapsed)
    assertEqual(WC().DropCount(e[1].count, e[1].hidden), "1 drop · 0 shown")
    assertEqual(e[2].group.key, "b"); assertFalse(e[2].collapsed, "the first group with a drop shown opens")
    assertEqual(e[2].count, 2)
    assertEqual(e[3].drop.id, 3, "the tab's order within the group"); assertEqual(e[4].drop.id, 2)
    assertEqual(e[5].group.key, "a"); assertTrue(e[5].collapsed); assertEqual(#e, 5)
    local searched = ctxOf(function(d) return d.id ~= 4 end)
    searched.hiddenBy = function() return "search" end
    assertEqual(Cells.Entries(groups, get, searched, {})[1].group.key, "b", "a group Search hides whole is left out")
    local toggled = Cells.Entries(groups, get, ctxOf(), { collapsed = { a = false, c = true } })
    assertEqual(toggled[1].group.key, "c"); assertTrue(toggled[1].collapsed, "the player's toggle wins")
    assertEqual(toggled[2].group.key, "b"); assertEqual(toggled[2].count, 2, "nothing is dismissed")
    local oldest = Cells.Entries(groups, get, ctxOf(nil, "oldest"), {})
    assertEqual(oldest[1].group.key, "a", "Sort: Oldest turns the groups round")
end)

test("cells: KeepsHeader keeps a group the View hid whole, and one whose drops have no recorder", function()
    local W = WC()
    assertTrue(W.KeepsHeader(1, {}))
    assertFalse(W.KeepsHeader(0, {}), "nothing for the tab")
    assertTrue(W.KeepsHeader(0, { { drop = {}, why = "interesting" } }), "View: counted, never silent")
    assertFalse(W.KeepsHeader(0, { { drop = {}, why = "search" }, { drop = {}, why = "content" } }), "the question asked")
    assertFalse(W.KeepsHeader(0, { { drop = { seenBy = "Alt-Testrealm" }, why = "char" } }), "a Character choice")
    assertTrue(W.KeepsHeader(0, { { drop = {}, why = "char" } }), "kept before the dropdown: no recorder")
end)

-- ── the table, headless ─────────────────────────────────────────────────────────────────────

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
    -- View: All, so the sidegrade is listed too.
    NS.WindowFilterBar.Set("group", "view", "all")
    NS.ShowWindow()
    return NS, NS.WindowGroup.Drawn(), m
end

local function rowFor(drawn, id)
    for _, r in ipairs(drawn.rows) do if r.dropId == id then return r end end
end

local function textOf(region) return region and region:GetText() end

test("table: built at the least width, every column shows and Ask stays inside the row (feedback-4 §4)", function()
    local NS, _, m = T.enableAddon()
    local K = NS.Constants.WINDOW
    m.__now = 100
    seed(NS, { GROUP }, { drop() })
    NS.addon.db.profile.window = { geometry = { full = { width = 600 } } }   -- stored under the least
    NS.ShowWindow()
    assertEqual(NS.Window.Frame():GetWidth(), K.MIN_WIDTH, "raised to the least width")
    local drawn = NS.WindowGroup.Drawn()
    assertEqual(keys(drawn.columns), "item,ilvl,slot,armorType,looter,me,them,trade,tradeWindow,actions")
    local c = rowFor(drawn, 1).cells
    assertTrue(c.slot:IsShown()); assertTrue(c.looter:IsShown()); assertTrue(c.them:IsShown())
    assertTrue(c.tradeWindow:IsShown())
    assertTrue(c.actions:IsShown())
    local _, _, _, x = c.actions:GetPoint(1)   -- from the row's left edge, itself indented
    assertTrue(K.ROW_INDENT + x + c.actions:GetWidth() <= K.MIN_WIDTH - 2 * K.INSET - K.SCROLL_W)
end)

-- Feedback-2 spec §8 (FB2-9): the tables read like Ka0s Loot History's, 18-pixel rows and the
-- template's own text size (0 is Default); a stored size from 8 to 20 replaces it.
test("rows: the pure metrics read Default as the template's size and keep the row height in range", function()
    local NS = T.newAddon()
    local WR, K = NS.WindowRows, NS.Constants.WINDOW
    assertEqual(K.ROW_H, nil, "the default lives only in defaults/Profile.lua")
    assertEqual(WR.ROW_H, 18, "Loot History's row height, read from the profile defaults")
    assertEqual(NS.C.PROFILE.window.rowHeight, 18); assertEqual(NS.C.PROFILE.window.fontSize, 0)
    assertEqual(WR.FontSize(0), nil, "0 is Default"); assertEqual(WR.FontSize(nil), nil)
    assertEqual(WR.FontSize("12"), nil); assertEqual(WR.FontSize(-3), nil); assertEqual(WR.FontSize(0 / 0), nil)
    assertEqual(WR.FontSize(12), 12); assertEqual(WR.FontSize(12.4), 12)
    assertEqual(WR.FontSize(3), K.FONT_MIN, "1 to 7 read as the least size"); assertEqual(WR.FontSize(99), K.FONT_MAX)
    assertEqual(WR.RowHeight(nil), 18); assertEqual(WR.RowHeight(24), 24)
    assertEqual(WR.RowHeight(4), K.ROW_H_MIN); assertEqual(WR.RowHeight(400), K.ROW_H_MAX)
    assertEqual(WR.IconSize(18), 16, "the item button fits an 18-pixel row")
    assertEqual(WR.IconSize(32), K.ROW_ICON, "and never grows past its own size")
    assertEqual(WR.CountdownRowHeight(18), 32, "a Drops row with Trade window keeps room for its countdown bar")
    assertEqual(WR.CountdownRowHeight(18, nil), 32, "Default reads the template's size")
    assertEqual(WR.CountdownRowHeight(30), 44, "a taller row adds the bar's room")
    assertEqual(WR.CountdownRowHeight(18, 14), 40, "a larger text grows the row so its two lines never overlap")
    assertEqual(WR.CountdownRowHeight(18, 20), 52)
    assertEqual(WR.CountdownRowHeight(40, 8), 54, "the row height wins when it needs more")
end)

test("rows: a stored row height and font size stay as the player set them", function()
    local NS = T.enableAddon()
    NS.addon.db.profile.window.rowHeight, NS.addon.db.profile.window.fontSize = 24, 12
    local m = NS.WindowRows.Metrics()
    assertEqual(m.height, 24); assertEqual(m.fontSize, 12); assertEqual(m.icon, 20); assertEqual(m.countdownHeight, 38)
end)

test("rows: Font size reads `0 (Default)` on the CLI, and its slider reaches 0", function()
    local NS = T.bootAddon()
    local row = NS.SchemaRuntime.FindRow("window.fontSize")
    assertEqual(row.min, 0); assertEqual(row.max, 20)
    local fmt = function(_, v) return tostring(v) end
    assertEqual(NS.addon.Settings.FormatValue(row, 0, fmt), "0 (Default)")
    assertEqual(NS.addon.Settings.FormatValue(row, 14, fmt), "14")
end)

test("table: the Window page's row height and font size lay out and size the drop rows", function()
    local NS = shownTable()
    local K = NS.Constants.WINDOW
    NS.SchemaRuntime.Set("window.columns.tradeWindow", false)   -- its bar's room is the next test's
    local drawn = NS.WindowGroup.Drawn()
    local r1 = rowFor(drawn, 1)
    assertEqual(r1:GetHeight(), NS.WindowRows.ROW_H, "the default row height")
    assertEqual(r1.cells.item.button:GetWidth(), 16, "the item button fits the row")
    local _, size = r1.cells.ilvl.text:GetFont()
    assertEqual(size, 10, "the template's own size: the mock's default face answers 10")
    NS.SchemaRuntime.Set("window.rowHeight", 32)
    NS.SchemaRuntime.Set("window.fontSize", 15)
    drawn = NS.WindowGroup.Drawn()
    r1 = rowFor(drawn, 1)
    local r2 = rowFor(drawn, 2)
    assertEqual(r1:GetHeight(), 32); assertEqual(r1.cells.ilvl:GetHeight(), 32)
    assertEqual(r1.cells.item.button:GetWidth(), K.ROW_ICON)
    local _, _, _, _, y1 = r1:GetPoint(1)
    local _, _, _, _, y2 = r2:GetPoint(1)
    assertEqual(math.abs(y2 - y1), 32, "the next row starts one row height down")
    _, size = r1.cells.ilvl.text:GetFont()
    assertEqual(size, 15)
    _, size = r1.cells.me.glyph:GetFont()
    assertEqual(size, 15, "the verdict glyph too")
    NS.SchemaRuntime.Set("window.fontSize", 0)
    r1 = rowFor(NS.WindowGroup.Drawn(), 1)
    _, size = r1.cells.ilvl.text:GetFont()
    assertEqual(size, 10, "Default puts the template's size back")
    _, size = r1.cells.me.glyph:GetFont()
    assertEqual(size, 12, "and the glyph's own")
end)

test("table: built headless, one header and one row per drop, each column painted", function()
    local NS, drawn = shownTable()
    assertEqual(#drawn.headers, 1); assertEqual(#drawn.rows, 2)
    assertEqual(textOf(drawn.headers[1].text), "Boss 3 · Dungeon · 10s ago · 2 drops")
    local r = rowFor(drawn, 1)
    local c = r.cells
    assertEqual(textOf(c.item.text), "Crown of Roaring Storms")
    assertEqual(c.item.button.link, LINK)
    assertEqual(textOf(c.ilvl.text), "311"); assertEqual(textOf(c.slot.text), "Head")
    assertEqual(textOf(c.looter.text), "Seta")
    assertEqual(textOf(c.me.text), "19"); assertEqual(textOf(c.me.glyph), "▲")
    assertEqual(textOf(c.them.text), "13"); assertEqual(textOf(c.trade.text), "Likely")
    assertEqual(textOf(c.actions.ask.label), "Ask"); assertTrue(c.actions.ask:IsShown())
    local r2 = rowFor(drawn, 2)
    assertEqual(textOf(r2.cells.them.level), "range"); assertEqual(textOf(r2.cells.them.text), "",
        "the ? goes: range already says why (feedback-6 spec §1)")
    assertEqual(textOf(r2.cells.trade.text), "Unknown")
    assertFalse(drawn.pane.placeholder:IsShown(), "drops on screen: no empty line")
    assertEqual(textOf(drawn.pane.colHead.labels.them.text), "Them")
    assertTrue(NS.Window.Frame().panes.group:IsShown())
end)

test("table: the verdicts wear their tones, the looter their class color, the item its quality", function()
    local NS, drawn = shownTable()
    local c = rowFor(drawn, 1).cells
    local G = NS.Constants.TONE.good
    local r, g, b = c.me.text:GetTextColor()
    assertEqual(table.concat({ r, g, b }, ","), table.concat({ G.r, G.g, G.b }, ","), "an upgrade for you is green")
    local R = NS.Constants.TONE.red
    r, g = c.them.text:GetTextColor()
    assertEqual(r .. "," .. g, R.r .. "," .. R.g, "their downgrade is red: one tone per verdict")
    assertEqual(c.them.text.__points[1][2], c.them.glyph, "the arrow comes before the number")
    assertEqual(c.them.glyph.__points[1][2], c.them, "the arrow sits at the cell's left edge")
    r = c.looter.text:GetTextColor()
    assertEqual(r, 1, "a priest is white")
end)

test("table: every shown cell has a reason tooltip; nothing is blank", function()
    local NS, drawn = shownTable()
    local W = NS.Window
    for _, row in ipairs(drawn.rows) do
        for key, cell in pairs(row.cells) do
            if cell:IsShown() and key ~= "actions" then
                -- the item cell's hover is the real item tooltip (DW-80, BUG-2), not a text one
                local itemTip = cell.showItem and cell.itemButton.link ~= nil
                assertTrue(itemTip or #W.TooltipOf(cell) >= 2, key .. " has a reason")
                local all = (cell.level and cell.level:GetText() or "") .. (cell.text:GetText() or "")
                assertTrue(all ~= "", key .. " is not blank")
            end
        end
        local a = row.cells.actions
        local tipHost = a.ask:IsShown() and a.ask or a.dashTip
        assertTrue(#W.TooltipOf(tipHost) >= 2, "the Ask cell has a reason")
        assertTrue(a.dismiss == nil, "no dismiss mark (feedback-4 spec §2)")
    end
    for _, label in pairs(drawn.pane.colHead.labels) do
        if label:IsShown() then assertTrue(#W.TooltipOf(label) >= 2, "each column label explains itself") end
    end
    assertTrue(#W.TooltipOf(drawn.headers[1]) >= 3)
end)

test("table: rows come from the pool: a repaint reuses them, fewer drops park the rest", function()
    local NS, drawn = shownTable()
    local Pool = NS.Pool
    local first = drawn.rows[1]
    NS.Window.Refresh()
    drawn = NS.WindowGroup.Drawn()
    assertTrue(drawn.rows[1] == first, "the same frame, in the same place")
    local free, active = Pool.Counts(drawn.pane.rowPool)
    assertEqual(free .. "/" .. active, "0/2")
    seed(NS, { { key = "enc:3", label = "Boss 3", kind = "encounter", at = 90, drops = { 1 } } }, { drop() })
    NS.Window.Refresh()
    free, active = Pool.Counts(drawn.pane.rowPool)
    assertEqual(free .. "/" .. active, "1/1")
    assertFalse(first == drawn.pane.rowPool.free[1] and first:IsShown(), "a parked row is hidden")
end)

test("table: a header click collapses its group, and a second expands it", function()
    local NS, drawn = shownTable()
    drawn.headers[1]:__fire("OnClick")
    drawn = NS.WindowGroup.Drawn()
    assertEqual(#drawn.rows, 0, "collapsed: its rows go")
    assertTrue(textOf(drawn.headers[1].text):find("%(collapsed%)") ~= nil)
    assertTrue(NS.State.windowGroup.collapsed["enc:3"])
    drawn.headers[1]:__fire("OnClick")
    assertEqual(#NS.WindowGroup.Drawn().rows, 2)
end)

test("table: an item button shows the game's tooltip, shift-click links it and ctrl-click tries it on", function()
    local _, drawn, m = shownTable()
    local b = rowFor(drawn, 1).cells.item.button
    b:__fire("OnEnter")
    assertEqual(m.tooltipLinks[#m.tooltipLinks], LINK)
    b:__fire("OnClick", "LeftButton")
    assertEqual(#m.chatLinks + #m.dressUps, 0, "a plain click links nothing")
    m.shift = true
    b:__fire("OnClick", "LeftButton")
    assertEqual(m.chatLinks[1], LINK)
    m.shift, m.ctrl = false, true
    b:__fire("OnClick", "LeftButton")
    assertEqual(m.dressUps[1], LINK)
    assertTrue(b.art:GetTexture() ~= nil, "the item's own icon")
end)

-- The placement itself is tests/test_row_tooltip.lua's (feedback-3 spec §2, DW-B2).
test("item tooltip: a row's item button opens the game's tooltip at the row's top right, else on its own", function()
    local NS, drawn, m = shownTable()
    local row = rowFor(drawn, 1)
    local b = row.cells.item.button
    b:__fire("OnEnter")
    assertEqual(m.GameTooltip.__anchor, "ANCHOR_NONE")
    local point, rel, relPoint = m.GameTooltip:GetPoint(1)
    assertEqual(point .. ">" .. relPoint, "BOTTOMLEFT>TOPRIGHT", "no geometry: on the button's right")
    assertTrue(rel == b)
    local win = NS.Window.Frame()
    win.GetLeft = function() return 200 end
    win.GetRight = function() return 1200 end
    win.GetTop = function() return 800 end
    row.GetTop = function() return 600 end   -- the row, not the button: its top right
    m.UIParent.GetWidth = function() return 1920 end
    m.GameTooltip.GetWidth = function() return 320 end
    b:__fire("OnEnter")
    point, rel, relPoint = m.GameTooltip:GetPoint(1)
    assertEqual(point .. ">" .. relPoint, "BOTTOMLEFT>TOPRIGHT")
    assertTrue(rel == win, "just outside the window, at the row's top")
    assertEqual(select(5, m.GameTooltip:GetPoint(1)), -200)
    m.UIParent.GetWidth = function() return 1400 end
    b:__fire("OnEnter")
    point, rel, relPoint = m.GameTooltip:GetPoint(1)
    assertEqual(point .. ">" .. relPoint, "BOTTOMRIGHT>TOPLEFT", "no room on the right")
    assertTrue(rel == win)
end)

test("table: Them shows the looter's worn item from their inspect read before their verdict", function()
    local NS, _, m = T.enableAddon()
    m.__now = 100
    seed(NS, { GROUP }, { drop() })
    NS.Inspect.Get = function(guid)
        if guid == "Player-1-0000000A" then return { status = "fresh", at = 60, gear = { [1] = { link = OLD1, ilvl = 324 } } } end
    end
    NS.ShowWindow()
    local eq = rowFor(NS.WindowGroup.Drawn(), 1).cells.them
    assertEqual(eq.icons[1].link, OLD1); assertTrue(eq.icons[1]:IsShown())
    assertFalse(eq.icons[2]:IsShown(), "a helm: one item")
    assertEqual(textOf(eq.level), "324", "the worn item's level; its age is in the tooltip")
    assertEqual(textOf(eq.glyph) .. textOf(eq.text), "▽13", "then the verdict")
    assertEqual(NS.Window.TooltipOf(eq)[3], "Inspected 40s ago.")
end)

test("table: Me shows your worn item from the gear snapshot, its icon showing your own slot", function()
    local NS, _, m = T.enableAddon()
    m.__now = 100
    seed(NS, { GROUP }, { drop() })
    NS.Gear.Snapshot = function() return { equipped = { [1] = { link = OLD2, ilvl = 296 } } } end
    NS.ShowWindow()
    local eq = rowFor(NS.WindowGroup.Drawn(), 1).cells.me
    assertTrue(eq:IsShown())
    assertEqual(eq.icons[1].link, OLD2); assertTrue(eq.icons[1]:IsShown())
    assertEqual(eq.icons[1].worn.unit, "player"); assertEqual(eq.icons[1].worn.slot, 1)
    assertFalse(eq.icons[2]:IsShown(), "a helm: one item")
    assertEqual(textOf(eq.level), "296")
    assertEqual(textOf(NS.WindowGroup.Drawn().pane.colHead.labels.me.text), "Me")
    NS.Gear.Snapshot = function() return { equipped = { [1] = { link = OLD1, ilvl = 300 } } } end
    NS.addon:SendMessage(NS.MSG.GEAR_CHANGED)
    m.advance(0)
    assertEqual(textOf(rowFor(NS.WindowGroup.Drawn(), 1).cells.me.level), "300", "a new snapshot repaints it")
end)

test("table: the Ask button asks through the shared handler, and AskStateChanged repaints it", function()
    local NS, drawn, m = shownTable()
    local calls, state = {}, "ready"
    NS.Asks.Press = function(kind, target, id) calls[#calls + 1] = { kind, target, id }; state = "queued"; return "queued" end
    NS.Asks.StateOf = function() return state end
    local ask = rowFor(drawn, 1).cells.actions.ask
    ask:__fire("OnClick")
    assertEqual(table.concat(calls[1], ","), "ask,Seta-Realm,1")
    NS.addon:SendMessage(NS.MSG.ASK_STATE_CHANGED, 1, "queued", "ask", "Seta-Realm")
    m.advance(0)   -- a bus message repaints on the next frame
    ask = rowFor(NS.WindowGroup.Drawn(), 1).cells.actions.ask
    assertEqual(textOf(ask.label), "Queued")
    assertTrue(ask.art:IsShown(), "the catalog's clock mark")
    state = "sent"
    NS.addon:SendMessage(NS.MSG.ASK_STATE_CHANGED, 1, "sent", "ask", "Seta-Realm")
    m.advance(0)
    ask = rowFor(NS.WindowGroup.Drawn(), 1).cells.actions.ask
    assertEqual(textOf(ask.label), "Asked"); assertFalse(ask:IsEnabled())
end)

test("table: a drop with no ask offered shows a dash with its reason", function()
    local NS, drawn = shownTable()
    local a = rowFor(drawn, 2).cells.actions
    assertTrue(a.ask:IsShown(), "a sidegrade for you may be asked for")
    seed(NS, { GROUP }, { drop({ me = { verdict = "downgrade", ilvlDelta = -5, reasons = {} } }) })
    NS.Window.Refresh()
    a = rowFor(NS.WindowGroup.Drawn(), 1).cells.actions
    assertFalse(a.ask:IsShown()); assertTrue(a.dash:IsShown())
    assertEqual(textOf(a.dash), "–")
    assertEqual(NS.Window.TooltipOf(a.dashTip)[2], "It is not an upgrade for you.")
end)

test("table: no row can be dismissed: no ×, no handler, no dismissed state (feedback-4 spec §2)", function()
    local NS, drawn = shownTable()
    assertTrue(rowFor(drawn, 1).cells.actions.dismiss == nil)
    assertTrue(NS.DismissDrop == nil); assertTrue(NS.WindowGroup.Dismiss == nil)
    assertTrue(NS.State.windowGroup.dismissed == nil)
    assertEqual(#drawn.rows, 2)
end)

test("table: the compact layout draws cards instead of the table, and the full layout the table again", function()
    local NS = shownTable()
    NS.SetWindowMode("compact")
    assertTrue(NS.WindowGroup.IsCompact())
    local drawn = NS.WindowGroup.Drawn()
    assertTrue(drawn.compact == true, "the compact pane (modules/CompactGroup.lua)")
    assertEqual(#drawn.rows, 2, "a card per drop")
    assertFalse(drawn.pane.scroll:IsShown(), "the table's scroll frame hides")
    assertFalse(drawn.pane.colHead:IsShown(), "and its column labels")
    assertEqual(#NS.WindowGroup.Drawn().entries, 3, "the same entries")
    NS.ToggleWindowMode()
    drawn = NS.WindowGroup.Drawn()
    assertTrue(drawn.compact == nil)
    assertEqual(#drawn.columns, 10)
    assertTrue(drawn.pane.scroll:IsShown()); assertFalse(drawn.pane.compactView.scroll:IsShown())
end)

-- ── the Trade window column (feedback-5 spec §1) ────────────────────────────────────────────

test("cells: another player's drop is always the estimate, its tooltip naming the looter; ending soon is no words", function()
    local NS = T.newAddon()
    local MC = NS.MineCells
    -- an exact expiry on another player's record is not trusted: only their own bags know it
    local theirs = drop({ trade = { state = "likely", reasonKey = "notUpgrade", basis = "inspect", expiresAt = 200 } })
    local cd = MC.Countdown(theirs, 100)
    assertFalse(cd.exact); assertEqual(MC.Clock(cd.left), "2:00:00")
    local c = MC.TradeWindow(theirs, 100, 600)
    assertEqual(c.text, "~2:00:00"); assertEqual(c.tone, "plain"); assertFalse(c.bold); assertEqual(c.fraction, 1)
    assertTrue(joined(c.tip):find("about 2:00:00 left for Seta to trade it") ~= nil, joined(c.tip))
    assertTrue(joined(c.tip):find("your bags") == nil, "never your bags on their drop")
    local soon = MC.TradeWindow(drop({ at = 100 - 7000 }), 100, 600)
    assertEqual(soon.text, "~0:03:20", "the words `ending soon` are not drawn")
    assertTrue(soon.bold); assertTrue(soon.soon); assertEqual(soon.tone, "warn")
    assertTrue(joined(soon.tip):find("Ending soon: once it runs out, Seta keeps it.", 1, true) ~= nil, joined(soon.tip))
    local up = MC.TradeWindow(drop({ trade = { state = "no", reasonKey = "upgradeForLooter", basis = "inspect", args = { 311, 300 } } }), 100)
    assertEqual(up.text, "Their upgrade"); assertEqual(up.tone, "bad"); assertEqual(up.fraction, 0)
    assertTrue(up.tip[2]:find("300 Seta wears") ~= nil, up.tip[2])
    local yours = MC.TradeWindow(drop({ isMine = true, trade = { state = "no", reasonKey = "upgradeForLooter", args = { 311 } } }), 100)
    assertEqual(yours.text, "Your upgrade")
    local boe = MC.TradeWindow(drop({ trade = { state = "yes", reasonKey = "boe", basis = "bind" } }), 100)
    assertEqual(boe.text, "No limit (BoE)")
    assertEqual(MC.TradeWindow(drop({ trade = NONE }), 100).text, "Checking")
end)

-- Bar colors as they are set (the mock does not keep a texture's color).
local function recordBar(bar)
    local seen = {}
    rawset(bar, "SetColorTexture", function(self, r, g, b) seen[#seen + 1] = { r, g, b }; return self end)
    rawset(bar, "SetWidth", function(self, w) seen.width = w; return self end)
    return seen
end

test("table: Trade window paints every drop's countdown over its bar; the row grows by the bar's room", function()
    local NS, _, m = T.enableAddon()
    local C, WR = NS.Constants, NS.WindowRows
    m.__now = 100
    seed(NS, { { key = "enc:3", label = "Boss 3", kind = "encounter", situation = "dungeon", at = 90, drops = { 1, 2, 3, 4 } } }, {
        drop(), drop({ id = 2, at = 100 - 7000 }),
        drop({ id = 3, trade = { state = "no", reasonKey = "bonusRoll", basis = "bind" } }),
        drop({ id = 4, trade = { state = "yes", reasonKey = "boe", basis = "bind" } }) })
    NS.WindowFilterBar.Set("group", "view", "all")
    NS.ShowWindow()
    local drawn = NS.WindowGroup.Drawn()
    assertEqual(textOf(drawn.pane.colHead.labels.tradeWindow.text), "Trade window")
    local f = rowFor(drawn, 1).cells.tradeWindow
    local colors = recordBar(f.bar)
    local soonColors = recordBar(rowFor(drawn, 2).cells.tradeWindow.bar)
    NS.Window.Refresh()
    drawn = NS.WindowGroup.Drawn()
    f = rowFor(drawn, 1).cells.tradeWindow
    assertTrue(f:IsShown()); assertEqual(f:GetWidth(), 76)
    assertEqual(textOf(f.text), "~2:00:00", "another player's drop: the estimate from when it dropped")
    assertTrue(joined(f.tipLines):find("left for Seta") ~= nil, joined(f.tipLines))
    assertTrue(f.bar:IsShown()); assertEqual(f.fraction, 1); assertEqual(colors[#colors][1], C.TONE.good.r)
    assertEqual(colors.width, 76 - NS.WindowGroup.TRADE_WINDOW_PAD, "a full bar spans the column but its padding")
    assertFalse(f.bold)
    assertEqual(rowFor(drawn, 1):GetHeight(), WR.CountdownRowHeight(WR.ROW_H), "the row height plus the bar's room")
    assertEqual(f:GetHeight(), WR.CountdownRowHeight(WR.ROW_H))
    local soon = rowFor(drawn, 2).cells.tradeWindow
    assertEqual(textOf(soon.text), "~0:03:20"); assertTrue(soon.bold)
    assertEqual(select(1, soon.text:GetTextColor()), C.TONE.warn.r, "amber")
    assertEqual(soonColors[#soonColors][1], C.TONE.warn.r, "and its bar")
    local dead = rowFor(drawn, 3).cells.tradeWindow
    assertEqual(textOf(dead.text), "Bonus roll"); assertFalse(dead.bar:IsShown())
    assertEqual(textOf(rowFor(drawn, 4).cells.tradeWindow.text), "No limit (BoE)")
    NS.SchemaRuntime.Set("window.columns.tradeWindow", false)
    drawn = NS.WindowGroup.Drawn()
    assertFalse(rowFor(drawn, 1).cells.tradeWindow:IsShown())
    assertEqual(rowFor(drawn, 1):GetHeight(), WR.ROW_H, "turned off, the row is the row height again")
end)

-- The live countdown tickers: a repeating ticker every `period` seconds, not canceled.
local function tickers(m, period)
    local n = 0
    for _, t in ipairs(m.__timers) do
        if t.ticker and not t.stopped and t.delay == period then n = n + 1 end
    end
    return n
end

test("table: the countdowns move each second while one runs, repainting the Trade window cells alone", function()
    local NS, drawn, m = shownTable()
    assertEqual(tickers(m, 1), 1, "a countdown runs, so the each-second ticker does")
    assertEqual(textOf(rowFor(drawn, 1).cells.tradeWindow.text), "~2:00:00")
    local entries = 0
    local real = NS.WindowCells.Entries
    NS.WindowCells.Entries = function(...) entries = entries + 1; return real(...) end
    m.advance(1)
    assertEqual(textOf(rowFor(NS.WindowGroup.Drawn(), 1).cells.tradeWindow.text), "~1:59:59")
    m.advance(2)
    assertEqual(textOf(rowFor(NS.WindowGroup.Drawn(), 1).cells.tradeWindow.text), "~1:59:57")
    assertEqual(entries, 0, "the table is not rebuilt: only the countdowns repaint")
    m.__now = m.__now + 12
    NS.addon:SendMessage(NS.MSG.TRADE_TIMER_TICK)
    assertEqual(textOf(rowFor(NS.WindowGroup.Drawn(), 1).cells.tradeWindow.text), "~1:59:45", "TradeTimerTick moves it too")
    NS.Window.SelectTab("history")
    NS.Window.Refresh()
    assertEqual(tickers(m, 1), 0, "another tab: no countdown ticker")
    NS.Window.SelectTab("group")
    NS.Window.Refresh()
    assertEqual(tickers(m, 1), 1)
    NS.HideWindow()
    assertEqual(tickers(m, 1), 0, "a hidden window runs none")
end)

test("table: with no countdown running (nothing tradeable, or the column off) no each-second ticker runs", function()
    local NS, _, m = T.enableAddon()
    m.__now = 100
    seed(NS, { GROUP }, { drop({ trade = { state = "no", reasonKey = "bonusRoll", basis = "bind" } }),
        drop({ id = 2, trade = { state = "yes", reasonKey = "boe", basis = "bind" } }) })
    NS.WindowFilterBar.Set("group", "view", "all")
    NS.ShowWindow()
    assertEqual(tickers(m, 1), 0)
    assertFalse(NS.WindowGroup.LiveCountdown())
    seed(NS, { GROUP }, { drop(), drop({ id = 2 }) })
    NS.Window.Refresh()
    assertTrue(NS.WindowGroup.LiveCountdown()); assertEqual(tickers(m, 1), 1)
    NS.SchemaRuntime.Set("window.columns.tradeWindow", false)
    NS.Window.Refresh()
    assertFalse(NS.WindowGroup.LiveCountdown(), "no column, nothing to move"); assertEqual(tickers(m, 1), 0)
end)

test("table: a column the profile turns off is not drawn", function()
    local NS = shownTable()
    NS.addon.db.profile.window.columns = { slot = false }
    NS.Window.Refresh()
    local drawn = NS.WindowGroup.Drawn()
    assertFalse(rowFor(drawn, 1).cells.slot:IsShown())
    assertFalse(drawn.pane.colHead.labels.slot:IsShown())
end)

test("table: the filter bar filters the rows, and the empty line says why nothing shows", function()
    local NS = shownTable()
    local FB = NS.WindowFilterBar
    FB.Set("group", "search", "littlewolf")
    local drawn = NS.WindowGroup.Drawn()
    assertEqual(#drawn.rows, 1); assertEqual(drawn.rows[1].dropId, 2)
    FB.Set("group", "search", "nobody")
    drawn = NS.WindowGroup.Drawn()
    assertEqual(#drawn.rows + #drawn.headers, 0)
    assertTrue(drawn.pane.placeholder:IsShown())
    assertEqual(textOf(drawn.pane.placeholder), "No drop matches the filters. View: All shows everything.")
    assertFalse(drawn.pane.colHead:IsShown())
end)

test("table: with no drop at all the empty state says so, with Preview with test data and Scan group", function()
    local NS = T.enableAddon()
    NS.ShowWindow()
    local drawn = NS.WindowGroup.Drawn()
    local e = drawn.empty
    assertTrue(e:IsShown())
    assertFalse(drawn.pane.placeholder:IsShown(), "the empty state, not the filters' line")
    assertFalse(drawn.pane.colHead:IsShown())
    assertEqual(textOf(e.title), "No drops yet")
    assertEqual(textOf(e.text), "Loot your group receives appears here, grouped by boss.")
    assertEqual(textOf(e.preview.label), "Preview with test data")
    assertEqual(textOf(e.scan.label), "Scan group")
    assertEqual(NS.Window.TooltipOf(e.preview)[1], "Preview with test data")
    assertEqual(NS.Window.TooltipOf(e.scan)[1], "Scan group")
end)

test("table: the empty state's buttons turn test mode on and scan the group", function()
    local NS, _, m = T.enableAddon()
    m.seedGearJournal()
    NS.ShowWindow()
    local e = NS.WindowGroup.Drawn().empty
    local scanned = 0
    NS.ScanGroup = function() scanned = scanned + 1 end
    e.scan:__fire("OnClick")
    assertEqual(scanned, 1)
    e.preview:__fire("OnClick")
    assertTrue(NS.State.testMode)
    local drawn = NS.WindowGroup.Drawn()
    assertFalse(drawn.empty:IsShown())
    assertTrue(#drawn.rows > 0, "the placeholders are drawn")
end)

-- ── the host handler ────────────────────────────────────────────────────────────────────────

test("table: PressAsk says why it asked nobody: your own drop, a gone drop, the addon disabled", function()
    local NS, _, m = T.enableAddon()
    local pressed = false
    NS.Asks.Press = function() pressed = true; return "sent" end
    seed(NS, { GROUP }, { drop({ isMine = true }) })
    assertEqual(NS.PressAsk(1), "refused")
    assertTrue(m.prints[#m.prints]:find("That is your own drop") ~= nil)
    assertEqual(select(2, NS.PressAsk(99)), "noDrop")
    seed(NS, { GROUP }, { drop() })
    NS.SchemaRuntime.Set("enabled", false)
    assertEqual(select(2, NS.PressAsk(1)), "disabled")
    assertFalse(pressed)
    NS.SchemaRuntime.Set("enabled", true)
    assertEqual(NS.PressAsk(1), "sent")
    NS.Asks.Press = function() return "refused", "alreadyAsked" end
    NS.PressAsk(1)
    assertTrue(m.prints[#m.prints]:find("You already asked Seta%-Realm for it") ~= nil)
end)

-- ── whose move it is (feedback-4 spec §1) ───────────────────────────────────────────────────

test("cells: ActionTone is red for your move, yellow while waiting, green once done", function()
    local W = WC()
    assertEqual(W.ActionTone("ready"), "red"); assertEqual(W.ActionTone("failed"), "red")
    assertEqual(W.ActionTone("queued"), "yellow"); assertEqual(W.ActionTone("sent"), "yellow")
    assertEqual(W.ActionTone("traded"), "good"); assertEqual(W.ActionTone("tradedAway"), "good")
    assertTrue(W.ActionTone(nil) == nil); assertTrue(W.ActionTone("other") == nil)
end)

test("cells: an Offer is cyan while it is your move, its other states as any button's (feedback-6 spec §2)", function()
    local W = WC()
    assertEqual(W.ActionTone("ready", "offer"), "cyan"); assertEqual(W.ActionTone("failed", "offer"), "cyan")
    assertEqual(W.ActionTone("queued", "offer"), "yellow"); assertEqual(W.ActionTone("sent", "offer"), "yellow")
    assertEqual(W.ActionTone("tradedAway", "offer"), "good")
    assertEqual(W.ActionTone("ready"), "red", "Ask keeps its red")
    local cyan = T.newAddon().Constants.TONE.cyan
    assertTrue(cyan.b > cyan.g and cyan.g > cyan.r and cyan.r < 0.5, "a cyan")
end)

test("table: the Ask button wears its state's tone: red to ask, yellow once asked, green once traded", function()
    local NS, drawn = shownTable()
    local R, Y, G = NS.Constants.TONE.red, NS.Constants.TONE.yellow, NS.Constants.TONE.good
    local ask = rowFor(drawn, 1).cells.actions.ask
    assertEqual(ask.tone, "red"); assertEqual(select(1, ask.label:GetTextColor()), R.r)
    NS.Asks.StateOf = function() return "sent" end
    NS.Window.Refresh()
    ask = rowFor(NS.WindowGroup.Drawn(), 1).cells.actions.ask
    assertEqual(textOf(ask.label), "Asked"); assertEqual(ask.tone, "yellow")
    assertEqual(select(2, ask.label:GetTextColor()), Y.g)
    NS.History.OutcomeOf = function() return "received" end
    NS.Window.Refresh()
    ask = rowFor(NS.WindowGroup.Drawn(), 1).cells.actions.ask
    assertEqual(textOf(ask.label), "Traded"); assertEqual(ask.tone, "good")
    assertEqual(select(2, ask.label:GetTextColor()), G.g)
end)

-- ── the Type column (feedback-4 spec §3) ────────────────────────────────────────────────────

test("cells: Type names the armor type, Jewelry, Trinkets, Cloak or Weapons, else a dash with why", function()
    local NS = T.newAddon()
    local W, A = NS.WindowCells, NS.Constants.ARMOR_SUBCLASS
    local ARMOR = NS.Constants.ITEM_CLASS.ARMOR
    local function typeOf(loc, classID, sub)
        return W.ArmorType(drop({ facts = { ilvl = 300, equipLoc = loc, classID = classID, subClassID = sub } }))
    end
    assertEqual(typeOf("INVTYPE_HEAD", ARMOR, A.PLATE).text, "Plate")
    assertEqual(typeOf("INVTYPE_CHEST", ARMOR, A.CLOTH).text, "Cloth")
    assertEqual(typeOf("INVTYPE_ROBE", ARMOR, A.CLOTH).text, "Cloth")
    assertEqual(typeOf("INVTYPE_HAND", ARMOR, A.LEATHER).text, "Leather")
    assertEqual(typeOf("INVTYPE_FEET", ARMOR, A.MAIL).text, "Mail")
    assertEqual(typeOf("INVTYPE_NECK", ARMOR, A.GENERIC).text, "Jewelry")
    assertEqual(typeOf("INVTYPE_FINGER", ARMOR, A.GENERIC).text, "Jewelry")
    assertEqual(typeOf("INVTYPE_TRINKET", ARMOR, A.GENERIC).text, "Trinkets")
    assertEqual(typeOf("INVTYPE_CLOAK", ARMOR, A.CLOTH).text, "Cloak", "a cloak is never Cloth")
    for _, loc in ipairs({ "INVTYPE_WEAPON", "INVTYPE_2HWEAPON", "INVTYPE_WEAPONMAINHAND", "INVTYPE_WEAPONOFFHAND",
        "INVTYPE_SHIELD", "INVTYPE_HOLDABLE", "INVTYPE_RANGED", "INVTYPE_RANGEDRIGHT" }) do
        assertEqual(typeOf(loc, 2, 7).text, "Weapons", loc)
    end
    local cosmetic = typeOf("INVTYPE_HEAD", ARMOR, A.COSMETIC)
    assertEqual(cosmetic.text, "–"); assertFalse(cosmetic.known); assertEqual(cosmetic.tone, "muted")
    local token = typeOf(nil, 15, 0)
    assertEqual(token.text, "–"); assertTrue(#token.tip >= 2 and token.tip[2] ~= "", "the dash says why")
    local plate = typeOf("INVTYPE_HEAD", ARMOR, A.PLATE)
    assertEqual(plate.tip[1], "Type: Plate"); assertTrue(plate.known)
end)

test("table: the Type column sits after Slot and is painted on every row", function()
    local _, drawn = shownTable()
    local c = rowFor(drawn, 2).cells
    assertEqual(textOf(c.armorType.text), "Jewelry", "the ring")
    assertEqual(textOf(drawn.pane.colHead.labels.armorType.text), "Type")
    local keysShown = {}
    for _, col in ipairs(drawn.columns) do keysShown[#keysShown + 1] = col.key end
    assertEqual(keysShown[3] .. "," .. keysShown[4], "slot,armorType")
end)
