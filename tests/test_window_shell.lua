-- tests/test_window_shell.lua — the main window's chrome (design spec §11.1, boards 01 and 06): the
-- title bar, the restriction badge, Scan group, the tabs and their lazy panes, the filter bar and
-- its per-tab state, the footer, minimize and auto-open; plus the pure predicates and composers
-- the tabs' bodies and the footer draw from. Built headless under the mock (tests/wow_mock.lua
-- records the window's whole frame tree).

local T = _G.DW_TEST
local test, assertEqual, assertTrue, assertFalse = T.test, T.assertEqual, T.assertTrue, T.assertFalse

-- An enabled addon with the window shown.
local function shown(opts)
    local NS, _, m = T.enableAddon(opts)
    NS.ShowWindow()
    return NS, NS.Window.Frame(), m
end

-- A crafted drop record, for the predicates and for a DropAdded the feed is stubbed to answer.
local function drop(over)
    local d = { id = 1, at = 100, link = "|cffa335ee|Hitem:1::|h[Crown of Roaring Storms]|h|r",
        looter = { name = "Seta-Realm" }, me = { verdict = "upgrade", ilvlDelta = 19 },
        trade = { state = "likely" }, facts = { ilvl = 311 }, seenBy = "Testchar-Testrealm" }
    for k, v in pairs(over or {}) do d[k] = v end
    return d
end

-- Answer `rec` for every NS.LootFeed.Get, and announce it.
local function announce(NS, rec)
    NS.LootFeed.Get = function() return rec end
    NS.addon:SendMessage(NS.MSG.DROP_ADDED, rec.id)
end

local function textOf(region) return region and region:GetText() end

-- ── the title bar ───────────────────────────────────────────────────────────────────────────

test("shell: the title bar holds the centered gold title, the badge, Scan group, minimize and close, and no logo", function()
    local NS, f = shown()
    assertEqual(f.logo, nil, "no logo in the title bar: the launcher and the TOC keep it")
    for _, r in ipairs(f.titleBar.__regions) do
        local tex = r.__objType == "Texture" and r:GetTexture()
        assertTrue(not (type(tex) == "string" and tex:find("logo", 1, true)), "no logo texture on the bar")
    end
    assertEqual(textOf(f.title), "Ka0s Drop Watcher")
    assertEqual(f.title.__template, "GameFontNormal")
    local pt = f.title.__points[1]
    assertEqual(#f.title.__points, 1, "one anchor")
    assertEqual(pt[1], "CENTER"); assertEqual(pt[2], f.titleBar); assertEqual(pt[3], "CENTER")
    local r, g, b = f.title:GetTextColor()
    assertEqual(table.concat({ r, g, b }, ","), "1,0.82,0", "ApplySkin tints the title gold")
    assertFalse(f.badge:IsShown(), "no badge while nothing is restricted")
    assertEqual(textOf(f.scanButton.label), "Scan group")
    assertTrue(f.scanButton.art:GetTexture() ~= nil, "Scan group wears a catalog mark beside its label")
    assertTrue(f.minimizeButton.art:IsShown() and not f.minimizeButton.glyph:IsShown(), "the catalog mark, not the glyph")
    assertTrue(f.closeButton ~= nil)
    assertTrue(NS.HasWidgets())
end)

-- Feedback spec §1 (FB-3): a mode's words sit 10px right of the title in GameFontNormalLarge, in
-- their own color, with no box: the frame that carries their tooltip draws nothing.
local function assertModeText(m, word, r, g, b, title)
    assertEqual(m.text:GetText(), word)
    assertEqual(m.text.__template, "GameFontNormalLarge")
    local cr, cg, cb = m.text:GetTextColor()
    assertEqual(table.concat({ cr, cg, cb }, ","), table.concat({ r, g, b }, ","))
    local pt = m.__points[1]
    assertEqual(pt[1], "LEFT"); assertEqual(pt[2], title); assertEqual(pt[3], "RIGHT"); assertEqual(pt[4], 10)
    for _, reg in ipairs(m.__regions) do
        assertTrue(reg.__objType ~= "Texture", "no chip fill or border behind the words")
    end
    assertTrue(m:GetWidth() > 0, "sized to the words, so the tooltip has an area")
end

test("shell: TEST MODE is bright-red text beside the title, SIMULATION the same in cyan, each shown only in its mode", function()
    local NS, f = shown()
    local TB = NS.WindowTitleBar
    assertModeText(f.testText, "TEST MODE", 1, 0.15, 0.15, f.title)
    assertModeText(f.simText, "SIMULATION", 0.35, 0.8, 1, f.title)
    assertFalse(f.testText:IsShown()); assertFalse(f.simText:IsShown())
    NS.SetTestMode(true)
    NS.Window.Refresh()
    assertTrue(f.testText:IsShown()); assertFalse(f.simText:IsShown())
    assertEqual(NS.Window.TooltipOf(f.testText)[1], "Test mode")
    assertTrue(f.banner:IsShown(), "the yellow strip under the filter bar is kept")
    NS.SetTestMode(false)
    NS.Sim.IsActive = function() return true end
    TB.PaintModeText(f)
    assertTrue(f.simText:IsShown()); assertFalse(f.testText:IsShown())
    assertEqual(f.newChip.__points[1][2], f.simText, "the `n new` counter follows the mode's words")
end)

test("shell: the default size is 1022 x 600, the least width every column fits (feedback-4 spec §4)", function()
    local _, f = shown()
    assertEqual(f:GetWidth(), 1022)
    assertEqual(f:GetHeight(), 600)
end)

test("shell: Escape and every close path close the dropdowns' shared menu too", function()
    local NS, f = shown()
    local closed = 0
    NS.CloseMenu = function() closed = closed + 1 end
    f:Hide()   -- Escape (UISpecialFrames) hides the frame directly, and the client runs OnHide
    f:__fire("OnHide")
    assertTrue(closed >= 1)
    assertFalse(NS.State.windowOpen, "Escape is the player closing it")
end)

test("shell: the title bar is its own module, and the shell's BadgeText and TextButton are its", function()
    local NS = T.newAddon()
    local TB, W = NS.WindowTitleBar, NS.Window
    assertTrue(type(TB) == "table" and type(TB.Build) == "function", "modules/WindowTitleBar.lua publishes NS.WindowTitleBar")
    assertEqual(W.BadgeText("combat", 3), TB.BadgeText("combat", 3))
    local tip = { TB.TestTip() }
    assertEqual(tip[1], "Test mode")
    assertEqual(#tip, 4, "the chip and the banner share one four-line tooltip")
end)

test("shell: minimized, the title bar wears the plus mark and the `n new` counter; expanded, neither", function()
    local NS, f = shown()
    NS.WindowTitleBar.PaintMinimized(f, true, 2)
    assertEqual(f.minimizeButton.mark, "add")
    assertTrue(f.newChip:IsShown())
    assertEqual(textOf(f.newChip.text), "2 new")
    NS.WindowTitleBar.PaintMinimized(f, true, 0)
    assertFalse(f.newChip:IsShown(), "no counter while nothing new arrived")
    NS.WindowTitleBar.PaintMinimized(f, false, 2)
    assertTrue(f.minimizeButton.mark ~= "add", "the minimize mark again")
    assertFalse(f.newChip:IsShown())
end)

-- ── the restriction badge ───────────────────────────────────────────────────────────────────

test("shell: BadgeText names the restriction and counts the queued asks", function()
    local NS = T.newAddon()
    local W = NS.Window
    assertTrue(W.BadgeText(nil, 3) == nil, "nothing restricted: no badge")
    assertEqual(W.BadgeText("encounter", 0), "Encounter")
    assertEqual(W.BadgeText("encounter", 2), "Encounter · 2 queued")
    assertEqual(W.BadgeText("challengeMode", 1), "Mythic+ key · 1 queued")
    assertEqual(W.BadgeText("somethingNew", nil), "somethingNew", "an unknown reason still says something")
end)

test("shell: RestrictionChanged shows the badge, AskStateChanged counts the queue, its tooltip lists it", function()
    local NS, f, m = shown()
    NS.addon:SendMessage(NS.MSG.RESTRICTION_CHANGED, "encounter", false)
    m.advance(0)   -- a bus message repaints on the next frame
    assertTrue(f.badge:IsShown())
    assertEqual(textOf(f.badge.text), "Encounter")
    NS.Asks.Queued = function() return { { kind = "ask", target = "Seta-Realm" } } end
    NS.addon:SendMessage(NS.MSG.ASK_STATE_CHANGED, 1, "queued", "ask", "Seta-Realm")
    assertEqual(textOf(f.badge.text), "Encounter · 1 queued")
    local tip = NS.Window.TooltipOf(f.badge)
    assertEqual(tip[1], "Encounter")
    assertTrue(tip[2]:find("boss encounter") ~= nil, "which restriction, in words")
    assertEqual(tip[3], "Queued: Ask to Seta-Realm")
    NS.addon:SendMessage(NS.MSG.RESTRICTION_CHANGED, nil, true)
    m.advance(0)
    assertFalse(f.badge:IsShown(), "lifted: the badge goes")
end)

-- ── Scan group ──────────────────────────────────────────────────────────────────────────────

test("shell: Scan group asks the inspect broker through the shared handler, and says what it did", function()
    local NS, f, m = shown()
    local causes = {}
    NS.Inspect.Scan = function(cause) causes[#causes + 1] = cause; return 3 end
    f.scanButton:__fire("OnClick")
    assertEqual(table.concat(causes, ","), "scan")
    assertTrue(m.prints[#m.prints]:find("Inspecting 3 group members") ~= nil)
    NS.Inspect.Scan = function() return 0 end
    f.scanButton:__fire("OnClick")
    assertTrue(m.prints[#m.prints]:find("Nothing to inspect") ~= nil)
end)

test("shell: Scan group is refused while the addon is disabled", function()
    local NS = T.enableAddon()
    local called = false
    NS.Inspect.Scan = function() called = true; return 1 end
    NS.SchemaRuntime.Set("enabled", false)
    assertEqual(NS.ScanGroup(), 0)
    assertFalse(called)
end)

-- ── the tabs ────────────────────────────────────────────────────────────────────────────────

test("shell: three tabs, Group drops active in gold with its underline, the others gray", function()
    local NS, f = shown()
    assertEqual(table.concat(NS.Window.TABS, ","), "group,mine,history")
    assertEqual(NS.Window.ActiveTab(), "group")
    assertEqual(textOf(f.tabs.group.label), "Group drops")
    assertEqual(textOf(f.tabs.mine.label), "My drops")
    assertEqual(textOf(f.tabs.history.label), "History")
    local r, g = f.tabs.group.label:GetTextColor()
    assertEqual(r .. "," .. g, "1,0.82")
    assertTrue(f.tabs.group.underline:IsShown())
    assertFalse(f.tabs.mine.underline:IsShown())
    assertTrue(f.panes.group:IsShown() and not f.panes.mine:IsShown())
end)

test("shell: clicking a tab shows its pane and moves the gold underline; an unknown tab is refused", function()
    local NS, f = shown()
    f.tabs.mine:__fire("OnClick")
    assertEqual(NS.Window.ActiveTab(), "mine")
    assertTrue(f.panes.mine:IsShown() and not f.panes.group:IsShown())
    assertTrue(f.tabs.mine.underline:IsShown() and not f.tabs.group.underline:IsShown())
    assertFalse(NS.Window.SelectTab("nope"))
    assertEqual(NS.Window.ActiveTab(), "mine")
end)

-- Feedback-3 spec §0 (DW-B0): the label counts every drop of yours, so it reconciles with the
-- simulator's loot step and the Group drops headers; the tooltip says how many you can still trade.
test("shell: My drops counts all your drops in its label, the tradeable ones in its tooltip", function()
    local NS, f = shown()
    NS.LootFeed.Drops = function()
        return { drop({ isMine = true, trade = { state = "yes" } }), drop({ isMine = true, trade = { state = "no" } }),
            drop({ isMine = true, trade = { state = "likely" } }), drop() }
    end
    NS.Window.Refresh()
    -- red under: the M10 label, which counted the tradeable two only (the owner's `My drops` with no count)
    assertEqual(textOf(f.tabs.mine.label), "My drops · 3")
    local tip = NS.Window.TooltipOf(f.tabs.mine)
    assertEqual(tip[1], "My drops · 3"); assertEqual(tip[3], "2 of them you can still trade.")
    NS.LootFeed.Drops = function() return { drop({ isMine = true, trade = { state = "no" } }) } end
    assertEqual(NS.Window.TooltipOf(f.tabs.mine)[3], "None of them can be traded now.")
    NS.LootFeed.Drops = function() return { drop() } end
    assertEqual(NS.Window.TooltipOf(f.tabs.mine)[3], nil, "no drop of yours, no count")
    assertEqual(NS.Window.TabLabel("mine", 0), "My drops")
end)

test("shell: a tab's body is built on its first show, and refreshed with the tab's view", function()
    local NS, f = shown()
    local built, seen = 0, nil
    NS.Window.RegisterTab("history", {
        build = function() built = built + 1 end,
        refresh = function(_, ctx) seen = ctx end,
    })
    assertEqual(built, 0, "not while another tab is shown")
    assertTrue(f.panes.history.placeholder ~= nil)
    NS.Window.SelectTab("history")
    NS.Window.SelectTab("group")
    NS.Window.SelectTab("history")
    assertEqual(built, 1, "once")
    assertEqual(seen.tab, "history")
    assertEqual(seen.feed, "live")
    assertFalse(f.panes.history.placeholder:IsShown(), "the body replaces the placeholder")
    assertTrue(seen.matches(drop()) and type(seen.compare) == "function")
end)

test("shell: a tab with no body says what it will hold, never a blank pane", function()
    local _, f = shown()
    for _, key in ipairs({ "group", "mine", "history" }) do
        local text = textOf(f.panes[key].placeholder)
        assertTrue(type(text) == "string" and #text > 10, key)
    end
    -- The Group drops body has drawn itself: with no drop, its empty state (board 06 D).
    assertTrue(f.panes.group.emptyState:IsShown())
end)

-- ── the filter bar ──────────────────────────────────────────────────────────────────────────

test("shell: the filter bar holds View, Quality, Content and the search box, and no checkbox", function()
    local NS = shown()
    local c = NS.WindowFilterBar.Controls()
    assertEqual(textOf(c.view.text), "View: All", "All is the default View (FB2-1)")
    assertEqual(textOf(c.quality.text), "Quality: Rare+")
    assertEqual(textOf(c.content.text), "Content: This instance")
    assertTrue(c.likelyOnly == nil and c.usableOnly == nil and c.upgradeOnly == nil,
        "the checkboxes are View values now (FB2-2)")
    assertEqual(textOf(c.search.hint), "Filter looter or item…")
    assertTrue(c.search:IsShown(), "the default width leaves room for the search box")
end)

-- Feedback-2 spec §1 (FB2-2): the View is multi-select like Loot History's Direction.
local function pick(dd, value)
    dd:ToggleSelected(value)
    if dd.onMultiSelect then dd.onMultiSelect(dd._selected) end
end

test("shell: the View is multi-select: its values combine, the label counts them, and All clears them", function()
    local NS = shown()
    local FB, c = NS.WindowFilterBar, NS.WindowFilterBar.Controls()
    assertTrue(c.view.multi, "multi-select")
    local labels = {}
    for _, o in ipairs(c.view._options) do labels[#labels + 1] = o.label end
    assertEqual(table.concat(labels, ","), "View: All,Interesting,Likely tradeable,Usable by me,Upgrade for me")
    pick(c.view, "likely")
    assertEqual(textOf(c.view.text), "Likely tradeable", "one value: its name")
    assertTrue(FB.State("group").view.likely)
    pick(c.view, "usable")
    assertEqual(textOf(c.view.text), "View: 2 selected")
    local v = FB.State("group").view
    assertTrue(v.likely and v.usable and v.interesting == nil)
    pick(c.view, "likely")
    assertEqual(textOf(c.view.text), "Usable by me", "a second click takes a value out")
    pick(c.view, "all")
    assertEqual(textOf(c.view.text), "View: All")
    assertEqual(next(FB.State("group").view), nil, "All clears the others")
end)

test("shell: each tab grays the View values it does not use, and a grayed value does not toggle", function()
    local NS = shown()
    local FB, c = NS.WindowFilterBar, NS.WindowFilterBar.Controls()
    NS.Window.SelectTab("history")
    assertTrue(c.view:IsEnabled(), "History uses the View")
    local colors = {}
    for _, o in ipairs(c.view._options) do colors[o.value] = o.color end
    assertTrue(colors.likely ~= nil, "History has no Likely tradeable: grayed")
    assertTrue(colors.interesting == nil and colors.usable == nil and colors.upgrade == nil)
    pick(c.view, "likely")
    assertEqual(next(FB.State("history").view), nil, "a grayed value neither toggles nor filters")
    pick(c.view, "upgrade")
    assertTrue(FB.State("history").view.upgrade)
    NS.Window.SelectTab("mine")
    assertFalse(c.view:IsEnabled(), "My drops does not use the View")
    NS.Window.SelectTab("group")
    for _, o in ipairs(c.view._options) do assertTrue(o.color == nil, o.value .. " is used on Group drops") end
    assertEqual(textOf(c.view.text), "View: All", "the Group drops state comes back")
end)

-- FB2-3: the View tooltip is a bullet list, one line per value.
test("shell: the View tooltip lists every value as a bullet, and grays the ones a tab does not use", function()
    local NS = shown()
    local W, c = NS.Window, NS.WindowFilterBar.Controls()
    local tip = W.TooltipOf(c.view)
    assertEqual(tip[1], "View")
    assertEqual(#tip, 6, "the title and five values")
    assertEqual(tip[2], "• All: every drop that passed the situation and quality gates.")
    assertTrue(tip[3]:find("^• Interesting: ") ~= nil)
    assertTrue(tip[4]:find("^• Likely tradeable: ") ~= nil)
    assertTrue(tip[5]:find("^• Usable by me: ") ~= nil)
    assertTrue(tip[6]:find("^• Upgrade for me: ") ~= nil)
    for i = 2, 6 do assertTrue(tip[i]:find("not on this tab", 1, true) == nil, "Group drops uses them all") end
    NS.Window.SelectTab("history")
    tip = W.TooltipOf(c.view)
    assertTrue(tip[4]:find("(not on this tab)", 1, true) ~= nil and tip[4]:find("^|cff") ~= nil,
        "History grays Likely tradeable")
    assertTrue(tip[5]:find("not on this tab", 1, true) == nil)
end)

-- Feedback-3 spec §1 (DW-B1): a filter-bar control's tooltip sits above it, never over it or its menu.
test("filter bar tooltip: AboveSide is right when the screen has room past the control, else left", function()
    local NS = T.newAddon()
    local side = NS.Window.AboveSide
    assertEqual(side(1000, 300, 1920), "right")
    assertEqual(side(1620, 300, 1920), "right", "exactly fits")
    assertEqual(side(1621, 300, 1920), "left")
    assertEqual(side(nil, 300, 1920), "right", "unknown geometry: ANCHOR_RIGHT")
    assertEqual(side(1000, 300, nil), "right")
end)

local function hoverAbove(m, w, right, tipWidth)
    w.GetRight = function() return right end
    m.UIParent.GetWidth = function() return 1920 end
    m.GameTooltip.GetWidth = function() return tipWidth end
    w:__fire("OnEnter")
    local point, rel, relPoint, x, y = m.GameTooltip:GetPoint(1)
    return tostring(point) .. ">" .. tostring(relPoint), rel, x, y
end

test("filter bar tooltip: every bar control and the footer's Sort open above the control, top right", function()
    local NS, _, m = shown()
    local c = NS.WindowFilterBar.Controls()
    local _, sort = NS.WindowFooter.Parts()
    for _, key in ipairs({ "view", "quality", "content", "char", "search", "sort" }) do
        local w = key == "sort" and sort or c[key]
        assertTrue(w ~= nil, key .. " is built")
        local pts, rel, x, y = hoverAbove(m, w, 900, 300)
        assertEqual(m.GameTooltip.__anchor, "ANCHOR_NONE", key)
        assertEqual(pts, "BOTTOMLEFT>TOPRIGHT", key .. ": its bottom left on the control's top right")
        assertTrue(rel == w, key .. ": anchored to the control")
        assertEqual(x, 0); assertEqual(y, 0)
        assertEqual(#m.GameTooltip.__points, 1, key .. ": one point")
    end
end)

test("filter bar tooltip: with no room on the right it opens above the control, top left", function()
    local NS, _, m = shown()
    local _, sort = NS.WindowFooter.Parts()
    local pts, rel = hoverAbove(m, sort, 1800, 300)
    assertEqual(pts, "BOTTOMRIGHT>TOPLEFT")
    assertTrue(rel == sort)
    pts = hoverAbove(m, NS.WindowFilterBar.Controls().view, 1800, 300)
    assertEqual(pts, "BOTTOMRIGHT>TOPLEFT")
end)

test("filter bar tooltip: the room is measured in screen pixels, at each frame's scale", function()
    local NS, _, m = shown()
    local view = NS.WindowFilterBar.Controls().view
    view.GetEffectiveScale = function() return 0.5 end
    assertEqual((hoverAbove(m, view, 3000, 300)), "BOTTOMLEFT>TOPRIGHT", "3000 units at 0.5 is 1500 px")
    m.GameTooltip.GetEffectiveScale = function() return 2 end
    assertEqual((hoverAbove(m, view, 3000, 300)), "BOTTOMRIGHT>TOPLEFT", "a 600 px tooltip does not fit")
end)

test("filter bar tooltip: the tab strip keeps its own anchor (only the bar moved)", function()
    local _, f, m = shown()
    f.tabs.group:__fire("OnEnter")
    assertEqual(m.GameTooltip.__anchor, "ANCHOR_BOTTOM")
end)

-- Ka0s Loot History's filter bar look (ui spec §2, FB-5): ../LootHistory/modules/BrowserFilterBar.lua.
local LH_FILL, LH_LINE = { 0.1, 0.1, 0.12, 0.9 }, { 0.24, 0.24, 0.27, 0.9 }

local function assertFlatSkin(w, what)
    assertEqual(w.__template, "BackdropTemplate", what .. ": no Blizzard template's rounded art")
    local b = w.__backdrop
    assertTrue(b ~= nil, what .. ": a backdrop")
    assertEqual(b.bgFile, "Interface\\Buttons\\WHITE8X8", what .. ": flat fill")
    assertEqual(b.edgeFile, "Interface\\Buttons\\WHITE8X8", what .. ": square edge")
    assertEqual(b.edgeSize, 1, what .. ": a 1px line")
    for i = 1, 4 do
        assertEqual(w.__backdropColor[i], LH_FILL[i], what .. ": fill " .. i)
        assertEqual(w.__backdropBorder[i], LH_LINE[i], what .. ": line " .. i)
    end
end

test("shell: the search box is Loot History's flat, square box", function()
    local NS = shown()
    local eb = NS.WindowFilterBar.Controls().search
    assertEqual(eb.__frameType, "EditBox")
    assertFlatSkin(eb, "search")
    assertEqual(eb.__height, 20, "as tall as the dropdowns")
    assertEqual(eb.__fontObject, "GameFontHighlightSmall")
    assertEqual(eb.__textInsets[1], 6)
    assertEqual(eb.hint.__template, "GameFontDisableSmall")
    assertEqual(eb.hint.__points[1][4], 6, "the hint sits where the typed text starts")
    eb:__fire("OnEditFocusGained")
    assertEqual(eb.__backdropBorder[1], 1, "focus lights the line gold")
    eb:__fire("OnEditFocusLost")
    assertEqual(eb.__backdropBorder[1], LH_LINE[1], "and the line goes back")
end)

test("shell: the dropdowns are LibKa0s's, the widget Loot History's bar uses, spaced as it spaces them", function()
    local NS = shown()
    local c = NS.WindowFilterBar.Controls()
    for _, key in ipairs({ "view", "quality", "content" }) do
        assertEqual(c[key].__template, "BackdropTemplate", key)
        assertEqual(c[key].__height, 20, key)
    end
    local _, rel, _, x = c.quality:GetPoint(1)
    assertTrue(rel == c.view, "Quality follows View")
    assertEqual(x, 8, "Loot History's 8px gap")
end)

test("shell: each tab keeps its own filter state, and grays what it does not use", function()
    local NS = shown()
    local FB, c = NS.WindowFilterBar, NS.WindowFilterBar.Controls()
    pick(c.view, "interesting")
    assertTrue(FB.State("group").view.interesting)
    NS.Window.SelectTab("mine")
    assertEqual(next(FB.State("mine").view), nil, "a separate state")
    assertFalse(c.view:IsEnabled(), "My drops does not use View: grayed, not hidden")
    assertTrue(c.view:IsShown())
    assertTrue(c.search:IsEnabled())
    c.search:SetText("crown")
    c.search:__fire("OnTextChanged", true)
    assertEqual(FB.State("mine").search, "crown")
    NS.Window.SelectTab("group")
    assertEqual(textOf(c.view.text), "Interesting", "the tab's own state comes back onto the bar")
    assertEqual(c.search:GetText(), "")
    assertTrue(c.view:IsEnabled())
end)

test("shell: a filter change redraws the active tab with the new state", function()
    local NS = shown()
    local seen
    NS.Window.RegisterTab("group", { build = function() end, refresh = function(_, ctx) seen = ctx.filter end })
    local c = NS.WindowFilterBar.Controls()
    pick(c.view, "likely")
    assertTrue(seen.view.likely)
    assertFalse(NS.WindowFilterBar.Set("group", "view", "all"), "the View takes a set, not a string")
    assertFalse(NS.WindowFilterBar.Set("group", "view", { bogus = true }), "an unknown value is refused")
    assertFalse(NS.WindowFilterBar.Set("group", "view", { likely = "yes" }), "a member is true")
end)

test("shell: a fresh tab's state is seeded from the profile's feed settings when valid", function()
    local NS = T.enableAddon()
    NS.addon.db.profile.feed = { view = { likely = true, usable = true, upgrade = "yes" },
        content = "nonsense", sort = "ilvl" }
    local st = NS.WindowFilterBar.State("group")
    assertTrue(st.view.likely and st.view.usable)
    assertTrue(st.view.upgrade == nil, "an invalid stored value falls back to off")
    assertEqual(st.content, "instance", "an invalid stored value falls back")
    assertEqual(st.sort, "ilvl")
end)

test("shell: the Quality control shows the mode in force and sets it through the shared handler", function()
    local NS = shown()
    local c = NS.WindowFilterBar.Controls()
    c.quality.onSelect("dynamicSlot")
    assertEqual(NS.addon.db.profile.feed.quality.mode, "dynamicSlot")
    assertEqual(NS.LootFeed.Config().qualityMode, "dynamicSlot", "the feed reads what the control wrote")
    assertEqual(textOf(c.quality.text), "Quality: Match slot")
    assertFalse(NS.SetQualityMode("bogus"))
    local tip = NS.Window.TooltipOf(c.quality)
    assertEqual(tip[1], "Quality: Match slot")
end)

test("shell: IsInteresting is an upgrade for you, or a drop its looter has no use for and can trade", function()
    local FB = T.newAddon().WindowFilterBar
    -- Branch 1: an upgrade for you, whatever its trade estimate.
    assertTrue(FB.IsInteresting(drop()))
    assertTrue(FB.IsInteresting(drop({ trade = { state = "unknown" } })))
    assertTrue(FB.IsInteresting(drop({ trade = { state = "no" } })), "the union: your upgrade even when it cannot be traded")
    -- Branch 2: the looter has no use for it, and it can be traded.
    for _, v in ipairs({ "downgrade", "cantUse", "doesntWant" }) do
        for _, st in ipairs({ "yes", "likely" }) do
            assertTrue(FB.IsInteresting(drop({ me = { verdict = "sidegrade" }, them = { verdict = v }, trade = { state = st } })),
                v .. " for them, trade " .. st)
        end
        assertFalse(FB.IsInteresting(drop({ me = { verdict = "sidegrade" }, them = { verdict = v }, trade = { state = "unknown" } })),
            v .. " for them, trade unknown")
        assertFalse(FB.IsInteresting(drop({ me = { verdict = "sidegrade" }, them = { verdict = v }, trade = { state = "no" } })),
            v .. " for them, trade no")
    end
    assertFalse(FB.IsInteresting(drop({ me = { verdict = "sidegrade" }, them = { verdict = "upgrade" }, trade = { state = "yes" } })),
        "the looter's own upgrade, a sidegrade for you")
    assertFalse(FB.IsInteresting(drop({ me = { verdict = "sidegrade" } })), "no verdict for the looter")
    assertFalse(FB.IsInteresting(drop({ me = false })), "no verdict for anyone yet")
    assertTrue(FB.IsInteresting(drop({ isMine = true, me = false, trade = { state = "yes" } })))
    assertFalse(FB.IsInteresting(drop({ isMine = true, trade = { state = "no" } })))
    assertFalse(FB.IsInteresting(nil))
    assertTrue(FB.IsTradeableMine(drop({ isMine = true })))
    assertFalse(FB.IsTradeableMine(drop()))
end)

test("shell: InGroup keeps your own drops out of Group drops unless showOwn is on", function()
    local FB = T.newAddon().WindowFilterBar
    assertTrue(FB.InGroup(drop(), false))
    assertFalse(FB.InGroup(drop({ isMine = true }), nil), "off by default")
    assertFalse(FB.InGroup(drop({ isMine = true }), false))
    assertTrue(FB.InGroup(drop({ isMine = true }), true))
    assertFalse(FB.InGroup(nil, true))
end)

test("shell: Matches applies only the controls a tab honors", function()
    local FB = T.newAddon().WindowFilterBar
    local st = { view = { interesting = true, likely = true }, content = "instance", search = "", sort = "newest" }
    local dull = drop({ me = { verdict = "downgrade" }, trade = { state = "unknown" } })
    assertEqual(FB.HiddenBy(dull, st, nil, FB.HONORS.group), "interesting", "not interesting, the first value")
    st.view = { likely = true }
    assertEqual(FB.HiddenBy(dull, st, nil, FB.HONORS.group), "likely", "not likely tradeable")
    assertTrue(FB.Matches(dull, st, nil, FB.HONORS.mine), "My drops uses neither")
    assertTrue(FB.Matches(dull, st, nil, FB.HONORS.history), "History has no Likely tradeable")
    st.view = {}
    assertTrue(FB.Matches(dull, st, { instanceSince = 50 }, FB.HONORS.group))
    assertFalse(FB.Matches(dull, st, { instanceSince = 150 }, FB.HONORS.group), "before this instance")
    st.content = "all"
    assertTrue(FB.Matches(dull, st, { instanceSince = 150 }, FB.HONORS.group))
    st.search = "ROARING"
    assertTrue(FB.Matches(dull, st), "the item name, ignoring case")
    st.search = "seta"
    assertTrue(FB.Matches(dull, st), "the looter")
    st.search = "cloak"
    assertFalse(FB.Matches(dull, st))
    assertFalse(FB.Matches(nil, st))
end)

-- Feedback spec §3 (FB-8), now View values (feedback-2 spec §1): Usable by me hides can't use and
-- doesn't want; Upgrade for me keeps only your upgrades. My drops uses neither.
test("shell: Usable by me hides what you can't use or don't want; Upgrade for me keeps your upgrades", function()
    local FB = T.newAddon().WindowFilterBar
    local st = { view = { usable = true }, content = "all", search = "", sort = "newest" }
    local function v(verdict) return drop({ me = verdict and { verdict = verdict } or false }) end
    for _, verdict in ipairs({ "upgrade", "sidegrade", "downgrade", "unknown" }) do
        assertTrue(FB.Matches(v(verdict), st, nil, FB.HONORS.group), "usable: " .. verdict)
    end
    assertTrue(FB.Matches(v(nil), st, nil, FB.HONORS.group), "not judged yet: kept")
    assertFalse(FB.Matches(v("cantUse"), st, nil, FB.HONORS.group))
    assertFalse(FB.Matches(v("doesntWant"), st, nil, FB.HONORS.group), "your own preferences")
    assertTrue(FB.Matches(v("cantUse"), st, nil, FB.HONORS.mine), "My drops does not use it")
    st.view = { upgrade = true }
    assertTrue(FB.Matches(v("upgrade"), st, nil, FB.HONORS.group))
    for _, verdict in ipairs({ "sidegrade", "downgrade", "cantUse", "doesntWant", "unknown" }) do
        assertFalse(FB.Matches(v(verdict), st, nil, FB.HONORS.group), "upgrade only: " .. verdict)
    end
    assertFalse(FB.Matches(v(nil), st, nil, FB.HONORS.group), "not judged yet: not an upgrade")
    assertFalse(FB.Matches(v("downgrade"), st, nil, FB.HONORS.history), "History uses it")
    assertTrue(FB.Matches(v("downgrade"), st, nil, FB.HONORS.mine), "My drops does not")
    st.view = { usable = true, upgrade = true }
    assertEqual(FB.HiddenBy(v("cantUse"), st, nil, FB.HONORS.group), "usable", "AND: the first value that fails")
    assertEqual(FB.HiddenBy(v("sidegrade"), st, nil, FB.HONORS.group), "upgrade")
    assertTrue(FB.Matches(v("upgrade"), st, nil, FB.HONORS.group), "passes both")
    assertEqual(FB.ReasonLabel("usable", st), "View: Usable by me")
    assertEqual(FB.ReasonLabel("content", { content = "instance" }), "Content: This instance")
end)

test("shell: Comparator orders newest, oldest, by item level and by your gain", function()
    local FB = T.newAddon().WindowFilterBar
    local a = drop({ id = 1, at = 10, facts = { ilvl = 300 }, me = { ilvlDelta = 4 } })
    local b = drop({ id = 2, at = 20, facts = { ilvl = 311 }, me = { ilvlDelta = 19 } })
    local c = drop({ id = 3, at = 30, facts = {}, me = {} })
    local function order(sort)
        local list = { a, b, c }
        table.sort(list, FB.Comparator(sort))
        local ids = {}
        for i, d in ipairs(list) do ids[i] = d.id end
        return table.concat(ids, ",")
    end
    assertEqual(order("newest"), "3,2,1")
    assertEqual(order("oldest"), "1,2,3")
    assertEqual(order("ilvl"), "2,1,3", "an unread level sorts last")
    assertEqual(order("gain"), "2,1,3")
    assertEqual(order("bogus"), "3,2,1", "newest for an unknown order")
end)

-- ── the footer ──────────────────────────────────────────────────────────────────────────────

test("shell: the footer composer says inspect freshness, last loot, the situation and Pawn", function()
    local WF = T.newAddon().WindowFooter
    local s = WF.Compose({ members = 5, good = 4, outOfRange = 1, pending = 0, lastLootAgo = 12,
        situation = "mythicPlus", tracking = true, pawn = "on" })
    assertEqual(s.inspect.text, "Inspect 4/5 fresh · 1 out of range")
    assertEqual(s.loot.text, "Last loot 12s ago")
    assertEqual(s.situation.text, "Situation: Mythic+")
    assertEqual(s.pawn.text, "Pawn: on")
    local idle = WF.Compose({ members = 0, situation = "solo", tracking = false, pawn = "off" })
    assertEqual(idle.inspect.text, "Inspect: no group")
    assertEqual(idle.loot.text, "No loot seen yet")
    assertEqual(idle.situation.text, "Not tracking in Solo · change in settings")
    assertEqual(idle.pawn.text, "Pawn: off")
    for _, seg in pairs(WF.Compose(nil)) do
        assertTrue(type(seg.text) == "string" and #seg.tip >= 2, "every segment has words and a reason")
    end
    assertEqual(WF.Ago(59), "59s")
    assertEqual(WF.Ago(150), "2m")
    assertEqual(WF.Ago(7300), "2h")
end)

test("shell: the live footer reads the client, and its Sort follows the active tab", function()
    local NS = shown()
    local segs, sort = NS.WindowFooter.Parts()
    assertEqual(textOf(segs.situation.text), "Not tracking in Solo · change in settings")
    assertEqual(textOf(segs.inspect.text), "Inspect: no group")
    assertEqual(textOf(sort.text), "Sort: Newest")
    sort.onSelect("gain")
    assertEqual(NS.WindowFilterBar.State("group").sort, "gain")
    NS.Window.SelectTab("mine")
    assertEqual(textOf(sort.text), "Sort: Newest", "My drops keeps its own order")
end)

test("shell: the footer's ticker runs only while the whole window is on screen", function()
    local NS, f, m = shown()
    local running = #m.__timers()
    assertTrue(running >= 1)
    NS.Window.SetMinimized(true)
    assertEqual(#m.__timers(), running - 1, "minimized: stopped")
    NS.Window.SetMinimized(false)
    assertEqual(#m.__timers(), running)
    NS.HideWindow()
    assertFalse(f:IsShown())
    assertEqual(#m.__timers(), running - 1, "hidden: stopped")
end)

-- ── minimize ────────────────────────────────────────────────────────────────────────────────

test("shell: minimize collapses to the title bar, keeps the size, and counts every drop added", function()
    local NS, f, m = shown()
    f.minimizeButton:__fire("OnClick")
    assertTrue(NS.Window.IsMinimized())
    assertTrue(NS.addon.db.profile.window.minimized, "kept in the profile")
    assertFalse(f.body:IsShown())
    assertEqual(f:GetHeight(), 32)
    assertEqual(f:GetWidth(), 1022)
    assertEqual(f.minimizeButton.mark, "add")
    assertFalse(f.newChip:IsShown(), "nothing new yet")
    announce(NS, drop({ id = 7 }))
    announce(NS, drop({ id = 8, me = { verdict = "downgrade" } }))
    assertEqual(NS.Window.NewCount(), 2, "every drop added, not only the interesting ones (FB-12)")
    announce(NS, drop({ id = 9, test = true }))
    assertEqual(NS.Window.NewCount(), 2, "a test placeholder is not in the live feed shown")
    m.advance(0)
    assertTrue(f.newChip:IsShown())
    assertEqual(textOf(f.newChip.text), "2 new")
    f.minimizeButton:__fire("OnClick")
    assertTrue(f.body:IsShown())
    assertEqual(f:GetHeight(), 600)
    assertEqual(NS.Window.NewCount(), 0)
end)

test("shell: a double-click on the title bar expands a minimized window", function()
    local NS, f, m = shown()
    NS.Window.SetMinimized(true)
    f.titleBar:__fire("OnMouseUp", "LeftButton")
    m.advance(1)
    f.titleBar:__fire("OnMouseUp", "LeftButton")
    assertTrue(NS.Window.IsMinimized(), "two clicks a second apart are not a double-click")
    m.advance(0.2)
    f.titleBar:__fire("OnMouseUp", "LeftButton")
    assertFalse(NS.Window.IsMinimized())
end)

test("shell: minimized, the corner grip does not resize and the stored size is kept", function()
    local NS, f = shown()
    NS.Window.SetMinimized(true)
    assertFalse(f.resizeGrip:IsShown())
    f.resizeGrip:__fire("OnMouseDown", "LeftButton")
    f:SetSize(700, 32)
    f.resizeGrip:__fire("OnMouseUp", "LeftButton")
    assertTrue(NS.addon.db.profile.window.geometry == nil, "nothing saved")
end)

test("shell: a minimized window comes back minimized after a settings repaint", function()
    local NS, f = shown()
    NS.Window.SetMinimized(true)
    NS.SchemaRuntime.Set("alpha", 0.8)
    assertEqual(f:GetHeight(), 32)
end)

test("shell: minimize and expand keep the title bar in place, whatever point it was saved at", function()
    local NS, f = shown()
    assertEqual(f:GetPoint(1), "CENTER", "the default point")
    -- Where the client draws it: 1000 x 600 centered on a 1920 x 1080 screen.
    f.GetLeft = function() return 460 end
    f.GetTop = function() return 840 end
    NS.Window.SetMinimized(true)
    local point, _, relPoint, x, y = f:GetPoint(1)
    assertEqual(table.concat({ point, relPoint, x, y }, ","), "TOPLEFT,BOTTOMLEFT,460,840")
    assertEqual(table.concat(NS.addon.db.profile.window.geometry.full.point, ","), "TOPLEFT,BOTTOMLEFT,460,840", "and kept")
    assertEqual(f:GetHeight(), 32)
    NS.Window.SetMinimized(false)
    assertEqual(table.concat({ f:GetPoint(1) }, ",", 3, 5), "BOTTOMLEFT,460,840", "the expand grows downward")
    assertEqual(f:GetHeight(), 600)
end)

-- ── a parent's hide ─────────────────────────────────────────────────────────────────────────

test("shell: a parent's hide (Alt-Z, a cinematic) is not the player closing the window", function()
    local NS, f = shown()
    -- UIParent hidden: the client runs the window's OnHide, but its own shown flag stays set.
    f:__fire("OnHide")
    assertTrue(NS.State.windowOpen, "the player's choice is kept")
    f:__fire("OnShow")
    NS.Window.UpdateVisibility(true)
    assertTrue(f:IsShown(), "a later show decision keeps it open")
    f:Hide()
    f:__fire("OnHide")
    assertFalse(NS.State.windowOpen, "a hide of the frame itself still closes it")
end)

-- ── batched repaints ────────────────────────────────────────────────────────────────────────

test("shell: a burst of bus messages repaints once, on the next frame", function()
    local NS, _, m = shown()
    local W, n = NS.Window, 0
    local refresh = W.Refresh
    W.Refresh = function(...) n = n + 1; return refresh(...) end
    for i = 1, 5 do NS.addon:SendMessage(NS.MSG.DROP_UPDATED, i) end
    NS.addon:SendMessage(NS.MSG.ASK_STATE_CHANGED, 1, "queued", "ask", "Seta-Realm")
    NS.addon:SendMessage(NS.MSG.RESTRICTION_CHANGED, "encounter", false)
    assertEqual(n, 0, "nothing repaints inside the burst")
    m.advance(0)
    assertEqual(n, 1, "one pass for the whole burst")
    m.advance(1)
    assertEqual(n, 1, "and nothing more queued")
end)

test("shell: a countdown tick on the Group drops tab repaints nothing of the window", function()
    local NS, _, m = shown()
    local W, n = NS.Window, 0
    local refresh = W.Refresh
    W.Refresh = function(...) n = n + 1; return refresh(...) end
    assertEqual(W.ActiveTab(), "group")
    NS.addon:SendMessage(NS.MSG.TRADE_TIMER_TICK)
    m.advance(0)
    assertEqual(n, 0, "no countdown on screen, no repaint")
end)

-- ── auto-open ───────────────────────────────────────────────────────────────────────────────

local HEROIC = { inInstance = true, instanceType = "party", difficultyID = 2, inGroup = true }

local function inDungeon()
    local NS, _, m = T.enableAddon()
    m.__context.inInstance, m.__context.instanceType, m.__context.inGroup = true, "party", true
    m.instance.difficultyID = HEROIC.difficultyID
    m.__fire("PLAYER_ENTERING_WORLD")
    assertEqual(NS.Situations.Current(), "dungeon")
    return NS, m
end

-- Feedback spec §3 (FB-12): every drop added to the feed opens a hidden window, with no latch.
test("shell: every drop added in an auto-open situation opens the window, each time it is closed", function()
    local NS = inDungeon()
    announce(NS, drop({ id = 1, me = { verdict = "downgrade" }, trade = { state = "no" } }))
    assertTrue(NS.IsWindowShown(), "not interesting, still opens: it passed the feed's gates")
    NS.HideWindow()
    announce(NS, drop({ id = 2 }))
    assertTrue(NS.IsWindowShown(), "closed by the player: the next drop opens it again")
    NS.HideWindow()
    announce(NS, drop({ id = 3 }))
    assertTrue(NS.IsWindowShown(), "and again: no once-per-situation latch")
end)

test("shell: your own drop opens the window too, whatever showOwn says, and counts as new", function()
    local NS = inDungeon()
    local mine = { isMine = true, me = false, trade = { state = "yes" } }
    local function own(id) local d = drop(mine); d.id = id; return d end
    announce(NS, own(1))
    assertTrue(NS.IsWindowShown(), "showOwn off: your own drop still opens the window")
    NS.Window.SetMinimized(true)
    announce(NS, own(2))
    assertEqual(NS.Window.NewCount(), 1)
    assertTrue(NS.Window.IsMinimized(), "a minimized window stays minimized")
end)

test("shell: a minimized window the player closed opens minimized, its count rising", function()
    local NS = inDungeon()
    NS.ShowWindow()
    NS.Window.SetMinimized(true)
    NS.HideWindow()
    announce(NS, drop({ id = 1 }))
    assertTrue(NS.IsWindowShown()); assertTrue(NS.Window.IsMinimized())
    assertEqual(NS.Window.NewCount(), 1)
end)

test("shell: a test placeholder opens the window while test mode is on, and a live drop does not then", function()
    local NS = inDungeon()
    NS.State.testMode = true
    announce(NS, drop({ id = 1 }))
    assertFalse(NS.IsWindowShown(), "a live drop is not in the test feed shown")
    announce(NS, drop({ id = 2, test = true }))
    assertTrue(NS.IsWindowShown(), "test mode's drops follow the same rule")
end)

-- The dungeon variant of test_window's close rule: test mode's own drops auto-open the window (the
-- pool is ready at once) before test mode marks it, and that open is still test mode's.
test("shell: in a dungeon, turning test mode off closes the window its drops opened", function()
    local NS, m = inDungeon()
    m.seedGearJournal()
    NS.SetTestMode(true)
    assertEqual(#NS.LootFeed.Drops("test"), 16, "the test drops are in"); assertTrue(NS.IsWindowShown())
    NS.SetTestMode(false)
    assertFalse(NS.IsWindowShown(), "test mode opened it, so off closes it")
    NS.ShowWindow()
    NS.SetTestMode(true)
    NS.SetTestMode(false)
    assertTrue(NS.IsWindowShown(), "the player opened it, so it stays")
end)

test("shell: a test drop that reopens a window the player closed in test mode closes with test mode", function()
    local NS = inDungeon()
    NS.SetTestMode(true)
    NS.HideWindow()
    announce(NS, drop({ id = 1, test = true }))
    assertTrue(NS.IsWindowShown())
    NS.SetTestMode(false)
    assertFalse(NS.IsWindowShown())
end)

test("shell: no auto-open for a test drop outside test mode, outside an auto-open situation, or with the master off", function()
    local NS = inDungeon()
    announce(NS, drop({ id = 1, test = true }))
    assertFalse(NS.IsWindowShown())
    NS.addon.db.profile.autoOpen = false
    announce(NS, drop({ id = 2 }))
    assertFalse(NS.IsWindowShown())
    local solo = T.enableAddon()
    announce(solo, drop({ id = 3 }))
    assertFalse(solo.IsWindowShown(), "solo is not an auto-open situation")
end)

-- ── reasons everywhere ──────────────────────────────────────────────────────────────────────

test("shell: every control on the chrome has a tooltip with a reason", function()
    local NS, f = shown()
    local W, c = NS.Window, NS.WindowFilterBar.Controls()
    local segs, sort = NS.WindowFooter.Parts()
    NS.addon:SendMessage(NS.MSG.RESTRICTION_CHANGED, "combat", true)
    local widgets = { f.scanButton, f.minimizeButton, f.badge, f.newChip, f.tabs.group, f.tabs.mine,
        f.tabs.history, c.view, c.quality, c.content, c.search, sort,
        segs.inspect, segs.loot, segs.situation, segs.pawn }
    for i, w in ipairs(widgets) do
        local tip = W.TooltipOf(w)
        assertTrue(#tip >= 2 and type(tip[1]) == "string" and type(tip[2]) == "string", "widget " .. i)
    end
    NS.Window.SelectTab("mine")
    assertEqual(W.TooltipOf(c.view)[2], "This tab does not use this filter.", "a grayed control says why")
end)

-- ── degraded ────────────────────────────────────────────────────────────────────────────────

test("shell: without the Widgets library the window builds with no dead dropdown", function()
    local skip = {}
    for _, rel in ipairs(T.loadAddon.libFiles) do
        if rel:find("/Widgets") then skip[#skip + 1] = rel end
    end
    assertTrue(#skip >= 1)
    local NS = shown({ skip = skip })
    assertFalse(NS.HasWidgets())
    local c = NS.WindowFilterBar.Controls()
    assertTrue(c.view == nil and c.quality == nil and c.content == nil)
    assertTrue(c.search ~= nil, "the search still filters")
    local _, sort = NS.WindowFooter.Parts()
    assertTrue(sort == nil)
    NS.CloseMenu()
end)

-- M11 review leftover (feedback-3 spec §5, DW-B5): near the top of the screen the tooltip goes below.
test("filter bar tooltip: AboveFits is true when the screen has room over the control, else false", function()
    local fits = T.newAddon().Window.AboveFits
    assertTrue(fits(800, 200, 1080))
    assertTrue(fits(880, 200, 1080), "exactly fits")
    assertTrue(not fits(881, 200, 1080))
    assertTrue(fits(nil, 200, 1080), "unknown geometry: above")
    assertTrue(fits(1000, 200, nil))
end)

local function hoverNearTop(m, w, right, top)
    w.GetTop = function() return top end
    m.UIParent.GetHeight = function() return 1080 end
    m.GameTooltip.GetHeight = function() return 120 end
    local pts, rel = hoverAbove(m, w, right, 300)
    w.GetTop = nil
    return pts, rel
end

test("filter bar tooltip: near the top of the screen it opens below the control, never over it", function()
    local NS, _, m = shown()
    local view = NS.WindowFilterBar.Controls().view
    local pts, rel = hoverNearTop(m, view, 900, 1000)
    assertEqual(pts, "TOPLEFT>BOTTOMRIGHT", "its top left on the control's bottom right")
    assertTrue(rel == view)
    assertEqual((hoverNearTop(m, view, 1800, 1000)), "TOPRIGHT>BOTTOMLEFT", "no room on the right either")
    assertEqual((hoverNearTop(m, view, 900, 900)), "BOTTOMLEFT>TOPRIGHT", "room above: above")
    local side, where = NS.Window.PlaceAbove(m.GameTooltip, view)
    assertEqual(side, "right"); assertEqual(where, "above")
end)
