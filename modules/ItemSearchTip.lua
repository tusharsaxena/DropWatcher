local _, NS = ...
-- modules/ItemSearchTip.lua — Item Search's block on every item tooltip (DropWatcher#17, Item Search
-- spec §4.4, mockup board 1). WoW Forever's alone (C.FEATURE.itemSearch, clients-§4).
--
-- THE HOOK. One TooltipDataProcessor post call for the Item data type (NS.Compat.HookItemTooltips),
-- registered once at OnEnable on WoW Forever whatever the latch says, so it covers every tooltip
-- the client fills with an item: the bags, chat links (ItemRefTooltip), the loot window, the
-- comparison tooltips and other addons' GameTooltip uses. The client keeps a post call for the
-- session, so the call itself checks, cheapest first: the addon stands up, the tooltip switch is
-- on, ForeverDB is LOADED (the owner: without ForeverDB, or before its load, no block at all, not
-- even Crafting; spec §1), the tooltip may be written, the data names an item, a comparison
-- tooltip only when that setting allows it (off by default, the owner), Shift held when the
-- Shift-only setting is on, and the block not already on this tooltip for this item.
--
-- NEVER TWICE, NEVER A LOAD. The block marks the tooltip with the item id it wrote and skips a
-- second post call for the same item; the mark goes on the tooltip's OnHide and OnTooltipCleared
-- (hooked once per tooltip), so the client's own refresh, which clears the tooltip first, writes it
-- again. The facts come from NS.ItemSearch.Get, which reads ForeverDB only once it is loaded and
-- never loads it (spec §2), and keeps each item's static facts for the session (spec §4.3), so a
-- warm hover reads nothing from the database.
--
-- SECRET-SAFE. The call reads the post call's data.id (else the id in data.hyperlink) and nothing
-- else of the tooltip: never another line's text (client-quirks: a tooltip's text can be secret).
--
-- WHAT IT WRITES (IST.Lines, pure; IST.Paint writes it):
--   * the separator, a 1 px rule in the skin's accent (`text.accent`, read at call time), and the
--     title line, the `search` magnifier and "Drop Watcher · Item Search" in the same accent
--     (the "Separator and title line" setting);
--   * the switched-on sections in the settings' order (IST.ORDER by default), each a heading in
--     the tooltip label's muted gold and its rows, an empty section left out:
--       Drops from  the first `rows` sources (name, level range; chance on the right), a
--                   World drop row with its minimum level, then "and N more";
--       Sold by     the vendors (the cheapest one's price on the right), then "and N more";
--       Quests      `!` in your log, `?` not picked up yet, a check mark completed (left out while
--                   "Hide completed quests" is on); the quest's level on the right;
--       Crafting    a filled dot for a recipe you know, in its skill-up color, a dashed ring for one
--                   you don't; the profession on the right;
--       Also        the quests that reward the item and the quest it starts;
--   * the hint "<key>: open in Item Search", naming the key bound to C.ITEM_SEARCH.BINDING as the
--     client writes it, left out when nothing is bound (the "Keybind hint line" setting).
-- An item with no row in any switched-on section gets no block at all, title and hint included.
--
-- THE MARKS are texture escapes of LibKa0s media icons (`confirm`, `ph:circle`, `ph:circle-dashed`,
-- `search`), tinted through the escape: the tooltip's face draws no check mark or circles (the
-- glyph guard's safe set), as NS.TipMarks' verdict marks. `!` and `?` are text.

NS.ItemSearchTip = NS.ItemSearchTip or {}
local IST = NS.ItemSearchTip
local IS  = NS.ItemSearch
local C   = NS.Constants
local L   = NS.L

local Compat = NS.Compat

--- The sections' default order, and which are on by default (spec §4.7).
IST.ORDER = { "drops", "vendors", "quests", "crafting", "also" }
IST.SECTIONS = { drops = true, vendors = true, quests = true, crafting = true, also = false }

-- The separator's texture: the client's plain white square, tinted by the escape.
IST.RULE_TEXTURE = "Interface\\Buttons\\WHITE8X8"

local SKILL_TONE = { orange = "skillOrange", yellow = "skillYellow", green = "skillGreen", gray = "skillGray" }

-- With the media library absent (NS.Icon answers nil) a mark falls back to a character every face has.
local FALLBACK = { done = "+", known = "*", unknown = "o" }

local shownOn = setmetatable({}, { __mode = "k" })   -- tooltip -> the item id its block shows
local watched = setmetatable({}, { __mode = "k" })   -- tooltips whose OnHide / OnTooltipCleared are hooked
local installed = false

-- ── colors and marks ────────────────────────────────────────────────────────────────────────

-- A tone's r, g, b: "accent" is the skin's text.accent, read now; otherwise a C.TONE key.
local function rgb(tone)
    if tone == "accent" then
        local r, g, b = NS.SkinColor("text.accent")
        if r then return r, g, b end
        tone = "mutedGold"
    end
    local t = C.TONE[tone or "plain"] or C.TONE.plain
    return t.r, t.g, t.b
end

local function colored(text, tone)
    return NS.GroupRoster.Colored(text, rgb(tone))
end

-- A media icon as a tinted escape, or `fallback` without the library.
local function icon(name, tone, fallback)
    local path = NS.Icon(name)
    if not path then return colored(fallback, tone) end
    return NS.TipMarks.Escape(path, rgb(tone))
end

--- A quest row's mark: `!` (in your log), `?` (not picked up), the check mark (completed).
--- @param state string "log" | "todo" | "done"
--- @return string
function IST.QuestMark(state)
    if state == "log" then return colored("!", "yellow") end
    if state == "done" then return icon("confirm", "good", FALLBACK.done) end
    return colored("?", "muted")
end

--- A crafting row's mark: a filled dot in the skill-up color for a known recipe (plain without
--- one), a muted dashed ring for one you don't know.
--- @param row table a crafting row (IS.Live's)
--- @return string
function IST.CraftMark(row)
    if row.known then return icon("ph:circle", SKILL_TONE[row.color] or "plain", FALLBACK.known) end
    return icon("ph:circle-dashed", "muted", FALLBACK.unknown)
end

--- The separator: a RULE_WIDTH x 1 rule in the accent.
--- @return string
function IST.Rule()
    local r, g, b = rgb("accent")
    local function byte(v) return math.floor(math.max(0, math.min(1, v)) * 255 + 0.5) end
    return ("|T%s:1:%d:0:0:8:8:0:8:0:8:%d:%d:%d|t"):format(IST.RULE_TEXTURE, C.ITEM_SEARCH.RULE_WIDTH,
        byte(r), byte(g), byte(b))
end

-- ── the profession names ────────────────────────────────────────────────────────────────────

local PROFESSION
local function professionName(skillLine)
    PROFESSION = PROFESSION or {
        [129] = L["First Aid"], [164] = L["Blacksmithing"], [165] = L["Leatherworking"], [171] = L["Alchemy"],
        [185] = L["Cooking"], [197] = L["Tailoring"], [202] = L["Engineering"], [333] = L["Enchanting"],
        [755] = L["Jewelcrafting"],
    }
    return skillLine and PROFESSION[skillLine] or nil
end

--- A crafting skill line's profession name (the shipped table's nine), or nil. The Item Search
--- window's Crafting rows name it too.
--- @param skillLine number|nil
--- @return string|nil
function IST.ProfessionName(skillLine)
    return professionName(skillLine)
end

-- ── the lines (pure over the facts and the options) ────────────────────────────────────────

-- A line: { text, tone, right, rightTone }.
local function add(out, text, tone, right, rightTone)
    out[#out + 1] = { text = text, tone = tone, right = right, rightTone = rightTone }
end

local INDENT = "  "

local function levelRange(s)
    if not s.minLevel then return "" end
    if s.maxLevel and s.maxLevel ~= s.minLevel then return (" (%d-%d)"):format(s.minLevel, s.maxLevel) end
    return (" (%d)"):format(s.minLevel)
end

local function more(out, n)
    if n > 0 then add(out, INDENT .. L["and %d more"]:format(n), "muted") end
end

local function dropsLines(f, o, out)
    if #f.drops == 0 and not f.worldMinLevel then return end
    add(out, L["Drops from"], "mutedGold")
    for i = 1, math.min(o.rows, #f.drops) do
        local s = f.drops[i]
        add(out, INDENT .. s.name .. levelRange(s), s.named and "plain" or "muted",
            IS.Percent(s.chance) or L["rate unknown"], s.chance and "plain" or "muted")
    end
    if f.worldMinLevel then
        add(out, INDENT .. L["World drop"], "plain", L["level %d+"]:format(f.worldMinLevel), "muted")
    end
    more(out, f.dropMore or 0)
end

local function vendorLines(f, _, out)
    if #f.vendors == 0 then return end
    add(out, L["Sold by"], "mutedGold")
    local cheapest = f.vendorPrice and f.vendorPrice.npc
    local shown = math.min(C.ITEM_SEARCH.TIP_VENDORS, #f.vendors)
    for i = 1, shown do
        local v = f.vendors[i]
        local price = v.id == cheapest and Compat.CoinText(f.vendorPrice.price) or nil
        add(out, INDENT .. v.name, "plain", price, "plain")
    end
    more(out, #f.vendors - shown)
end

local function questLines(f, o, out)
    local rows = {}
    for _, q in ipairs(f.quests) do
        if not (o.hideCompleted and q.state == "done") then rows[#rows + 1] = q end
    end
    if #rows == 0 then return end
    add(out, L["Quests"], "mutedGold")
    for _, q in ipairs(rows) do
        add(out, INDENT .. IST.QuestMark(q.state) .. " " .. (q.title or L["Quest %d"]:format(q.id)), "plain",
            q.level and L["level %d"]:format(q.level) or nil, "muted")
    end
end

local function craftingLines(f, _, out)
    if #f.crafting == 0 then return end
    add(out, L["Crafting"], "mutedGold")
    for _, r in ipairs(f.crafting) do
        add(out, INDENT .. IST.CraftMark(r) .. " " .. (r.name or L["Recipe %d"]:format(r.spell)),
            r.known and "plain" or "muted", professionName(r.skillLine), "muted")
    end
end

local function alsoLines(f, _, out)
    local starts = f.startsQuest
    if #f.rewardFrom == 0 and not starts then return end
    add(out, L["Also"], "mutedGold")
    for _, q in ipairs(f.rewardFrom) do
        add(out, INDENT .. L["Reward from"], "muted", q.title or L["Quest %d"]:format(q.id), "plain")
    end
    if starts then
        add(out, INDENT .. L["Starts quest"], "muted", starts.title or L["Quest %d"]:format(starts.id), "plain")
    end
end

local SECTION = { drops = dropsLines, vendors = vendorLines, quests = questLines, crafting = craftingLines,
    also = alsoLines }

--- The block's lines for `facts` under the options `o` (IST.Options' shape) and the bound key's
--- text (nil: unbound). `{}` when no switched-on section has a row: no block at all.
--- @param facts table NS.ItemSearch.Get's answer
--- @param o table
--- @param keyText string|nil
--- @return table lines `{ { text, tone, right, rightTone } ... }`
function IST.Lines(facts, o, keyText)
    local body = {}
    for _, key in ipairs(o.order) do
        if o.sections[key] and SECTION[key] then SECTION[key](facts, o, body) end
    end
    if #body == 0 then return body end
    local out = {}
    if o.header then
        add(out, IST.Rule(), "accent")
        add(out, icon("search", "accent", "") .. " " .. L["Drop Watcher · Item Search"], "accent")
    end
    for _, line in ipairs(body) do out[#out + 1] = line end
    if o.hint and keyText then add(out, L["%s: open in Item Search"]:format(keyText), "muted") end
    return out
end

-- ── the options ─────────────────────────────────────────────────────────────────────────────

local function setting(key, default)
    local v = NS.Setting("itemSearch.tooltip." .. key)
    if v == nil then return default end
    return v
end

-- The order as stored, known keys once each, then any missing key in the default order.
local function orderOf(stored)
    if type(stored) ~= "table" then return IST.ORDER end
    local out, seen = {}, {}
    for _, key in ipairs(stored) do
        if SECTION[key] and not seen[key] then seen[key] = true; out[#out + 1] = key end
    end
    for _, key in ipairs(IST.ORDER) do
        if not seen[key] then out[#out + 1] = key end
    end
    return out
end

local function sectionsOf(stored)
    if type(stored) ~= "table" then return IST.SECTIONS end
    local out = {}
    for key, on in pairs(IST.SECTIONS) do
        if stored[key] == nil then out[key] = on else out[key] = stored[key] == true end
    end
    return out
end

--- The tooltip block's settings, read now (spec §4.7; every key under itemSearch.tooltip):
--- `{ enabled, shiftOnly, header, hint, comparison, hideCompleted, rows, sections, order }`.
--- @return table
function IST.Options()
    local shown = IS.ClampRows(setting("rows", IS.TIP_ROWS))
    return {
        enabled = setting("enabled", true) == true, shiftOnly = setting("shiftOnly", false) == true,
        header = setting("header", true) == true, hint = setting("hint", true) == true,
        comparison = setting("comparison", false) == true, hideCompleted = setting("hideCompleted", true) == true,
        rows = shown,
        sections = sectionsOf(setting("sections")), order = orderOf(setting("order")),
    }
end

-- ── painting and the hook ───────────────────────────────────────────────────────────────────

--- Write `lines` onto `tip`: AddDoubleLine for a line with a right side, else AddLine (no wrap),
--- each in its tone; then Show again, so a shown tooltip lays itself out around the new lines.
--- @param tip table
--- @param lines table IST.Lines' answer
function IST.Paint(tip, lines)
    for _, line in ipairs(lines) do
        local r, g, b = rgb(line.tone)
        if line.right and type(tip.AddDoubleLine) == "function" then
            local rr, rg, rb = rgb(line.rightTone)
            tip:AddDoubleLine(line.text, line.right, r, g, b, rr, rg, rb)
        else
            tip:AddLine(line.text, r, g, b, false)
        end
    end
    if type(tip.IsShown) == "function" and tip:IsShown() and type(tip.Show) == "function" then tip:Show() end
end

local function clearMark(tip)
    shownOn[tip] = nil
end

-- Hook the tooltip's OnHide and OnTooltipCleared once, so its mark goes when it hides or clears.
local function watch(tip)
    if watched[tip] or type(tip.HookScript) ~= "function" then return end
    watched[tip] = true
    tip:HookScript("OnHide", clearMark)
    if type(tip.HasScript) ~= "function" or tip:HasScript("OnTooltipCleared") then
        tip:HookScript("OnTooltipCleared", clearMark)
    end
end

--- Whether a block may be written now: WoW Forever, the addon up, the tooltip switch on, and
--- ForeverDB loaded (the owner: nothing before that, spec §1). Never loads anything.
--- @return boolean
function IST.Active()
    if not IS.Enabled() or (NS.IsStoodDown and NS.IsStoodDown()) then return false end
    if NS.Setting("itemSearch.tooltip.enabled") ~= true then return false end
    return IS.State() == "loaded"
end

--- The item tooltip post call (see the header). Answers whether it wrote a block, for the tests.
--- @param tip table
--- @param data table|nil the post call's tooltip data
--- @return boolean
function IST.OnTooltip(tip, data)
    if not IST.Active() or not Compat.TooltipWritable(tip) then return false end
    local itemID = Compat.TooltipItemID(data)
    if not itemID or shownOn[tip] == itemID then return false end
    local o = IST.Options()
    if not o.comparison and Compat.IsComparisonTooltip(tip) then return false end
    if o.shiftOnly and not Compat.ShiftDown() then return false end
    local facts = IS.Get(itemID, o)
    if not facts then return false end
    local lines = IST.Lines(facts, o, o.hint and Compat.BindingKeyText(C.ITEM_SEARCH.BINDING) or nil)
    if #lines == 0 then return false end
    watch(tip)
    shownOn[tip] = itemID
    IST.Paint(tip, lines)
    return true
end

--- Register the post call, once a session, on WoW Forever (core/DropWatcher.lua's OnEnable).
--- Answers whether the hook is in.
--- @return boolean
function IST.Install()
    if installed or not IS.Enabled() then return installed end
    installed = Compat.HookItemTooltips(function(tip, data) IST.OnTooltip(tip, data) end)
    return installed
end
