local _, NS = ...
-- modules/WindowTabs.lua — the main window's tab strip (design spec §11.1, board 01), peeled out of
-- the shell (RX-27: modules/Window.lua had passed the 1100-line split point its automated-test
-- disposition set): the tabs' labels, tooltips and placeholders, the strip and its tabs, one pane per
-- tab with its placeholder, the panes' layout under the filter bar, the tabs' paint, and the tabs'
-- registry (each body's `{ build, refresh, ownBar }`, NS.Window.RegisterTab) with the lazy build and
-- the active tab's refresh.
--
-- THE SHELL KEEPS THE STATE. Which tab is active, the frame, the show decision and the repaint pass
-- stay modules/Window.lua's (Window.SelectTab, Window.ActiveTab, Window.Refresh); every function here
-- takes the frame and the active tab from it, so nothing here holds a second copy. The frame fields
-- are the shell's as before: `f.tabStrip`, `f.tabs[key]` (each with its `label`, and without the
-- library its own `underline`) and `f.panes[key]` (each with its `placeholder` and, once its body is
-- built, `built`). modules/CompactChrome.lua lays the same tabs out at its own width.
--
-- THE TABS (feedback-5 spec §3 retired `mine`; issue #12 added Insights after History) are
-- NS.Window.TABS, in strip order; a retired key opens the tab that took its drops (WT.Resolve).
--
-- LOAD ORDER. Directly before modules/Window.lua in the TOC: the shell captures NS.WindowTabs as it
-- loads, and this file reads NS.Window (TABS, SelectTab, AttachTooltip) only at call time.

NS.WindowTabs = NS.WindowTabs or {}
local WT = NS.WindowTabs
local K  = NS.Constants.WINDOW
local L  = NS.L

local TAB_SET = { group = true, history = true, insights = true }
-- A retired tab's key opens the tab that took its drops.
local TAB_ALIAS = { mine = "group" }
local TAB_LABEL = { group = L["Drops"], history = L["History"], insights = L["Insights"] }
-- Each tab's tooltip rows (feedback-21): { label, value } pairs, or a function answering them
-- (Insights names the period it covers, which the retention row moves).
local TAB_TIP = {
    group   = { { L["Holds"], L["every drop your group receives, yours included"] }, { L["Grouped by"], L["boss or key run"] } },
    history = { { L["Holds"], L["drops from earlier encounters"] }, { L["Kept"], L["across sessions"] } },
    insights = function()
        local R = NS.HistoryRetention
        local days = R.Days()
        return { { L["Holds"], L["charts over the kept history"] },
            { L["Covers"], days > 0 and L["the last %s kept"]:format(R.Label(days)) or L["every kept day"] } }
    end,
}
-- What a tab with no body yet says, so the window is never blank.
local TAB_PLACEHOLDER = {
    group   = L["No drops yet. Loot your group receives appears here."],
    history = L["Drops from earlier encounters appear here."],
    insights = L["Charts over the kept history appear here."],
}

local tabSpecs = {}   -- [tab] = { build = fn(pane), refresh = fn(pane, ctx), ownBar = boolean|nil }

-- ── pure ────────────────────────────────────────────────────────────────────────────────────

--- Whether `key` names a tab (a retired key does not).
--- @param key string|nil
--- @return boolean
function WT.Known(key) return TAB_SET[key] == true end

--- The tab a key opens: itself, the tab that took a retired key's drops, or nil for no tab.
--- @param key string|nil
--- @return string|nil
function WT.Resolve(key)
    key = TAB_ALIAS[key] or key
    return TAB_SET[key] and key or nil
end

--- A tab's label in the full layout: `Drops`, `History` or `Insights`. No count: the Drops tab's
--- footer says how many of your drops you can still trade (feedback-5 spec §3).
--- @param key string
--- @return string
function WT.Label(key)
    return TAB_LABEL[key] or tostring(key)
end

--- A tab's tooltip: its label and what it holds.
--- @param key string
--- @return string title, string... lines
function WT.Tip(key)
    local out, rows = { TAB_LABEL[key] }, TAB_TIP[key]
    if type(rows) == "function" then rows = rows() end
    for _, r in ipairs(rows or {}) do out[#out + 1] = NS.TipMarks.Row(r[1], r[2]) end
    return unpack(out)
end

-- ── the registry ────────────────────────────────────────────────────────────────────────────

--- Keep a tab's body (NS.Window.RegisterTab).
--- @param key string
--- @param spec table { build = fn, refresh = fn, ownBar = boolean|nil }
function WT.Register(key, spec)
    assert(TAB_SET[key], "unknown tab " .. tostring(key))
    tabSpecs[key] = spec
end

--- Whether a tab draws its own filter bar (its spec's `ownBar`: Insights).
--- @param key string
--- @return boolean
function WT.OwnsBar(key)
    local spec = tabSpecs[key]
    return spec ~= nil and spec.ownBar == true
end

--- Build a tab's body on its first show (its spec's `build`); a tab with no body keeps its placeholder.
--- @param f table the window frame
--- @param key string
function WT.BuildPane(f, key)
    local pane, spec = f.panes[key], tabSpecs[key]
    if spec and not pane.built then
        pane.built = true
        spec.build(pane)
    end
end

--- The active tab's refresh with its view; a tab with no body shows its placeholder (a body shows
--- it itself, as its empty state, from its refresh).
--- @param f table the window frame
--- @param active string
--- @param ctx function tab -> Window.TabContext's
function WT.RefreshActive(f, active, ctx)
    for key, p in pairs(f.panes) do
        p.placeholder:SetShown(tabSpecs[key] == nil)
    end
    local spec = tabSpecs[active]
    if spec and spec.refresh then spec.refresh(f.panes[active], ctx(active)) end
end

-- ── construction ────────────────────────────────────────────────────────────────────────────

local function buildTab(strip, key, i)
    local tab = CreateFrame("Button", nil, strip)
    tab:SetSize(K.TAB_W, K.TAB_H)
    tab:SetPoint("LEFT", strip, "LEFT", (i - 1) * (K.TAB_W + K.TAB_GAP), 0)
    tab.label = tab:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    tab.label:SetPoint("CENTER", tab, "CENTER", 0, 0)
    tab.label:SetText(TAB_LABEL[key])
    if NS.Skin.IsEnabled() then
        -- The skin's Tab (FS-DW-FIX, cause A1): its backing, edge, underline and label colors.
        NS.Skin.Tab(tab, { text = tab.label, selected = false })
    else
        -- Without the library: the text roles (WT.Paint) and this underline, as the window drew.
        tab.underline = tab:CreateTexture(nil, "ARTWORK")
        NS.SkinPaint(tab.underline, function(t) t:SetColorTexture(NS.SkinColor("tab.onLine")) end)
        tab.underline:SetHeight(2)
        tab.underline:SetPoint("BOTTOMLEFT", tab, "BOTTOMLEFT", 8, 0)
        tab.underline:SetPoint("BOTTOMRIGHT", tab, "BOTTOMRIGHT", -8, 0)
    end
    tab:SetScript("OnClick", function() NS.Window.SelectTab(key) end)
    NS.Window.AttachTooltip(tab, function() return WT.Tip(key) end, "chrome")
    return tab
end

--- The strip along the body's top and a tab per NS.Window.TABS key on it (`f.tabStrip`, `f.tabs`).
--- @param f table the window frame
--- @param body table its body
function WT.Build(f, body)
    local strip = CreateFrame("Frame", nil, body)
    strip:SetPoint("TOPLEFT", body, "TOPLEFT", K.INSET, -2)
    strip:SetPoint("TOPRIGHT", body, "TOPRIGHT", -K.INSET, -2)
    strip:SetHeight(K.TAB_H)
    f.tabStrip, f.tabs = strip, {}
    for i, key in ipairs(NS.Window.TABS) do f.tabs[key] = buildTab(strip, key, i) end
end

--- One hidden pane per tab, each with its placeholder (`f.panes`); laid out by WT.Layout.
--- @param f table the window frame
--- @param body table its body
function WT.BuildPanes(f, body)
    f.panes = {}
    for _, key in ipairs(NS.Window.TABS) do
        local pane = CreateFrame("Frame", nil, body)
        pane.placeholder = pane:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        pane.placeholder:SetPoint("CENTER", pane, "CENTER", 0, 0)
        NS.Skin.Text(pane.placeholder, "text.highlight")
        pane.placeholder:SetText(TAB_PLACEHOLDER[key])
        pane:Hide()
        f.panes[key] = pane
    end
end

-- ── the paint ───────────────────────────────────────────────────────────────────────────────

--- The panes fill between the filter bar and the footer (the strip in force, in test mode or a
--- simulation, is over the tabs: the shell moved the body down by it); a pane with its own bar
--- (WT.OwnsBar) starts under the tabs, and while it is the active tab the shared bar is hidden. A
--- pane is anchored again only when its top moves (RX-27: not on every pass).
--- @param f table the window frame
--- @param active string
function WT.Layout(f, active)
    f.filterHost:SetShown(not WT.OwnsBar(active))
    for key, pane in pairs(f.panes) do
        local top = K.TAB_H + 4 + (WT.OwnsBar(key) and 0 or K.FILTER_H)
        if pane.dwTop ~= top then
            pane.dwTop = top
            pane:ClearAllPoints()
            pane:SetPoint("TOPLEFT", f.body, "TOPLEFT", K.INSET, -top)
            pane:SetPoint("BOTTOMRIGHT", f.body, "BOTTOMRIGHT", -K.INSET, 0)
        end
    end
end

--- The tabs' labels in the layout in force and the skin's selection (S.SetTabSelection, which keeps
--- it through a skin switch), once per change. Without the library, the labels in text roles: the
--- active one in the accent, an idle one in the idle gray `dw.idle`, with the window's own underline.
--- @param f table the window frame
--- @param active string
function WT.Paint(f, active)
    for key, tab in pairs(f.tabs) do
        local on = key == active
        local role = on and "accent" or "dw.idle"
        tab.label:SetText(NS.CompactChrome.TabText(key))
        if tab.dwRole ~= role then
            tab.dwRole = role
            if tab.underline then NS.Skin.Text(tab.label, role) else NS.Skin.SetTabSelection(tab, on) end
        end
        if tab.underline then tab.underline:SetShown(on) end
    end
end
