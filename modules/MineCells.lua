local _, NS = ...
-- modules/MineCells.lua — what your own drops and the Offer panel say (design spec §11.4, board
-- 04; feedback-5 spec §1-§3): the Trade window cell every drop shows on Drops, the candidates
-- ranked for the Offer panel (feedback-7 spec §0: their Their eq cell is NS.SideCells.Candidate's),
-- the Offer panel's buttons, header and dock, the Drops strip's
-- summary line and Post my tradeables' lines; and what your own drop says on Drops (feedback-5
-- spec §2): Trade's word, Them as `Upgrade for N` (feedback-7 spec §2; `(Details)` before, and
-- `(Multiple)` before that) with every member it upgrades in the tooltip, and the Offer button.
-- Nothing is ever blank: an unknown value says `?`, `–` or `Checking` and its tooltip says why.
--
-- PURE. Every composer takes the drop record (modules/LootFeed.lua's shape: `candidates`, `trade`
-- with its `expiresAt`, `me`) and plain inputs (the clock, the warning threshold, an ask's state)
-- and answers a plain table; nothing here reads a module, the client or a saved variable (only
-- NS.TipMarks: Upgrade for N's tooltip lines take the class and quality colors; and NS.OffSpec, pure,
-- for a candidate's off-spec part), so test_mine_cells drives each state case by case. The frame edges that paint them are
-- modules/WindowGroup.lua, modules/CompactGroup.lua and modules/DetailCard.lua (the Trade window
-- column, the compact card's countdown and your own drop's cells, through modules/WindowOwn.lua),
-- modules/DropsStrip.lua (the strip) and modules/OfferPanel.lua (the panel). The shared verdict
-- and trade wording is modules/WindowCells.lua's.
--
--   cell = { text, glyph, tone = key of C.TONE, tip = { title, lines... } }
--
-- THE COUNTDOWN. Your own drop's trade window is exact once the trade timer has read the item's
-- tooltip (`trade.basis == "timer"`, `trade.expiresAt`); before that it is estimated from when it
-- dropped and the rule's window (C.TRADE_WINDOW), and says so. Another player's drop (`isMine ==
-- false`) is always that estimate, and its tooltip names the looter rather than your bags. A
-- bind-on-equip drop has no window. At `trade.warnAt` seconds or less the countdown is ending soon
-- (spec §7.4): amber and bold, its bar amber, the words `Ending soon: …` in its tooltip only
-- (feedback-5 spec §1: the cell is never wide enough to say it; feedback-6 spec §0 sizes it to its
-- widest answer).
--
-- THE CANDIDATES (spec §11.4). Every other member, judged for your drop by the feed: upgrades first
-- by their gain, then equal, then off-spec upgrades and equals (feedback-19 spec §3: a member whose
-- current spec can't use it but another spec of theirs gains, by that spec's gain; offerable too),
-- no upgrade, can't use, checking and unavailable, each tie by name; each
-- carries its judgment (`eval`) and a line explaining its status (`explain`), which the Offer
-- panel's Their eq cell draws in the Drops table's Them look (NS.SideCells.Candidate; the status
-- pills and the `eq -> drop` text went with feedback-7 spec §0). An
-- upgrade for you is not offered by default: Them reads `Hidden` until you open
-- the Offer panel yourself (AskFlow B2).
--
-- YOUR OWN DROP ON DROPS (feedback-5 spec §2; feedback-7 spec §2). Trade reads its word alone
-- (`Yes`, not `Yes (2)`), its tooltip saying how many members it upgrades; Them reads `Upgrade for N`
-- (NS.SideCells.Them; main-spec upgrades only), green, or `No upgrades`, muted, its tooltip naming each upgrade by gain as a
-- grid row (feedback-7 spec §3, NS.TipMarks.GearRows): `Butterz  276  Bloodthorn Treads  ▲11`, the
-- name in its class color, the item in its quality color, the table's glyph and the gain in green.
-- The keep?
-- rule holds: while it is an upgrade for you and not revealed, the count is not said and Them
-- reads `Hidden`. Actions is Offer (MC.OwnOffer, WindowCells.Ask's shape), toned by the furthest
-- offer sent (cyan while it is your move, feedback-6 spec §2); the gray No action with the reason
-- when it cannot be traded (WindowCells.NoAction, feedback-11 spec §1).

NS.MineCells = NS.MineCells or {}
local MC = NS.MineCells
local C  = NS.Constants
local L  = NS.L
local WC = NS.WindowCells
local TM = NS.TipMarks

local floor, max, min = math.floor, math.max, math.min

local DASH = "–"

local function num(v)
    if type(v) == "number" and v == v then return v end
    return nil
end

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

--- The time left to trade a drop: { left, exact, fraction } (fraction of the rule's window left,
--- 0..1), or nil when there is no countdown (not tradeable, bind on equip, not estimated). Exact
--- only from the trade timer's read of your own item; another player's drop is always estimated.
--- @param drop table
--- @param now number GetTime()
--- @return table|nil
function MC.Countdown(drop, now)
    local t = tradeOf(drop)
    if t.state == nil or t.state == "no" or isBoe(t) then return nil end
    local left, exact
    if num(t.expiresAt) and num(now) and drop.isMine ~= false then
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
    local w = num(warnAt) or NS.C.PROFILE.trade.warnAt
    return w > 0 and left <= w
end

-- A short reason a drop cannot be traded, for the cell (the tooltip has the whole sentence).
-- Why not, in the words that fit the Trade window column (ui spec §4, FB-11: never cut short); the
-- full reason is the cell's tooltip.
local NO_SHORT = {
    bonusRoll = L["Bonus roll"], warbound = L["Warbound"], legacy = L["Legacy loot"],
    expired = L["Window passed"], upgradeForLooter = L["Your upgrade"], upgradeForYou = L["Your upgrade"],
    badFacts = L["Not loaded"],
}
-- Another player's drop says whose upgrade it is in the same room.
local NO_SHORT_THEIRS = { upgradeForLooter = L["Their upgrade"] }
-- Both read-only, for the test that sizes the Trade window column to its widest answer
-- (feedback-6 spec §0, tests/test_drops_layout.lua).
MC.NO_SHORT, MC.NO_SHORT_THEIRS = NO_SHORT, NO_SHORT_THEIRS

-- Whose drop it is, for the tooltips: nil for yours (or a record that does not say), else the
-- looter's short name.
local function othersName(drop)
    if drop.isMine ~= false then return nil end
    return WC.ShortName(type(drop.looter) == "table" and drop.looter.name or nil)
end

-- ── the Trade window column ─────────────────────────────────────────────────────────────────

-- `who` is the looter's short name on another player's drop, nil on yours.
local function windowTip(cd, soon, who)
    local lines = { L["Trade window"] }
    local left = MC.Clock(cd.left)
    if cd.exact then
        lines[2] = L["Read from the item's tooltip: %s left to trade it."]:format(left)
    elseif who then
        lines[2] = L["Estimated from when it dropped: about %s left for %s to trade it. Only their own bags know the exact time."]:format(left, who)
    else
        lines[2] = L["Estimated from when it dropped: about %s left. The exact time is read once the item is in your bags."]:format(left)
    end
    if soon then
        lines[3] = who and L["Ending soon: once it runs out, %s keeps it."]:format(who)
            or L["Ending soon: trade it now or it stays yours."]
    end
    return lines
end

--- The Trade window column: the countdown and its bar, why it is not tradeable, or `No limit` for a
--- bind-on-equip drop, for your drop or another player's (whose estimate names its looter).
--- `fraction` is how much of the bar is filled; ending soon is `bold`, `soon` and the warn tone,
--- never words in the text (feedback-5 spec §1).
--- @param drop table
--- @param now number GetTime()
--- @param warnAt number|nil seconds (the `trade.warnAt` default when nil)
--- @return table cell, with `fraction`, `bold` and `soon`
function MC.TradeWindow(drop, now, warnAt)
    local t = tradeOf(drop)
    local who = othersName(drop)
    if t.state == "no" then
        local short = who and NO_SHORT_THEIRS[t.reasonKey] or NO_SHORT[t.reasonKey]
        local c = cell(short or L["Not tradeable"], "bad", L["Not tradeable"], WC.TradeReason(t, who or L["you"]))
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
        local c = cell(L["Checking"], "muted", L["Trade window"], L["Not estimated yet: the item's details are loading."])
        c.fraction = 0
        return c
    end
    local soon = endingSoon(cd.left, warnAt)
    local text = MC.Clock(cd.left)
    if not cd.exact then text = "~" .. text end
    local c = { text = text, tone = soon and "warn" or "plain", tip = windowTip(cd, soon, who) }
    c.fraction, c.bold, c.soon, c.left = cd.fraction, soon, soon, cd.left
    return c
end

-- ── the candidates ──────────────────────────────────────────────────────────────────────────

-- Each status's rank (lower first) and the line explaining it (the Their eq cell's tooltip). An
-- off-spec upgrade or equal (feedback-19 spec §3) ranks after every main-spec one.
local RANK = { upgrade = 1, sidegrade = 2, offSpecUpgrade = 3, offSpecSidegrade = 4, downgrade = 5,
    cantUse = 6, doesntWant = 6, unknown = 7, checking = 8, unavailable = 9 }
local EXPLAIN = {
    upgrade = L["An upgrade for them: a higher item level than what they wear there."],
    sidegrade = L["About what they wear there: within the sidegrade band."],
    offSpecUpgrade = L["An upgrade for one of their other specs (off-spec)."],
    offSpecSidegrade = L["About what one of their other specs has there (off-spec): within the sidegrade band."],
    downgrade = L["Lower than what they wear there."],
    cantUse = L["Their class or spec cannot use it."],
    doesntWant = L["Usable, but not wanted for their spec."],
    unknown = L["Their gear was read, but the item it would replace was not."],
    checking = L["Their gear is being inspected; the verdict follows."],
    unavailable = L["Their gear could not be read: out of range, offline or not inspected yet."],
}

-- A Can't use another spec of theirs gains from (NS.OffSpec.Of): its off-spec status, else nil.
local OFF_STATUS = { upgrade = "offSpecUpgrade", sidegrade = "offSpecSidegrade" }

-- The status a candidate shows: its verdict when judged (an off-spec upgrade or equal its own),
-- else checking or unavailable.
local function statusOf(c)
    if c.status == "ready" then
        local v = type(c.eval) == "table" and c.eval.verdict or "unknown"
        local off = NS.OffSpec.Of(c.eval)
        v = off and OFF_STATUS[off.verdict] or v
        return RANK[v] and v or "unknown"
    end
    if c.status == "checking" then return "checking" end
    return "unavailable"
end

local OFFERABLE = { upgrade = true, sidegrade = true, offSpecUpgrade = true, offSpecSidegrade = true }

-- One candidate, ready to draw: its gain and baseline the off-spec part's when that is the one
-- that counts (NS.OffSpec.EvalFor), so byRank sorts each tier by gain.
local function entryOf(c)
    local status = statusOf(c)
    local who = WC.ShortName(c.name)
    local eval = type(c.eval) == "table" and c.eval or nil
    local judged = eval and NS.OffSpec.EvalFor(eval)
    return { guid = c.guid, name = c.name, short = who, classFile = c.classFile, status = status,
        rank = RANK[status], gain = judged and num(judged.ilvlDelta) or nil, eval = eval, explain = EXPLAIN[status],
        baseline = judged and type(judged.baseline) == "table" and judged.baseline or nil,
        offerable = OFFERABLE[status] == true }
end

local function byRank(a, b)
    if a.rank ~= b.rank then return a.rank < b.rank end
    local ga, gb = a.gain or -math.huge, b.gain or -math.huge
    if ga ~= gb then return ga > gb end
    return tostring(a.short) < tostring(b.short)
end

--- Every other member, ranked for your drop: { guid, name, short, classFile, status, rank, gain,
--- eval (NS.Evaluate's answer, or nil), explain (a line on the status), baseline (the worn item it
--- is judged against: facts, or nil), offerable }, upgrades first by gain.
--- @param drop table
--- @return table
function MC.Candidates(drop)
    local out = {}
    for _, c in pairs(type(drop.candidates) == "table" and drop.candidates or {}) do
        if type(c) == "table" then out[#out + 1] = entryOf(c) end
    end
    table.sort(out, byRank)
    return out
end

local function countChecking(list)
    local n = 0
    for _, e in ipairs(list) do if e.status == "checking" then n = n + 1 end end
    return n
end

-- Upgrade for N counts main-spec upgrades only (feedback-19 spec §3).
local function upgradesOf(list)
    local ups = {}
    for _, e in ipairs(list) do if e.status == "upgrade" then ups[#ups + 1] = e end end
    return ups
end

-- ── your own drop on Drops (feedback-5 spec §2) ─────────────────────────────────────────────

local HIDDEN_LINE = L["An upgrade for you: nobody is offered it unless you choose to. Offer shows who it would help."]

-- The keep? rule: an upgrade for you whose Offer panel you have not opened this session (a
-- main-spec upgrade: an off-spec one never keeps a drop hidden, feedback-19 spec §3).
local function keepHidden(drop, revealed)
    return type(drop.me) == "table" and drop.me.verdict == "upgrade" and not revealed
end

--- How many members drop `drop` upgrades (MC.Candidates' upgrades).
--- @param drop table
--- @return number
function MC.UpgradeCount(drop) return #upgradesOf(MC.Candidates(drop)) end

--- The Trade column on your own drop: WindowCells.Trade's word alone (`Yes`, `Likely`: feedback-7
--- spec §2 dropped the count from the cell) and a tooltip line saying how many members it upgrades.
--- Not counted on a drop that cannot be traded, nor under the keep? rule (its tooltip says why).
--- @param drop table one of your drops
--- @param revealed boolean|nil its Offer panel was opened this session
--- @return table cell, with `state` and `upgrades` (nil when not counted)
function MC.OwnTrade(drop, revealed)
    local c = WC.Trade(drop)
    if c.state == nil or c.state == "no" then return c end
    if keepHidden(drop, revealed) then
        c.tip[#c.tip + 1] = HIDDEN_LINE
        return c
    end
    local n = MC.UpgradeCount(drop)
    c.upgrades = n
    if n > 0 then
        c.tip[#c.tip + 1] = n == 1 and L["Upgrades 1 member: Offer shows who."]
            or L["Upgrades %d members: Offer shows who."]:format(n)
    end
    return c
end

-- One upgrade's grid row (feedback-7 spec §3): `Butterz  276  Bloodthorn Treads  ▲11`, the name in
-- its class color, the worn item's name in its quality color, the table's glyph and the gain
-- (unsigned) in green; `empty` (muted) when they wear nothing there. The worn item is the one the
-- drop is judged against, so of two (rings, trinkets, one-hand weapons) the lower, the one it would
-- replace (NS.Evaluate's baseline): a candidate's other worn item is not known here.
local function upgradeRow(e)
    local base = e.baseline
    local items = (base and num(base.ilvl)) and { base } or {}
    return TM.GearRows(TM.ClassName(e.short, e.classFile), items, #items == 0 and 1 or 0,
        TM.ArrowCell("upgrade", e.gain), base)[1]
end

--- The members your own drop upgrades, ranked by gain (MC.Candidates' entries), as `Upgrade for N`
--- counts them; none on a drop that cannot be traded, nor under the keep? rule. The detail card's
--- FOR THE GROUP lists them (feedback-20).
--- @param drop table one of your drops
--- @param revealed boolean|nil
--- @return table
function MC.Upgrades(drop, revealed)
    if tradeOf(drop).state == "no" or keepHidden(drop, revealed) then return {} end
    return upgradesOf(MC.Candidates(drop))
end

--- Them on your own drop (feedback-7 spec §2): `Upgrade for N`, green, N the members it upgrades;
--- `No upgrades`, muted, when it upgrades none. Its tooltip lists each upgrade ranked by gain (a grid,
--- a row each: NS.TipMarks.GearRows), else
--- says why there is none (nobody's whose gear was read, `n checking`, nobody else in the group). `Hidden`
--- under the keep? rule; a dash on a drop that cannot be traded.
--- @param drop table one of your drops
--- @param revealed boolean|nil
--- @param title string|nil the tooltip's title (the column's name; `Them` when nil)
--- @return table cell, with `upgrades` and `hidden`
function MC.Details(drop, revealed, title)
    title = title or L["Them"]
    if tradeOf(drop).state == "no" then
        return cell(DASH, "muted", title, L["Not tradeable, so nobody can be offered it."])
    end
    if keepHidden(drop, revealed) then
        local c = cell(L["Hidden"], "muted", title, HIDDEN_LINE)
        c.hidden = true
        return c
    end
    local list = MC.Candidates(drop)
    local ups = upgradesOf(list)
    local c = #ups > 0 and cell(L["Upgrade for %d"]:format(#ups), "good", title) or cell(L["No upgrades"], "muted", title)
    c.upgrades = #ups
    if #list == 0 then
        c.tip[2] = L["Nobody else in your group."]
        return c
    end
    if #ups > 0 then
        local rows = {}
        for i, e in ipairs(ups) do rows[i] = upgradeRow(e) end
        c.tip[#c.tip + 1] = TM.Grid(rows)
    end
    if #ups == 0 then c.tip[#c.tip + 1] = L["Not an upgrade for anyone whose gear was read."] end
    local checking = countChecking(list)
    if checking > 0 then c.tip[#c.tip + 1] = L["%d checking"]:format(checking) end
    return c
end

-- Your own drop's Offer button, by the furthest offer sent for it (WindowOwn's ToneStates). Every
-- state carries an icon (feedback-7 spec §1): `external-link` while it reads Offer, handing the item out
-- (feedback-10 spec §1).
local OWN_OFFER_LOOK = {
    ready = { text = L["Offer"], icon = "external-link" }, failed = { text = L["Offer"], icon = "external-link" },
    queued = { text = L["Queued"], icon = "clock", line = L["An offer of it is queued until chat allows it."] },
    sent = { text = L["Offered"], icon = "confirm", line = L["You offered it: the panel shows to whom."] },
    tradedAway = { text = L["Traded"], icon = "confirm", line = L["You traded it away."] },
}
MC.OWN_OFFER_LOOK = OWN_OFFER_LOOK   -- read by the suites: every state has an icon

--- Actions on your own drop (feedback-5 spec §2), in WindowCells.Ask's shape with `offer` true:
--- Offer, which opens the Offer panel (always clickable), labeled and toned by `toneState` (cyan
--- until an offer was sent, feedback-6 spec §2: `kind` "offer"; yellow once offered or queued,
--- green once given away); No action with the reason on a drop that cannot be traded
--- (WindowCells.NoAction, feedback-11 spec §1).
--- @param drop table one of your drops
--- @param toneState string|nil the offer half of the tone states (`ready`, `queued`, `sent`, `failed`,
---   `tradedAway`)
--- @return table { offered, offer = true, text, icon, enabled, tip, state, kind }
function MC.OwnOffer(drop, toneState)
    local t = tradeOf(drop)
    if t.state == "no" then
        local none = WC.NoAction(L["Not tradeable: %s"]:format(WC.TradeReason(t, L["you"])))
        none.offer = true
        return none
    end
    local s = OWN_OFFER_LOOK[toneState] and toneState or "ready"
    local l = OWN_OFFER_LOOK[s]
    local tip = { L["Offer"], L["Open the panel of who could use it, ranked by their gain, with Offer for each."] }
    tip[3] = l.line
    return { offered = true, offer = true, text = l.text, icon = l.icon, enabled = true, tip = tip, state = s, kind = "offer" }
end

-- ── the buttons ─────────────────────────────────────────────────────────────────────────────

-- One message button's look per ask state (modules/Asks.lua): label, catalog mark, clickable.
-- Every state carries a mark (feedback-7 spec §1); `readyIcon` is the one it wears while ready.
local function lookTable(ready, sent, readyIcon)
    return {
        ready  = { text = ready, icon = readyIcon, enabled = true },
        queued = { text = L["Queued"], icon = "clock", enabled = true },
        sent   = { text = sent, icon = "confirm", enabled = false },
        failed = { text = L["Retry"], icon = "reset", enabled = true },
    }
end

local OFFER_LOOK = lookTable(L["Offer"], L["Offered"], "external-link")     -- handing the item out
local ANNOUNCE_LOOK = lookTable(L["Announce"], L["Announced"], "speech-bubble") -- a post to the group
MC.OFFER_LOOK, MC.ANNOUNCE_LOOK = OFFER_LOOK, ANNOUNCE_LOOK   -- read by the suites: every state has an icon

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

--- The state an Offer or Announce button is toned by (feedback-4 spec §1; WindowCells.ActionTone): green
--- `tradedAway` once you traded the drop away, else the button's own state (`ready` for none).
--- @param outcome string|nil the drop's History outcome
--- @param state string|nil the button's ask state, or the furthest offer for the drop
--- @return string
function MC.ToneState(outcome, state)
    if outcome == "tradedAway" then return "tradedAway" end
    return state or "ready"
end

--- The Offer button of one candidate, by its ask state. While it reads Offer its `kind` is "offer"
--- (cyan, feedback-6 spec §2); as Retry it takes Retry's red.
--- @param state string|nil NS.Asks.StateOf's state
--- @param reason string|nil
--- @param who string the member's short name
--- @return table { text, icon, enabled, state, tip, kind }
function MC.OfferButton(state, reason, who)
    local b = look(OFFER_LOOK, state)
    b.tip = { offerTip(b.state, who, reason) }
    if b.state ~= "failed" then b.kind = "offer" end
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

-- ── the summary and Post my tradeables ──────────────────────────────────────────────────────

--- The Drops strip's summary line (board 04's footer; feedback-5 spec §3): how many of your drops
--- may be traded and the next countdown to run out.
--- @param drops table your own drops the tab lists
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
