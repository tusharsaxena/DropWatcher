local _, NS = ...
-- modules/ItemSearchTabs.lua — the Item Search window's tabs, pure (Item Search feedback spec §5.3 to
-- §5.5; mockups V2Window and V2Tabs): which tabs an item has and their labels, each tab's columns
-- (fixed widths and the flex columns that share the rest), its filters and its sorts, and the view of
-- a tab's rows (modules/ItemSearchCells.lua's) under a view state. The frame edge
-- (modules/ItemSearchGrid.lua, modules/ItemSearchWindow.lua) keeps the state and draws the answer.
-- No client call and no setting read here.
--
-- THE TABS (spec §5.3): one per section that has rows, in the order Drops from, Gathered from (round
-- 3 spec §4.3, item 7: the herbs, veins and fishing nodes, apart from the drops), Sold by, Quests,
-- Crafting, Skinned from; each label carries its count, and Crafting's the filtered count with the
-- whole count beside it ("Crafting 12 / 74", spec §4).
--
-- A VIEW STATE is `{ sort = { col, desc }, filters = { [key] = boolean } }`. `col` "best" is the
-- ranking's order ("Best for you", spec §3), the default; a column's click sorts by it, a second
-- click flips it (TABS.NextSort). A filter changes the view only and is never saved (spec §5.5). A
-- filter NARROWS when its value is its `narrows` value (Creatures off, Only my zone on): only then
-- does it drop rows, and the header's funnel is filled while any filter narrows (TABS.Narrowed).
-- Reset (TABS.DefaultState) is shown only while the state is not the default (TABS.IsDefault).
--
-- THE COLUMNS (spec §5.4) are exactly the spec's, less the two the client gives no data for (Sold
-- by's Stock and Requires: LibKa0s-ForeverDB-1.0 reads ForeverDB's vendx for prices only; spec §5.4
-- lets such a column go). A few widths moved a little so Crafting's fixed columns fit the minimum
-- window (Profession 120, Skill 130, Status 120). TABS.Layout gives every fixed column its width and
-- shares the rest among the flex ones, so a wider window truncates less (W8); a narrow one scales the
-- fixed columns down before a flex column falls under FLEX_MIN. The columns start TABS.INSET in from
-- the table's left edge and end TABS.INSET short of its right (round 3 spec §4.1, item 12: the
-- window's body margin, C.WINDOW.INSET), so the first column's text sits off the edge; the row's
-- stripe, hover wash and selection edge still span the whole row. The glyph and mark columns are
-- centered (`justify`).

NS.ItemSearchTabs = NS.ItemSearchTabs or {}
local TABS = NS.ItemSearchTabs
local L    = NS.L

local floor = math.floor

TABS.ORDER = { "drops", "gathered", "vendors", "quests", "crafting", "skinned" }
TABS.GAP = 6
TABS.INSET = NS.Constants.WINDOW.INSET   -- 6: the columns' margin at each side of the table
TABS.FLEX_MIN = 72

local function col(key, title, w, opts)
    local c = { key = key, title = title }
    if w == "flex" then c.flex = true else c.w = w end
    for k, v in pairs(opts or {}) do c[k] = v end
    if c.sort == nil then c.sort = title ~= nil end
    return c
end

local PIN = col("pin", nil, 28, { kind = "pin", sort = false })

-- Each tab: its title, the header's noun (one, many), its columns and its filters. A filter is
-- `{ key, label, default, narrows, keep(row) }`: while its value is `narrows`, a row stays only when
-- keep(row) answers true.
TABS.DEF = {
    drops = {
        title = L["Drops from"], one = L["source"], many = L["sources"],
        columns = {
            col("source", L["Source"], "flex", { tip = L["the creature, object or container it drops from"] }),
            col("type", L["Type"], 80, { tip = L["Creature, Elite, Rare, Rare Elite, Boss, Object or Container"] }),
            col("level", L["Level"], 64, { tip = L["its level, in the color of how hard it is for you"] }),
            col("zone", L["Zone"], "flex", { tip = L["where it stands: your zone first, else where it mostly stands"] }),
            col("chance", L["Chance"], 150, { kind = "bar", first = "desc", tip = L["the drop chance ForeverDB recorded"] }),
            PIN,
        },
        filters = {
            { key = "npc", label = L["Creatures"], default = true, narrows = false, keep = function(r) return r.kind ~= "npc" end },
            { key = "object", label = L["Objects"], default = true, narrows = false, keep = function(r) return r.kind ~= "object" end },
            { key = "item", label = L["Containers"], default = true, narrows = false, keep = function(r) return r.kind ~= "item" end },
            { key = "zone", label = L["Only my zone"], default = false, narrows = true, keep = function(r) return r.here == true end },
            { key = "band", label = L["Only my level band"], default = false, narrows = true, keep = function(r) return r.band ~= false end },
        },
    },
    gathered = {
        title = L["Gathered from"], one = L["node"], many = L["nodes"],
        columns = {
            col("node", L["Node"], "flex", { tip = L["the herb, vein or fishing node it is gathered from"] }),
            col("profession", L["Profession"], 90, { tip = L["the gathering profession it takes"] }),
            col("skill", L["Skill"], 64, { tip = L["the skill the node needs, red when above yours; ? when unknown"] }),
            col("zone", L["Zone"], "flex", { tip = L["where it stands: your zone first, else where it mostly stands"] }),
            col("chance", L["Chance"], 150, { kind = "bar", first = "desc", tip = L["the chance ForeverDB recorded"] }),
            PIN,
        },
        filters = {
            { key = "herbalism", label = L["Herbalism"], default = true, narrows = false, keep = function(r) return r.gather ~= "herbalism" end },
            { key = "mining", label = L["Mining"], default = true, narrows = false, keep = function(r) return r.gather ~= "mining" end },
            { key = "fishing", label = L["Fishing"], default = true, narrows = false, keep = function(r) return r.gather ~= "fishing" end },
            { key = "mine", label = L["Only my professions"], default = false, narrows = true, keep = function(r) return r.mine end },
            { key = "zone", label = L["Only my zone"], default = false, narrows = true, keep = function(r) return r.here == true end },
        },
    },
    vendors = {
        title = L["Sold by"], one = L["vendor"], many = L["vendors"],
        columns = {
            col("vendor", L["Vendor"], "flex", { tip = L["who sells it; its title on the row's tooltip"] }),
            col("level", L["Level"], 56, { tip = L["the vendor's level"] }),
            col("zone", L["Zone"], "flex", { tip = L["where it stands: your zone first, else where it mostly stands"] }),
            col("faction", L["Faction"], 90, { tip = L["Alliance, Horde or Both (either faction); red: only the other faction can buy here"] }),
            col("price", L["Price"], 110, { tip = L["its price at this vendor: the one you saw there, else ForeverDB's"] }),
            PIN,
        },
        filters = {
            { key = "faction", label = L["Only my faction"], default = false, narrows = true, keep = function(r) return not r.other end },
        },
    },
    quests = {
        title = L["Quests"], one = L["quest"], many = L["quests"],
        columns = {
            col("mark", nil, 24, { kind = "mark", sort = false, justify = "CENTER" }),
            col("quest", L["Quest"], "flex", { tip = L["its title, in the color of how hard it is for you"] }),
            col("role", L["Role"], 110, { tip = L["whether it needs the item, rewards it or the item starts it"] }),
            col("level", L["Level"], 56, { tip = L["the quest's level"] }),
            col("min", L["Min"], 56, { tip = L["the level needed to pick it up"] }),
            col("status", L["Status"], 130, { tip = L["in your log, can pick up, too high or completed"] }),
            col("giver", L["Giver"], "flex", { tip = L["who gives it, and where"] }),
            PIN,
        },
        filters = {
            { key = "completed", label = L["Hide completed"], default = false, narrows = true, keep = function(r) return r.state ~= "done" end },
        },
    },
    crafting = {
        title = L["Crafting"], one = L["recipe"], many = L["recipes"], chip = "mine",
        columns = {
            col("glyph", nil, 24, { kind = "glyph", sort = false, justify = "CENTER" }),
            col("recipe", L["Recipe"], "flex", { tip = L["the recipe; white if you know it"] }),
            col("profession", L["Profession"], 120, { tip = L["the profession it belongs to"] }),
            col("uses", L["Uses"], 56, { tip = L["how many of this item one craft takes"] }),
            col("makes", L["Makes"], "flex", { tip = L["what it makes; hover it for the item"] }),
            col("skill", L["Skill"], 130, { kind = "parts", tip = L["its skill-up breakpoints: orange, yellow, green, gray"] }),
            col("status", L["Status"], 120, { tip = L["known, not known, or the profession you lack"] }),
        },
        filters = {
            { key = "mine", label = L["Only my professions"], default = "mine", narrows = true, keep = function(r) return r.mine end },
            { key = "known", label = L["Only known"], default = false, narrows = true, keep = function(r) return r.known end },
        },
    },
    skinned = {
        title = L["Skinned from"], one = L["creature"], many = L["creatures"],
        columns = {
            col("creature", L["Creature"], "flex", { tip = L["the creature it is skinned from"] }),
            col("level", L["Level"], 64, { tip = L["its level, in the color of how hard it is for you"] }),
            col("skill", L["Skill"], 64, { tip = L["the Skinning it needs, red when above yours"] }),
            col("zone", L["Zone"], "flex", { tip = L["where it stands: your zone first, else where it mostly stands"] }),
            col("chance", L["Chance"], 150, { kind = "bar", first = "desc", tip = L["the chance ForeverDB recorded"] }),
            PIN,
        },
        filters = {
            { key = "zone", label = L["Only my zone"], default = false, narrows = true, keep = function(r) return r.here == true end },
        },
    },
}

--- A tab's column by key, or nil.
--- @param tab string
--- @param key string
--- @return table|nil
function TABS.Column(tab, key)
    for _, c in ipairs(TABS.DEF[tab] and TABS.DEF[tab].columns or {}) do
        if c.key == key then return c end
    end
    return nil
end

-- ── the tab set ─────────────────────────────────────────────────────────────────────────────

--- How many of `rows` are sources: every row but the World drop row, which is not one.
--- @param rows table
--- @return number
function TABS.Count(rows)
    local n = 0
    for _, r in ipairs(rows or {}) do if not r.world then n = n + 1 end end
    return n
end

--- The tabs an item has: `{ { key, title, count, total } }` in TABS.ORDER, a tab with no rows left
--- out (a Drops tab with the World drop row alone still shows). `count` is what the tab shows by
--- default: Crafting's with the profession filter applied when `mine` (spec §4); every other tab's
--- is its total. Neither counts the World drop row (TABS.Count).
--- @param built table ISC.Build's answer
--- @param mine boolean only the professions you know
--- @return table
function TABS.Tabs(built, mine)
    local out = {}
    for _, key in ipairs(TABS.ORDER) do
        local rows = built[key] or {}
        if #rows > 0 then
            local total = TABS.Count(rows)
            local count = total
            if key == "crafting" and mine then
                count = 0
                for _, r in ipairs(rows) do if r.mine then count = count + 1 end end
            end
            out[#out + 1] = { key = key, title = TABS.DEF[key].title, count = count, total = total }
        end
    end
    return out
end

--- The tab to show: `want` when the item has it, else the first; nil for none.
--- @param tabs table TABS.Tabs' answer
--- @param want string|nil
--- @return string|nil
function TABS.Pick(tabs, want)
    for _, t in ipairs(tabs) do if t.key == want then return want end end
    return tabs[1] and tabs[1].key or nil
end

-- ── the view state ──────────────────────────────────────────────────────────────────────────

local function defaultOf(f, opts)
    if f.default == "mine" then return opts.mine == true end
    return f.default
end

--- A tab's default view state: Best for you, every filter at its default (Crafting's "Only my
--- professions" is `opts.mine`, the setting, spec §4).
--- @param tab string
--- @param opts table|nil { mine }
--- @return table
function TABS.DefaultState(tab, opts)
    opts = opts or {}
    local filters = {}
    for _, f in ipairs(TABS.DEF[tab] and TABS.DEF[tab].filters or {}) do filters[f.key] = defaultOf(f, opts) end
    return { sort = { col = "best", desc = false }, filters = filters }
end

--- Whether `state` is its tab's default: Best for you and no filter moved (Reset hides).
--- @return boolean
function TABS.IsDefault(tab, state, opts)
    if state.sort.col ~= "best" then return false end
    local def = TABS.DefaultState(tab, opts)
    for key, v in pairs(def.filters) do
        if (state.filters[key] == true) ~= v then return false end
    end
    return true
end

--- Whether any filter narrows the rows now: the funnel is filled (spec §5.5).
--- @return boolean
function TABS.Narrowed(tab, state)
    for _, f in ipairs(TABS.DEF[tab] and TABS.DEF[tab].filters or {}) do
        if (state.filters[f.key] == true) == f.narrows then return true end
    end
    return false
end

--- The sort after a click on column `key`: the same column flips; another column starts in its
--- first order (`first`, ascending unless it says "desc"); "best" is always Best for you.
--- @param tab string
--- @param sort table { col, desc }
--- @param key string a column key, or "best"
--- @return table a new sort
function TABS.NextSort(tab, sort, key)
    if key == "best" then return { col = "best", desc = false } end
    if sort.col == key then return { col = key, desc = not sort.desc } end
    local c = TABS.Column(tab, key)
    return { col = key, desc = c ~= nil and c.first == "desc" }
end

--- The words the section header says for the sort in force: "Best for you", or the column's title
--- with its direction.
--- @return string
function TABS.SortLabel(tab, sort)
    if sort.col == "best" then return L["Best for you"] end
    local c = TABS.Column(tab, sort.col)
    local title = c and c.title or sort.col
    return (sort.desc and L["%s, high to low"] or L["%s, low to high"]):format(title)
end

--- The Sort menu's entries: Best for you first, then each sortable column. `{ { key, label } }`.
--- @param tab string
--- @return table
function TABS.SortChoices(tab)
    local out = { { key = "best", label = L["Best for you"] } }
    for _, c in ipairs(TABS.DEF[tab] and TABS.DEF[tab].columns or {}) do
        if c.sort then out[#out + 1] = { key = c.key, label = c.title } end
    end
    return out
end

-- ── the view ────────────────────────────────────────────────────────────────────────────────

local function passes(row, filters, state)
    if row.world then return true end
    for _, f in ipairs(filters) do
        if (state.filters[f.key] == true) == f.narrows and not f.keep(row) then return false end
    end
    return true
end

-- `a` before `b` on column `key` (nil last in either direction), the ranking breaking a tie.
local function columnBefore(key, desc)
    return function(a, b)
        local x, y = a.sort[key], b.sort[key]
        if x ~= y then
            if x == nil then return false end
            if y == nil then return true end
            if type(x) ~= type(y) then x, y = tostring(x), tostring(y) end
            if desc then return x > y end
            return x < y
        end
        return a.best < b.best
    end
end

--- A tab's rows under `state`: filtered (spec §5.5), then sorted (the ranking for "best", else the
--- column, nil last). The World drop row stays last. A new array, and how many rows the filters
--- left out.
--- @param tab string
--- @param rows table ISC's rows
--- @param state table
--- @return table shown, number hidden
function TABS.View(tab, rows, state)
    local def = TABS.DEF[tab]
    local filters = def and def.filters or {}
    local out, tail, hidden = {}, nil, 0
    for _, r in ipairs(rows or {}) do
        if not passes(r, filters, state) then
            hidden = hidden + 1
        elseif r.world then
            tail = r
        else
            out[#out + 1] = r
        end
    end
    local key = state.sort.col
    if key == "best" then
        table.sort(out, function(a, b) return a.best < b.best end)
    else
        table.sort(out, columnBefore(key, state.sort.desc))
    end
    if tail then out[#out + 1] = tail end
    return out, hidden
end

--- The section header's count: "54 sources", or "12 of 74 recipes" while a filter hides some.
--- @param tab string
--- @param shown number
--- @param total number
--- @return string
function TABS.CountText(tab, shown, total)
    local def = TABS.DEF[tab]
    local noun = total == 1 and def.one or def.many
    if shown < total then return L["%d of %d %s"]:format(shown, total, noun) end
    return L["%d %s"]:format(total, noun)
end

-- ── the layout ──────────────────────────────────────────────────────────────────────────────

-- The fixed columns' width and the flex columns' count.
local function measure(cols)
    local fixed, flex = 0, 0
    for _, c in ipairs(cols) do
        if c.flex then flex = flex + 1 else fixed = fixed + c.w end
    end
    return fixed, flex
end

--- Lay `cols` across `width`: `{ [key] = { x, w } }`, from x = TABS.INSET across
--- `width - 2 * TABS.INSET`. Fixed columns keep their width and the flex ones share the rest,
--- TABS.GAP apart; when that leaves a flex column under TABS.FLEX_MIN, the fixed columns are scaled
--- down until it does not.
--- @param cols table a tab's columns
--- @param width number the table's whole width
--- @return table
function TABS.Layout(cols, width)
    width = width - 2 * TABS.INSET
    local fixed, flex = measure(cols)
    local gaps = TABS.GAP * math.max(0, #cols - 1)
    local room = width - gaps - fixed
    local scale = 1
    if flex > 0 and room < flex * TABS.FLEX_MIN and fixed > 0 then
        scale = math.max(0.5, (width - gaps - flex * TABS.FLEX_MIN) / fixed)
        room = width - gaps - fixed * scale
    end
    local share = flex > 0 and math.max(TABS.FLEX_MIN, floor(room / flex)) or 0
    local out, x = {}, TABS.INSET
    for _, c in ipairs(cols) do
        local w = c.flex and share or floor(c.w * scale)
        out[c.key] = { x = x, w = w }
        x = x + w + TABS.GAP
    end
    return out
end
