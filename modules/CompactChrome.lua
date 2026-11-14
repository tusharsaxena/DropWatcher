local _, NS = ...
-- modules/CompactChrome.lua — the window's chrome in the compact layout (compact spec §4, DW-C4):
-- the title bar, the tabs, the one-row filter bar with its Filters menu, the mode strips (test mode's
-- and the simulation's) and the one-line footer. The same frame and the same controls as the full layout, laid out again: nothing
-- here changes what is recorded, gated, judged or sent.
--
--   title bar   `Drop Watcher` centered, alone while a mode's strip marks the mode; `TEST` / `SIM`
--               beside it in their red and cyan only while minimized or with no strip; the
--               lock button at the left (RX-08), the restriction badge its lock and the queued
--               count beside it; the layout toggle,
--               minimize and close at the right (Scan group is the Drops strip's icon, feedback-16)
--   tabs        `Drops`, `History` at a reduced width (their tooltips say what each holds)
--   filter bar  View, the search box (`Filter…`) and Filters ▾ on the right. The Filters menu lists
--               the full bar's Quality, Content and Character dropdowns and the tab's Sort, one child
--               level each, whose rows are that dropdown's own and whose picks go through it, so their
--               choices, their multi-select and their per-tab state are identical. The button counts
--               the ones not at their default (`Filters · 2`), and its tooltip lists every value in
--               force.
--   strip       the strip in force (test mode's or the simulation's) in shorter words, wrapping to
--               two lines when the width needs it
--   footer      one line, `Inspect 4/4 · Mythic+`; the rest of the full footer is its tooltip
--
-- A CASCADE OF THE DROPDOWNS THEMSELVES. Filters ▾ opens LibKa0s-Widgets' shared menu on its button
-- (W.ContextMenu through NS.ContextMenu) with one `submenu` row per dropdown (Widgets minor 23), in
-- CC.MENU_ROWS' order and named for the control. Each child lists that dropdown's own option rows and
-- reads its tick (`selected`) from that same dropdown, and a pick goes through the dropdown's own
-- path (SetValue and onSelect, ToggleSelected and onMultiSelect, as its own menu's click does), so
-- there is one state: the full bar, the count and the tooltip stay in step. Single-select rows
-- (Quality, Content, Sort) are `radio` and close the menu on a pick; Character's multi-select rows are
-- `keepOpen`, the library repainting every level so the ticks follow. In compact the four dropdowns
-- stay where the full layout puts them, hidden. Until Widgets 23 the menu had no submenu rows, and
-- Filters ▾ opened a hand-built panel the dropdowns were reparented into, with an outside-press
-- listener of its own; the library's menu closes on an outside press itself.
--
-- PURE: TabText, ModeWord, BadgeShort, FooterLine, FooterTip, IsActive, ActiveKeys, CountActive,
-- FiltersLabel and FiltersTip. The edge: Paint (Window.Refresh's every pass; the layout itself only
-- when the layout in force changed), ModeStrip (the strip of the mode in force), BannerH (its height,
-- which Window's pane layout reads),
-- PaintFooter (WindowFooter.Refresh in compact) and the Filters menu (FilterRows, ToggleFilters,
-- CloseFilters). WindowFilterBar.Layout
-- stands aside in compact: the search box's anchors size it there.

NS.CompactChrome = NS.CompactChrome or {}
local CC = NS.CompactChrome
local K  = NS.Constants.WINDOW
local L  = NS.L

local TAG = "UI"

CC.TAB_W     = 84     -- one compact tab
CC.VIEW_W    = 104    -- the View dropdown on the compact bar
CC.FILTERS_W = 84     -- the Filters ▾ button
CC.BADGE_W   = 44     -- the restriction badge: its lock and the queued count
CC.WRAP_H    = 12     -- the strip's second line
local GAP = 8

-- The Filters menu's rows, top to bottom; the tab's Sort is the last.
CC.MENU_ROWS = { "quality", "content", "char", "sort" }
-- The ones the button counts (compact spec §4: Quality, Content and Character).
CC.COUNTED = { "quality", "content", "char" }
-- Each menu row's name, its Filters tooltip row's label.
local MENU_LABEL = { quality = L["Quality"], content = L["Content"], char = L["Character"], sort = L["Sort"] }

local SHORT_TAB = { group = L["Drops"], history = L["History"], insights = L["Insights"] }
local WORD = {
    test = { full = L["TEST MODE"], compact = L["TEST"] },
    sim  = { full = L["SIM"], compact = L["SIM"] },
}

-- ── pure ────────────────────────────────────────────────────────────────────────────────────

--- A tab's label in a layout: compact `Drops` and `History`; full Window.TabLabel's (the same
--- words: feedback-5 spec §3 left two short tab names).
--- @param key string
--- @param compact boolean|nil the layout in force is compact (read when nil)
--- @return string
function CC.TabText(key, compact)
    if compact == nil then compact = NS.WindowCompact.Mode() == "compact" end
    if not compact then return NS.Window.TabLabel(key) end
    return SHORT_TAB[key] or tostring(key)
end

--- The word beside the title: test mode's `TEST MODE` or `TEST`, the simulator's `SIM`.
--- @param kind string `test` or `sim`
--- @param compact boolean|nil
--- @return string
function CC.ModeWord(kind, compact)
    local w = WORD[kind] or WORD.test
    return compact and w.compact or w.full
end

--- The compact restriction badge's text beside its lock: the queued asks' count, or nothing.
--- @param queued number|nil
--- @return string
function CC.BadgeShort(queued)
    local n = tonumber(queued) or 0
    if n > 0 then return tostring(n) end
    return ""
end

local function situationShort(i)
    local name = NS.WindowFooter.SituationLabel(i.situation)
    if type(i.sim) == "table" then return L["Sim: %s"]:format(name) end
    if i.tracking == false then return L["%s (not tracked)"]:format(name) end
    return name
end

--- The compact footer's one line from WindowFooter.Read's inputs: inspect freshness and the
--- situation, `Inspect 4/4 · Mythic+` (`No group · Solo` alone, `Sim: Raid` while simulating).
--- @param i table|nil
--- @return string
function CC.FooterLine(i)
    i = type(i) == "table" and i or {}
    local members = tonumber(i.members) or 0
    local inspect = members == 0 and L["No group"] or L["Inspect %d/%d"]:format(i.good or 0, members)
    return inspect .. " · " .. situationShort(i)
end

--- The compact footer's tooltip: every segment the full footer shows, from WindowFooter.Compose.
--- @param composed table|nil { inspect, loot, situation, pawn }, each { text }
--- @return table lines
function CC.FooterTip(composed)
    composed = type(composed) == "table" and composed or {}
    local TM = NS.TipMarks
    local out = { L["Status"] }
    for _, key in ipairs(NS.WindowFooter.SEGMENTS) do
        local seg = composed[key]
        if seg and seg.text then out[#out + 1] = TM.Row(nil, seg.text) end
    end
    out[#out + 1] = TM.Hint(L["The full view's footer shows each of these on its own."])
    return out
end

local function sameSet(a, b)
    if type(a) ~= "table" or type(b) ~= "table" then return false end
    for k in pairs(a) do if not b[k] then return false end end
    for k in pairs(b) do if not a[k] then return false end end
    return true
end

--- Whether one counted control is off its default on a tab that honors it: Quality when the mode in
--- force is not the feed's default mode, Content when it is not the seeded value, Character when it
--- is not exactly you (on a tab whose default is All, History's, when it names anyone).
--- @param key string `quality`, `content` or `char`
--- @param st table the tab's filter state
--- @param honors table the tab's WindowFilterBar.HONORS row
--- @param d table { quality = mode in force, qualityDefault, content = the seeded Content, current,
--- charAll = the tab's Character default is All }
--- @return boolean
function CC.IsActive(key, st, honors, d)
    if type(st) ~= "table" or type(honors) ~= "table" or not honors[key] then return false end
    if key == "quality" then return d.quality ~= d.qualityDefault end
    if key == "content" then return st.content ~= d.content end
    if key == "char" then
        if d.charAll then return type(st.char) == "table" and next(st.char) ~= nil end
        if NS.CharFilter.IsCurrent(st.char, d.current) then return false end
        return not sameSet(st.char, { [NS.CharFilter.CURRENT] = true })
    end
    return false
end

--- How many counted controls are off their default (CC.IsActive), with no table built.
--- @return number
function CC.CountActive(st, honors, d)
    local n = 0
    for _, key in ipairs(CC.COUNTED) do
        if CC.IsActive(key, st, honors, d) then n = n + 1 end
    end
    return n
end

--- The counted controls off their default, in menu order.
--- @return table keys
function CC.ActiveKeys(st, honors, d)
    local out = {}
    for _, key in ipairs(CC.COUNTED) do
        if CC.IsActive(key, st, honors, d) then out[#out + 1] = key end
    end
    return out
end

--- The Filters button's label: `Filters`, or `Filters · n` while n are off their default.
--- @param n number|nil
--- @return string
function CC.FiltersLabel(n)
    n = tonumber(n) or 0
    if n > 0 then return L["Filters · %d"]:format(n) end
    return L["Filters"]
end

--- The Filters button's tooltip: a row per value in force, in the menu's order, the ones off their
--- default in yellow, then what the button holds.
--- @param labels table { quality, content, char, sort } the collapsed labels in force
--- @param active table|nil the keys off their default (CC.ActiveKeys)
--- @return table lines
function CC.FiltersTip(labels, active)
    local on = {}
    for _, key in ipairs(active or {}) do on[key] = true end
    local TM = NS.TipMarks
    local out = { L["Filters"] }
    for _, key in ipairs(CC.MENU_ROWS) do
        local text = labels and labels[key]
        if text then
            local label = MENU_LABEL[key]
            -- A dropdown's text that names its control already (`Quality: Rare+`) keeps its value.
            if text:sub(1, #label + 2) == label .. ": " then text = text:sub(#label + 3) end
            out[#out + 1] = TM.Row(label, text, on[key] and "yellow" or nil)
        end
    end
    out[#out + 1] = TM.Hint(L["Yellow: off its default."])
    return out
end

-- ── reads ───────────────────────────────────────────────────────────────────────────────────

local function isCompact() return NS.WindowCompact.Mode() == "compact" end

-- The counted controls' defaults on the tab now: the feed's own quality mode, the seeded Content
-- (the `feed.content` row, as a fresh tab's state starts, unless the tab fixes its own:
-- WindowFilterBar.TAB_FIXED), your key, and whether the tab's Character default is All.
local defaults = {}
local function readDefaults(tab)
    local FB, P = NS.WindowFilterBar, NS.C.PROFILE.feed
    local fixed = FB.TAB_FIXED[tab] or {}
    local content = NS.Setting("feed.content")
    local ok = false
    for _, v in ipairs(FB.ContentValues(tab)) do if v == content then ok = true end end
    defaults.content = fixed.content or (ok and content or P.content)
    defaults.charAll = fixed.char ~= nil
    defaults.qualityDefault = P.quality.mode
    defaults.quality = NS.QualityGate.ResolveMode(NS.Setting("feed.quality.mode"), NS.Situations.QualityOverride())
    defaults.current = NS.CharFilter.CurrentKey()
    return defaults
end

-- ── the Filters menu (frame edge) ───────────────────────────────────────────────────────────

local parts = {}   -- filters (the button), menu (the shared menu while this opened it)

local function controlsByKey()
    local c = NS.WindowFilterBar.Controls()
    local _, sort = NS.WindowFooter.Parts()
    return { quality = c.quality, content = c.content, char = c.char, sort = sort }
end

local function labelsInForce()
    local out = {}
    for key, dd in pairs(controlsByKey()) do
        local text = dd and dd.text and dd.text:GetText()
        if text and text ~= "" then out[key] = text end
    end
    return out
end

local function filtersTip()
    local tab = NS.Window.ActiveTab()
    local FB = NS.WindowFilterBar
    return unpack(CC.FiltersTip(labelsInForce(), CC.ActiveKeys(FB.State(tab), FB.HONORS[tab], readDefaults(tab))))
end

-- Whether one of a dropdown's options is what it shows: the library's own reading (an option's
-- isActive first; a multi-select's set, "all" when it is empty; a single-select's value).
local function optionOn(dd, opt)
    if opt.isActive then return opt.isActive(dd) and true or false end
    if dd.multi then
        if opt.value == "all" then return next(dd._selected) == nil end
        return dd._selected[opt.value] == true
    end
    return opt.value == dd._value
end

-- A pick through the dropdown's own path, as a click on its own menu's row: a multi-select toggles
-- (a preset, "all" included, as the dropdown does) and tells onMultiSelect; a single-select sets the
-- value and tells onSelect.
local function pickThrough(dd, opt)
    if dd.multi then
        dd:ToggleSelected(opt.value)
        if dd.onMultiSelect then dd.onMultiSelect(dd._selected) end
        return
    end
    dd:SetValue(opt.value, opt.label)
    if dd.onSelect then dd.onSelect(opt.value, opt) end
end

-- One dropdown's child level: a row per option, its tick and its gold read from the dropdown.
local function childRows(dd)
    local out = {}
    for i, opt in ipairs(dd._options or {}) do
        local function on() return optionOn(dd, opt) end
        out[i] = { value = opt.value, label = opt.label, color = opt.color, title = opt.title, divider = opt.divider,
            selected = on, isActive = on, radio = not dd.multi or nil, keepOpen = dd.multi or nil,
            onClick = function() pickThrough(dd, opt) end }
    end
    return out
end

--- The Filters menu's rows on the active tab: one submenu row per dropdown built, in CC.MENU_ROWS'
--- order, named for its control and disabled where the tab does not honor it (its dropdown grayed).
--- @return table rows (empty with no dropdown: the library absent)
function CC.FilterRows()
    local byKey = controlsByKey()
    local honors = NS.WindowFilterBar.HONORS[NS.Window.ActiveTab()] or {}
    local out = {}
    for _, key in ipairs(CC.MENU_ROWS) do
        local dd = byKey[key]
        if dd then
            out[#out + 1] = { value = key, label = MENU_LABEL[key], submenu = childRows(dd),
                disabled = honors[key] ~= true or nil }
        end
    end
    return out
end

--- Close the Filters menu, when it is the one open (every level of the cascade goes with it).
function CC.CloseFilters()
    local m = parts.menu
    parts.menu = nil
    if m and m:IsShown() then
        NS.CloseMenu()
        NS.Debug(TAG, "filters menu closed")
    end
end

--- Open the Filters menu under its button, or close it (the library's second call on its anchor).
function CC.ToggleFilters()
    local b = parts.filters
    if not b then return end
    local m = NS.ContextMenu(b, CC.FilterRows(), { width = CC.FILTERS_W })
    parts.menu = m and m:IsShown() and m or nil
    NS.Debug(TAG, "filters menu %s", parts.menu and "open" or "closed")
end

-- The filter bar's flat skin, the dropdowns' and the search box's: the skin's Inset, a recessed
-- control's fill and edge (`input.bg`, `input.border`, its style and size; Ka0s Default the 1px
-- WHITE8X8 box these always drew), recorded by the library and repainted on a skin switch.
local function flat(f)
    if not f.SetBackdrop then return end
    NS.Skin.Inset(f)
end

local function buildButton(host)
    local b = CreateFrame("Button", nil, host, "BackdropTemplate")
    b:SetSize(CC.FILTERS_W, K.CONTROL_H)
    flat(b)
    b.label = b:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    b.label:SetPoint("LEFT", b, "LEFT", 6, 0)
    NS.Skin.Text(b.label, "text.highlight")
    b.label:SetText(CC.FiltersLabel(0))
    b.count = 0
    b.arrow = b:CreateTexture(nil, "OVERLAY")
    b.arrow:SetSize(12, 12)
    b.arrow:SetPoint("RIGHT", b, "RIGHT", -4, 0)
    b.arrow:SetTexture(NS.Icon("chevron-down"))
    -- The skin's icon tint (Ka0s Default 0.7 gray), not the dropdown's gold `icon.arrow`.
    NS.SkinPaint(b.arrow, function(t) t:SetVertexColor(NS.SkinColor("icon.tint")) end)
    b:SetPoint("RIGHT", host, "RIGHT", 0, 0)
    b:SetScript("OnClick", function() CC.ToggleFilters() end)
    NS.Window.AttachTooltip(b, filtersTip, "above")
    b:Hide()
    return b
end

local function ensureParts(f)
    if parts.frame == f then return end
    parts = { frame = f }
    parts.filters = buildButton(f.filterHost)
end

-- The dropdowns the Filters menu lists, hidden in compact where the full layout keeps them; the
-- count of those built.
local function hideHeld()
    local n = 0
    for _, dd in pairs(controlsByKey()) do
        dd:Hide()
        n = n + 1
    end
    return n
end

-- ── the layout (frame edge) ─────────────────────────────────────────────────────────────────

local function fitWord(m, word)
    m.text:SetText(word)
    local w = m.text.GetStringWidth and m.text:GetStringWidth()
    if type(w) ~= "number" or w <= 0 then w = #word * 11 end
    m:SetWidth(w)
end

local function layoutTitleBar(f, compact)
    f.title:SetText(compact and L["Drop Watcher"] or NS.BRAND)
    fitWord(f.testText, CC.ModeWord("test", compact))
    fitWord(f.simText, CC.ModeWord("sim", compact))
    f.badge:ClearAllPoints()
    if compact then
        f.badge:SetWidth(CC.BADGE_W)
        f.badge:SetPoint("LEFT", f.lockButton, "RIGHT", 4, 0)
    else
        f.badge:SetWidth(170)
        f.badge:SetPoint("RIGHT", f.modeButton, "LEFT", -8, 0)
    end
end

local function layoutTabs(f, compact)
    local w = compact and CC.TAB_W or K.TAB_W
    for i, key in ipairs(NS.Window.TABS) do
        local tab = f.tabs[key]
        tab:SetWidth(w)
        tab:ClearAllPoints()
        tab:SetPoint("LEFT", f.tabStrip, "LEFT", (i - 1) * (w + K.TAB_GAP), 0)
    end
end

-- The strips' words and wrap, both strips (each nil on a degraded install). The library anchors its
-- text (LEFT to the mark, RIGHT to the strip, justified LEFT), so full truncates a long line and
-- compact wraps the short one to two lines.
local STRIP_TEXT = {
    banner = {
        full    = L["TEST MODE: sample drops of real items in every state. Nothing is whispered. Combat ends it."],
        compact = L["TEST: sample drops in every state. Nothing is whispered; combat ends it."],
    },
    simBanner = {
        full    = L["SIM: a made-up group session through the real engine. Nothing is sent. /dw sim stop ends it."],
        compact = L["SIM: a made-up session. Nothing is sent. /dw sim stop ends it."],
    },
}

local function layoutStrip(f, compact)
    for key, text in pairs(STRIP_TEXT) do
        local b = f[key]
        if b then
            b.text:SetText(compact and text.compact or text.full)
            b.text:SetWordWrap(compact)
        end
    end
end

-- The full bar back: the dropdowns on the bar and Sort on the tab's strip (feedback-10 spec §3).
-- WindowFooter.Refresh shows Sort again on its next pass.
local function restoreBar(f)
    CC.CloseFilters()
    if parts.filters then parts.filters:Hide() end
    local c = NS.WindowFilterBar.Controls()
    for _, key in ipairs(CC.COUNTED) do
        if c[key] then c[key]:Show() end
    end
    NS.WindowFilterBar.Anchor()
    NS.WindowFooter.AnchorSort()
    NS.WindowFilterBar.Layout(f:GetWidth())
end

local function compactBar(f)
    ensureParts(f)
    local c = NS.WindowFilterBar.Controls()
    local held = hideHeld()
    parts.filters:SetShown(held > 0)
    if c.view then c.view:SetWidth(CC.VIEW_W) end
    local eb = c.search
    if not eb then return end
    eb:ClearAllPoints()
    if c.view then eb:SetPoint("LEFT", c.view, "RIGHT", GAP, 0) else eb:SetPoint("LEFT", f.filterHost, "LEFT", 0, 0) end
    if held > 0 then eb:SetPoint("RIGHT", parts.filters, "LEFT", -GAP, 0)
    else eb:SetPoint("RIGHT", f.filterHost, "RIGHT", 0, 0) end
    eb.hint:SetText(L["Filter…"])
    eb:Show()
end

local function layoutFooter(compact)
    local segments = NS.WindowFooter.Parts()
    for key, s in pairs(segments) do
        if key ~= "inspect" then s:SetShown(not compact) end
    end
end

local function layout(f, compact)
    layoutTitleBar(f, compact)
    layoutTabs(f, compact)
    layoutStrip(f, compact)
    layoutFooter(compact)
    if compact then compactBar(f) else restoreBar(f) end
    NS.Debug(TAG, "chrome -> %s", compact and "compact" or "full")
end

-- The title and the word beside it centered together in compact, the title alone in full.
local function placeTitle(f, compact)
    local word = (f.testText:IsShown() and f.testText) or (f.simText:IsShown() and f.simText) or nil
    local x = 0
    if compact and word then x = -(NS.WindowTitleBar.MODE_GAP + (word:GetWidth() or 0)) / 2 end
    if f.titleX == x then return end
    f.titleX = x
    f.title:ClearAllPoints()
    f.title:SetPoint("CENTER", f.titleBar, "CENTER", x, 0)
end

local function paintFilters()
    local b = parts.filters
    if not (b and b:IsShown()) then return end
    local tab = NS.Window.ActiveTab()
    local FB = NS.WindowFilterBar
    local n = CC.CountActive(FB.State(tab), FB.HONORS[tab], readDefaults(tab))
    if b.count == n then return end
    b.count = n
    b.label:SetText(CC.FiltersLabel(n))
end

--- One pass of the chrome (Window.Refresh, before the tabs and the bar): the whole layout when the
--- layout in force changed since the last pass, then the title's place, the strip's height and, in
--- compact, the Filters button's count. A minimized window closes the Filters menu.
--- @param f table the window frame
function CC.Paint(f)
    local compact = isCompact()
    if f.chromeCompact ~= compact then
        f.chromeCompact = compact
        layout(f, compact)
    end
    placeTitle(f, compact)
    local b = CC.ModeStrip(f)
    local h = CC.BannerH() - 4
    if b and b.slotH ~= h then
        b.slotH = h
        b:SetHeight(h)
    end
    if NS.Window.IsMinimized() then CC.CloseFilters() end
    if compact then paintFilters() end
end

-- A font string's width on one line. On Retail since 10.0 GetStringWidth is bounded by the width
-- the anchors give it, so a wrapped string never reads wider than its room; GetUnboundedStringWidth
-- is the unwrapped width.
local function unwrappedWidth(fs)
    local measure = fs.GetUnboundedStringWidth or fs.GetStringWidth
    local w = measure and measure(fs)
    return type(w) == "number" and w > 0 and w or nil
end

--- The strip of the mode in force: f.banner in test mode, f.simBanner while a simulation runs (the
--- two modes are exclusive), else f.banner. Nil on a degraded install (no Widgets library).
--- @param f table the window frame
--- @return table|nil
function CC.ModeStrip(f)
    if NS.State.testMode == true then return f.banner end
    if NS.Sim:IsActive() then return f.simBanner end
    return f.banner
end

--- The height of the strip in force (CC.ModeStrip) in the layout in force: one line full; compact two
--- when its words do not fit on one line (their unwrapped width against the room their anchors give
--- them); 0 when the window has no such strip (the Widgets library absent).
--- @return number
function CC.BannerH()
    local f = NS.Window.Frame()
    local strip = f and CC.ModeStrip(f)
    if f and not strip then return 0 end
    if not (f and f.chromeCompact) then return K.BANNER_H end
    local fs = strip.text
    local w = unwrappedWidth(fs)
    local room = fs.GetWidth and fs:GetWidth()
    if type(room) ~= "number" or room <= 0 then room = (f:GetWidth() or 0) - 2 * K.INSET - 30 end
    if w and room > 0 and w <= room then return K.BANNER_H end
    return K.BANNER_H + CC.WRAP_H
end

--- The compact footer (WindowFooter.Refresh): the inspect segment holds the one line, its tooltip
--- every full segment; the other segments are hidden by the layout.
--- @param segments table WindowFooter's built segments
--- @param read table WindowFooter.Read's inputs
--- @param composed table WindowFooter.Compose's segments
function CC.PaintFooter(segments, read, composed)
    local s = segments.inspect
    if not s then return end
    s.text:SetText(CC.FooterLine(read))
    s.tipLines = CC.FooterTip(composed)
    local w = s.text:GetStringWidth()
    s:SetWidth(type(w) == "number" and w > 0 and w or 200)
end

--- The Filters button and the menu it opened, for the suites: { filters, menu }.
--- @return table
function CC.Parts() return parts end

-- A hidden window closes the menu with it.
NS.Window.AddVisibilityListener(function(shown)
    if not shown then CC.CloseFilters() end
end)
