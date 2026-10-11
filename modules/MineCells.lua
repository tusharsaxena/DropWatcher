local _, NS = ...
-- modules/MineCells.lua — what the My drops tab and the Offer panel say (design spec §11.4, board
-- 04): each column's text, tone and reason tooltip for your own drops, the candidates ranked with
-- their status pills, the tab's summary line, the Post my tradeables lines and where the Offer
-- panel docks. Nothing is ever blank: an unknown value says `?`, `–` or `Checking…` and its
-- tooltip says why.
--
-- PURE. Every composer takes the drop record (modules/LootFeed.lua's shape: `candidates`, `trade`
-- with its `expiresAt`, `me`) and plain inputs (the clock, the warning threshold, an ask's state)
-- and answers a plain table; nothing here reads a module, the client or a saved variable, so
-- test_window_mine drives each state case by case. The frame edges that paint them are
-- modules/WindowMine.lua (the tab) and modules/OfferPanel.lua (the panel). The shared verdict and
-- trade wording is modules/WindowCells.lua's.
--
--   cell = { text, glyph, tone = key of C.TONE, tip = { title, lines... } }
--
-- THE COUNTDOWN. Your own drop's trade window is exact once the trade timer has read the item's
-- tooltip (`trade.basis == "timer"`, `trade.expiresAt`); before that it is estimated from when it
-- dropped and the rule's window (C.TRADE_WINDOW), and says so. A bind-on-equip drop has no window.
-- At `trade.warnAt` seconds or less the countdown reads `ending soon` and is drawn bold (spec §7.4).
--
-- THE CANDIDATES (spec §11.4). Every other member, judged for your drop by the feed: upgrades first
-- by their gain, then EQUAL, NO UPGRADE, CAN'T USE, CHECKING… and UNAVAILABLE, each tie by name. An
-- upgrade for you is not offered by default: the Best candidates cell says `Hidden: an upgrade for
-- you` until you open the Offer panel yourself (AskFlow B2).

NS.MineCells = NS.MineCells or {}
local MC = NS.MineCells
local C  = NS.Constants
local L  = NS.L
local WC = NS.WindowCells

local floor, max, min = math.floor, math.max, math.min

local DASH = "–"
local TOP_N = 3

local function num(v)
    if type(v) == "number" and v == v then return v end
    return nil
end

local function round(n) return floor(n + 0.5) end

local function cell(text, tone, title, ...)
    return { text = text, tone = tone, tip = { title, ... } }
end

local function facts(drop) return type(drop.facts) == "table" and drop.facts or {} end

local function tradeOf(drop) return type(drop.trade) == "table" and drop.trade or {} end

--- A countdown clock: `1:47:12`, `0:08:41`.
--- @param seconds number|nil
--- @return string
function MC.Clock(seconds)
    local s = max(0, floor(num(seconds) or 0))
    return ("%d:%02d:%02d"):format(floor(s / 3600), floor((s % 3600) / 60), s % 60)
end

-- ── the countdown ───────────────────────────────────────────────────────────────────────────

local function isBoe(t) return t.state == "yes" and t.reasonKey == "boe" end

--- The time left to trade your own drop: { left, exact, fraction } (fraction of the rule's window
--- left, 0..1), or nil when there is no countdown (not tradeable, bind on equip, not estimated).
--- @param drop table
--- @param now number GetTime()
--- @return table|nil
function MC.Countdown(drop, now)
    local t = tradeOf(drop)
    if t.state == nil or t.state == "no" or isBoe(t) then return nil end
    local left, exact
    if num(t.expiresAt) and num(now) then
        left, exact = t.expiresAt - now, true
    elseif num(drop.at) and num(now) then
        left, exact = drop.at + C.TRADE_WINDOW - now, false
    else
        return nil
    end
    left = max(0, left)
    return { left = left, exact = exact, fraction = min(1, left / C.TRADE_WINDOW) }
end

-- Whether `left` seconds is at or under the warning threshold (0 or less turns it off).
local function endingSoon(left, warnAt)
    local w = num(warnAt) or C.TRADE_WARN_AT
    return w > 0 and left <= w
end

-- A short reason a drop cannot be traded, for the cell (the tooltip has the whole sentence).
local NO_SHORT = {
    bonusRoll = L["bonus roll"], warbound = L["warbound"], legacy = L["legacy loot"],
    expired = L["window passed"], upgradeForLooter = L["an upgrade for you"], badFacts = L["not loaded"],
}

-- ── the My drops columns ────────────────────────────────────────────────────────────────────

--- The For me column: the verdict, with `keep?` under an upgrade (board 04 note 2).
--- @param drop table
--- @return table cell, with `keep`
function MC.ForMe(drop)
    local c = WC.Me(drop)
    c.keep = c.verdict == "upgrade"
    if c.keep then
        c.sub = L["keep?"]
        c.tip[#c.tip + 1] = L["An upgrade for you: keep it, or offer it anyway. Nobody is offered it unless you choose to."]
    end
    return c
end

local function windowTip(cd, soon)
    local lines = { L["Trade window"] }
    if cd.exact then
        lines[2] = L["Read from the item's tooltip: %s left to trade it."]:format(MC.Clock(cd.left))
    else
        lines[2] = L["Estimated from when it dropped: about %s left. The exact time is read once the item is in your bags."]:format(MC.Clock(cd.left))
    end
    if soon then lines[3] = L["Ending soon: trade it now or it stays yours."] end
    return lines
end

--- The Trade window column: the countdown and its bar, `Not tradeable: why`, or `No limit` for a
--- bind-on-equip drop. `fraction` is how much of the bar is filled; `bold` marks ending soon.
--- @param drop table
--- @param now number GetTime()
--- @param warnAt number|nil seconds (C.TRADE_WARN_AT when nil)
--- @return table cell, with `fraction`, `bold` and `soon`
function MC.TradeWindow(drop, now, warnAt)
    local t = tradeOf(drop)
    if t.state == "no" then
        local c = cell(L["Not tradeable: %s"]:format(NO_SHORT[t.reasonKey] or tostring(t.reasonKey or "?")), "bad",
            L["Not tradeable"], WC.TradeReason(t, L["you"]))
        c.fraction = 0
        return c
    end
    if isBoe(t) then
        local c = cell(L["No limit (BoE)"], "good", L["Trade window"], L["Bind on equip: it stays tradeable until someone equips it."])
        c.fraction = 1
        return c
    end
    local cd = MC.Countdown(drop, now)
    if not cd then
        local c = cell(L["Checking…"], "muted", L["Trade window"], L["Not estimated yet: the item's details are loading."])
        c.fraction = 0
        return c
    end
    local soon = endingSoon(cd.left, warnAt)
    local text = MC.Clock(cd.left)
    if not cd.exact then text = "~" .. text end
    if soon then text = text .. " " .. L["ending soon"] end
    local c = { text = text, tone = soon and "warn" or "plain", tip = windowTip(cd, soon) }
    c.fraction, c.bold, c.soon, c.left = cd.fraction, soon, soon, cd.left
    return c
end

-- ── the candidates ──────────────────────────────────────────────────────────────────────────

-- Each status's rank (lower first) and pill.
local RANK = { upgrade = 1, sidegrade = 2, downgrade = 3, cantUse = 4, doesntWant = 4, unknown = 5, checking = 6, unavailable = 7 }
local PILL_TONE = { upgrade = "good", sidegrade = "plain", downgrade = "bad", cantUse = "bad", doesntWant = "bad",
    unknown = "muted", checking = "muted", unavailable = "muted" }
local PILL_TEXT = {
    sidegrade = L["EQUAL"], downgrade = L["NO UPGRADE"], cantUse = L["CAN'T USE"], doesntWant = L["CAN'T USE"],
    unknown = L["UNAVAILABLE"], checking = L["CHECKING…"], unavailable = L["UNAVAILABLE"],
}
local PILL_TIP = {
    upgrade = L["An upgrade for them: a higher item level than what they wear there."],
    sidegrade = L["About what they wear there: within the sidegrade band."],
    downgrade = L["Lower than what they wear there."],
    cantUse = L["Their class or spec cannot use it."],
    doesntWant = L["Usable, but not wanted for their spec."],
    unknown = L["Their gear was read, but the item it would replace was not."],
    checking = L["Their gear is being inspected; the verdict follows."],
    unavailable = L["Their gear could not be read: out of range, offline or not inspected yet."],
}

-- The status a candidate shows: its verdict when judged, else checking or unavailable.
local function statusOf(c)
    if c.status == "ready" then
        local v = type(c.eval) == "table" and c.eval.verdict or "unknown"
        return RANK[v] and v or "unknown"
    end
    if c.status == "checking" then return "checking" end
    return "unavailable"
end

local function gainOf(c)
    return type(c.eval) == "table" and num(c.eval.ilvlDelta) or nil
end

local function pillOf(status, gain, who)
    local text = PILL_TEXT[status]
    if status == "upgrade" then
        text = gain and L["%s UPGRADE"]:format(WC.Signed(gain)) or L["UPGRADE"]
    end
    return { text = text, tone = PILL_TONE[status], tip = { ("%s: %s"):format(who, text), PILL_TIP[status] } }
end

-- `eq → drop`: what they wear there against the drop's item level.
local function eqText(status, eval, ilvl)
    local drop = ilvl and tostring(ilvl) or "?"
    if status == "checking" then return "… → " .. drop end
    local base = type(eval) == "table" and eval.baseline or nil
    if type(base) == "table" and num(base.ilvl) then return ("%d → %s"):format(round(base.ilvl), drop) end
    local d = type(eval) == "table" and num(eval.ilvlDelta)
    if d and ilvl then return ("%d → %s"):format(round(ilvl - d), drop) end
    if type(eval) == "table" and eval.verdict == "upgrade" then return L["empty"] .. " → " .. drop end
    return DASH .. " → " .. drop
end

-- One candidate, ready to draw.
local function entryOf(c, ilvl)
    local status = statusOf(c)
    local who = WC.ShortName(c.name)
    local gain = gainOf(c)
    return { guid = c.guid, name = c.name, short = who, classFile = c.classFile, status = status,
        rank = RANK[status], gain = gain, pill = pillOf(status, gain, who), eq = eqText(status, c.eval, ilvl),
        offerable = status == "upgrade" or status == "sidegrade" }
end

local function byRank(a, b)
    if a.rank ~= b.rank then return a.rank < b.rank end
    local ga, gb = a.gain or -math.huge, b.gain or -math.huge
    if ga ~= gb then return ga > gb end
    return tostring(a.short) < tostring(b.short)
end

--- Every other member, ranked for your drop: { guid, name, short, classFile, status, rank, gain,
--- pill = { text, tone, tip }, eq, offerable }, upgrades first by gain.
--- @param drop table
--- @return table
function MC.Candidates(drop)
    local out = {}
    local ilvl = num(facts(drop).ilvl)
    for _, c in pairs(type(drop.candidates) == "table" and drop.candidates or {}) do
        if type(c) == "table" then out[#out + 1] = entryOf(c, ilvl) end
    end
    table.sort(out, byRank)
    return out
end

local function countChecking(list)
    local n = 0
    for _, e in ipairs(list) do if e.status == "checking" then n = n + 1 end end
    return n
end

local function rankedTip(list)
    local tip = { L["Best candidates"] }
    for _, e in ipairs(list) do tip[#tip + 1] = ("%s: %s (%s)"):format(e.short, e.pill.text, e.eq) end
    return tip
end

local function upgradesOf(list)
    local ups = {}
    for _, e in ipairs(list) do if e.status == "upgrade" then ups[#ups + 1] = e end end
    return ups
end

local function topText(ups)
    local parts = {}
    for i = 1, min(TOP_N, #ups) do
        local e = ups[i]
        parts[i] = e.gain and ("%s %s"):format(e.short, WC.Signed(e.gain)) or e.short
    end
    if #ups > TOP_N then parts[#parts + 1] = L["+%d more"]:format(#ups - TOP_N) end
    return table.concat(parts, " · ")
end

-- The cell when no one is an upgrade: still checking, or nobody's.
local function noUpgradeCell(list)
    local checking = countChecking(list)
    local c
    if checking > 0 then
        c = { text = L["Checking %d…"]:format(checking), tone = "muted", tip = rankedTip(list) }
        c.tip[#c.tip + 1] = L["Their gear is being inspected; the list fills in as each read lands."]
    else
        c = { text = L["Nobody's upgrade"], tone = "muted", tip = rankedTip(list) }
        c.tip[#c.tip + 1] = L["It is not an upgrade for anyone whose gear was read. Announce still offers it to the group."]
    end
    return c
end

--- The Best candidates column: the top three upgrades (`Seta +14 · Butterz +6 · +1 more`), or why
--- there are none. Hidden for an upgrade for you until you choose to offer it (`revealed`).
--- @param drop table
--- @param revealed boolean|nil the player opened its Offer panel this session
--- @return table cell, with `list` (MC.Candidates' answer) and `hidden`
function MC.BestCandidates(drop, revealed)
    local list = MC.Candidates(drop)
    local c
    if tradeOf(drop).state == "no" then
        c = cell(DASH, "muted", L["Best candidates"], L["Not tradeable, so nobody can be offered it."])
    elseif #list == 0 then
        c = cell(L["Nobody else in your group"], "muted", L["Best candidates"], L["Join a group to see who it would help."])
    elseif type(drop.me) == "table" and drop.me.verdict == "upgrade" and not revealed then
        c = cell(L["Hidden: an upgrade for you"], "muted", L["Best candidates"],
            L["It is an upgrade for you, so nobody is offered it unless you choose to. Offer… shows who it would help."])
        c.hidden = true
    else
        local ups = upgradesOf(list)
        if #ups == 0 then
            c = noUpgradeCell(list)
        else
            c = { text = topText(ups), tone = "good", tip = rankedTip(list) }
        end
    end
    c.list = list
    return c
end

-- ── the buttons ─────────────────────────────────────────────────────────────────────────────

-- One message button's look per ask state (modules/Asks.lua): label, catalog mark, clickable.
local function lookTable(ready, sent)
    return {
        ready  = { text = ready, enabled = true },
        queued = { text = L["Queued"], icon = "clock", enabled = true },
        sent   = { text = sent, icon = "confirm", enabled = false },
        failed = { text = L["Retry"], icon = "reset", enabled = true },
    }
end

local OFFER_LOOK = lookTable(L["Offer"], L["Offered"])
local ANNOUNCE_LOOK = lookTable(L["Announce"], L["Announced"])

local QUEUED_LINE = L["Chat is restricted right now: it is sent when it lifts."]

local function offerTip(state, who, reason)
    if state == "queued" then return L["Queued"], QUEUED_LINE, L["Click to cancel it."] end
    if state == "sent" then return L["Offered"], L["You offered it to %s. One offer per item per member."]:format(who) end
    if state == "failed" then return L["Retry"], L["The offer to %s was not sent: %s."]:format(who, tostring(reason or "?")), L["Click to try again."] end
    return L["Offer"], L["Whisper %s your offer template for this item."]:format(who), L["One offer per item per member."]
end

local function announceTip(state, reason)
    if state == "queued" then return L["Queued"], QUEUED_LINE, L["Click to cancel it."] end
    if state == "sent" then return L["Announced"], L["You posted it to the group. One announce per item."] end
    if state == "failed" then return L["Retry"], L["The announce was not sent: %s."]:format(tostring(reason or "?")), L["Click to try again."] end
    return L["Announce"], L["Post your announce template for this item to the group or raid."], L["One announce per item."]
end

local function look(tbl, state)
    local s = tbl[state] and state or "ready"
    local l = tbl[s]
    return { text = l.text, icon = l.icon, enabled = l.enabled, state = s }
end

--- The Offer button of one candidate, by its ask state.
--- @param state string|nil NS.Asks.StateOf's state
--- @param reason string|nil
--- @param who string the member's short name
--- @return table { text, icon, enabled, state, tip }
function MC.OfferButton(state, reason, who)
    local b = look(OFFER_LOOK, state)
    b.tip = { offerTip(b.state, who, reason) }
    return b
end

--- The Announce button of one drop, by its ask state.
--- @param state string|nil
--- @param reason string|nil
--- @return table { text, icon, enabled, state, tip }
function MC.AnnounceButton(state, reason)
    local b = look(ANNOUNCE_LOOK, state)
    b.tip = { announceTip(b.state, reason) }
    return b
end

--- The Trade button of one candidate: enabled, or disabled with the trade helper's reason.
--- @param ok boolean NS.TradeHelper.CanGive's answer
--- @param why string|nil its reason, in words
--- @param who string
--- @return table { enabled, tip }
function MC.TradeButton(ok, why, who)
    if ok then
        return { enabled = true, tip = { L["Trade"], L["Open a trade with %s with the item already placed."]:format(who), L["You confirm in the trade window."] } }
    end
    return { enabled = false, tip = { L["Trade: not now"], why or L["The trade cannot be opened now."] } }
end

--- A row's actions (board 04 note 4): Offer… and Announce while it may be traded; a dash and Hide
--- when it cannot.
--- @param drop table
--- @param best table MC.BestCandidates' answer
--- @param announce table MC.AnnounceButton's answer
--- @return table { tradeable, offer = { primary, tip }, announce, hide = { tip }, dash = { tip } }
function MC.Actions(drop, best, announce)
    local t = tradeOf(drop)
    if t.state == "no" then
        return { tradeable = false,
            dash = { tip = { L["No offer"], L["Not tradeable: %s"]:format(WC.TradeReason(t, L["you"])) } },
            hide = { tip = { L["Hide"], L["Hide this drop from My drops for this session."] } } }
    end
    local ups = upgradesOf(best.list or {})
    local primary = #ups > 0 and not best.hidden
    return { tradeable = true, announce = announce,
        offer = { primary = primary, tip = { L["Offer…"], L["Open the panel of who could use it, ranked by their gain, with Offer and Trade for each."] } } }
end

-- ── the summary and Post my tradeables ──────────────────────────────────────────────────────

--- The tab's summary line (board 04's footer): how many of your drops may be traded and the next
--- countdown to run out.
--- @param drops table your own drops on the tab
--- @param now number GetTime()
--- @return table { count, next, text, tip }
function MC.Summary(drops, now)
    local count, nextLeft = 0, nil
    for _, d in ipairs(drops) do
        local s = tradeOf(d).state
        if s == "yes" or s == "likely" then
            count = count + 1
            local cd = MC.Countdown(d, now)
            if cd and (nextLeft == nil or cd.left < nextLeft) then nextLeft = cd.left end
        end
    end
    local text = count == 1 and L["1 tradeable"] or L["%d tradeable"]:format(count)
    if nextLeft then text = text .. " · " .. L["next expiry %s"]:format(MC.Clock(nextLeft)) end
    return { count = count, next = nextLeft, text = text,
        tip = { L["Your tradeable drops"], L["How many of your drops you can still trade, and the next trade window to run out."] } }
end

--- Post my tradeables' lines (spec §11.4): one announce listing every link, cut into several lines
--- so none passes `maxLen` bytes (a link counts whole and is never split).
--- @param links table item links, in order
--- @param maxLen number|nil C.MESSAGE_MAX_LEN when nil
--- @return table lines
function MC.PostLines(links, maxLen)
    maxLen = num(maxLen) or C.MESSAGE_MAX_LEN
    local prefix = L["Up for trade, whisper me:"]
    local lines, cur = {}, nil
    for _, link in ipairs(links or {}) do
        if type(link) == "string" and link ~= "" then
            local nextLine = cur and (cur .. " " .. link)
            if nextLine and #nextLine <= maxLen then
                cur = nextLine
            else
                if cur then lines[#lines + 1] = cur end
                cur = prefix .. " " .. link
            end
        end
    end
    if cur then lines[#lines + 1] = cur end
    return lines
end

-- ── the Offer panel's header and dock ───────────────────────────────────────────────────────

--- The Offer panel's item line: `You: -5 ilvl · 305 · Trade window 1:47:12`.
--- @param drop table
--- @param now number GetTime()
--- @param warnAt number|nil
--- @return table { name, text, tip, tone }
function MC.PanelHeader(drop, now, warnAt)
    local me = WC.Me(drop)
    local parts = {}
    local d = type(drop.me) == "table" and num(drop.me.ilvlDelta)
    parts[1] = d and L["You: %s ilvl"]:format(WC.Signed(d)) or L["You: %s"]:format(me.text)
    local ilvl = num(facts(drop).ilvl)
    parts[2] = ilvl and tostring(ilvl) or "?"
    local tw = MC.TradeWindow(drop, now, warnAt)
    parts[3] = L["Trade window %s"]:format(tw.text)
    local tip = { WC.ItemName(drop.link) or "?" }
    for i = 2, #me.tip do tip[#tip + 1] = me.tip[i] end
    for i = 2, #tw.tip do tip[#tip + 1] = tw.tip[i] end
    return { name = WC.ItemName(drop.link) or "?", text = table.concat(parts, " · "), tip = tip, tone = tw.tone }
end

--- Where the Offer panel goes (spec §11.4): docked to the window's right edge, else its left, else
--- floating, when the screen has no room either side. Unknown geometry docks right.
--- @param left number|nil the window's left edge
--- @param right number|nil its right edge
--- @param width number the panel's width
--- @param screen number|nil the screen's width
--- @param gap number|nil the gap between the two
--- @return string `right`, `left` or `float`
function MC.DockSide(left, right, width, screen, gap)
    left, right, screen = num(left), num(right), num(screen)
    if not (left and right and screen and screen > 0) then return "right" end
    gap = num(gap) or 0
    if right + gap + width <= screen then return "right" end
    if left - gap - width >= 0 then return "left" end
    return "float"
end
