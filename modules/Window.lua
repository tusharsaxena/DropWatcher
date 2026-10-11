local addonName, NS = ...
-- modules/Window.lua — the main window's shell (design spec §11.1, boards 01 and 06): frame, skin,
-- title bar (logo, gold title, restriction badge, Scan group, minimize, close), the tab strip and
-- its lazily built panes, the filter bar's host, the footer's host, test mode's chip and banner,
-- minimize, resize, position, lock, scale, alpha and the show decision.
--
-- A non-secure standalone window (standalone-windows): built lazily on the first show, skinned
-- through LibKa0s-Core's ApplySkin, closed by Escape (UISpecialFrames) and by the shared close mark
-- (NS.MakeCloseButton). Title-bar marks come from the shared icon catalog (NS.Icon), each with a
-- plain character beneath it for a texture that does not load. The chrome follows Ka0s Loot
-- History's window: a 30px title bar, a 26px tab strip with a gold active label and underline, the
-- filter bar, the tab's body and the footer.
--
-- THE SPLIT. modules/WindowFilterBar.lua owns the filter bar (its controls, each tab's filter state
-- and the pure row predicates), modules/WindowFooter.lua the footer (its pure composer and its
-- reads). The tabs' bodies are the feature items' (WindowGroup, WindowMine, WindowHistory): each
-- calls Window.RegisterTab(key, { build, refresh }) and is built on its tab's first show. A tab
-- with no body yet shows a line saying what it will hold, so the window is never blank.
--
-- THE UI LISTENS. It repaints on the bus (RestrictionChanged, AskStateChanged, SituationChanged,
-- DropAdded, DropUpdated, TradeTimerExpiring), batched into one pass on the next frame however
-- many messages arrive; InspectDone repaints the footer alone; TradeTimerTick and its own footer
-- ticker (which also moves the My drops tab's estimated countdowns) repaint only what shows a
-- countdown, the My drops tab and the Offer panel. It reads records
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
-- Geometry (profile.window: point, width, height, minimized) is written here and nowhere else: by
-- a drag, a resize, the minimize button and Reset position.

NS.Window = NS.Window or {}
local Window = NS.Window
local K      = NS.Constants.WINDOW
local C      = NS.Constants
local L      = NS.L
local Perf   = NS.Perf

local TAG = "UI"

-- The 128x128 logo the TOC and the launcher wear.
local LOGO = ("Interface\\AddOns\\%s\\media\\logos\\%s.logo.128.tga"):format(addonName, addonName:lower())

-- The tabs, in strip order (design spec §11.1).
Window.TABS = { "group", "mine", "history" }
local TAB_SET = { group = true, mine = true, history = true }
local TAB_LABEL = { group = L["Group drops"], mine = L["My drops"], history = L["History"] }
local TAB_TIP = {
    group   = L["Every drop your group receives, one row each, grouped by boss or key run."],
    mine    = L["Your own drops you can still trade, with the time left and who each would help."],
    history = L["Drops from earlier encounters, kept across sessions."],
}
-- What a tab with no body yet says, so the window is never blank.
local TAB_PLACEHOLDER = {
    group   = L["No drops yet. Loot your group receives appears here."],
    mine    = L["Your tradeable drops appear here, with who each would help."],
    history = L["Drops from earlier encounters appear here."],
}

-- The restriction badge's words (design spec §11.1), keyed by RestrictionChanged's `reason`.
local REASON_LABEL = {
    encounter = L["Encounter"], challengeMode = L["Mythic+ key"], pvpMatch = L["PvP match"],
    chat = L["Chat restricted"], chatLockdown = L["Chat lockdown"], combat = L["Combat"],
}
local REASON_TIP = {
    encounter     = L["A boss encounter is in progress: addons cannot whisper or inspect until it ends. Asks wait in the queue and are sent then."],
    challengeMode = L["A Mythic+ key is running: addon chat is restricted until it ends. Asks wait in the queue and are sent then."],
    pvpMatch      = L["A PvP match is in progress: addon chat is restricted until it ends. Asks wait in the queue."],
    chat          = L["The client restricts addon chat right now. Asks wait in the queue and are sent once it lifts."],
    chatLockdown  = L["Chat messaging is locked down right now. Asks wait in the queue and are sent once it lifts."],
    combat        = L["You are in combat: inspects and trades wait until it ends. Asks are still sent."],
}
local KIND_LABEL = { ask = L["Ask"], offer = L["Offer"], announce = L["Announce"] }
local BADGE_LIST_MAX = 8

local frame   -- built on the first show
local openedByTestMode = false   -- test mode, not the player, opened the window
local visibilityListeners = {}   -- fn(shown), told on every OnShow and OnHide of the frame
local tabSpecs = {}              -- [tab] = { build = fn(pane), refresh = fn(pane, ctx) }
local activeTab = "group"
local newCount = 0               -- interesting drops since the window was minimized
local restrictionReason          -- RestrictionChanged's last `reason` (nil: nothing restricted)
local restrictionSeen = false    -- a RestrictionChanged has arrived since the stand-up
local autoOpenedIn               -- the situation the first interesting drop already opened it in
local instanceSince              -- GetTime() of the last situation change: "This instance"
local footerTicker
local lastTitleClick
local repaintPending = false     -- a bus repaint is queued for the next frame
local repaintCountdown           -- the countdowns' own repaint (defined with the repaints below)

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

-- ── tooltips ────────────────────────────────────────────────────────────────────────────────

local function showTooltip(self)
    local lines = { self.tooltip() }
    if #lines == 0 or not GameTooltip then return end
    GameTooltip:SetOwner(self, "ANCHOR_BOTTOM")
    GameTooltip:SetText(lines[1], C.GOLD.r, C.GOLD.g, C.GOLD.b)
    for i = 2, #lines do GameTooltip:AddLine(lines[i], 1, 1, 1, true) end
    GameTooltip:Show()
end

local function hideTooltip()
    if GameTooltip then GameTooltip:Hide() end
end

--- Give `widget` a tooltip: `fn()` answers the title, then each line. Read on every hover, so it is
--- never stale, and kept as `widget.tooltip` so a suite reads exactly what a hover would show.
--- Hooked rather than set, so a library widget keeps its own hover tint.
--- @param widget table
--- @param fn function
function Window.AttachTooltip(widget, fn)
    widget.tooltip = fn
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

--- The restriction badge's text: nil while nothing is restricted (the badge hides), else the
--- reason and, when asks wait, how many: `Encounter · 2 queued`.
--- @param reason string|nil RestrictionChanged's reason
--- @param queued number|nil
--- @return string|nil
function Window.BadgeText(reason, queued)
    if reason == nil then return nil end
    local label = REASON_LABEL[reason] or tostring(reason)
    local n = tonumber(queued) or 0
    if n > 0 then return L["%s · %d queued"]:format(label, n) end
    return label
end

--- A tab's label: `My drops · 2` counts your tradeable drops.
--- @param key string
--- @param mine number|nil
--- @return string
function Window.TabLabel(key, mine)
    local n = tonumber(mine) or 0
    if key == "mine" and n > 0 then return L["My drops · %d"]:format(n) end
    return TAB_LABEL[key] or tostring(key)
end

-- ── reads ───────────────────────────────────────────────────────────────────────────────────

local function queuedAsks()
    return NS.Asks and NS.Asks.Queued() or {}
end

-- Your drops you can still trade, in the feed on show (the test feed in test mode).
local function mineCount()
    local FB, n = NS.WindowFilterBar, 0
    for _, d in ipairs(NS.LootFeed.Drops(feedName())) do
        if FB.IsTradeableMine(d) then n = n + 1 end
    end
    return n
end

-- RestrictionChanged's last reason; before the first one, the tracker's own answer.
local function currentReason()
    if restrictionSeen then return restrictionReason end
    return NS.Restrictions and NS.Restrictions.ActiveReason() or nil
end

local function badgeTooltip()
    local reason = currentReason()
    local lines = { Window.BadgeText(reason, 0) or L["Not restricted"] }
    if REASON_TIP[reason] then lines[2] = REASON_TIP[reason] end
    local queued = queuedAsks()
    for i, a in ipairs(queued) do
        if i > BADGE_LIST_MAX then
            lines[#lines + 1] = L["and %d more"]:format(#queued - BADGE_LIST_MAX)
            break
        end
        lines[#lines + 1] = L["Queued: %s to %s"]:format(KIND_LABEL[a.kind] or tostring(a.kind), tostring(a.target))
    end
    return unpack(lines)
end

-- ── geometry ────────────────────────────────────────────────────────────────────────────────

local function savePoint()
    local point, _, relativePoint, x, y = frame:GetPoint(1)
    if point then geometry().point = { point, relativePoint, x, y } end
end

local function saveSize(width, height)
    local g = geometry()
    g.width, g.height = width, height
end

local function applyPoint()
    local pt = geometry().point
    if type(pt) ~= "table" then pt = K.POINT end
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

-- Minimized, the window is its title bar alone; the stored height is kept for the expand.
local function applySize()
    local g = geometry()
    local height = isMinimized() and (K.TITLE_H + 2) or (g.height or K.HEIGHT)
    frame:SetSize(g.width or K.WIDTH, height)
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
    footerTicker = nil
end

-- "Last loot 12s ago" ages while nothing else happens: one slow ticker, alive only while the whole
-- window is on screen.
local function startTicker()
    if footerTicker or isMinimized() or not (frame and frame:IsShown()) then return end
    footerTicker = C_Timer.NewTicker(K.FOOTER_TICK, tick)
end

-- ── construction: the title bar ─────────────────────────────────────────────────────────────

local function onDragStart()
    if isLocked() then return end
    frame:StartMoving()
end

local function onDragStop()
    frame:StopMovingOrSizing()
    savePoint()
end

-- A double-click on the bar expands a minimized window (board 06 A).
local function onTitleClick(_, button)
    if button ~= "LeftButton" then return end
    local now = GetTime()
    if lastTitleClick and now - lastTitleClick <= K.DOUBLE_CLICK and isMinimized() then
        lastTitleClick = nil
        Window.SetMinimized(false)
        return
    end
    lastTitleClick = now
end

-- The mark for `icon` from the catalog, or `glyph` when the texture does not resolve.
local function setMark(b, icon, glyph)
    local path = NS.Icon(icon)
    b.art:SetTexture(path)
    b.art:SetShown(path ~= nil)
    b.glyph:SetText(glyph)
    b.glyph:SetShown(path == nil)
    b.mark = icon
end

local function iconButton(parent, icon, glyph, onClick)
    local b = CreateFrame("Button", nil, parent)
    b:SetSize(K.ICON, K.ICON)
    b.art = b:CreateTexture(nil, "ARTWORK")
    b.art:SetPoint("TOPLEFT", b, "TOPLEFT", 3, -3)
    b.art:SetPoint("BOTTOMRIGHT", b, "BOTTOMRIGHT", -3, 3)
    b.glyph = b:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    b.glyph:SetPoint("CENTER", b, "CENTER", 0, 0)
    setMark(b, icon, glyph)
    b:SetScript("OnClick", onClick)
    return b
end

-- A flat button: the skin's fill and inner line, a label kept centered and a mark beside it
-- (standalone-windows: a wide action button keeps its label).
local function textButton(parent, width, icon, text, onClick)
    local b = CreateFrame("Button", nil, parent, "BackdropTemplate")
    b:SetSize(width, K.CONTROL_H)
    local S = NS.SKIN
    if b.SetBackdrop and S.bgFile then
        b:SetBackdrop({ bgFile = S.bgFile, edgeFile = S.edgeFile, edgeSize = S.edgeSize })
        b:SetBackdropColor(0.12, 0.12, 0.14, 1)
        b:SetBackdropBorderColor(unpack(S.innerBorder or S.border))
    end
    b.art = b:CreateTexture(nil, "ARTWORK")
    b.art:SetSize(12, 12)
    b.art:SetPoint("LEFT", b, "LEFT", 6, 0)
    b.art:SetTexture(NS.Icon(icon))
    b.label = b:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    b.label:SetPoint("CENTER", b, "CENTER", 7, 0)
    b.label:SetText(text)
    b:SetScript("OnClick", onClick)
    return b
end

--- A flat button in the window's look (the Scan group button's, and each Group drops row's Ask):
--- the skin's fill and inner line, a catalog mark at the left (`icon` may be nil) and a centered
--- label (`b.label`, `b.art`). `onClick(b)` runs on a click.
--- @return table
function Window.TextButton(parent, width, icon, text, onClick)
    return textButton(parent, width, icon, text, onClick)
end

local function buildBadge(bar)
    local b = CreateFrame("Frame", nil, bar)
    b:SetSize(170, K.CONTROL_H)
    b.art = b:CreateTexture(nil, "ARTWORK")
    b.art:SetSize(12, 12)
    b.art:SetPoint("LEFT", b, "LEFT", 4, 0)
    b.art:SetTexture(NS.Icon("lock"))
    b.art:SetVertexColor(1, 0.6, 0.2)
    b.text = b:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    b.text:SetPoint("LEFT", b.art, "RIGHT", 4, 0)
    b.text:SetTextColor(1, 0.6, 0.2)
    Window.AttachTooltip(b, badgeTooltip)
    b:Hide()
    return b
end

local function minimizeTip()
    if isMinimized() then
        return L["Expand"], L["Show the whole window again. Double-clicking the title bar does the same."]
    end
    return L["Minimize"], L["Collapse the window to its title bar. Its position is kept, and a counter shows the interesting drops that arrive meanwhile."]
end

local function scanTip()
    return L["Scan group"], L["Inspects every other member of your group, one at a time and out of combat, so each drop can be judged for its looter."]
end

local function newTip()
    return L["%d new"]:format(newCount), L["Interesting drops that arrived since you minimized the window. Expand it to see them."]
end

-- Test mode's chip and banner (design spec §11.6, board 06 E) share one tooltip.
local function testTip()
    return L["Test mode"],
        L["Placeholder drops show every verdict, trade, inspect and ask state, so the layout can be checked anywhere."],
        L["Ask, Offer and Announce print their text in your chat frame instead of sending it."],
        L["Combat ends it, and so do /dw test, the launcher menu and the Master controls checkbox."]
end

local function buildTestChip(bar, title)
    local chip = CreateFrame("Frame", nil, bar)
    chip:SetSize(76, K.CONTROL_H - 4)
    chip:SetPoint("LEFT", title, "RIGHT", 8, 0)
    chip.fill = chip:CreateTexture(nil, "BACKGROUND")
    chip.fill:SetAllPoints(chip)
    chip.fill:SetColorTexture(C.TONE.warn.r, C.TONE.warn.g, C.TONE.warn.b, 0.18)
    chip.text = chip:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    chip.text:SetPoint("CENTER", chip, "CENTER", 0, 0)
    chip.text:SetText(L["TEST MODE"])
    chip.text:SetTextColor(C.TONE.warn.r, C.TONE.warn.g, C.TONE.warn.b)
    Window.AttachTooltip(chip, testTip)
    chip:Hide()
    return chip
end

local function buildTitleControls(f, bar)
    f.closeButton = NS.MakeCloseButton(bar, function() Window.Close() end)
    local right, rightPoint = bar, "RIGHT"
    if f.closeButton then
        f.closeButton:SetPoint("RIGHT", bar, "RIGHT", -6, 0)
        right, rightPoint = f.closeButton, "LEFT"
    end
    -- The catalog's minimize mark; the key is the library's spelling (tests/prose_waivers.lua).
    f.minimizeButton = iconButton(bar, "minimise", "-", function() Window.ToggleMinimized() end)
    f.minimizeButton:SetPoint("RIGHT", right, rightPoint, -4, 0)
    Window.AttachTooltip(f.minimizeButton, minimizeTip)
    f.scanButton = textButton(bar, 96, "people", L["Scan group"], function() NS.ScanGroup() end)
    f.scanButton:SetPoint("RIGHT", f.minimizeButton, "LEFT", -6, 0)
    Window.AttachTooltip(f.scanButton, scanTip)
    f.badge = buildBadge(bar)
    f.badge:SetPoint("RIGHT", f.scanButton, "LEFT", -8, 0)
end

local function buildTitleBar(f)
    local bar = CreateFrame("Frame", nil, f)
    bar:SetPoint("TOPLEFT", f, "TOPLEFT", 1, -1)
    bar:SetPoint("TOPRIGHT", f, "TOPRIGHT", -1, -1)
    bar:SetHeight(K.TITLE_H)
    bar:EnableMouse(true)
    bar:RegisterForDrag("LeftButton")
    bar:SetScript("OnDragStart", onDragStart)
    bar:SetScript("OnDragStop", onDragStop)
    bar:SetScript("OnMouseUp", onTitleClick)
    f.titleBar = bar

    f.logo = bar:CreateTexture(nil, "ARTWORK")
    f.logo:SetSize(K.LOGO, K.LOGO)
    f.logo:SetPoint("LEFT", bar, "LEFT", 8, 0)
    f.logo:SetTexture(LOGO)

    -- Gold through ApplySkin, which tints `frame.title`.
    f.title = bar:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    f.title:SetPoint("LEFT", f.logo, "RIGHT", 6, 0)
    f.title:SetText(NS.BRAND)

    f.testChip = buildTestChip(bar, f.title)
    f.newChip = CreateFrame("Frame", nil, bar)
    f.newChip:SetSize(60, K.CONTROL_H)
    f.newChip:SetPoint("LEFT", f.title, "RIGHT", 8, 0)
    f.newChip.text = f.newChip:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    f.newChip.text:SetPoint("LEFT", f.newChip, "LEFT", 0, 0)
    Window.AttachTooltip(f.newChip, newTip)
    f.newChip:Hide()

    buildTitleControls(f, bar)

    f.divider = f:CreateTexture(nil, "ARTWORK")
    f.divider:SetHeight(1)
    f.divider:SetPoint("TOPLEFT", bar, "BOTTOMLEFT", 0, 0)
    f.divider:SetPoint("TOPRIGHT", bar, "BOTTOMRIGHT", 0, 0)
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
    Window.AttachTooltip(tab, function() return TAB_LABEL[key], TAB_TIP[key] end)
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
    b.text:SetText(L["TEST MODE: placeholder drops in every state. Nothing is whispered. Combat ends it."])
    Window.AttachTooltip(b, testTip)
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
    local top = K.TAB_H + 4 + K.FILTER_H + (NS.State.testMode == true and K.BANNER_H or 0)
    for _, pane in pairs(frame.panes) do
        pane:ClearAllPoints()
        pane:SetPoint("TOPLEFT", frame.body, "TOPLEFT", K.INSET, -top)
        pane:SetPoint("BOTTOMRIGHT", frame.body, "BOTTOMRIGHT", -K.INSET, K.FOOTER_H)
    end
end

local function makeResizable(f)
    NS.MakeResizable(f, {
        minWidth     = K.MIN_WIDTH,
        minHeight    = K.MIN_HEIGHT,
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
    buildTitleBar(f)
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
--- @return table { tab, feed, filter, honors, ctx, matches = fn(drop), compare = fn(a, b) }
function Window.TabContext(tab)
    tab = tab or activeTab
    local FB = NS.WindowFilterBar
    local st, honors = FB.State(tab), FB.HONORS[tab]
    local feed = feedName()
    -- The placeholders ignore the situation, so This instance does not cut them (spec §11.6).
    local ctx = { instanceSince = feed ~= "test" and instanceSince or nil }
    -- Group drops lists your own loot only with `feed.showOwn` on; it goes to My drops.
    local own = tab ~= "group" or showOwn()
    return {
        tab = tab, feed = feed, filter = st, honors = honors, ctx = ctx,
        matches = function(drop) return FB.InGroup(drop, own) and FB.Matches(drop, st, ctx, honors) end,
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
    local mine = mineCount()
    for key, tab in pairs(frame.tabs) do
        local active = key == activeTab
        local c = active and C.GOLD or C.IDLE
        tab.label:SetText(Window.TabLabel(key, mine))
        tab.label:SetTextColor(c.r, c.g, c.b)
        tab.underline:SetShown(active)
    end
end

local function paintBadge()
    local text = Window.BadgeText(currentReason(), #queuedAsks())
    frame.badge.text:SetText(text or "")
    frame.badge:SetShown(text ~= nil)
end

-- The TEST MODE chip beside the title, the `n new` counter after it.
local function paintTestChip()
    local on = NS.State.testMode == true
    frame.testChip:SetShown(on)
    frame.newChip:ClearAllPoints()
    frame.newChip:SetPoint("LEFT", on and frame.testChip or frame.title, "RIGHT", 8, 0)
end

local function paintMinimized()
    local m = isMinimized()
    frame.body:SetShown(not m)
    if frame.resizeGrip then frame.resizeGrip:SetShown(not m) end
    if m then setMark(frame.minimizeButton, "add", "+") else setMark(frame.minimizeButton, "minimise", "-") end
    frame.newChip.text:SetText(L["%d new"]:format(newCount))
    frame.newChip:SetShown(m and newCount > 0)
end

--- One repaint pass: the title bar's badge and counter, the tabs, and (expanded) the banner, the
--- filter bar, the footer and the active tab's body.
function Window.Refresh()
    if not frame then return end
    local t0 = Perf.on and debugprofilestop()
    paintBadge()
    paintTestChip()
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

-- A countdown moved (TradeTimerTick, the footer ticker): only what shows one repaints, the My drops
-- tab while it is the active tab and the Offer panel while it is open; the Group drops table, the
-- filter bar and the footer are left alone.
repaintCountdown = function()
    if not (frame and frame:IsShown()) or isMinimized() then return end
    if activeTab == "mine" then refreshActive() end
    if NS.OfferPanel and NS.OfferPanel.IsShown() then NS.OfferPanel.Refresh() end
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
    if inCombat == nil then inCombat = UnitAffectingCombat("player") and true or false end
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

--- Scale, alpha, geometry and the minimized state from the current profile, then the show
--- decision. Run at stand-up, on a profile change and by the Master controls rows' reactions.
function Window.ApplySettings()
    if frame then
        applyLook()
        applySize()
        applyPoint()
    end
    Window.UpdateVisibility()
end

--- Reset position: forget the stored point and size, and put the window back where it started.
function Window.ResetPosition()
    local g = geometry()
    g.point, g.width, g.height = nil, nil, nil
    if frame then
        applySize()
        applyPoint()
    end
    NS.Print(L["window position reset"])
end

--- The built frame, or nil before the first show. For the suites and the diagnostics report.
function Window.Frame() return frame end

-- ── the bus ─────────────────────────────────────────────────────────────────────────────────

-- An interesting drop the Group drops table would list: what auto-open and `n new` count. Your own
-- loot counts only with `feed.showOwn` on; otherwise My drops · n is where it shows.
local function groupInteresting(rec)
    local FB = NS.WindowFilterBar
    return FB.InGroup(rec, showOwn()) and FB.IsInteresting(rec)
end

-- The first interesting live drop in a situation set to auto-open opens a closed window, once per
-- situation: closing it again is the player's choice (design spec §6.1). Master `autoOpen` false
-- turns it off everywhere.
local function maybeAutoOpen(rec)
    if rec.test or NS.State.windowOpen == true or setting("autoOpen") == false then return end
    local Sit = NS.Situations
    local key = Sit.Current()
    if autoOpenedIn == key or not Sit.ShouldAutoOpen(key) then return end
    if not groupInteresting(rec) then return end
    autoOpenedIn = key
    NS.Debug(TAG, "auto-open: the first interesting drop in %s", key)
    Window.Open()
end

local function onDropAdded(id)
    local rec = NS.LootFeed.Get(id)
    if not rec then return end
    maybeAutoOpen(rec)
    local inFeed = (rec.test == true) == (NS.State.testMode == true)
    if isMinimized() and inFeed and groupInteresting(rec) then newCount = newCount + 1 end
    scheduleRepaint()
end

local function onRestriction(reason)
    restrictionSeen, restrictionReason = true, reason
    scheduleRepaint()
end

local function onSituation()
    instanceSince = GetTime()
    autoOpenedIn = nil
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
        if frame then paintBadge() end
        scheduleRepaint()
    end)
    target:RegisterMessage(M.SITUATION_CHANGED, function() onSituation() end)
    target:RegisterMessage(M.DROP_ADDED, function(_, id) onDropAdded(id) end)
    target:RegisterMessage(M.DROP_UPDATED, function() scheduleRepaint() end)
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
