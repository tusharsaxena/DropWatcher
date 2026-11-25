local addonName, NS = ...
-- settings/ItemSearchPage.lua — the Item Search page's two host pieces (Item Search spec §4.7,
-- mockup board 3, DropWatcher#17), WoW Forever's alone: settings/Pages.lua registers the page only
-- where C.FEATURE.itemSearch is true, and this file publishes nothing on Retail.
--
--   Settings.ItemSearchPage.SectionOrder  Item tooltip's afterGroup: the section order as a drag
--                                         list (LibKa0s-Widgets-1.0 ReorderList, the widget set's
--                                         reorder control, options-ui-§18), a row per section in
--                                         the stored order. A drop writes the whole order through
--                                         the seam (`itemSearch.tooltip.order`, a map row).
--   Settings.ItemSearchPage.Park          the page's beforeClear: stops a drag in flight and hands
--                                         the list's handles and row boxes back (the controller's
--                                         Cancel), then parks the list's host off its placeholder.
--   Settings.ItemSearchPage.KeybindTab    the Keybindings host tab: the library's key editor
--                                         (O.KeybindingsTab, options-ui-§20) over the Item Search
--                                         row of NS.BINDINGS alone, the same row General >
--                                         Keybindings draws, so the key is shown and changed the
--                                         way the window toggle's is.
--
-- THE HOST IS BUILT ONCE and re-parented to a fresh AceGUI placeholder on each render, as Drops ›
-- Situations' table is (settings/PageEditors.lua): its rows are raw frames, and a raw frame left on
-- a released AceGUI container would ride it into whatever AceGUI hands that container to next. The
-- placeholder's own OnRelease parks it (options-ui-§19, the canonical undo); beforeClear parks it
-- too. The ReorderList controller lives for one render: Park cancels it BEFORE the page clears,
-- because the controller's handles and boxes sit on the host's row frames.

local K = NS.Constants
if not K.FEATURE.itemSearch then return end

local DW       = NS.addon
local Settings = DW.Settings
local L        = NS.L

local ISP = {}
Settings.ItemSearchPage = ISP

ISP.ORDER_PATH = "itemSearch.tooltip.order"
ISP.ROW_H      = 24   -- a row's box
ISP.STRIDE     = 28   -- top of a row to the next row's top: the drop arithmetic's step
local HANDLE_W_FALLBACK = 30
local LABEL_GAP = 8

local function H() return Settings.Helpers end

local function widgets()
    local W = LibStub and LibStub("LibKa0s-Widgets-1.0", true)
    return (W and W.ReorderList) and W or nil
end

local function labelOf(key)
    for _, s in ipairs(Settings.ITEM_SEARCH_SECTIONS) do
        if s.key == key then return s.label end
    end
    return key
end

-- ── pure ────────────────────────────────────────────────────────────────────────────────────

--- `order` with its `from`th entry moved to `to` (a fresh table; `order` is not changed). An
--- index outside the list leaves the order as it was.
--- @param order table
--- @param from number
--- @param to number
--- @return table
function ISP.Moved(order, from, to)
    local out = {}
    for i, key in ipairs(order) do out[i] = key end
    if type(from) ~= "number" or type(to) ~= "number" or not out[from] then return out end
    local key = table.remove(out, from)
    table.insert(out, math.max(1, math.min(#out + 1, to)), key)
    return out
end

--- The sections in the order the tooltip writes them (NS.ItemSearchTip.Options' order: the stored
--- one, known keys once each, any missing key after it in the default order).
--- @return table
function ISP.Order()
    return NS.ItemSearchTip.Options().order
end

--- Move one section and store the whole order through the seam. Answers the seam's answer.
--- @param from number
--- @param to number
function ISP.Move(from, to)
    if from == to then return true end
    return NS.SchemaRuntime.Set(ISP.ORDER_PATH, ISP.Moved(ISP.Order(), from, to))
end

-- ── the list ────────────────────────────────────────────────────────────────────────────────

local function gutter()
    local W = widgets()
    return (W and W.ROW_BOX and W.ROW_BOX.HANDLE_W) or HANDLE_W_FALLBACK
end

local function buildHost(ctx)
    local host = CreateFrame("Frame", nil, ctx.panel)
    host:Hide()
    local t = { host = host, rows = {} }
    for i = 1, #Settings.ITEM_SEARCH_SECTIONS do
        local row = CreateFrame("Frame", nil, host)
        row:SetHeight(ISP.ROW_H)
        row:SetPoint("TOPLEFT", host, "TOPLEFT", 0, -(i - 1) * ISP.STRIDE)
        row:SetPoint("TOPRIGHT", host, "TOPRIGHT", 0, -(i - 1) * ISP.STRIDE)
        row.label = row:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        row.label:SetPoint("LEFT", row, "LEFT", gutter() + LABEL_GAP, 0)
        row.label:SetJustifyH("LEFT")
        t.rows[i] = row
    end
    return t
end

-- Each row names its section, in the order the tooltip writes them, in the panel's body color.
local function paintRows(t)
    local order = ISP.Order()
    for i, row in ipairs(t.rows) do
        row.key = order[i]
        row.label:SetText(labelOf(order[i]))
        local r, g, b = NS.SkinPanelColor("text.body")
        if r then row.label:SetTextColor(r, g, b) end
    end
end

-- One controller for this render over the five rows; a drop stores the new order and repaints.
local function attachList(t)
    local W = widgets()
    if not W then return nil end
    local list = W.ReorderList({
        stride = ISP.STRIDE, owner = addonName,
        handleIcon = NS.Icon and NS.Icon("move") or nil,
        handleTooltip = L["Drag to reorder"],
        onMove = function(from, to)
            if ISP.Move(from, to) then paintRows(t) end
        end,
    })
    for _, row in ipairs(t.rows) do
        list:AddRow(row, { ghostText = labelOf(row.key), height = ISP.ROW_H, draggable = true })
    end
    list:Finish(t.host)
    return list
end

--- Stop this render's drag and give the controller's handles and boxes back, then park the host.
--- The page's beforeClear, and the placeholder's OnRelease (the host's part alone).
--- @param ctx table
function ISP.Park(ctx)
    if ctx.dwSectionList then
        ctx.dwSectionList:Cancel()
        ctx.dwSectionList = nil
    end
    local t = ctx.dwSectionOrder
    if not t then return end
    t.host:Hide()
    t.host:SetParent(ctx.panel)
    t.host:ClearAllPoints()
end

--- Item tooltip's afterGroup: the Section order heading line, then the drag list on a placeholder
--- the height of its rows. Repainted on every render and after every write (Defaults, a profile
--- switch, `/dw set`), through the page's refreshers.
--- @param ctx table
function ISP.SectionOrder(ctx)
    local h = H()
    local scroll = h.EnsureScroll(ctx)
    if not scroll then return end
    h.TextRow(ctx, L["Section order"], { fontObject = "GameFontNormal" })
    h.TextRow(ctx, L["The order the tooltip writes its sections in. Drag a section by its handle to move it."],
        { fontObject = "GameFontHighlightSmall" })
    local holder = H().AceGUI:Create("SimpleGroup")
    NS.SkinPaintAce(holder)
    holder:SetLayout(nil)
    holder:SetFullWidth(true)
    holder:SetHeight(ISP.STRIDE * #Settings.ITEM_SEARCH_SECTIONS + 4)
    scroll:AddChild(holder)
    local t = ctx.dwSectionOrder or buildHost(ctx)
    ctx.dwSectionOrder = t
    NS.SkinOnRelease(holder, function(w)
        if t.host:GetParent() == w.frame then ISP.Park(ctx) end
    end)
    t.host:SetParent(holder.frame)
    t.host:ClearAllPoints()
    t.host:SetAllPoints(holder.frame)
    t.host:Show()
    paintRows(t)
    ctx.dwSectionList = attachList(t)
    ctx.refreshers[#ctx.refreshers + 1] = function() paintRows(t) end
end

-- ── the key ─────────────────────────────────────────────────────────────────────────────────

--- The Keybindings host tab over the Item Search binding alone (NS.BINDINGS' row of
--- C.ITEM_SEARCH.BINDING); nil without the library (the stub's KeybindingsTab answers nil).
--- @return table|nil
function ISP.KeybindTab()
    local rows = {}
    for _, b in ipairs(NS.BINDINGS or {}) do
        if b.command == K.ITEM_SEARCH.BINDING then rows[#rows + 1] = b end
    end
    return H().KeybindingsTab({ bindings = rows,
        intro = L["The Item Search key opens Item Search on the item under the pointer, or closes it. Ctrl-Alt-D is set for you once, only when that key runs nothing else."] })
end
