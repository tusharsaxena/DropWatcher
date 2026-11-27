local addonName, NS = ...
-- modules/ItemSearchWindow.lua — the Item Search window (DropWatcher#17, Item Search spec §4.5; Item
-- Search feedback spec §5; mockups V2Window and V2Tabs): the frame edge over the pure halves,
-- modules/ItemSearchView.lua (the search and the header), modules/ItemSearchCells.lua (each tab's
-- rows) and modules/ItemSearchTabs.lua (the tabs, columns, filters and sorts), drawn through
-- modules/ItemSearchGrid.lua's headers, tables and match rows. WoW Forever's alone
-- (C.FEATURE.itemSearch, clients-§4): on Retail nothing here is built or opens.
--
-- THE WINDOW (feedback spec §5.1). A non-secure standalone window (standalone-windows) in Drop
-- Watcher's chrome: the skin's shell and title band (NS.ApplySkin, NS.Skin.Shell, NS.Skin.Header),
-- the title "Drop Watcher · Item Search" in the main window's title font (GameFontNormal through
-- NS.Skin.TitleBar), the title bar's settings and close marks (NS.WindowTitleBar.Marks; the lock and
-- its code are gone, W13: it is always movable by its title bar), the library's footer with
-- ForeverDB's state alone (no key hint, W2), Escape (UISpecialFrames), raised on a click
-- (SetToplevel), clamped to the screen. It is resizable from the footer's corner grip
-- (NS.MakeResizable, W14): C.ITEM_SEARCH.WINDOW's MIN_W x MIN_H at least, the screen at most,
-- WIDTH x HEIGHT by default; the size is saved with the position (itemSearch.window.size, .point)
-- and the panes reflow to it, the tables' flex columns taking the room (spec §5.4). It is NOT a
-- companion (its key opens it on its own and it keeps a saved position), so it carries the gear.
--
-- FONTS MATCH DROP WATCHER (W3). Every row, cell and match is drawn in the main window's table font
-- and row height (NS.WindowRows.Metrics: Window > Layout's Row height and the Tables font block,
-- the skin's face and its scale); the headers' and the column labels' text is the main window's
-- (GameFontNormalSmall in `list.header.text`); the item header's name is the main window's own
-- item title, the detail card's (modules/DetailCard.lua: GameFontNormal in the skin's face), its
-- line the small template, never GameFontNormalLarge.
--
-- THE LEFT PANE (spec §5.2). The search box (the library's, NS.MakeSearchBox, or a plain edit box
-- without it) and Clear (a flat button, its label centered: no mark beside it, W6); the matches,
-- run C.ITEM_SEARCH.DEBOUNCE seconds after the last key (Enter shows the first match at once),
-- under a "Matches · n" section header with a Sort mark (Best match, Name, Item id). Each match row
-- is ISG.MatchRow: striped, washed under the pointer, the selected look on the item the right pane
-- shows (W5), its game tooltip on hover, a shift-click linking it (W7). Recent searches are gone
-- (W4): no list, no store, no setting (schema step 17). Under the matches, while you hold the item
-- shown (bags or bank), the verdict panel (modules/ItemSearchVerdictPanel.lua, round 4 addendum A1,
-- R4-DW-11): the tooltip's badge and the score's breakdown; the Matches list shrinks to make room
-- and takes the full height again when it hides.
--
-- THE RIGHT PANE (spec §5.3). The item header (icon, name in its quality color, the line, and a dim
-- "Shift-click the name or icon to link it"): hovering the icon or the name shows the item's game
-- tooltip, a shift-click on either links it in chat (W7; the Link in chat button and its code are
-- gone). The ForeverDB notice while it is not loaded. Then the tab strip: the main window's tab
-- look (NS.Skin.Tab, NS.Skin.SetTabSelection; modules/WindowTabs.lua's, without the library its
-- own underline), a tab per section with rows in TABS.ORDER, each label with its count (Crafting's
-- filtered count, the whole count dim beside it). The tab shown is the last one picked
-- (itemSearch.window.tab) when the item has it, else the first. Under the strip the tab's section
-- header (its title and count, the sort in force, Filter · Sort · Reset; Crafting's My professions
-- chip) and its table. Each tab's view state (its sort and filters, TABS' state) lives for the
-- session and is never saved (spec §5.5).
--
-- READS NEVER LOAD (spec §2). Every ForeverDB read goes through NS.ItemSearch.Get or the reader only
-- while NS.ItemSearch.State() is "loaded".

NS.ItemSearchWindow = NS.ItemSearchWindow or {}
local ISW  = NS.ItemSearchWindow
local IS   = NS.ItemSearch
local ISV  = NS.ItemSearchView
local ISC  = NS.ItemSearchCells
local TABS = NS.ItemSearchTabs
local ISG  = NS.ItemSearchGrid
local C    = NS.Constants
local L    = NS.L

local Compat = NS.Compat
local WIN = C.ITEM_SEARCH.WINDOW
local K   = C.WINDOW

local frame                 -- built on the first open
local shownItem             -- the item the detail pane shows
local query = ""            -- the search box's text as last typed
local searchTimer           -- the debounce
local retries = 0           -- repaints asked for an item the client is still loading
local matches = {}
local matchSort = "best"    -- the matches' Sort (spec §5.2), for the session
local views = {}            -- [tab] = TABS' view state, for the session (spec §5.5: never saved)
local shownTab              -- the tab on screen now
-- The last ISC.Build (the item, its facts and its rows), kept for a VIEW-ONLY repaint: a corner drag,
-- a sort or filter click, Reset or a tab pick changes only how the rows are shown, so it re-lays
-- the table from these rows instead of reading the facts and ranking every section again (the
-- feedback review's resize finding). Every other repaint builds afresh and replaces them.
local lastBuild = { item = nil, facts = nil, rows = nil }
local viewOnly = false      -- the next ISW.Refresh may reuse lastBuild (repaintView sets it)

local function TM() return NS.TipMarks end
local function VP() return NS.ItemSearchVerdictPanel end
local function WP() return NS.ItemSearchWaypoint end

-- ── settings ────────────────────────────────────────────────────────────────────────────────

local function setting(key, default)
    local v = NS.Setting("itemSearch.window." .. key)
    if v == nil then return default end
    return v
end

--- The window's settings, read now (every key under itemSearch.window).
--- @return table { barFromSkin, barColor, pins }
function ISW.Options()
    return {
        barFromSkin = setting("barFromSkin", true) ~= false, barColor = setting("barColor"),
        pins = setting("pins", true) ~= false,
    }
end

--- Whether the window can open now: WoW Forever, and its switch on.
--- @return boolean
function ISW.Available()
    return IS.Enabled() and NS.Setting("itemSearch.window.enabled") ~= false
end

local function geometry()
    local db = NS.addon and NS.addon.db
    local p = db and db.profile
    if type(p) ~= "table" then return {} end
    if type(p.itemSearch) ~= "table" then p.itemSearch = {} end
    if type(p.itemSearch.window) ~= "table" then p.itemSearch.window = {} end
    return p.itemSearch.window
end

-- ── the view's context ──────────────────────────────────────────────────────────────────────

local function loadedDB()
    if IS.State() ~= "loaded" then return nil end
    return NS.ForeverDB
end

-- ForeverDB's state as the window words it: a load that failed because the addon is missing is
-- "missing" (spec §1's line), not "failed".
local function fdbState()
    local state = IS.State()
    if state == "failed" and IS.FailReason() == "missing" then return "missing" end
    return state
end

local function itemOf(id)
    local db = loadedDB()
    local it = db and db.Item(id) or nil
    if type(it) ~= "table" then it = Compat.ItemInfoByID(id) end
    return it
end

-- The cells' context (modules/ItemSearchCells.lua's header): ForeverDB's reads only once loaded.
local function cellsContext()
    local db = loadedDB()
    return {
        spots = db and db.Spots or nil, mapName = Compat.MapName, npc = db and db.NPC or nil,
        object = db and db.Object or nil, quest = db and db.Quest or nil, item = itemOf,
        profession = NS.ItemSearchTip.ProfessionName, coin = Compat.CoinText, dateText = Compat.DateText,
        facts = IS.Get,   -- a not-known recipe's recipe item, for where it is learned (ISR3-DW-08)
    }
end

local function headerContext()
    return { qualityName = Compat.QualityName, classNames = Compat.ItemClassNames }
end

-- ── colors ──────────────────────────────────────────────────────────────────────────────────

local function barColor(o)
    if o.barFromSkin then
        local r, g, b = NS.SkinColor("text.accent")
        if r then return r, g, b end
    end
    local c = type(o.barColor) == "table" and o.barColor or C.TONE.mutedGold
    return c.r or c[1] or 1, c.g or c[2] or 1, c.b or c[3] or 1
end

local function toneRGB(tone)
    local t = C.TONE[tone] or C.TONE.plain
    return t.r, t.g, t.b
end

-- A quest row's mark: the tooltip's own, in the game's style and at its size (round 3 spec §4.2,
-- item 13).
local function questMark(status)
    return NS.ItemSearchTip.QuestMark(status, C.ITEM_SEARCH.MARK_SIZE)
end

-- ── the view states ─────────────────────────────────────────────────────────────────────────

local function stateOf(tab)
    if not views[tab] then views[tab] = TABS.DefaultState(tab, IS.ViewDefaults()) end
    return views[tab]
end

-- Repaint how the rows are shown, from the last build (see lastBuild).
local function repaintView()
    viewOnly = true
    ISW.Refresh()
end

--- A tab's view state now (its sort and filters; the default until a click moves it).
--- @param tab string
--- @return table
function ISW.ViewState(tab) return stateOf(tab) end

--- Sort tab `tab` by column `key` (a click on its label: the same column flips) or "best".
--- @param tab string
--- @param key string
function ISW.SortBy(tab, key)
    local st = stateOf(tab)
    st.sort = TABS.NextSort(tab, st.sort, key)
    repaintView()
end

--- Turn one of tab `tab`'s filters (spec §5.5) on or off (`on` nil flips it). View only, not saved.
--- @param tab string
--- @param key string
--- @param on boolean|nil
function ISW.SetFilter(tab, key, on)
    local st = stateOf(tab)
    if on == nil then on = st.filters[key] ~= true end
    st.filters[key] = on == true
    repaintView()
end

--- Reset tab `tab`: Best for you, every filter at its default.
--- @param tab string
function ISW.ResetView(tab)
    views[tab] = nil
    repaintView()
end

--- The "Only professions you know" setting moved (spec §4: the Crafting tab starts filtered by it):
--- the tab's filter follows the setting again, then the window repaints as for any setting.
function ISW.FollowProfessionsSetting()
    if views.crafting then views.crafting.filters.mine = IS.MyProfessionsOnly() end
    ISW.ApplySettings()
end

--- The "Hide the other faction's vendors" setting moved (R4-DW-08): the Sold by tab's "Only my
--- faction" follows the setting again, then the window repaints as for any setting.
function ISW.FollowFactionSetting()
    if views.vendors then views.vendors.filters.faction = IS.HideOtherFaction() end
    ISW.ApplySettings()
end

--- The tab picked last (kept per profile), or nil.
--- @return string|nil
function ISW.PickedTab() return geometry().tab end

--- Show tab `key` and remember it as the one picked last.
--- @param key string
function ISW.SelectTab(key)
    geometry().tab = key
    repaintView()
end

--- The tab on screen now, or nil.
--- @return string|nil
function ISW.ShownTab() return shownTab end

-- ── building: the title bar ─────────────────────────────────────────────────────────────────

local function savePoint()
    local point, _, relativePoint, x, y = frame:GetPoint(1)
    if point then geometry().point = { point, relativePoint, x, y } end
end

local function applyPoint()
    local pt = geometry().point
    frame:ClearAllPoints()
    if type(pt) == "table" and type(pt[1]) == "string" then
        frame:SetPoint(pt[1], UIParent, pt[2] or pt[1], tonumber(pt[3]) or 0, tonumber(pt[4]) or 0)
    else
        frame:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
    end
end

-- The saved size, at least the minimum (no saved size: the default).
local function savedSize()
    local s = geometry().size
    local w = type(s) == "table" and tonumber(s[1]) or WIN.WIDTH
    local h = type(s) == "table" and tonumber(s[2]) or WIN.HEIGHT
    return math.max(WIN.MIN_W, w), math.max(WIN.MIN_H, h)
end

local function applySize()
    local w, h = savedSize()
    frame:SetSize(w, h)
    frame.dwW, frame.dwH = w, h
end

-- The window's width now: the frame's, else the size it was given.
local function width()
    local w = frame and frame:GetWidth() or 0
    if type(w) ~= "number" or w <= 0 then w = frame and frame.dwW or WIN.WIDTH end
    return w
end

local function buildTitle(f)
    local bar = CreateFrame("Frame", nil, f)
    bar:SetPoint("TOPLEFT", f, "TOPLEFT", 1, -1)
    bar:SetPoint("TOPRIGHT", f, "TOPRIGHT", -1, -1)
    bar:SetHeight(K.TITLE_H)
    bar:EnableMouse(true)
    bar:RegisterForDrag("LeftButton")
    bar:SetScript("OnDragStart", function() f:StartMoving() end)
    bar:SetScript("OnDragStop", function()
        f:StopMovingOrSizing()
        savePoint()
    end)
    f.titleBar = bar
    f.title = bar:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    f.title:SetPoint("CENTER", bar, "CENTER", 0, 0)
    f.title:SetText(L["Drop Watcher · Item Search"])
    NS.Skin.TitleBar(bar, { text = f.title, place = NS.WindowTitleBar.PLACE })
    -- Not a companion (see the header): settings · close. The gear opens Drop Watcher's settings on
    -- Item Search's own page (settings/ItemSearchPage.lua).
    local hb = NS.WindowTitleBar.Marks(bar, { frame = f, close = function() ISW.Close() end,
        settings = function() NS.addon:OpenSettings("itemSearch") end, extras = {} })
    f.closeButton = hb.close
end

-- ── building: the left pane ─────────────────────────────────────────────────────────────────

local function fallbackBox(parent, w)
    local box = CreateFrame("EditBox", nil, parent, "InputBoxTemplate")
    box:SetSize(w, K.CONTROL_H)
    box:SetAutoFocus(false)
    box:SetScript("OnTextChanged", function(self) ISW.SetQuery(self:GetText()) end)
    box:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
    return box
end

local function buildSearch(f)
    local w = WIN.LEFT_W - 64
    local box = NS.MakeSearchBox(f, w, { hint = L["Item name or id"], onChange = function(t) ISW.SetQuery(t) end })
    box = box or fallbackBox(f, w)
    box:HookScript("OnEnterPressed", function() ISW.ShowFirst() end)
    box:SetPoint("TOPLEFT", f.titleBar, "BOTTOMLEFT", K.INSET, -8)
    f.searchBox = box
    f.clearButton = NS.Window.TextButton(f, 56, nil, L["Clear"], function() ISW.Clear() end)
    -- No mark: the label sits in the button's center (W6), not nudged past an empty mark slot.
    NS.Window.SetButtonMark(f.clearButton, L["Clear"], nil)
    f.clearButton:SetPoint("LEFT", box, "RIGHT", 6, 0)
    NS.Window.AttachTooltip(f.clearButton, function()
        return L["Clear"], TM().Row(L["Empties"], L["the search box and the matches"])
    end, "chrome")
end

local function matchSortRows()
    local rows = {}
    for _, key in ipairs(ISV.MATCH_SORTS) do
        rows[#rows + 1] = { value = key, label = ISV.MATCH_SORT_LABEL[key], radio = true,
            selected = function() return matchSort == key end,
            onClick = function() ISW.SortMatches(key) end }
    end
    return rows
end

local function buildLeft(f)
    f.matchHead = ISG.Header(f, {
        { key = "sort", icon = "ph:arrows-down-up", glyph = "=",
          onClick = function(self) NS.ContextMenu(self, matchSortRows()) end,
          tip = function()
              return L["Sort the matches"], TM().Row(L["Now"], ISV.MATCH_SORT_LABEL[matchSort]),
                  TM().Hint(L["Click: pick an order"])
          end },
    })
    f.matchHead:SetPoint("TOPLEFT", f.searchBox, "BOTTOMLEFT", 0, -8)
    f.matchHead:SetWidth(WIN.LEFT_W)
    f.matchScroll, f.matchContent = ISG.ScrollArea(f)
    f.matchScroll:SetPoint("TOPLEFT", f.matchHead, "BOTTOMLEFT", 0, -2)
    f.matchScroll:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", K.INSET, NS.FooterMetric("HEIGHT") + 4)
    f.matchScroll:SetWidth(WIN.LEFT_W - K.SCROLL_W)
    f.matchPool = NS.Pool.New()
    f.matchNote = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    f.matchNote:SetPoint("TOPLEFT", f.matchHead, "BOTTOMLEFT", 4, -6)
    f.matchNote:SetWidth(WIN.LEFT_W - 8)
    f.matchNote:SetJustifyH("LEFT")
    f.matchNote:SetWordWrap(true)
    NS.Skin.Font(f.matchNote)
    NS.Skin.Text(f.matchNote, "text.muted")
    VP().Build(f)
end

-- ── building: the right pane ────────────────────────────────────────────────────────────────

local function rightX() return WIN.LEFT_W + 2 * K.INSET end

-- The header's icon and name: the item's game tooltip on hover, a shift-click links it (W7).
local function linkable(b)
    b:SetScript("OnEnter", function(self) ISG.ItemTip(self, shownItem) end)
    b:SetScript("OnLeave", ISG.HideTip)
    b:SetScript("OnClick", function() if Compat.ShiftDown() then ISG.LinkItem(shownItem) end end)
end

local function smallText(f, layer, template, token)
    local fs = f:CreateFontString(nil, layer, template)
    fs:SetJustifyH("LEFT")
    NS.Skin.Font(fs)
    if token then NS.Skin.Text(fs, token) end
    return fs
end

local function buildHeader(f)
    f.icon = CreateFrame("Button", nil, f)
    f.icon:SetSize(WIN.ICON, WIN.ICON)
    f.icon:SetPoint("TOPLEFT", f.titleBar, "BOTTOMLEFT", rightX(), -8)
    f.icon.art = f.icon:CreateTexture(nil, "ARTWORK")
    f.icon.art:SetAllPoints(f.icon)
    linkable(f.icon)
    f.name = smallText(f, "OVERLAY", "GameFontNormal")
    f.name:SetPoint("TOPLEFT", f.icon, "TOPRIGHT", 8, -1)
    f.name:SetWordWrap(false)
    f.nameButton = CreateFrame("Button", nil, f)
    f.nameButton:SetAllPoints(f.name)
    linkable(f.nameButton)
    f.line = smallText(f, "OVERLAY", "GameFontHighlightSmall", "text.muted")
    f.line:SetPoint("TOPLEFT", f.name, "BOTTOMLEFT", 0, -3)
    f.linkHint = smallText(f, "OVERLAY", "GameFontHighlightSmall", "dw.idle")
    f.linkHint:SetPoint("TOPRIGHT", f.titleBar, "BOTTOMRIGHT", -K.INSET, -12)
    f.linkHint:SetText(L["Shift-click the name or icon to link it"])
    f.notice = smallText(f, "OVERLAY", "GameFontHighlightSmall", "text.muted")
    f.notice:SetPoint("TOPLEFT", f.icon, "BOTTOMLEFT", 0, -8)
    f.notice:SetPoint("RIGHT", f, "RIGHT", -K.INSET, 0)
    f.notice:SetWordWrap(true)
    -- An item ForeverDB (loaded) knows nothing about: this line under the header and no tab strip.
    f.noFacts = smallText(f, "OVERLAY", "GameFontHighlightSmall", "text.muted")
    f.noFacts:SetPoint("TOPLEFT", f.icon, "BOTTOMLEFT", 0, -8)
    f.noFacts:SetText(L["Nothing is known about this item: no drop, vendor, quest, recipe or skinning source."])
    f.noFacts:Hide()
    f.empty = smallText(f, "OVERLAY", "GameFontHighlight", "text.muted")
    f.empty:SetPoint("TOP", f.titleBar, "BOTTOM", WIN.LEFT_W / 2, -120)
    f.empty:SetText(L["Type an item's name or id on the left."])
end

-- One tab of the strip (the main window's look, modules/WindowTabs.lua's buildTab).
local function buildTab(strip, key)
    local tab = CreateFrame("Button", nil, strip)
    tab:SetHeight(K.TAB_H)
    tab.key = key
    tab.label = tab:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    tab.label:SetPoint("CENTER", tab, "CENTER", 0, 0)
    if NS.Skin.IsEnabled() then
        NS.Skin.Tab(tab, { text = tab.label, selected = false })
    else
        tab.underline = tab:CreateTexture(nil, "ARTWORK")
        NS.SkinPaint(tab.underline, function(t) t:SetColorTexture(NS.SkinColor("tab.onLine")) end)
        tab.underline:SetHeight(2)
        tab.underline:SetPoint("BOTTOMLEFT", tab, "BOTTOMLEFT", 8, 0)
        tab.underline:SetPoint("BOTTOMRIGHT", tab, "BOTTOMRIGHT", -8, 0)
    end
    tab:SetScript("OnClick", function() ISW.SelectTab(key) end)
    NS.Window.AttachTooltip(tab, function() return ISW.TabTip(key) end, "chrome")
    tab:Hide()
    return tab
end

local function filterRows(tab)
    local rows = {}
    for _, flt in ipairs(TABS.DEF[tab].filters) do
        rows[#rows + 1] = { value = flt.key, label = flt.label, keepOpen = true,
            selected = function() return stateOf(tab).filters[flt.key] == true end,
            onClick = function() ISW.SetFilter(tab, flt.key) end }
    end
    return rows
end

local function sortRows(tab)
    local rows = {}
    for _, ch in ipairs(TABS.SortChoices(tab)) do
        rows[#rows + 1] = { value = ch.key, label = ch.label, radio = true,
            selected = function() return stateOf(tab).sort.col == ch.key end,
            onClick = function()
                if stateOf(tab).sort.col ~= ch.key then ISW.SortBy(tab, ch.key) end
            end }
    end
    return rows
end

local function resetTip()
    return L["Reset"], TM().Row(L["Puts back"], L["Best for you, with no filters"]), TM().Hint(L["Click: reset this tab"])
end

local function buildSection(f)
    f.section = ISG.Header(f, {
        { key = "filter", icon = "ph:funnel", glyph = "Y", tip = function() return ISW.FilterTip(shownTab) end,
          onClick = function(self) if shownTab then NS.ContextMenu(self, filterRows(shownTab)) end end },
        { key = "sort", icon = "ph:arrows-down-up", glyph = "=", tip = function() return ISW.SortTip(shownTab) end,
          onClick = function(self) if shownTab then NS.ContextMenu(self, sortRows(shownTab)) end end },
        { key = "reset", icon = "reset", glyph = "x", tip = resetTip,
          onClick = function() if shownTab then ISW.ResetView(shownTab) end end },
    })
    f.grid = ISG.Table(f)
end

local function buildRight(f)
    buildHeader(f)
    f.tabStrip = CreateFrame("Frame", nil, f)
    f.tabStrip:SetPoint("TOPLEFT", f.titleBar, "BOTTOMLEFT", rightX(), -(WIN.ICON + 18))
    f.tabStrip:SetPoint("RIGHT", f, "RIGHT", -K.INSET, 0)
    f.tabStrip:SetHeight(K.TAB_H)
    f.tabs = {}
    for _, key in ipairs(TABS.ORDER) do f.tabs[key] = buildTab(f.tabStrip, key) end
    buildSection(f)
    f.section:SetPoint("TOPLEFT", f.tabStrip, "BOTTOMLEFT", 0, -4)
    f.section:SetPoint("RIGHT", f, "RIGHT", -K.INSET, 0)
    f.grid.frame:SetPoint("TOPLEFT", f.section, "BOTTOMLEFT", 0, -2)
    f.grid.frame:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -K.INSET, NS.FooterMetric("HEIGHT") + 4)
end

-- ── building: the footer, the grip, the frame ───────────────────────────────────────────────

local function buildFooter(f)
    f.foot = NS.MakeFooter(f, { inset = 1, grip = true }) or NS.BareFooter(f, {})
end

local function onResizeStop(f, w, h)
    f.dwSizing = false
    if type(w) == "number" and type(h) == "number" and w > 0 and h > 0 then
        geometry().size = { math.floor(w + 0.5), math.floor(h + 0.5) }
        f.dwW, f.dwH = w, h
    end
    savePoint()
    repaintView()
end

-- One step of a drag (R7-DW-01). The full repaint (sort, every row's text and font, Matches, the
-- verdict, the footer) ran on every OnSizeChanged, so each frame of the drag redrew the whole
-- table. Now a drag only moves things: the verdict panel fits the new height, and the table's
-- columns are laid across a new width for the rows in view. Mouse-up repaints in full.
local function sizeStep(f, w)
    if not f:IsShown() then return end
    local m = NS.WindowRows.Metrics()
    VP().Fit(f, m.height)
    local tw = math.max(1, w - rightX() - K.INSET - K.SCROLL_W)
    if f.grid and f.grid.dwW ~= tw then
        f.grid.dwW = tw
        ISG.Relayout(f.grid, tw, m.height)
    end
end

local function makeResizable(f)
    local grip = NS.MakeResizable(f, {
        minWidth = WIN.MIN_W, minHeight = WIN.MIN_H, owner = addonName,
        -- In the footer's bottom-right corner (LibKa0s Widgets' Footer, its `grip` corner).
        gripParent = f.foot,
        onResize = function(w, h)
            if type(w) == "number" and w > 0 then f.dwW = w end
            if type(h) == "number" and h > 0 then f.dwH = h end
            if f.dwSizing then return sizeStep(f, width()) end
            repaintView()
        end,
        -- The anchor is saved with the size: sizing from the corner moves the frame's anchor.
        onResizeStop = function(w, h) onResizeStop(f, w, h) end,
    })
    if grip and grip.HookScript then
        grip:HookScript("OnMouseDown", function(_, button)
            if button == nil or button == "LeftButton" then f.dwSizing = true end
        end)
    end
end

local function onHide()
    ISG.HideTip()
    NS.CloseMenu()
    if searchTimer then searchTimer:Cancel(); searchTimer = nil end
end

local function build()
    local f = CreateFrame("Frame", WIN.NAME, UIParent, "BackdropTemplate")
    f:SetFrameStrata(C.LAYERS.STRATA.WINDOW)
    f:SetToplevel(true)
    f:SetMovable(true)
    f:SetClampedToScreen(true)
    f:EnableMouse(true)
    f:Hide()
    frame = f
    applySize()
    applyPoint()
    buildTitle(f)
    buildSearch(f)
    buildLeft(f)
    buildRight(f)
    buildFooter(f)
    makeResizable(f)
    NS.ApplySkin(f)
    NS.Skin.Shell(f, { noTopBar = true })
    NS.Skin.Header(f, { bars = { f.titleBar } })
    if type(UISpecialFrames) == "table" then tinsert(UISpecialFrames, WIN.NAME) end
    f:SetScript("OnHide", onHide)
    return f
end

local function ensureFrame()
    return frame or build()
end

-- ── tooltips ────────────────────────────────────────────────────────────────────────────────

--- A tab's tooltip: its title, its rows, Crafting's count in your professions.
--- @param key string
--- @return string title, string... lines
function ISW.TabTip(key)
    local def = TABS.DEF[key]
    local t = frame and frame.tabs[key]
    local out = { def.title, TM().Row(L["Rows"], tostring(t and t.dwTotal or 0)) }
    if key == "crafting" and t and t.dwCount ~= t.dwTotal then
        out[#out + 1] = TM().Row(L["In your professions"], tostring(t.dwCount))
    end
    out[#out + 1] = TM().Hint(L["Click: show this tab"])
    return unpack(out)
end

--- The Filter mark's tooltip: what narrows the rows now.
--- @param tab string|nil
--- @return string title, string... lines
function ISW.FilterTip(tab)
    if not tab then return end
    local st, on = stateOf(tab), {}
    for _, flt in ipairs(TABS.DEF[tab].filters) do
        if (st.filters[flt.key] == true) == flt.narrows then
            on[#on + 1] = flt.narrows and flt.label or L["no %s"]:format(flt.label:lower())
        end
    end
    local now = #on > 0 and table.concat(on, ", ") or L["everything"]
    return L["Filter"], TM().Row(L["Showing"], now), TM().Hint(L["Click: choose what to show; not saved"])
end

--- The Sort mark's tooltip: the sort in force.
--- @param tab string|nil
--- @return string title, string... lines
function ISW.SortTip(tab)
    if not tab then return end
    return L["Sort"], TM().Row(L["Now"], TABS.SortLabel(tab, stateOf(tab).sort)),
        TM().Hint(L["Click: pick an order; a column's title sorts too"])
end

-- ── painting: the left pane ─────────────────────────────────────────────────────────────────

local function paintLeft(m)
    local f = frame
    local rows = ISV.SortMatches(matches.rows or {}, matchSort)
    local w = WIN.LEFT_W - K.SCROLL_W
    NS.Pool.ReleaseAll(f.matchPool)
    for i, r in ipairs(rows) do
        local row = NS.Pool.Acquire(f.matchPool, function()
            return ISG.MatchRow(f.matchContent, function(id) ISW.ShowItem(id) end)
        end)
        row:ClearAllPoints()
        row:SetPoint("TOPLEFT", f.matchContent, "TOPLEFT", 0, -(i - 1) * m.height)
        row:SetSize(w, m.height)
        ISG.PaintMatch(row, r, i, w, m.height, r.id == shownItem, m)
    end
    f.matchContent:SetSize(w, math.max(1, #rows * m.height))
    local note = ISV.NoteText(matches.note)
    f.matchNote:SetText(note or "")
    f.matchNote:SetShown(note ~= nil)
    ISG.PaintHeader(f.matchHead, { title = L["Matches"], count = #rows > 0 and tostring(#rows) or nil,
        note = #rows > 1 and ISV.MATCH_SORT_LABEL[matchSort] or nil,
        marks = { sort = { shown = #rows > 1 } } })
end

--- The match rows the list draws now, in order (for the tests).
--- @return table
function ISW.MatchRows()
    local out = {}
    for i, row in ipairs(frame and frame.matchPool.active or {}) do out[i] = row end
    return out
end

-- ── painting: the right pane ────────────────────────────────────────────────────────────────

local function itemHeader(facts)
    local f = frame
    local item = facts and facts.item or { id = shownItem }
    f.icon.art:SetTexture(item.icon or Compat.ItemIcon(item.id) or NS.Icon("gi:help"))
    f.name:SetText(item.name or L["Item %d"]:format(item.id))
    local qr, qg, qb = NS.QualityColor(item.quality)
    if qr == nil then qr, qg, qb = toneRGB("plain") end
    f.name:SetTextColor(qr, qg, qb)
    f.line:SetText(ISV.ItemLine(item, headerContext()))
end

local function tabLabel(t)
    if t.key == "crafting" and t.count ~= t.total then
        local r, g, b = NS.SkinColor("text.muted")
        return ("%s %d %s"):format(t.title, t.count, NS.GroupRoster.Colored(("/ %d"):format(t.total), r, g, b))
    end
    return ("%s %d"):format(t.title, t.count)
end

local function selectTab(tab, on)
    if tab.underline then
        NS.Skin.Text(tab.label, on and "accent" or "dw.idle")
        tab.underline:SetShown(on)
    else
        NS.Skin.SetTabSelection(tab, on)
    end
end

local function paintTabs(tabs, active)
    local f = frame
    for _, tab in pairs(f.tabs) do tab:Hide() end
    local x = 0
    for _, t in ipairs(tabs) do
        local tab = f.tabs[t.key]
        tab.dwCount, tab.dwTotal = t.count, t.total
        tab.label:SetText(tabLabel(t))
        local w = math.max(96, math.floor((tab.label:GetStringWidth() or 0) + 28))
        tab:SetWidth(w)
        tab:ClearAllPoints()
        tab:SetPoint("LEFT", f.tabStrip, "LEFT", x, 0)
        x = x + w + K.TAB_GAP
        selectTab(tab, t.key == active)
        tab:Show()
    end
end

local function chipOf(tab, st)
    if not TABS.DEF[tab].chip then return nil end
    local mine = st.filters.mine == true
    return {
        text = mine and L["My professions"] or L["All professions"],
        onClick = function() ISW.SetFilter(tab, "mine") end,
        tip = function()
            return mine and L["My professions"] or L["All professions"],
                TM().Row(L["Shows"], mine and L["recipes in the professions you know"] or L["every recipe that uses the item"]),
                TM().Hint(L["Click: switch; for this view only, not saved"])
        end,
    }
end

local function paintSection(tab, st, shown, total)
    local def = TABS.DEF[tab]
    ISG.PaintHeader(frame.section, {
        title = def.title, count = TABS.CountText(tab, shown, total),
        note = L["sorted: %s"]:format(TABS.SortLabel(tab, st.sort)),
        marks = { filter = { shown = #def.filters > 0, badge = TABS.Narrowed(tab, st) }, sort = { shown = true },
            reset = { shown = not TABS.IsDefault(tab, st, IS.ViewDefaults()) } },
        chip = chipOf(tab, st),
    })
end

local function tableOpts(tab, st, m, o)
    return {
        metrics = m, sort = st.sort, onSort = function(key) ISW.SortBy(tab, key) end,
        barColor = function() return barColor(o) end,
        canPin = function(spot) return o.pins and type(spot.map) == "number" and WP().Method() or nil end,
        questMark = questMark, onPin = function(spot, title) ISW.SetPin(spot, title) end,
        onOpen = function(id) ISW.ShowItem(id) end, empty = L["No rows match these filters."],
    }
end

local function showTabs(on)
    local f = frame
    f.tabStrip:SetShown(on)
    f.section:SetShown(on)
    f.grid.frame:SetShown(on)
end

local function paintTab(built, m)
    local f = frame
    local tabs = TABS.Tabs(built, stateOf("crafting").filters.mine == true)
    local key = TABS.Pick(tabs, ISW.PickedTab())
    shownTab = key
    showTabs(key ~= nil)
    f.noFacts:SetShown(key == nil and fdbState() == "loaded")
    if not key then return end
    paintTabs(tabs, key)
    local st = stateOf(key)
    local rows = TABS.View(key, built[key], st)
    paintSection(key, st, TABS.Count(rows), TABS.Count(built[key]))
    local w = width() - rightX() - K.INSET - K.SCROLL_W
    f.grid.dwW = math.max(1, w)
    ISG.PaintTable(f.grid, key, rows, math.max(1, w), tableOpts(key, st, m, ISW.Options()))
end

local function paintDetail(m, reuse)
    local f = frame
    local has = shownItem ~= nil
    for _, w in ipairs({ f.icon, f.name, f.nameButton, f.line, f.linkHint }) do w:SetShown(has) end
    f.empty:SetShown(not has)
    local notice = ISV.Notice(fdbState())
    f.notice:SetText(notice or "")
    f.notice:SetShown(notice ~= nil)
    if not has then
        shownTab = nil
        showTabs(false)
        f.noFacts:Hide()
        return
    end
    if not (reuse and lastBuild.item == shownItem and lastBuild.rows) then
        local facts = IS.Get(shownItem)
        lastBuild.item, lastBuild.facts = shownItem, facts
        lastBuild.rows = ISC.Build(facts, IS.Me(facts and facts.ranks), cellsContext())
    end
    itemHeader(lastBuild.facts)
    paintTab(lastBuild.rows, m)
end

local function paintFooter()
    local f = frame
    local st = NS.ForeverDB.Status()
    local meta = IS.State() == "loaded" and NS.ForeverDB.Meta() or nil
    local version = (meta and meta.version) or (type(st) == "table" and st.version) or nil
    local full = IS.State() == "loaded" and NS.ForeverDB.FullStatus() == "loaded"
    f.foot:SetLeft(ISV.FooterText(fdbState(), version, full))
    f.foot:SetRight("")
end

--- Repaint the whole window from the current state (a no-op while it is closed).
function ISW.Refresh()
    local reuse = viewOnly
    viewOnly = false
    if not (frame and frame:IsShown()) then return end
    local m = NS.WindowRows.Metrics()
    VP().Paint(frame, shownItem, m)
    paintLeft(m)
    paintDetail(m, reuse)
    paintFooter()
end

--- The table's rows on screen now (ISG rows: `dwTip`, `cells`), for the tests.
--- @return table
function ISW.TableRows()
    if not frame then return {} end
    return ISG.Rows(frame.grid)
end

-- ── the search ──────────────────────────────────────────────────────────────────────────────

local function runSearch()
    searchTimer = nil
    local db = loadedDB()
    local rows, note = ISV.Matches(query, { state = fdbState(), db = db, clientItem = Compat.ItemInfoByID,
        limit = WIN.MATCHES })
    matches = { rows = rows, note = note }
    local q = ISV.Classify(query)
    if q.kind == "id" and not (rows[1] and rows[1].name) then Compat.RequestItem(q.id) end
    ISW.Refresh()
end

--- The search box's text changed: run the search DEBOUNCE seconds after the last change.
--- @param t string|nil
function ISW.SetQuery(t)
    query = type(t) == "string" and t or ""
    if searchTimer then searchTimer:Cancel() end
    searchTimer = C_Timer.NewTimer(C.ITEM_SEARCH.DEBOUNCE, runSearch)
end

--- Run the pending search now (Enter, the slash verb).
function ISW.SearchNow()
    if searchTimer then searchTimer:Cancel() end
    runSearch()
end

--- Enter: run the search now and show its first match (in the Sort in force).
function ISW.ShowFirst()
    ISW.SearchNow()
    local first = ISV.SortMatches(matches.rows or {}, matchSort)[1]
    if first then ISW.ShowItem(first.id) end
end

--- Clear: empty the box and the matches.
function ISW.Clear()
    query = ""
    if searchTimer then searchTimer:Cancel(); searchTimer = nil end
    matches = {}
    if frame and frame.searchBox then frame.searchBox:SetText("") end
    ISW.Refresh()
end

--- The matches the list shows now: `{ rows, note }` (a copy of the rows, in the Sort in force).
--- @return table
function ISW.Matches()
    return { rows = ISV.SortMatches(matches.rows or {}, matchSort), note = matches.note }
end

--- Sort the matches (spec §5.2): "best", "name" or "id"; for the session.
--- @param mode string
function ISW.SortMatches(mode)
    matchSort = ISV.MATCH_SORT_LABEL[mode] and mode or "best"
    ISW.Refresh()
end

-- ── showing an item ─────────────────────────────────────────────────────────────────────────

-- An item the client has not cached and ForeverDB does not name reads again shortly.
local function retryUncached(id)
    local facts = IS.Get(id)
    if (facts and facts.item.name) or retries >= 4 then return end
    retries = retries + 1
    Compat.RequestItem(id)
    C_Timer.After(WIN.LOAD_RETRY, function()
        if shownItem == id then
            ISW.Refresh()
            retryUncached(id)
        end
    end)
end

--- Show `itemID` in the detail pane (opening the window).
--- @param itemID number
--- @return boolean shown
function ISW.ShowItem(itemID)
    itemID = tonumber(itemID)
    if not (itemID and itemID > 0) or not ISW.Available() then return false end
    shownItem, retries = itemID, 0
    if not ISW.IsShown() then ensureFrame():Show() end
    -- ForeverDB_Full may load now, the session's first open (round 3 spec §4.6, IS.WantFull: its
    -- setting, out of combat, never from the tooltip).
    IS.WantFull()
    ISW.Refresh()
    retryUncached(itemID)
    return true
end

--- The item the detail pane shows, or nil.
--- @return number|nil
function ISW.ShownItem() return shownItem end

--- A pin's click: set a waypoint at `spot` through NS.ItemSearchWaypoint (TomTom's, or Drop
--- Watcher's arrow; Item Search feedback spec §6), and say so in chat. Answers the method used, or nil.
--- @param spot table|nil { map, x, y }
--- @param title string|nil
--- @return string|nil
function ISW.SetPin(spot, title)
    if type(spot) ~= "table" or type(spot.map) ~= "number" then return nil end
    local zone = Compat.MapName(spot.map) or L["Map %d"]:format(spot.map)
    local how = WP().Set(spot, title, zone)
    if how then
        NS.Print(L["Waypoint set: %s (%s, %.1f, %.1f), shown by %s."]:format(tostring(title or ""), zone,
            spot.x * 100, spot.y * 100, WP().MethodLabel(how)))
    elseif WP().Method() == nil then
        NS.Print(L["No waypoint: TomTom is not loaded and Drop Watcher's arrow is not available."])
    else
        NS.Print(L["No waypoint: this map takes none here."])
    end
    return how
end

-- ── opening and closing ─────────────────────────────────────────────────────────────────────

--- Whether the window is on screen.
--- @return boolean
function ISW.IsShown()
    return frame ~= nil and frame:IsShown() == true
end

--- The window's frame (nil before its first open), for the tests and the key.
--- @return table|nil
function ISW.Frame() return frame end

--- Open the window: with `opts.itemID` that item shown, else empty with the search box focused.
--- Refused (false) on Retail or with the window switched off.
--- @param opts table|nil { itemID }
--- @return boolean
function ISW.Open(opts)
    if not ISW.Available() then return false end
    local f = ensureFrame()
    local id = opts and tonumber(opts.itemID)
    if id then return ISW.ShowItem(id) end
    f:Show()
    IS.WantFull()
    ISW.Refresh()
    if f.searchBox and f.searchBox.SetFocus then f.searchBox:SetFocus() end
    return true
end

--- Close the window.
function ISW.Close()
    if frame then frame:Hide() end
end

--- The main window's magnifier: open (search focused) or close.
--- @return boolean shown
function ISW.Toggle()
    if ISW.IsShown() then
        ISW.Close()
        return false
    end
    if not ISW.Available() then
        NS.Print(L["Item Search's window is switched off."])
        return false
    end
    return ISW.Open()
end

--- `/dw search [name|id]`: open the window, and with text search for it now (an id is shown at
--- once). Answers whether the window opened.
--- @param rest string|nil
--- @return boolean
function ISW.SlashSearch(rest)
    if not ISW.Available() then
        NS.Print(IS.Enabled() and L["Item Search's window is switched off."] or L["Item Search is WoW Forever's alone."])
        return false
    end
    local t = (tostring(rest or ""):gsub("^%s+", ""):gsub("%s+$", ""))
    if t == "" then return ISW.Open() end
    local q = ISV.Classify(t)
    if q.kind == "id" then return ISW.ShowItem(q.id) end
    ISW.Open()
    query = t
    if frame.searchBox then frame.searchBox:SetText(t) end
    ISW.SearchNow()
    return true
end

--- Settings moved (a window setting, a profile switch): put the frame at its saved size and point
--- and repaint an open window.
function ISW.ApplySettings()
    if frame then
        applySize()
        applyPoint()
    end
    ISW.Refresh()
end

-- A stand-down closes the window.
NS.STAND_DOWN[#NS.STAND_DOWN + 1] = function() ISW.Close() end
