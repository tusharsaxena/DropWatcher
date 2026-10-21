local _, NS = ...
-- modules/WindowCompact.lua — compact mode's switch (compact spec §1, DW-C0): the window's two
-- layouts, `full` and `compact`, over ONE frame. Both read the same feed, filters, settings and
-- engine; only the presentation differs, and switching never changes what is recorded, gated,
-- judged or sent.
--
-- THE MODE. `window.mode` (a schema row: the Window page's Layout choice, the title-bar toggle,
-- `/dw compact` and `/dw full`, all through NS.SetWindowMode in core/DropWatcher.lua) is the stored
-- layout. The layout IN FORCE (Mode) is compact while the run override holds, else the stored one.
--
-- PER-MODE GEOMETRY. Each layout keeps its own size and point in `window.geometry.<mode>`
-- ({ point, width, height }); modules/Window.lua reads and writes them through Geometry, Size and
-- Point, and nowhere else. Compact defaults to 400 x 560, sized between 400 and 520 wide and 220
-- and 900 tall; until the player moves it, its point is the full window's top-right corner
-- (CornerPoint), so it opens where the eye already is. `minimized` stays shared.
--
-- THE RUN OVERRIDE (`window.compactInRuns`, on by default). An auto-open inside a dungeon, raid,
-- Mythic+ key or delve (RUN below) opens the compact layout whatever the stored mode
-- (NS.State.compactRun = { key }). The run ends when the situation moves off the one it began in
-- (leaving the instance), or LOOT_GRACE seconds after CHALLENGE_MODE_COMPLETED: a completed key
-- still reads as mythicPlus (difficulty 8 stays until the player leaves), so completion is its own
-- edge, and the chest's loot, which arrives after it, still belongs to the run (the feed groups it
-- the same way, modules/LootFeed.lua). When the grace runs out the situation is latched
-- (NS.State.compactRunSpent): no later auto-open there re-arms the override, until the situation
-- moves or a new key starts. A hidden window lets go at once; a shown one keeps its layout and
-- lets go when it is next hidden, so it returns to the stored mode the next time it opens. The
-- player's own choice (NS.SetWindowMode) lets go at once.
--
-- PURE: ValidMode, IsRun, Effective, DefaultSize, Bounds, ClampSize, CornerPoint. The edge: the
-- reads through NS.Setting and the profile, Apply (the frame's bounds, size and point), and the
-- override's bus receiver and visibility listener. In the compact layout the Drops tab draws cards
-- (modules/CompactGroup.lua, DW-C2), and History its own (modules/CompactHistory.lua, DW-C3).

NS.WindowCompact = NS.WindowCompact or {}
local WC = NS.WindowCompact
local K  = NS.Constants.WINDOW

local TAG = "UI"

--- The two layouts, in the Layout row's order.
WC.MODES = { "full", "compact" }
local MODE_SET = { full = true, compact = true }

-- The situations a run is (compact spec §1: a dungeon, raid, key or delve).
local RUN = {
    mythicPlus = true, dungeon = true, followerDungeon = true, raidLFR = true, raid = true, delve = true,
}

local SIZE = {
    full    = { K.WIDTH, K.HEIGHT },
    compact = { K.COMPACT_WIDTH, K.COMPACT_HEIGHT },
}

-- { minW, minH, maxW, maxH }; a nil maximum is the screen's (LibKa0s-Core's MakeResizable default).
local BOUNDS = {
    full    = { K.MIN_WIDTH, K.MIN_HEIGHT },
    compact = { K.COMPACT_MIN_W, K.COMPACT_MIN_H, K.COMPACT_MAX_W, K.COMPACT_MAX_H },
}

-- Each anchor point's place on a frame, as fractions of its width (from the left) and its height
-- (from the bottom).
local FRACTION = {
    TOPLEFT = { 0, 1 }, TOP = { 0.5, 1 }, TOPRIGHT = { 1, 1 },
    LEFT = { 0, 0.5 }, CENTER = { 0.5, 0.5 }, RIGHT = { 1, 0.5 },
    BOTTOMLEFT = { 0, 0 }, BOTTOM = { 0.5, 0 }, BOTTOMRIGHT = { 1, 0 },
}

local FALLBACK_SCREEN = 4096

local function num(v) return type(v) == "number" and v == v and v or nil end

-- ── pure ────────────────────────────────────────────────────────────────────────────────────

--- Whether `v` names a layout.
--- @param v any
--- @return boolean
function WC.ValidMode(v) return MODE_SET[v] == true end

--- Whether a situation key is a run (a dungeon, raid, key or delve), where the override applies.
--- @param key string|nil
--- @return boolean
function WC.IsRun(key) return RUN[key] == true end

--- The layout in force: compact while a run override holds, else the stored one (`full` for
--- anything unknown).
--- @param stored any the stored `window.mode`
--- @param inRun boolean|nil the run override holds
--- @return string
function WC.Effective(stored, inRun)
    if inRun then return "compact" end
    return MODE_SET[stored] and stored or "full"
end

--- A layout's default size: 1080 x 600 full, 400 x 560 compact; each is also its least width.
--- @param mode string
--- @return number width, number height
function WC.DefaultSize(mode)
    local s = SIZE[mode] or SIZE.full
    return s[1], s[2]
end

--- A layout's resize bounds. A nil maximum is the screen's.
--- @param mode string
--- @return number minW, number minH, number|nil maxW, number|nil maxH
function WC.Bounds(mode)
    local b = BOUNDS[mode] or BOUNDS.full
    return b[1], b[2], b[3], b[4]
end

local function clamp(v, lo, hi)
    if v < lo then return lo end
    if hi and v > hi then return hi end
    return v
end

--- A layout's size from what is stored: the default for anything not a number, and within the
--- layout's bounds.
--- @param mode string
--- @param width any
--- @param height any
--- @return number width, number height
function WC.ClampSize(mode, width, height)
    local dw, dh = WC.DefaultSize(mode)
    local minW, minH, maxW, maxH = WC.Bounds(mode)
    return clamp(num(width) or dw, minW, maxW), clamp(num(height) or dh, minH, maxH)
end

--- The point that puts a frame's top-right corner on the top-right corner of a `width` x `height`
--- frame anchored at `point` ({ point, relativePoint, x, y }, relative to UIParent): compact's
--- default place, at the full window's corner.
--- @param point table
--- @param width number
--- @param height number
--- @return table { "TOPRIGHT", relativePoint, x, y }
function WC.CornerPoint(point, width, height)
    local f = FRACTION[point[1]] or FRACTION.CENTER
    return { "TOPRIGHT", point[2] or "CENTER", (num(point[3]) or 0) + width * (1 - f[1]),
        (num(point[4]) or 0) + height * (1 - f[2]) }
end

-- ── reads ───────────────────────────────────────────────────────────────────────────────────

local EMPTY = {}

local function profileWindow()
    local db = NS.addon and NS.addon.db
    local p = db and db.profile
    if not p then return nil end
    if type(p.window) ~= "table" then p.window = {} end
    return p.window
end

--- The stored layout, `window.mode` (`full` for anything unknown).
--- @return string
function WC.StoredMode()
    return WC.Effective(NS.Setting("window.mode"), false)
end

--- The layout in force: compact while the run override holds, else the stored one.
--- @return string
function WC.Mode()
    return WC.Effective(NS.Setting("window.mode"), NS.State.compactRun ~= nil)
end

--- Whether the run override holds the window compact.
--- @return boolean
function WC.InRun() return NS.State.compactRun ~= nil end

--- One layout's stored geometry, `window.geometry.<mode>` ({ point, width, height }), the layout
--- in force when `mode` is nil. Without `create` an absent one reads as an empty table that is not
--- stored; with it, the table is made so a write lands.
--- @param mode string|nil
--- @param create boolean|nil
--- @return table
function WC.Geometry(mode, create)
    mode = MODE_SET[mode] and mode or WC.Mode()
    local w = profileWindow()
    if not w then return create and {} or EMPTY end
    if type(w.geometry) ~= "table" then
        if not create then return EMPTY end
        w.geometry = {}
    end
    local g = w.geometry[mode]
    if type(g) == "table" then return g end
    if not create then return EMPTY end
    g = {}
    w.geometry[mode] = g
    return g
end

--- A layout's size: the stored one within its bounds, else its default.
--- @param mode string|nil the layout in force when nil
--- @return number width, number height
function WC.Size(mode)
    mode = MODE_SET[mode] and mode or WC.Mode()
    local g = WC.Geometry(mode)
    return WC.ClampSize(mode, g.width, g.height)
end

--- A layout's point: the stored one; else the full window's default place, and compact's at the
--- full window's top-right corner.
--- @param mode string|nil the layout in force when nil
--- @return table { point, relativePoint, x, y }
function WC.Point(mode)
    mode = MODE_SET[mode] and mode or WC.Mode()
    local pt = WC.Geometry(mode).point
    if type(pt) == "table" then return pt end
    if mode == "full" then return K.POINT end
    local full = WC.Geometry("full").point
    return WC.CornerPoint(type(full) == "table" and full or K.POINT, WC.Size("full"))
end

--- Forget both layouts' stored point and size (Reset position).
function WC.ResetGeometry()
    local w = profileWindow()
    if w then w.geometry = nil end
end

-- ── the frame edge ──────────────────────────────────────────────────────────────────────────

local function screen()
    local w = UIParent and num(UIParent:GetWidth())
    local h = UIParent and num(UIParent:GetHeight())
    return w or FALLBACK_SCREEN, h or FALLBACK_SCREEN
end

--- The layout in force on `f`: its resize bounds, then its size (modules/Window.lua's applySize
--- sets it, minimized or not).
--- @param f table the window frame
--- @return number width, number height
function WC.Fit(f)
    local mode = WC.Mode()
    local minW, minH, maxW, maxH = WC.Bounds(mode)
    local sw, sh = screen()
    f:SetResizeBounds(minW, minH, maxW or math.max(sw, minW), maxH or math.max(sh, minH))
    return WC.Size(mode)
end

--- Lay the built window out in the layout in force: its bounds, size and point (Window.ApplyLayout,
--- never the show decision, so a layout change neither opens nor closes the window), the filter
--- bar's width and one repaint (the title bar's toggle mark with it). Before the first show it does
--- nothing: the build reads the layout itself.
function WC.Apply()
    local W = NS.Window
    local f = W.Frame()
    if not f then return end
    W.ApplyLayout()
    NS.WindowFilterBar.Layout(f:GetWidth())
    W.Refresh()
end

--- The stored layout changed (the `window.mode` row's reaction): the player chose, so a run
--- override lets go, and the window takes the layout.
function WC.OnModeChanged()
    NS.State.compactRun = nil
    NS.Debug(TAG, "layout -> %s", WC.Mode())
    WC.Apply()
end

-- ── the run override ────────────────────────────────────────────────────────────────────────

--- An auto-open is about to happen in situation `key` (modules/Window.lua's auto-open): inside a
--- run, with `window.compactInRuns` on, the window opens compact until the run ends.
--- @param key string|nil
--- @return boolean held whether the override holds now
function WC.OnAutoOpen(key)
    if not WC.IsRun(key) or NS.Setting("window.compactInRuns") == false then return false end
    if NS.State.compactRunSpent == key then return false end
    NS.State.compactRun = { key = key }
    NS.Debug(TAG, "auto-open in %s: compact for the run", tostring(key))
    WC.Apply()
    return true
end

local function release()
    if NS.State.compactRun == nil then return end
    NS.State.compactRun = nil
    NS.Debug(TAG, "the run ended: layout -> %s", WC.Mode())
    WC.Apply()
end

-- The run has ended: a hidden window lets go now; a shown one when it is next hidden.
local function endRun()
    local run = NS.State.compactRun
    if not run or run.ended then return end
    if NS.Window.IsShown() then
        run.ended = true
        return
    end
    release()
end

-- The completion's grace timer (a C_Timer handle), nil when none runs.
local graceTimer

local function cancelGrace()
    if graceTimer then graceTimer:Cancel() end
    graceTimer = nil
end

--- The situation moved to `key`: the completion latch and its timer clear, and off the run's
--- situation the run has ended.
--- @param key string|nil
function WC.OnSituationChanged(key)
    if NS.State.compactRunSpent ~= key then NS.State.compactRunSpent = nil end
    local run = NS.State.compactRun
    if run and key ~= run.key then
        cancelGrace()
        endRun()
    end
end

--- The completed key's grace ran out in situation `key`: the run is over, and that situation is
--- latched so no later auto-open in the same instance re-arms the override.
--- @param key string the situation the key completed in
function WC.OnRunGraceEnded(key)
    graceTimer = nil
    if NS.Situations.Current() ~= key then return end
    NS.State.compactRunSpent = key
    NS.Debug(TAG, "key over in %s: no compact until the situation moves", tostring(key))
    endRun()
end

--- CHALLENGE_MODE_COMPLETED: the key is over, though the situation still reads mythicPlus until the
--- player leaves. The chest's loot is still the run's: the run ends LOOT_GRACE seconds from now.
function WC.OnRunCompleted()
    cancelGrace()
    local key = NS.Situations.Current()
    graceTimer = C_Timer.NewTimer(NS.LootFeed.LOOT_GRACE, function() WC.OnRunGraceEnded(key) end)
end

--- CHALLENGE_MODE_START: a new key is a new run, so the completion latch and its timer clear.
function WC.OnRunStarted()
    cancelGrace()
    NS.State.compactRunSpent = nil
end

-- Hidden by the player or the ladder (not a parent's hide: the frame's own flag is still set):
-- a run that has ended lets go, so the next open is the stored layout.
NS.Window.AddVisibilityListener(function(shown)
    local run = NS.State.compactRun
    if shown or not (run and run.ended) or NS.Window.IsShown() then return end
    release()
end)

-- CHALLENGE_MODE_START and CHALLENGE_MODE_COMPLETED are shared with modules/Situations.lua and
-- modules/LootFeed.lua (core/DropWatcher.lua's dispatcher); the situation's rows come first, so
-- Situations.Current is fresh here.
NS.FEATURE_EVENTS[#NS.FEATURE_EVENTS + 1] = { "CHALLENGE_MODE_START", "OnCompactRunStart" }
NS.FEATURE_EVENTS[#NS.FEATURE_EVENTS + 1] = { "CHALLENGE_MODE_COMPLETED", "OnCompactRunEnd" }
function NS.addon.OnCompactRunStart() WC.OnRunStarted() end
function NS.addon.OnCompactRunEnd() WC.OnRunCompleted() end

-- Tracked, so the stand-down takes it down and the stand-up replays it (Window.lua's pattern).
local target = NS.Bus:NewTarget()

local function listen()
    if not target then return end
    target:RegisterMessage(NS.MSG.SITUATION_CHANGED, function(_, key) WC.OnSituationChanged(key) end)
end
listen()

NS.STAND_DOWN[#NS.STAND_DOWN + 1] = function()
    NS.State.compactRun = nil
    NS.State.compactRunSpent = nil
    cancelGrace()
    if target and not NS.Bus.tracked then target:UnregisterAllMessages() end
end
NS.STAND_UP[#NS.STAND_UP + 1] = function()
    if not NS.Bus.tracked then listen() end
end
