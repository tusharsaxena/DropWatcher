local _, NS = ...
-- settings/ListEditors.lua — Drops › Item lists (issue #13, categories design spec §5.1): the host tab
-- that edits the Always watch and Never watch item lists (`feed.whitelist`, `feed.blacklist`).
--
-- A secondary strip, Always watch | Never watch, over one LibKa0s IdList (`kind = "item"`): its add
-- box takes an item ID, a shift-clicked link or the name of an item the client or the candidates
-- know, and each entry is drawn with its icon and name. The selection is session state per primary
-- tab, `ctx.activeSubTab[L["Item lists"]]`, healed when it names no list (options-ui-§13).
--
-- The widget never writes a path: its onAdd and onRemove call NS.ItemLists (modules/ItemLists.lua),
-- the lists' one writer, which the CLI's `/dw whitelist|blacklist` shares. A refusal (the ID is on
-- the other list, or already on this one) is raised again as its sentence, so IdList keeps the
-- typed text and says why under the box. The writer's seam write repaints only the scalar widgets
-- (RefreshScalars), so nothing releases the box under IdList; its own redraw then goes through
-- `ctx.rebuild`, this page alone. Kept out of settings/PageEditors.lua, which the plan keeps small.

local DW       = NS.addon
local Settings = DW.Settings
local L        = NS.L

local LE = {}
Settings.ListEditors = LE

--- The primary tab's key: the map rows' `group` (settings/SchemaRows.lua) and the key
--- `ctx.activeSubTab` files this tab's selection under.
LE.TAB = L["Item lists"]

--- The secondary strip, in order: the stored list's name (NS.ItemLists.LISTS), the sub-tab's label and
--- the blurb above its list.
LE.SUBTABS = {
    { key = "whitelist", label = L["Always watch"],
      desc = L["Always watched, whatever its kind, its quality or the minimum item level; the Situations tab still decides where drops are watched. Applies to drops from now on. An item can be on one list only: remove it from the other first."] },
    { key = "blacklist", label = L["Never watch"],
      desc = L["Never watched, gear included, whatever would show it otherwise. Applies to drops from now on. An item can be on one list only: remove it from the other first."] },
}

local NAME_HINT = L["Names work for items you carry (or carried this session), items on either list and items in this session's drops; otherwise use the ID or shift-click a link."]

local function H() return Settings.Helpers end

-- Every AceGUI widget this file acquires itself, painted for this addon's skin (skinning-§3), as
-- settings/PageEditors.lua's are.
local function acquire(wtype)
    local w = H().AceGUI:Create(wtype)
    NS.SkinPaintAce(w)
    return w
end

--- The sub-tab to show: `want` when it names a list, else the first (a stale pointer heals).
--- @param want any
--- @return string key
function LE.PickSubTab(want)
    for _, tab in ipairs(LE.SUBTABS) do
        if tab.key == want then return want end
    end
    return LE.SUBTABS[1].key
end

--- `list`'s IDs as IdList's entries, in ID order.
--- @param list string
--- @return table entries
function LE.Entries(list)
    local out = {}
    for i, id in ipairs(NS.ItemLists.List(list)) do out[i] = { id = id } end
    return out
end

--- The IDs a typed name may match beyond the client's own lookup: both lists' IDs, then the item of
--- every drop in this session's feed, newest first, each once. Read only; stores nothing.
--- @return table ids
function LE.Candidates()
    local out, seen = {}, {}
    local function take(id)
        if type(id) == "number" and not seen[id] then
            seen[id] = true
            out[#out + 1] = id
        end
    end
    for _, tab in ipairs(LE.SUBTABS) do
        for _, id in ipairs(NS.ItemLists.List(tab.key)) do take(id) end
    end
    local LF = NS.LootFeed
    local drops = LF and LF.Drops and LF.Drops("live") or {}
    for i = #drops, 1, -1 do take(drops[i].itemID) end
    return out
end

--- Call NS.ItemLists' `verb` (`Add` or `Remove`) on `list`; a refusal is raised as its sentence, so
--- IdList keeps the typed text and prints the line.
--- @param list string
--- @param verb string
--- @param id number
function LE.Write(list, verb, id)
    local IL = NS.ItemLists
    local ok, why = IL[verb](list, id)
    if not ok then error(IL.WhyText(list, why), 0) end
end

-- `text` in the panel's `text.disabled` gray (808080 on Ka0s Default), read when the tab renders:
-- the live skin's while the panel is skinned, Ka0s Default's while it is ignored (NS.SkinPanelColor).
local function grayed(text)
    local r, g, b = NS.SkinPanelColor("text.disabled")
    if type(r) ~= "number" then return text end
    local function byte(v) return math.floor(v * 255 + 0.5) end
    return ("|cff%02x%02x%02x"):format(byte(r), byte(g), byte(b)) .. text .. "|r"
end

local function drawStrip(ctx, scroll, key)
    local h = H()
    local host = acquire("SimpleGroup")
    host:SetLayout(nil)
    host:SetFullWidth(true)
    scroll:AddChild(host)
    local tabs = {}
    for i, tab in ipairs(LE.SUBTABS) do tabs[i] = { key = tab.key, label = tab.label } end
    local _, height = h.SubTabStrip(ctx, host.frame, {
        tabs = tabs, value = key,
        onSelect = function(k)
            if k == ctx.activeSubTab[LE.TAB] then return end
            ctx.activeSubTab[LE.TAB] = k
            h.RefreshPanel(ctx, true)
        end,
    })
    host:SetHeight(height or 0)
    h.AddSpacer(scroll, 6)
end

local function drawList(ctx, scroll, tab)
    local h = H()
    local blurb = acquire("Label")
    blurb:SetFullWidth(true)
    blurb:SetText(tab.desc)
    scroll:AddChild(blurb)
    h.AddSpacer(scroll, 6)
    h.IdList(ctx, {
        kind = "item", columns = 2, removeStyle = "icon",
        label = L["Add an item by ID, link or name"],
        tooltip = L["Type an item ID or an item's name, or shift-click an item link into the box."] .. " " .. NAME_HINT,
        candidates = LE.Candidates,
        strings = { nameHint = NAME_HINT },
        entries = function() return LE.Entries(tab.key) end,
        onAdd = function(id) LE.Write(tab.key, "Add", id) end,
        onRemove = function(id) LE.Write(tab.key, "Remove", id) end,
        emptyText = grayed(L["(none)"]),
    })
end

--- Drops › Item lists: the secondary strip, then the selected list's blurb and its IdList.
--- @param ctx table
function LE.ItemListsTab(ctx)
    local scroll = H().EnsureScroll(ctx)
    if not scroll then return end
    ctx.activeSubTab = ctx.activeSubTab or {}
    local key = LE.PickSubTab(ctx.activeSubTab[LE.TAB])
    ctx.activeSubTab[LE.TAB] = key
    drawStrip(ctx, scroll, key)
    for _, tab in ipairs(LE.SUBTABS) do
        if tab.key == key then drawList(ctx, scroll, tab) end
    end
    ctx.rebuild = function() H().RefreshPanel(ctx, true) end
end
