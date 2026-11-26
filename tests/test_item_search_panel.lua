-- tests/test_item_search_panel.lua — the Item Search window's verdict panel (round 4 addendum A1,
-- R4-DW-11; modules/ItemSearchVerdictPanel.lua): shown under Matches while this character holds the
-- item shown (bags, or the bank alone through the client's cached count), hidden otherwise with the
-- Matches list back at the footer; the tooltip's badge from the one builder; the score's breakdown
-- (NS.ItemSearchVerdict.Breakdown's lines, a total, the word's line) drawn as the verdict module
-- gives it; a bag change repainting it, throttled; and the panel giving way to the Matches list's
-- five rows in a short window. Every ForeverDB value is the kit fake's invented data
-- (tests/_kit/mock_foreverdb.lua); every count below is invented.

local T = _G.DW_TEST
local test, assertEqual, assertTrue, assertFalse =
    T.test, T.assertEqual, T.assertTrue, T.assertFalse

local FDB = dofile("tests/_kit/mock_foreverdb.lua")
local IDS = FDB.IDS

local FOREVER_ONLY = (not T.forever) and "WoW Forever's alone (clients-§4): the panel rides the Item Search window" or nil

-- The addon enabled with the ForeverDB fake loaded; `held[id] = { bags, bank, worn }` is what
-- C_Item.GetItemCount answers as the client does: the bags and what you wear, the bank only when
-- asked for. Each worn one is in a slot of `m.inventoryIDs.player` too (GetInventoryItemID's).
local function enabled()
    local held = {}
    local NS, _, m = T.enableAddon{ mock = function(mm)
        FDB.install(mm, { preset = "present" })
        mm.GetCoinTextureString = function(copper) return ("%dc"):format(copper) end
        mm.C_Item.GetItemCount = function(id, bank)
            local h = held[id]
            if not h then return 0 end
            return h[1] + (h[3] or 0) + (bank and h[2] or 0)
        end
    end }
    m.fireEvent("PLAYER_ENTERING_WORLD", true, false)
    m.advance(5)
    return NS, m, held
end

-- The point `name` of `region` last set, as { point, relativeTo, relativePoint, x, y }, or nil.
local function pointOf(region, name)
    local found, i = nil, 1
    while true do
        local p = { region:GetPoint(i) }
        if p[1] == nil then return found end
        if p[1] == name then found = p end
        i = i + 1
    end
end

local function lineTexts(lines)
    local out = {}
    for i, line in ipairs(lines) do out[i] = line.text end
    return out
end

test("verdict panel: shown under Matches while you hold the item in your bags, with the tooltip's badge", function()
    local NS, _, held = enabled()
    local W, P = NS.ItemSearchWindow, NS.ItemSearchVerdictPanel
    held[IDS.blade] = { 2, 0 }
    W.ShowItem(IDS.blade)
    local f = W.Frame()
    -- red under: no panel (the window before A1)
    assertTrue(f.verdict ~= nil and f.verdict:IsShown(), "the panel shows")
    assertEqual(f.verdict.head.title:GetText(), "Verdict")
    assertEqual(f.verdict.head.note:GetText(), "You have 2")
    local b = f.verdict.dwBreakdown
    local badge = NS.ItemSearchTip.Badge(b)
    -- the same pill as the tooltip's (R5-DW-02): IST.Badge's parts, drawn by IST.FillBadge on IST.MakeBadge's
    -- regions, hung by its left edge (nothing measured)
    local st = f.verdict.badge
    assertEqual(st.text:GetText(), badge.text)
    assertEqual(badge.text, badge.word .. " " .. tostring(b.score))
    assertTrue(st.text:IsShown() and st.piece.c:IsShown() and st.piece.tl:IsShown(), "the pill shown")
    local B = NS.Constants.ITEM_SEARCH.BADGE
    local p = st.icon.__points[1]
    assertTrue(p[1] == "LEFT" and p[2] == f.verdict and p[3] == "TOPLEFT" and p[4] == 4 + B.PAD, "hung by its left edge: " .. table.concat({ tostring(p[1]), tostring(p[2] == f.verdict), tostring(p[3]), tostring(p[4]) }, ","))
    local bottom = pointOf(f.matchScroll, "BOTTOMLEFT")
    assertTrue(bottom[2] == f.verdict, "the Matches list ends above the panel")
    assertTrue(#P.Lines(f) >= 2, "the breakdown's lines")
end, FOREVER_ONLY)

test("verdict panel: shown when the item is only in your bank (the client's cached count, bank closed)", function()
    local NS, _, held = enabled()
    local W = NS.ItemSearchWindow
    held[IDS.blade] = { 0, 3 }
    W.ShowItem(IDS.blade)
    local f = W.Frame()
    -- red under: the bags alone counted
    assertTrue(f.verdict:IsShown(), "held in the bank: shown")
    assertEqual(f.verdict.head.note:GetText(), "You have 3")
end, FOREVER_ONLY)

test("verdict panel: hidden when you hold none, the Matches list down to the footer", function()
    local NS = enabled()
    local W, P = NS.ItemSearchWindow, NS.ItemSearchVerdictPanel
    W.ShowItem(IDS.blade)
    local f = W.Frame()
    -- red under: a panel for every item shown
    assertFalse(f.verdict:IsShown(), "not held: hidden")
    assertEqual(#P.Lines(f), 0)
    local bottom = pointOf(f.matchScroll, "BOTTOMLEFT")
    assertTrue(bottom[2] == f, "the Matches list takes the full height")
    assertEqual(bottom[5], NS.FooterMetric("HEIGHT") + 4)
    W.Open()
    W.Clear()
    assertFalse(f.verdict:IsShown(), "no item shown: hidden")
end, FOREVER_ONLY)

test("verdict panel: its lines are the verdict module's breakdown, in order, adding up to the score", function()
    local NS, _, held = enabled()
    local W, P, IS = NS.ItemSearchWindow, NS.ItemSearchVerdictPanel, NS.ItemSearch
    held[IDS.blade] = { 1, 0 }
    W.ShowItem(IDS.blade)
    local f = W.Frame()
    local facts = IS.Get(IDS.blade)
    local b = NS.ItemSearchVerdict.Breakdown(IDS.blade, facts, IS.Me(facts.ranks))
    local lines = P.Lines(f)
    local n = #b.lines
    local sum = 0
    -- red under (R6-DW-08): no sections; the parts under "Why this word", a gold header
    assertEqual(lines[1].text, "Why this word"); assertEqual(lines[1].tone, "mutedGold")
    table.remove(lines, 1)
    for i, part in ipairs(b.lines) do
        -- red under: a panel that words or adds up the parts itself
        assertEqual(lines[i].text, part.text)
        assertEqual(tonumber(lines[i].right), part.points)
        -- red under (R5-DW-04): every number in one tone
        assertEqual(lines[i].rightTone, part.points > 0 and "good" or "red", "+ green, - red: " .. part.text)
        sum = sum + part.points
    end
    assertEqual(sum, b.use, "the parts add up to the use value (R6-DW-07)")
    assertEqual(lines[n + 1].text, b.from, "the line the verdict word comes from, right after the parts")
    assertEqual(lines[n + 1].tone, "muted"); assertEqual(lines[n + 1].right, "")
    assertTrue(b.from:find("^Use value %-?%d+ %(") ~= nil, "the use value and its band: " .. b.from)
    -- then "How sure": the score's parts, the data known and the score (the design's Score line)
    local at
    for i, line in ipairs(lines) do if line.text == "How sure" then at = i end end
    assertTrue(at ~= nil and lines[at].tone == "mutedGold", "a How sure header")
    for i, s in ipairs(b.sure) do
        assertEqual(lines[at + i].text, s.text); assertEqual(lines[at + i].right, s.right)
    end
    assertEqual(lines[at + #b.sure].text, "Score"); assertEqual(lines[at + #b.sure].right, tostring(b.score))
    if b.hint then assertEqual(lines[at + #b.sure + 1].text, b.hint, "the missing input as a plain hint, last") end
    for _, text in ipairs(lineTexts(lines)) do
        assertTrue(not text:find("Low") and not text:find("Medium") and not text:find("High"), "no tier: " .. text)
    end
end, FOREVER_ONLY)

test("verdict panel: + points green, - points red, the word's line in plain words, then How sure (R5-DW-04..06, R6-DW-08)", function()
    local NS = enabled()
    local rows = NS.ItemSearchVerdictPanel.Rows({ score = 15, use = 15, from = "Invented word line",
        lines = { { kind = "quest", text = "Invented gain", points = 35 }, { kind = "damper", text = "Invented loss", points = -20 } },
        sure = { { text = "Invented evidence", right = "50%" }, { text = "Score", right = "15" } }, hint = "Invented hint" })
    assertEqual(#rows, 9, "two headers, the two parts, the word's line, a spacer, two sure lines and the hint")
    assertEqual(rows[1].text, "Why this word"); assertEqual(rows[1].tone, "mutedGold")
    assertEqual(rows[2].right, "+35"); assertEqual(rows[2].rightTone, "good")
    assertEqual(rows[3].right, "-20"); assertEqual(rows[3].rightTone, "red")
    assertEqual(rows[4].text, "Invented word line"); assertEqual(rows[4].tone, "muted")
    assertTrue(rows[4].right == nil, "no number on the word's line")
    assertEqual(rows[5].text, "", "a blank line between the sections")
    assertEqual(rows[6].text, "How sure"); assertEqual(rows[6].tone, "mutedGold")
    assertEqual(rows[7].text, "Invented evidence"); assertEqual(rows[7].right, "50%")
    assertEqual(rows[8].text, "Score"); assertEqual(rows[8].right, "15")
    assertEqual(rows[9].text, "Invented hint"); assertEqual(rows[9].tone, "muted")
end, FOREVER_ONLY)

test("verdict panel: a (?) beside the badge explains the score from the scorer's own numbers (R5-DW-07)", function()
    local NS, _, held = enabled()
    local W, V = NS.ItemSearchWindow, NS.Constants.ITEM_SEARCH.VERDICT
    held[IDS.blade] = { 1, 0 }
    W.ShowItem(IDS.blade)
    local f = W.Frame()
    local help = f.verdict.help
    -- red under: no (?) (the owner: "Add a (?) icon next to the score")
    assertTrue(help ~= nil, "a (?) on the panel")
    -- red under (GLYPH-02, the owner's pick): Open Iconic's `help`; the help mark is ph:question,
    -- the filled circle with the ? cut out
    assertEqual(help.icon.__texture, NS.Icon("ph:question"))
    assertTrue(help.icon.__texture:find("phosphor\\question", 1, true) ~= nil, "LibKa0s' ph:question: " .. help.icon.__texture)
    local p = help.__points[1]
    assertTrue(p[1] == "LEFT" and p[2] == f.verdict.badge.piece.r and p[3] == "RIGHT", "right after the pill")
    local lines = NS.Window.TooltipOf(help)
    assertEqual(lines[1], "How the verdict and score work")
    local text = table.concat(lines, "\n")
    for _, want in ipairs({ ("+%d each"):format(V.QUEST_LOG), ("+%d each"):format(V.QUEST_CAN),
        ("orange +%d, yellow +%d, green +%d"):format(V.CRAFT.orange, V.CRAFT.yellow, V.CRAFT.green),
        ("an upgrade +%d"):format(V.UPGRADE), (": %d"):format(V.REBUY), (": %d"):format(V.TRIVIAL),
        ("Keep: a use value of %d or more. Hold: %d to %d."):format(V.KEEP, V.HOLD, V.KEEP - 1),
        ("A use value under %d: Auction or Vendor"):format(V.HOLD),
        ("Under %d%%"):format(V.HIGH), ("under %d%%"):format(V.MEDIUM),
        -- the score (R6-DW-08): how sure, from the evidence and the data known
        "Score = evidence for the word x data known", ("A Hold only because too little is known: %d%%"):format(V.SURE.FALLBACK * 100) }) do
        assertTrue(text:find(want, 1, true) ~= nil, "names " .. want)
    end
    -- read from the constants, never copied: a moved bar moves the help
    local keep = V.KEEP
    V.KEEP = 61
    assertTrue(table.concat(NS.Window.TooltipOf(help), "\n"):find("Keep: a use value of 61 or more. Hold: 20 to 60.", 1, true) ~= nil)
    V.KEEP = keep
end, FOREVER_ONLY)

test("verdict panel: the tooltip's pill, the panel's pill and its (?) are one size, within a tooltip line (R6-DW-02)", function()
    local NS, m, held = enabled()
    local W, B = NS.ItemSearchWindow, NS.Constants.ITEM_SEARCH.BADGE
    held[IDS.blade] = { 1, 0 }
    -- every button's size recorded (the kit's frames record no geometry)
    local make = m.CreateFrame
    m.CreateFrame = function(kind, ...)
        local fr = make(kind, ...)
        if kind == "Button" then rawset(fr, "SetSize", function(self, w, h) self.dwW, self.dwH = w, h end) end
        return fr
    end
    W.ShowItem(IDS.blade)
    m.CreateFrame = make
    local f = W.Frame()
    -- red under: a 16 px pill on a 14 px tooltip line (it ran into the reason line under it, the
    -- owner's "overlaps the text below it sometimes") with a separate, larger (?) beside it
    assertTrue(B.HEIGHT <= B.LINE, ("the pill (%s) fits a tooltip line's pitch (%s)"):format(tostring(B.HEIGHT), tostring(B.LINE)))
    assertTrue(B.ICON < B.HEIGHT and B.FONT <= B.ICON, "the icon and the text inside the pill")
    assertTrue(B.HELP == nil, "no size of the (?) apart from the pill's")
    local help = f.verdict.help
    assertEqual(help.dwW, B.HEIGHT, "the (?) as wide as the pill is tall")
    assertEqual(help.dwH, B.HEIGHT, "the (?) as tall as the pill")
    local tl = f.verdict.badge.piece.tl.__points[1]
    assertEqual(tl[5], B.HEIGHT / 2, "the panel's pill is HEIGHT tall")
end, FOREVER_ONLY)

test("verdict panel: a bag change for the item repaints it, throttled, and its hiding restores the Matches height", function()
    local NS, m, held = enabled()
    local W = NS.ItemSearchWindow
    held[IDS.blade] = { 2, 0 }
    W.ShowItem(IDS.blade)
    local f = W.Frame()
    assertTrue(f.verdict:IsShown())
    held[IDS.blade] = { 5, 0 }
    m.__fire("BAG_UPDATE_DELAYED")
    m.__fire("BAG_UPDATE_DELAYED")
    -- throttled: nothing moves before C.ITEM_SEARCH.PANEL.THROTTLE
    assertEqual(f.verdict.head.note:GetText(), "You have 2", "not repainted at once")
    m.advance(NS.Constants.ITEM_SEARCH.PANEL.THROTTLE + 0.01)
    -- red under: a panel painted once, at ShowItem, and never again
    assertEqual(f.verdict.head.note:GetText(), "You have 5", "repainted after the throttle")
    held[IDS.blade] = nil
    m.__fire("BAG_UPDATE_DELAYED")
    m.advance(NS.Constants.ITEM_SEARCH.PANEL.THROTTLE + 0.01)
    assertFalse(f.verdict:IsShown(), "sold: hidden")
    assertTrue(pointOf(f.matchScroll, "BOTTOMLEFT")[2] == f, "the Matches list's full height restored")
    -- the bank alone: PLAYERBANKSLOTS_CHANGED brings it back
    held[IDS.blade] = { 0, 1 }
    m.__fire("PLAYERBANKSLOTS_CHANGED")
    m.advance(NS.Constants.ITEM_SEARCH.PANEL.THROTTLE + 0.01)
    assertTrue(f.verdict:IsShown(), "banked: shown again")
    W.Close()
    held[IDS.blade] = nil
    m.__fire("BAG_UPDATE_DELAYED")
    m.advance(NS.Constants.ITEM_SEARCH.PANEL.THROTTLE + 0.01)
    assertTrue(f.verdict:IsShown(), "a closed window is not repainted")
end, FOREVER_ONLY)

test("verdict panel: the Matches list keeps its 5 rows; the panel takes every other pixel, so a resize moves the panel alone (R6-DW-05)", function()
    local NS, _, held = enabled()
    local W, P = NS.ItemSearchWindow, NS.ItemSearchVerdictPanel
    local K, ISG, PANEL = NS.Constants.WINDOW, NS.ItemSearchGrid, NS.Constants.ITEM_SEARCH.PANEL
    held[IDS.blade] = { 1, 0 }
    W.ShowItem(IDS.blade)
    local f = W.Frame()
    local rowH = NS.WindowRows.Metrics().height
    local top = ISG.HEADER_H + PANEL.GAP + NS.Constants.ITEM_SEARCH.BADGE.HEIGHT + PANEL.GAP
    local function column(height)
        return height - (1 + K.TITLE_H + 8 + K.CONTROL_H + 8 + ISG.HEADER_H + 2) - (NS.FooterMetric("HEIGHT") + 4)
    end
    -- red under (the owner: "Resizing the window vertically should resize the verdict panel not the
    -- matches panel"): the panel held at 8 lines and the Matches list taking the rest
    assertEqual(PANEL.LINES, nil, "no line count holds the panel")
    -- the default 600 tall window: the Matches list MIN_ROWS rows, the panel the rest
    assertEqual(P.Height(f, rowH), column(600) - PANEL.MIN_ROWS * rowH - PANEL.GAP)
    assertEqual(f.verdict:GetHeight(), P.Height(f, rowH))
    -- taller: every added pixel is the panel's, the Matches list's height unchanged
    f:SetSize(980, 800)
    assertEqual(P.Height(f, rowH), column(800) - PANEL.MIN_ROWS * rowH - PANEL.GAP)
    assertEqual(column(800) - P.Height(f, rowH) - PANEL.GAP, PANEL.MIN_ROWS * rowH, "the Matches list stays MIN_ROWS rows")
    W.Refresh()
    assertEqual(f.verdict:GetHeight(), P.Height(f, rowH), "a repaint lays the panel out at the new height")
    -- a short window with tall rows: the Matches list still keeps MIN_ROWS rows, the panel shrinks
    f:SetSize(760, 440)
    local h = P.Height(f, 30)
    assertEqual(column(440) - h - PANEL.GAP, PANEL.MIN_ROWS * 30, "five 30 px rows of matches kept")
    assertTrue(h >= top + 30, "down to its header, the badge and one line at least")
    -- rows so tall that both cannot fit: the panel keeps its header, the badge and one line
    assertEqual(P.Height(f, 60), top + 60)
end, FOREVER_ONLY)

test("verdict panel: a corner drag re-lays it without working the breakdown out again", function()
    local NS, _, held = enabled()
    local W = NS.ItemSearchWindow
    held[IDS.blade] = { 1, 0 }
    W.ShowItem(IDS.blade)
    local f = W.Frame()
    local IVD = NS.ItemSearchVerdict
    local real, calls = IVD.Breakdown, 0
    IVD.Breakdown = function(...) calls = calls + 1; return real(...) end
    f.resizeGrip:__fire("OnMouseDown", "LeftButton")
    f:SetSize(1200, 700)
    f.resizeGrip:__fire("OnMouseUp", "LeftButton")
    W.Refresh()
    -- red under: the breakdown worked out on every repaint
    assertEqual(calls, 0, "kept while the item, the count and the verdict memo stand")
    IVD.Bump()
    W.Refresh()
    assertEqual(calls, 1, "the verdict memo moved: worked out again")
    IVD.Breakdown = real
end, FOREVER_ONLY)

test("verdict panel: while the item's info is still loading it is worked out again on its own, four times at most", function()
    local NS, m, held = enabled()
    local W, IVD = NS.ItemSearchWindow, NS.ItemSearchVerdict
    held[IDS.blade] = { 1, 0 }
    local real, calls = IVD.Breakdown, 0
    IVD.Breakdown = function(...) calls = calls + 1; return real(...) end
    -- the double caches no item info for the blade: an unsettled breakdown, its fix the plain hint
    W.ShowItem(IDS.blade)
    local f = W.Frame()
    assertEqual(calls, 1)
    assertEqual(f.verdict.dwBreakdown.hint, "Item info is still loading")
    m.advance(NS.Constants.ITEM_SEARCH.VERDICT.RETRY + 0.01)
    -- red under: a panel kept on "still loading" until some other event
    assertEqual(calls, 2, "worked out again RETRY seconds on")
    m.advance(10)
    assertEqual(calls, 1 + NS.Constants.ITEM_SEARCH.PANEL.RETRIES, "and no more than RETRIES times")
    IVD.Breakdown = real
end, FOREVER_ONLY)

test("verdict panel: an item you only wear is not held; one worn, one in the bags and two banked reads You have 3", function()
    local NS, m, held = enabled()
    local W = NS.ItemSearchWindow
    local MH = NS.Constants.SLOT.MAINHAND
    m.inventoryIDs.player = { [MH] = IDS.blade }
    held[IDS.blade] = { 0, 0, 1 }
    -- red under: C_Item.GetItemCount's count taken whole, the worn one with it
    assertEqual(select(2, NS.Compat.ItemCount(IDS.blade)), 0, "worn alone: none held")
    W.ShowItem(IDS.blade)
    local f = W.Frame()
    assertFalse(f.verdict:IsShown(), "worn alone: hidden")
    held[IDS.blade] = { 1, 2, 1 }
    local bags, total = NS.Compat.ItemCount(IDS.blade)
    assertEqual(bags, 1); assertEqual(total, 3)
    W.ShowItem(IDS.blade)
    assertTrue(f.verdict:IsShown())
    assertEqual(f.verdict.head.note:GetText(), "You have 3", "the bags and the bank, not the worn one")
end, FOREVER_ONLY)

-- The blade as cached gear (an invented one-hander) judged `verdict.gear` by a stubbed feed judge,
-- under a stubbed gear snapshot whose signature is `verdict.sig`. Answers the undo.
local function gearBlade(NS, m, verdict)
    local realInfo = m.C_Item.GetItemInfo
    m.C_Item.GetItemInfo = function(id)
        if id == IDS.blade then
            return "Fixture Blade", "item:990101", 2, 15, 10, "", "", 1, "INVTYPE_WEAPON", 7, 250, 2, 0, 0
        end
        return realInfo(id)
    end
    local IF, LF, G = NS.ItemFacts, NS.LootFeed, NS.Gear
    local get, judge, snap = IF.Get, LF.JudgeMe, G.Snapshot
    IF.Get = function() return {} end
    LF.JudgeMe = function() return { verdict = verdict.gear, reasons = {} } end
    G.Snapshot = function() return { signature = verdict.sig } end
    return function()
        m.C_Item.GetItemInfo, IF.Get, LF.JudgeMe, G.Snapshot = realInfo, get, judge, snap
    end
end

test("verdict panel: a gear change works the breakdown out again, so it and the tooltip's badge agree", function()
    local NS, m, held = enabled()
    local W, IVD, IS = NS.ItemSearchWindow, NS.ItemSearchVerdict, NS.ItemSearch
    local verdict = { gear = "upgrade", sig = "worn-1" }
    local undo = gearBlade(NS, m, verdict)
    held[IDS.blade] = { 1, 0 }
    W.ShowItem(IDS.blade)
    local f = W.Frame()
    local facts = IS.Get(IDS.blade)
    -- the use value (R6-DW-07: the parts' sum; the score shown is how sure) and the score, both compared
    local function tooltipUse() return IVD.For(IDS.blade, facts, IS.Me(facts.ranks)).use end
    local function tooltipScore() return IVD.For(IDS.blade, facts, IS.Me(facts.ranks)).score end
    local before = f.verdict.dwBreakdown.use
    assertEqual(before, tooltipUse()); assertEqual(f.verdict.dwBreakdown.score, tooltipScore())
    -- you equip something better: the gear snapshot moves, and Drop Watcher's own GearChanged says so
    verdict.gear, verdict.sig = "downgrade", "worn-2"
    NS.addon:SendMessage(NS.MSG.GEAR_CHANGED)
    m.advance(NS.Constants.ITEM_SEARCH.PANEL.THROTTLE + 0.01)
    -- red under: the panel keeping "Upgrade for you +70" while the tooltip works out the new verdict
    assertEqual(f.verdict.dwBreakdown.use, tooltipUse(), "the panel and the tooltip agree")
    assertEqual(f.verdict.dwBreakdown.score, tooltipScore())
    assertEqual(f.verdict.dwBreakdown.use, before - NS.Constants.ITEM_SEARCH.VERDICT.UPGRADE, "the upgrade gone")
    -- a window repaint after a gear move with no event yet: worked out again too, as the tooltip's memo is
    verdict.gear, verdict.sig = "upgrade", "worn-3"
    W.Refresh()
    assertEqual(f.verdict.dwBreakdown.score, tooltipScore())
    assertEqual(f.verdict.dwBreakdown.use, before)
    undo()
end, FOREVER_ONLY)

test("verdict panel: still loading after its retries, a repaint or coming back to the item works it out again", function()
    local NS, m, held = enabled()
    local W, IVD = NS.ItemSearchWindow, NS.ItemSearchVerdict
    local RETRIES = NS.Constants.ITEM_SEARCH.PANEL.RETRIES
    held[IDS.blade] = { 1, 0 }
    held[IDS.leather] = { 1, 0 }
    local real, calls = IVD.Breakdown, 0
    IVD.Breakdown = function(...) calls = calls + 1; return real(...) end
    -- the double caches no item info for the blade: never settled
    W.ShowItem(IDS.blade)
    m.advance(10)
    assertEqual(calls, 1 + RETRIES, "the retries spent")
    W.Refresh()
    -- red under: "Item info is still loading" kept until the count or the verdict memo moves
    assertEqual(calls, 2 + RETRIES, "a window repaint works an unsettled breakdown out again")
    m.advance(10)
    assertEqual(calls, 2 + RETRIES, "and starts no timer of its own")
    W.ShowItem(IDS.leather)
    local away = calls
    W.ShowItem(IDS.blade)
    assertEqual(calls, away + 1)
    m.advance(NS.Constants.ITEM_SEARCH.VERDICT.RETRY + 0.01)
    -- red under: no retries for an item that spent them once
    assertEqual(calls, away + 2, "back on the blade: its retries again")
    IVD.Breakdown = real
end, FOREVER_ONLY)
