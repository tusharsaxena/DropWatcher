local _, NS = ...
-- modules/HistoryCard.lua — the History tab's detail card (feedback-15 spec §4, DW-Q4): a kept entry
-- expanded under its row, or under its compact card, drawn from the stored snapshot in the Drops
-- card's visual language (NS.DetailCard's frame, chips, boxes and buttons).
--
-- WHAT IT HOLDS. A history entry keeps no stats, baseline, reasons, candidates or trade rule
-- (modules/History.lua's entry shape), so the card says what it does keep, top to bottom:
--
--   header          the item button and the name in its quality color; chips for slot, armor type,
--                   item level and the outcome in its tone (WindowHistory.Outcome's)
--   FOR YOU         the verdict then (the title marks it AT THE TIME), the item-level and score
--                   deltas
--   FOR THE GROUP   the looter (class color, ` [YOU]` on your own drop), the Them verdict and its
--                   deltas; on your own drop who it was an upgrade for, which the snapshot does not
--                   hold, so the Them line says it is not kept
--   the trade box   the recorded estimate and its reason in the Drops card's words
--                   (NS.DetailCells.TradeBox over the snapshot: the basis, never a rule or an age)
--   WHEN AND WHERE  the time (and how long ago), the kept group's place (instance, boss,
--                   difficulty: NS.GroupPlace.Parts, as its header) and the character that saw it
--   actions         Link in chat; Mark declined or Clear declined (the row's right-click menu
--                   stays); Show in Drops while the drop is also live in the feed (History.DropOf):
--                   it selects the Drops tab, opens the drop's header and expands its card
--                   (NS.WindowGroup.Reveal). A button that cannot act is off, with why.
--
-- Side by side in the full table (For you beside For the group, the trade box beside When and
-- where), stacked in the compact layout (each box the card's width, the actions flowed into lines:
-- DetailCard.FlowActions), as the Drops card is.
--
-- THE SPLIT. HC.Model(drop, ctx) is pure: WindowHistory.AsDrop's record (with its kept `group`) and
-- the repaint's plain context in, DetailCells' shapes out (chip, side, box, act); test_history_card
-- drives it. HC.Build(content, stacked) builds the frame once per pane, HC.Paint(card, drop, width,
-- ctx) paints it on each repaint while a row is open and answers its height. Which entry is open is
-- WindowHistory's (NS.State.windowHistory.expanded: the entry itself, since a kept entry has no id
-- that lasts across repaints).

NS.HistoryCard = NS.HistoryCard or {}
local HC  = NS.HistoryCard
local K   = NS.Constants.WINDOW
local L   = NS.L
local WC  = NS.WindowCells
local DC  = NS.DetailCells
local TM  = NS.TipMarks

local max, floor = math.max, math.floor

local DASH = "–"
local P = K.CARD_PAD

HC.ACTION_KEYS = { "link", "declined", "show" }
HC.ACTION_W = { link = 92, declined = 112, show = 112 }
HC.SIDE_H = 24 + 3 * K.SIDE_ROW_H + 8    -- a box of three lines (DetailCard's side box, shorter)
HC.ACTION_GAP, HC.ACTION_LINE_GAP = 6, 4
-- The full card: the header, the two rows of boxes side by side, the actions.
HC.CARD_H = P + K.CARD_ICON + P + HC.SIDE_H + P + HC.SIDE_H + P + K.ACTION_H + P

-- An outcome a completed trade settled stands (History.SetDeclined refuses it).
local SETTLED = { received = true, tradedAway = true }

-- ── the words (pure) ────────────────────────────────────────────────────────────────────────

local function num(v)
    if type(v) == "number" and v == v then return v end
    return nil
end

local function row(key, label, text, tone, title, ...)
    return { key = key, label = label, text = text, tone = tone or "plain", tip = { title, ... } }
end

local function chipOf(c, tone) return { text = c.text, tone = tone or c.tone, tip = c.tip } end

local function chips(drop)
    local out = { chipOf(WC.Slot(drop)) }
    local kind = WC.ArmorType(drop)
    if kind.known then out[#out + 1] = chipOf(kind) end
    local ilvl = WC.Ilvl(drop)
    local text = num(drop.facts.ilvl) and L["ilvl %s"]:format(ilvl.text) or ilvl.text
    out[#out + 1] = { text = text, tone = ilvl.tone, tip = ilvl.tip }
    -- The Outcome cell's tooltip without its row-menu hint: the card's own buttons mark declined.
    local outcome = NS.WindowHistory.Outcome(drop)
    out[#out + 1] = { text = outcome.text, tone = outcome.tone, tip = { outcome.tip[1], outcome.tip[2] } }
    return out
end

-- The item-level and score deltas kept with a verdict, or a dash saying nothing was kept.
local function deltaRows(eval, tone)
    local d = type(eval) == "table" and num(eval.ilvlDelta) or nil
    local sd = type(eval) == "table" and num(eval.scoreDelta) or nil
    local ilvl = d and row("ilvl", L["Item level"], WC.Signed(d), tone, L["Item level"],
            TM.Row(L["Change"], WC.Signed(d), tone), TM.Row(L["Against"], L["what was worn then"]))
        or row("ilvl", L["Item level"], DASH, "muted", L["Item level"], TM.Row(L["Change"], L["not kept"]))
    local score = sd and row("score", L["Score"], ("%+.1f"):format(sd), sd >= 0 and "good" or "bad", L["Score"],
            TM.Row(L["Change"], ("%+.1f"):format(sd), sd >= 0 and "good" or "bad"), TM.Row(L["As of"], L["then"]))
        or row("score", L["Score"], DASH, "muted", L["Score"], TM.Row(L["Change"], L["not kept"]))
    return { ilvl, score }
end

-- An off-spec verdict (feedback-19 spec §1): its chip, a Spec row and its own deltas.
local function forYou(drop, classFile)
    local cell = WC.Me(drop, classFile)
    local off = NS.OffSpec.Of(drop.me)
    local rows = deltaRows(off or drop.me, cell.tone)
    if off then table.insert(rows, 1, NS.OffSpecCells.SpecRow(off)) end
    return { title = L["FOR YOU · AT THE TIME"], verdict = DC.VerdictChip(cell), rows = rows }
end

local function looterRow(drop)
    local lc = WC.Looter(drop)
    local r = row("looter", L["Looter"], lc.text, "plain", unpack(lc.tip))
    r.classFile, r.you = lc.classFile, lc.you
    return r
end

-- Your own drop: the looter is you; who it was an upgrade for is not in the snapshot.
local function ownGroup(drop)
    local them = row("them", L["Them"], DASH, "muted", L["Them"],
        TM.Row(L["Who it upgraded"], L["not kept in the history"]))
    return { title = L["FOR THE GROUP"], verdict = { text = DASH, tone = "muted", tip = them.tip },
        rows = { looterRow(drop), them } }
end

local function forGroup(drop)
    if drop.isMine then return ownGroup(drop) end
    local cell = NS.WindowHistory.ThemVerdict(drop)
    local rows = deltaRows(drop.them, cell.tone)
    table.insert(rows, 1, looterRow(drop))
    return { title = L["FOR THE GROUP"], verdict = DC.VerdictChip(cell), rows = rows }
end

local function whenRow(drop, ctx)
    local at = num(drop.at)
    if not (at and ctx.dateFn) then return row("when", L["When"], DASH, "muted", L["When"], TM.Row(L["Dropped"], L["not kept"])) end
    local date = ctx.dateFn("%Y-%m-%d %H:%M", at)
    local ago = num(ctx.nowEpoch) and NS.WindowHistory.Ago(ctx.nowEpoch - at) or nil
    return row("when", L["When"], ago and ("%s · %s"):format(date, ago) or date, "plain", L["When"],
        TM.Row(L["Dropped"], date), TM.Row(L["That is"], ago))
end

local function whereRow(group, situationLabel)
    if type(group) ~= "table" then
        return row("where", L["Where"], DASH, "muted", L["Where"], TM.Row(L["Place"], L["kept before it was recorded"]))
    end
    local text = table.concat(NS.GroupPlace.Parts(group, situationLabel, NS.GroupPlace.ShortNames()), " · ")
    return row("where", L["Where"], text, "plain", L["Where"], TM.Row(L["Place"], text))
end

-- The character that saw it: the entry's own, else its group's recorder.
local function seenByRow(drop)
    local key, class = drop.seenBy or nil, drop.seenByClass or nil
    if not key and type(drop.group) == "table" then key, class = NS.GroupPlace.Recorder(drop.group) end
    if type(key) ~= "string" then
        return row("seenBy", L["Seen by"], DASH, "muted", L["Seen by"], TM.Row(L["Character"], L["kept before it was recorded"]))
    end
    local r = row("seenBy", L["Seen by"], WC.ShortName(key), "plain", L["Seen by"], TM.Row(L["Character"], key))
    r.classFile = class or nil
    return r
end

local function whenWhere(drop, ctx)
    return { title = L["WHEN AND WHERE"],
        rows = { whenRow(drop, ctx), whereRow(drop.group, ctx.situationLabel), seenByRow(drop) } }
end

local function act(key, text, icon, enabled, title, ...)
    return { key = key, text = text, icon = icon, enabled = enabled and true or false, tip = { title, ... } }
end

local function linkAction(drop)
    local title = L["Link in chat"]
    if type(drop.link) ~= "string" then return act("link", title, "link-intact", false, title, TM.Row(L["Link"], L["not known"])) end
    return act("link", title, "link-intact", true, title, TM.Row(L["Puts"], L["the item's link in the chat box"]))
end

local function declinedAction(drop)
    if drop.outcome == "declined" then
        local title = L["Clear declined"]
        return act("declined", title, "reset", true, title, TM.Row(L["Puts back"], L["the outcome before declined"]))
    end
    local title = L["Mark declined"]
    if SETTLED[drop.outcome] then
        return act("declined", title, "ban", false, title, TM.Row(L["Settled by"], L["a completed trade"]),
            TM.Row(L["Outcome"], L["kept"]))
    end
    return act("declined", title, "ban", true, title, TM.Row(L["Means"], L["you passed on it"]),
        TM.Hint(L["The row's right-click menu does the same."]))
end

local function showAction(liveId)
    local title = L["Show in Drops"]
    if liveId == nil then
        return act("show", title, "arrow-right", false, title, TM.Row(L["In Drops"], L["no"]),
            TM.Row(L["Drops holds"], L["this session's drops, until the feed is cleared"]))
    end
    return act("show", title, "arrow-right", true, title, TM.Row(L["Selects"], L["the Drops tab"]),
        TM.Row(L["Then"], L["opens its group and expands its card"]))
end

--- The card's words for a kept entry (pure).
--- @param drop table WindowHistory.AsDrop's record, with its kept `group`
--- @param ctx table { nowEpoch = time(), dateFn = date, classFile (yours), situationLabel,
---   liveId (History.DropOf: the drop's id in the feed, or nil) }
--- @return table { chips, me, them, trade, where, actions }
function HC.Model(drop, ctx)
    ctx = type(ctx) == "table" and ctx or {}
    return {
        chips = chips(drop), me = forYou(drop, ctx.classFile), them = forGroup(drop),
        trade = DC.TradeBox(drop, ctx.situationLabel), where = whenWhere(drop, ctx),
        actions = { linkAction(drop), declinedAction(drop), showAction(ctx.liveId) },
    }
end

--- The stacked card's height at `width`: the header, the four boxes one under another, then the
--- actions' lines.
--- @param width number
--- @return number
function HC.StackedHeight(width)
    local _, lines = NS.DetailCard.FlowActions(width - 2 * P, HC.ACTION_KEYS, HC.ACTION_W)
    local boxes = 3 * HC.SIDE_H + K.TRADE_BOX_H + 4 * P
    return P + K.CARD_ICON + P + boxes + lines * K.ACTION_H + (lines - 1) * HC.ACTION_LINE_GAP + P
end

-- ── the frame ───────────────────────────────────────────────────────────────────────────────

--- Show the live drop `id` in the Drops tab: its header opened, its card expanded, the tab selected.
--- @param id any
function HC.ShowInDrops(id)
    if id ~= nil and NS.WindowGroup.Reveal(id) then NS.Window.SelectTab("group") end
end

local ON_CLICK = {
    link = function(b) if b.link then NS.Compat.InsertChatLink(b.link) end end,
    declined = function(b) NS.History.SetEntryDeclined(b.entry, b.on) end,
    show = function(b) HC.ShowInDrops(b.liveId) end,
}

local function buildActions(card)
    card.actions = {}
    local prev
    for _, key in ipairs(HC.ACTION_KEYS) do
        local b = NS.Window.TextButton(card, HC.ACTION_W[key], nil, "", ON_CLICK[key])
        b:SetHeight(K.ACTION_H)
        if prev then
            b:SetPoint("LEFT", prev, "RIGHT", HC.ACTION_GAP, 0)
        else
            b:SetPoint("BOTTOMLEFT", card, "BOTTOMLEFT", P, P)
        end
        b.key = key
        NS.Window.AttachTooltip(b, function() return unpack(b.tipLines or {}) end)
        card.actions[key] = b
        prev = b
    end
end

-- Side by side: For you | For the group, then the trade box | When and where.
local function placeSideBySide(card)
    local top = -(2 * P + K.CARD_ICON)
    card.me:SetPoint("TOPLEFT", card, "TOPLEFT", P, top)
    card.them:SetPoint("TOPRIGHT", card, "TOPRIGHT", -P, top)
    card.trade:SetPoint("TOPLEFT", card.me, "BOTTOMLEFT", 0, -P)
    card.where:SetPoint("TOPRIGHT", card.them, "BOTTOMRIGHT", 0, -P)
    card.trade:SetHeight(HC.SIDE_H)
end

-- Stacked: each box the card's width, one under another.
local function placeStacked(card)
    local top = -(2 * P + K.CARD_ICON)
    card.me:SetPoint("TOPLEFT", card, "TOPLEFT", P, top)
    card.me:SetPoint("TOPRIGHT", card, "TOPRIGHT", -P, top)
    local prev = card.me
    for _, box in ipairs({ card.them, card.trade, card.where }) do
        box:SetPoint("TOPLEFT", prev, "BOTTOMLEFT", 0, -P)
        box:SetPoint("TOPRIGHT", prev, "BOTTOMRIGHT", 0, -P)
        prev = box
    end
end

--- The card's frame, built once per pane inside `content` (the table's scroll child, or the compact
--- view's with `stacked`), hidden.
--- @param content table
--- @param stacked boolean|nil
--- @return table card
function HC.Build(content, stacked)
    local DCard = NS.DetailCard
    local card = DCard.Box(content)
    card:SetHeight(HC.CARD_H)
    card.stacked = stacked and true or nil
    DCard.BuildHeader(card)
    card.me, card.them, card.where = DCard.NewSide(card), DCard.NewSide(card), DCard.NewSide(card)
    for _, side in ipairs({ card.me, card.them, card.where }) do side:SetHeight(HC.SIDE_H) end
    DCard.BuildTrade(card)
    if card.stacked then placeStacked(card) else placeSideBySide(card) end
    buildActions(card)
    card:Hide()
    return card
end

local function qualityTone(fs, drop)
    local qc = type(ITEM_QUALITY_COLORS) == "table" and ITEM_QUALITY_COLORS[drop.facts.quality]
    if qc then fs:SetTextColor(qc.r, qc.g, qc.b) end
end

-- The item and its chips; a kept entry's item tooltip is its link's (no bag item to point at).
local function paintHeader(card, drop, list, width)
    NS.WindowGroup.SetItem(card.icon, type(drop.link) == "string" and drop.link or nil)
    card.name:SetText(WC.ItemName(drop.link) or "?")
    qualityTone(card.name, drop)
    card.nameTip.showItem = true
    for i, c in ipairs(card.chips) do
        local chip = list[i]
        c:SetShown(chip ~= nil)
        if chip then NS.DetailCard.PaintChip(c, chip) end
    end
    if card.stacked then NS.DetailCard.FitChips(card, width) end
end

local function placeStackedActions(card, width)
    local flow, lines = NS.DetailCard.FlowActions(width - 2 * P, HC.ACTION_KEYS, HC.ACTION_W)
    for key, at in pairs(flow) do
        local b = card.actions[key]
        b:ClearAllPoints()
        local up = (lines - 1 - at.line) * (K.ACTION_H + HC.ACTION_LINE_GAP)
        b:SetPoint("BOTTOMLEFT", card, "BOTTOMLEFT", P + at.x, P + up)
    end
end

local function paintActions(card, drop, list, liveId)
    local e = drop.entry
    for _, a in ipairs(list) do
        local b = card.actions[a.key]
        b.link, b.entry, b.liveId = drop.link, e, liveId
        b.on = type(e) == "table" and e.outcome ~= "declined"
        b.label:SetText(a.text)
        b.art:SetTexture(NS.Icon(a.icon))
        b:SetEnabled(a.enabled)
        b:SetAlpha(a.enabled and 1 or 0.5)
        b.tipLines = a.tip
        b.enabled = a.enabled
    end
end

--- Paint the card for a kept entry, `width` pixels wide; answers its height (HC.CARD_H, or the
--- stacked card's).
--- @param card table HC.Build's answer
--- @param drop table WindowHistory.AsDrop's record
--- @param width number
--- @param ctx table HC.Model's context
--- @return number height
function HC.Paint(card, drop, width, ctx)
    local DCard, m = NS.DetailCard, HC.Model(drop, ctx)
    card.entry = drop.entry
    local height = card.stacked and HC.StackedHeight(width) or HC.CARD_H
    card:SetSize(width, height)
    paintHeader(card, drop, m.chips, width)
    local sideW = max(floor((width - 3 * P) / 2), 120)
    if card.stacked then
        sideW = width - 2 * P
        placeStackedActions(card, width)
    else
        card.trade:SetWidth(sideW)
    end
    DCard.PaintSide(card.me, m.me, sideW)
    DCard.PaintSide(card.them, m.them, sideW)
    DCard.PaintSide(card.where, m.where, sideW)
    DCard.PaintTrade(card.trade, m.trade)
    paintActions(card, drop, m.actions, ctx and ctx.liveId)
    return height
end
