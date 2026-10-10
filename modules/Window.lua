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
--   2. the player opened it this session, or test mode is on              -> shown
-- Geometry (profile.window) is written here and nowhere else: by a drag, a resize and Reset position.

NS.Window = NS.Window or {}
local Window = NS.Window
local K      = NS.Constants.WINDOW
local L      = NS.L
local Perf   = NS.Perf

local frame   -- built on the first show

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
        onResizeStop = saveSize,
    })
    -- Escape closes it (standalone-windows); the frame is named, so the name is what the list holds.
    if type(UISpecialFrames) == "table" then tinsert(UISpecialFrames, K.NAME) end
    -- Hidden by Escape or the client's own close path: the player closed it.
    f:SetScript("OnHide", function() NS.State.windowOpen = false end)
    return f
end

local function ensureFrame()
    return frame or build()
end

-- ── the show decision ───────────────────────────────────────────────────────────────────────

local function combatAllows()
    local v = setting("visibility") or "always"
    if v == "never" then return false end
    if v == "always" then return true end
    local inCombat = UnitAffectingCombat("player") and true or false
    if v == "inCombat" then return inCombat end
    return not inCombat
end

--- Whether the window should be on screen now, by the ladder above.
--- @return boolean
function Window.ShouldShow()
    if NS.IsStoodDown() then return false end
    if not combatAllows() then return false end
    return NS.State.windowOpen == true or NS.State.testMode == true
end

--- Apply the show decision. Builds the frame only when it is about to be shown.
function Window.UpdateVisibility()
    local want = Window.ShouldShow()
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
    Window.UpdateVisibility()
end

function Window.Close()
    NS.State.windowOpen = false
    Window.UpdateVisibility()
end

function Window.Toggle()
    if Window.IsShown() then Window.Close() else Window.Open() end
end

--- @return boolean
function Window.IsShown()
    return frame ~= nil and frame:IsShown() == true
end

--- Test mode turned on or off (core/DropWatcher.lua NS.SetTestMode): show or repaint.
function Window.OnTestModeChanged()
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
