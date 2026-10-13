local _, NS = ...
-- modules/Window.lua — the main window's shell (design spec §11.1, boards 01 and 06): frame, skin,
-- title bar (centered gold title, restriction badge, Scan group, minimize, close), the tab strip and
-- its lazily built panes, the filter bar's host, the footer's host, test mode's title text and banner,
-- minimize, resize, position, lock, scale, alpha and the show decision.
--
-- A non-secure standalone window (standalone-windows): built lazily on the first show, skinned
-- through LibKa0s-Core's ApplySkin, closed by Escape (UISpecialFrames) and by the shared close mark
-- (NS.MakeCloseButton). Title-bar marks come from the shared icon catalog (NS.Icon), each with a
-- plain character beneath it for a texture that does not load. The chrome follows Ka0s Loot
-- History's window: a 30px title bar, a 26px tab strip with a gold active label and underline, the
-- filter bar, the tab's body and the footer.
--
-- THE SPLIT. modules/WindowTitleBar.lua owns the title bar (its controls, the badge's words and
-- the window's flat and icon buttons), modules/WindowFilterBar.lua the filter bar (its controls,
-- each tab's filter state and the pure row predicates), modules/WindowFooter.lua the footer (its
-- pure composer and its reads), modules/CompactChrome.lua all of it in the compact layout. The tabs'
-- bodies (WindowGroup, WindowMine, WindowHistory) each call Window.RegisterTab(key, { build,
-- refresh }) and are built on the tab's first show; a tab with no body says what it will hold.
--
-- THE UI LISTENS. It repaints on the bus (RestrictionChanged, AskStateChanged, SituationChanged,
-- DropAdded, DropUpdated, TradeTimerExpiring), batched into one pass on the next frame however
-- many messages arrive; InspectDone repaints the footer alone; TradeTimerTick, its own footer
-- ticker and (while Group drops shows a countdown still running: WindowGroup.LiveCountdown) a
-- countdown ticker every K.COUNTDOWN_TICK second repaint only what shows a countdown: the Group
-- drops tab's Trade window cells (WindowGroup.TickCountdowns, feedback-5 spec §1), the My drops tab
-- and the Offer panel. It reads records
-- through the engine's read-only accessors and never calls an engine action. A button's action goes
-- through the host handler its slash verb shares (NS.ScanGroup, NS.SetQualityMode,
-- core/DropWatcher.lua).
--
-- THE SHOW DECISION is one ladder, read in UpdateVisibility, and nothing else shows the frame:
--   0. stood down (the latch, which the perf harness's suspend also holds) -> hidden
--   1. General visibility `never`, or the combat condition not met       -> hidden
--   2. the player opened it this session (turning test mode on opens it, and so does the first
--      interesting drop in a situation set to auto-open)                   -> shown
-- Test mode never pins the window open: Close, Toggle and Escape always win. Turning test mode on
-- opens a closed window and remembers that it did; turning it off closes the window again only
-- when test mode was what opened it.
-- Geometry is written here (by a drag, a resize, the minimize button and Reset position) and by
-- modules/WindowCompact.lua: each layout's point and size (its Geometry), and the shared minimized.

NS.Window = NS.Window or {}
local Window = NS.Window
local K      = NS.Constants.WINDOW
local C      = NS.Constants
local L      = NS.L
local Perf   = NS.Perf

local TAG = "UI"

-- The tabs, in strip order (design spec §11.1).
Window.TABS = { "group", "mine", "history" }
local TAB_SET = { group = true, mine = true, history = true }
local TAB_LABEL = { group = L["Group drops"], mine = L["My drops"], history = L["History"] }
local TAB_TIP = {
    group   = L["Every drop your group receives, one row each, grouped by boss or key run."],
    mine    = L["Your own drops, with the time left to trade them and who each would help."],
    history = L["Drops from earlier encounters, kept across sessions."],
}
-- What a tab with no body yet says, so the window is never blank.
local TAB_PLACEHOLDER = {
    group   = L["No drops yet. Loot your group receives appears here."],
    mine    = L["Your tradeable drops appear here, with who each would help."],
    history = L["Drops from earlier encounters appear here."],
}

local frame   -- built on the first show
local openedByTestMode = false   -- test mode, not the player, opened the window
local visibilityListeners = {}   -- fn(shown), told on every OnShow and OnHide of the frame
local tabSpecs = {}              -- [tab] = { build = fn(pane), refresh = fn(pane, ctx) }
local activeTab = "group"
local newCount = 0               -- drops added to the shown feed since the window was minimized
local restrictionReason          -- RestrictionChanged's last `reason` (nil: nothing restricted)
local restrictionSeen = false    -- a RestrictionChanged has arrived since the stand-up
local instanceSince              -- GetTime() of the last situation change: "This instance"
local footerTicker
local countdownTicker            -- each second while Group drops shows a running countdown
local repaintPending = false     -- a bus repaint is queued for the next frame
local repaintCountdown           -- the countdowns' own repaint (defined with the repaints below)
local syncCountdownTicker        -- starts or stops the countdown ticker (defined with it)

local function notifyVisibility(shown)
    for _, fn in ipairs(visibilityListeners) do fn(shown) end
end

local function profile()
    local db = NS.addon and NS.addon.db
    return db and db.profile
end

local function setting(key)
    local p = profile()
    if p == nil then return nil end
    return p[key]
end

local function geometry()
    local p = profile()
    if not p then return {} end
    if type(p.window) ~= "table" then p.window = {} end
    return p.window
end

local function isLocked() return setting("locked") == true end

-- `feed.showOwn` (design spec §6.3): your own drops listed in Group drops too. Off by default.
local function showOwn()
    local feed = setting("feed")
    return type(feed) == "table" and feed.showOwn == true
end
local function isMinimized() return geometry().minimized == true end
local function feedName() return NS.State.testMode == true and "test" or "live" end

--- The feed the window shows: `test` in test mode, else `live`.
--- @return string
function Window.FeedName() return feedName() end

--- What the window shows: its feed (`test` in test mode, else `live`) and whether Group drops lists
--- your own drops too (`feed.showOwn`). The simulator's report places its drops by it (SimReport).
--- @return table { feed, showOwn }
function Window.FeedView() return { feed = feedName(), showOwn = showOwn() } end

-- ── tooltips ────────────────────────────────────────────────────────────────────────────────

-- ABOVE THE CONTROL (feedback-3 spec §1, DW-B1). A filter-bar control's tooltip (the bar's
-- dropdowns, its search box and the footer's Sort) never covers the control or the menu it opens
-- below: its BOTTOMLEFT sits on the control's TOPRIGHT (ANCHOR_RIGHT's place), or, when the screen
-- has no room on the right, its BOTTOMRIGHT on the control's TOPLEFT (ANCHOR_LEFT's). Near the top
-- of the screen, with no room above, it goes below instead (its TOPLEFT on the control's BOTTOMRIGHT,
-- else its TOPRIGHT on the BOTTOMLEFT; feedback-3 spec §5, DW-B5), so the clamp never pushes it over
-- the dropdown. Placed by hand after Show, so the room is measured on the tooltip's real size, at
-- each frame's scale.

local function num(v) return type(v) == "number" and v or nil end

local function geom(f, method)
    local fn = f and f[method]
    return fn and num(fn(f)) or nil
end

local function scaleOf(f) return geom(f, "GetEffectiveScale") or 1 end

--- Which side above a control its tooltip goes, in screen pixels: `right` when the tooltip fits
--- between the control's right edge and the screen's, else `left`. Unknown geometry answers `right`.
--- @param controlRight number|nil
--- @param tipWidth number|nil
--- @param screenWidth number|nil
--- @return string
function Window.AboveSide(controlRight, tipWidth, screenWidth)
    controlRight, tipWidth, screenWidth = num(controlRight), num(tipWidth), num(screenWidth)
    if not (controlRight and tipWidth and screenWidth) then return "right" end
    return controlRight + tipWidth <= screenWidth and "right" or "left"
end

--- Whether a tooltip fits above a control, in screen pixels: the control's top plus the tooltip's
--- height within the screen's height (feedback-3 spec §5, DW-B5). Unknown geometry answers true.
--- @param controlTop number|nil
--- @param tipHeight number|nil
--- @param screenHeight number|nil
--- @return boolean
function Window.AboveFits(controlTop, tipHeight, screenHeight)
    controlTop, tipHeight, screenHeight = num(controlTop), num(tipHeight), num(screenHeight)
    if not (controlTop and tipHeight and screenHeight) then return true end
    return controlTop + tipHeight <= screenHeight
end

-- The tooltip's point and the control's, by side and by whether it fits above. Below (near the top
-- of the screen) its top corner sits on the control's bottom one, so the clamp never pushes it over
-- the dropdown.
local ABOVE_POINTS = {
    above = { right = { "BOTTOMLEFT", "TOPRIGHT" }, left = { "BOTTOMRIGHT", "TOPLEFT" } },
    below = { right = { "TOPLEFT", "BOTTOMRIGHT" }, left = { "TOPRIGHT", "BOTTOMLEFT" } },
}

-- A frame's measure in screen pixels, nil when unknown.
local function screenPx(f, method)
    local v = geom(f, method)
    return v and v * scaleOf(f) or nil
end

--- Place a shown tooltip above `widget`, at its top right, else its top left; below it (its bottom
--- right, else its bottom left) when the screen has no room above. Answers the side and `above` or
--- `below`.
--- @param tip table a GameTooltip, shown
--- @param widget table the hovered control
--- @return string side, string where
function Window.PlaceAbove(tip, widget)
    local side = Window.AboveSide(screenPx(widget, "GetRight"), (geom(tip, "GetWidth") or 0) * scaleOf(tip),
        screenPx(UIParent, "GetWidth"))
    local where = Window.AboveFits(screenPx(widget, "GetTop"), (geom(tip, "GetHeight") or 0) * scaleOf(tip),
        screenPx(UIParent, "GetHeight")) and "above" or "below"
    local pts = ABOVE_POINTS[where][side]
    tip:ClearAllPoints()
    tip:SetPoint(pts[1], widget, pts[2], 0, 0)
    return side, where
end

-- Each placement after Show: `above` (a filter-bar control, DW-B1) and `row` (a table row's cell,
-- button or header, DW-B2: modules/RowTooltip.lua, the row's top right like Loot History).
local PLACERS = {
    above = function(tip, w) Window.PlaceAbove(tip, w) end,
    row = function(tip, w) NS.RowTooltip.PlaceOrFallback(tip, w) end,
}

local function showTooltip(self)
    local lines = { self.tooltip() }
    if #lines == 0 or not GameTooltip then return end
    local placer = PLACERS[self.tipPlace]
    GameTooltip:SetOwner(self, placer and "ANCHOR_NONE" or "ANCHOR_BOTTOM")
    GameTooltip:SetText(lines[1], C.GOLD.r, C.GOLD.g, C.GOLD.b)
    for i = 2, #lines do GameTooltip:AddLine(lines[i], 1, 1, 1, true) end
    GameTooltip:Show()
    if placer then placer(GameTooltip, self) end
end

local function hideTooltip()
    if GameTooltip then GameTooltip:Hide() end
end

--- Give `widget` a tooltip: `fn()` answers the title, then each line. Read on every hover, so it is
--- never stale, and kept as `widget.tooltip` so a suite reads exactly what a hover would show.
--- Hooked rather than set, so a library widget keeps its own hover tint.
--- `place` is nil (below the widget, ANCHOR_BOTTOM), `above` (Window.PlaceAbove: a filter-bar
--- control, DW-B1) or `row` (NS.RowTooltip: a table row's cell, button or header, DW-B2).
--- @param widget table
--- @param fn function
--- @param place string|nil
function Window.AttachTooltip(widget, fn, place)
    widget.tooltip = fn
    widget.tipPlace = place
    if widget.EnableMouse then widget:EnableMouse(true) end
    widget:HookScript("OnEnter", showTooltip)
    widget:HookScript("OnLeave", hideTooltip)
end

--- What a hover over `widget` shows, as a list (title first), or an empty list.
--- @param widget table|nil
--- @return table
function Window.TooltipOf(widget)
    if not (widget and widget.tooltip) then return {} end
    return { widget.tooltip() }
end

-- ── pure labels ─────────────────────────────────────────────────────────────────────────────

--- The restriction badge's text (modules/WindowTitleBar.lua's BadgeText).
--- @param reason string|nil RestrictionChanged's reason
--- @param queued number|nil
--- @return string|nil
function Window.BadgeText(reason, queued)
    return NS.WindowTitleBar.BadgeText(reason, queued)
end

--- A tab's label: `My drops · 2` counts the drops of yours the tab lists (the feed on show, less
--- the ones its own filters hide), so it reconciles with what it lists, the
--- simulator's loot step and the Group drops headers (feedback-3 spec §0 and §5).
--- @param key string
--- @param mine number|nil
--- @return string
function Window.TabLabel(key, mine)
    local n = tonumber(mine) or 0
    if key == "mine" and n > 0 then return L["My drops · %d"]:format(n) end
    return TAB_LABEL[key] or tostring(key)
end

-- ── reads ───────────────────────────────────────────────────────────────────────────────────

-- A tab's tooltip: My drops says how many of the drops it lists you can still trade, then names
-- your drops it leaves out (hidden by its filters; feedback-3 spec §5).
local function tabTip(key)
    if key ~= "mine" then return TAB_LABEL[key], TAB_TIP[key] end
    local t = NS.WindowMine.TabTally()
    local out = { Window.TabLabel(key, t.listed), TAB_TIP[key] }
    if t.listed > 0 then
        out[3] = t.tradeable > 0 and L["%d of them you can still trade."]:format(t.tradeable)
            or L["None of them can be traded now."]
    end
    for _, line in ipairs(NS.WindowMine.ExcludedLines(t.excluded, t.filter)) do out[#out + 1] = line end
    return unpack(out)
end

--- RestrictionChanged's last reason; before the first one, the tracker's own answer. Nil while
--- nothing is restricted. The title bar's badge reads it.
--- @return string|nil
function Window.RestrictionReason()
    if restrictionSeen then return restrictionReason end
    return NS.Restrictions and NS.Restrictions.ActiveReason() or nil
end

-- ── geometry ────────────────────────────────────────────────────────────────────────────────

local function savePoint()
    local point, _, relativePoint, x, y = frame:GetPoint(1)
    if point then NS.WindowCompact.Geometry(nil, true).point = { point, relativePoint, x, y } end
end

local function saveSize(width, height)
    local g = NS.WindowCompact.Geometry(nil, true)
    g.width, g.height = width, height
end

local function applyPoint()
    local pt = NS.WindowCompact.Point()
    frame:ClearAllPoints()
    frame:SetPoint(pt[1], UIParent, pt[2], pt[3] or 0, pt[4] or 0)
end

-- Minimize and expand grow and shrink the window from its top edge, so the title bar stays where
-- it is whatever point it was saved at (CENTER by default): the anchor moves to the top-left corner
-- first. GetLeft/GetTop answer in the frame's own coordinates, the ones UIParent's BOTTOMLEFT offsets
-- take, so no scale adjustment is needed.
local function anchorTopLeft()
    local left, top = frame:GetLeft(), frame:GetTop()
    if type(left) ~= "number" or type(top) ~= "number" then return end
    frame:ClearAllPoints()
    frame:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", left, top)
    savePoint()
end

-- The layout's bounds and size (modules/WindowCompact.lua). Minimized, the window is its title bar
-- alone; the stored height is kept for the expand.
local function applySize()
    local width, height = NS.WindowCompact.Fit(frame)
    frame:SetSize(width, isMinimized() and (K.TITLE_H + 2) or height)
end

local function applyLook()
    frame:SetScale(setting("scale") or 1)
    frame:SetAlpha(setting("alpha") or 1)
end

-- ── the footer ticker ───────────────────────────────────────────────────────────────────────

local function repaintFooter()
    if frame and frame:IsShown() and not isMinimized() and NS.WindowFooter then NS.WindowFooter.Refresh() end
end

-- The footer ticker: the footer's ages, and the countdowns while one is on screen.
local function tick()
    repaintFooter()
    repaintCountdown()
end

local function stopTicker()
    if footerTicker then footerTicker:Cancel() end
    if countdownTicker then countdownTicker:Cancel() end
    footerTicker, countdownTicker = nil, nil
end

-- "Last loot 12s ago" ages while nothing else happens: one slow ticker, alive only while the whole
-- window is on screen.
local function startTicker()
    if footerTicker or isMinimized() or not (frame and frame:IsShown()) then return end
    footerTicker = C_Timer.NewTicker(K.FOOTER_TICK, tick)
end

-- ── construction: the title bar's drag (the bar is modules/WindowTitleBar.lua) ────────────────

local function onDragStart()
    if isLocked() then return end
    frame:StartMoving()
end

local function onDragStop()
    frame:StopMovingOrSizing()
    savePoint()
end

--- A flat button in the window's look (the Scan group button's, and each Group drops row's Ask):
--- the skin's fill and inner line, a catalog mark at the left (`icon` may be nil) and a centered
--- label (`b.label`, `b.art`). `onClick(b)` runs on a click. Built by modules/WindowTitleBar.lua.
--- @return table
function Window.TextButton(parent, width, icon, text, onClick)
    return NS.WindowTitleBar.TextButton(parent, width, icon, text, onClick)
end

-- ── construction: the tabs and the body ─────────────────────────────────────────────────────

local function buildTab(strip, key, i)
    local tab = CreateFrame("Button", nil, strip)
    tab:SetSize(K.TAB_W, K.TAB_H)
    tab:SetPoint("LEFT", strip, "LEFT", (i - 1) * (K.TAB_W + K.TAB_GAP), 0)
    tab.label = tab:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    tab.label:SetPoint("CENTER", tab, "CENTER", 0, 0)
    tab.label:SetText(TAB_LABEL[key])
    tab.underline = tab:CreateTexture(nil, "ARTWORK")
    tab.underline:SetColorTexture(C.GOLD.r, C.GOLD.g, C.GOLD.b, 1)
    tab.underline:SetHeight(2)
    tab.underline:SetPoint("BOTTOMLEFT", tab, "BOTTOMLEFT", 8, 0)
    tab.underline:SetPoint("BOTTOMRIGHT", tab, "BOTTOMRIGHT", -8, 0)
    tab:SetScript("OnClick", function() Window.SelectTab(key) end)
    Window.AttachTooltip(tab, function() return tabTip(key) end)
    return tab
end

local function buildTabs(f, body)
    local strip = CreateFrame("Frame", nil, body)
    strip:SetPoint("TOPLEFT", body, "TOPLEFT", K.INSET, -2)
    strip:SetPoint("TOPRIGHT", body, "TOPRIGHT", -K.INSET, -2)
    strip:SetHeight(K.TAB_H)
    f.tabStrip, f.tabs = strip, {}
    for i, key in ipairs(Window.TABS) do f.tabs[key] = buildTab(strip, key, i) end
end

local function buildPanes(f, body)
    f.panes = {}
    for _, key in ipairs(Window.TABS) do
        local pane = CreateFrame("Frame", nil, body)
        pane.placeholder = pane:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        pane.placeholder:SetPoint("CENTER", pane, "CENTER", 0, 0)
        pane.placeholder:SetText(TAB_PLACEHOLDER[key])
        pane:Hide()
        f.panes[key] = pane
    end
end

-- The test-mode banner (board 06 E), between the filter bar and the tab's body.
local function buildBanner(f, body)
    local b = CreateFrame("Frame", nil, body)
    b:SetPoint("TOPLEFT", f.filterHost, "BOTTOMLEFT", 0, -2)
    b:SetPoint("TOPRIGHT", f.filterHost, "BOTTOMRIGHT", 0, -2)
    b:SetHeight(K.BANNER_H - 4)
    b.fill = b:CreateTexture(nil, "BACKGROUND")
    b.fill:SetAllPoints(b)
    b.fill:SetColorTexture(C.TONE.warn.r, C.TONE.warn.g, C.TONE.warn.b, 0.12)
    b.art = b:CreateTexture(nil, "ARTWORK")
    b.art:SetSize(12, 12)
    b.art:SetPoint("LEFT", b, "LEFT", 6, 0)
    b.art:SetTexture(NS.Icon("info"))
    b.text = b:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    b.text:SetPoint("LEFT", b.art, "RIGHT", 6, 0)
    b.text:SetText(L["TEST MODE: sample drops of real items in every state. Nothing is whispered. Combat ends it."])
    Window.AttachTooltip(b, NS.WindowTitleBar.TestTip)
    b:Hide()
    f.banner = b
end

local function buildBody(f)
    local body = CreateFrame("Frame", nil, f)
    body:SetPoint("TOPLEFT", f.divider, "BOTTOMLEFT", 0, 0)
    body:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -1, 1)
    f.body = body
    buildTabs(f, body)

    f.filterHost = CreateFrame("Frame", nil, body)
    f.filterHost:SetPoint("TOPLEFT", body, "TOPLEFT", K.INSET, -(K.TAB_H + 4))
    f.filterHost:SetPoint("TOPRIGHT", body, "TOPRIGHT", -K.INSET, -(K.TAB_H + 4))
    f.filterHost:SetHeight(K.FILTER_H)

    buildBanner(f, body)

    f.footerHost = CreateFrame("Frame", nil, body)
    f.footerHost:SetPoint("BOTTOMLEFT", body, "BOTTOMLEFT", K.INSET, 0)
    f.footerHost:SetPoint("BOTTOMRIGHT", body, "BOTTOMRIGHT", -K.INSET, 0)
    f.footerHost:SetHeight(K.FOOTER_H)

    buildPanes(f, body)
    NS.WindowFilterBar.Build(f.filterHost)
    NS.WindowFooter.Build(f.footerHost)
end

-- The panes fill between the filter bar (and the banner, in test mode) and the footer.
local function layoutPanes()
    local top = K.TAB_H + 4 + K.FILTER_H + (NS.State.testMode == true and NS.CompactChrome.BannerH() or 0)
    for _, pane in pairs(frame.panes) do
        pane:ClearAllPoints()
        pane:SetPoint("TOPLEFT", frame.body, "TOPLEFT", K.INSET, -top)
        pane:SetPoint("BOTTOMRIGHT", frame.body, "BOTTOMRIGHT", -K.INSET, K.FOOTER_H)
    end
end

local function makeResizable(f)
    local minW, minH, maxW, maxH = NS.WindowCompact.Bounds(NS.WindowCompact.Mode())
    NS.MakeResizable(f, {
        minWidth = minW, minHeight = minH, maxWidth = maxW, maxHeight = maxH,
        canResize    = function() return not isLocked() and not isMinimized() end,
        -- The anchor is saved with the size: sizing from the corner moves the frame's anchor, and a
        -- later ApplySettings re-anchors the stored size at the stored point.
        onResizeStop = function(width, height)
            saveSize(width, height)
            savePoint()
            NS.WindowFilterBar.Layout(width)
            -- The table's columns take the new width.
            Window.Refresh()
        end,
    })
end

-- A parent's hide (Alt-Z, a cinematic, the full-screen map) also runs OnHide, but leaves the frame's
-- own shown flag set, and the window returns with UIParent: only a hide of the frame itself (Escape,
-- the close mark, the ladder) is the player closing it.
local function onHide(self)
    if not self:IsShown() then NS.State.windowOpen = false end
    stopTicker()
    -- The dropdowns' popup is a process-wide singleton: hiding the window does not reach it.
    NS.CloseMenu()
    hideTooltip()
    notifyVisibility(false)
end

local function onShow()
    startTicker()
    syncCountdownTicker()
    notifyVisibility(true)
end

local function build()
    local f = CreateFrame("Frame", K.NAME, UIParent, "BackdropTemplate")
    f:SetFrameStrata("MEDIUM")
    f:SetMovable(true)
    f:SetClampedToScreen(true)
    f:EnableMouse(true)
    f:Hide()
    frame = f
    applySize()
    applyPoint()
    applyLook()
    NS.WindowTitleBar.Build(f, { onDragStart = onDragStart, onDragStop = onDragStop })
    buildBody(f)
    NS.ApplySkin(f)
    makeResizable(f)
    NS.WindowFilterBar.Layout(f:GetWidth())
    -- Escape closes it (standalone-windows); the frame is named, so the name is what the list holds.
    if type(UISpecialFrames) == "table" then tinsert(UISpecialFrames, K.NAME) end
    -- Hidden by Escape or the client's own close path: the player closed it.
    f:SetScript("OnHide", onHide)
    f:SetScript("OnShow", onShow)
    Window.SelectTab(activeTab)
    return f
end

local function ensureFrame()
    return frame or build()
end

-- ── repainting ──────────────────────────────────────────────────────────────────────────────

local function buildPane(key)
    local pane, spec = frame.panes[key], tabSpecs[key]
    if spec and not pane.built then
        pane.built = true
        spec.build(pane)
    end
end

--- The view a tab's body draws: its feed, its filter state, the controls it honors and the row
--- predicate and order that apply them (modules/WindowFilterBar.lua).
--- @param tab string|nil the active tab when nil
--- `belongs` says whether a drop is the tab's at all (Group drops: your own only with `feed.showOwn`),
--- `hiddenBy` which control hides one that is (FB.HiddenBy), so a header counts every drop.
--- @return table { tab, feed, filter, honors, ctx, matches = fn(drop), belongs = fn(drop),
---   hiddenBy = fn(drop), compare = fn(a, b) }
function Window.TabContext(tab)
    tab = tab or activeTab
    local FB = NS.WindowFilterBar
    local st, honors = FB.State(tab), FB.HONORS[tab]
    local feed = feedName()
    -- The placeholders ignore the situation, so This instance does not cut them (spec §11.6). The
    -- Character dropdown reads your recorder key (modules/CharFilter.lua).
    local ctx = { instanceSince = feed ~= "test" and instanceSince or nil, current = NS.CharFilter.CurrentKey() }
    -- Group drops lists your own loot only with `feed.showOwn` on; it goes to My drops, and a header
    -- counts only the ones My drops lists (`onMine`, feedback-3 spec §5).
    local own = tab ~= "group" or showOwn()
    return {
        tab = tab, feed = feed, filter = st, honors = honors, ctx = ctx,
        onMine = tab == "group" and not own and NS.WindowMine.ListsNow or nil,
        matches = function(drop) return FB.InGroup(drop, own) and FB.Matches(drop, st, ctx, honors) end,
        belongs = function(drop) return FB.InGroup(drop, own) end,
        hiddenBy = function(drop) return FB.HiddenBy(drop, st, ctx, honors) end,
        compare = FB.Comparator(st.sort),
    }
end

local function refreshActive()
    -- A tab with no body shows its placeholder; a body shows it itself, as its empty state, from
    -- its refresh below.
    for key, p in pairs(frame.panes) do
        p.placeholder:SetShown(tabSpecs[key] == nil)
    end
    local spec = tabSpecs[activeTab]
    if spec and spec.refresh then spec.refresh(frame.panes[activeTab], Window.TabContext(activeTab)) end
end

local function paintTabs()
    local mine = NS.WindowMine.ListedCount()
    for key, tab in pairs(frame.tabs) do
        local active = key == activeTab
        local c = active and C.GOLD or C.IDLE
        tab.label:SetText(NS.CompactChrome.TabText(key, mine))
        tab.label:SetTextColor(c.r, c.g, c.b)
        tab.underline:SetShown(active)
    end
end

local function paintMinimized()
    local m = isMinimized()
    frame.body:SetShown(not m)
    if frame.resizeGrip then frame.resizeGrip:SetShown(not m) end
    NS.WindowTitleBar.PaintMinimized(frame, m, newCount)
end

--- One repaint pass: the title bar's badge and counter, the tabs, and (expanded) the banner, the
--- filter bar, the footer and the active tab's body.
function Window.Refresh()
    if not frame then return end
    local t0 = Perf.on and debugprofilestop()
    local TB = NS.WindowTitleBar
    TB.PaintBadge(frame)
    TB.PaintModeText(frame)
    NS.CompactChrome.Paint(frame)   -- the compact layout's chrome (compact spec §4)
    paintMinimized()
    if not isMinimized() then
        frame.banner:SetShown(NS.State.testMode == true)
        layoutPanes()
        paintTabs()
        NS.WindowFilterBar.Sync(activeTab)
        NS.WindowFooter.Refresh()
        refreshActive()
        -- The Offer panel docks beside the window and repaints with it (modules/OfferPanel.lua).
        if NS.OfferPanel then NS.OfferPanel.Refresh() end
    end
    syncCountdownTicker()
    if t0 then Perf.Note("window.refresh", debugprofilestop() - t0) end
end

local function repaint()
    if frame and frame:IsShown() then Window.Refresh() end
end

local function flushRepaint()
    repaintPending = false
    repaint()
end

-- A bus message marks the window for one repaint on the next frame, so a burst (test mode's
-- placeholders, a Scan group's DropUpdated per drop, a run of ask states) costs one pass, not one
-- per message. A player's own click still repaints at once (repaint).
local function scheduleRepaint()
    if repaintPending or not (frame and frame:IsShown()) then return end
    repaintPending = true
    C_Timer.After(0, flushRepaint)
end

--- Mark the shown window for one repaint on the next frame, shared with the window's own bus
--- messages so a burst costs one pass (the History tab's HistoryChanged comes through here).
Window.ScheduleRepaint = scheduleRepaint

-- A countdown moved (TradeTimerTick, the footer ticker, the countdown ticker): only what shows one
-- repaints, Group drops' Trade window cells or the My drops tab while it is the active tab and the
-- Offer panel while it is open; the rest of the table, the filter bar and the footer are left alone.
-- The countdown ticker runs while the shown, expanded window's Group drops tab has a countdown
-- still running (WindowGroup.LiveCountdown), and stops with the last one.
syncCountdownTicker = function()
    local want = frame and frame:IsShown() and not isMinimized() and activeTab == "group"
        and NS.WindowGroup.LiveCountdown()
    if want and not countdownTicker then
        countdownTicker = C_Timer.NewTicker(K.COUNTDOWN_TICK, function() repaintCountdown() end)
    elseif not want and countdownTicker then
        countdownTicker:Cancel()
        countdownTicker = nil
    end
end

repaintCountdown = function()
    if not (frame and frame:IsShown()) or isMinimized() then return syncCountdownTicker() end
    if activeTab == "group" then NS.WindowGroup.TickCountdowns() end
    if activeTab == "mine" then refreshActive() end
    if NS.OfferPanel and NS.OfferPanel.IsShown() then NS.OfferPanel.Refresh() end
    syncCountdownTicker()
end

-- ── tabs ────────────────────────────────────────────────────────────────────────────────────

--- Show one tab: its pane is built on its first show, and the filter bar takes its state.
--- @param key string `group`, `mine` or `history`
--- @return boolean changed false for an unknown tab
function Window.SelectTab(key)
    if not TAB_SET[key] then return false end
    activeTab = key
    if not frame then return true end
    for k, pane in pairs(frame.panes) do pane:SetShown(k == key) end
    buildPane(key)
    NS.Debug(TAG, "tab -> %s", key)
    Window.Refresh()
    return true
end

--- @return string
function Window.ActiveTab() return activeTab end

--- A feature item's body for one tab (WindowGroup, WindowMine, WindowHistory): `spec.build(pane)`
--- runs on the tab's first show, `spec.refresh(pane, Window.TabContext(tab))` on every repaint
--- while it is the active tab.
--- @param key string
--- @param spec table { build = fn, refresh = fn }
function Window.RegisterTab(key, spec)
    assert(TAB_SET[key], "unknown tab " .. tostring(key))
    tabSpecs[key] = spec
    if not frame then return end
    frame.panes[key].built = nil
    if key == activeTab then
        buildPane(key)
        repaint()
    end
end

--- A filter control changed on `tab` (modules/WindowFilterBar.lua): the active tab redraws.
--- @param tab string
function Window.OnFilterChanged(tab)
    if tab == activeTab then repaint() end
end

-- ── minimize ────────────────────────────────────────────────────────────────────────────────

--- Collapse the window to its title bar, or expand it again. Kept in the profile; the position and
--- the expanded size are untouched. Minimizing starts the `n new` counter at zero.
--- @param on boolean
function Window.SetMinimized(on)
    on = on and true or false
    if on == isMinimized() then return end
    geometry().minimized = on or nil
    newCount = 0
    NS.Debug(TAG, "window %s", on and "minimized" or "expanded")
    if not frame then return end
    NS.CloseMenu()
    -- The Offer panel and the Edit message box hang off the window, not its body: they close with
    -- the body rather than float beside a title bar.
    if on and NS.OfferPanel then NS.OfferPanel.Close() end
    if on and NS.DetailCard then NS.DetailCard.CloseEditor() end
    anchorTopLeft()
    applySize()
    if on then stopTicker() else startTicker() end
    Window.Refresh()
end

function Window.ToggleMinimized() Window.SetMinimized(not isMinimized()) end

--- @return boolean
function Window.IsMinimized() return isMinimized() end

--- The interesting drops counted since the window was minimized.
--- @return number
function Window.NewCount() return newCount end

-- ── the show decision ───────────────────────────────────────────────────────────────────────

-- `inCombat` is the combat edge when a PLAYER_REGEN handler runs the decision
-- (events-frames-taint-§2); off an edge it is nil and the player's flag is read.
local function combatAllows(inCombat)
    local v = setting("visibility") or "always"
    if v == "never" then return false end
    if v == "always" then return true end
    if inCombat == nil then inCombat = NS.Compat.PlayerInCombat() end
    if v == "inCombat" then return inCombat end
    return not inCombat
end

--- Whether the window should be on screen now, by the ladder above.
--- @param inCombat boolean|nil the combat edge, when a PLAYER_REGEN handler asks
--- @return boolean
function Window.ShouldShow(inCombat)
    if NS.IsStoodDown() then return false end
    if not combatAllows(inCombat) then return false end
    return NS.State.windowOpen == true
end

--- Apply the show decision. Builds the frame only when it is about to be shown.
--- @param inCombat boolean|nil the combat edge, when a PLAYER_REGEN handler asks
function Window.UpdateVisibility(inCombat)
    local want = Window.ShouldShow(inCombat)
    if want then
        ensureFrame()
        Window.Refresh()
        frame:Show()
        startTicker()   -- OnShow starts it too; both are idempotent
        syncCountdownTicker()
    elseif frame and frame:IsShown() then
        -- Hidden by the ladder, not by the player: keep the player's choice for the next show.
        local open = NS.State.windowOpen
        frame:Hide()
        stopTicker()
        NS.State.windowOpen = open
    end
end

-- ── the player's own actions ────────────────────────────────────────────────────────────────

function Window.Open()
    NS.State.windowOpen = true
    openedByTestMode = false
    Window.UpdateVisibility()
end

function Window.Close()
    NS.State.windowOpen = false
    openedByTestMode = false
    Window.UpdateVisibility()
end

function Window.Toggle()
    if Window.IsShown() then Window.Close() else Window.Open() end
end

--- Be told `fn(shown)` whenever the frame is shown or hidden, by any path (the ladder, Escape, the
--- close mark). The window calls no engine module; an engine module that paces itself by the
--- window (the trade timer's ticker) registers here instead. Listeners are never removed: each
--- checks the stand-down latch itself.
--- @param fn function
function Window.AddVisibilityListener(fn)
    visibilityListeners[#visibilityListeners + 1] = fn
end

--- @return boolean
function Window.IsShown()
    return frame ~= nil and frame:IsShown() == true
end

--- Test mode turned on or off (core/DropWatcher.lua NS.SetTestMode). On opens a closed window;
--- off closes it again only when test mode was what opened it.
--- @param on boolean
function Window.OnTestModeChanged(on)
    if on and NS.State.windowOpen ~= true then
        NS.State.windowOpen = true
        openedByTestMode = true
    elseif not on and openedByTestMode then
        NS.State.windowOpen = false
        openedByTestMode = false
    end
    Window.UpdateVisibility()
    Window.Refresh()
end

--- Scale, alpha, the layout's geometry and the minimized state, with no show decision (WC.Apply).
function Window.ApplyLayout()
    if frame then applyLook(); applySize(); applyPoint() end
end

--- Window.ApplyLayout, then the show decision. Run at stand-up, on a profile change and by the
--- Master controls rows' reactions.
function Window.ApplySettings()
    Window.ApplyLayout()
    Window.UpdateVisibility()
end

--- Reset position: forget both layouts' stored point and size, and put the window back where it
--- started; the toast's and the simulation panel's saved positions go too (modules/Toast.lua,
--- modules/SimPanel.lua).
function Window.ResetPosition()
    NS.WindowCompact.ResetGeometry()
    if frame then
        applySize()
        applyPoint()
    end
    if NS.Toast then NS.Toast.ResetPosition() end
    if NS.SimPanel then NS.SimPanel.ResetPosition() end
    NS.Print(L["window position reset"])
end

--- The built frame, or nil before the first show. For the suites and the diagnostics report.
function Window.Frame() return frame end

-- ── the bus ─────────────────────────────────────────────────────────────────────────────────

-- Whether a drop belongs to the feed the window shows: test mode's placeholders while it is on,
-- the live feed's drops (the simulator's included) otherwise.
local function inShownFeed(rec)
    return (rec.test == true) == (NS.State.testMode == true)
end

-- AUTO-OPEN (feedback spec §3, FB-12). Every drop added to the shown feed opens a hidden window: it
-- passed the feed's gates (its situation tracked, the minimum quality), whoever looted it, your own
-- included. There is no once-per-situation latch: a window the player closes opens again on the
-- next drop. Master `autoOpen` false, or the situation's own `autoOpen` false, turns it off. A
-- minimized window stays minimized and counts the drop (`n new`). The frame is not protected
-- (no secure template, no protected child), so opening it in combat is allowed and taints nothing.
-- A test drop's open is test mode's (openedByTestMode), so turning test mode off closes it again:
-- NS.SetTestMode fills the feed before Window.OnTestModeChanged, so the drops can open it first.
local function maybeAutoOpen(rec)
    if NS.State.windowOpen == true or setting("autoOpen") == false then return end
    local Sit = NS.Situations
    local key = Sit.Current()
    if not Sit.ShouldAutoOpen(key) then return end
    NS.Debug(TAG, "auto-open: drop %s added in %s", tostring(rec.id), tostring(key))
    NS.WindowCompact.OnAutoOpen(key)   -- compact during a run (`window.compactInRuns`)
    Window.Open()
    openedByTestMode = rec.test == true
end

local function onDropAdded(id)
    local rec = NS.LootFeed.Get(id)
    if not rec then return end
    if not inShownFeed(rec) then
        scheduleRepaint()
        return
    end
    maybeAutoOpen(rec)
    if isMinimized() then newCount = newCount + 1 end
    scheduleRepaint()
end

local function onRestriction(reason)
    restrictionSeen, restrictionReason = true, reason
    scheduleRepaint()
end

local function onSituation()
    instanceSince = GetTime()
    scheduleRepaint()
end

-- Tracked, so the stand-down takes them down and the stand-up replays them. Without the bus
-- library it is a bare target, unregistered here instead (NS.Bus.tracked says which).
local target = NS.Bus:NewTarget()

local function listen()
    if not target then return end
    local M = NS.MSG
    target:RegisterMessage(M.RESTRICTION_CHANGED, function(_, reason) onRestriction(reason) end)
    -- The badge's queued count, and the Ask buttons of the active tab's rows.
    target:RegisterMessage(M.ASK_STATE_CHANGED, function()
        if frame then NS.WindowTitleBar.PaintBadge(frame) end
        scheduleRepaint()
    end)
    target:RegisterMessage(M.SITUATION_CHANGED, function() onSituation() end)
    target:RegisterMessage(M.DROP_ADDED, function(_, id) onDropAdded(id) end)
    target:RegisterMessage(M.DROP_UPDATED, function() scheduleRepaint() end)
    -- The My eq column reads your gear snapshot: a new one repaints it (feedback spec §3, FB-6).
    target:RegisterMessage(M.GEAR_CHANGED, function() scheduleRepaint() end)
    target:RegisterMessage(M.INSPECT_DONE, function() repaintFooter() end)
    -- The My drops tab's and the Offer panel's countdowns (modules/TradeTimer.lua).
    target:RegisterMessage(M.TRADE_TIMER_TICK, function() repaintCountdown() end)
    -- A drop nearing its end changes the tab's count and the rows' tones: one whole pass.
    target:RegisterMessage(M.TRADE_TIMER_EXPIRING, function() scheduleRepaint() end)
end
listen()

NS.STAND_DOWN[#NS.STAND_DOWN + 1] = function()
    stopTicker()
    repaintPending = false
    restrictionSeen, restrictionReason = false, nil
    if target and not NS.Bus.tracked then target:UnregisterAllMessages() end
end
NS.STAND_UP[#NS.STAND_UP + 1] = function()
    if not NS.Bus.tracked then listen() end
end
