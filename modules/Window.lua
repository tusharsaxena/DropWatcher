local _, NS = ...
-- modules/Window.lua — the main window's shell: frame, skin, title bar, position, size, lock, scale,
-- alpha, the show decision and the test-mode banner (design spec §11.1).
--
-- A non-secure standalone window (standalone-windows): built lazily on the first show, skinned
-- through LibKa0s-Core's ApplySkin, closed by Escape (UISpecialFrames) and by the shared close mark
-- (NS.MakeCloseButton). The tab strip, filter bar, tables and footer arrive with the feature items;
-- until then the body says what the window will hold.
--
-- THE SHOW DECISION is one ladder, read in UpdateVisibility, and nothing else shows the frame:
--   0. stood down (the latch, which the perf harness's suspend also holds) -> hidden
--   1. General visibility `never`, or the combat condition not met       -> hidden
--   2. the player opened it this session (turning test mode on opens it)   -> shown
-- Test mode never pins the window open: Close, Toggle and Escape always win. Turning test mode on
-- opens a closed window and remembers that it did; turning it off closes the window again only
-- when test mode was what opened it.
-- Geometry (profile.window) is written here and nowhere else: by a drag, a resize and Reset position.

NS.Window = NS.Window or {}
local Window = NS.Window
local K      = NS.Constants.WINDOW
local L      = NS.L
local Perf   = NS.Perf

local frame   -- built on the first show
local openedByTestMode = false   -- test mode, not the player, opened the window
local visibilityListeners = {}   -- fn(shown), told on every OnShow and OnHide of the frame

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

local function applySize()
    local g = geometry()
    frame:SetSize(g.width or K.WIDTH, g.height or K.HEIGHT)
end

local function applyLook()
    frame:SetScale(setting("scale") or 1)
    frame:SetAlpha(setting("alpha") or 1)
end

-- ── construction ────────────────────────────────────────────────────────────────────────────

local function onDragStart()
    if isLocked() then return end
    frame:StartMoving()
end

local function onDragStop()
    frame:StopMovingOrSizing()
    savePoint()
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
    f.titleBar = bar

    f.title = bar:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    f.title:SetPoint("LEFT", bar, "LEFT", 10, 0)
    f.title:SetText(NS.BRAND)

    f.closeButton = NS.MakeCloseButton(bar, function() Window.Close() end)
    if f.closeButton then f.closeButton:SetPoint("RIGHT", bar, "RIGHT", -6, 0) end

    f.divider = f:CreateTexture(nil, "ARTWORK")
    f.divider:SetHeight(1)
    f.divider:SetPoint("TOPLEFT", bar, "BOTTOMLEFT", 0, 0)
    f.divider:SetPoint("TOPRIGHT", bar, "BOTTOMRIGHT", 0, 0)
end

local function buildBody(f)
    f.banner = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    f.banner:SetPoint("TOP", f.divider, "BOTTOM", 0, -8)
    f.banner:SetText(L["TEST MODE: placeholder drops, nothing is sent"])

    f.empty = f:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    f.empty:SetPoint("CENTER", f, "CENTER", 0, 0)
    f.empty:SetText(L["No drops yet. Loot your group receives appears here."])
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
    NS.MakeResizable(f, {
        minWidth     = K.MIN_WIDTH,
        minHeight    = K.MIN_HEIGHT,
        canResize    = function() return not isLocked() end,
        -- The anchor is saved with the size: sizing from the corner moves the frame's anchor, and a
        -- later ApplySettings re-anchors the stored size at the stored point.
        onResizeStop = function(width, height)
            saveSize(width, height)
            savePoint()
        end,
    })
    -- Escape closes it (standalone-windows); the frame is named, so the name is what the list holds.
    if type(UISpecialFrames) == "table" then tinsert(UISpecialFrames, K.NAME) end
    -- Hidden by Escape or the client's own close path: the player closed it.
    f:SetScript("OnHide", function()
        NS.State.windowOpen = false
        notifyVisibility(false)
    end)
    f:SetScript("OnShow", function() notifyVisibility(true) end)
    return f
end

local function ensureFrame()
    return frame or build()
end

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
    elseif frame and frame:IsShown() then
        -- Hidden by the ladder, not by the player: keep the player's choice for the next show.
        local open = NS.State.windowOpen
        frame:Hide()
        NS.State.windowOpen = open
    end
end

--- One repaint pass: the banner and the body text follow the current state.
function Window.Refresh()
    if not frame then return end
    local t0 = Perf.on and debugprofilestop()
    local test = NS.State.testMode == true
    frame.banner:SetShown(test)
    frame.empty:SetShown(not test)
    if t0 then Perf.Note("window.refresh", debugprofilestop() - t0) end
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

--- Scale, alpha and geometry from the current profile, then the show decision. Run at stand-up,
--- on a profile change and by the Master controls rows' reactions.
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
