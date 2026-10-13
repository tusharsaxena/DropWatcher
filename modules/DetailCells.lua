local _, NS = ...
-- modules/DetailCells.lua — what the detail card says (design spec §11.3, board 02): the item
-- header's chips, the For you and For the looter comparisons, the trade estimate box and the
-- actions, each with its reason tooltip. Nothing is ever blank: a value not known says `–` or `?`
-- and its tooltip says why.
--
-- PURE. Every composer takes the drop record (modules/LootFeed.lua's shape) and plain inputs (the
-- clock, the looter's inspect entry and spec name, the ask's state, the trade guard's answer) and
-- answers plain tables; nothing here reads a module, the client or a saved variable, so
-- test_detail_card drives each state case by case. The frame edge that paints them is
-- modules/DetailCard.lua. The verdict, trade and ask wording is modules/WindowCells.lua's, so the
-- card and the row it expands never disagree; on your own drop (feedback-5 spec §2) the Them row's
-- `(Details)` and the Offer in place of Ask are modules/MineCells.lua's, as the row's are.
--
--   chip = { text, tone?, tip = { title, lines... } }
--   side = { title, verdict = { text, tone, tip }, rows = { { key, label, text, tone, tip, link } } }
--   box  = { chip = { text, tone }, text, meta, tip }
--   act  = { key, text, icon, enabled, tip }

NS.DetailCells = NS.DetailCells or {}
local DC = NS.DetailCells
local C  = NS.Constants
local L  = NS.L
local WC = NS.WindowCells
local MC = NS.MineCells

local floor, abs = math.floor, math.abs

local DASH = "–"

-- The stats a chip or a stat line names, by C_Item.GetItemStats key.
local PRIMARY = {
    ITEM_MOD_STRENGTH_SHORT = L["Str"], ITEM_MOD_AGILITY_SHORT = L["Agi"], ITEM_MOD_INTELLECT_SHORT = L["Int"],
}
local PRIMARY_ORDER = { "ITEM_MOD_STRENGTH_SHORT", "ITEM_MOD_AGILITY_SHORT", "ITEM_MOD_INTELLECT_SHORT" }
local SECONDARY = {
    ITEM_MOD_CRIT_RATING_SHORT = L["Crit"], ITEM_MOD_HASTE_RATING_SHORT = L["Haste"],
    ITEM_MOD_MASTERY_RATING_SHORT = L["Mastery"], ITEM_MOD_VERSATILITY = L["Vers"],
}
local SECONDARY_ORDER = {
    "ITEM_MOD_CRIT_RATING_SHORT", "ITEM_MOD_HASTE_RATING_SHORT", "ITEM_MOD_MASTERY_RATING_SHORT", "ITEM_MOD_VERSATILITY",
}
local TERTIARY = {
    ITEM_MOD_CR_LIFESTEAL_SHORT = L["Leech"], ITEM_MOD_CR_SPEED_SHORT = L["Speed"],
    ITEM_MOD_CR_AVOIDANCE_SHORT = L["Avoidance"], ITEM_MOD_CR_STURDINESS_SHORT = L["Indestructible"],
}
local TERTIARY_ORDER = {
    "ITEM_MOD_CR_LIFESTEAL_SHORT", "ITEM_MOD_CR_SPEED_SHORT", "ITEM_MOD_CR_AVOIDANCE_SHORT", "ITEM_MOD_CR_STURDINESS_SHORT",
}


local BIND_CHIP = {
    [C.BIND.ON_ACQUIRE] = { L["BoP"], L["Bind on pickup: it binds to whoever loots it."] },
    [C.BIND.ON_EQUIP] = { L["BoE"], L["Bind on equip: tradeable until someone wears it."] },
    [C.BIND.ON_USE] = { L["BoU"], L["Bind on use: tradeable until someone uses it."] },
    [C.BIND.QUEST] = { L["Quest"], L["A quest item."] },
}

local VERDICT_CHIP = {
    upgrade = L["UPGRADE"], sidegrade = L["SIDEGRADE"], downgrade = L["DOWNGRADE"],
    cantUse = L["CAN'T USE"], doesntWant = L["DOESN'T WANT"], unknown = L["UNKNOWN"],
}

local TRADE_CHIP = {
    yes = L["TRADEABLE"], likely = L["LIKELY TRADEABLE"], unknown = L["TRADE UNKNOWN"], no = L["NOT TRADEABLE"],
}
local TRADE_TONE = { yes = "good", likely = "good", unknown = "muted", no = "bad" }
local RULE_WORD = { personal = L["personal loot"], group = L["group loot"], legacy = L["legacy loot"] }
local BASIS_WORD = { bind = L["the item's bind"], rule = L["the content's rule"], inspect = L["inspect"], timer = L["your bag's timer"] }

-- ── small helpers ───────────────────────────────────────────────────────────────────────────

local function num(v)
    if type(v) == "number" and v == v then return v end
    return nil
end

local function round(n) return floor(n + 0.5) end

local function facts(drop) return type(drop.facts) == "table" and drop.facts or {} end

local function looterName(drop)
    local who = type(drop.looter) == "table" and drop.looter or {}
    return WC.ShortName(who.name)
end

local function chip(text, title, ...)
    return { text = text, tip = { title, ... } }
end

local function row(key, label, text, tone, title, ...)
    return { key = key, label = label, text = text, tone = tone or "plain", tip = { title, ... } }
end

-- ── the header's chips ──────────────────────────────────────────────────────────────────────

local function slotChip(f)
    local label = WC.SlotLabel(f.equipLoc)
    if not label then return chip(DASH, L["Slot"], L["Not an item that is worn, or its details have not loaded."]) end
    return chip(label, L["Slot"], L["Worn in the %s slot."]:format(label))
end

-- The Type column's answer as a chip (feedback-4 spec §3: Cloth … Plate, Jewelry, Trinkets, Cloak,
-- Weapons); none when the type is not known.
local function armorChip(f)
    local t = WC.ArmorType({ facts = f })
    if not t.known then return nil end
    return chip(t.text, L["Type"], t.tip[2])
end

local function bindChip(f)
    if f.warbound then
        return chip(L["Warbound"], L["Bind"], L["Warbound: it binds to the account and can't be traded."])
    end
    local b = BIND_CHIP[f.bindType]
    if not b then return nil end
    return chip(b[1], L["Bind"], b[2])
end

-- `Hero 2/6`, or nil for no track.
local function trackText(tr)
    if type(tr) ~= "table" or not tr.name then return nil end
    return ("%s %s/%s"):format(tr.name, tostring(tr.rank or "?"), tostring(tr.max or "?"))
end

local function trackChip(f)
    local text, ilvl = trackText(f.track), num(f.ilvl)
    if not text then
        if not ilvl then return nil end
        return chip(tostring(ilvl), L["Item level %d"]:format(ilvl), L["No upgrade track."])
    end
    if ilvl then text = ("%s · %d"):format(text, ilvl) end
    return chip(text, L["Upgrade track"], L["The upgrade track and rank, then the item level."])
end

-- The look: `New look` when you have not collected the appearance, `Look known` when you have,
-- nothing when it is not known or the item has none (design spec §4, transmog-known).
local function transmogChip(f)
    if f.transmogKnown == false then
        local c = chip(L["New look"], L["Transmog"], L["You have not collected this item's appearance."])
        c.tone = "good"
        return c
    end
    if f.transmogKnown == true then
        local c = chip(L["Look known"], L["Transmog"], L["You have already collected this item's appearance."])
        c.tone = "muted"
        return c
    end
    return nil
end

local function primaryChip(stats)
    local names = {}
    for _, key in ipairs(PRIMARY_ORDER) do
        if num(stats[key]) then names[#names + 1] = PRIMARY[key] end
    end
    if #names == 0 then return nil end
    return chip(table.concat(names, "/"), L["Primary stat"], L["The primary stat it carries: a spec of another primary stat can't use it."])
end

local function hasSocket(stats)
    for key, v in pairs(stats) do
        if type(key) == "string" and key:find("^EMPTY_SOCKET_") and num(v) then return true end
    end
    return false
end

local function extraChips(stats, out)
    if hasSocket(stats) then out[#out + 1] = chip(L["Socket"], L["Socket"], L["It has a gem socket."]) end
    for _, key in ipairs(TERTIARY_ORDER) do
        if num(stats[key]) then
            out[#out + 1] = chip(TERTIARY[key], L["Tertiary stat"], L["It carries %s."]:format(TERTIARY[key]))
        end
    end
end

--- The item header's chips (board 02, callout 1): slot, armor type, bind, track and rank, the look
--- (transmog), primary stat, socket and tertiary stats. A chip with nothing to say is left out; the
--- slot always shows.
--- @param drop table
--- @return table list of chips
function DC.Chips(drop)
    local f = facts(drop)
    local stats = type(f.stats) == "table" and f.stats or {}
    local out = { slotChip(f) }
    for _, fn in ipairs({ armorChip, bindChip, trackChip, transmogChip }) do
        local c = fn(f)
        if c then out[#out + 1] = c end
    end
    out[#out + 1] = primaryChip(stats)
    extraChips(stats, out)
    return out
end

-- ── the comparison rows ─────────────────────────────────────────────────────────────────────

local function baseOf(eval)
    return type(eval) == "table" and type(eval.baseline) == "table" and eval.baseline or nil
end

local function emptySlot(eval)
    if type(eval) ~= "table" or type(eval.reasons) ~= "table" then return false end
    for _, r in ipairs(eval.reasons) do if r.key == "emptySlot" then return true end end
    return false
end

-- `mine`: the item is yours, so its slot is kept for the real tooltip (`wornSlot`, DW-80).
local function replacesRow(eval, whose, mine)
    local base = baseOf(eval)
    if base then
        local name = WC.ItemName(base.link) or "?"
        local r = row("replaces", L["Replaces"], ("%s · %s"):format(name, tostring(num(base.ilvl) or "?")), "plain",
            L["Replaces"], L["The item %s would take off for it: the lower of two where there are two."]:format(whose))
        r.link = base.link
        r.wornSlot = mine and num(base.slot) or nil
        return r
    end
    if emptySlot(eval) then
        return row("replaces", L["Replaces"], L["Empty slot"], "good", L["Replaces"], L["The slot is empty, so anything is an upgrade."])
    end
    return row("replaces", L["Replaces"], DASH, "muted", L["Replaces"], L["The item it would replace has not been read."])
end

local function ilvlRow(eval, ilvl, tone)
    local d = type(eval) == "table" and num(eval.ilvlDelta) or nil
    if not (d and ilvl) then
        return row("ilvl", L["Item level"], ilvl and tostring(ilvl) or "?", "muted", L["Item level"],
            L["No item-level change: nothing to compare with yet."])
    end
    local from = round(ilvl - d)
    return row("ilvl", L["Item level"], ("%d → %d · %s"):format(from, ilvl, WC.Signed(d)), tone, L["Item level"],
        L["%d against %d: %s."]:format(ilvl, from, WC.Signed(d)))
end

local TRACK_GLYPH = { [1] = WC.GLYPH.upgrade, [0] = WC.GLYPH.sidegrade, [-1] = WC.GLYPH.downgrade }

-- Shown even within one track (board 02, callout 2): a rank change is still a change.
local function missingTrack(to)
    if to then return row("track", L["Track"], to, "muted", L["Track"], L["The worn item's track was not read."]) end
    return row("track", L["Track"], DASH, "muted", L["Track"], L["The drop has no upgrade track."])
end

local function trackRow(eval, dropTrack)
    local base = baseOf(eval)
    local to, from = trackText(dropTrack), trackText(base and base.track)
    if not (to and from) then return missingTrack(to) end
    local td = type(eval.trackDelta) == "table" and eval.trackDelta or nil
    if not td then
        return row("track", L["Track"], ("%s → %s"):format(from, to), "plain", L["Track"],
            L["The tracks could not be ranked against each other."])
    end
    return row("track", L["Track"], ("%s → %s %s"):format(from, to, TRACK_GLYPH[td.sign] or ""), "plain", L["Track"],
        L["The track it moves to, rank included."])
end

--- The secondary-stat change from `base` to `item`, the largest first: `+130 Haste -119 Mastery`,
--- or nil when neither carries a secondary stat.
--- @param item table|nil the drop's facts.stats
--- @param base table|nil the replaced item's facts.stats
--- @return string|nil
function DC.StatChange(item, base)
    item, base = type(item) == "table" and item or {}, type(base) == "table" and base or {}
    local parts = {}
    for _, key in ipairs(SECONDARY_ORDER) do
        local d = (num(item[key]) or 0) - (num(base[key]) or 0)
        if d ~= 0 then parts[#parts + 1] = { d = d, label = SECONDARY[key] } end
    end
    if #parts == 0 then return nil end
    table.sort(parts, function(a, b) return abs(a.d) > abs(b.d) end)
    local out = {}
    for _, p in ipairs(parts) do out[#out + 1] = ("%s %s"):format(WC.Signed(p.d), p.label) end
    return table.concat(out, " ")
end

local function statsRow(eval, dropStats)
    local base = baseOf(eval)
    if not base then
        return row("stats", L["Stats"], DASH, "muted", L["Stats"], L["No stat change: the item it would replace has not been read."])
    end
    local text = DC.StatChange(dropStats, base.stats)
    if not text then return row("stats", L["Stats"], L["no change"], "plain", L["Stats"], L["The same secondary stats."]) end
    return row("stats", L["Stats"], text, "plain", L["Stats"], L["The secondary stats it gains and loses."])
end

-- The score line by the scorer in use (modules/Scoring.lua's InUse): its label, and why there is
-- no score when there is none.
local SCORER_LINE = {
    pawn    = { label = L["Pawn"], none = L["Pawn has not scored it yet."] },
    weights = { label = L["Weights"],
                none = L["Your weights for this specialization score nothing yet: set them in Settings, Comparison."] },
    none    = { label = L["Score"], none = L["No scorer is in use: the verdict uses item level alone."] },
}

local function scoreRow(eval, scorer)
    if scorer == true then scorer = "pawn" end
    local line = SCORER_LINE[scorer] or SCORER_LINE.none
    local sd = type(eval) == "table" and num(eval.scoreDelta) or nil
    if sd then
        return row("score", line.label, ("%+.1f"):format(sd), sd >= 0 and "good" or "bad", L["Score"],
            L["The scorer's change for your spec."])
    end
    return row("score", line.label, DASH, "muted", L["Score"], line.none)
end

local function specRow(drop, inspect, specName, now)
    local who = looterName(drop)
    local spec = specName or L["spec unknown"]
    local at = type(inspect) == "table" and num(inspect.at) or nil
    if not (at and num(now)) then
        return row("spec", L["Spec"], spec, "muted", L["Spec"], L["%s has not been inspected yet."]:format(who))
    end
    local age = WC.Duration(now - at)
    return row("spec", L["Spec"], L["%s · inspected %s ago"]:format(spec, age), "plain", L["Spec"],
        L["%s's spec and gear were read %s ago."]:format(who, age))
end

local function verdictChip(cell)
    local glyph = cell.glyph and (cell.glyph .. " ") or ""   -- the arrow first (feedback-4 spec §0)
    return { text = glyph .. (VERDICT_CHIP[cell.verdict] or VERDICT_CHIP.unknown), tone = cell.tone, tip = cell.tip }
end

local function sideRows(eval, f, tone, whose, mine)
    local ilvl = num(f.ilvl)
    return { replacesRow(eval, whose, mine), ilvlRow(eval, ilvl, tone), trackRow(eval, f.track), statsRow(eval, f.stats) }
end

--- The For you column (board 02, callouts 2 and 3).
--- @param drop table
--- @param scorer string|boolean the scorer in use, "pawn" | "weights" | "none" (true reads "pawn")
--- @return table side
function DC.ForYou(drop, scorer)
    local cell = WC.Me(drop)
    local rows = sideRows(drop.me, facts(drop), cell.tone, L["you"], true)
    rows[#rows + 1] = scoreRow(drop.me, scorer)
    return { title = L["FOR YOU"], verdict = verdictChip(cell), rows = rows }
end

-- Your own drop's side (feedback-5 spec §2): the looter is you, and the Them row reads (Details)
-- with every member it upgrades in its tooltip (MineCells.Multiple), as the row's Them cell does.
local function ownSide(drop, revealed)
    local m = MC.Multiple(drop, revealed, L["Them"])
    local tip = m.tip
    return { title = L["FOR THE GROUP"], verdict = { text = m.text, tone = m.tone, tip = tip },
        rows = { row("mine", L["Looter"], L["you"], "muted", L["Looter"], L["Your own drop: Offer shows who it would help."]),
            { key = "them", label = L["Them"], text = m.text, tone = m.tone, tip = tip } } }
end

--- The For the looter column (board 02, callout 4): the same comparison against their inspected
--- gear, and their spec with the read's age. On your own drop: the Them row's `(Details)`.
--- @param drop table
--- @param inspect table|nil the looter's inspect entry (NS.Inspect.Get)
--- @param specName string|nil the looter's spec, in words
--- @param now number|nil GetTime()
--- @param revealed boolean|nil your own drop's Offer panel was opened this session (WindowOwn)
--- @return table side
function DC.ForLooter(drop, inspect, specName, now, revealed)
    if drop.isMine then return ownSide(drop, revealed) end
    local who = looterName(drop)
    local title = L["FOR %s (LOOTER)"]:format(who:upper())
    local cell = WC.Them(drop, now)
    local rows = sideRows(drop.them, facts(drop), cell.tone, who)
    rows[#rows + 1] = specRow(drop, inspect, specName, now)
    return { title = title, verdict = verdictChip(cell), rows = rows }
end

-- ── the trade box ───────────────────────────────────────────────────────────────────────────

local function metaLine(t, situationLabel)
    local parts = {}
    local rule = RULE_WORD[t.rule]
    if rule then
        parts[#parts + 1] = situationLabel and L["Rule: %s, %s"]:format(rule, situationLabel) or L["Rule: %s"]:format(rule)
    end
    local basis = BASIS_WORD[t.basis]
    if basis then
        local age = num(t.age)
        parts[#parts + 1] = age and L["Basis: %s %s ago"]:format(basis, WC.Duration(age)) or L["Basis: %s"]:format(basis)
    end
    if #parts == 0 then return L["Not estimated yet."] end
    return table.concat(parts, " · ")
end

--- The trade estimate box (board 02, callout 5): the state, the reason in plain words, the rule in
--- force and how fresh the data is.
--- @param drop table
--- @param situationLabel string|nil the drop's situation, in words
--- @return table box
function DC.TradeBox(drop, situationLabel)
    local t = drop.trade
    local cell = WC.Trade(drop)
    if type(t) ~= "table" or not TRADE_CHIP[t.state] then
        return { chip = { text = TRADE_CHIP.unknown, tone = "muted" }, text = L["Not estimated yet."],
            meta = L["The estimate is made once the item's details load."], tip = cell.tip }
    end
    local tip = { cell.tip[1], L["Another player's drop can only be estimated: the game says for sure only to them."] }
    if drop.isMine then tip[2] = L["Your own drop: the estimate follows your bag's trade timer."] end
    return { chip = { text = TRADE_CHIP[t.state], tone = TRADE_TONE[t.state] },
        text = WC.TradeReason(t, looterName(drop)), meta = metaLine(t, situationLabel), tip = tip }
end

-- ── the actions ─────────────────────────────────────────────────────────────────────────────

local function act(key, text, icon, enabled, title, ...)
    return { key = key, text = text, icon = icon, enabled = enabled and true or false, tip = { title, ... } }
end

-- Your own drop's Offer in the Ask's place (feedback-5 spec §2): it opens the Offer panel.
local function offerAction(o)
    local a = act("ask", o.offered and o.text or L["Offer"], "chat", o.offered, unpack(o.tip))
    a.state, a.offer = o.state, true
    return a
end

local function askAction(drop, ask)
    local who = looterName(drop)
    if not ask.offered then return act("ask", L["Ask"], "chat", false, L["Ask"], ask.tip[2]) end
    local text = ask.state == "ready" and L["Ask %s"]:format(who) or ask.text
    local a = act("ask", text, "chat", ask.enabled, unpack(ask.tip))
    a.state = ask.state
    return a
end

local EDITABLE = { ready = true, failed = true }

local function editAction(ask)
    local title = L["Edit message"]
    if not ask.offered then return act("edit", title, "edit", false, title, ask.tip[2]) end
    if not EDITABLE[ask.state] then
        return act("edit", title, "edit", false, title, L["The ask is already %s."]:format(ask.text:lower()))
    end
    return act("edit", title, "edit", true, title, L["Edit the ask before it is sent: the template, filled in, in a box you can change."])
end

local function linkAction(drop)
    local title = L["Link in chat"]
    if type(drop.link) ~= "string" then return act("link", title, "link-intact", false, title, L["The item's link is not known."]) end
    return act("link", title, "link-intact", true, title, L["Put the item's link in the chat box."])
end

local RETRY_BUSY = { pending = true, combatParked = true }
local RETRY_GOOD = { fresh = true, cached = true }

-- The age of a read the broker still counts good (it would not inspect again), or nil.
local function goodReadAge(inspect, now)
    if type(inspect) ~= "table" or not RETRY_GOOD[inspect.status] or inspect.stale then return nil end
    local at = num(inspect.at)
    return at and num(now) and now - at or nil
end

-- Why a retry would do nothing, or nil when it would queue the looter.
local function noRetryReason(drop, inspect, now)
    if drop.isMine then return L["Your own drop: your gear is always read."] end
    local guid = type(drop.looter) == "table" and drop.looter.guid or nil
    if not guid then return L["The looter is not known well enough to inspect."] end
    if type(inspect) == "table" and RETRY_BUSY[inspect.status] then return L["An inspect of them is already queued."] end
    local age = goodReadAge(inspect, now)
    if age then return L["Their gear was read %s ago; it is read again when it changes or grows old."]:format(WC.Duration(age)) end
    return nil
end

local function retryAction(drop, inspect, now)
    local title = L["Retry inspect"]
    local why = noRetryReason(drop, inspect, now)
    if why then return act("retry", title, "reset", false, title, why) end
    return act("retry", title, "reset", true, title, L["Inspect %s again now, ahead of the warm-up queue."]:format(looterName(drop)))
end

-- The disabled Trade button's short reason (board 02: `Trade · out of range`).
local TRADE_SHORT = {
    combat = L["in combat"], range = L["out of range"], offline = L["offline"], noTarget = L["not in group"],
    self = L["your own"], stoodDown = L["disabled"], noApi = L["unavailable"],
}

local function tradeAction(drop, trade)
    local title = L["Trade"]
    if drop.isMine then return act("trade", title, "transfer", false, title, L["Your own drop: Offer has a Trade button for each member."]) end
    if type(drop.trade) == "table" and drop.trade.state == "no" then
        return act("trade", L["Trade · can't"], "transfer", false, title, L["Its looter can't trade it."])
    end
    trade = type(trade) == "table" and trade or {}
    if not trade.ok then
        local text = TRADE_SHORT[trade.reason] and L["Trade · %s"]:format(TRADE_SHORT[trade.reason]) or title
        return act("trade", text, "transfer", false, title, trade.text or L["A trade can't be opened now."])
    end
    return act("trade", title, "transfer", true, title,
        L["Open a trade with %s, so they can put the item in."]:format(looterName(drop)))
end

--- The card's actions (board 02, callout 6), left to right: Ask (Offer on your own drop, with
--- `offer` set: feedback-5 spec §2), Edit message, Link in chat, Retry inspect and Trade. A
--- disabled one says why in its tooltip. Nothing hides a drop (feedback-4 spec §2).
--- @param drop table
--- @param ctx table { askState, askReason, inspect (the looter's entry), now, trade = { ok, reason, text },
--- transmogAsk (the `messages.transmogAsk` setting), offerTone (your own drop's: WindowOwn.ToneStates) }
--- @return table list of actions
function DC.Actions(drop, ctx)
    ctx = type(ctx) == "table" and ctx or {}
    local ask = WC.Ask(drop, ctx.askState, ctx.askReason, ctx.transmogAsk)
    local first = drop.isMine and offerAction(MC.OwnOffer(drop, ctx.offerTone)) or askAction(drop, ask)
    return {
        first, editAction(ask), linkAction(drop),
        retryAction(drop, ctx.inspect, ctx.now), tradeAction(drop, ctx.trade),
    }
end
