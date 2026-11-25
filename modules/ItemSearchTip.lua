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
--     title line "Drop Watcher · Item Search" in the same accent, with no icon before it (Item
--     Search feedback spec §7, T2; the "Separator and title line" setting);
--   * the switched-on sections in the settings' order (IST.ORDER by default), each a heading in
--     the tooltip label's muted gold and its rows, an empty section left out. Every section's rows
--     come in NS.ItemSearch.Rank's order for the player now (feedback spec §3) and stop at
--     `itemSearch.tooltip.rows` (5 by default, 1 to 20; §7), the rest one "and N more" line:
--       Drops from    the sources (name, level range; chance on the right), then a World drop row
--                     with its minimum level, then "and N more";
--       Sold by       the vendors (the cheapest one's price on the right);
--       Quests        `!` in your log, `?` not picked up yet, a check mark completed (left out while
--                     "Hide completed quests" is on); the quest's level on the right;
--       Crafting      the recipe glyph (IST.CraftMark, §5.7) and the profession on the right; with
--                     "Only professions you know" on (§4) the other professions' recipes are left
--                     out and counted on one dim line, "+N in professions you don't know", after
--                     "and N more" (the heading and that line alone when every recipe is filtered);
--       Skinned from  the creatures (name, level range; chance on the right);
--       Also          the quests that reward the item and the quest it starts;
--   * the hint "<key>: open in Item Search", naming the key bound to C.ITEM_SEARCH.BINDING as the
--     client writes it (GetBindingKey through GetBindingText, so `ALT-CTRL-D` reads `Alt-Ctrl-D`),
--     left out when nothing is bound (the "Show the key hint" setting, feedback spec §1).
-- An item with no row in any switched-on section gets no block at all, title and hint included.
--
-- THE MARKS are texture escapes of LibKa0s media icons (`confirm`, and the recipe glyphs
-- `ph:arrow-fat-up`, `ph:arrows-horizontal` and `ph:lock`), tinted through the escape: the tooltip's
-- face draws no check mark, arrow or padlock (the glyph guard's safe set), as NS.TipMarks' verdict
-- marks. The recipe glyphs carry an explicit C.ITEM_SEARCH.GLYPH_SIZE (14:14), so the tooltip and the
-- window's glyph column draw them at one size (round 3 spec §4.1). `!` and `?` are text.

NS.ItemSearchTip = NS.ItemSearchTip or {}
local IST = NS.ItemSearchTip
local IS  = NS.ItemSearch
local C   = NS.Constants
local L   = NS.L

local Compat = NS.Compat

--- The sections' default order, and which are on by default (spec §4.7).
IST.ORDER = { "drops", "vendors", "quests", "crafting", "skinned", "also" }
IST.SECTIONS = { drops = true, vendors = true, quests = true, crafting = true, skinned = true, also = false }

-- The separator's texture: the client's plain white square, tinted by the escape.
IST.RULE_TEXTURE = "Interface\\Buttons\\WHITE8X8"

local SKILL_TONE = { orange = "skillOrange", yellow = "skillYellow", green = "skillGreen", gray = "skillGray" }

-- The recipe glyphs (round 3 spec §4.1, after feedback spec §5.7): each glyph's icon, its tone (the
-- skill-up's own for an up arrow), and the character it falls back to.
local GLYPH = {
    up     = { icon = "ph:arrow-fat-up", fallback = "^" },
    flat   = { icon = "ph:arrows-horizontal", tone = "glyphKnown", fallback = "=" },
    locked = { icon = "ph:lock", tone = "glyphLocked", fallback = "x" },
}
local SKILL_UP = { orange = true, yellow = true, green = true }

-- With the media library absent (NS.Icon answers nil) a mark falls back to a character every face has.
local FALLBACK = { done = "+" }

local shownOn = setmetatable({}, { __mode = "k" })   -- tooltip -> the item id its block shows
local watched = setmetatable({}, { __mode = "k" })   -- tooltips whose OnHide / OnTooltipCleared are hooked
local installed = false
local tipMe = {}   -- the hover's ranking context, refilled by IS.Me on each post call (never kept)

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

-- A media icon as a tinted escape, or `fallback` without the library. `size` (pixels) fixes the
-- escape's size; nil draws it at the text's height (0:0).
local function icon(name, tone, fallback, size)
    local path = NS.Icon(name)
    if not path then return colored(fallback, tone) end
    local r, g, b = rgb(tone)
    return NS.TipMarks.Escape(path, r, g, b, size)
end

--- A quest row's mark: `!` (in your log), `?` (not picked up), the check mark (completed).
--- @param state string "log" | "todo" | "done"
--- @return string
function IST.QuestMark(state)
    if state == "log" then return colored("!", "yellow") end
    if state == "done" then return icon("confirm", "good", FALLBACK.done) end
    return colored("?", "muted")
end

--- A crafting row's glyph (feedback spec §5.7): "up" for a known recipe that can skill up (orange,
--- yellow or green), "flat" for a known one that cannot (gray, or no breakpoints to tell), "locked"
--- for one you don't know.
--- @param row table a crafting row (IS.Live's)
--- @return string
function IST.CraftGlyph(row)
    if not row.known then return "locked" end
    if SKILL_UP[row.color] then return "up" end
    return "flat"
end

--- A crafting row's mark, in the tooltip and the window alike: a fat up arrow in the skill-up color,
--- a light gray left-right arrow, or a dark gray padlock (IST.CraftGlyph), each at
--- C.ITEM_SEARCH.GLYPH_SIZE. The shapes differ as well as the colors, so a color-blind player reads
--- them too.
--- @param row table a crafting row (IS.Live's)
--- @return string
function IST.CraftMark(row)
    local glyph = IST.CraftGlyph(row)
    local g = GLYPH[glyph]
    local tone = glyph == "up" and SKILL_TONE[row.color] or g.tone
    return icon(g.icon, tone, g.fallback, C.ITEM_SEARCH.GLYPH_SIZE)
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

-- Each section writes from `f` (the facts) and `r` (IS.Ranked's answer for them), capped at o.rows.
-- How many of `rows` show under the cap `n` (IS.Cap's count, without its new array: the block is
-- written on every hover), and how many are past them.
local function capped(rows, n)
    local k = math.min(IS.ClampRows(n), #rows)
    return k, #rows - k
end

local function dropsLines(f, r, o, out)
    if #r.drops == 0 and not f.worldMinLevel then return end
    add(out, L["Drops from"], "mutedGold")
    local shown, rest = capped(r.drops, o.rows)
    for i = 1, shown do
        local s = r.drops[i]
        add(out, INDENT .. s.name .. levelRange(s), s.named and "plain" or "muted",
            IS.Percent(s.chance) or L["rate unknown"], s.chance and "plain" or "muted")
    end
    if f.worldMinLevel then
        add(out, INDENT .. L["World drop"], "plain", L["level %d+"]:format(f.worldMinLevel), "muted")
    end
    more(out, rest)
end

local function vendorLines(f, r, o, out)
    if #r.vendors == 0 then return end
    add(out, L["Sold by"], "mutedGold")
    local cheapest = f.vendorPrice and f.vendorPrice.npc
    local shown, rest = capped(r.vendors, o.rows)
    for i = 1, shown do
        local v = r.vendors[i]
        local price = v.id == cheapest and Compat.CoinText(f.vendorPrice.price) or nil
        add(out, INDENT .. v.name, "plain", price, "plain")
    end
    more(out, rest)
end

local function questLines(_, r, o, out)
    local rows = {}
    for _, q in ipairs(r.quests) do
        if not (o.hideCompleted and q.state == "done") then rows[#rows + 1] = q end
    end
    if #rows == 0 then return end
    add(out, L["Quests"], "mutedGold")
    local shown, rest = capped(rows, o.rows)
    for i = 1, shown do
        local q = rows[i]
        add(out, INDENT .. IST.QuestMark(q.state) .. " " .. (q.title or L["Quest %d"]:format(q.id)), "plain",
            q.level and L["level %d"]:format(q.level) or nil, "muted")
    end
    more(out, rest)
end

local function craftingLines(_, r, o, out)
    local hidden = r.craftHidden or 0
    if #r.crafting == 0 and hidden == 0 then return end
    add(out, L["Crafting"], "mutedGold")
    local shown, rest = capped(r.crafting, o.rows)
    for i = 1, shown do
        local c = r.crafting[i]
        add(out, INDENT .. IST.CraftMark(c) .. " " .. (c.name or L["Recipe %d"]:format(c.spell)),
            c.known and "plain" or "muted", professionName(c.skillLine), "muted")
    end
    more(out, rest)
    if hidden > 0 then add(out, INDENT .. L["+%d in professions you don't know"]:format(hidden), "muted") end
end

local function skinnedLines(_, r, o, out)
    if #r.skinned == 0 then return end
    add(out, L["Skinned from"], "mutedGold")
    local shown, rest = capped(r.skinned, o.rows)
    for i = 1, shown do
        local s = r.skinned[i]
        add(out, INDENT .. s.name .. levelRange(s), "plain", IS.Percent(s.chance) or L["rate unknown"],
            s.chance and "plain" or "muted")
    end
    more(out, rest)
end

local function alsoLines(f, _, o, out)
    local starts = f.startsQuest
    if #f.rewardFrom == 0 and not starts then return end
    add(out, L["Also"], "mutedGold")
    local shown, rest = capped(f.rewardFrom, o.rows)
    for i = 1, shown do
        local q = f.rewardFrom[i]
        add(out, INDENT .. L["Reward from"], "muted", q.title or L["Quest %d"]:format(q.id), "plain")
    end
    more(out, rest)
    if starts then
        add(out, INDENT .. L["Starts quest"], "muted", starts.title or L["Quest %d"]:format(starts.id), "plain")
    end
end

local SECTION = { drops = dropsLines, vendors = vendorLines, quests = questLines, crafting = craftingLines,
    skinned = skinnedLines, also = alsoLines }

--- The block's lines for `facts` under the options `o` (IST.Options' shape), the bound key's text
--- (nil: unbound) and the ranking's context `me` (NS.ItemSearch.Me's shape; nil ranks with no
--- context). `{}` when no switched-on section has a row: no block at all.
--- @param facts table NS.ItemSearch.Get's answer
--- @param o table
--- @param keyText string|nil
--- @param me table|nil
--- @return table lines `{ { text, tone, right, rightTone } ... }`
function IST.Lines(facts, o, keyText, me)
    local ranked = IS.Ranked(facts, me or {}, o.mine)
    local body = {}
    for _, key in ipairs(o.order) do
        if o.sections[key] and SECTION[key] then SECTION[key](facts, ranked, o, body) end
    end
    if #body == 0 then return body end
    local out = {}
    if o.header then
        add(out, IST.Rule(), "accent")
        add(out, L["Drop Watcher · Item Search"], "accent")
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

-- The last stored order (a copy) and sections (the values read) with their answers: Options runs
-- on every hover, so an unchanged setting answers the same table again rather than a new one.
local lastOrder = { stored = nil, out = nil }
local lastSections = { seen = {}, out = nil }

local function sameOrder(stored)
    local copy = lastOrder.stored
    if not copy or #copy ~= #stored then return false end
    for i = 1, #stored do
        if copy[i] ~= stored[i] then return false end
    end
    return true
end

-- The order as stored, known keys once each, then any missing key in the default order.
local function orderOf(stored)
    if type(stored) ~= "table" then return IST.ORDER end
    if sameOrder(stored) then return lastOrder.out end
    local out, seen = {}, {}
    for _, key in ipairs(stored) do
        if SECTION[key] and not seen[key] then seen[key] = true; out[#out + 1] = key end
    end
    for _, key in ipairs(IST.ORDER) do
        if not seen[key] then out[#out + 1] = key end
    end
    local copy = {}
    for i, key in ipairs(stored) do copy[i] = key end
    lastOrder.stored, lastOrder.out = copy, out
    return out
end

local function sameSections(stored)
    if not lastSections.out then return false end
    for key in pairs(IST.SECTIONS) do
        if lastSections.seen[key] ~= stored[key] then return false end
    end
    return true
end

local function sectionsOf(stored)
    if type(stored) ~= "table" then return IST.SECTIONS end
    if sameSections(stored) then return lastSections.out end
    local out, seen = {}, {}
    for key, on in pairs(IST.SECTIONS) do
        seen[key] = stored[key]
        if stored[key] == nil then out[key] = on else out[key] = stored[key] == true end
    end
    lastSections.seen, lastSections.out = seen, out
    return out
end

--- The tooltip block's settings, read now (spec §4.7; every key under itemSearch.tooltip):
--- `{ enabled, shiftOnly, header, hint, comparison, hideCompleted, rows, mine, sections, order }`
--- (`mine`: itemSearch.myProfessionsOnly, feedback spec §4).
--- @return table
function IST.Options()
    local shown = IS.ClampRows(setting("rows", IS.TIP_ROWS))
    return {
        enabled = setting("enabled", true) == true, shiftOnly = setting("shiftOnly", false) == true,
        header = setting("header", true) == true, hint = setting("hint", true) == true,
        comparison = setting("comparison", false) == true, hideCompleted = setting("hideCompleted", true) == true,
        rows = shown, mine = IS.MyProfessionsOnly(),
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
    local facts = IS.Get(itemID)
    if not facts then return false end
    local lines = IST.Lines(facts, o, o.hint and Compat.BindingKeyText(C.ITEM_SEARCH.BINDING) or nil,
        IS.Me(facts.ranks, tipMe))
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
