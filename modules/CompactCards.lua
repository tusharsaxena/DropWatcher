local _, NS = ...
-- modules/CompactCards.lua — what compact mode's cards say (compact spec §2 and §3, DW-C1): each
-- card's three lines of text, their tones and their tooltips, for both tabs, and the group
-- header's short form. The same data as the full tables: every piece is a full-view composer's
-- cell (modules/WindowCells.lua, modules/SideCells.lua, modules/MineCells.lua,
-- modules/WindowHistory.lua), reshaped, so
-- the words, the tones and the reason tooltips never differ between the two layouts.
--
-- PURE. Every composer takes the drop record and plain inputs (the clock, your gear, the looter's
-- gear, an ask's state, your realm, a date formatter) and answers a plain table; nothing here reads
-- a module's state, the client or a saved variable, so test_compact_cards drives each state case by
-- case. The frame edges that paint the cards are DW-C2's and DW-C3's per-tab bodies.
--
--   cell = { text, glyph, tone = key of C.TONE, tip = { title, lines... } }   (WindowCells' shape)
--
-- THE CARDS. A card is three lines; each line's pieces are named fields, left to right, and the
-- edge draws the ones marked right-aligned against the card's right edge:
--
--   Drops        line 1: ilvl, item (quality color), fresh in brackets right after it, dimmed, or
--                        nothing (CC.FreshMark; feedback-10 spec §2)
--                line 2: looter (class color, ⊕ when cross-realm, ` [YOU]` in gold on your own drop:
--                        feedback-7 spec §2), slot, type, trade; ask (right: Offer on your own drop;
--                        No action with neither, feedback-11 spec §1). No trade window countdown
--                        (feedback-10 spec §2)
--                line 3: you and them, each a half: the label, then the full table's Me or Them
--                        cell without its icons (`Upgrade for N` on your own drop, feedback-7 spec §2)
--   History      line 1: ilvl, item; outcome (right, in its tone)
--                line 2: looter, slot, type, trade; time (right, dimmed)
--                line 3: you, them
--
-- LINE 3 (feedback-6 spec §1) reads as the full table's merged Me and Them cells (NS.SideCells), the
-- icons left out: the label, the worn item level (plain; `empty`, `…`, `range` muted), then the glyph
-- and the unsigned difference in the verdict's tone: `You 321/308 ▼8`, `Them 276 ▲12`, `Them
-- Upgrade for 2` on your own drop. A verdict the full view says in a word keeps compact mode's ⊘
-- (`You 321 ⊘ Can't use`). One tooltip over the half: the gear's lines, then the verdict's. Glyphs, ⊘
-- and ⊕ are drawn in the monospace face (JetBrains Mono carries all three).
--
-- THE HEADER'S SHORT FORM. `Instance · Boss · Difficulty · 3m · 2 · Recorder`: no `ago`, no
-- `drops`, `1 of 2` while a filter hides some; each piece longer than its HEADER_MAX characters is
-- cut with `…` (Looking For Raid reads LFR, GroupPlace.ShortNames). Its tooltip opens with the long form (the full view's header text) and keeps the
-- full view's lines: the kind, the party, the hidden drops and the click hint.

NS.CompactCards = NS.CompactCards or {}
local CC = NS.CompactCards
local L  = NS.L
local WC = NS.WindowCells
local MC = NS.MineCells
local SC = NS.SideCells

local floor = math.floor

local DASH = "–"

--- The mark of a verdict the full view says in a word (cannot use, not wanted).
CC.NO_GLYPH = "⊘"
--- The mark of a looter from another realm (the realm is in the tooltip).
CC.CROSS_REALM = "⊕"
-- The header's pieces, each cut to its own number of characters (feedback-15), so a line with
-- every piece at its limit fits HEADER_CHARS, about what a default-width pane (COMPACT_WIDTH 440)
-- holds in the header's font. The situation word stands in for a difficulty, never beside one.
CC.HEADER_CHARS = 76
CC.HEADER_MAX = { instance = 14, label = 14, difficulty = 11, situation = 16, age = 7, count = 6, who = 9 }

local DAY = 86400

local WORD_VERDICT = { cantUse = true, doesntWant = true }

local function num(v)
    if type(v) == "number" and v == v then return v end
    return nil
end

local function facts(drop) return type(drop.facts) == "table" and drop.facts or {} end

local function copyTip(tip)
    local out = {}
    for i, l in ipairs(type(tip) == "table" and tip or {}) do out[i] = l end
    return out
end

-- ── text helpers ────────────────────────────────────────────────────────────────────────────

-- The byte length of the UTF-8 character starting with byte `c`.
local function charLen(c)
    if c >= 0xF0 then return 4 end
    if c >= 0xE0 then return 3 end
    if c >= 0xC0 then return 2 end
    return 1
end

--- `s` cut to `n` characters (UTF-8 aware), the last one replaced by `…` when it is cut.
--- @param s string|nil
--- @param n number
--- @return string, boolean cut
function CC.Truncate(s, n)
    s = type(s) == "string" and s or ""
    local i, count, cuts = 1, 0, {}
    while i <= #s do
        count = count + 1
        cuts[count] = i
        i = i + charLen(s:byte(i))
    end
    if count <= n or n < 1 then return s, false end
    return (s:sub(1, cuts[n] - 1):gsub("%s+$", "")) .. "…", true
end

--- A short age: `40s`, `3m`, `1h 59m`, then `1d`, `3d`.
--- @param seconds number|nil
--- @return string
function CC.Age(seconds)
    local s = math.max(0, num(seconds) or 0)
    if s < DAY then return WC.Duration(s) end
    return L["%dd"]:format(floor(s / DAY))
end

--- A verdict's compact text: the glyph and the difference (`▼8`), ⊘ and a word (`⊘ Can't use`), the
--- word alone, or "" for an unknown verdict the gear part explains.
--- @param v table CC.Verdict's answer
--- @return string
function CC.VerdictText(v)
    if v.glyph == CC.NO_GLYPH then return v.glyph .. " " .. v.text end
    return (v.glyph or "") .. v.text
end

-- ── the shared pieces ───────────────────────────────────────────────────────────────────────

--- A Me or Them cell (NS.SideCells) as compact mode draws it: the full view's pieces, tones and
--- tooltip, with ⊘ before a verdict the full view says in a word.
--- @param c table a SideCells cell
--- @return table { level, levelTone, glyph, text, tone, tip, verdict, items, upgrades, hidden }
function CC.Verdict(c)
    local glyph = c.glyph
    if not glyph and WORD_VERDICT[c.verdict] then glyph = CC.NO_GLYPH end
    return { level = c.level, levelTone = c.levelTone, glyph = glyph, text = c.text, tone = c.tone,
        tip = copyTip(c.tip), verdict = c.verdict, items = c.items or {}, upgrades = c.upgrades, hidden = c.hidden }
end

--- One half of line 3: `You 321/308 ▼8`; its label and CC.Verdict's pieces.
--- @param label string `You` or `Them`
--- @param side table a SideCells cell (SC.Me, SC.Them, SC.Merge)
--- @return table { label, level, levelTone, glyph, text, tone, tip, verdict, items, upgrades, hidden }
function CC.Half(label, side)
    local h = CC.Verdict(side)
    h.label = label
    return h
end

--- A half's plain text: `You 321/308 ▼8`, `Them range`, `Them Upgrade for 2`.
--- @param h table CC.Half's answer
--- @return string
function CC.HalfText(h)
    local parts = { h.label }
    if h.level then parts[#parts + 1] = h.level end
    local v = CC.VerdictText(h)
    if v ~= "" then parts[#parts + 1] = v end
    return table.concat(parts, " ")
end

--- The item piece: the link's name in its quality color; hovering shows the game's own tooltip, so
--- `tip` is only the fallback the full view's Item cell carries.
--- @param drop table
--- @return table cell, with `link`, `quality` and `gameTooltip`
function CC.Item(drop)
    local c = WC.Item(drop)
    c.quality = facts(drop).quality
    c.gameTooltip = true
    return c
end

-- The realm of a `Name-Realm`, or nil.
local function realmOf(name)
    if type(name) ~= "string" then return nil end
    return name:match("^[^%-]+%-(.+)$")
end

local function normalized(realm)
    if type(realm) ~= "string" then return nil end
    local out = realm:gsub("[%s%-]", ""):lower()
    return out ~= "" and out or nil
end

--- Whether a looter's `Name-Realm` is on another realm than `ownRealm` (nil when either is unknown).
--- @param name string|nil
--- @param ownRealm string|nil your realm, normalized or not
--- @return boolean, string|nil realm
function CC.CrossRealm(name, ownRealm)
    local realm = realmOf(name)
    local a, b = normalized(realm), normalized(ownRealm)
    if not (a and b) then return false, realm end
    return a ~= b, realm
end

--- The looter piece: the full view's Looter cell (short name, class color, `you` on your own drop),
--- with ⊕ (`mark`) and a tooltip line naming the realm when the looter is from another realm.
--- @param drop table
--- @param ownRealm string|nil
--- @return table cell, with `classFile`, `you`, `mark` and `crossRealm`
function CC.Looter(drop, ownRealm)
    local c = WC.Looter(drop)
    local who = type(drop.looter) == "table" and drop.looter.name or nil
    local cross, realm = CC.CrossRealm(who, ownRealm)
    c.crossRealm = cross
    if cross then
        c.mark = CC.CROSS_REALM
        c.tip[#c.tip + 1] = L["From another realm: %s."]:format(realm)
    end
    return c
end

-- The freshness word of each inspect state without a good read.
local FRESH_WORD = { pending = "…", combatParked = L["combat"], outOfRange = L["range"], failed = "!",
    unavailable = DASH }

local function freshText(insp, now)
    local status = type(insp) == "table" and insp.status or "pending"
    if status == "cached" then return L["cached"] end
    if status == "fresh" then
        local at = num(insp.at)
        if at and num(now) then return WC.Duration(now - at) end
        return L["fresh"]
    end
    return FRESH_WORD[status] or DASH
end

--- Line 1's inspect freshness (dimmed, in brackets after the name: CC.FreshMark): `2m`, `cached`, `…`, `range`, `combat`, `!`,
--- `–`; the tooltip says how old the read is or why there is none. Your own drop needs no inspect.
--- @param drop table
--- @param now number|nil GetTime()
--- @return table cell
function CC.Freshness(drop, now)
    if drop.isMine then
        return { text = DASH, tone = "muted", tip = { L["Inspect"], L["Your own drop: your gear is always current."] } }
    end
    local who = WC.ShortName(type(drop.looter) == "table" and drop.looter.name or nil)
    return { text = freshText(drop.inspect, now), tone = "muted",
        tip = { L["Inspect of %s"]:format(who), WC.InspectLine(drop.inspect, who, now) } }
end

--- Line 1's freshness as the card draws it (feedback-10 spec §2): `(2m)`, `(cached)`, `(range)`, or nil
--- where there is nothing to say (your own drop, no inspect to speak of: the dash) or where Them
--- already says it (a read still pending, `…`: feedback-11 spec §0), so the card draws no placeholder.
--- @param cell table|nil CC.Freshness's answer
--- @return string|nil
function CC.FreshMark(cell)
    local t = type(cell) == "table" and cell.text
    if type(t) ~= "string" or t == "" or t == DASH or t == "…" then return nil end
    return "(" .. t .. ")"
end

-- ── the Drops card (spec §2) ────────────────────────────────────────────────────────────────

-- Line 2's action and trade, and line 3's Them: the looter's, or on your own drop its Offer,
-- its trade word and `Upgrade for N` (feedback-5 spec §2: the full table's cells).
local function sides(drop, ctx, now)
    local them = CC.Half(L["Them"], SC.Them(drop, ctx.gear, now, ctx.revealed))
    if drop.isMine then
        return MC.OwnOffer(drop, ctx.offerTone), MC.OwnTrade(drop, ctx.revealed), them
    end
    return WC.Ask(drop, ctx.askState, ctx.askReason, ctx.transmogAsk), WC.Trade(drop), them
end

--- A Drops card.
--- @param drop table
--- @param ctx table { now, equipped and classFile (your gear snapshot's), gear (the looter's inspect gear),
---   askState, askReason, transmogAsk, ownRealm; on your own drop revealed (its Offer panel was opened this session) and offerTone (the offer half of
---   WindowOwn.ToneStates) }
--- @return table card
function CC.Group(drop, ctx)
    ctx = ctx or {}
    local now = ctx.now
    local action, trade, them = sides(drop, ctx, now)
    return {
        kind = "group", id = drop.id, link = drop.link,
        -- line 1
        ilvl = WC.Ilvl(drop), item = CC.Item(drop), fresh = CC.Freshness(drop, now),
        -- line 2
        looter = CC.Looter(drop, ctx.ownRealm), slot = WC.Slot(drop), armorType = WC.ArmorType(drop),
        trade = trade, ask = action,
        -- line 3
        you = CC.Half(L["You"], SC.Me(drop, ctx.equipped, ctx.classFile)),
        them = them,
    }
end

-- ── the History card (spec §3) ──────────────────────────────────────────────────────────────

local function dayOf(dateFn, at)
    return ("%s %d"):format(dateFn("%b", at), tonumber(dateFn("%d", at)) or 0)
end

--- When a kept drop dropped: `17:02` within a day of `nowEpoch`, else `Oct 9`; the tooltip has the
--- full date and how long ago.
--- @param at number|nil the entry's time()
--- @param nowEpoch number|nil time()
--- @param dateFn function|nil the client's `date` (strftime-like); nil reads `?`
--- @return table cell
function CC.When(at, nowEpoch, dateFn)
    at, nowEpoch = num(at), num(nowEpoch)
    if not (at and type(dateFn) == "function") then
        return { text = "?", tone = "muted", tip = { L["When"], L["The time it dropped was not kept."] } }
    end
    local recent = nowEpoch and nowEpoch - at < DAY
    local text = recent and dateFn("%H:%M", at) or dayOf(dateFn, at)
    local tip = { L["When"], dateFn("%Y-%m-%d %H:%M", at) }
    if nowEpoch then tip[#tip + 1] = NS.WindowHistory.Ago(nowEpoch - at) end
    return { text = text, tone = "muted", tip = tip }
end

--- A History card.
--- @param drop table a kept entry as NS.WindowHistory.AsDrop shapes it
--- @param ctx table { nowEpoch, dateFn, ownRealm }
--- @return table card
function CC.History(drop, ctx)
    ctx = ctx or {}
    local WH = NS.WindowHistory
    return {
        kind = "history", id = drop.id, link = drop.link,
        -- line 1
        ilvl = WC.Ilvl(drop), item = CC.Item(drop), outcome = WH.Outcome(drop),
        -- line 2
        looter = CC.Looter(drop, ctx.ownRealm), slot = WC.Slot(drop), armorType = WC.ArmorType(drop),
        trade = WC.Trade(drop),
        time = CC.When(drop.at, ctx.nowEpoch, ctx.dateFn),
        -- line 3
        you = CC.Half(L["You"], WH.MeCell(drop)), them = CC.Half(L["Them"], WH.ThemCell(drop)),
    }
end

-- ── the plain text of a card (tests, and the simulator's report) ────────────────────────────

local function looterText(c)
    local t = c.you and (c.text .. " " .. c.you) or c.text
    return c.mark and (t .. " " .. c.mark) or t
end

local function lineTwo(card, right)
    return ("%s · %s · %s · %s  %s"):format(looterText(card.looter), card.slot.text, card.armorType.text,
        card.trade.text, right.text)
end

local PLAIN = {
    group = function(card)
        local fresh = CC.FreshMark(card.fresh)
        local one = ("%s %s"):format(card.ilvl.text, card.item.text) .. (fresh and (" " .. fresh) or "")
        return { one, lineTwo(card, card.ask),
            CC.HalfText(card.you) .. "  " .. CC.HalfText(card.them) }
    end,
    history = function(card)
        return { ("%s %s  %s"):format(card.ilvl.text, card.item.text, card.outcome.text), lineTwo(card, card.time),
            CC.HalfText(card.you) .. "  " .. CC.HalfText(card.them) }
    end,
}

--- A card's three lines as plain text, each piece in order (two spaces before a right-aligned one).
--- @param card table CC.Group's or CC.History's answer
--- @return table { line1, line2, line3 }
function CC.Plain(card)
    return PLAIN[card.kind](card)
end

-- ── the header's short form ─────────────────────────────────────────────────────────────────

--- A header's short count: the drops the group holds for the tab, `1 of 2` while a filter hides some.
--- @param shown number
--- @param hidden table|nil { { drop, why }, ... }
--- @return string
function CC.Count(shown, hidden)
    shown = tonumber(shown) or 0
    local nHidden = type(hidden) == "table" and #hidden or 0
    if nHidden == 0 then return tostring(shown) end
    return L["%d of %d"]:format(shown, shown + nHidden)
end


-- The short form's tooltip: the full view's title, its long form, then its other lines.
local function shortTip(full)
    local tip = { full.tip[1], full.text }
    for i = 2, #full.tip do tip[#tip + 1] = full.tip[i] end
    return tip
end

local function shortHeader(group, shown, age, situationLabel, hidden, full)
    local M = CC.HEADER_MAX
    local parts, who, roles = WC.Place(group, situationLabel, M.who)
    local cut, any = false, false
    for i, role in ipairs(roles) do
        parts[i], cut = CC.Truncate(parts[i], M[role]); any = any or cut
    end
    local function push(v, max)
        if v then parts[#parts + 1], cut = CC.Truncate(v, max); any = any or cut end
    end
    push(age, M.age)
    push(CC.Count(shown, hidden), M.count)
    parts[#parts + 1] = who
    local key = who and NS.GroupPlace.Recorder(group)
    if key then any = select(2, CC.Truncate(key:match("^([^%-]+)") or key, M.who)) or any end
    return { text = table.concat(parts, " · "), tip = shortTip(full), cut = any }
end

--- A Drops header's short form (compact spec §2): `Instance · Boss · Difficulty ·
--- 3m · 2 · Recorder`, its tooltip the long form (WC.Header) and its lines. The chevron says whether
--- it is collapsed, so the text does not.
--- @param group table a feed group
--- @param shown number
--- @param now number|nil GetTime()
--- @param situationLabel string|nil
--- @param collapsed boolean
--- @param hidden table|nil
--- @param filter table|nil
--- @return table { text, tip, cut }
function CC.Header(group, shown, now, situationLabel, collapsed, hidden, filter)
    local full = WC.Header(group, shown, now, situationLabel, collapsed, hidden, filter)
    local age = (num(group.at) and num(now)) and CC.Age(now - group.at) or nil
    return shortHeader(group, shown, age, situationLabel, hidden, full)
end

--- A History header's short form: as CC.Header, its age in days once a day old (`2d`), its tooltip
--- the long form (NS.WindowHistory.Header).
--- @param group table a History group
--- @param shown number
--- @param nowEpoch number|nil time()
--- @param situationLabel string|nil
--- @param collapsed boolean
--- @param hidden table|nil
--- @param filter table|nil
--- @return table { text, tip, cut }
function CC.HistoryHeader(group, shown, nowEpoch, situationLabel, collapsed, hidden, filter)
    local full = NS.WindowHistory.Header(group, shown, nowEpoch, situationLabel, collapsed, hidden, filter)
    local age = (num(group.at) and num(nowEpoch)) and CC.Age(nowEpoch - group.at) or nil
    return shortHeader(group, shown, age, situationLabel, hidden, full)
end
