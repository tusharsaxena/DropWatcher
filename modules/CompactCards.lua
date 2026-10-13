local _, NS = ...
-- modules/CompactCards.lua — what compact mode's cards say (compact spec §2 and §3, DW-C1): each
-- card's three lines of text, their tones and their tooltips, for all three tabs, and the group
-- header's short form. The same data as the full tables: every piece is a full-view composer's
-- cell (modules/WindowCells.lua, modules/MineCells.lua, modules/WindowHistory.lua), reshaped, so
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
--   Group drops  line 1: item (quality color), ilvl (right), ask
--                line 2: looter (class color, ⊕ when cross-realm), slot, trade; fresh (right, dimmed)
--                line 3: you = { label, verdict, eq }, them = { label, verdict, eq }
--   My drops     line 1: item, ilvl (right), offer (or a dash on a drop that cannot be traded)
--                line 2: forYou = { label, verdict, sub }, trade (the countdown and its bar, right)
--                line 3: candidates (class-colored parts), announce (none on a drop that cannot be traded)
--   History      line 1: item, ilvl (right), outcome (right, in its tone)
--                line 2: looter, slot, trade; time (right, dimmed)
--                line 3: you, them
--
-- THE VERDICT. A verdict reads glyph then text: `▲ +19`, `≈ +0`, `▽ -13`, and a verdict the full
-- view says in a word gets compact mode's ⊘ (`⊘ Can't use`, `⊘ Not wanted`). The worn levels
-- follow in parentheses, dimmed (`(321/308)`, `(empty)`, `(…)`); none where the full view's cell
-- is a dash. Glyphs, ⊘ and ⊕ are drawn in the monospace face (JetBrains Mono carries all three).
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

--- A verdict's compact text: the glyph (⊘ for a worded verdict), a space, then the cell's text.
--- @param v table CC.Verdict's answer
--- @return string
function CC.VerdictText(v)
    if v.glyph then return v.glyph .. " " .. v.text end
    return v.text
end

-- ── the shared pieces ───────────────────────────────────────────────────────────────────────

--- A verdict cell as compact mode draws it: the full view's text, tone and tooltip, with ⊘ for a
--- verdict the full view says in a word.
--- @param c table a WindowCells verdict cell (WC.Me, WC.Them, MC.ForMe)
--- @return table { text, glyph, tone, tip, verdict }
function CC.Verdict(c)
    local glyph = c.glyph
    if not glyph and WORD_VERDICT[c.verdict] then glyph = CC.NO_GLYPH end
    return { text = c.text, glyph = glyph, tone = c.tone, tip = copyTip(c.tip), verdict = c.verdict }
end

-- The worn levels, in parentheses and dimmed; nil where the full view shows a dash.
local EQ_WORD = { [L["empty slot"]] = L["empty"] }

--- An equipment cell's levels as compact mode draws them: `(321/308)`, `(empty)`, `(…)`; nil when
--- the full view shows a dash (not worn, or your own drop's Their eq).
--- @param c table|nil WC.MyEq's or WC.TheirEq's answer
--- @return table|nil { text, tone = "muted", tip, items }
function CC.Eq(c)
    if type(c) ~= "table" or c.text == DASH then return nil end
    return { text = ("(%s)"):format(EQ_WORD[c.text] or c.text), tone = "muted", tip = copyTip(c.tip), items = c.items }
end

--- One half of line 3: `You ▽ -13 (321/308)`.
--- @param label string `You` or `Them`
--- @param verdictCell table a WindowCells verdict cell
--- @param eqCell table|nil a WindowCells equipment cell
--- @return table { label, verdict, eq }
function CC.Half(label, verdictCell, eqCell)
    return { label = label, verdict = CC.Verdict(verdictCell), eq = CC.Eq(eqCell) }
end

--- A half's plain text: `You ▽ -13 (321/308)`.
--- @param h table CC.Half's answer
--- @return string
function CC.HalfText(h)
    local out = h.label .. " " .. CC.VerdictText(h.verdict)
    if h.eq then out = out .. " " .. h.eq.text end
    return out
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

--- The looter piece: the full view's Looter cell (short name, class color), with ⊕ (`mark`) and a
--- tooltip line naming the realm when the looter is from another realm.
--- @param drop table
--- @param ownRealm string|nil
--- @return table cell, with `classFile`, `mark` and `crossRealm`
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

-- ── the Group drops card (spec §2) ──────────────────────────────────────────────────────────

--- A Group drops card.
--- @param drop table
--- @param ctx table { now, equipped (your gear snapshot's), gear (the looter's inspect gear),
---   askState, askReason, transmogAsk, ownRealm }
--- @return table card
function CC.Group(drop, ctx)
    ctx = ctx or {}
    local now = ctx.now
    return {
        kind = "group", id = drop.id, link = drop.link,
        -- line 1
        item = CC.Item(drop), ilvl = WC.Ilvl(drop),
        ask = WC.Ask(drop, ctx.askState, ctx.askReason, ctx.transmogAsk),
        -- line 2
        looter = CC.Looter(drop, ctx.ownRealm), slot = WC.Slot(drop), trade = WC.Trade(drop),
        fresh = CC.Freshness(drop, now),
        -- line 3
        you = CC.Half(L["You"], WC.Me(drop), WC.MyEq(drop, ctx.equipped)),
        them = CC.Half(L["Them"], WC.Them(drop, now), WC.TheirEq(drop, ctx.gear, now)),
    }
end

-- ── the My drops card (spec §3) ─────────────────────────────────────────────────────────────

-- Line 2's countdown: MC.TradeWindow's, but a drop that cannot be traded says so in two words (the
-- reason stays in the tooltip).
local function countdown(drop, now, warnAt)
    local c = MC.TradeWindow(drop, now, warnAt)
    if type(drop.trade) == "table" and drop.trade.state == "no" then c.text = L["Not tradeable"] end
    return c
end

local function forYou(drop)
    local c = MC.ForMe(drop)
    local sub = c.sub and ("(%s)"):format(c.sub) or nil
    return { label = L["For you"], verdict = CC.Verdict(c), sub = sub, keep = c.keep }
end

-- Line 3's candidates: the full view's Best candidates cell, with each named upgrade as its own
-- part so the edge can color it by class.
local function candidates(best)
    local c = { text = best.text, tone = best.tone, tip = copyTip(best.tip), hidden = best.hidden, parts = {} }
    if best.tone ~= "good" then return c end
    local parts, more = MC.TopUpgrades(best.list or {})
    for i, p in ipairs(parts) do c.parts[i] = { text = p.text, classFile = p.entry.classFile } end
    c.more = more
    return c
end

-- Line 1's Offer, or the dash a drop that cannot be traded shows instead.
local function offerOf(actions)
    if actions.tradeable then
        return { text = L["Offer"], primary = actions.offer.primary, enabled = true, tip = copyTip(actions.offer.tip) }
    end
    return { text = DASH, dash = true, enabled = false, tip = copyTip(actions.dash.tip) }
end

-- Line 3's Announce; nil on a drop that cannot be traded (line 1's dash says why).
local function lineThreeAction(actions)
    if actions.tradeable then return actions.announce end
    return nil
end

--- A My drops card.
--- @param drop table one of your drops
--- @param ctx table { now, warnAt, revealed (its Offer panel was opened this session),
---   announceState, announceReason }
--- @return table card
function CC.Mine(drop, ctx)
    ctx = ctx or {}
    local best = MC.BestCandidates(drop, ctx.revealed)
    local actions = MC.Actions(drop, best, MC.AnnounceButton(ctx.announceState, ctx.announceReason))
    return {
        kind = "mine", id = drop.id, link = drop.link, tradeable = actions.tradeable,
        -- line 1
        item = CC.Item(drop), ilvl = WC.Ilvl(drop), offer = offerOf(actions),
        -- line 2
        forYou = forYou(drop), trade = countdown(drop, ctx.now, ctx.warnAt),
        -- line 3
        candidates = candidates(best), action = lineThreeAction(actions),
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
        looter = CC.Looter(drop, ctx.ownRealm), slot = WC.Slot(drop), trade = WC.Trade(drop),
        time = CC.When(drop.at, ctx.nowEpoch, ctx.dateFn),
        -- line 3
        you = CC.Half(L["You"], WC.Me(drop), nil), them = CC.Half(L["Them"], WH.Them(drop), nil),
    }
end

-- ── the plain text of a card (tests, and the simulator's report) ────────────────────────────

local function looterText(c) return c.mark and (c.text .. " " .. c.mark) or c.text end

local function lineTwo(card, right)
    return ("%s · %s · %s  %s"):format(looterText(card.looter), card.slot.text, card.trade.text, right.text)
end

local function candidatesText(c)
    if #c.parts == 0 then return c.text end
    local words = {}
    for i, p in ipairs(c.parts) do words[i] = p.text end
    words[#words + 1] = c.more
    return table.concat(words, " · ")
end

local PLAIN = {
    group = function(card)
        local ask = card.ask.offered and card.ask.text or DASH
        return { ("%s  %s  %s"):format(card.item.text, card.ilvl.text, ask), lineTwo(card, card.fresh),
            CC.HalfText(card.you) .. "  " .. CC.HalfText(card.them) }
    end,
    mine = function(card)
        local fy = card.forYou
        local two = fy.label .. " " .. CC.VerdictText(fy.verdict) .. (fy.sub and (" " .. fy.sub) or "")
        return { ("%s  %s  %s"):format(card.item.text, card.ilvl.text, card.offer.text),
            two .. "  " .. card.trade.text, candidatesText(card.candidates) .. (card.action and ("  " .. card.action.text) or "") }
    end,
    history = function(card)
        return { ("%s  %s  %s"):format(card.item.text, card.ilvl.text, card.outcome.text), lineTwo(card, card.time),
            CC.HalfText(card.you) .. "  " .. CC.HalfText(card.them) }
    end,
}

--- A card's three lines as plain text, each piece in order (two spaces before a right-aligned one).
--- @param card table CC.Group's, CC.Mine's or CC.History's answer
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

--- A Group drops or My drops header's short form (compact spec §2): `Instance · Boss · Difficulty ·
--- 3m · 2 · Recorder`, its tooltip the long form (WC.Header) and its lines. The chevron says whether
--- it is collapsed, so the text does not.
--- @param group table a feed group
--- @param shown number
--- @param now number|nil GetTime()
--- @param situationLabel string|nil
--- @param collapsed boolean
--- @param hidden table|nil
--- @param filter table|nil
--- @param yours number|nil
--- @return table { text, tip, cut }
function CC.Header(group, shown, now, situationLabel, collapsed, hidden, filter, yours)
    local full = WC.Header(group, shown, now, situationLabel, collapsed, hidden, filter, yours)
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
