local _, NS = ...
-- settings/ItemSearchRows.lua — the Item Search page's schema rows (Item Search spec §4.7, mockup
-- board 3, DropWatcher#17). WoW Forever's alone: on Retail Item Search has no row, no default and no
-- read (spec §1, clients-§4), so this file returns before it declares anything, and every row also
-- carries `clients` as settings/SchemaRows.lua's Forever-only rows do.
--
-- The page (`itemSearch`, settings/Pages.lua) draws three schema tabs and the library's Keybindings
-- host tab (settings/ItemSearchPage.lua), its rows in the Settings artboard's order (Item Search
-- feedback spec §9):
--   * Item tooltip: Add Item Search to item tooltips (the block's switch; with Item Search's
--     window switch it decides whether ForeverDB loads at all, spec §2), Comparison tooltips too,
--     Rows per section, Show the key hint, Only while holding Shift, Separator line, Show recipe
--     skill levels (round 3 spec §4.2, §5); then,
--     under Tooltip and window, Only professions you know (one switch for both, feedback spec §4);
--     then the sections' switches and Hide completed quests; then the section order, a drag list
--     (LibKa0s-Widgets-1.0 ReorderList, the widget set's reorder control) drawn by the page's
--     afterGroup over the `itemSearch.tooltip.order` map row (skipRender, written whole).
--   * Item Search window: its switch and the bar color (Use the skin's color, else the swatch
--     beside it). Density, Font size, Zone and level columns and Remember recent searches went in
--     ISF-DW-05 (feedback spec §5.1, §5.2, §5.4; schema step 17): the window's rows take the main
--     window's table font and row height, and every tab draws all its columns. The window has no
--     lock (W13) and remembers its size and last tab with no setting.
--   * Waypoints (ISF-DW-07, feedback spec §6): Waypoints (Automatic, TomTom or Drop Watcher's
--     arrow) and Waypoint pins; then Drop Watcher's arrow's own blocks, LibKa0s's
--     WaypointArrowSettings rows (settings/ItemSearchArrowRows.lua, after the Options instance).
-- Every `default` references defaults/Profile.lua (savedvariables-§2). The makers and checks are
-- settings/SchemaRows.lua's (Settings.RowMakers), so a row here is shaped like every other row.

local K = NS.Constants
if not K.FEATURE.itemSearch then return end

local DW       = NS.addon
local Settings = DW.Settings
local L        = NS.L
local M        = Settings.RowMakers
local D        = NS.C.PROFILE.itemSearch

local CLIENTS = K.FEATURE_CLIENTS.itemSearch
local PAGE = "itemSearch"

-- The tooltip block's sections, in their default order (NS.ItemSearchTip.ORDER), each with its
-- switch's label and tooltip. The section order list names them the same way.
local SECTIONS = {
    { key = "drops", label = L["Drops from"],
      tip = L["The creatures, objects and containers that drop the item, likeliest first, with their chance, and the level a world drop starts at."] },
    { key = "vendors", label = L["Sold by"],
      tip = L["The vendors that sell the item, with the lowest price seen."] },
    { key = "quests", label = L["Quests"],
      tip = L["The quests that ask for the item: in your log, not picked up yet, or completed."] },
    { key = "crafting", label = L["Crafting"],
      tip = L["The recipes the item is a reagent in, with the skill-up color your rank gives a recipe you know."] },
    { key = "skinned", label = L["Skinned from"],
      tip = L["The creatures the item is skinned from, likeliest first, with their chance."] },
    { key = "also", label = L["Reward from / starts quest"],
      tip = L["The quests that reward the item, and the quest the item starts."] },
}
Settings.ITEM_SEARCH_SECTIONS = SECTIONS

-- The section order's check: every entry a known section, none twice, at least one.
local KNOWN = {}
for _, s in ipairs(SECTIONS) do KNOWN[s.key] = true end
local function validOrder(v)
    if type(v) ~= "table" or #v == 0 then return false end
    local seen, n = {}, 0
    for _, key in pairs(v) do
        n = n + 1
        if not KNOWN[key] or seen[key] then return false end
        seen[key] = true
    end
    return n == #v
end
Settings.ValidSectionOrder = validOrder

-- A switch moved: Item Search loads ForeverDB now if it is wanted now (modules/ItemSearch.lua's
-- IS.Refresh), and the window closes once its switch is off.
local function refreshSearch()
    if NS.ItemSearch and NS.ItemSearch.Refresh then NS.ItemSearch.Refresh() end
end
local function windowSwitch()
    refreshSearch()
    local W = NS.ItemSearchWindow
    if W and not W.Available() then W.Close() end
end
local function repaintSearchWindow()
    local W = NS.ItemSearchWindow
    if W and W.ApplySettings then W.ApplySettings() end
end
-- "Only professions you know": the window's Crafting filter follows the setting again (spec §4).
local function followProfessions()
    local W = NS.ItemSearchWindow
    if W and W.FollowProfessionsSetting then W.FollowProfessionsSetting() else repaintSearchWindow() end
end

-- ── Item tooltip ────────────────────────────────────────────────────────────────────────────

local function tooltip()
    local T = D.tooltip
    local at = { page = PAGE, group = L["Item tooltip"], subgroup = L["Tooltip block"], clients = CLIENTS }
    local off = M.unless("itemSearch.tooltip.enabled", true)
    M.bool("itemSearch.tooltip.enabled", T.enabled, L["Add Item Search to item tooltips"],
        L["Under every item tooltip (your bags, chat links, the loot window, other addons' tooltips), say where the item drops, who sells it, its quests and its recipes. Needs the ForeverDB addon: without it the tooltip shows nothing of Item Search. ForeverDB loads a few seconds after login, out of combat, unless this and the Item Search window are both off."],
        M.with(at, { solo = true, onChange = refreshSearch }))
    local sub = M.with(at, { disabledIf = off })
    -- The block's rows in the Settings artboard's order (Item Search feedback spec §9): Comparison
    -- tooltips, Rows per section and Show the key hint, then Shift-only, the separator line and the
    -- recipe skill levels (round 3 spec §5).
    M.bool("itemSearch.tooltip.comparison", T.comparison, L["Comparison tooltips too"],
        L["Add the block to the comparison tooltips beside the item tooltip as well. Needs Add Item Search to item tooltips."], sub)
    M.slider("itemSearch.tooltip.rows", T.rows, NS.ItemSearch.TIP_ROWS_MIN, NS.ItemSearch.TIP_ROWS_MAX, 1,
        L["Rows per section"],
        L["How many rows each section of the tooltip shows, 1 to 20, before \"and N more\": drop sources, vendors, quests, recipes and skinned creatures alike. The Item Search window lists every one. Needs Add Item Search to item tooltips."],
        M.with(sub, { validate = M.wholeIn(NS.ItemSearch.TIP_ROWS_MIN, NS.ItemSearch.TIP_ROWS_MAX) }))
    M.bool("itemSearch.tooltip.hint", T.hint, L["Show the key hint"],
        L["Close the block with a line naming the key bound to Item Search and what it does. No line while the key is unbound. Needs Add Item Search to item tooltips."], sub)
    M.bool("itemSearch.tooltip.shiftOnly", T.shiftOnly, L["Only while holding Shift"],
        L["Add the block only while you hold Shift as the tooltip opens. Needs Add Item Search to item tooltips."], sub)
    M.bool("itemSearch.tooltip.header", T.header, L["Separator line"],
        L["Draw a thin line across the tooltip above Drop Watcher's block. Needs Add Item Search to item tooltips."], sub)
    M.bool("itemSearch.tooltip.craftSkill", T.craftSkill, L["Show recipe skill levels"],
        L["On each recipe row of the Crafting section, show the skill levels where the recipe turns yellow, green and gray (and its orange minimum), each in its color, in place of the profession's name. Needs Add Item Search to item tooltips."], sub)
    -- One switch for the tooltip and the window's Crafting tab (spec §4), under its own heading.
    M.bool("itemSearch.myProfessionsOnly", D.myProfessionsOnly, L["Only professions you know"],
        L["Show only the recipes of professions you have, in the tooltip and, to start with, in the Item Search window's Crafting tab. The tooltip counts the rest on one line. Until your skills are read, every recipe shows."],
        M.with(at, { subgroup = L["Tooltip and window"], onChange = followProfessions }))

    local sections = M.with(sub, { subgroup = L["Sections"] })
    for _, s in ipairs(SECTIONS) do
        M.bool("itemSearch.tooltip.sections." .. s.key, T.sections[s.key], s.label,
            s.tip .. " " .. L["Needs Add Item Search to item tooltips."], sections)
    end
    M.bool("itemSearch.tooltip.hideCompleted", T.hideCompleted, L["Hide completed quests"],
        L["Leave the quests you have completed out of the tooltip. The Item Search window still lists them. Needs Quests."],
        M.with(sections, {
            disabledIf = function() return off() or NS.Setting("itemSearch.tooltip.sections.quests") ~= true end }))
    -- The order the sections are written in: drawn by the page's drag list (settings/ItemSearchPage.lua),
    -- written whole through the seam.
    M.map("itemSearch.tooltip.order", T.order, validOrder, L["Section order"],
        L["The order the tooltip writes its sections in. Drag a section by its handle to move it."], sections)
end

-- ── Item Search window ──────────────────────────────────────────────────────────────────────

local function window()
    local W = D.window
    local at = { page = PAGE, group = L["Item Search window"], subgroup = L["Window"], clients = CLIENTS,
        onChange = repaintSearchWindow }
    M.bool("itemSearch.window.enabled", W.enabled, L["Enable the Item Search window"],
        L["The Item Search window: search an item by name or id and see every source, quest and recipe. Opened by the magnifier in the main window's title bar, the Item Search key or /dw search. Off, it does not open, and with the tooltip block off too ForeverDB is never loaded."],
        M.with(at, { solo = true, onChange = windowSwitch }))
    local bars = M.with(at, { subgroup = L["Bars"] })
    -- The swatch and its Use the skin's color companion on one line (options-ui-§17). No
    -- `disabledIf` on either (anti-pattern #74).
    M.add(M.with(bars, { path = "itemSearch.window.barColor", type = "color", default = W.barColor,
        label = L["Bar color"], startsLine = true, validate = M.isColor,
        tooltip = L["The color of the drop chance bars in DROPS FROM. Not read while Use the skin's color is on."] }))
    M.bool("itemSearch.window.barFromSkin", W.barFromSkin, L["Use the skin's color"],
        L["Draw the drop chance bars in the skin's accent color. Bar color, beside this, is not read while this is on."], bars)
end

-- ── Waypoints (Item Search feedback spec §6, §9) ────────────────────────────────────────────

-- Who draws the way to a pin, then the pins' switch. Drop Watcher's arrow's own rows
-- (LibKa0s-WaypointArrow-1.0's WaypointArrowSettings) follow on this tab, composed after the
-- Options instance exists (settings/ItemSearchArrowRows.lua).
Settings.ITEM_SEARCH_WAYPOINTS = L["Waypoints"]

local function waypoints()
    local at = { page = PAGE, group = Settings.ITEM_SEARCH_WAYPOINTS, subgroup = L["Waypoints"], clients = CLIENTS }
    local WP = NS.ItemSearchWaypoint
    M.pick(WP.SETTING, D.waypoints, M.choices({
        "auto", L["Automatic"], "tomtom", L["TomTom"], "arrow", L["Drop Watcher's arrow"],
    }), L["Waypoints"],
        L["Who points the way to a waypoint pin. Automatic uses TomTom when it is loaded, and Drop Watcher's arrow otherwise. TomTom needs the TomTom addon: while it is not loaded, Drop Watcher's arrow is used instead."],
        M.with(at, { onChange = function()
            WP.ApplySettings()
            repaintSearchWindow()
        end }))
    M.bool("itemSearch.window.pins", D.window.pins, L["Waypoint pins"],
        L["Show a map pin on each row of the Item Search window with a known spot. Clicking it sets a waypoint there, with the arrow Waypoints names."],
        M.with(at, { onChange = repaintSearchWindow }))
end

NS.SchemaRuntime.AddRows(M.Collect(function()
    tooltip()
    window()
    waypoints()
end))
