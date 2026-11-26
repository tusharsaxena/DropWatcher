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
--     tooltip's width. It is ANCHORED, never measured (round 4, R4-DW-06): two zero-alpha edge
--     textures hang from the tooltip's top corners down to the spacer's left middle, and the line
--     hangs from their bottom corners, so the client places it in the same layout pass as the line
--     and nothing reads geometry inside the post call (where the lines have none yet). The client
--     rebuilds an item tooltip about five times a second (clear, sometimes a hide, refill), so a
--     clear or a hide only marks the line stale; the next block claims it again, and a line no
--     block claimed comes off on the next frame. Hiding it on every clear was the one-frame blink;
--     measuring it up to three times a rebuild from half-finished layouts was the dim ghost line;
--   * the label line, always (item 14a): "Drop Watcher" in the tooltip label's muted gold, the
--     verdict badge right after it (round 4, R4-DW-07; the "Show the Keep / Hold / Sell / Toss
--     badge" setting): two filled boxes joined flush, `<icon> <Verdict>` on the verdict's bright
--     tone and the score on its darker shade (Keep green, Hold yellow, Sell amber, Toss red;
--     NS.ItemSearchVerdict, IST.Badge). The boxes are textures and font strings of the tooltip's own,
--     kept like the separator: hung by anchors from the label line, stale on a clear or a hide,
--     claimed again by a refill, off on the next frame when nothing claims them. The label's text
--     ends in a transparent texture escape as wide as the badge, so the tooltip sizes itself to fit.
--     The confidence tier is never shown (the owner); it still keeps a Low from saying Toss;
--   * the badge's reasons (the "Explain the badge" setting, under the badge): its top two and the
--     largest negative part (NS.ItemSearchVerdict), each "  · <reason>" with the bullet in muted
--     gold, then, below a High confidence, the fix, muted ("Open your profession window to rank
--     recipes");
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
--                     Drop Watcher saw there, else ForeverDB's). With "Hide the other faction's
--                     vendors" on (R4-DW-08, the default) the vendors only the other side can buy
--                     from are left out and counted on one dim line, "+N other-faction vendors",
--                     after "and N more" (the heading and that line alone when every vendor is
--                     the other side's); off, they show "Horde only" / "Alliance only" in red;
--       Quests        the game's marks (IST.QuestMark, round 3 item 13): the yellow `!` not picked
--                     up (dimmed while your level is too low), the gray `?` in your log, the green
--                     `?` complete and waiting to be turned in, a green check turned in (left out
--                     while "Hide completed quests" is on), then "<Title> (<Level>)" in the quest's
--                     difficulty tone; on the right "<Giver> - <Zone>" (R4-DW-09), muted: the first
--                     giver not test-named (NS.ItemSearch.QuestGiver, resolved once per item), its
--                     text memoized per giver and map;
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
-- are LibKa0s media icons (`ph:arrow-fat-up`, `dash` and `ph:lock`) at an explicit
-- C.ITEM_SEARCH.GLYPH_SIZE (14:14; the dash 14 wide, cropped to its bar and DASH_HEIGHT tall), so the
-- tooltip and the window's glyph column draw them at one size (round 3 spec §4.1, round 4 R4-DW-02). The quest marks are the client's own GossipFrame icons and the media
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
    flat   = { icon = "dash", tone = "glyphKnown", fallback = "-" },
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
local rules = setmetatable({}, { __mode = "k" })     -- tooltip -> its separator { tex, edgeL, edgeR, line, ... }
local badges = setmetatable({}, { __mode = "k" })    -- tooltip -> its verdict badge { boxL, boxR, textL, textR, line, ... }
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

-- LibKa0s' `dash` (tools/artwork/dash_icon.py): its bar's rows on the 64-pixel canvas, top and bottom.
local DASH_TOP, DASH_BOTTOM = 25, 39

-- The no-skill-up dash: the texture cropped to its bar, GLYPH_SIZE wide (the fat arrow's width) and
-- DASH_HEIGHT tall, a whole number of pixels, so the line never smears over two half-lit rows.
local function dashMark(g)
    local path = NS.Icon(g.icon)
    if not path then return colored(g.fallback, g.tone) end
    local r, gr, b = rgb(g.tone)
    local s, S = NS.TipMarks.TEX_SIZE, NS.TipMarks.Byte
    return ("|T%s:%d:%d:0:0:%d:%d:0:%d:%d:%d:%d:%d:%d|t"):format(path, C.ITEM_SEARCH.DASH_HEIGHT,
        C.ITEM_SEARCH.GLYPH_SIZE, s, s, s, DASH_TOP, DASH_BOTTOM, S(r), S(gr), S(b))
end

--- A crafting row's mark, in the tooltip and the window alike: a fat up arrow in the skill-up color,
--- a thick light gray dash (round 4, R4-DW-02), or a dark gray padlock (IST.CraftGlyph), each
--- C.ITEM_SEARCH.GLYPH_SIZE wide. The shapes differ as well as the colors, so a color-blind player
--- reads them too.
--- @param row table a crafting row (IS.Live's)
--- @return string
function IST.CraftMark(row)
    local glyph = IST.CraftGlyph(row)
    local g = GLYPH[glyph]
    if glyph == "flat" then return dashMark(g) end
    local tone = glyph == "up" and SKILL_TONE[row.color] or g.tone
    return icon(g.icon, tone, g.fallback, C.ITEM_SEARCH.GLYPH_SIZE)
end

--- A crafting row's skill breakpoints as one string, each part in its skill-up hue and your band
--- bracketed (IS.SkillParts, the window's Skill column's), memoized per recipe and band (IS.SkillBand,
--- round 4 R4-DW-05): the breakpoints are static, the band moves with your rank and the hues change
--- only with the skin (IST.ForgetLooks). Nil for a recipe with no breakpoints.
--- @param row table a crafting row
--- @return string|nil
function IST.SkillText(row)
    local spell = row.spell
    local band = IS.SkillBand(row)
    local bands
    if spell ~= nil then
        bands = partsMemo[spell]
        if not bands then bands = {}; partsMemo[spell] = bands end
        local memo = bands[band]
        if memo == false then return nil end
        if memo then return memo end
    end
    local parts = IS.SkillParts(row)
    local text
    for _, p in ipairs(parts) do
        local part = colored(p.text, p.tone)
        text = text and (text .. " " .. part) or part
    end
    if bands then bands[band] = text or false end
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

-- The ink on a box of the color r, g, b: the skin's plain text tone on a mid or dark tone, the tone's own deep shade on
-- a light one (Hold's yellow), so the word and the score read on every verdict.
local function inkOf(r, g, b)
    if 0.299 * r + 0.587 * g + 0.114 * b > 0.6 then return r * 0.2, g * 0.2, b * 0.2 end
    return rgb("plain")
end

local function badgeText(v)
    local look = VERDICT_LOOK[v.verdict] or VERDICT_LOOK.hold
    local ir, ig, ib = inkOf(rgb(look.tone))
    local path = NS.Icon(look.icon)
    local mark = path and (NS.TipMarks.Escape(path, ir, ig, ib, C.ITEM_SEARCH.BADGE.ICON) .. " ") or ""
    return { word = mark .. verdictWord(v.verdict), score = tostring(v.score), tone = look.tone, ink = { ir, ig, ib } }
end

-- A memo's branch under `key`, made on first use.
local function branch(t, key)
    local b = t[key]
    if not b then b = {}; t[key] = b end
    return b
end

--- The badge's parts for a verdict answer (NS.ItemSearch.Verdict's), round 4 R4-DW-07: `{ word,
--- score, tone, ink }`, `word` the icon (C.ITEM_SEARCH.BADGE.ICON; none without the media library)
--- and the verdict's word, `score` the number, `tone` the box's C.TONE key and `ink` the texts' r,
--- g, b on it. No confidence tier. The same table for the same verdict and score until the skin's
--- looks change: read, never changed.
--- @param v table
--- @return table
function IST.Badge(v)
    local byScore = branch(badgeMemo, v.verdict or "hold")
    local badge = byScore[v.score]
    if not badge then
        badge = badgeText(v)
        byScore[v.score] = badge
    end
    return badge
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
    local line = hintMemo[v.hint]
    if not line then
        line = { text = v.hint, tone = "muted" }
        hintMemo[v.hint] = line
    end
    return line
end

-- Append a verdict's reason lines to `out`: no table of their own (the block runs on every hover).
local function addReasons(out, v)
    for _, text in ipairs(v.reasons or {}) do out[#out + 1] = reasonLine(text) end
    if v.hint then out[#out + 1] = hintLine(v) end
end

--- The badge's reason lines for a verdict answer, a new array: one "  · <reason>" per reason (the
--- bullet in muted gold), then the confidence's fix, muted and without the tier, below a High
--- confidence. Each line is the
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

-- Each profession's name in its own tone (R4-DW-04), per skill line: the tones are fixed, so the
-- strings are built once, not on every hover. False for a line with no name.
local professionMemo = {}

local function professionText(skillLine)
    if skillLine == nil then return nil end
    local memo = professionMemo[skillLine]
    if memo == nil then
        local name = professionName(skillLine)
        memo = name and colored(name, C.PROFESSION_TONE[skillLine]) or false
        professionMemo[skillLine] = memo
    end
    return memo or nil
end

--- A recipe skill line's profession tone (C.PROFESSION_TONE, round 4 R4-DW-04), or nil: the
--- tooltip's crafting and gathering rows and the window's Profession columns color the name with it.
--- @param skillLine number|nil
--- @return string|nil a C.TONE key
function IST.ProfessionTone(skillLine)
    return skillLine and C.PROFESSION_TONE[skillLine] or nil
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
    local right = professionText(IS.GATHER_LINE[g.gather]) or ""
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

-- The count of the other faction's vendors left out (R4-DW-08): one dim line.
local function otherFaction(out, n)
    if n == 1 then add(out, INDENT .. L["+1 other-faction vendor"], "muted")
    elseif n > 1 then add(out, INDENT .. L["+%d other-faction vendors"]:format(n), "muted") end
end

-- With `o.hideOtherFaction` (the "Hide the other faction's vendors" setting, R4-DW-08) the vendors
-- only the other side can buy from are left out and counted; one with no known side stays. Every
-- vendor the other side's: the heading and the count alone. No array is built: the block is
-- written on every hover.
local function vendorLines(_, r, o, out, me)
    local vendors = r.vendors
    if #vendors == 0 then return end
    add(out, L["Sold by"], "mutedGold")
    local hide = o.hideOtherFaction and me ~= nil
    local cap, own, other = IS.ClampRows(o.rows), 0, 0
    for i = 1, #vendors do
        local v = vendors[i]
        if hide and IS.OtherSide(v, me) then
            other = other + 1
        else
            own = own + 1
            if own <= cap then
                local right, rightTone = vendorRight(v, me)
                add(out, INDENT .. v.name, "plain", right, rightTone)
            end
        end
    end
    more(out, own - math.min(own, cap))
    otherFaction(out, other)
end

-- A quest giver's "<Giver> - <Zone>" (NS.ItemSearchCells.GiverText, the window's Giver column's),
-- memoized per giver (kind and id) and map, so a hover builds no string and reads no spot or map
-- name once the giver was shown on that map. False in the memo: no text. Emptied when the spots
-- are (NS.ItemSearch.SpotsGeneration: ForeverDB's state moved, or ForeverDB_Full loaded).
local giverMemo, giverGeneration = { npc = {}, object = {} }, nil

local function giverZone(g, me, map)
    local spots = me and me.spots
    local where = type(spots) == "function"
        and NS.ItemSearchCells.Where(spots(g.kind, g.id), map, Compat.MapName) or nil
    return where and where.zone or nil
end

local function giverRight(g, me)
    if type(g) ~= "table" or not giverMemo[g.kind] then return nil end
    local generation = IS.SpotsGeneration()
    if giverGeneration ~= generation then giverMemo, giverGeneration = { npc = {}, object = {} }, generation end
    local map = me and me.mapID
    local byId = giverMemo[g.kind]
    local byMap = byId[g.id]
    if not byMap then byMap = {}; byId[g.id] = byMap end
    local text = byMap[map or 0]
    if text == nil then
        text = NS.ItemSearchCells.GiverText(g.name, giverZone(g, me, map)) or false
        byMap[map or 0] = text
    end
    return text or nil
end

-- A quest row (R4-DW-09, the owner's layout): "<mark> <Title> (<Level>)" on the left in the title's
-- difficulty tone (NS.ItemSearchCells.LevelTone, the window's Quest cell's), "<Giver> - <Zone>" on
-- the right, muted.
local function questLines(_, r, o, out, me)
    local rows = {}
    for _, q in ipairs(r.quests) do
        if not (o.hideCompleted and q.state == "done") then rows[#rows + 1] = q end
    end
    if #rows == 0 then return end
    add(out, L["Quests"], "mutedGold")
    local shown, rest = capped(rows, o.rows)
    local cells, level = NS.ItemSearchCells, me and me.level
    for i = 1, shown do
        local q = rows[i]
        local mark = IST.QuestMark(cells.QuestStatus(q.state, q.minLevel, level), C.ITEM_SEARCH.MARK_SIZE)
        local text = INDENT .. mark .. " " .. (q.title or L["Quest %d"]:format(q.id))
        if q.level then text = text .. L[" (%d)"]:format(q.level) end
        add(out, text, cells.LevelTone(q.level, level), giverRight(q.giver, me), "muted")
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
-- professions), else the profession alone; the profession in its own tone (R4-DW-04).
local function craftRight(c, o, mix)
    local profession = professionText(c.skillLine)
    local parts = o.craftSkill and IST.SkillText(c) or nil
    if not parts then return profession, "plain" end
    if mix and profession then return parts .. " " .. colored("·", "muted") .. " " .. profession, "plain" end
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
-- badge after the label (the "Show the Keep / Hold / Sell / Toss badge" setting; the line's `badge`,
-- IST.Badge's parts, which IST.Paint draws), and the badge's reasons (the "Explain the badge"
-- setting).
local function head(o, verdict)
    local out = {}
    if o.header then out[1] = { text = " ", rule = true } end
    verdict = o.badge and verdict or nil
    add(out, L["Drop Watcher"], "mutedGold")
    if verdict then out[#out].badge = IST.Badge(verdict) end
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
--- @return table lines `{ { text, tone, right, rightTone, rule, badge } ... }` (`rule`: the separator's
--- spacer; `badge`: the label line's badge, IST.Badge's parts)
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
--- mine, hideOtherFaction, sections, order }` (`mine`: itemSearch.myProfessionsOnly, feedback spec
--- §4; `hideOtherFaction`: itemSearch.hideOtherFaction, R4-DW-08; `craftSkill`: round 3 §4.2;
--- `badge` and `reasons`: round 3 §4.5).
--- @return table
function IST.Options()
    local shown = IS.ClampRows(setting("rows", IS.TIP_ROWS))
    return {
        enabled = setting("enabled", true) == true, shiftOnly = setting("shiftOnly", false) == true,
        header = setting("header", true) == true, hint = setting("hint", true) == true,
        comparison = setting("comparison", false) == true, hideCompleted = setting("hideCompleted", true) == true,
        craftSkill = setting("craftSkill", true) == true, badge = setting("badge", true) == true,
        reasons = setting("reasons", true) == true, rows = shown, mine = IS.MyProfessionsOnly(),
        hideOtherFaction = IS.HideOtherFaction(),
        sections = sectionsOf(setting("sections")), order = orderOf(setting("order")),
    }
end

-- ── kept regions: the separator and the badge (R4-DW-06, R4-DW-07) ─────────────────────────
-- Each is a record `st` with `line` (the tooltip line it hangs from, nil while down), `stale`, and
-- `hide(st)`. A clear or a hide marks it stale; a block claims it again; the next frame's sweep takes
-- down one that nothing claimed.

local function keep(st, hide)
    st.hide = hide
    st.sweep = function()
        st.sweeping = false
        if st.stale then st.stale, st.line = false, nil; hide(st) end
    end
    return st
end

local function markStale(st)
    if not (st and st.line) then return end
    st.stale = true
    if not st.sweeping then
        st.sweeping = true
        C_Timer.After(0, st.sweep)
    end
end

local function dropKept(st)
    if not st then return end
    st.line, st.stale = nil, false
    st.hide(st)
end

local function snapped(tex)
    if type(tex.SetSnapToPixelGrid) == "function" then tex:SetSnapToPixelGrid(true) end
    if type(tex.SetTexelSnappingBias) == "function" then tex:SetTexelSnappingBias(0) end
end

-- ── the separator (round 3 spec §4.2, item 14b; anchored since R4-DW-06) ───────────────────

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

-- An invisible texture of the tooltip's own, there only to carry an anchor.
local function edgeOf(tip)
    local e = tip:CreateTexture(nil, "BACKGROUND")
    if type(e) ~= "table" then return nil end
    e:SetTexture(IST.RULE_TEXTURE)
    if type(e.SetAlpha) == "function" then e:SetAlpha(0) end
    return e
end

-- Hang the edges from the spacer line `n`: the left edge from the tooltip's top left to the line's
-- left middle, the right edge from the tooltip's top right to the same point; the line itself hangs
-- from their bottom corners. False when the tooltip has no such line (an unnamed tooltip).
local function anchorRule(tip, st, n)
    if st.anchored == n then return true end
    local fs = Compat.TooltipLeftLine(tip, n)
    if not fs then return false end
    st.edgeL:ClearAllPoints()
    st.edgeL:SetPoint("TOPLEFT", tip, "TOPLEFT", 0, 0)
    st.edgeL:SetPoint("BOTTOMRIGHT", fs, "LEFT", 0, 0)
    st.edgeR:ClearAllPoints()
    st.edgeR:SetPoint("TOPRIGHT", tip, "TOPRIGHT", 0, 0)
    st.edgeR:SetPoint("BOTTOMLEFT", fs, "LEFT", 0, 0)
    st.anchored = n
    return true
end

-- The tooltip's separator, made on its first block: the line (pixel snapped: the client places it,
-- so the client rounds it) and its two edges, the line hung from the edges once and for all, painted
-- `dw.tipRule` now and on every skin switch. Nil for a tooltip that makes no texture.
local function ruleOf(tip)
    local st = rules[tip]
    if st then return st end
    if type(tip.CreateTexture) ~= "function" then return nil end
    local edgeL, edgeR = edgeOf(tip), edgeOf(tip)
    local tex = tip:CreateTexture(nil, "ARTWORK")
    if not (edgeL and edgeR and type(tex) == "table") then return nil end
    tex:SetTexture(IST.RULE_TEXTURE)
    snapped(tex)
    NS.SkinPaint(tex, paintRule)
    local inset = C.ITEM_SEARCH.RULE_INSET
    tex:SetPoint("TOPLEFT", edgeL, "BOTTOMLEFT", inset, 0)
    tex:SetPoint("TOPRIGHT", edgeR, "BOTTOMRIGHT", -inset, 0)
    local px = onePixel(tip)
    tex:SetHeight(px)
    tex:Hide()
    st = keep({ tex = tex, edgeL = edgeL, edgeR = edgeR, px = px }, function(r) r.tex:Hide() end)
    rules[tip] = st
    return st
end

-- The block on `tip` claims its separator for spacer line `n`: anchored (again only when the line
-- moved), one physical pixel tall at the tooltip's scale now (set again only when a UI or tooltip
-- scale change moved it, `st.px`, so a warm hover sets nothing), shown, no longer stale.
local function claimRule(tip, st, n)
    st.stale = false
    if not (n and anchorRule(tip, st, n)) then st.line = nil; st.tex:Hide(); return end
    local px = onePixel(tip)
    if px ~= st.px then st.tex:SetHeight(px); st.px = px end
    st.line = n
    st.tex:Show()
end


--- The tooltip's separator texture, or nil before its first block (for the tests and diagnostics).
--- @param tip table
--- @return table|nil
function IST.RuleOf(tip)
    local st = rules[tip]
    return st and st.tex or nil
end

-- ── the verdict badge's frames (round 4, R4-DW-07) ─────────────────────────────────────────

local function showBadge(st, on)
    for _, r in ipairs({ st.boxL, st.boxR, st.textL, st.textR }) do
        if on then r:Show() else r:Hide() end
    end
end

local function hideBadge(st) showBadge(st, false) end

local function boxOf(tip)
    local t = tip:CreateTexture(nil, "ARTWORK")
    if type(t) ~= "table" then return nil end
    t:SetTexture(IST.RULE_TEXTURE)
    snapped(t)
    t:SetHeight(C.ITEM_SEARCH.BADGE.HEIGHT)
    return t
end

local function textOf(tip, box)
    local fs = tip:CreateFontString(nil, "OVERLAY", "GameTooltipText")
    if type(fs) ~= "table" then return nil end
    fs:SetPoint("CENTER", box, "CENTER", 0, 0)
    return fs
end

--- The verdict badge's regions on `parent` (a tooltip, or the Item Search window's verdict panel,
--- R4-DW-11: one builder, so both draw the same badge): `{ boxL, boxR, textL, textR }`, the score's
--- box, the word's box joined flush to its left, and each one's text centered on it, hidden. The
--- caller anchors `boxR` and fills them with IST.FillBadge. Nil for a parent that makes no texture
--- or font string.
--- @param parent table
--- @return table|nil
function IST.MakeBadge(parent)
    if type(parent.CreateTexture) ~= "function" or type(parent.CreateFontString) ~= "function" then return nil end
    local boxL, boxR = boxOf(parent), boxOf(parent)
    local textL, textR = boxL and textOf(parent, boxL), boxR and textOf(parent, boxR)
    if not (textL and textR) then return nil end
    boxL:SetPoint("RIGHT", boxR, "LEFT", 0, 0)
    local st = { boxL = boxL, boxR = boxR, textL = textL, textR = textR }
    hideBadge(st)
    return st
end

--- Show or hide a badge's regions (IST.MakeBadge's).
--- @param st table
--- @param on boolean
function IST.ShowBadge(st, on)
    showBadge(st, on)
end

-- The tooltip's badge, made on its first badge (IST.MakeBadge) and kept like the separator.
local function badgeOf(tip)
    local st = badges[tip]
    if st then return st end
    st = IST.MakeBadge(tip)
    if not st then return nil end
    keep(st, hideBadge)
    badges[tip] = st
    return st
end

-- A font string's drawn width, rounded up to a whole unit (0 when the client gives none).
local function textWidth(fs)
    local fn = fs.GetUnboundedStringWidth or fs.GetStringWidth
    local w = type(fn) == "function" and fn(fs) or nil
    if Compat.IsSecret(w) or type(w) ~= "number" then return 0 end
    return math.ceil(w)
end

-- Fill a box and its text with one part: the text in `ink`, the box tinted r, g, b, PAD either side.
local function fillPart(box, fs, text, ink, r, g, b)
    fs:SetText(text)
    fs:SetTextColor(ink[1], ink[2], ink[3])
    box:SetVertexColor(r, g, b)
    local w = textWidth(fs) + 2 * C.ITEM_SEARCH.BADGE.PAD
    box:SetWidth(w)
    return w
end

-- Draw `badge` (IST.Badge's parts) on a badge (IST.MakeBadge's), again only when it changed (the parts
-- are memoized, so a warm hover sets nothing). Answers the width to reserve: GAP and both boxes.
local function fillBadge(st, badge)
    if st.badge == badge then return st.width end
    local r, g, b = rgb(badge.tone)
    local k = C.ITEM_SEARCH.BADGE.DARK
    local wl = fillPart(st.boxL, st.textL, badge.word, badge.ink, r, g, b)
    local wr = fillPart(st.boxR, st.textR, badge.score, badge.ink, r * k, g * k, b * k)
    st.badge, st.width = badge, C.ITEM_SEARCH.BADGE.GAP + wl + wr
    return st.width
end

--- Draw `badge` (IST.Badge's parts) on `st` (IST.MakeBadge's regions): the word's box in the
--- verdict's bright tone, the score's in C.ITEM_SEARCH.BADGE.DARK times it. Sets nothing when `st`
--- already shows those parts. Answers the badge's width with C.ITEM_SEARCH.BADGE.GAP before it.
--- @param st table
--- @param badge table
--- @return number
function IST.FillBadge(st, badge)
    return fillBadge(st, badge)
end

-- The label's text with the badge's width reserved at its end: a texture escape cropped to one
-- fully transparent corner texel of a shipped icon (escapes carry no alpha, and no blank texture
-- ships), HEIGHT tall so the line fits the boxes; spaces without the media library. Kept per width.
local labelMemo = {}

local function reservedLabel(text, width)
    local byText = branch(labelMemo, text)
    local out = byText[width]
    if out then return out end
    local path = NS.Icon("ph:lock")
    if path then
        local t = NS.TipMarks.TEX_SIZE
        out = text .. ("|T%s:%d:%d:0:0:%d:%d:0:1:0:1|t"):format(path, C.ITEM_SEARCH.BADGE.HEIGHT, width, t, t)
    else
        out = text .. (" "):rep(math.ceil(width / 4))
    end
    byText[width] = out
    return out
end

-- The block claims the badge for its label line `n`: the score's box hung from the line's right
-- end (the end of the reserved width), anchored again only when the line moved, and shown.
local function claimBadge(tip, st, n)
    st.stale = false
    local fs = n and Compat.TooltipLeftLine(tip, n)
    if not fs then st.line = nil; hideBadge(st); return end
    if st.anchored ~= n then
        st.boxR:ClearAllPoints()
        st.boxR:SetPoint("RIGHT", fs, "RIGHT", 0, 0)
        st.anchored = n
    end
    st.line = n
    showBadge(st, true)
end

--- The tooltip's badge `{ boxL, boxR, textL, textR }`, or nil before its first badge (for the tests
--- and diagnostics).
--- @param tip table
--- @return table|nil
function IST.BadgeOf(tip)
    return badges[tip]
end

-- ── painting and the hook ───────────────────────────────────────────────────────────────────

-- Write one line: AddDoubleLine with a right side, else AddLine (no wrap), each in its tone; `text`
-- in place of the line's own when given (the label with the badge's width reserved).
local function addTo(tip, line, text)
    local r, g, b = rgb(line.tone)
    if line.right and type(tip.AddDoubleLine) == "function" then
        local rr, rg, rb = rgb(line.rightTone)
        tip:AddDoubleLine(text or line.text, line.right, r, g, b, rr, rg, rb)
    else
        tip:AddLine(text or line.text, r, g, b, false)
    end
end

-- The spacer line's number on `tip` now, or nil.
local function lineCount(tip)
    if type(tip.NumLines) ~= "function" then return nil end
    local n = tip:NumLines()
    if Compat.IsSecret(n) or type(n) ~= "number" then return nil end
    return n
end

--- Write `lines` onto `tip`, each in its tone, the separator claimed for its spacer line (anchored,
--- so the client places it). `filling`: the client is filling the tooltip now (the post call), and
--- shows it itself once every post call has run (TooltipDataHandler); otherwise a shown tooltip is
--- shown again, so it lays itself out around the new lines. The post call never shows it mid-fill:
--- that resized the tooltip before later post calls added their lines (R4-DW-06).
--- @param tip table
--- @param lines table IST.Lines' answer
--- @param filling boolean|nil
function IST.Paint(tip, lines, filling)
    local st, bt
    for _, line in ipairs(lines) do
        bt = line.badge and badgeOf(tip) or bt
        if line.badge and bt then
            addTo(tip, line, reservedLabel(line.text, fillBadge(bt, line.badge)))
            claimBadge(tip, bt, lineCount(tip))
        else
            addTo(tip, line)
        end
        if line.rule then
            st = ruleOf(tip)
            if st then claimRule(tip, st, lineCount(tip)) end
        end
    end
    if not st then dropKept(rules[tip]) end
    if not bt then dropKept(badges[tip]) end
    if not filling and type(tip.IsShown) == "function" and tip:IsShown() and type(tip.Show) == "function" then
        tip:Show()
    end
end

local function clearMark(tip)
    shownOn[tip] = nil
    markStale(rules[tip])
    markStale(badges[tip])
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

local function onTooltip(tip, data)
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
    IST.Paint(tip, lines, true)
    return true
end

-- NEVER RE-ENTERED (R5-DW-00). The verdict reads Pawn (NS.Compat.PawnItemValue), and Pawn's
-- PawnGetItemData fills its own hidden PawnPrivateTooltip1 with SetHyperlink. That fill runs every Item
-- post call, this one included, on that tooltip, which asked Pawn again: a C stack overflow. A post
-- call that arrives while one is running is another addon's scan inside ours, so it writes nothing.
-- The body runs in pcall, so an error releases the guard before it is raised again.
local busy = false

--- The item tooltip post call (see the header). Answers whether it wrote a block, for the tests.
--- A call made while another runs (a scan tooltip filled from inside it) answers false.
--- @param tip table
--- @param data table|nil the post call's tooltip data
--- @return boolean
function IST.OnTooltip(tip, data)
    if busy then return false end
    busy = true
    local ok, wrote = pcall(onTooltip, tip, data)
    busy = false
    if not ok then error(wrote, 0) end
    return wrote
end

--- Register the post call, once a session, on WoW Forever (core/DropWatcher.lua's OnEnable).
--- Answers whether the hook is in.
--- @return boolean
function IST.Install()
    if installed or not IS.Enabled() then return installed end
    installed = Compat.HookItemTooltips(function(tip, data) IST.OnTooltip(tip, data) end)
    return installed
end
