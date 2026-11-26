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
--   * the separator (round 3 spec §4.2, item 14b; the "Separator line" setting): one blank spacer
--     line with a hairline lying across its middle, a Texture of the tooltip's own (one per
--     tooltip, made on first use), C.ITEM_SEARCH.RULE_INSET in from each edge, one physical pixel
--     tall (LibKa0s-Core's __PixelSize) and tinted the owner token `dw.tipRule`. It never sets the
--     tooltip's width. It is hidden on the tooltip's OnHide and OnTooltipCleared, and placed again
--     on its OnSizeChanged and once on the next frame (the post call can run before the tooltip is
--     laid out);
--   * the label line, always (item 14a): "Drop Watcher" at the left in the tooltip label's muted
--     gold, the verdict badge at the right (round 3 spec §4.5, item 14c; the "Show the Keep / Hold /
--     Sell / Toss badge" setting): `<icon> <Verdict> <score> · <Tier>`, the icon, word and score in
--     the verdict's tone and the tier muted (NS.ItemSearchVerdict, IST.Badge). The old title line
--     "Drop Watcher · Item Search" is gone;
--   * the badge's reasons (the "Explain the badge" setting, under the badge): its top two, each
--     "  · <reason>" with the bullet in muted gold, then, below a High confidence, the
--     confidence's fix, muted ("Confidence Medium: Open your profession window to rank recipes");
--   * the switched-on sections in the settings' order (IST.ORDER by default), each a heading in
--     the tooltip label's muted gold and its rows, an empty section left out. Every section's rows
--     come in NS.ItemSearch.Rank's order for the player now (feedback spec §3) and stop at
--     `itemSearch.tooltip.rows` (3 by default since ISR3-DW-07, 1 to 20; §7), the rest one
--     "and N more" line:
--       Drops from    the sources (name, level range; chance on the right), then a World drop row
--                     with its minimum level, then "and N more"; a creature's name in its rank's
--                     color (round 3 item 6: elite gold, rare silver, rare elite pale blue, boss
--                     purple, a normal one plain);
--       Gathered from the herbs, veins and fishing nodes (round 3 item 7): the node on the left,
--                     "<Profession> <skill> · <chance>" on the right, the skill red above your rank;
--       Sold by       the vendors, each with its own price on the right (round 3 item 8: the one
--                     Drop Watcher saw there, else ForeverDB's), or "Horde only" / "Alliance only"
--                     in red where only the other side can buy;
--       Quests        the game's marks (IST.QuestMark, round 3 item 13): the yellow `!` not picked
--                     up (dimmed while your level is too low), the gray `?` in your log, the green
--                     `?` complete and waiting to be turned in, a green check turned in (left out
--                     while "Hide completed quests" is on); the quest's level on the right;
--       Crafting      the recipe glyph (IST.CraftMark, §5.7); on the right the recipe's skill
--                     breakpoints, each in its skill-up hue (round 3 item 4, the window's Skill
--                     column's parts, memoized per recipe), then " · <profession>" in muted when
--                     the rows shown mix professions; the profession alone for a recipe with no
--                     breakpoints or with "Show recipe skill levels" off. With "Only professions
--                     you know" on (§4) the other professions' recipes are left out and counted on
--                     one dim line, "+N in professions you don't know", after "and N more" (the
--                     heading and that line alone when every recipe is filtered);
--       Skinned from  the creatures (name in its rank's color, level range; chance on the right);
--       Also          the quests that reward the item and the quest it starts;
--   * the hint "<key>: open in Item Search", naming the key bound to C.ITEM_SEARCH.BINDING as the
--     client writes it (GetBindingKey through GetBindingText, so `ALT-CTRL-D` reads `Alt-Ctrl-D`),
--     left out when nothing is bound (the "Show the key hint" setting, feedback spec §1).
-- An item with no row in any switched-on section gets no block at all, title and hint included.
--
-- THE MARKS are texture escapes, tinted through the escape: the tooltip's face draws no check mark,
-- arrow or padlock (the glyph guard's safe set), as NS.TipMarks' verdict marks. The recipe glyphs
-- are LibKa0s media icons (`ph:arrow-fat-up`, `ph:arrows-horizontal` and `ph:lock`) at an explicit
-- C.ITEM_SEARCH.GLYPH_SIZE (14:14), so the tooltip and the window's glyph column draw them at one
-- size (round 3 spec §4.1). The quest marks are the client's own GossipFrame icons and the media
-- icon `ph:check-fat`, at C.ITEM_SEARCH.MARK_SIZE, the same in the tooltip and the window (§4.2).
-- With the media library absent every mark falls back to a character every face has.

NS.ItemSearchTip = NS.ItemSearchTip or {}
local IST = NS.ItemSearchTip
local IS  = NS.ItemSearch
local C   = NS.Constants
local L   = NS.L

local Compat = NS.Compat

--- The sections' default order, and which are on by default (spec §4.7).
IST.ORDER = { "drops", "gathered", "vendors", "quests", "crafting", "skinned", "also" }
IST.SECTIONS = { drops = true, gathered = true, vendors = true, quests = true, crafting = true, skinned = true,
    also = false }

-- The separator's texture: the client's plain white square, tinted `dw.tipRule`.
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

-- The quest marks (round 3 spec §4.2, item 13), per ISC.QuestStatus' state: the client's own
-- GossipFrame icon (`gossip`, QUEST_ICON's word) or the media icon, the tint multiplied in (nil:
-- none, the texture's own colors; a C.TONE key; or "dim", the `!` at half its brightness), and the
-- character and tone of the fallback with the media library absent.
local QUEST_ICON = "Interface\\GossipFrame\\%sQuestIcon"
local QUEST_MARK = {
    can   = { gossip = "Available", fallback = "!", fallbackTone = "yellow" },
    high  = { gossip = "Available", tint = "dim", fallback = "!", fallbackTone = "muted" },
    log   = { gossip = "Incomplete", fallback = "?", fallbackTone = "muted" },
    ready = { gossip = "Active", tint = "good", fallback = "?", fallbackTone = "good" },
    done  = { icon = "ph:check-fat", tint = "good", fallback = "+", fallbackTone = "good" },
}
local DIM = 0.5
local INDENT = "  "

local shownOn = setmetatable({}, { __mode = "k" })   -- tooltip -> the item id its block shows
local watched = setmetatable({}, { __mode = "k" })   -- tooltips whose OnHide / OnTooltipCleared are hooked
local rules = setmetatable({}, { __mode = "k" })     -- tooltip -> its separator { tex, line, place }
local installed = false
local tipMe = {}   -- the hover's ranking context, refilled by IS.Me on each post call (never kept)

-- The memos a hover reads instead of building strings (round 3 spec §4.2): the quest marks per
-- size and state, and each recipe's colored skill parts. Both hold skin tones, so a skin switch
-- empties them.
-- The badge's strings and its reason lines (round 3 spec §4.5) are kept too, by what they show
-- rather than by answer, so a verdict worked out again draws the same strings: the badge per verdict,
-- tier and score, each reason's line per reason text and each confidence line per tier and fix (at
-- most C.ITEM_SEARCH.VERDICT.LINE_CAP reason lines, then emptied). They go with the skin's tones.
local markMemo, partsMemo, badgeMemo, reasonMemo, hintMemo = {}, {}, {}, {}, {}
local reasonCount = 0
local function forgetLooks()
    markMemo, partsMemo, badgeMemo, reasonMemo, hintMemo = {}, {}, {}, {}, {}
    reasonCount = 0
end
if NS.Skin and type(NS.Skin.OnLooksChanged) == "function" then NS.Skin.OnLooksChanged(forgetLooks) end

--- Empty the hover's memos (the quest marks, the recipes' skill parts and the badges): the skin's
--- OnLooksChanged listener, and a suite's handle.
function IST.ForgetLooks()
    forgetLooks()
end

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

-- A mark's tint: its tone's color, or the texture's own colors scaled by 1 (none) or DIM.
local function tintOf(m)
    if m.tint and m.tint ~= "dim" then return rgb(m.tint) end
    local k = m.tint == "dim" and DIM or 1
    return k, k, k
end

local function questMark(m, size)
    if not NS.Icon(QUEST_MARK.done.icon) then return colored(m.fallback, m.fallbackTone) end
    local path = m.icon and NS.Icon(m.icon) or QUEST_ICON:format(m.gossip)
    local r, g, b = tintOf(m)
    return NS.TipMarks.Escape(path, r, g, b, size)
end

--- A quest's mark in the game's style (round 3 spec §4.2, item 13), the tooltip's and the window's
--- alike, by NS.ItemSearchCells.QuestStatus' state: "can" the yellow `!` (AvailableQuestIcon),
--- "high" the same `!` dimmed (your level is too low), "log" the gray `?` (IncompleteQuestIcon),
--- "ready" the `?` (ActiveQuestIcon) tinted green, "done" a plain fat check (`ph:check-fat`) in
--- green. `size` pixels square (C.ITEM_SEARCH.MARK_SIZE by default). Without the media library the
--- characters `!`, `?` and `+`, colored. An unknown state reads as "can".
--- @param state string
--- @param size number|nil
--- @return string
function IST.QuestMark(state, size)
    size = size or C.ITEM_SEARCH.MARK_SIZE
    local bySize = markMemo[size]
    if not bySize then bySize = {}; markMemo[size] = bySize end
    local key = QUEST_MARK[state] and state or "can"
    local mark = bySize[key]
    if not mark then
        mark = questMark(QUEST_MARK[key], size)
        bySize[key] = mark
    end
    return mark
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

--- A crafting row's skill breakpoints as one string, each part in its skill-up hue (IS.SkillParts,
--- the window's Skill column's), memoized per recipe: the breakpoints are static and the hues
--- change only with the skin (IST.ForgetLooks). Nil for a recipe with no breakpoints.
--- @param row table a crafting row
--- @return string|nil
function IST.SkillText(row)
    local spell = row.spell
    local memo
    if spell ~= nil then memo = partsMemo[spell] end
    if memo == false then return nil end
    if memo then return memo end
    local parts = IS.SkillParts(row)
    local text
    for _, p in ipairs(parts) do
        local part = colored(p.text, p.tone)
        text = text and (text .. " " .. part) or part
    end
    if spell ~= nil then partsMemo[spell] = text or false end
    return text
end

-- ── the verdict badge (round 3 spec §4.5, item 14c) ───────────────────────────────────────────

-- Each verdict's icon and tone: Keep a padlock in `good`, Hold an hourglass in `yellow`, Sell coins in
-- `warn` (amber: gold is the label's tone on the same line), Toss a bin in `bad`.
local VERDICT_LOOK = {
    keep = { icon = "ph:lock", tone = "good" },
    hold = { icon = "ph:hourglass", tone = "yellow" },
    sell = { icon = "ph:coins", tone = "warn" },
    toss = { icon = "ph:trash", tone = "bad" },
}

local function verdictWord(verdict)
    if verdict == "keep" then return L["Keep"] end
    if verdict == "sell" then return L["Sell"] end
    if verdict == "toss" then return L["Toss"] end
    return L["Hold"]
end

local function tierWord(tier)
    if tier == "high" then return L["High"] end
    if tier == "medium" then return L["Medium"] end
    return L["Low"]
end

local function badgeText(v)
    local look = VERDICT_LOOK[v.verdict] or VERDICT_LOOK.hold
    local mark = NS.Icon(look.icon) and (icon(look.icon, look.tone, "", C.ITEM_SEARCH.MARK_SIZE) .. " ") or ""
    return mark .. colored(("%s %d"):format(verdictWord(v.verdict), v.score), look.tone) .. " "
        .. colored(L["· %s"]:format(tierWord(v.tier)), "muted")
end

-- A memo's branch under `key`, made on first use.
local function branch(t, key)
    local b = t[key]
    if not b then b = {}; t[key] = b end
    return b
end

--- The badge's string for a verdict answer (NS.ItemSearch.Verdict's): `<icon> <Verdict> <score> ·
--- <Tier>`, the icon (C.ITEM_SEARCH.MARK_SIZE; none without the media library), word and score in
--- the verdict's tone, the tier muted. The same string for the same verdict, tier and score until
--- the skin's looks change.
--- @param v table
--- @return string
function IST.Badge(v)
    local byScore = branch(branch(badgeMemo, v.verdict or "hold"), v.tier or "low")
    local text = byScore[v.score]
    if not text then
        text = badgeText(v)
        byScore[v.score] = text
    end
    return text
end

local function reasonLine(text)
    local line = reasonMemo[text]
    if line then return line end
    if reasonCount >= C.ITEM_SEARCH.VERDICT.LINE_CAP then reasonMemo, reasonCount = {}, 0 end
    line = { text = INDENT .. colored("·", "mutedGold") .. " " .. text, tone = "plain" }
    reasonMemo[text], reasonCount = line, reasonCount + 1
    return line
end

local function hintLine(v)
    local byHint = branch(hintMemo, v.tier or "low")
    local line = byHint[v.hint]
    if not line then
        line = { text = L["Confidence %s: %s"]:format(tierWord(v.tier), v.hint), tone = "muted" }
        byHint[v.hint] = line
    end
    return line
end

-- Append a verdict's reason lines to `out`: no table of their own (the block runs on every hover).
local function addReasons(out, v)
    for _, text in ipairs(v.reasons or {}) do out[#out + 1] = reasonLine(text) end
    if v.hint then out[#out + 1] = hintLine(v) end
end

--- The badge's reason lines for a verdict answer, a new array: one "  · <reason>" per reason (the
--- bullet in muted gold), then the confidence's fix, muted, below a High confidence. Each line is the
--- same table for the same text until the skin's looks change: a line is read, never changed.
--- @param v table
--- @return table
function IST.ReasonLines(v)
    local out = {}
    addReasons(out, v)
    return out
end

-- ── the profession names ────────────────────────────────────────────────────────────────────

local PROFESSION
local function professionName(skillLine)
    PROFESSION = PROFESSION or {
        [129] = L["First Aid"], [164] = L["Blacksmithing"], [165] = L["Leatherworking"], [171] = L["Alchemy"],
        [185] = L["Cooking"], [197] = L["Tailoring"], [202] = L["Engineering"], [333] = L["Enchanting"],
        [755] = L["Jewelcrafting"],
        -- the gathering lines, which WoW Forever gives recipes too (round 4, R4-DW-03)
        [182] = L["Herbalism"], [186] = L["Mining"], [356] = L["Fishing"], [393] = L["Skinning"],
    }
    return skillLine and PROFESSION[skillLine] or nil
end

--- A recipe skill line's profession name (the nine crafting lines and the four gathering ones), or
--- nil. The Item Search window's Crafting rows name it too.
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

-- A gathering row's right side: "<Profession> <skill> · <chance>", the skill in the Gathered from
-- tab's tone (NS.ItemSearchCells.GatherSkillCell), no skill for fishing.
local function gatherRight(g, ranks)
    local cells = NS.ItemSearchCells
    local right = cells.GATHER_NAME[g.gather] or ""
    if g.gather ~= "fishing" then
        local skill = cells.GatherSkillCell(g, ranks)
        right = right .. " " .. colored(skill.text, skill.tone)
    end
    return right .. " " .. L["· %s"]:format(IS.Percent(g.chance) or L["rate unknown"])
end

local function gatheredLines(_, r, o, out, me)
    local rows = r.gathered or {}
    if #rows == 0 then return end
    add(out, L["Gathered from"], "mutedGold")
    local shown, rest = capped(rows, o.rows)
    local ranks = me and me.ranks
    for i = 1, shown do
        local g = rows[i]
        add(out, INDENT .. g.name, "plain", gatherRight(g, ranks), "plain")
    end
    more(out, rest)
end

-- A vendor row's right side (round 3 spec §4.4): "Horde only" or "Alliance only" in red when only
-- the other side can buy there, else its own price (recorded, else ForeverDB's), else nothing.
local function vendorRight(v, me)
    local only = me and NS.ItemSearchCells.SideOnly(v, me)
    if only then return only, "red" end
    if type(v.price) == "number" then return Compat.CoinText(v.price), "plain" end
    return nil, "plain"
end

local function vendorLines(_, r, o, out, me)
    if #r.vendors == 0 then return end
    add(out, L["Sold by"], "mutedGold")
    local shown, rest = capped(r.vendors, o.rows)
    for i = 1, shown do
        local v = r.vendors[i]
        local right, rightTone = vendorRight(v, me)
        add(out, INDENT .. v.name, "plain", right, rightTone)
    end
    more(out, rest)
end

local function questLines(_, r, o, out, me)
    local rows = {}
    for _, q in ipairs(r.quests) do
        if not (o.hideCompleted and q.state == "done") then rows[#rows + 1] = q end
    end
    if #rows == 0 then return end
    add(out, L["Quests"], "mutedGold")
    local shown, rest = capped(rows, o.rows)
    local status, level = NS.ItemSearchCells.QuestStatus, me and me.level
    for i = 1, shown do
        local q = rows[i]
        local mark = IST.QuestMark(status(q.state, q.minLevel, level), C.ITEM_SEARCH.MARK_SIZE)
        add(out, INDENT .. mark .. " " .. (q.title or L["Quest %d"]:format(q.id)), "plain",
            q.level and L["level %d"]:format(q.level) or nil, "muted")
    end
    more(out, rest)
end

-- Whether the first `n` crafting rows come from more than one profession.
local function mixed(rows, n)
    local first = rows[1] and rows[1].skillLine
    for i = 2, n do
        if rows[i].skillLine ~= first then return true end
    end
    return false
end

-- A crafting row's right side: the skill parts (then " · <profession>" when the rows mix
-- professions), else the profession alone, muted.
local function craftRight(c, o, mix)
    local profession = professionName(c.skillLine)
    local parts = o.craftSkill and IST.SkillText(c) or nil
    if not parts then return profession, "muted" end
    if mix and profession then return parts .. " " .. colored(L["· %s"]:format(profession), "muted"), "plain" end
    return parts, "plain"
end

local function craftingLines(_, r, o, out)
    local hidden = r.craftHidden or 0
    if #r.crafting == 0 and hidden == 0 then return end
    add(out, L["Crafting"], "mutedGold")
    local shown, rest = capped(r.crafting, o.rows)
    local mix = o.craftSkill and mixed(r.crafting, shown)
    for i = 1, shown do
        local c = r.crafting[i]
        local right, rightTone = craftRight(c, o, mix)
        add(out, INDENT .. IST.CraftMark(c) .. " " .. (c.name or L["Recipe %d"]:format(c.spell)),
            c.known and "plain" or "muted", right, rightTone)
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

local SECTION = { drops = dropsLines, gathered = gatheredLines, vendors = vendorLines, quests = questLines, crafting = craftingLines,
    skinned = skinnedLines, also = alsoLines }

-- The block's head: the separator's spacer (the "Separator line" setting), the label line with the
-- badge at its right (the "Show the Keep / Hold / Sell / Toss badge" setting), and the badge's
-- reasons (the "Explain the badge" setting).
local function head(o, verdict)
    local out = {}
    if o.header then out[1] = { text = " ", rule = true } end
    verdict = o.badge and verdict or nil
    add(out, L["Drop Watcher"], "mutedGold", verdict and IST.Badge(verdict) or nil, "plain")
    if verdict and o.reasons then addReasons(out, verdict) end
    return out
end

--- The block's lines for `facts` under the options `o` (IST.Options' shape), the bound key's text
--- (nil: unbound), the ranking's context `me` (NS.ItemSearch.Me's shape; nil ranks with no
--- context) and the item's verdict (NS.ItemSearch.Verdict's answer; nil or `o.badge` off: no badge,
--- no reasons). `{}` when no switched-on section has a row: no block at all.
--- @param facts table NS.ItemSearch.Get's answer
--- @param o table
--- @param keyText string|nil
--- @param me table|nil
--- @param verdict table|nil
--- @return table lines `{ { text, tone, right, rightTone, rule } ... }` (`rule`: the separator's spacer)
function IST.Lines(facts, o, keyText, me, verdict)
    local ranked = IS.Ranked(facts, me or {}, o.mine)
    local body = {}
    for _, key in ipairs(o.order) do
        if o.sections[key] and SECTION[key] then SECTION[key](facts, ranked, o, body, me) end
    end
    if #body == 0 then return body end
    local out = head(o, verdict)
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
--- `{ enabled, shiftOnly, header, hint, comparison, hideCompleted, craftSkill, badge, reasons, rows,
--- mine, sections, order }` (`mine`: itemSearch.myProfessionsOnly, feedback spec §4; `craftSkill`:
--- round 3 §4.2; `badge` and `reasons`: round 3 §4.5).
--- @return table
function IST.Options()
    local shown = IS.ClampRows(setting("rows", IS.TIP_ROWS))
    return {
        enabled = setting("enabled", true) == true, shiftOnly = setting("shiftOnly", false) == true,
        header = setting("header", true) == true, hint = setting("hint", true) == true,
        comparison = setting("comparison", false) == true, hideCompleted = setting("hideCompleted", true) == true,
        craftSkill = setting("craftSkill", true) == true, badge = setting("badge", true) == true,
        reasons = setting("reasons", true) == true, rows = shown, mine = IS.MyProfessionsOnly(),
        sections = sectionsOf(setting("sections")), order = orderOf(setting("order")),
    }
end

-- ── the separator (round 3 spec §4.2, item 14b) ────────────────────────────────────────────

local function isNum(v) return type(v) == "number" and v == v end

--- Where the hairline's top goes, as an offset from the tooltip's top (UI units, negative going
--- down): across the vertical middle of the spacer line whose font string spans `lineTop` to
--- `lineBottom`, one `px` tall, rounded to whole pixels. Pure. Nil when any input is not a number
--- or `px` is not above 0 (the tooltip not laid out yet).
--- @param tipTop number|nil
--- @param lineTop number|nil
--- @param lineBottom number|nil
--- @param px number|nil one physical pixel in the tooltip's units
--- @return number|nil
function IST.RuleOffset(tipTop, lineTop, lineBottom, px)
    if not (isNum(tipTop) and isNum(lineTop) and isNum(lineBottom) and isNum(px)) or px <= 0 then return nil end
    local off = (lineTop + lineBottom) / 2 + px / 2 - tipTop
    return math.floor(off / px + 0.5) * px
end

-- One plain number from a region's geometry getter, or nil (no getter, not laid out, a secret).
local function geom(obj, getter)
    local fn = type(obj) == "table" and obj[getter]
    if type(fn) ~= "function" then return nil end
    local v = fn(obj)
    if Compat.IsSecret(v) or type(v) ~= "number" then return nil end
    return v
end

-- One physical pixel in `tip`'s units: LibKa0s-Core's __PixelSize (the library's one mechanism for
-- a 1 px edge), 1 without it.
local function onePixel(tip)
    local core = LibStub and LibStub("LibKa0s-Core-1.0", true)
    local px = core and type(core.__PixelSize) == "function" and core.__PixelSize(tip, 1) or nil
    if type(px) ~= "number" or px <= 0 then return 1 end
    return px
end

local function paintRule(tex)
    tex:SetVertexColor(NS.SkinColor("dw.tipRule"))
end

-- Lay the separator across its spacer line, or hide it: no spacer line on the tooltip now, or the
-- tooltip not laid out yet (the next frame's call, or its OnSizeChanged, places it then).
local function placeRule(tip)
    local st = rules[tip]
    if not st then return end
    local tex = st.tex
    local fs = st.line and Compat.TooltipLeftLine(tip, st.line)
    local px = onePixel(tip)
    local off = fs and IST.RuleOffset(geom(tip, "GetTop"), geom(fs, "GetTop"), geom(fs, "GetBottom"), px)
    if not off then tex:Hide(); return end
    local inset = C.ITEM_SEARCH.RULE_INSET
    tex:ClearAllPoints()
    tex:SetPoint("TOPLEFT", tip, "TOPLEFT", inset, off)
    tex:SetPoint("TOPRIGHT", tip, "TOPRIGHT", -inset, off)
    tex:SetHeight(px)
    tex:Show()
end

-- The tooltip's separator, made on its first block: a Texture of the tooltip's own, pixel snapping
-- off (its offset is rounded instead), painted `dw.tipRule` now and on every skin switch, placed
-- again on the tooltip's OnSizeChanged. Nil for a tooltip that makes no texture.
local function ruleOf(tip)
    local st = rules[tip]
    if st then return st end
    if type(tip.CreateTexture) ~= "function" then return nil end
    local tex = tip:CreateTexture(nil, "ARTWORK")
    if type(tex) ~= "table" then return nil end
    tex:SetTexture(IST.RULE_TEXTURE)
    if type(tex.SetSnapToPixelGrid) == "function" then tex:SetSnapToPixelGrid(false) end
    if type(tex.SetTexelSnappingBias) == "function" then tex:SetTexelSnappingBias(0) end
    NS.SkinPaint(tex, paintRule)
    tex:Hide()
    st = { tex = tex }
    st.place = function() placeRule(tip) end
    rules[tip] = st
    if type(tip.HookScript) == "function" then tip:HookScript("OnSizeChanged", st.place) end
    return st
end

local function hideRule(tip)
    local st = rules[tip]
    if not st then return end
    st.line = nil
    st.tex:Hide()
end

--- The tooltip's separator texture, or nil before its first block (for the tests and diagnostics).
--- @param tip table
--- @return table|nil
function IST.RuleOf(tip)
    local st = rules[tip]
    return st and st.tex or nil
end

-- ── painting and the hook ───────────────────────────────────────────────────────────────────

-- Write one line: AddDoubleLine with a right side, else AddLine (no wrap), each in its tone.
local function addTo(tip, line)
    local r, g, b = rgb(line.tone)
    if line.right and type(tip.AddDoubleLine) == "function" then
        local rr, rg, rb = rgb(line.rightTone)
        tip:AddDoubleLine(line.text, line.right, r, g, b, rr, rg, rb)
    else
        tip:AddLine(line.text, r, g, b, false)
    end
end

-- The spacer line's number on `tip` now, or nil.
local function lineCount(tip)
    if type(tip.NumLines) ~= "function" then return nil end
    local n = tip:NumLines()
    if Compat.IsSecret(n) or type(n) ~= "number" then return nil end
    return n
end

--- Write `lines` onto `tip`, each in its tone, the separator laid across its spacer line (placed
--- now, and again on the next frame, once the tooltip is laid out); then Show again, so a shown
--- tooltip lays itself out around the new lines.
--- @param tip table
--- @param lines table IST.Lines' answer
function IST.Paint(tip, lines)
    local st
    for _, line in ipairs(lines) do
        addTo(tip, line)
        if line.rule then
            st = ruleOf(tip)
            if st then st.line = lineCount(tip) end
        end
    end
    if not st then hideRule(tip) end
    if type(tip.IsShown) == "function" and tip:IsShown() and type(tip.Show) == "function" then tip:Show() end
    if st and st.line then
        placeRule(tip)
        C_Timer.After(0, st.place)
    end
end

local function clearMark(tip)
    shownOn[tip] = nil
    hideRule(tip)
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
    local me = IS.Me(facts.ranks, tipMe)
    local verdict = o.badge and NS.ItemSearchVerdict.For(itemID, facts, me) or nil
    local lines = IST.Lines(facts, o, o.hint and Compat.BindingKeyText(C.ITEM_SEARCH.BINDING) or nil, me, verdict)
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
