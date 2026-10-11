local _, NS = ...
-- modules/DetailCard.lua — the detail card (design spec §11.3, board 02): the expanded row of the
-- Group drops table, with the full reasoning behind the row's verdicts.
--
-- WHAT IT HOLDS, top to bottom: the item header (a real item button, the name in its quality color
-- and the chips: slot, armor type, bind, track and rank, primary stat, socket, tertiary stats); the
-- For you and For the looter boxes side by side (what it replaces, the item-level change, the track
-- change, the stat change, and Pawn's score for you or the looter's spec and the inspect's age, each
-- under a verdict chip); the trade estimate box (the state, the reason in plain words, the rule in
-- force and how fresh the data is); and the actions: Ask, Edit message, Link in chat, Retry inspect,
-- Trade (disabled with its reason) and Hide this item. Every line and chip has a reason tooltip.
--
-- THE SPLIT. What each part says is modules/DetailCells.lua's (pure); this file is the frame edge
-- that paints it. modules/WindowGroup.lua owns the expansion (which row is open, where the card
-- goes) and calls Build once per pane and Paint on every repaint while a row is open.
--
-- THE UI LISTENS. The card is repainted with the table, on the bus. It reads the looter's inspect
-- entry (NS.Inspect.Get), the ask's state (NS.Asks.StateOf), the message preview (NS.Asks.Preview),
-- the trade guard (NS.TradeHelper.CanTradeWith) and the client through NS.Compat (the spec's name,
-- Pawn's presence), all read-only. Its buttons go through the host handlers in core/DropWatcher.lua
-- (NS.PressAsk, NS.RetryInspect, NS.TradeWithLooter) and the table's own Dismiss; Link in chat is
-- Compat.InsertChatLink, as an item button's shift-click is.
--
-- THE EDIT MESSAGE BOX. Edit message opens a small skinned box over the window, prefilled with the
-- ask template filled in for this drop, with a byte counter against the chat limit, Send and
-- Cancel (design spec §9.2's edit-before-sending popup). Send asks through NS.PressAsk with the
-- edited text; Escape or Cancel closes it. One box, shared by every card, built on its first use.

NS.DetailCard = NS.DetailCard or {}
local DCard = NS.DetailCard
local DC    = NS.DetailCells
local K     = NS.Constants.WINDOW
local C     = NS.Constants
local L     = NS.L

local max, floor = math.max, math.floor

local MAX_CHIPS = 9
local MAX_SIDE_ROWS = 5
local ACTION_KEYS = { "ask", "edit", "link", "retry", "trade", "hide" }
local ACTION_W = { ask = 92, edit = 100, link = 92, retry = 96, trade = 124, hide = 104 }

local editor   -- the Edit message box, built on its first use

-- Why the box has nothing to send (NS.Asks.Preview's refusal reasons).
local EDIT_REFUSAL = {
    notInGroup = L["the looter is not in your group"], offline = L["the looter is offline"],
    self = L["that is your own drop"], noTarget = L["the looter is not known"], disabled = L["the addon is disabled"],
}

-- ── small painting helpers ──────────────────────────────────────────────────────────────────

local function setTone(fs, tone)
    local c = C.TONE[tone] or C.TONE.plain
    fs:SetTextColor(c.r, c.g, c.b)
end

local function tipOf(frame) return unpack(frame.tipLines or {}) end

local function attach(frame)
    NS.Window.AttachTooltip(frame, function() return tipOf(frame) end)
end

-- A string's drawn width, with an estimate where the client has not measured it yet.
local function textWidth(fs, text)
    local w = fs.GetStringWidth and fs:GetStringWidth()
    if type(w) ~= "number" or w <= 0 then w = #(text or "") * 6 end
    return w
end

local function box(parent)
    local f = CreateFrame("Frame", nil, parent, "BackdropTemplate")
    local S = NS.SKIN
    if f.SetBackdrop and S and S.bgFile then
        f:SetBackdrop({ bgFile = S.bgFile, edgeFile = S.edgeFile, edgeSize = S.edgeSize })
        f:SetBackdropColor(0.08, 0.08, 0.10, 0.9)
        f:SetBackdropBorderColor(unpack(S.innerBorder or S.border))
    end
    return f
end

-- A chip: a bordered label with a tooltip.
local function newChip(parent)
    local c = box(parent)
    c:SetHeight(K.CHIP_H)
    c.text = c:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    c.text:SetPoint("CENTER", c, "CENTER", 0, 0)
    attach(c)
    return c
end

local function paintChip(c, chip)
    c.text:SetText(chip.text)
    setTone(c.text, chip.tone)
    c.tipLines = chip.tip
    c:SetWidth(floor(textWidth(c.text, chip.text) + 12))
end

-- ── building: the header ────────────────────────────────────────────────────────────────────

local function buildHeader(card)
    local P = K.CARD_PAD
    card.icon = NS.WindowGroup.ItemButton(card, K.CARD_ICON)
    card.icon:SetPoint("TOPLEFT", card, "TOPLEFT", P, -P)
    card.name = card:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    card.name:SetPoint("TOPLEFT", card.icon, "TOPRIGHT", P, 0)
    card.name:SetJustifyH("LEFT")
    card.nameTip = CreateFrame("Frame", nil, card)
    card.nameTip:SetAllPoints(card.name)
    attach(card.nameTip)
    card.chips = {}
    for i = 1, MAX_CHIPS do
        local c = newChip(card)
        if i == 1 then
            c:SetPoint("BOTTOMLEFT", card.icon, "BOTTOMRIGHT", P, 0)
        else
            c:SetPoint("LEFT", card.chips[i - 1], "RIGHT", 4, 0)
        end
        card.chips[i] = c
    end
end

-- ── building: a comparison box ──────────────────────────────────────────────────────────────

local function newSideRow(side, i)
    local r = CreateFrame("Frame", nil, side)
    r:SetHeight(K.SIDE_ROW_H)
    r:SetPoint("TOPLEFT", side, "TOPLEFT", 10, -(24 + (i - 1) * K.SIDE_ROW_H))
    r:SetPoint("TOPRIGHT", side, "TOPRIGHT", -10, -(24 + (i - 1) * K.SIDE_ROW_H))
    r.label = r:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    r.label:SetPoint("LEFT", r, "LEFT", 0, 0)
    r.item = NS.WindowGroup.ItemButton(r, K.SIDE_ROW_H - 2)
    r.item:SetPoint("LEFT", r, "LEFT", K.SIDE_LABEL, 0)
    r.value = r:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    r.value:SetJustifyH("LEFT")
    r.value:SetWordWrap(false)
    attach(r)
    return r
end

local function newSide(card)
    local side = box(card)
    side:SetHeight(K.SIDE_H)
    side.title = side:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    side.title:SetPoint("TOPLEFT", side, "TOPLEFT", 10, -8)
    side.title:SetTextColor(C.IDLE.r, C.IDLE.g, C.IDLE.b)
    side.verdict = newChip(side)
    side.verdict:SetPoint("TOPRIGHT", side, "TOPRIGHT", -8, -5)
    side.rows = {}
    for i = 1, MAX_SIDE_ROWS do side.rows[i] = newSideRow(side, i) end
    return side
end

-- ── building: the trade box and the actions ─────────────────────────────────────────────────

local function buildTrade(card)
    local t = box(card)
    t:SetHeight(K.TRADE_BOX_H)
    t.chip = newChip(t)
    t.chip:SetPoint("TOPLEFT", t, "TOPLEFT", 10, -8)
    t.text = t:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    t.text:SetPoint("TOPLEFT", t.chip, "TOPRIGHT", 10, -2)
    t.text:SetPoint("RIGHT", t, "RIGHT", -10, 0)
    t.text:SetJustifyH("LEFT")
    t.meta = t:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    t.meta:SetPoint("TOPLEFT", t.text, "BOTTOMLEFT", 0, -3)
    t.meta:SetJustifyH("LEFT")
    attach(t)
    card.trade = t
end

local ON_CLICK = {
    ask   = function(b) NS.PressAsk(b.dropId) end,
    edit  = function(b) DCard.OpenEditor(b.dropId) end,
    link  = function(b) if b.link then NS.Compat.InsertChatLink(b.link) end end,
    retry = function(b) NS.RetryInspect(b.dropId) end,
    trade = function(b) NS.TradeWithLooter(b.dropId) end,
    hide  = function(b) NS.WindowGroup.Dismiss(b.dropId) end,
}

local function buildActions(card)
    card.actions = {}
    local prev
    for _, key in ipairs(ACTION_KEYS) do
        local b = NS.Window.TextButton(card, ACTION_W[key], nil, "", ON_CLICK[key])
        b:SetHeight(K.ACTION_H)
        if key == "hide" then
            b:SetPoint("BOTTOMRIGHT", card, "BOTTOMRIGHT", -K.CARD_PAD, K.CARD_PAD)
        elseif prev then
            b:SetPoint("LEFT", prev, "RIGHT", 6, 0)
        else
            b:SetPoint("BOTTOMLEFT", card, "BOTTOMLEFT", K.CARD_PAD, K.CARD_PAD)
        end
        b.key = key
        attach(b)
        card.actions[key] = b
        if key ~= "hide" then prev = b end
    end
end

--- The card's frame, built once per pane inside `content` (the table's scroll child), hidden.
--- @param content table
--- @return table card
function DCard.Build(content)
    local card = box(content)
    card:SetHeight(K.CARD_H)
    buildHeader(card)
    card.me, card.them = newSide(card), newSide(card)
    local P = K.CARD_PAD
    card.me:SetPoint("TOPLEFT", card, "TOPLEFT", P, -(2 * P + K.CARD_ICON))
    card.them:SetPoint("TOPRIGHT", card, "TOPRIGHT", -P, -(2 * P + K.CARD_ICON))
    buildTrade(card)
    card.trade:SetPoint("TOPLEFT", card.me, "BOTTOMLEFT", 0, -P)
    card.trade:SetPoint("TOPRIGHT", card.them, "BOTTOMRIGHT", 0, -P)
    buildActions(card)
    card:Hide()
    return card
end

-- ── painting ────────────────────────────────────────────────────────────────────────────────

local function qualityTone(fs, drop)
    local q = type(drop.facts) == "table" and drop.facts.quality
    local qc = type(ITEM_QUALITY_COLORS) == "table" and ITEM_QUALITY_COLORS[q]
    if qc then fs:SetTextColor(qc.r, qc.g, qc.b) else setTone(fs, "plain") end
end

local function paintHeader(card, drop)
    local name = NS.WindowCells.ItemName(drop.link) or "?"
    NS.WindowGroup.SetItem(card.icon, drop.link)
    card.name:SetText(name)
    qualityTone(card.name, drop)
    card.nameTip.tipLines = { name, L["Shift-click the icon to link it in chat; ctrl-click to try it on."] }
    local chips = DC.Chips(drop)
    for i, c in ipairs(card.chips) do
        local chip = chips[i]
        c:SetShown(chip ~= nil)
        if chip then paintChip(c, chip) end
    end
end

local function paintSideRow(r, line, width)
    r:SetShown(line ~= nil)
    if not line then return end
    r.label:SetText(line.label)
    r.value:SetText(line.text)
    setTone(r.value, line.tone)
    r.tipLines = line.tip
    r.key = line.key
    NS.WindowGroup.SetItem(r.item, line.link)
    r.value:ClearAllPoints()
    local x = K.SIDE_LABEL + (line.link and K.SIDE_ROW_H + 2 or 0)
    r.value:SetPoint("LEFT", r, "LEFT", x, 0)
    r.value:SetWidth(max(width - 20 - x, 20))
end

local function paintSide(side, model, width)
    side:SetWidth(width)
    side.title:SetText(model.title)
    paintChip(side.verdict, model.verdict)
    for i, r in ipairs(side.rows) do paintSideRow(r, model.rows[i], width) end
end

local function paintTrade(t, model)
    paintChip(t.chip, { text = model.chip.text, tone = model.chip.tone, tip = model.tip })
    t.text:SetText(model.text)
    t.meta:SetText(model.meta)
    t.tipLines = { model.tip[1], model.text, model.meta, model.tip[2] }
end

local function askState(drop)
    local target = NS.AskTargetOf(drop)
    if not target then return "ready" end
    return NS.TestMode.AskState(drop, NS.Asks.StateOf("ask", target, drop.id))
end

local function tradeGuard(drop)
    local who = type(drop.looter) == "table" and drop.looter or {}
    local target = who.guid or who.name
    if drop.isMine or not target then return { ok = false, reason = "noTarget" } end
    local TH = NS.TradeHelper
    local ok, reason = TH.CanTradeWith(target)
    return { ok = ok, reason = reason, text = TH.ReasonText(reason) }
end

-- The looter's inspect entry (a test mode placeholder's own).
local function inspectOf(drop)
    return NS.TestMode.InspectOf(drop)
end

local function paintActions(card, drop, ctx)
    for _, a in ipairs(DC.Actions(drop, ctx)) do
        local b = card.actions[a.key]
        b.dropId, b.link = drop.id, drop.link
        b.label:SetText(a.text)
        b.art:SetTexture(NS.Icon(a.icon))
        b:SetEnabled(a.enabled)
        b:SetAlpha(a.enabled and 1 or 0.5)
        b.tipLines = a.tip
        b.enabled = a.enabled
    end
end

--- Paint the card for `drop`, `width` pixels wide.
--- @param card table DCard.Build's answer
--- @param drop table the feed record
--- @param width number
--- @param now number GetTime()
function DCard.Paint(card, drop, width, now)
    card.dropId = drop.id
    card:SetSize(width, K.CARD_H)
    paintHeader(card, drop)
    local insp = inspectOf(drop)
    local specName = insp and NS.Compat.SpecName(insp.specID) or nil
    local sideW = max(floor((width - 3 * K.CARD_PAD) / 2), 120)
    paintSide(card.me, DC.ForYou(drop, NS.Compat.PawnIsReady()), sideW)
    paintSide(card.them, DC.ForLooter(drop, insp, specName, now), sideW)
    local situation = NS.WindowFooter.SITUATION_LABEL[drop.situation]
    paintTrade(card.trade, DC.TradeBox(drop, situation))
    local state, reason = askState(drop)
    paintActions(card, drop, { askState = state, askReason = reason, inspect = insp, now = now, trade = tradeGuard(drop) })
end

-- ── the Edit message box ────────────────────────────────────────────────────────────────────

local function counterText(n)
    return L["%d / %d bytes"]:format(n, C.MESSAGE_MAX_LEN)
end

local function textOf(e) return e.box:GetText() or "" end

local function refreshEditor(e)
    local n = #textOf(e)
    local ok = n > 0 and n <= C.MESSAGE_MAX_LEN
    e.counter:SetText(counterText(n))
    setTone(e.counter, ok and "muted" or "bad")
    e.send:SetEnabled(ok)
    e.send:SetAlpha(ok and 1 or 0.5)
end

local function sendEditor(e)
    local text = textOf(e)
    if #text == 0 or #text > C.MESSAGE_MAX_LEN then return end
    e:Hide()
    NS.PressAsk(e.dropId, { text = text })
end

local function editorButtons(e)
    e.send = NS.Window.TextButton(e, 80, "chat", L["Send"], function() sendEditor(e) end)
    e.send:SetPoint("BOTTOMRIGHT", e, "BOTTOMRIGHT", -10, 10)
    NS.Window.AttachTooltip(e.send, function()
        return L["Send"], L["Whisper the looter this text. One ask per item per looter."]
    end)
    e.cancel = NS.Window.TextButton(e, 80, "cancel", L["Cancel"], function() e:Hide() end)
    e.cancel:SetPoint("RIGHT", e.send, "LEFT", -6, 0)
    NS.Window.AttachTooltip(e.cancel, function() return L["Cancel"], L["Close the box without sending."] end)
end

local function editorBox(e)
    local frame = box(e)
    frame:SetPoint("TOPLEFT", e, "TOPLEFT", 10, -30)
    frame:SetPoint("BOTTOMRIGHT", e, "BOTTOMRIGHT", -10, 40)
    e.box = CreateFrame("EditBox", nil, frame)
    e.box:SetPoint("TOPLEFT", frame, "TOPLEFT", 6, -6)
    e.box:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -6, 6)
    e.box:SetMultiLine(true)
    e.box:SetAutoFocus(false)
    e.box:SetFontObject("ChatFontNormal")
    e.box:SetScript("OnTextChanged", function() refreshEditor(e) end)
    e.box:SetScript("OnEscapePressed", function() e:Hide() end)
    e.box:SetScript("OnEnterPressed", function() sendEditor(e) end)
end

local function buildEditor()
    local win = NS.Window.Frame()
    local e = CreateFrame("Frame", nil, win, "BackdropTemplate")
    e:SetSize(K.EDITOR_W, K.EDITOR_H)
    e:SetPoint("CENTER", win, "CENTER", 0, 0)
    e:SetFrameStrata("DIALOG")
    e:EnableMouse(true)
    NS.ApplySkin(e)
    e.title = e:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    e.title:SetPoint("TOPLEFT", e, "TOPLEFT", 10, -9)
    e.title:SetTextColor(C.GOLD.r, C.GOLD.g, C.GOLD.b)
    e.closeButton = NS.MakeCloseButton(e, function() e:Hide() end)
    if e.closeButton then e.closeButton:SetPoint("TOPRIGHT", e, "TOPRIGHT", -6, -6) end
    editorBox(e)
    e.counter = e:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    e.counter:SetPoint("BOTTOMLEFT", e, "BOTTOMLEFT", 12, 16)
    editorButtons(e)
    e:Hide()
    return e
end

--- Open the Edit message box for drop `dropID`: the ask template filled in for its looter, ready
--- to change and send. Says in the box why nothing can be sent when the ask would be refused.
--- @param dropID number
--- @return table|nil the box, or nil before the window is built
function DCard.OpenEditor(dropID)
    if not NS.Window.Frame() then return nil end
    editor = editor or buildEditor()
    local rec = NS.LootFeed.Get(dropID)
    local target = NS.AskTargetOf(rec)
    local who = NS.WindowCells.ShortName(target)
    local preview, why = nil, "noTarget"
    if target then preview, why = NS.Asks.Preview("ask", target, dropID) end
    editor.dropId = dropID
    editor.title:SetText(L["Edit message to %s"]:format(who))
    editor.box:SetText(preview and preview.text or "")
    refreshEditor(editor)
    if not preview then editor.counter:SetText(L["Can't ask: %s."]:format(EDIT_REFUSAL[why] or tostring(why))) end
    editor:Show()
    return editor
end

--- Close the Edit message box without sending (the window minimizing takes it down).
function DCard.CloseEditor()
    if editor then editor:Hide() end
end

--- The Edit message box, or nil before its first use. For the suites.
--- @return table|nil
function DCard.Editor() return editor end
