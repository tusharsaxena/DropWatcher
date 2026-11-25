local _, NS = ...
-- settings/ItemSearchArrowRows.lua — Drop Watcher's arrow's settings rows on the Item Search page's
-- Waypoints tab (Item Search feedback spec §6, §9; ISF-DW-07). WoW Forever's alone, as the page is.
--
-- The rows are LibKa0s-WaypointArrow-1.0's own (WaypointArrowSettings, docs/api/WaypointArrow/
-- version-3.3-docs.md), the same blocks Skill Master shows, composed by Drop Watcher's Options
-- instance (Settings.Helpers), so this file loads after settings/OptionsSetup.lua: the look (Arrow
-- style, Use the skin's colors, Far color, Near color, Arrow scale) under Waypoint arrow, the Text
-- block (the canonical Font block with its Use the skin's font, color and shadow companions, Text
-- position, Show the target's name, Distance units) under Arrow text, and the Position block (X
-- offset, Y offset, Lock the arrow, and the Reset position button, an afterSubgroup hook that
-- settings/Pages.lua hands to the page's render) under Arrow position. Each row is at
-- NS.ItemSearchWaypoint.PATHS (`itemSearch.arrow.*`), its default from defaults/Profile.lua's
-- `itemSearch.arrow` (the library's DEFAULTS), and takes settings/SchemaRows.lua's checks here (the
-- library emits none).
--
-- SHOWN WHEN DROP WATCHER'S ARROW CAN BE THE ONE USED (spec §9): every row is drawn disabled while
-- Waypoints resolves to TomTom (Automatic with TomTom loaded, or TomTom), on top of the library's own
-- dimming (the swatches while the skin's colors are drawn, the font picker while the skin's font is).
--
-- Without the library major there is no arrow and no row.

local K = NS.Constants
if not K.FEATURE.itemSearch then return end

local DW       = NS.addon
local Settings = DW.Settings
local L        = NS.L
local Check    = Settings.Checks
local WP       = NS.ItemSearchWaypoint
local CLIENTS  = K.FEATURE_CLIENTS.itemSearch

-- The library's rows' words (its SETTINGS_STRINGS keys), in Drop Watcher's locale.
local WORDS = {
    STYLE = L["Arrow style"],
    STYLE_TIP = L["How the arrow is drawn. Raised floats over the world on a soft shadow; On the ground lies flat, tilted toward you."],
    STYLE_FLAT = L["Flat"], STYLE_RIDGE = L["Ridge"], STYLE_RAISED = L["Raised"], STYLE_FACETED = L["Faceted"],
    STYLE_GROUND = L["On the ground"],
    USE_SKIN = L["Use the skin's colors"],
    USE_SKIN_TIP = L["The arrow fades from the skin's accent color, far away, to its good color as you arrive. Off: your own two colors."],
    FAR = L["Far color"], FAR_TIP = L["The arrow's color 300 yards away or more. Not read while Use the skin's colors is on."],
    NEAR = L["Near color"], NEAR_TIP = L["The arrow's color 30 yards away or closer. Not read while Use the skin's colors is on."],
    SCALE = L["Arrow scale"], SCALE_TIP = L["The size of the arrow and its distance, 0.5 to 2."],
    FONT = L["Font"], FONT_TIP = L["The face the arrow's distance is drawn in."],
    FONT_SIZE = L["Font size"], FONT_SIZE_TIP = L["Height of the arrow's distance, in points."],
    FONT_COLOR = L["Font color"], FONT_COLOR_TIP = L["The color the arrow's distance is drawn in."],
    CLASS_COLOR = L["Use class color"],
    CLASS_COLOR_TIP = L["Draw the arrow's distance in your class color instead of the swatch beside it."],
    FONT_SHADOW_TIP = L["Draw a soft shadow behind the arrow's distance, for legibility over bright art."],
    FONT_SKIN_TIP = L["Draw the arrow's distance in the skin's font. The font picker is not read while this is on."],
    TEXT_POSITION = L["Text position"],
    TEXT_POSITION_TIP = L["Where the distance sits beside the arrow, or Hidden for the arrow alone."],
    POS_BELOW = L["Below"], POS_ABOVE = L["Above"], POS_LEFT = L["Left"], POS_RIGHT = L["Right"], POS_HIDDEN = L["Hidden"],
    SHOW_LABEL = L["Show the target's name"],
    SHOW_LABEL_TIP = L["A second line under the distance with the name of the source the arrow points to."],
    UNITS = L["Distance units"], UNITS_TIP = L["Yards, or thousands of yards from 1000 on (4.2k yd)."],
    UNITS_YARDS = L["Yards"], UNITS_COMPACT = L["Compact"],
    POSITION = L["Arrow position"],
    X_OFFSET = L["X offset"],
    X_TIP = L["How far right of the screen's center the arrow sits; the Arrow scale does not move it. Dragging the arrow sets it."],
    Y_OFFSET = L["Y offset"],
    Y_TIP = L["How far above the screen's center the arrow sits; the Arrow scale does not move it. Dragging the arrow sets it."],
    LOCK = L["Lock the arrow"],
    LOCK_TIP = L["While on, the arrow cannot be dragged. Its right-click menu still opens."],
    RESET_POSITION = L["Reset position"], RESET_POSITION_TIP = L["Put the arrow back at its default position."],
}

--- Whether Drop Watcher's arrow is not the one a pin would use now (Waypoints resolves to TomTom).
--- @return boolean
local function tomtomDraws() return WP.Method() == "tomtom" end

-- The library's own dimming (a path or a predicate), with TomTom's on top.
local function dimmed(own)
    return function(row)
        if tomtomDraws() then return true end
        if type(own) == "string" then return NS.Setting(own) == true end
        if type(own) == "function" then return own(row) == true end
        return false
    end
end

-- A value one of the row's own choices: an ordered { value, text } list or a value -> label map.
local function inValues(values)
    return function(v)
        if v == nil or type(values) ~= "table" then return false end
        if values[v] ~= nil then return true end
        for _, e in ipairs(values) do
            if type(e) == "table" and e.value == v then return true end
        end
        return false
    end
end

--- The check a library row takes by its type.
--- @param row table
--- @return function
local function checkOf(row)
    if row.type == "bool" then return Check.isBool end
    if row.type == "number" then return Check.inRange(row.min or -math.huge, row.max or math.huge) end
    if row.type == "color" then return Check.isColor end
    -- The font picker's values are LibSharedMedia's, which another addon may not have registered
    -- yet at load: a face is any name, as Window › Layout's tables' font takes it.
    if row.key == "font" then return Check.nonEmptyString end
    if row.values then return inValues(row.values) end
    return Check.nonEmptyString
end

local rows, hooks = WP.SettingsRows({
    page = "itemSearch", group = Settings.ITEM_SEARCH_WAYPOINTS, subgroup = L["Waypoint arrow"],
    textSubgroup = L["Arrow text"], positionSubgroup = WORDS.POSITION, L = WORDS,
    options = Settings.Helpers,
    encodeColor = function(r, g, b, a) return { r = r, g = g, b = b, a = a or 1 } end,
})

local D = NS.C.PROFILE.itemSearch.arrow
for _, row in ipairs(rows) do
    row.clients = CLIENTS
    -- The default is defaults/Profile.lua's (savedvariables-§2), which holds the library's DEFAULTS.
    local tail = type(row.path) == "string" and row.path:match("([^%.]+)$") or nil
    if tail and D[tail] ~= nil then row.default = D[tail] end
    row.validate = row.validate or checkOf(row)
    row.tooltip = row.tooltip or row.desc
    row.disabledIf = dimmed(row.disabledIf)
end
NS.SchemaRuntime.AddRows(rows)

--- The Position block's Reset position button, keyed by its subgroup, for the page's render.
Settings.ITEM_SEARCH_ARROW_HOOKS = hooks or {}
