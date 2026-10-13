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
--   Drops        line 1: item (quality color), ilvl (right), ask (Offer on your own drop)
--                line 2: looter (class color, ⊕ when cross-realm, ` [YOU]` in gold on your own drop:
--                        feedback-7 spec §2), slot, type, trade; countdown (right, with its bar:
--                        MineCells.TradeWindow's, for a drop with a countdown, feedback-5 spec §1) or
--                        else fresh (right, dimmed)
--                line 3: you and them, each a half: the label, then the full table's Me or Them
--                        cell without its icons (`Upgrade for N` on your own drop, feedback-7 spec §2)
--   History      line 1: item, ilvl (right), outcome (right, in its tone)
--                line 2: looter, slot, type, trade; time (right, dimmed)
--                line 3: you, them
--
-- LINE 3 (feedback-6 spec §1) reads as the full table's merged Me and Them cells (NS.SideCells), the
-- icons left out: the label, the worn item level (plain; `empty`, `…`, `range` muted), then the glyph
-- and the unsigned difference in the verdict's tone: `You 321/308 ▽8`, `Them 276 ▲12`, `Them
-- Upgrade for 2` on your own drop. A verdict the full view says in a word keeps compact mode's ⊘
-- (`You 321 ⊘ Can't use`). One tooltip over the half: the gear's lines, then the verdict's. Glyphs, ⊘
-- and ⊕ are drawn in the monospace face (JetBrains Mono carries all three).
--
-- THE HEADER'S SHORT FORM. `Instance · Boss · Difficulty · 3m · 2 · Recorder`: no `ago`, no
-- `drops`, `1 of 2` while a filter hides some; an instance name longer than PLACE_MAX characters is
-- cut with `…`. Its tooltip opens with the long form (the full view's header text) and keeps the
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
--- The longest header place part, in characters, before it is cut with `…`.
CC.PLACE_MAX = 24

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
    return s:sub(1, cuts[n] - 1) .. "…", true
end

--- A short age: `40s`, `3m`, `1h 59m`, then `1d`, `3d`.
--- @param seconds number|nil
--- @return string
function CC.Age(seconds)
    local s = math.max(0, num(seconds) or 0)
    if s < DAY then return WC.Duration(s) end
    return L["%dd"]:format(floor(s / DAY))
end

--- A verdict's compact text: the glyph and the difference (`▽8`), ⊘ and a word (`⊘ Can't use`), the
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

--- One half of line 3: `You 321/308 ▽8`; its label and CC.Verdict's pieces.
--- @param label string `You` or `Them`
--- @param side table a SideCells cell (SC.Me, SC.Them, SC.Merge)
--- @return table { label, level, levelTone, glyph, text, tone, tip, verdict, items, upgrades, hidden }
function CC.Half(label, side)
    local h = CC.Verdict(side)
    h.label = label
    return h
end

--- A half's plain text: `You 321/308 ▽8`, `Them range`, `Them Upgrade for 2`.
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

--- Line 2's inspect freshness (dimmed, right-aligned): `2m`, `cached`, `…`, `range`, `combat`, `!`,
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

-- ── the Drops card (spec §2) ────────────────────────────────────────────────────────────────

-- Line 2's countdown on a Drops card: the Trade window cell for a drop with a countdown (your
-- own or another player's estimate), nil for one with none (not tradeable, bind on equip, not
-- estimated), which keeps the inspect freshness there.
local function groupCountdown(drop, now, warnAt)
    if not MC.Countdown(drop, now) then return nil end
    return MC.TradeWindow(drop, now, warnAt)
end

-- Line 1's action, line 2's trade and line 3's Them: the looter's, or on your own drop its Offer,
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
--- @param ctx table { now, equipped (your gear snapshot's), gear (the looter's inspect gear),
---   askState, askReason, transmogAsk, ownRealm, warnAt (the trade.warnAt default when nil); on your
---   own drop revealed (its Offer panel was opened this session) and offerTone (the offer half of
---   WindowOwn.ToneStates) }
--- @return table card
function CC.Group(drop, ctx)
    ctx = ctx or {}
    local now = ctx.now
    local action, trade, them = sides(drop, ctx, now)
    return {
        kind = "group", id = drop.id, link = drop.link,
        -- line 1
        item = CC.Item(drop), ilvl = WC.Ilvl(drop), ask = action,
        -- line 2
        looter = CC.Looter(drop, ctx.ownRealm), slot = WC.Slot(drop), armorType = WC.ArmorType(drop),
        trade = trade,
        fresh = CC.Freshness(drop, now), countdown = groupCountdown(drop, now, ctx.warnAt),
        -- line 3
        you = CC.Half(L["You"], SC.Me(drop, ctx.equipped)),
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
        item = CC.Item(drop), ilvl = WC.Ilvl(drop), outcome = WH.Outcome(drop),
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
        local ask = card.ask.offered and card.ask.text or DASH
        return { ("%s  %s  %s"):format(card.item.text, card.ilvl.text, ask), lineTwo(card, card.countdown or card.fresh),
            CC.HalfText(card.you) .. "  " .. CC.HalfText(card.them) }
    end,
    history = function(card)
        return { ("%s  %s  %s"):format(card.item.text, card.ilvl.text, card.outcome.text), lineTwo(card, card.time),
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

-- The place parts with the first (the instance, or the label) cut to PLACE_MAX characters.
local function shortPlace(parts)
    local cut = false
    if #parts > 0 then parts[1], cut = CC.Truncate(parts[1], CC.PLACE_MAX) end
    return parts, cut
end

-- The short form's tooltip: the full view's title, its long form, then its other lines.
local function shortTip(full)
    local tip = { full.tip[1], full.text }
    for i = 2, #full.tip do tip[#tip + 1] = full.tip[i] end
    return tip
end

local function shortHeader(group, shown, age, situationLabel, hidden, full)
    local parts, who = WC.Place(group, situationLabel)
    local cut
    parts, cut = shortPlace(parts)
    parts[#parts + 1] = age
    parts[#parts + 1] = CC.Count(shown, hidden)
    parts[#parts + 1] = who
    return { text = table.concat(parts, " · "), tip = shortTip(full), cut = cut }
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
