local _, NS = ...
-- modules/CompactChrome.lua — the window's chrome in the compact layout (compact spec §4, DW-C4):
-- the title bar, the tabs, the one-row filter bar with its Filters menu, the mode strips (test mode's
-- and the simulation's) and the one-line footer. The same frame and the same controls as the full layout, laid out again: nothing
-- here changes what is recorded, gated, judged or sent.
--
--   title bar   `Drop Watcher` centered, alone while a mode's strip marks the mode; `TEST` / `SIM`
--               beside it in their red and cyan only while minimized or with no strip; the
--               restriction badge its lock and the queued count, at the left; the layout toggle,
--               minimize and close at the right (Scan group is the Drops strip's icon, feedback-16)
--   tabs        `Drops`, `History` at a reduced width (their tooltips say what each holds)
--   filter bar  View, the search box (`Filter…`) and Filters ▾ on the right. The Filters menu holds
--               the full bar's Quality, Content and Character dropdowns and the tab's Sort, the
--               very same LibKa0s-Widgets dropdowns moved into it, so their choices, their
--               multi-select and their per-tab state are identical. The button counts the ones not at
--               their default (`Filters · 2`), and its tooltip lists every value in force.
--   strip       the strip in force (test mode's or the simulation's) in shorter words, wrapping to
--               two lines when the width needs it
--   footer      one line, `Inspect 4/4 · Mythic+`; the rest of the full footer is its tooltip
--
-- WHY A PANEL, NOT SUBMENUS. LibKa0s-Widgets-1.0's popup has no submenu rows, and a second set of
-- dropdowns would be a second state to keep in step. So Filters ▾ opens a small panel under the
-- button holding the four dropdowns themselves, each opening its own menu as on the full bar.
--
-- PURE: TabText, ModeWord, BadgeShort, FooterLine, FooterTip, IsActive, ActiveKeys, CountActive,
-- FiltersLabel and FiltersTip. The edge: Paint (Window.Refresh's every pass; the layout itself only
-- when the layout in force changed), ModeStrip (the strip of the mode in force), BannerH (its height,
-- which Window's pane layout reads),
-- PaintFooter (WindowFooter.Refresh in compact) and the Filters panel. WindowFilterBar.Layout
-- stands aside in compact: the search box's anchors size it there.

NS.CompactChrome = NS.CompactChrome or {}
local CC = NS.CompactChrome
local K  = NS.Constants.WINDOW
local L  = NS.L

local TAG = "UI"

CC.TAB_W     = 84     -- one compact tab
CC.VIEW_W    = 104    -- the View dropdown on the compact bar
CC.FILTERS_W = 84     -- the Filters ▾ button
CC.PANEL_W   = 196    -- the Filters panel
CC.BADGE_W   = 44     -- the restriction badge: its lock and the queued count
CC.WRAP_H    = 12     -- the strip's second line
local GAP = 8
local ROW_GAP = 4

-- The Filters panel's rows, top to bottom; the tab's Sort is the last.
CC.PANEL_ROWS = { "quality", "content", "char", "sort" }
-- The ones the button counts (compact spec §4: Quality, Content and Character).
CC.COUNTED = { "quality", "content", "char" }
-- Each panel row's name, its Filters tooltip row's label.
local PANEL_LABEL = { quality = L["Quality"], content = L["Content"], char = L["Character"], sort = L["Sort"] }

local SHORT_TAB = { group = L["Drops"], history = L["History"] }
local WORD = {
    test = { full = L["TEST MODE"], compact = L["TEST"] },
    sim  = { full = L["SIMULATION"], compact = L["SIM"] },
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

--- The word beside the title: test mode's `TEST MODE` or `TEST`, the simulator's `SIMULATION` or `SIM`.
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

--- The Filters button's tooltip: a row per value in force, in the panel's order, the ones off their
--- default in yellow, then what the button holds.
--- @param labels table { quality, content, char, sort } the collapsed labels in force
--- @param active table|nil the keys off their default (CC.ActiveKeys)
--- @return table lines
function CC.FiltersTip(labels, active)
    local on = {}
    for _, key in ipairs(active or {}) do on[key] = true end
    local TM = NS.TipMarks
    local out = { L["Filters"] }
    for _, key in ipairs(CC.PANEL_ROWS) do
        local text = labels and labels[key]
        if text then
            local label = PANEL_LABEL[key]
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

-- ── the Filters panel (frame edge) ──────────────────────────────────────────────────────────

local parts = {}   -- filters (the button), panel

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

--- Close the Filters panel (and any dropdown menu opened from it).
function CC.CloseFilters()
    if parts.panel and parts.panel:IsShown() then
        NS.CloseMenu()
        parts.panel:Hide()
    end
end

--- Open or close the Filters panel under its button.
function CC.ToggleFilters()
    local p = parts.panel
    if not p then return end
    if p:IsShown() then CC.CloseFilters() return end
    NS.CloseMenu()
    p:Show()
    NS.Debug(TAG, "filters panel open")
end

local function flat(f)
    local FLAT = NS.WindowFilterBar.FLAT
    if not f.SetBackdrop then return end
    f:SetBackdrop({ bgFile = FLAT.edge, edgeFile = FLAT.edge, edgeSize = 1,
                    insets = { left = 1, right = 1, top = 1, bottom = 1 } })
    f:SetBackdropColor(unpack(FLAT.fill))
    f:SetBackdropBorderColor(unpack(FLAT.line))
end

local function buildButton(host)
    local b = CreateFrame("Button", nil, host, "BackdropTemplate")
    b:SetSize(CC.FILTERS_W, K.CONTROL_H)
    flat(b)
    b.label = b:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    b.label:SetPoint("LEFT", b, "LEFT", 6, 0)
    b.label:SetText(CC.FiltersLabel(0))
    b.count = 0
    b.arrow = b:CreateTexture(nil, "OVERLAY")
    b.arrow:SetSize(12, 12)
    b.arrow:SetPoint("RIGHT", b, "RIGHT", -4, 0)
    b.arrow:SetTexture(NS.Icon("chevron-down"))
    b.arrow:SetVertexColor(0.7, 0.7, 0.72)
    b:SetPoint("RIGHT", host, "RIGHT", 0, 0)
    b:SetScript("OnClick", function() CC.ToggleFilters() end)
    NS.Window.AttachTooltip(b, filtersTip, "above")
    b:Hide()
    return b
end

local function buildPanel(f, button)
    local p = CreateFrame("Frame", nil, f, "BackdropTemplate")
    p:SetFrameStrata("DIALOG")
    flat(p)
    p:EnableMouse(true)
    p:SetPoint("TOPRIGHT", button, "BOTTOMRIGHT", 0, -2)
    p:SetSize(CC.PANEL_W, 12 + #CC.PANEL_ROWS * (K.CONTROL_H + ROW_GAP) - ROW_GAP)
    p:Hide()
    return p
end

local function ensureParts(f)
    if parts.frame == f then return end
    parts = { frame = f }
    parts.filters = buildButton(f.filterHost)
    parts.panel = buildPanel(f, parts.filters)
end

-- Move the four dropdowns into the panel, one under another.
local function fillPanel()
    local p = parts.panel
    local byKey = controlsByKey()
    local i = 0
    for _, key in ipairs(CC.PANEL_ROWS) do
        local dd = byKey[key]
        if dd then
            dd:SetParent(p)
            dd:ClearAllPoints()
            dd:SetPoint("TOPLEFT", p, "TOPLEFT", 6, -(6 + i * (K.CONTROL_H + ROW_GAP)))
            dd:SetWidth(CC.PANEL_W - 12)
            i = i + 1
        end
    end
    return i
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
        f.badge:SetPoint("LEFT", f.titleBar, "LEFT", 6, 0)
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
        full    = L["SIMULATION: a made-up group session through the real engine. Nothing is sent; /dw sim stop ends it."],
        compact = L["SIM: a made-up session. Nothing is sent; /dw sim stop ends it."],
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
local function restoreBar(f)
    CC.CloseFilters()
    if parts.filters then parts.filters:Hide() end
    NS.WindowFilterBar.Anchor()
    NS.WindowFooter.AnchorSort()
    NS.WindowFilterBar.Layout(f:GetWidth())
end

local function compactBar(f)
    ensureParts(f)
    local c = NS.WindowFilterBar.Controls()
    local held = fillPanel()
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
--- compact, the Filters button's count. A minimized window closes the Filters panel.
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

--- The Filters button and panel, for the suites: { filters, panel }.
--- @return table
function CC.Parts() return parts end

-- A hidden window closes the panel with it.
NS.Window.AddVisibilityListener(function(shown)
    if not shown then CC.CloseFilters() end
end)
