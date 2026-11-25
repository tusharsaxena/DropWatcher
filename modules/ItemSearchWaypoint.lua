local addonName, NS = ...
-- modules/ItemSearchWaypoint.lua — who draws the way to an Item Search pin (Item Search feedback spec
-- §6, W11 and W12; ISF-DW-07). WoW Forever's alone in use: the Item Search window's pins are its one
-- caller (modules/ItemSearchWindow.lua), and on Retail nothing calls it.
--
--   NS.ItemSearchWaypoint.Resolve(choice, tomtom, arrow)  pure: "tomtom" | "arrow" | nil
--   NS.ItemSearchWaypoint.Choice() / .Method() / .Set(spot, title) / .Clear() / .ArrowAvailable()
--   NS.ItemSearchWaypoint.Instance() / .ApplySettings() / .OpenSettings() / .SettingsRows(opts)
--   NS.ItemSearchWaypoint.PATHS / .CHOICES / .MethodLabel(how)
--
-- THE SETTING, `itemSearch.waypoints`: "auto" (the default: TomTom when it is loaded, else Drop
-- Watcher's arrow; the spec's W12 call, a player who installed TomTom chose it), "tomtom" or "arrow".
-- "tomtom" while TomTom is not loaded falls back to Drop Watcher's arrow, so a pin never does
-- nothing: the settings row's tooltip says so, and the pin's tooltip names the arrow it will use.
--
-- DROP WATCHER'S ARROW is LibKa0s-WaypointArrow-1.0 (vendored; docs/api/WaypointArrow/
-- version-3.3-docs.md is the contract), driven the way Skill Master's modules/WaypointArrow.lua
-- drives it: one instance built on first use, configured from the profile at PATHS
-- (`itemSearch.arrow.*`, each the library's own key name, the three "Use the skin's ..." companions
-- at their rows' paths plus "FromSkin"), its drag, lock and Reset position written back through the
-- write seam (NS.SchemaRuntime.Set), its right-click menu the library's with Arrow settings... added.
-- Within the library's arrival distance it clears itself and chat says so.
--
-- THE CLIENT'S OWN USER WAYPOINT (C_Map.SetUserWaypoint) IS NOT USED (spec §6): it draws no arrow
-- on WoW Forever. Every waypoint set prints one chat line (the window's ISW.SetPin).
--
-- Without the library major Drop Watcher's arrow is not available: "auto" and "arrow" then use
-- TomTom when it is loaded, else no pin shows.

NS.ItemSearchWaypoint = NS.ItemSearchWaypoint or {}
local WP = NS.ItemSearchWaypoint
local L  = NS.L

local Arrow = LibStub and LibStub("LibKa0s-WaypointArrow-1.0", true)

WP.FRAME_NAME = "DropWatcherWaypointArrow"
WP.SETTING    = "itemSearch.waypoints"
WP.DEFAULT    = "auto"
WP.CHOICES    = { "auto", "tomtom", "arrow" }
WP.PAGE       = "itemSearch"

local P = "itemSearch.arrow."
--- The profile paths the arrow's settings live at: each the library's key under itemSearch.arrow.
WP.PATHS = {
    style = P .. "style", useSkinColors = P .. "useSkinColors", farColor = P .. "farColor",
    nearColor = P .. "nearColor", scale = P .. "scale",
    font = P .. "font", fontSize = P .. "fontSize", fontColor = P .. "fontColor",
    useClassColorFont = P .. "useClassColorFont", fontFlags = P .. "fontFlags",
    fontShadow = P .. "fontShadow", textPosition = P .. "textPosition", showLabel = P .. "showLabel",
    distanceUnits = P .. "distanceUnits", x = P .. "x", y = P .. "y", lock = P .. "lock",
}

local inst
local target            -- { title, zone } of the arrow's waypoint, for the arrival line

-- ── the choice ──────────────────────────────────────────────────────────────────────────────

local VALID = {}
for _, v in ipairs(WP.CHOICES) do VALID[v] = true end

--- Who draws the way for `choice`, given whether TomTom is loaded and whether Drop Watcher's arrow
--- is there: "tomtom", "arrow", or nil (neither can). An unknown choice reads as "auto".
--- @param choice string|nil
--- @param tomtom boolean
--- @param arrow boolean
--- @return string|nil
function WP.Resolve(choice, tomtom, arrow)
    if not VALID[choice] then choice = WP.DEFAULT end
    if choice == "tomtom" and tomtom then return "tomtom" end
    if choice == "arrow" and arrow then return "arrow" end
    if choice == "auto" and tomtom then return "tomtom" end
    if arrow then return "arrow" end
    if tomtom then return "tomtom" end
    return nil
end

--- The stored choice ("auto" | "tomtom" | "arrow").
--- @return string
function WP.Choice()
    local v = NS.Setting and NS.Setting(WP.SETTING) or nil
    return VALID[v] and v or WP.DEFAULT
end

--- Whether Drop Watcher's arrow can draw (the library major is vendored and loaded).
--- @return boolean
function WP.ArrowAvailable() return Arrow ~= nil and type(Arrow.New) == "function" end

--- Who draws the next waypoint now: "tomtom", "arrow" or nil.
--- @return string|nil
function WP.Method()
    return WP.Resolve(WP.Choice(), NS.Compat.TomTomLoaded(), WP.ArrowAvailable())
end

--- The method's name as the pin's tooltip and the settings write it.
--- @param how string|nil
--- @return string
function WP.MethodLabel(how)
    if how == "tomtom" then return L["TomTom"] end
    if how == "arrow" then return L["Drop Watcher's arrow"] end
    return L["No arrow"]
end

-- ── the arrow ───────────────────────────────────────────────────────────────────────────────

local function setSetting(path, value)
    if NS.SchemaRuntime and NS.SchemaRuntime.Set then NS.SchemaRuntime.Set(path, value) end
    local S = NS.addon and NS.addon.Settings
    local H = S and S.Helpers
    if H and H.RefreshScalars then H.RefreshScalars() end
end

local function get(path) return NS.Setting(path) end

local function onArrive()
    local t = target
    target = nil
    if t then NS.Print(L["You have arrived: %s"]:format(t.title)) end
    NS.Debug("SEARCH", "waypoint arrow: arrived at %s", tostring(t and t.title))
end

-- The arrow is a HUD display of one icon, a body element whose window group is itself: its
-- tooltip opens beside it (NS.RowTooltip.PlaceOrFallback, LibKa0s-Tooltip-1.0's PlaceBeside), owned
-- at ANCHOR_NONE, in the skin's tooltip colors (skinning-§7), as every Drop Watcher tooltip is.
local function tipLine(text, token)
    local r, g, b = NS.Skin.Color(token)
    GameTooltip:AddLine(text, r, g, b, true)
end

local function onEnter(f)
    if not GameTooltip then return end
    GameTooltip:SetOwner(f, "ANCHOR_NONE")
    local r, g, b = NS.Skin.Color("gtip.title")
    GameTooltip:SetText(target and target.title or L["Waypoint"], r, g, b)
    if target and target.zone then tipLine(target.zone, "gtip.value") end
    local locked = inst ~= nil and inst:IsLocked()
    tipLine(locked and L["Right-click for options."] or L["Right-click for options. Drag to move the arrow."],
        "dw.tipHint")
    GameTooltip:Show()
    NS.RowTooltip.PlaceOrFallback(GameTooltip, f)
end

local function onLeave(f)
    if GameTooltip and GameTooltip:IsOwned(f) then GameTooltip:Hide() end
end

-- The library's words, keyed as its STRINGS: the distance, the sample's label and the menu.
local ARROW_STRINGS = {
    DISTANCE = L["%d yd"], DISTANCE_COMPACT = L["%.1fk yd"], SAMPLE = L["Waypoint"],
    MENU_CLEAR = L["Clear waypoint"], MENU_SHARE = L["Share in chat"], MENU_MAP = L["Show on map"],
    MENU_LOCK = L["Lock the arrow"], MENU_UNLOCK = L["Unlock the arrow"], MENU_RESET = L["Reset position"],
    MENU_SHARE_TIP = L["Opens the chat box with a /way line for this waypoint. Press Enter to send it to the channel the box is set to, or edit it first. Nothing is sent until you do."],
    MENU_NO_MAP = L["This waypoint has no map point to share or show."],
    MENU_COMBAT = L["Not available in combat."],
}

-- The library's menu, then Arrow settings... (off in combat, where the panel will not open).
local function menuItems(items)
    local combat = NS.Compat.InCombatLockdown()
    items[#items + 1] = { id = "settings", label = L["Arrow settings..."], disabled = combat,
        tooltip = combat and L["Not available in combat."]
            or L["Open Settings › Item Search › Waypoints, where the arrow's look, text and position are set."],
        onClick = function() WP.OpenSettings() end }
    return items
end

--- The library instance, built on first use (nil without the library).
--- @return table|nil
function WP.Instance()
    if inst or not WP.ArrowAvailable() then return inst end
    inst = Arrow:New({
        addon = addonName, name = WP.FRAME_NAME, skin = addonName,
        paths = WP.PATHS, set = setSetting,
        onEnter = onEnter, onLeave = onLeave, onArrive = onArrive,
        onClear = function() WP.Clear() end,
        menuItems = menuItems, strings = ARROW_STRINGS,
        debug = function(_, msg) NS.Debug("SEARCH", "waypoint arrow: %s", tostring(msg)) end,
    })
    inst:ConfigureFrom(get, WP.PATHS)
    return inst
end

--- The arrow's waypoint goes and the arrow hides.
function WP.Clear()
    target = nil
    if inst then inst:Clear() end
end

--- A settings row moved, a profile switch or a skin change: the arrow takes its settings again; a
--- choice that no longer draws Drop Watcher's arrow takes it down.
function WP.ApplySettings()
    if not inst then return end
    inst:ConfigureFrom(get, WP.PATHS)
    if WP.Method() ~= "arrow" then WP.Clear() end
end

--- The arrow's menu: the settings panel on Item Search's page.
function WP.OpenSettings()
    if NS.addon and NS.addon.OpenSettings then NS.addon:OpenSettings(WP.PAGE) end
end

-- ── setting a waypoint ──────────────────────────────────────────────────────────────────────

local function plain(v) return type(v) == "number" and v == v and not NS.Compat.IsSecret(v) end

--- Set a waypoint at `spot` ({ map, x, y }, x and y 0..1), named `title`, through Method(). Answers
--- the method used ("tomtom" | "arrow"), or nil when nothing could take it (no method, a spot the
--- arrow cannot place).
--- @param spot table|nil
--- @param title string|nil
--- @param zone string|nil the zone's name, for the arrow's tooltip
--- @return string|nil
function WP.Set(spot, title, zone)
    if type(spot) ~= "table" or not (plain(spot.map) and plain(spot.x) and plain(spot.y)) then return nil end
    local how = WP.Method()
    if how == "tomtom" then
        return NS.Compat.AddTomTomWaypoint(spot.map, spot.x, spot.y, title) and how or nil
    end
    if how ~= "arrow" then return nil end
    local a = WP.Instance()
    if not a then return nil end
    a:ConfigureFrom(get, WP.PATHS)
    target = { title = tostring(title or L["Waypoint"]), zone = zone }
    if a:SetTarget({ mapID = spot.map, x = spot.x, y = spot.y, label = target.title }) == false then
        target = nil
        return nil
    end
    NS.Debug("SEARCH", "waypoint arrow: %s at map %d", target.title, spot.map)
    return how
end

-- ── the settings rows ───────────────────────────────────────────────────────────────────────

--- The library's settings blocks (the look, the Text block, the Position block) at PATHS, each
--- row's change re-applying the settings. Answers the rows and the afterSubgroup hooks (the
--- Position block's Reset position button); `{}, {}` without the library.
--- @param opts table page, group, subgroup, textSubgroup, positionSubgroup, L, options
--- @return table, table
function WP.SettingsRows(opts)
    if not (Arrow and type(Arrow.SettingsRows) == "function") then return {}, {} end
    local o = {}
    for k, v in pairs(opts or {}) do o[k] = v end
    o.paths = WP.PATHS
    o.onChange = function() WP.ApplySettings() end
    o.onResetPosition = function() local a = WP.Instance(); if a then a:ResetPosition() end end
    local rows, hooks = Arrow.SettingsRows(o)
    return rows, hooks or {}
end

-- A skin switch: the built arrow takes its settings again (its skin-following colors and font).
if NS.Skin and type(NS.Skin.OnLooksChanged) == "function" then
    NS.Skin.OnLooksChanged(function() WP.ApplySettings() end)
end

-- A stand-down takes the arrow down.
NS.STAND_DOWN[#NS.STAND_DOWN + 1] = function() WP.Clear() end
