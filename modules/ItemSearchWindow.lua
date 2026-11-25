local _, NS = ...
-- modules/ItemSearchWindow.lua — the Item Search window (DropWatcher#17, Item Search spec §4.5,
-- mockup board 2): the frame edge over the pure rows of modules/ItemSearchView.lua. WoW Forever's
-- alone (C.FEATURE.itemSearch, clients-§4): on Retail nothing here is built or opens.
--
-- THE WINDOW. A non-secure standalone window (standalone-windows) in Drop Watcher's chrome: the
-- skin's shell and title band (NS.ApplySkin, NS.Skin.Shell, NS.Skin.Header), the title bar's
-- strip of marks (NS.WindowTitleBar.Marks: lock · settings · close), the library's footer, Escape
-- (UISpecialFrames), raised on a click (SetToplevel), clamped to the screen, moved by its title
-- bar unless Drop Watcher is locked (the one `locked` setting the main window and the launcher
-- share), and its position saved per profile (itemSearch.window.point) on every drag's stop. It is
-- NOT a companion (standalone-windows, *A companion window carries no settings mark*): its key
-- binding opens it on its own and it keeps a saved position, so it fails the "owned" test and
-- carries the gear, as the mockup draws. Its size is fixed, so there is no resize grip.
--
-- THE LEFT PANE. The "Item name or id" box (the library's search box, NS.MakeSearchBox, or a plain
-- edit box without it) and Clear; the matches, run C.ITEM_SEARCH.DEBOUNCE seconds after the last
-- key (Enter shows the first match at once); then the recent searches, the last
-- C.ITEM_SEARCH.WINDOW.RECENT items shown, account-wide (db.global.itemSearch.recent, the lead's
-- `global`), while "remember recent searches" is on.
--
-- THE RIGHT PANE. The item header (icon, name in its quality color, the quality, class, subclass,
-- required level and id line) with Link in chat; the ForeverDB notice while it is not loaded (spec
-- §1); then DROPS FROM, SOLD BY, QUESTS, CRAFTING and ALSO, each left out when empty, in pooled
-- rows. A drop row's bar is scaled to the top chance, in the skin's accent or the custom color; a
-- pin, shown only for a source with a spot and a client that can set a waypoint there
-- (NS.Compat.WaypointMethod: the client's own user waypoint, else TomTom), sets it.
--
-- THE FOOTER. "ForeverDB <version> · <state>" on the left, the key binding's hint on the right
-- ("<key>: open in Item Search", or nothing while unbound).
--
-- READS NEVER LOAD (spec §2). Every ForeverDB read goes through NS.ItemSearch.Get or the adapter
-- only while NS.ItemSearch.State() is "loaded".

NS.ItemSearchWindow = NS.ItemSearchWindow or {}
local ISW = NS.ItemSearchWindow
local IS  = NS.ItemSearch
local ISV = NS.ItemSearchView
local C   = NS.Constants
local L   = NS.L

local Compat = NS.Compat
local WIN = C.ITEM_SEARCH.WINDOW

local frame                 -- built on the first open
local shownItem             -- the item the detail pane shows
local query = ""            -- the search box's text as last typed
local searchTimer           -- the debounce
local retries = 0           -- repaints asked for an item the client is still loading
local matches = {}

-- ── settings ────────────────────────────────────────────────────────────────────────────────

local function setting(key, default)
    local v = NS.Setting("itemSearch.window." .. key)
    if v == nil then return default end
    return v
end

--- The window's settings, read now (spec §4.7; every key under itemSearch.window).
--- @return table { barFromSkin, barColor, density, fontSize, columns, pins, recent }
function ISW.Options()
    local size = tonumber(setting("fontSize", WIN.FONT)) or WIN.FONT
    local density = setting("density", "comfortable")
    return {
        barFromSkin = setting("barFromSkin", true) ~= false, barColor = setting("barColor"),
        density = WIN.ROW_H[density] and density or "comfortable",
        fontSize = math.max(WIN.FONT_MIN, math.min(WIN.FONT_MAX, math.floor(size))),
        columns = setting("columns", true) ~= false, pins = setting("pins", true) ~= false,
        recent = setting("recent", true) ~= false,
    }
end

--- Whether the window can open now: WoW Forever, and its switch on.
--- @return boolean
function ISW.Available()
    return IS.Enabled() and NS.Setting("itemSearch.window.enabled") ~= false
end

local function geometry()
    local db = NS.addon and NS.addon.db
    local p = db and db.profile
    if type(p) ~= "table" then return {} end
    if type(p.itemSearch) ~= "table" then p.itemSearch = {} end
    if type(p.itemSearch.window) ~= "table" then p.itemSearch.window = {} end
    return p.itemSearch.window
end

-- The account-wide recent list, made on first use (nil before the database exists).
local function recentStore()
    local db = NS.addon and NS.addon.db
    local g = db and db.global
    if type(g) ~= "table" then return nil end
    if type(g.itemSearch) ~= "table" then g.itemSearch = {} end
    if type(g.itemSearch.recent) ~= "table" then g.itemSearch.recent = {} end
    return g.itemSearch
end

--- The recent searches, newest first (a copy).
--- @return table
function ISW.Recent()
    local store = recentStore()
    local out = {}
    for i, id in ipairs(store and store.recent or {}) do out[i] = id end
    return out
end

-- ── the view's context ──────────────────────────────────────────────────────────────────────

local function loadedDB()
    if IS.State() ~= "loaded" then return nil end
    return NS.ForeverDB
end

-- ForeverDB's state as the window words it: a load that failed because the addon is missing is
-- "missing" (spec §1's line), not "failed".
local function fdbState()
    local state = IS.State()
    if state == "failed" and IS.FailReason() == "missing" then return "missing" end
    return state
end

local function viewContext()
    local db = loadedDB()
    return {
        spots = db and db.Spots or nil, mapName = Compat.MapName, npc = db and db.NPC or nil,
        quest = db and db.Quest or nil, profession = NS.ItemSearchTip.ProfessionName,
        qualityName = Compat.QualityName, classNames = Compat.ItemClassNames,
    }
end

-- ── colors and fonts ────────────────────────────────────────────────────────────────────────

local function tone(name)
    local t = C.TONE[name or "plain"] or C.TONE.plain
    return t.r, t.g, t.b
end

local function barColor(o)
    if o.barFromSkin then
        local r, g, b = NS.SkinColor("text.accent")
        if r then return r, g, b end
    end
    local c = type(o.barColor) == "table" and o.barColor or C.TONE.mutedGold
    return c.r or c[1] or 1, c.g or c[2] or 1, c.b or c[3] or 1
end

local BASE_SIZE = NS.FONT_SIZE.GameFontHighlight

local function text(parent, size, justify)
    local fs = NS.ScaledFontString(parent, "OVERLAY", "GameFontHighlight", (size or WIN.FONT) / BASE_SIZE)
    NS.Skin.Font(fs)
    fs:SetJustifyH(justify or "LEFT")
    fs:SetWordWrap(false)
    return fs
end

-- ── item tooltips on the rows ───────────────────────────────────────────────────────────────

local function itemLink(id)
    local it = Compat.ItemInfoByID(id)
    return it and it.link or nil
end

local function showItemTip(owner, id)
    if not (GameTooltip and id) then return end
    GameTooltip:SetOwner(owner, "ANCHOR_NONE")
    Compat.TooltipHyperlink(GameTooltip, itemLink(id) or ("item:" .. id))
    GameTooltip:Show()
    NS.RowTooltip.PlaceOrFallback(GameTooltip, owner)
end

local function hideTip()
    if GameTooltip then GameTooltip:Hide() end
end

-- ── the pane rows ───────────────────────────────────────────────────────────────────────────

-- One pooled row: up to six text cells, a bar (its back and fill) and a pin, laid out per paint.
local function newRow(parent, size)
    local row = CreateFrame("Button", nil, parent)
    row.tipRow = true
    row.cells = {}
    for i = 1, 6 do row.cells[i] = text(row, size) end
    row.barBack = row:CreateTexture(nil, "ARTWORK")
    row.barFill = row:CreateTexture(nil, "OVERLAY")
    NS.SkinPaint(row.barBack, function(t) t:SetColorTexture(NS.SkinColor("list.stripe")) end)
    row.pin = CreateFrame("Button", nil, row)
    row.pin:SetSize(WIN.PIN, WIN.PIN)
    row.pin.art = row.pin:CreateTexture(nil, "ARTWORK")
    row.pin.art:SetAllPoints(row.pin)
    row.pin.art:SetTexture(NS.Icon("arrow-right"))
    row.pin:SetScript("OnClick", function(self) ISW.SetPin(self.spot, self.title) end)
    NS.Window.AttachTooltip(row.pin, function()
        return L["Set a waypoint"], NS.TipMarks.Row(L["At"], row.pin.where or "")
    end, "chrome")
    row:SetScript("OnEnter", function(self) if self.itemID then showItemTip(self, self.itemID) end end)
    row:SetScript("OnLeave", hideTip)
    row:SetScript("OnClick", function(self) if self.itemID then ISW.ShowItem(self.itemID) end end)
    return row
end

local pools = {}   -- [parent key] = { pool, size }

local function poolOf(key, parent, size)
    local p = pools[key]
    if p and p.size ~= size then
        NS.Pool.ReleaseAll(p.pool)
        p = nil
    end
    if not p then
        p = { pool = NS.Pool.New(), size = size, parent = parent }
        pools[key] = p
    end
    return p
end

-- The column widths per row kind (`name` takes the rest of the row).
local COLUMN_W = { level = 44, zone = 110, bar = WIN.BAR_W, pct = 44, pin = WIN.PIN + 4, price = 96,
    state = 92, prof = 92, breaks = 150, label = 92, right = 96, id = 64 }

-- Lay `keys` across `width` and answer { key = { x, w } }; `name` is flexible.
local function layout(keys, width)
    local fixed = 0
    for _, k in ipairs(keys) do if k ~= "name" then fixed = fixed + (COLUMN_W[k] or 60) + 4 end end
    local out, x = {}, 0
    for _, k in ipairs(keys) do
        local w = k == "name" and math.max(40, width - fixed - 4) or COLUMN_W[k] or 60
        out[k] = { x = x, w = w }
        x = x + w + 4
    end
    return out
end

-- `color` is a C.TONE name, or an { r, g, b } triple (an item's quality color); a nil triple
-- (an unknown quality) falls back to the plain tone.
local function placeCell(row, i, col, h, value, color, justify)
    local fs = row.cells[i]
    fs:ClearAllPoints()
    fs:SetPoint("LEFT", row, "LEFT", col.x, 0)
    fs:SetSize(col.w, h)
    fs:SetJustifyH(justify or "LEFT")
    fs:SetText(value or "")
    local r, g, b
    if type(color) == "table" then r, g, b = color[1], color[2], color[3] end
    if r == nil then r, g, b = tone(type(color) == "string" and color or nil) end
    fs:SetTextColor(r, g, b)
    fs:Show()
end

local function placeBar(row, col, h, fraction, o)
    row.barBack:ClearAllPoints()
    row.barBack:SetPoint("LEFT", row, "LEFT", col.x, 0)
    row.barBack:SetSize(col.w, math.max(4, h - 10))
    row.barBack:Show()
    local w = fraction > 0 and math.max(1, math.floor(col.w * fraction + 0.5)) or 0
    row.barFill:ClearAllPoints()
    row.barFill:SetPoint("LEFT", row, "LEFT", col.x, 0)
    row.barFill:SetSize(math.max(w, 1), math.max(4, h - 10))
    row.barFill:SetColorTexture(barColor(o))
    row.barFill:SetShown(w > 0)
end

local function placePin(row, col, spot, title, zone, o)
    local how = o.pins and spot and Compat.WaypointMethod(spot.map) or nil
    row.pin.spot, row.pin.title, row.pin.where = spot, title, zone
    row.pin:ClearAllPoints()
    row.pin:SetPoint("LEFT", row, "LEFT", col.x, 0)
    row.pin:SetShown(how ~= nil)
end

-- Reset a pooled row before it is drawn again.
local function blank(row)
    for _, fs in ipairs(row.cells) do fs:Hide() end
    row.barBack:Hide()
    row.barFill:Hide()
    row.pin:Hide()
    row.itemID = nil
end

-- ── the detail pane's sections ──────────────────────────────────────────────────────────────

-- Each section: its heading, the row kind's columns (with and without the zone and level
-- columns) and the painter of one row onto the columns.
local function dropCells(row, cols, h, r, o)
    local i = 1
    local function cell(key, value, color, justify)
        if cols[key] then placeCell(row, i, cols[key], h, value, color, justify); i = i + 1 end
    end
    cell("name", r.name, (r.named or r.world) and "plain" or "muted")
    cell("level", r.level, "muted")
    cell("zone", r.zone, "muted")
    if cols.bar and not r.world then placeBar(row, cols.bar, h, r.fraction or 0, o) end
    cell("pct", r.pct, r.known and "plain" or "muted", "RIGHT")
    if cols.pin then placePin(row, cols.pin, r.spot, r.name, r.zone, o) end
end

local function vendorCells(row, cols, h, r, o)
    local i = 1
    local function cell(key, value, color, justify)
        if cols[key] then placeCell(row, i, cols[key], h, value, color, justify); i = i + 1 end
    end
    cell("name", r.name, "plain")
    cell("level", r.level, "muted")
    cell("zone", r.zone, "muted")
    cell("price", r.price and Compat.CoinText(r.price) or "", "plain", "RIGHT")
    if cols.pin then placePin(row, cols.pin, r.spot, r.name, r.zone, o) end
end

local function questCells(row, cols, h, r, o)
    local i = 1
    local function cell(key, value, color, justify)
        if cols[key] then placeCell(row, i, cols[key], h, value, color, justify); i = i + 1 end
    end
    cell("name", NS.ItemSearchTip.QuestMark(r.state) .. " " .. r.title, "plain")
    cell("level", r.level and tostring(r.level) or "", "muted")
    cell("zone", r.zone, "muted")
    cell("state", r.stateText, r.state == "done" and "good" or "muted")
    if cols.pin then placePin(row, cols.pin, r.spot, r.title, r.zone, o) end
end

local function breaksText(parts)
    local out = {}
    for _, p in ipairs(parts) do out[#out + 1] = NS.GroupRoster.Colored(p.text, tone(p.tone)) end
    return table.concat(out, " ")
end

local function craftCells(row, cols, h, r)
    placeCell(row, 1, cols.name, h, NS.ItemSearchTip.CraftMark(r) .. " " .. r.name, r.known and "plain" or "muted")
    placeCell(row, 2, cols.prof, h, r.profession, "muted")
    placeCell(row, 3, cols.breaks, h, breaksText(r.breakpoints))
    placeCell(row, 4, cols.state, h, r.stateText, r.known and "good" or "muted", "RIGHT")
end

local function alsoCells(row, cols, h, r)
    placeCell(row, 1, cols.label, h, r.label, "muted")
    placeCell(row, 2, cols.name, h, r.text, "plain")
    placeCell(row, 3, cols.right, h, r.right, "muted", "RIGHT")
end

ISW.SECTIONS = {
    { key = "drops", title = L["DROPS FROM"], rows = function(f, ctx) return ISV.DropRows(f, ctx) end,
        cols = { "name", "level", "zone", "bar", "pct", "pin" }, bare = { "name", "bar", "pct", "pin" }, paint = dropCells },
    { key = "vendors", title = L["SOLD BY"], rows = function(f, ctx) return ISV.VendorRows(f, ctx) end,
        cols = { "name", "level", "zone", "price", "pin" }, bare = { "name", "price", "pin" }, paint = vendorCells },
    { key = "quests", title = L["QUESTS"], rows = function(f, ctx) return ISV.QuestRows(f, ctx) end,
        cols = { "name", "level", "zone", "state", "pin" }, bare = { "name", "state", "pin" }, paint = questCells },
    { key = "crafting", title = L["CRAFTING"], rows = function(f, ctx) return ISV.CraftRows(f, ctx) end,
        cols = { "name", "prof", "breaks", "state" }, paint = craftCells },
    { key = "also", title = L["ALSO"], rows = function(f) return ISV.AlsoRows(f) end,
        cols = { "label", "name", "right" }, paint = alsoCells },
}

--- The detail pane's sections for `facts`: `{ { key, title, rows } }`, an empty section left out.
--- @param facts table|nil NS.ItemSearch.Get's answer
--- @param ctx table ISV's context
--- @return table
function ISW.Sections(facts, ctx)
    local out = {}
    if not facts then return out end
    for _, s in ipairs(ISW.SECTIONS) do
        local rows = s.rows(facts, ctx)
        if #rows > 0 then out[#out + 1] = { key = s.key, title = s.title, rows = rows, spec = s } end
    end
    return out
end

-- ── building ────────────────────────────────────────────────────────────────────────────────

local function savePoint()
    local point, _, relativePoint, x, y = frame:GetPoint(1)
    if point then geometry().point = { point, relativePoint, x, y } end
end

local function applyPoint()
    local pt = geometry().point
    frame:ClearAllPoints()
    if type(pt) == "table" and type(pt[1]) == "string" then
        frame:SetPoint(pt[1], UIParent, pt[2] or pt[1], tonumber(pt[3]) or 0, tonumber(pt[4]) or 0)
    else
        frame:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
    end
end

local function lockTip()
    local TM = NS.TipMarks
    if NS.Window.IsLocked() then
        return L["Unlock the window"], TM.Row(L["Lets"], L["it be dragged again"]),
            TM.Row(L["Stored as"], L["Lock frame on General > Master controls"])
    end
    return L["Lock the window"], TM.Row(L["Keeps"], L["it from being dragged"]),
        TM.Row(L["Stored as"], L["Lock frame on General > Master controls"])
end

local function buildTitle(f)
    local bar = CreateFrame("Frame", nil, f)
    bar:SetPoint("TOPLEFT", f, "TOPLEFT", 1, -1)
    bar:SetPoint("TOPRIGHT", f, "TOPRIGHT", -1, -1)
    bar:SetHeight(C.WINDOW.TITLE_H)
    bar:EnableMouse(true)
    bar:RegisterForDrag("LeftButton")
    bar:SetScript("OnDragStart", function() if not NS.Window.IsLocked() then f:StartMoving() end end)
    bar:SetScript("OnDragStop", function()
        f:StopMovingOrSizing()
        savePoint()
    end)
    f.titleBar = bar
    f.title = bar:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    f.title:SetPoint("CENTER", bar, "CENTER", 0, 0)
    f.title:SetText(L["Item Search"])
    NS.Skin.TitleBar(bar, { text = f.title, place = NS.WindowTitleBar.PLACE })
    -- Not a companion (see the header): lock · settings · close.
    -- The gear opens Drop Watcher's settings on Item Search's own page (settings/ItemSearchPage.lua).
    local hb = NS.WindowTitleBar.Marks(bar, { frame = f, close = function() ISW.Close() end,
        settings = function() NS.addon:OpenSettings("itemSearch") end, extras = {
        { key = "lock", icon = "lock", glyph = "L", onClick = function() NS.ToggleLock(); ISW.PaintLock() end },
    } })
    f.closeButton, f.lockButton = hb.close, hb.extras.lock
    NS.Window.AttachTooltip(f.lockButton, lockTip, "chrome")
end

local function fallbackBox(parent, width)
    local box = CreateFrame("EditBox", nil, parent, "InputBoxTemplate")
    box:SetSize(width, C.WINDOW.CONTROL_H)
    box:SetAutoFocus(false)
    box:SetScript("OnTextChanged", function(self) ISW.SetQuery(self:GetText()) end)
    box:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
    return box
end

local function buildSearch(f)
    local width = WIN.LEFT_W - 64
    local box = NS.MakeSearchBox(f, width, { hint = L["Item name or id"],
        onChange = function(t) ISW.SetQuery(t) end })
    box = box or fallbackBox(f, width)
    box:HookScript("OnEnterPressed", function() ISW.ShowFirst() end)
    box:SetPoint("TOPLEFT", f.titleBar, "BOTTOMLEFT", C.WINDOW.INSET, -8)
    f.searchBox = box
    f.clearButton = NS.Window.TextButton(f, 56, nil, L["Clear"], function() ISW.Clear() end)
    f.clearButton:SetPoint("LEFT", box, "RIGHT", 6, 0)
end

local function scrollArea(f)
    local scroll = CreateFrame("ScrollFrame", nil, f, "UIPanelScrollFrameTemplate")
    local content = CreateFrame("Frame", nil, scroll)
    content:SetSize(1, 1)
    scroll:SetScrollChild(content)
    local bar = rawget(scroll, "ScrollBar")
    if bar then NS.Skin.ScrollBar(bar) end
    return scroll, content
end

local function heading(parent, words)
    local fs = parent:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    fs:SetText(words)
    NS.Skin.Text(fs, "heading")
    return fs
end

local function buildLeft(f)
    local foot = NS.FooterMetric("HEIGHT")
    local recentH = WIN.RECENT * WIN.ROW_H.compact + 24
    f.matchesHead = heading(f, L["Matches"])
    f.matchesHead:SetPoint("TOPLEFT", f.searchBox, "BOTTOMLEFT", 0, -8)
    f.matchScroll, f.matchContent = scrollArea(f)
    f.matchScroll:SetPoint("TOPLEFT", f.matchesHead, "BOTTOMLEFT", 0, -4)
    f.matchScroll:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", C.WINDOW.INSET, foot + recentH)
    f.matchScroll:SetWidth(WIN.LEFT_W - C.WINDOW.SCROLL_W)
    f.matchNote = text(f, WIN.FONT)
    f.matchNote:SetPoint("TOPLEFT", f.matchesHead, "BOTTOMLEFT", 0, -6)
    f.matchNote:SetWidth(WIN.LEFT_W - 8)
    f.matchNote:SetWordWrap(true)
    f.recentHead = heading(f, L["Recent searches"])
    f.recentHead:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", C.WINDOW.INSET, foot + recentH - 16)
    f.recentHost = CreateFrame("Frame", nil, f)
    f.recentHost:SetPoint("TOPLEFT", f.recentHead, "BOTTOMLEFT", 0, -4)
    f.recentHost:SetSize(WIN.LEFT_W, recentH - 24)
end

local function buildHeader(f)
    local x = WIN.LEFT_W + 2 * C.WINDOW.INSET
    f.icon = CreateFrame("Button", nil, f)
    f.icon:SetSize(WIN.ICON, WIN.ICON)
    f.icon:SetPoint("TOPLEFT", f.titleBar, "BOTTOMLEFT", x, -8)
    f.icon.art = f.icon:CreateTexture(nil, "ARTWORK")
    f.icon.art:SetAllPoints(f.icon)
    f.icon:SetScript("OnEnter", function(self) showItemTip(self, shownItem) end)
    f.icon:SetScript("OnLeave", hideTip)
    f.name = f:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    f.name:SetPoint("TOPLEFT", f.icon, "TOPRIGHT", 8, 0)
    f.name:SetJustifyH("LEFT")
    NS.Skin.Font(f.name)
    f.line = text(f, WIN.FONT - 2)
    f.line:SetPoint("TOPLEFT", f.name, "BOTTOMLEFT", 0, -3)
    f.linkButton = NS.Window.TextButton(f, 104, "chat", L["Link in chat"], function() ISW.LinkInChat() end)
    f.linkButton:SetPoint("TOPRIGHT", f.titleBar, "BOTTOMRIGHT", -C.WINDOW.INSET, -10)
    NS.Window.AttachTooltip(f.linkButton, function()
        return L["Link in chat"], NS.TipMarks.Row(L["Puts"], L["the item's link in your chat box"])
    end, "chrome")
    f.notice = text(f, WIN.FONT)
    f.notice:SetPoint("TOPLEFT", f.icon, "BOTTOMLEFT", 0, -8)
    f.notice:SetWidth(WIN.WIDTH - x - C.WINDOW.INSET)
    f.notice:SetWordWrap(true)
    NS.Skin.Text(f.notice, "text.muted")
    f.empty = text(f, WIN.FONT)
    f.empty:SetPoint("TOP", f, "TOPLEFT", x + (WIN.WIDTH - x) / 2, -120)
    f.empty:SetText(L["Type an item's name or id on the left."])
    NS.Skin.Text(f.empty, "text.muted")
end

local function buildDetail(f)
    local x = WIN.LEFT_W + 2 * C.WINDOW.INSET
    f.detailScroll, f.detailContent = scrollArea(f)
    f.detailScroll:SetPoint("TOPLEFT", f.titleBar, "BOTTOMLEFT", x, -WIN.ICON - 40)
    f.detailScroll:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -C.WINDOW.SCROLL_W - 4, NS.FooterMetric("HEIGHT") + 4)
    f.detailW = WIN.WIDTH - x - C.WINDOW.SCROLL_W - 10
    f.detailContent:SetWidth(f.detailW)
    f.headings = {}
end

local function buildFooter(f)
    f.foot = NS.MakeFooter(f, { inset = 1 }) or NS.BareFooter(f, {})
end

local function onHide()
    hideTip()
    if searchTimer then searchTimer:Cancel(); searchTimer = nil end
end

local function build()
    local f = CreateFrame("Frame", WIN.NAME, UIParent, "BackdropTemplate")
    f:SetFrameStrata(C.LAYERS.STRATA.WINDOW)
    f:SetToplevel(true)
    f:SetMovable(true)
    f:SetClampedToScreen(true)
    f:EnableMouse(true)
    f:SetSize(WIN.WIDTH, WIN.HEIGHT)
    f:Hide()
    frame = f
    applyPoint()
    buildTitle(f)
    buildSearch(f)
    buildLeft(f)
    buildHeader(f)
    buildDetail(f)
    buildFooter(f)
    NS.ApplySkin(f)
    NS.Skin.Shell(f, { noTopBar = true })
    NS.Skin.Header(f, { bars = { f.titleBar } })
    if type(UISpecialFrames) == "table" then tinsert(UISpecialFrames, WIN.NAME) end
    f:SetScript("OnHide", onHide)
    return f
end

local function ensureFrame()
    return frame or build()
end

-- ── painting ────────────────────────────────────────────────────────────────────────────────

--- The lock mark's look: full strength while locked, dimmed while unlocked (as the main window's).
function ISW.PaintLock()
    if frame and frame.lockButton then NS.WindowTitleBar.PaintLock(frame, NS.Window.IsLocked()) end
end

-- A list row (a match or a recent item): icon, name in quality color, id.
local function paintItemRow(row, r, width, h)
    blank(row)
    row.itemID = r.id
    local qr, qg, qb = NS.QualityColor(r.quality)
    local icon = r.icon or Compat.ItemIcon(r.id)
    local label = (icon and ("|T%s:0|t "):format(tostring(icon)) or "") .. (r.name or L["Item %d"]:format(r.id))
    placeCell(row, 1, { x = 0, w = width - COLUMN_W.id - 4 }, h, label, { qr, qg, qb })
    placeCell(row, 2, { x = width - COLUMN_W.id, w = COLUMN_W.id }, h, tostring(r.id), "muted", "RIGHT")
end

local function paintList(key, parent, rows, o)
    local h = WIN.ROW_H[o.density]
    local p = poolOf(key, parent, o.fontSize)
    NS.Pool.ReleaseAll(p.pool)
    local width = WIN.LEFT_W - C.WINDOW.SCROLL_W
    for i, r in ipairs(rows) do
        local row = NS.Pool.Acquire(p.pool, function() return newRow(parent, o.fontSize) end)
        row:ClearAllPoints()
        row:SetPoint("TOPLEFT", parent, "TOPLEFT", 0, -(i - 1) * h)
        row:SetSize(width, h)
        paintItemRow(row, r, width, h)
    end
    return #rows * h
end

local function recentRows()
    local out = {}
    local db = loadedDB()
    for _, id in ipairs(ISW.Recent()) do
        local it = db and db.Item(id) or Compat.ItemInfoByID(id)
        out[#out + 1] = { id = id, name = type(it) == "table" and it.name or nil,
            quality = type(it) == "table" and it.quality or nil, icon = type(it) == "table" and it.icon or nil }
    end
    return out
end

local function paintLeft(o)
    local f = frame
    local h = paintList("matches", f.matchContent, matches.rows or {}, o)
    f.matchContent:SetSize(WIN.LEFT_W - C.WINDOW.SCROLL_W, math.max(1, h))
    local note = ISV.NoteText(matches.note)
    f.matchNote:SetText(note or "")
    f.matchNote:SetShown(note ~= nil)
    f.recentHead:SetShown(o.recent)
    f.recentHost:SetShown(o.recent)
    if o.recent then paintList("recent", f.recentHost, recentRows(), o) end
end

local function headingOf(i)
    local f = frame
    if not f.headings[i] then f.headings[i] = heading(f.detailContent, "") end
    return f.headings[i]
end

local function paintSection(s, y, o)
    local f = frame
    local h = WIN.ROW_H[o.density]
    local cols = layout((o.columns or not s.spec.bare) and s.spec.cols or s.spec.bare, f.detailW)
    local p = poolOf("detail", f.detailContent, o.fontSize)
    for _, r in ipairs(s.rows) do
        local row = NS.Pool.Acquire(p.pool, function() return newRow(f.detailContent, o.fontSize) end)
        blank(row)
        row:ClearAllPoints()
        row:SetPoint("TOPLEFT", f.detailContent, "TOPLEFT", 0, -y)
        row:SetSize(f.detailW, h)
        s.spec.paint(row, cols, h, r, o)
        y = y + h
    end
    return y
end

local function itemHeader(facts)
    local f = frame
    local item = facts and facts.item or { id = shownItem }
    local qr, qg, qb = NS.QualityColor(item.quality)
    f.icon.art:SetTexture(item.icon or Compat.ItemIcon(item.id) or NS.Icon("help"))
    f.name:SetText(item.name or L["Item %d"]:format(item.id))
    if qr == nil then qr, qg, qb = tone("plain") end
    f.name:SetTextColor(qr, qg, qb)
    f.line:SetText(ISV.ItemLine(item, viewContext()))
    f.linkButton:SetEnabled(itemLink(item.id) ~= nil)
end

local function paintDetail(o)
    local f = frame
    local has = shownItem ~= nil
    for _, w in ipairs({ f.icon, f.name, f.line, f.linkButton, f.detailScroll }) do w:SetShown(has) end
    f.empty:SetShown(not has)
    local notice = ISV.Notice(fdbState())
    f.notice:SetText(notice or "")
    f.notice:SetShown(notice ~= nil)
    for _, fs in ipairs(f.headings) do fs:Hide() end
    local p = poolOf("detail", f.detailContent, o.fontSize)
    NS.Pool.ReleaseAll(p.pool)
    if not has then return end
    local facts = IS.Get(shownItem)
    itemHeader(facts)
    local y = 0
    for i, s in ipairs(ISW.Sections(facts, viewContext())) do
        local hd = headingOf(i)
        hd:ClearAllPoints()
        hd:SetPoint("TOPLEFT", f.detailContent, "TOPLEFT", 0, -y - 4)
        hd:SetText(s.title)
        hd:Show()
        y = paintSection(s, y + 20, o) + 6
    end
    f.detailContent:SetHeight(math.max(1, y))
end

local function paintFooter()
    local f = frame
    local st = NS.ForeverDB.Status()
    local meta = IS.State() == "loaded" and NS.ForeverDB.Meta() or nil
    local version = (meta and meta.version) or (type(st) == "table" and st.version) or nil
    f.foot:SetLeft(ISV.FooterText(fdbState(), version))
    local key = Compat.BindingKeyText(C.ITEM_SEARCH.BINDING)
    f.foot:SetRight(key and L["%s: open in Item Search"]:format(key) or "")
end

--- Repaint the whole window from the current state (a no-op while it is closed).
function ISW.Refresh()
    if not (frame and frame:IsShown()) then return end
    local o = ISW.Options()
    paintLeft(o)
    paintDetail(o)
    paintFooter()
    ISW.PaintLock()
end

-- ── the search ──────────────────────────────────────────────────────────────────────────────

local function runSearch()
    searchTimer = nil
    local db = loadedDB()
    local rows, note = ISV.Matches(query, { state = fdbState(), db = db, clientItem = Compat.ItemInfoByID,
        limit = WIN.MATCHES })
    matches = { rows = rows, note = note }
    local q = ISV.Classify(query)
    if q.kind == "id" and not (rows[1] and rows[1].name) then Compat.RequestItem(q.id) end
    ISW.Refresh()
end

--- The search box's text changed: run the search DEBOUNCE seconds after the last change.
--- @param t string|nil
function ISW.SetQuery(t)
    query = type(t) == "string" and t or ""
    if searchTimer then searchTimer:Cancel() end
    searchTimer = C_Timer.NewTimer(C.ITEM_SEARCH.DEBOUNCE, runSearch)
end

--- Run the pending search now (Enter, the slash verb).
function ISW.SearchNow()
    if searchTimer then searchTimer:Cancel() end
    runSearch()
end

--- Enter: run the search now and show its first match.
function ISW.ShowFirst()
    ISW.SearchNow()
    local first = matches.rows and matches.rows[1]
    if first then ISW.ShowItem(first.id) end
end

--- Clear: empty the box and the matches.
function ISW.Clear()
    query = ""
    if searchTimer then searchTimer:Cancel(); searchTimer = nil end
    matches = {}
    if frame and frame.searchBox then frame.searchBox:SetText("") end
    ISW.Refresh()
end

--- The matches the list shows now: `{ rows, note }` (a copy of the rows).
--- @return table
function ISW.Matches()
    local rows = {}
    for i, r in ipairs(matches.rows or {}) do rows[i] = r end
    return { rows = rows, note = matches.note }
end

-- ── showing an item ─────────────────────────────────────────────────────────────────────────

-- An item the client has not cached and ForeverDB does not name reads again shortly.
local function retryUncached(id)
    local facts = IS.Get(id)
    if (facts and facts.item.name) or retries >= 4 then return end
    retries = retries + 1
    Compat.RequestItem(id)
    C_Timer.After(WIN.LOAD_RETRY, function()
        if shownItem == id then
            ISW.Refresh()
            retryUncached(id)
        end
    end)
end

--- Show `itemID` in the detail pane (opening the window), and put it first in the recent searches
--- while they are remembered.
--- @param itemID number
--- @return boolean shown
function ISW.ShowItem(itemID)
    itemID = tonumber(itemID)
    if not (itemID and itemID > 0) or not ISW.Available() then return false end
    shownItem, retries = itemID, 0
    if ISW.Options().recent then
        local store = recentStore()
        if store then store.recent = ISV.PushRecent(store.recent, itemID, WIN.RECENT) end
    end
    if not ISW.IsShown() then ensureFrame():Show() end
    ISW.Refresh()
    retryUncached(itemID)
    return true
end

--- The item the detail pane shows, or nil.
--- @return number|nil
function ISW.ShownItem() return shownItem end

--- Link in chat: the shown item's link into the chat box. Answers whether it went.
--- @return boolean
function ISW.LinkInChat()
    local link = shownItem and itemLink(shownItem)
    if not link then
        if shownItem then Compat.RequestItem(shownItem) end
        NS.Print(L["That item is still loading: try again in a moment."])
        return false
    end
    return Compat.LinkInChat(link)
end

--- A pin's click: set a waypoint at `spot`. Answers the method used, or nil.
--- @param spot table|nil { map, x, y }
--- @param title string|nil
--- @return string|nil
function ISW.SetPin(spot, title)
    if type(spot) ~= "table" then return nil end
    local how = Compat.SetWaypoint(spot.map, spot.x, spot.y, title)
    local zone = Compat.MapName(spot.map) or L["Map %d"]:format(spot.map)
    if how then
        NS.Print(L["Waypoint set: %s (%s, %.1f, %.1f)."]:format(tostring(title or ""), zone, spot.x * 100, spot.y * 100))
    else
        NS.Print(L["No waypoint: this map takes none here."])
    end
    return how
end

-- ── opening and closing ─────────────────────────────────────────────────────────────────────

--- Whether the window is on screen.
--- @return boolean
function ISW.IsShown()
    return frame ~= nil and frame:IsShown() == true
end

--- The window's frame (nil before its first open), for the tests and the key.
--- @return table|nil
function ISW.Frame() return frame end

--- Open the window: with `opts.itemID` that item shown, else empty with the search box focused.
--- Refused (false) on Retail or with the window switched off.
--- @param opts table|nil { itemID }
--- @return boolean
function ISW.Open(opts)
    if not ISW.Available() then return false end
    local f = ensureFrame()
    local id = opts and tonumber(opts.itemID)
    if id then return ISW.ShowItem(id) end
    f:Show()
    ISW.Refresh()
    if f.searchBox and f.searchBox.SetFocus then f.searchBox:SetFocus() end
    return true
end

--- Close the window.
function ISW.Close()
    if frame then frame:Hide() end
end

--- The main window's magnifier: open (search focused) or close.
--- @return boolean shown
function ISW.Toggle()
    if ISW.IsShown() then
        ISW.Close()
        return false
    end
    if not ISW.Available() then
        NS.Print(L["Item Search's window is switched off."])
        return false
    end
    return ISW.Open()
end

--- `/dw search [name|id]`: open the window, and with text search for it now (an id is shown at
--- once). Answers whether the window opened.
--- @param rest string|nil
--- @return boolean
function ISW.SlashSearch(rest)
    if not ISW.Available() then
        NS.Print(IS.Enabled() and L["Item Search's window is switched off."] or L["Item Search is WoW Forever's alone."])
        return false
    end
    local t = (tostring(rest or ""):gsub("^%s+", ""):gsub("%s+$", ""))
    if t == "" then return ISW.Open() end
    local q = ISV.Classify(t)
    if q.kind == "id" then return ISW.ShowItem(q.id) end
    ISW.Open()
    query = t
    if frame.searchBox then frame.searchBox:SetText(t) end
    ISW.SearchNow()
    return true
end

--- Settings moved (the lock, a window setting, a profile switch): repaint an open window.
function ISW.ApplySettings()
    if frame then applyPoint() end
    ISW.Refresh()
end

-- A stand-down closes the window.
NS.STAND_DOWN[#NS.STAND_DOWN + 1] = function() ISW.Close() end
