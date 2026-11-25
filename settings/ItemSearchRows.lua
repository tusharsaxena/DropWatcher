local _, NS = ...
-- settings/ItemSearchRows.lua — the Item Search page's schema rows (Item Search spec §4.7, mockup
-- board 3, DropWatcher#17). WoW Forever's alone: on Retail Item Search has no row, no default and no
-- read (spec §1, clients-§4), so this file returns before it declares anything, and every row also
-- carries `clients` as settings/SchemaRows.lua's Forever-only rows do.
--
-- The page (`itemSearch`, settings/Pages.lua) draws two schema tabs and the library's Keybindings
-- host tab (settings/ItemSearchPage.lua):
--   * Item tooltip: Add Item Search to item tooltips (the block's switch; with Item Search's
--     window switch it decides whether ForeverDB loads at all, spec §2), Only while holding Shift,
--     Separator and title line, Keybind hint line, Comparison tooltips too, Rows per section and
--     Only professions you know (Item Search feedback spec §4, §7); then the sections' switches and
--     Hide completed quests; then the section order, a drag list
--     (LibKa0s-Widgets-1.0 ReorderList, the widget set's reorder control) drawn by the page's
--     afterGroup over the `itemSearch.tooltip.order` map row (skipRender, written whole).
--   * Item Search window: its switch, the bar color (Use the skin's color, else the swatch beside
--     it), density, font size, the zone and level columns, the waypoint pins and the recent
--     searches.
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

local DENSITIES = M.choices{ "comfortable", L["Comfortable"], "compact", L["Compact"] }

-- ── Item tooltip ────────────────────────────────────────────────────────────────────────────

local function tooltip()
    local T = D.tooltip
    local at = { page = PAGE, group = L["Item tooltip"], subgroup = L["Tooltip block"], clients = CLIENTS }
    local off = M.unless("itemSearch.tooltip.enabled", true)
    M.bool("itemSearch.tooltip.enabled", T.enabled, L["Add Item Search to item tooltips"],
        L["Under every item tooltip (your bags, chat links, the loot window, other addons' tooltips), say where the item drops, who sells it, its quests and its recipes. Needs the ForeverDB addon: without it the tooltip shows nothing of Item Search. ForeverDB loads a few seconds after login, out of combat, unless this and the Item Search window are both off."],
        M.with(at, { solo = true, onChange = refreshSearch }))
    local sub = M.with(at, { disabledIf = off })
    M.bool("itemSearch.tooltip.shiftOnly", T.shiftOnly, L["Only while holding Shift"],
        L["Add the block only while you hold Shift as the tooltip opens. Needs Add Item Search to item tooltips."], sub)
    M.bool("itemSearch.tooltip.header", T.header, L["Separator and title line"],
        L["Open the block with a rule and the Drop Watcher · Item Search title, in the skin's accent. Needs Add Item Search to item tooltips."], sub)
    M.bool("itemSearch.tooltip.hint", T.hint, L["Keybind hint line"],
        L["Close the block with the Item Search key and what it does. Left out while the key is unbound. Needs Add Item Search to item tooltips."], sub)
    M.bool("itemSearch.tooltip.comparison", T.comparison, L["Comparison tooltips too"],
        L["Add the block to the comparison tooltips beside the item tooltip as well. Needs Add Item Search to item tooltips."], sub)
    M.slider("itemSearch.tooltip.rows", T.rows, NS.ItemSearch.TIP_ROWS_MIN, NS.ItemSearch.TIP_ROWS_MAX, 1,
        L["Rows per section"],
        L["How many rows each section of the tooltip shows, 1 to 20, before \"and N more\": drop sources, vendors, quests, recipes and skinned creatures alike. The Item Search window lists every one. Needs Add Item Search to item tooltips."],
        M.with(sub, { validate = M.wholeIn(NS.ItemSearch.TIP_ROWS_MIN, NS.ItemSearch.TIP_ROWS_MAX) }))
    M.bool("itemSearch.myProfessionsOnly", D.myProfessionsOnly, L["Only professions you know"],
        L["Show only the recipes of professions you have, in the tooltip and, to start with, in the Item Search window's Crafting tab. The tooltip counts the rest on one line. Until your skills are read, every recipe shows."],
        M.with(at, { onChange = repaintSearchWindow }))

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
    local rows = M.with(at, { subgroup = L["Rows"] })
    M.pick("itemSearch.window.density", W.density, DENSITIES, L["Density"],
        L["How tall the window's rows are: Comfortable or Compact."], rows)
    M.slider("itemSearch.window.fontSize", W.fontSize, 10, 16, 1, L["Font size"],
        L["The size of the window's text, 10 to 16."], M.with(rows, { validate = M.wholeIn(10, 16) }))
    M.bool("itemSearch.window.columns", W.columns, L["Zone and level columns"],
        L["Show the level and zone columns in DROPS FROM, SOLD BY and QUESTS."], rows)
    M.bool("itemSearch.window.pins", W.pins, L["Waypoint pins"],
        L["Show a pin on each row with a known spot. Clicking it sets a waypoint on the map, or a TomTom waypoint when TomTom is installed."], rows)
    M.bool("itemSearch.window.recent", W.recent, L["Remember recent searches"],
        L["List the last 10 items you looked at under the search box, on every character. Off, the list is hidden and nothing new is added."], rows)
end

NS.SchemaRuntime.AddRows(M.Collect(function()
    tooltip()
    window()
end))
