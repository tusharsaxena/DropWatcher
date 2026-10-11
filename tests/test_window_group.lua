-- tests/test_window_group.lua — the Group drops table (design spec §11.1-§11.2, boards 01, 03 and
-- 06): every cell's text, glyph, tone and reason tooltip (modules/WindowCells.lua, pure), the
-- column sets and the entry order (modules/WindowGroup.lua's pure halves), then the table built
-- headless under the mock: pooled rows, encounter headers that collapse, item buttons, the Ask
-- button, the dismiss mark, the compact preset, the filters and the empty state.

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

test("cells: Me shows the signed change beside ▲ ≈ ▽, green for an upgrade and gray for a downgrade", function()
    local W = WC()
    local up = W.Me(drop())
    assertEqual(up.text, "+19"); assertEqual(up.glyph, "▲"); assertEqual(up.tone, "good")
    local side = W.Me(drop({ me = { verdict = "sidegrade", ilvlDelta = 0.4, reasons = {} } }))
    assertEqual(side.text, "+0"); assertEqual(side.glyph, "≈"); assertEqual(side.tone, "plain")
    local down = W.Me(drop({ me = { verdict = "downgrade", ilvlDelta = -13, reasons = {} } }))
    assertEqual(down.text, "-13"); assertEqual(down.glyph, "▽"); assertEqual(down.tone, "bad")
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

test("cells: the Them column inverts the tones: their upgrade is amber, their downgrade green", function()
    local W = WC()
    local down = W.Them(drop(), 100)
    assertEqual(down.text, "-13"); assertEqual(down.glyph, "▽"); assertEqual(down.tone, "good")
    assertEqual(down.tip[1], "For Seta: Downgrade")
    local up = W.Them(drop({ them = { verdict = "upgrade", ilvlDelta = 12, reasons = {} } }), 100)
    assertEqual(up.tone, "warn")
    local cant = W.Them(drop({ them = { verdict = "cantUse", reasons = {} } }), 100)
    assertEqual(cant.tone, "good", "they cannot use it: good news for you")
end)

test("cells: Them is a dash on your own drop and `?` with the inspect's reason while unread", function()
    local W = WC()
    local mine = W.Them(drop({ isMine = true, them = NONE }), 100)
    assertEqual(mine.text, "–"); assertTrue(mine.tip[2]:find("My drops") ~= nil)
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

-- ── the Their eq column ─────────────────────────────────────────────────────────────────────

test("cells: Their eq shows both rings for a ring, one item for a helm, and the read's age", function()
    local W = WC()
    local gear = { [1] = { link = OLD1, ilvl = 324 }, [11] = { link = OLD1, ilvl = 300 }, [12] = { link = OLD2, ilvl = 296 } }
    local helm = W.TheirEq(drop(), gear, 100)
    assertEqual(#helm.items, 1); assertEqual(helm.text, "40s"); assertEqual(helm.tone, "plain")
    assertEqual(helm.tip[1], "Seta wears")
    assertEqual(helm.tip[2], "Old Band (324)")
    local ring = W.TheirEq(drop({ facts = { ilvl = 311, equipLoc = "INVTYPE_FINGER" }, link = RING }), gear, 100)
    assertEqual(#ring.items, 2, "rings compare with both worn rings")
    local none = W.TheirEq(drop(), nil, 100)
    assertEqual(#none.items, 0); assertTrue(joined(none.tip):find("Nothing read") ~= nil)
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
    assertFalse(mine.offered); assertEqual(mine.text, "–"); assertTrue(mine.tip[2]:find("My drops") ~= nil)
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

test("table: the default columns, the compact preset's, and a column the profile turns off", function()
    local WG = T.newAddon().WindowGroup
    assertEqual(keys(WG.Columns(false)), "item,ilvl,slot,looter,theirEq,me,them,trade,actions")
    assertEqual(keys(WG.Columns(true)), "item,ilvl,theirEq,me,actions")
    assertEqual(keys(WG.Columns(false, { slot = false, item = false, them = true })),
        "item,ilvl,looter,theirEq,me,them,trade,actions", "Item never hides")
end)

test("table: the Item column takes the slack, never less than its minimum", function()
    local NS = T.newAddon()
    local WG, K = NS.WindowGroup, NS.Constants.WINDOW
    local cols = WG.Columns(true)
    local wide = WG.Layout(cols, 600)
    local fixed = 40 + 84 + 70 + 96 + 5 * K.CELL_GAP
    assertEqual(wide.item.w, 600 - fixed)
    assertEqual(wide.ilvl.x, wide.item.w + K.CELL_GAP)
    assertEqual(WG.Layout(cols, 100).item.w, K.ITEM_MIN)
end)

local function ctxOf(pass, sort)
    return { matches = pass or function() return true end, filter = { sort = sort or "newest" },
        compare = function(a, b) return a.id > b.id end }
end

test("table: groups newest first, the first open and older ones collapsed, empty ones left out", function()
    local WG = T.newAddon().WindowGroup
    local byId = { [1] = drop({ id = 1 }), [2] = drop({ id = 2 }), [3] = drop({ id = 3 }), [4] = drop({ id = 4 }) }
    local groups = {
        { key = "a", drops = { 1 } }, { key = "b", drops = { 2, 3 } }, { key = "c", drops = { 4 } },
    }
    local get = function(id) return byId[id] end
    local e = WG.Entries(groups, get, ctxOf(function(d) return d.id ~= 4 end), {})
    assertEqual(e[1].kind, "header"); assertEqual(e[1].group.key, "b", "c has no matching drop")
    assertFalse(e[1].collapsed); assertEqual(e[1].count, 2)
    assertEqual(e[2].drop.id, 3, "the tab's order within the group"); assertEqual(e[3].drop.id, 2)
    assertEqual(e[4].group.key, "a"); assertTrue(e[4].collapsed); assertEqual(#e, 4)
    local toggled = WG.Entries(groups, get, ctxOf(), { collapsed = { a = false, c = true }, dismissed = { [2] = true } })
    assertEqual(toggled[1].group.key, "c"); assertTrue(toggled[1].collapsed, "the player's toggle wins")
    assertEqual(toggled[2].group.key, "b"); assertEqual(toggled[2].count, 1, "a dismissed drop is gone")
    local oldest = WG.Entries(groups, get, ctxOf(nil, "oldest"), {})
    assertEqual(oldest[1].group.key, "a", "Sort: Oldest turns the groups round")
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
    assertEqual(textOf(c.me.text), "+19"); assertEqual(textOf(c.me.glyph), "▲")
    assertEqual(textOf(c.them.text), "-13"); assertEqual(textOf(c.trade.text), "Likely")
    assertEqual(textOf(c.actions.ask.label), "Ask"); assertTrue(c.actions.ask:IsShown())
    local r2 = rowFor(drawn, 2)
    assertEqual(textOf(r2.cells.them.text), "?"); assertEqual(textOf(r2.cells.theirEq.text), "range")
    assertEqual(textOf(r2.cells.trade.text), "Unknown")
    assertFalse(drawn.pane.placeholder:IsShown(), "drops on screen: no empty line")
    assertEqual(textOf(drawn.pane.colHead.labels.theirEq.text), "Their eq")
    assertTrue(NS.Window.Frame().panes.group:IsShown())
end)

test("table: the verdicts wear their tones, the looter their class color, the item its quality", function()
    local NS, drawn = shownTable()
    local c = rowFor(drawn, 1).cells
    local G = NS.Constants.TONE.good
    local r, g, b = c.me.text:GetTextColor()
    assertEqual(table.concat({ r, g, b }, ","), table.concat({ G.r, G.g, G.b }, ","), "an upgrade for you is green")
    r, g = c.them.text:GetTextColor()
    assertEqual(r .. "," .. g, G.r .. "," .. G.g, "their downgrade is green too: the Them column is inverted")
    r = c.looter.text:GetTextColor()
    assertEqual(r, 1, "a priest is white")
end)

test("table: every shown cell has a reason tooltip; nothing is blank", function()
    local NS, drawn = shownTable()
    local W = NS.Window
    for _, row in ipairs(drawn.rows) do
        for key, cell in pairs(row.cells) do
            if cell:IsShown() and key ~= "actions" then
                assertTrue(#W.TooltipOf(cell) >= 2, key .. " has a reason")
                assertTrue((cell.text:GetText() or "") ~= "", key .. " is not blank")
            end
        end
        local a = row.cells.actions
        local tipHost = a.ask:IsShown() and a.ask or a.dashTip
        assertTrue(#W.TooltipOf(tipHost) >= 2, "the Ask cell has a reason")
        assertTrue(#W.TooltipOf(a.dismiss) >= 2)
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

test("table: Their eq shows the looter's worn item from their inspect read", function()
    local NS, _, m = T.enableAddon()
    m.__now = 100
    seed(NS, { GROUP }, { drop() })
    NS.Inspect.Get = function(guid)
        if guid == "Player-1-0000000A" then return { status = "fresh", at = 60, gear = { [1] = { link = OLD1, ilvl = 324 } } } end
    end
    NS.ShowWindow()
    local eq = rowFor(NS.WindowGroup.Drawn(), 1).cells.theirEq
    assertEqual(eq.icons[1].link, OLD1); assertTrue(eq.icons[1]:IsShown())
    assertFalse(eq.icons[2]:IsShown(), "a helm: one item")
    assertEqual(textOf(eq.text), "40s")
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
    seed(NS, { GROUP }, { drop({ isMine = true, them = NONE }) })
    NS.Window.Refresh()
    a = rowFor(NS.WindowGroup.Drawn(), 1).cells.actions
    assertFalse(a.ask:IsShown()); assertTrue(a.dash:IsShown())
    assertEqual(textOf(a.dash), "–")
    assertTrue(NS.Window.TooltipOf(a.dashTip)[2]:find("My drops") ~= nil)
end)

test("table: the × dismisses a row for the session", function()
    local NS, drawn = shownTable()
    rowFor(drawn, 1).cells.actions.dismiss:__fire("OnClick")
    drawn = NS.WindowGroup.Drawn()
    assertEqual(#drawn.rows, 1)
    assertTrue(rowFor(drawn, 1) == nil)
    assertTrue(NS.State.windowGroup.dismissed[1])
end)

test("table: the compact preset keeps Item and looter, Ilvl, Their eq, Me and Ask", function()
    local NS = shownTable()
    NS.SetCompact(true)
    assertTrue(NS.addon.db.profile.window.compact)
    local drawn = NS.WindowGroup.Drawn()
    assertEqual(keys(drawn.columns), "item,ilvl,theirEq,me,actions")
    local c = rowFor(drawn, 1).cells
    assertEqual(textOf(c.item.text), "Seta", "the item cell names the looter")
    assertFalse(c.slot:IsShown()); assertFalse(c.trade:IsShown())
    assertEqual(textOf(drawn.pane.colHead.labels.item.text), "Item / looter")
    assertEqual(textOf(drawn.pane.colHead.labels.actions.text), "Ask")
    assertEqual(NS.Window.TooltipOf(c.item)[1], "Crown of Roaring Storms")
    NS.ToggleCompact()
    assertEqual(#NS.WindowGroup.Drawn().columns, 9)
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
    local NS = T.enableAddon()
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
