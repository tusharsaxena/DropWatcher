-- tests/test_item_search_round7.lua — owner feedback round 7 on the Item Search window
-- (Ka0sAddonsCommonTasks docs/2026-11-27-OWNER_FEEDBACK_ROUND7/): a corner drag that only moves
-- things until the mouse comes up (R7-DW-01, "The resize drag behavior for this window is quite
-- laggy"), a tooltip on every verdict panel line (R7-DW-02) and the first section's header renamed
-- Why this verdict (R7-DW-03). Every ForeverDB value is the kit fake's invented data
-- (tests/_kit/mock_foreverdb.lua); every count below is invented.

local T = _G.DW_TEST
local test, assertEqual, assertTrue = T.test, T.assertEqual, T.assertTrue

local FDB = dofile("tests/_kit/mock_foreverdb.lua")
local IDS = FDB.IDS

local FOREVER_ONLY = (not T.forever) and "WoW Forever's alone (clients-§4): Item Search is" or nil

local function enabled()
    local held = {}
    local NS, _, m = T.enableAddon{ mock = function(mm)
        FDB.install(mm, { preset = "present" })
        mm.GetCoinTextureString = function(copper) return ("%dc"):format(copper) end
        mm.C_Item.GetItemCount = function(id, bank)
            local h = held[id]
            if not h then return 0 end
            return h[1] + (bank and h[2] or 0)
        end
    end }
    m.fireEvent("PLAYER_ENTERING_WORLD", true, false)
    m.advance(5)
    return NS, m, held
end

-- Count the SetText calls on every cell of the rows drawn now.
local function spyText(rows)
    local n = { 0 }
    for _, row in ipairs(rows) do
        for _, c in ipairs(row.cells) do
            local real = c.text.SetText
            c.text.SetText = function(...) n[1] = n[1] + 1; return real(...) end
        end
    end
    return n
end

test("item search window: a corner drag moves the columns and the panel, painting nothing until the mouse comes up (R7-DW-01)", function()
    local NS, _, held = enabled()
    local W, IVD = NS.ItemSearchWindow, NS.ItemSearchVerdict
    held[IDS.blade] = { 1, 0 }
    W.ShowItem(IDS.blade)
    local f = W.Frame()
    local rows = W.TableRows()
    assertTrue(#rows > 0, "rows drawn")
    local narrow = f.grid.layout.source.w
    local panelH = f.verdict:GetHeight()
    local texts = spyText(rows)
    local breakdowns, realB = 0, IVD.Breakdown
    IVD.Breakdown = function(...) breakdowns = breakdowns + 1; return realB(...) end
    local paints, realP = 0, NS.ItemSearchGrid.PaintTable
    NS.ItemSearchGrid.PaintTable = function(...) paints = paints + 1; return realP(...) end
    f.resizeGrip:__fire("OnMouseDown", "LeftButton")
    -- the kit's SetSize fires nothing (mock_resize.lua): the client's per-frame OnSizeChanged, fired here
    for i = 1, 5 do
        f:SetSize(1100 + i * 60, 640 + i * 20)
        f:__fire("OnSizeChanged", 1100 + i * 60, 640 + i * 20)
    end
    -- red under: every OnSizeChanged ran the full repaint (sort, every row's text and font)
    assertEqual(paints, 0, "no table paint while dragging")
    assertEqual(texts[1], 0, "no cell text set while dragging")
    assertEqual(breakdowns, 0, "the verdict not worked out while dragging")
    assertTrue(f.grid.layout.source.w > narrow, "the flex column follows the drag")
    assertEqual(rows[1]:GetWidth(), f.grid.dwW, "a row in view takes the new width")
    assertTrue(f.verdict:GetHeight() > panelH, "the panel follows the drag")
    f.resizeGrip:__fire("OnMouseUp", "LeftButton")
    assertTrue(paints >= 1, "mouse-up paints in full")
    assertEqual(f.dwSizing, false)
    -- a size change that is not a drag (the saved size applied, a reset) still paints in full
    paints = 0
    f:SetSize(1000, 620)
    f:__fire("OnSizeChanged", 1000, 620)
    assertTrue(paints >= 1, "a plain size change repaints")
    IVD.Breakdown, NS.ItemSearchGrid.PaintTable = realB, realP
end, FOREVER_ONLY)

test("verdict panel: its first header reads Why this verdict (R7-DW-03)", function()
    local NS, _, held = enabled()
    local W = NS.ItemSearchWindow
    held[IDS.blade] = { 1, 0 }
    W.ShowItem(IDS.blade)
    local lines = NS.ItemSearchVerdictPanel.Lines(W.Frame())
    -- red under: "Why this word"
    assertEqual(lines[1].text, "Why this verdict")
end, FOREVER_ONLY)

test("verdict panel: every line but the blank one explains itself on hover (R7-DW-02)", function()
    local NS, _, held = enabled()
    local W = NS.ItemSearchWindow
    held[IDS.blade] = { 1, 0 }
    W.ShowItem(IDS.blade)
    local f = W.Frame()
    local shown = 0
    for _, row in ipairs(f.verdict.lines) do
        if row:IsShown() then
            local text = row.cells.text.text:GetText()
            local tip = NS.Window.TooltipOf(row)
            if text == "" then
                assertEqual(#tip, 0, "the blank line has no tooltip")
            else
                -- red under: no tooltip on the panel's lines
                assertTrue(#tip >= 2, "a title and a line for: " .. text)
                shown = shown + 1
            end
        end
    end
    assertTrue(shown >= 6, "the parts, the use value, both headers and How sure's lines")
end, FOREVER_ONLY)

test("verdict tips: every part and How sure key the scorer emits has a tooltip, its numbers read live (R7-DW-02)", function()
    local NS = enabled()
    local IVT, V = NS.ItemSearchVerdictTips, NS.Constants.ITEM_SEARCH.VERDICT
    for _, key in ipairs({ "questLog", "questCan", "starts", "questsCap", "craft", "learn", "craftCap", "others",
        "othersCap", "upgrade", "sidegrade", "rebuy", "trivial", "poorCap", "questFloor", "collect",
        "use", "money", "evidence", "fallback", "data", "score",
        "whyHead", "sureHead", "from", "vendor", "noVendor", "auction", "net", "noPrice", "hint" }) do
        assertTrue(IVT.Has(key), "a tooltip for " .. key)
        assertTrue(#IVT.Lines({ key = key, points = -5 }) >= 2, "a title and a line for " .. key)
    end
    assertEqual(#IVT.Lines(nil), 0); assertEqual(#IVT.Lines({ key = "nope" }), 0)
    -- red under (R7-REV): an unformatted "100%%" shown with both signs
    for _, line in ipairs(IVT.Lines({ key = "use" })) do assertTrue(not line:find("%%%%"), "no doubled %: " .. line) end
    local cap = table.concat(IVT.Lines({ key = "questsCap", points = -15 }), "\n")
    assertTrue(cap:find("Taken off here: 15.", 1, true) ~= nil, "a cap says what it took off")
    local real = V.QUEST_CAN
    V.QUEST_CAN = 41
    assertTrue(table.concat(IVT.Lines({ key = "questCan" }), "\n"):find("adds 41.", 1, true) ~= nil, "read live")
    V.QUEST_CAN = real
    NS.addon.db.profile.itemSearch.auction.margin = 25
    assertTrue(table.concat(IVT.Lines({ key = "net" }), "\n"):find("by over 25%", 1, true) ~= nil, "the live margin")
end, FOREVER_ONLY)

test("verdict tips: every breakdown line the scorer builds carries a key with a tooltip (R7-DW-02)", function()
    local NS = enabled()
    local IS, IVD, IVT = NS.ItemSearch, NS.ItemSearchVerdict, NS.ItemSearchVerdictTips
    for _, id in ipairs({ IDS.blade, IDS.leather }) do
        local facts = IS.Get(id)
        local b = IVD.Breakdown(id, facts, IS.Me(facts and facts.ranks))
        for _, line in ipairs(b.lines) do assertTrue(IVT.Has(line.key or ""), "keyed: " .. line.text) end
        for _, s in ipairs(b.sure) do assertTrue(IVT.Has(s.key or ""), "keyed: " .. s.text) end
    end
end, FOREVER_ONLY)
