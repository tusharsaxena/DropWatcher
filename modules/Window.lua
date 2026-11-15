local addonName, NS = ...
-- modules/Window.lua — the main window's shell (design spec §11.1, boards 01 and 06): frame, skin,
-- title bar (centered gold title, restriction badge, compact's Scan group icon, minimize, close), the active tab
-- and its lazily built panes, the filter bar's host, the footer's host, the mode strips (the library's
-- strip in its test and simulation flavors, anchored and tipped here; the title bar's TEST MODE /
-- SIM word stands in only while minimized or with no strip), minimize, resize, position, lock, scale, alpha
-- and the show decision.
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
-- pure composer and its reads), modules/WindowTabs.lua the tab strip (its tabs, their labels and
-- tooltips, the panes, their layout and paint, and the tabs' registry; RX-27), modules/CompactChrome.lua
-- all of it in the compact layout. The tabs' bodies (WindowGroup, WindowHistory, WindowInsights) each
-- call Window.RegisterTab(key, { build, refresh, ownBar }) and are built on the tab's first show; a tab
-- with no body says what it will hold. The shell keeps which tab is active (Window.SelectTab).
--
-- THREE TABS: Drops, History (feedback-5 spec §3) and Insights (issue #12). The Drops tab's key stays
-- `group`, so its filter state and the suites keep their key; the retired tab's key, `mine`, opens
-- Drops (Window.SelectTab), and your own drops are on Drops now. A tab with `ownBar` (Insights) draws
-- its own bar: the shared one, its Sort and its Sync stand aside (Window.TabOwnsBar).
--
-- THE UI LISTENS. It repaints on the bus (RestrictionChanged, AskStateChanged, SituationChanged,
-- DropAdded, DropUpdated, TradeTimerExpiring), batched into one pass on the next frame however
-- many messages arrive; InspectDone repaints the footer alone; TradeTimerTick, its own footer
-- ticker and (while Drops shows a countdown still running: WindowGroup.LiveCountdown) a countdown
-- ticker every K.COUNTDOWN_TICK second repaint only what shows a countdown: the Drops tab's Trade
-- window cells and its footer summary's next expiry (WindowGroup.TickCountdowns, feedback-5 spec §1 and §3)
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

-- The tabs, in strip order (design spec §11.1; feedback-5 spec §3 retired `mine`; issue #12 added
-- Insights after History).
Window.TABS = { "group", "history", "insights" }
local WT     = NS.WindowTabs   -- the tab strip, its panes and the tabs' registry (RX-27)

local frame   -- built on the first show
local openedByTestMode = false   -- test mode, not the player, opened the window
local visibilityListeners = {}   -- fn(shown), told on every OnShow and OnHide of the frame
local geometryListeners = {}     -- fn(cause), told when the frame moves, resizes, rescales or minimizes
local activeTab = "group"
local newCount = 0               -- drops added to the shown feed since the window was minimized
local restrictionReason          -- RestrictionChanged's last `reason` (nil: nothing restricted)
local restrictionSeen = false    -- a RestrictionChanged has arrived since the stand-up
local instanceSince              -- GetTime() of the last situation change (kept across a reload)
local footerTicker
local countdownTicker            -- each second while Drops shows a running countdown
local repaintPending = false     -- a bus repaint is queued for the next frame
local repaintCountdown           -- the countdowns' own repaint (defined with the repaints below)
local syncCountdownTicker        -- starts or stops the countdown ticker (defined with it)

local function notifyVisibility(shown)
    for _, fn in ipairs(visibilityListeners) do fn(shown) end
end

-- `cause` is `move` (a drag's stop, Reset position), `resize` (the grip's stop), `layout` (scale,
-- alpha, the layout's size and point: Window.ApplyLayout) or `minimize` (Window.SetMinimized).
local function notifyGeometry(cause)
    if not frame then return end
    for _, fn in ipairs(geometryListeners) do fn(cause) end
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

local function isMinimized() return geometry().minimized == true end
local function feedName() return NS.State.testMode == true and "test" or "live" end

--- What the window shows: its feed (`test` in test mode, else `live`). The simulator's report
--- places its drops by it (SimReport). Drops lists every drop, your own included
--- (feedback-5 spec §2: `feed.showOwn` is retired).
--- @return table { feed }
function Window.FeedView() return { feed = feedName() } end

--- The feed the window shows (`test` in test mode, else `live`), with no table built: the repaint's
--- own read (WindowPending), which FeedView's fresh table would bill to every pass.
--- @return string
function Window.FeedName() return feedName() end

-- ── tooltips ────────────────────────────────────────────────────────────────────────────────

-- ABOVE THE CONTROL (feedback-3 spec §1, DW-B1). A filter-bar control's tooltip (the bar's
-- dropdowns, its search box and the tab's Sort) never covers the control or the menu it opens
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
-- button or header, DW-B2: modules/RowTooltip.lua, the row's top right like Loot History) and
-- `rolls` (a Rolls panel line, RX-26: beside the panel away from the window, NS.RollsPanel.PlaceTip,
-- else below the line as ANCHOR_BOTTOM would).
local function placeRolls(tip, w)
    if NS.RollsPanel.PlaceTip(tip, w) then return end
    tip:ClearAllPoints()
    tip:SetPoint("TOP", w, "BOTTOM", 0, 0)
end

local PLACERS = {
    above = function(tip, w) Window.PlaceAbove(tip, w) end,
    row = function(tip, w) NS.RowTooltip.PlaceOrFallback(tip, w) end,
    rolls = placeRolls,
}

-- One line under the title: a string wraps at the tooltip's width; `{ text, wrap = false }`
-- (feedback-6 spec §3) does not, so the tooltip grows to fit it; `{ grid = rows }`
-- (NS.TipMarks.Grid, feedback-7 spec §3) reserves a line per row, painted as columns by NS.TipGrid.
-- The lines are the skin's tooltip value color (Ka0s Default white) and the title its tooltip title
-- (gold); GameTooltip's frame stays the client's (skinning-§7).
local function addTipLine(line)
    if type(line) == "table" and type(line.grid) == "table" then
        NS.TipGrid.Add(GameTooltip, line)
        return
    end
    local r, g, b = NS.Skin.Color("gtip.value")
    if type(line) == "table" then
        GameTooltip:AddLine(line.text, r, g, b, line.wrap ~= false)
    else
        GameTooltip:AddLine(line, r, g, b, true)
    end
end

local function showTooltip(self)
    local lines = { self.tooltip() }
    if #lines == 0 or not GameTooltip then return end
    local placer = PLACERS[self.tipPlace]
    NS.TipGrid.Begin()
    GameTooltip:SetOwner(self, placer and "ANCHOR_NONE" or "ANCHOR_BOTTOM")
    local r, g, b = NS.Skin.Color("gtip.title")
    GameTooltip:SetText(lines[1], r, g, b)
    for i = 2, #lines do addTipLine(lines[i]) end
    GameTooltip:Show()
    NS.TipGrid.Paint(GameTooltip)   -- after Show: it measures, widens and shows again
    if placer then placer(GameTooltip, self) end
end

local function hideTooltip()
    if GameTooltip then GameTooltip:Hide() end
end

--- Give `widget` a tooltip: `fn()` answers the title, then each line (a string, which wraps,
--- `{ text, wrap = false }`, which does not, or `{ grid = rows }`, columns:
--- NS.TipMarks.Grid, painted by NS.TipGrid). Read on every hover, so it is
--- never stale, and kept as `widget.tooltip` so a suite reads exactly what a hover would show.
--- Hooked rather than set, so a library widget keeps its own hover tint. A button shows it while
--- disabled too (SetMotionScriptsWhileDisabled): the gray No action's tooltip is why there is none.
--- `place` is nil (below the widget, ANCHOR_BOTTOM), `above` (Window.PlaceAbove: a filter-bar
--- control, DW-B1), `row` (NS.RowTooltip: a table row's cell, button or header, DW-B2) or `rolls`
--- (NS.RollsPanel.PlaceTip: a Rolls panel line, beside the panel away from the window, RX-26).
--- @param widget table
--- @param fn function
--- @param place string|nil
function Window.AttachTooltip(widget, fn, place)
    widget.tooltip = fn
    widget.tipPlace = place
    if widget.EnableMouse then widget:EnableMouse(true) end
    if widget.SetMotionScriptsWhileDisabled then widget:SetMotionScriptsWhileDisabled(true) end
    widget:HookScript("OnEnter", showTooltip)
    widget:HookScript("OnLeave", hideTooltip)
    widget:HookScript("OnEnter", function(self) NS.WindowRows.WashRowOf(self, true) end)
    widget:HookScript("OnLeave", function(self) NS.WindowRows.WashRowOf(self, false) end)
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

--- A tab's label in the full layout (NS.WindowTabs.Label).
--- @param key string
--- @return string
function Window.TabLabel(key) return WT.Label(key) end

-- ── reads ───────────────────────────────────────────────────────────────────────────────────

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

-- Minimized, the window is its band and the edge above and below it (R5-WIN): the band's height
-- and its inset from the top, as S.Shell lays it for the skin in force (2 + 30 + 2 under a 2 px
-- edge), so the bottom edge never covers the band. With no library, the 1 px edge's 32.
local function minimizedHeight()
    local band = NS.Skin.Band(frame)
    local h = band and band:GetHeight()
    local y = band and select(5, band:GetPoint(1))
    if type(h) ~= "number" or h <= 0 or type(y) ~= "number" then return K.TITLE_H + 2 end
    return h - 2 * y
end

-- The layout's bounds and size (modules/WindowCompact.lua). Minimized, the window is its title bar
-- alone; the stored height is kept for the expand.
local function applySize()
    local width, height = NS.WindowCompact.Fit(frame)
    frame:SetSize(width, isMinimized() and minimizedHeight() or height)
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
    NS.WindowAutoClose.Cancel()   -- a drag keeps an auto-opened window open (rolls UX design §3.6)
    if isLocked() then return end
    frame:StartMoving()
end

local function onDragStop()
    frame:StopMovingOrSizing()
    savePoint()
    notifyGeometry("move")
end

--- A flat button in the window's look (the Scan group button's, and each Drops row's Ask):
--- the skin's fill and inner line, a catalog mark at the left (`icon` may be nil) and a centered
--- label (`b.label`, `b.art`). `onClick(b)` runs on a click. Built by modules/WindowTitleBar.lua.
--- @return table
function Window.TextButton(parent, width, icon, text, onClick, scale)
    return NS.WindowTitleBar.TextButton(parent, width, icon, text, onClick, scale)
end

--- A TextButton's label and mark (`icon` may be nil): WindowTitleBar.SetButtonMark.
--- @param b table a Window.TextButton
--- @param text string
--- @param icon string|nil
function Window.SetButtonMark(b, text, icon) NS.WindowTitleBar.SetButtonMark(b, text, icon) end

-- ── construction: the body (the tab strip is modules/WindowTabs.lua) ────────────────────────

-- The mode strips (board 06 E; preview-mode's *Where the strip sits*): the library's strip
-- (LibKa0s-Widgets' TestStrip, LibKa0s#48), one per mode, docked directly under the title bar, full
-- width, above the tabs, the filter bar and the tab's body (`dock = "title"`, Widgets minor 27: the
-- library anchors it, and places it again on every show, hide and resize), and tipped here: f.banner
-- (amber, test mode, TestTip) and f.simBanner (cyan, kind "sim" from Widgets minor 14, a running
-- simulation, SimTip). Both are born hidden; Refresh shows the one in force, and the body moves down
-- by the strip in force's `BodyOffset` (relayBody). No library, no strips: both stay nil, the body
-- moves nothing and the title bar's word marks the mode.

-- The body's top under the title bar, moved down by the strip in force (0 with none showing); each
-- strip's show and hide (its onOffset) and every layout pass call it, the latter because the
-- compact layout's two-line strip changes its height with no show.
local function relayBody(f)
    local body = f.body
    if not body then return end
    local offset = math.max(f.banner and f.banner:BodyOffset() or 0, f.simBanner and f.simBanner:BodyOffset() or 0)
    if body.dwOffset == offset then return end
    body.dwOffset = offset
    body:ClearAllPoints()
    body:SetPoint("TOPLEFT", f.divider, "BOTTOMLEFT", 0, -offset)
    body:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -1, 1)
end

local function buildBanner(f, body)
    local dock = { titleBar = f.titleBar, window = f, onOffset = function() relayBody(f) end }
    local b = NS.MakeTestStrip(body,
        L["TEST MODE: sample drops of real items in every state. Nothing is whispered. Combat ends it."], nil, dock)
    if not b then return end
    Window.AttachTooltip(b, NS.WindowTitleBar.TestTip)
    f.banner = b
    local s = NS.MakeTestStrip(body,
        L["SIM: a made-up group session through the real engine. Nothing is sent. /dw sim stop ends it."], "sim", dock)
    if not s then return end
    Window.AttachTooltip(s, NS.WindowTitleBar.SimTip)
    f.simBanner = s
end

-- The window's footer (standalone-windows' *The footer*, LibKa0s Widgets' Footer, minor 27): no fill,
-- the hairline in the skin's `divider` along its top, `FOOTER.HEIGHT` tall across the body's bottom
-- edge (inset 0: the body is already 1 px inside the window's edge), the resize grip's corner cleared
-- (`grip`, the grip itself built on it by makeResizable). Its words are its own left line and its
-- controls its marks (RX-24: NS.WindowFooter, NS.FooterRow), the active tab's. No library: a bare
-- frame of the same height with the two lines and no marks (NS.BareFooter).
local function buildFooter(body)
    return NS.MakeFooter(body, { grip = true, inset = 0, marks = NS.FooterRow.MarkSpecs() })
        or NS.BareFooter(body)
end

local function buildBody(f)
    local body = CreateFrame("Frame", nil, f)
    f.body = body
    relayBody(f)
    WT.Build(f, body)

    f.filterHost = CreateFrame("Frame", nil, body)
    f.filterHost:SetPoint("TOPLEFT", body, "TOPLEFT", K.INSET, -(K.TAB_H + 4))
    f.filterHost:SetPoint("TOPRIGHT", body, "TOPRIGHT", -K.INSET, -(K.TAB_H + 4))
    f.filterHost:SetHeight(K.FILTER_H)

    buildBanner(f, body)

    -- The footer, the one footer line (RX-09, rolls-UX spec §3.7; RX-24): the panes reach the body's
    -- foot and their scroll frames end over it; the resize grip is built in its bottom-right corner
    -- (makeResizable). No status bar and no strip of its own: the active tab's words and the status
    -- are its left line, the tab's controls its marks.
    f.footerHost = buildFooter(body)

    WT.BuildPanes(f, body)
    NS.WindowFilterBar.Build(f.filterHost)
    NS.FooterRow.Attach(f.footerHost)
    NS.WindowFooter.Build(f.footerHost)
end

local function makeResizable(f)
    local minW, minH, maxW, maxH = NS.WindowCompact.Bounds(NS.WindowCompact.Mode())
    NS.MakeResizable(f, {
        minWidth = minW, minHeight = minH, maxWidth = maxW, maxHeight = maxH,
        -- The owner's icon.grip tints the grip's art, live (Core minor 14): the tool windows' grips
        -- and this one wear one skin; under Ka0s Default and WoW Default it is the client's art.
        owner        = addonName,
        -- In the footer's bottom-right corner (LibKa0s Widgets' Footer, RX-09); hidden while locked or
        -- minimized (paintMinimized, RX-08).
        gripParent   = f.footerHost,
        canResize    = function() return not isLocked() and not isMinimized() end,
        -- The anchor is saved with the size: sizing from the corner moves the frame's anchor, and a
        -- later ApplySettings re-anchors the stored size at the stored point.
        onResizeStop = function(width, height)
            saveSize(width, height)
            savePoint()
            NS.WindowFilterBar.Layout(width)
            -- The table's columns take the new width.
            Window.Refresh()
            notifyGeometry("resize")
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
    f:SetFrameStrata(C.LAYERS.STRATA.WINDOW)
    f:SetToplevel(true)   -- a click raises it over another MEDIUM window it overlaps (frame-layering-§4)
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
    -- The title bar paints its own title.bg (S.TitleBar), so the shell draws no second band under it.
    NS.Skin.Shell(f, { noTopBar = true })
    -- The bar takes the band's rect, flush inside the edge at Shell's inset in every skin, as Ka0s Loot
    -- History's (R5-WIN): its title and controls, anchored to the bar at y 0, sit on the band's middle.
    NS.Skin.Header(f, { bars = { f.titleBar } })
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

--- The view a tab's body draws: its feed, its filter state, the controls it honors and the row
--- predicate and order that apply them (modules/WindowFilterBar.lua).
--- @param tab string|nil the active tab when nil
--- Every drop is the tab's (Drops lists your own too: feedback-5 spec §2); `hiddenBy` says
--- which control hides one (FB.HiddenBy), so a header counts every drop.
--- @return table { tab, feed, filter, honors, ctx, matches = fn(drop), hiddenBy = fn(drop),
---   compare = fn(a, b) }
function Window.TabContext(tab)
    tab = tab or activeTab
    local FB = NS.WindowFilterBar
    local st, honors = FB.State(tab), FB.HONORS[tab]
    local feed = feedName()
    -- The placeholders ignore the situation and the login, so neither This instance nor This session
    -- cuts them (spec §11.6); This session is the login in the client clock (feedback-15 spec §1). The
    -- Character dropdown reads your recorder key (modules/CharFilter.lua).
    local live = feed ~= "test"
    local ctx = { instanceSince = live and instanceSince or nil, current = NS.CharFilter.CurrentKey(),
        sessionSince = live and NS.Session.StartClock() or nil }
    return {
        tab = tab, feed = feed, filter = st, honors = honors, ctx = ctx,
        matches = function(drop) return FB.Matches(drop, st, ctx, honors) end,
        hiddenBy = function(drop) return FB.HiddenBy(drop, st, ctx, honors) end,
        compare = FB.Comparator(st.sort),
    }
end

local function paintMinimized()
    local m = isMinimized()
    frame.body:SetShown(not m)
    -- The grip shows only while the window can be resized: expanded and unlocked (RX-08); the
    -- footer clears its corner only while it shows (foot:SetGrip), told only when that turns, since
    -- W.Footer lays its marks and both lines out again on every SetGrip (RX-27).
    local grip = not m and not isLocked()
    if frame.resizeGrip then frame.resizeGrip:SetShown(grip) end
    local foot = frame.footerHost
    if foot.SetGrip and foot.dwGrip ~= grip then
        foot.dwGrip = grip
        foot:SetGrip(grip)
    end
    NS.WindowTitleBar.PaintMinimized(frame, m, newCount)
    NS.WindowTitleBar.PaintLock(frame, isLocked())
end

--- One repaint pass: the title bar's badge and counter, the tabs, and (expanded) the mode strips, the
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
        local sim = NS.State.testMode ~= true and NS.Sim:IsActive()
        if frame.banner then frame.banner:SetShown(NS.State.testMode == true) end
        if frame.simBanner then frame.simBanner:SetShown(sim) end
        relayBody(frame)
        WT.Layout(frame, activeTab)
        WT.Paint(frame, activeTab)
        if not Window.TabOwnsBar(activeTab) then NS.WindowFilterBar.Sync(activeTab) end
        NS.WindowFooter.Refresh()
        WT.RefreshActive(frame, activeTab, Window.TabContext)
        -- The Offer panel docks beside the window and repaints with it (modules/OfferPanel.lua).
        if NS.OfferPanel then NS.OfferPanel.Refresh() end
    end
    syncCountdownTicker()
    NS.WindowAutoClose.OnRefresh()   -- an armed auto-close reaches the frames this pass built
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
-- repaints, Drops' Trade window cells and its footer summary while it is the active tab and the Offer panel
-- while it is open; the rest of the table, the filter bar and the footer are left alone.
-- The countdown ticker runs while the shown, expanded window's Drops tab has a countdown
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
    if NS.OfferPanel and NS.OfferPanel.IsShown() then NS.OfferPanel.Refresh() end
    syncCountdownTicker()
end

-- ── tabs ────────────────────────────────────────────────────────────────────────────────────

--- Show one tab: its pane is built on its first show, and the filter bar takes its state. The
--- retired `mine` opens Drops (`group`; feedback-5 spec §3).
--- @param key string `group`, `history` or `insights`
--- @return boolean changed false for an unknown tab
function Window.SelectTab(key)
    key = WT.Resolve(key)
    if not key then return false end
    activeTab = key
    if not frame then return true end
    for k, pane in pairs(frame.panes) do pane:SetShown(k == key) end
    if Window.TabOwnsBar(key) then
        NS.CloseMenu()   -- the shared bar's menu and the compact Filters menu go with the bar
        NS.CompactChrome.CloseFilters()
    end
    WT.BuildPane(frame, key)
    NS.Debug(TAG, "tab -> %s", key)
    Window.Refresh()
    return true
end

--- @return string
function Window.ActiveTab() return activeTab end

--- Whether a tab draws its own filter bar (its spec's `ownBar`: Insights).
--- @param tab string|nil the active tab when nil
--- @return boolean
function Window.TabOwnsBar(tab) return WT.OwnsBar(tab or activeTab) end

--- A feature item's body for one tab (WindowGroup, WindowHistory, WindowInsights): `spec.build(pane)`
--- runs on the tab's first show, `spec.refresh(pane, Window.TabContext(tab))` on every repaint
--- while it is the active tab. `spec.ownBar` marks a tab that draws its own filter bar.
--- @param key string
--- @param spec table { build = fn, refresh = fn, ownBar = boolean|nil }
function Window.RegisterTab(key, spec)
    WT.Register(key, spec)
    if not frame then return end
    frame.panes[key].built = nil
    if key == activeTab then
        WT.BuildPane(frame, key)
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
    notifyGeometry("minimize")
end

function Window.ToggleMinimized() Window.SetMinimized(not isMinimized()) end

--- @return boolean
function Window.IsMinimized() return isMinimized() end

--- Whether `locked` (Lock frame, `/dw lock`) holds the window in place: no drag, no resize grip.
--- @return boolean
function Window.IsLocked() return isLocked() end

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
    NS.WindowAutoClose.Disarm()   -- a manual show never closes by itself (an auto-open re-arms after)
    NS.State.windowOpen = true
    openedByTestMode = false
    Window.UpdateVisibility()
end

function Window.Close()
    NS.WindowAutoClose.Disarm()
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

--- Be told `fn(cause)` whenever the built frame moves (`move`), resizes (`resize`), takes the
--- layout's scale, size and point again (`layout`) or minimizes and expands (`minimize`): the Rolls
--- panel docked beside it (modules/RollsPanel.lua) re-checks its side. Listeners are never removed.
--- @param fn function
function Window.AddGeometryListener(fn)
    geometryListeners[#geometryListeners + 1] = fn
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
    if frame then
        applyLook(); applySize(); applyPoint()
        NS.IconStyle.Resnap()   -- the Scale moved under the icons on screen: one pixel again (R5-ICON)
        notifyGeometry("layout")
    end
end

--- Window.ApplyLayout, then the show decision. Run at stand-up, on a profile change and by the
--- Master controls rows' reactions.
function Window.ApplySettings()
    Window.ApplyLayout()
    Window.UpdateVisibility()
end

--- Reset position: forget both layouts' stored point and size, and put the window back where it
--- started; the toast's saved position goes too (modules/Toast.lua), and the simulation panel
--- forgets this session's dragged point and docks beside the window again (LibKa0s-Sim-1.0).
function Window.ResetPosition()
    NS.WindowCompact.ResetGeometry()
    if frame then
        applySize()
        applyPoint()
        notifyGeometry("move")
    end
    if NS.Toast then NS.Toast.ResetPosition() end
    if NS.Sim then NS.Sim:ResetPanelPosition() end
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
-- It opens on Drops, where the drop is (feedback-20); a window already open keeps the tab it shows.
-- A test drop's open is test mode's (openedByTestMode), so turning test mode off closes it again:
-- NS.SetTestMode fills the feed before Window.OnTestModeChanged, so the drops can open it first.
-- A drop restored after a reload (feedback-15 spec §0) was seen before it: it opens nothing, and
-- a window minimized before the reload does not count it new.
-- A ROLL opens it too (RX-16): its Blizzard roll popup is up and Pending admitted it into Rolling
-- now past the same gates (onPendingOpened). `what` names the drop or the roll in the debug line.
local function maybeAutoOpen(rec, what)
    if NS.State.windowOpen == true or setting("autoOpen") == false or rec.source == "restore" then return end
    local Sit = NS.Situations
    local key = Sit.Current()
    if not Sit.ShouldAutoOpen(key) then return end
    NS.Debug(TAG, "auto-open: %s %s in %s", what or "drop", tostring(rec.id), tostring(key))
    NS.WindowCompact.OnAutoOpen(key)   -- compact during a run (`window.compactInRuns`)
    Window.SelectTab("group")
    Window.Open()
    openedByTestMode = rec.test == true
    NS.WindowAutoClose.Arm()   -- auto-close (rolls UX design §3.6): only an auto-open's show counts down
end

local function onDropAdded(id)
    local rec = NS.LootFeed.Get(id)
    if not rec then return end
    if not inShownFeed(rec) then
        scheduleRepaint()
        return
    end
    maybeAutoOpen(rec)
    if isMinimized() and rec.source ~= "restore" then newCount = newCount + 1 end
    scheduleRepaint()
end

-- PendingChanged(id, "open" or "popup"): a roll item in Rolling now (RX-16) holds your roll popup
-- (`rollID`, claimed as it entered or when the popup came up after it) and passed the feed's gates.
-- A roll the loot history lists that you get no popup for opens nothing (RX-20). A master-loot
-- hold (kind `ml`) has no popup, and a roll Pending rebuilt after a reload or stand-up (`restored`)
-- was seen before: neither opens anything, nor does a roll with `rolls.show` off (Rolling now lists
-- nothing). A test mode sample opens only the test feed's window, by test mode's own rule, as a
-- test drop does.
local function onPendingOpened(id)
    local item = NS.Pending.Get(id)
    if not item or item.kind == "ml" or item.restored or not inShownFeed(item) then return end
    if not NS.WindowPending.Shown() or (item.rollID == nil and not item.test) then return end
    maybeAutoOpen(item, "roll")
end

local function onRestriction(reason)
    restrictionSeen, restrictionReason = true, reason
    scheduleRepaint()
end

-- This instance starts now, or, on a reload's first announcement in the same place, where it
-- started before the reload (NS.Session.MarkSituation, feedback-15 spec §0).
local function onSituation(key)
    instanceSince = NS.Session.MarkSituation(key)
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
    target:RegisterMessage(M.SITUATION_CHANGED, function(_, key) onSituation(key) end)
    target:RegisterMessage(M.DROP_ADDED, function(_, id) onDropAdded(id) end)
    target:RegisterMessage(M.DROP_UPDATED, function() scheduleRepaint() end)
    -- Drops' Rolling now section (modules/WindowPending.lua): an item opened, changed or closed.
    -- A roll item opening opens a closed window (RX-16).
    target:RegisterMessage(M.PENDING_CHANGED, function(_, id, cause)
        if cause == "open" or cause == "popup" then onPendingOpened(id) end
        scheduleRepaint()
    end)
    -- The Me cell reads your gear snapshot: a new one repaints it (feedback spec §3, FB-6).
    target:RegisterMessage(M.GEAR_CHANGED, function() scheduleRepaint() end)
    target:RegisterMessage(M.INSPECT_DONE, function() repaintFooter() end)
    -- The Drops tab's and the Offer panel's countdowns (modules/TradeTimer.lua).
    target:RegisterMessage(M.TRADE_TIMER_TICK, function() repaintCountdown() end)
    -- A drop nearing its end changes the tab's count and the rows' tones: one whole pass.
    target:RegisterMessage(M.TRADE_TIMER_EXPIRING, function() scheduleRepaint() end)
end
listen()

-- A skin switch (OnLooksChanged: the library has repainted what it recorded, and core/SkinSetup.lua
-- has refilled the tones and repainted the host's own paints): one whole pass of the shown window, so
-- every tone set at paint time (a cell, a tab, a button) and the rows' font size take the new skin.
-- Tracked by no bus: the skin is not this addon's, and it fires only on a player's pick.
NS.Skin.OnLooksChanged(function()
    NS.WindowRows.OnLooksChanged()
    NS.Glow.OnLooksChanged()
    if frame and isMinimized() then applySize() end   -- the band's inset moves with the skin's edge
    repaint()
end)

NS.STAND_DOWN[#NS.STAND_DOWN + 1] = function()
    stopTicker()
    repaintPending = false
    restrictionSeen, restrictionReason = false, nil
    if target and not NS.Bus.tracked then target:UnregisterAllMessages() end
end
NS.STAND_UP[#NS.STAND_UP + 1] = function()
    if not NS.Bus.tracked then listen() end
end
