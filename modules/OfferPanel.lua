local _, NS = ...
-- modules/OfferPanel.lua — the Offer panel, "Who could use this?" (design spec §11.4, board 04 and
-- AskFlow B3-B4): one of your drops against every other member's inspected gear, with Offer and
-- Trade for each and Announce to group.
--
-- WHAT IT HOLDS, top to bottom: the title (`Who could use this?` and `YOUR DROP`) with the shared
-- close mark; the item header (a real item button, the name in its quality color, and `You: -5 ilvl ·
-- 305 · Trade window 1:47:12`); the column labels; the candidates, ranked (upgrades first by their
-- gain), each with a class-colored stripe, the name, `eq → drop`, a status pill (`+n UPGRADE`,
-- `EQUAL`, `NO UPGRADE`, `CAN'T USE`, `CHECKING` or `UNAVAILABLE`) and, for an upgrade or an equal,
-- the Offer and Trade buttons; the list scrolls in a raid. The foot strip holds Announce to group and
-- a note on the order. What each part says is modules/MineCells.lua's (pure); this file is the frame
-- edge. Nothing is ever blank: a member with no button shows a dash with the reason.
--
-- THE DOCK. The panel is a child of the main window, so it hides, scales and fades with it. It is
-- docked to the window's right edge, else its left when the screen has no room on the right, else
-- floats over the window's right half (MineCells.DockSide), re-placed on every repaint. Beside the
-- compact window (compact spec §3, DW-C3) its width is unchanged and it takes the side with room
-- the same way; it keeps its own least height (OP.CompactHeight) rather than the short window's,
-- and floating, it is centered over the narrower window.
--
-- THE UI LISTENS. One panel, built on its first Open; NS.State.offerPanel.dropId names the drop it
-- shows. The window repaints it with the active tab (Window.Refresh), so the bus reaches it: the
-- candidates' inspects (DropUpdated), the ask states (AskStateChanged) and the countdown
-- (TradeTimerTick). It closes itself when its drop is gone. Offer goes through NS.PressOffer, Trade
-- through NS.GiveDrop (the trade helper's guards, read first through NS.TradeHelper.CanGive so a
-- refused trade is a disabled button with the reason), Announce to group through NS.PressAnnounce.

NS.OfferPanel = NS.OfferPanel or {}
local OP    = NS.OfferPanel
local K     = NS.Constants.WINDOW
local C     = NS.Constants
local L     = NS.L
local State = NS.State
local MC    = NS.MineCells

local max = math.max

local panel   -- built on the first Open

local COLS = {
    { key = "member", label = L["Member"], x = 8, tip = L["A member of your group, in their class color."] },
    { key = "eq", label = L["Eq → drop"], x = 132, tip = L["The item level they wear in that slot, then your drop's."] },
    { key = "status", label = L["Status"], x = 222, tip = L["Your drop judged for them, from their inspected gear."] },
    { key = "actions", label = L["Actions"], x = 326, tip = L["Offer whispers your offer template; Trade opens the trade window with the item placed."] },
}

-- ── small helpers ───────────────────────────────────────────────────────────────────────────

local function setTone(fs, tone)
    local c = C.TONE[tone] or C.TONE.plain
    fs:SetTextColor(c.r, c.g, c.b)
end

local function tipOf(frame) return unpack(frame.tipLines or {}) end

-- `place` is "row" for a candidate row's parts (the row's top right, modules/RowTooltip.lua), nil
-- for the panel's header.
local function attach(frame, place)
    NS.Window.AttachTooltip(frame, function() return tipOf(frame) end, place)
end

local function sink()
    local s = State.offerPanel
    if not s then
        s = {}
        State.offerPanel = s
    end
    return s
end

local function tipFrame(parent, place)
    local f = CreateFrame("Frame", nil, parent)
    f.text = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    f.text:SetPoint("LEFT", f, "LEFT", 0, 0)
    f.text:SetJustifyH("LEFT")
    f.text:SetWordWrap(false)
    attach(f, place)
    return f
end

-- ── building a candidate row ────────────────────────────────────────────────────────────────

local function newPill(row)
    local p = CreateFrame("Frame", nil, row, "BackdropTemplate")
    p:SetSize(K.PILL_W, K.CHIP_H)
    local S = NS.SKIN
    if p.SetBackdrop and S and S.edgeFile then
        p:SetBackdrop({ edgeFile = S.edgeFile, edgeSize = S.edgeSize })
    end
    p.text = p:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    p.text:SetPoint("CENTER", p, "CENTER", 0, 0)
    attach(p, "row")
    return p
end

local function rowButtons(row)
    local W = NS.Window
    row.offer = W.TextButton(row, K.PANEL_BTN_W, nil, L["Offer"], function(b) NS.PressOffer(b.dropId, b.target) end)
    row.offer:SetPoint("LEFT", row, "LEFT", COLS[4].x, 0)
    attach(row.offer, "row")
    row.trade = W.TextButton(row, K.PANEL_BTN_W, "transfer", L["Trade"], function(b) NS.GiveDrop(b.dropId, b.target) end)
    row.trade:SetPoint("LEFT", row.offer, "RIGHT", 4, 0)
    attach(row.trade, "row")
    row.dash = tipFrame(row, "row")
    row.dash:SetPoint("LEFT", row, "LEFT", COLS[4].x, 0)
    row.dash:SetSize(K.PANEL_BTN_W, K.OFFER_ROW_H)
    row.dash.text:SetText("–")
end

local function newRow(content)
    local row = CreateFrame("Frame", nil, content)
    row:SetHeight(K.OFFER_ROW_H)
    row.tipRow = true
    row.stripe = row:CreateTexture(nil, "ARTWORK")
    row.stripe:SetSize(3, K.OFFER_ROW_H - 6)
    row.stripe:SetPoint("LEFT", row, "LEFT", 0, 0)
    row.member = tipFrame(row, "row")
    row.member:SetPoint("LEFT", row, "LEFT", COLS[1].x, 0)
    row.member:SetSize(COLS[2].x - COLS[1].x - 6, K.OFFER_ROW_H)
    row.eq = tipFrame(row, "row")
    row.eq:SetPoint("LEFT", row, "LEFT", COLS[2].x, 0)
    row.eq:SetSize(COLS[3].x - COLS[2].x - 6, K.OFFER_ROW_H)
    row.pill = newPill(row)
    row.pill:SetPoint("LEFT", row, "LEFT", COLS[3].x, 0)
    rowButtons(row)
    return row
end

-- ── building the panel ──────────────────────────────────────────────────────────────────────

local function buildTitle(p)
    p.title = p:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    p.title:SetPoint("TOPLEFT", p, "TOPLEFT", 10, -9)
    p.title:SetText(L["Who could use this?"])
    p.title:SetTextColor(C.GOLD.r, C.GOLD.g, C.GOLD.b)
    p.kind = p:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    p.kind:SetPoint("LEFT", p.title, "RIGHT", 8, 0)
    p.kind:SetText(L["YOUR DROP"])
    p.closeButton = NS.MakeCloseButton(p, function() OP.Close() end)
    if p.closeButton then p.closeButton:SetPoint("TOPRIGHT", p, "TOPRIGHT", -6, -6) end
end

local function buildHeader(p)
    p.item = NS.WindowGroup.ItemButton(p, K.CARD_ICON)
    p.item:SetPoint("TOPLEFT", p, "TOPLEFT", 10, -32)
    p.name = tipFrame(p)
    NS.WindowGroup.ItemHover(p.name, p.item)
    p.name:SetPoint("TOPLEFT", p.item, "TOPRIGHT", 8, 0)
    p.name:SetSize(K.OFFER_W - K.CARD_ICON - 40, 16)
    p.name.text:SetFontObject("GameFontNormal")
    p.line = tipFrame(p)
    p.line:SetPoint("TOPLEFT", p.name, "BOTTOMLEFT", 0, -2)
    p.line:SetSize(K.OFFER_W - K.CARD_ICON - 40, 14)
end

local function buildHeads(p)
    p.heads = {}
    for _, col in ipairs(COLS) do
        local f = CreateFrame("Frame", nil, p)
        f:SetSize(100, K.COLHEAD_H)
        f:SetPoint("TOPLEFT", p, "TOPLEFT", 10 + col.x, -(K.OFFER_HEAD_H - K.COLHEAD_H))
        f.text = f:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        f.text:SetPoint("LEFT", f, "LEFT", 0, 0)
        f.text:SetText(col.label)
        f.text:SetTextColor(C.IDLE.r, C.IDLE.g, C.IDLE.b)
        NS.Window.AttachTooltip(f, function() return col.label, col.tip end)
        p.heads[col.key] = f
    end
end

local function announceTip(p)
    return unpack(p.announce.tipLines or { L["Announce to group"] })
end

local function buildFoot(p)
    local W = NS.Window
    p.announce = W.TextButton(p, 130, "speech-bubble", L["Announce to group"], function() NS.PressAnnounce(p.dropId) end)
    p.announce:SetPoint("BOTTOMLEFT", p, "BOTTOMLEFT", 10, 8)
    W.AttachTooltip(p.announce, function() return announceTip(p) end)
    p.note = tipFrame(p)
    p.note:SetPoint("BOTTOMRIGHT", p, "BOTTOMRIGHT", -10, 8)
    p.note:SetSize(200, K.CONTROL_H)
    p.note.text:ClearAllPoints()
    p.note.text:SetPoint("RIGHT", p.note, "RIGHT", 0, 0)
    p.note.text:SetJustifyH("RIGHT")
end

local function buildList(p)
    local scroll = CreateFrame("ScrollFrame", nil, p, "UIPanelScrollFrameTemplate")
    scroll:SetPoint("TOPLEFT", p, "TOPLEFT", 10, -K.OFFER_HEAD_H - 2)
    scroll:SetPoint("BOTTOMRIGHT", p, "BOTTOMRIGHT", -K.SCROLL_W - 4, K.OFFER_FOOT_H + 4)
    local content = CreateFrame("Frame", nil, scroll)
    content:SetSize(1, 1)
    scroll:SetScrollChild(content)
    p.scroll, p.content = scroll, content
    p.rowPool = NS.Pool.New()
    p.empty = p:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    p.empty:SetPoint("TOP", p, "TOP", 0, -K.OFFER_HEAD_H - 20)
end

local function build()
    local win = NS.Window.Frame()
    local p = CreateFrame("Frame", nil, win, "BackdropTemplate")
    p:SetSize(K.OFFER_W, win:GetHeight() > 0 and win:GetHeight() or K.HEIGHT)
    p:SetFrameStrata("MEDIUM")
    p.tipHost = true   -- its item tooltip goes beside the panel, not the window under it (modules/RowTooltip.lua)
    win.tipDocked = p  -- and a window row's tooltip goes beside the docked panel, not over it
    p:EnableMouse(true)
    NS.ApplySkin(p)
    buildTitle(p)
    buildHeader(p)
    buildHeads(p)
    buildList(p)
    buildFoot(p)
    p:Hide()
    return p
end

-- ── the dock ────────────────────────────────────────────────────────────────────────────────

local function screenWidth()
    local w = UIParent and UIParent.GetWidth and UIParent:GetWidth()
    return type(w) == "number" and w or nil
end

local function edge(frame, method)
    local v = frame[method] and frame[method](frame)
    return type(v) == "number" and v or nil
end

--- The panel's height beside the compact window: the window's, but never under OFFER_MIN_H (the
--- header, a few candidates and the foot).
--- @param winHeight number|nil
--- @return number
function OP.CompactHeight(winHeight)
    return max(type(winHeight) == "number" and winHeight or 0, K.OFFER_MIN_H)
end

-- Beside the compact window: top-aligned at its own least height; floating, centered over it.
local function dockCompact(p, win, side)
    if side == "right" then
        p:SetPoint("TOPLEFT", win, "TOPRIGHT", K.DOCK_GAP, 0)
    elseif side == "left" then
        p:SetPoint("TOPRIGHT", win, "TOPLEFT", -K.DOCK_GAP, 0)
    else
        p:SetPoint("TOP", win, "TOP", 0, -K.TITLE_H)
    end
    p:SetHeight(OP.CompactHeight(edge(win, "GetHeight")))
end

local function dock(p)
    local win = NS.Window.Frame()
    local side = MC.DockSide(edge(win, "GetLeft"), edge(win, "GetRight"), K.OFFER_W, screenWidth(), K.DOCK_GAP)
    p:ClearAllPoints()
    if NS.WindowGroup.IsCompact() then
        dockCompact(p, win, side)
    elseif side == "right" then
        p:SetPoint("TOPLEFT", win, "TOPRIGHT", K.DOCK_GAP, 0)
        p:SetPoint("BOTTOMLEFT", win, "BOTTOMRIGHT", K.DOCK_GAP, 0)
    elseif side == "left" then
        p:SetPoint("TOPRIGHT", win, "TOPLEFT", -K.DOCK_GAP, 0)
        p:SetPoint("BOTTOMRIGHT", win, "BOTTOMLEFT", -K.DOCK_GAP, 0)
    else
        p:SetPoint("TOPRIGHT", win, "TOPRIGHT", -K.INSET, -K.TITLE_H)
        p:SetPoint("BOTTOMRIGHT", win, "BOTTOMRIGHT", -K.INSET, K.FOOTER_H)
    end
    -- Floating over the window, it is drawn above the window's rows.
    p:SetFrameStrata(side == "float" and "DIALOG" or "MEDIUM")
    p:SetWidth(K.OFFER_W)
    p.dock = side
end

-- ── painting ────────────────────────────────────────────────────────────────────────────────

local function paintHeader(p, drop, now, warnAt)
    local h = MC.PanelHeader(drop, now, warnAt)
    NS.WindowGroup.SetItem(p.item, drop.link, NS.WindowGroup.Where(drop))
    p.name.text:SetText(h.name)
    p.name.showItem = true   -- the real item tooltip (WindowGroup.ItemHover, DW-80)
    local q = type(drop.facts) == "table" and drop.facts.quality
    local qc = type(ITEM_QUALITY_COLORS) == "table" and ITEM_QUALITY_COLORS[q]
    if qc then p.name.text:SetTextColor(qc.r, qc.g, qc.b) end
    p.line.text:SetText(h.text)
    setTone(p.line.text, h.tone == "warn" and "warn" or "muted")
    p.line.tipLines = h.tip
end

local function classStripe(row, classFile)
    local r, g, b = NS.Compat.ClassColor(classFile)
    if r then
        row.stripe:SetColorTexture(r, g, b, 1)
        row.member.text:SetTextColor(r, g, b)
    else
        row.stripe:SetColorTexture(C.IDLE.r, C.IDLE.g, C.IDLE.b, 1)
        setTone(row.member.text, "plain")
    end
end

local function paintButtons(row, e, drop)
    local show = e.offerable and drop.trade and drop.trade.state ~= "no"
    row.offer:SetShown(show)
    row.trade:SetShown(show)
    row.dash:SetShown(not show)
    if not show then
        row.dash.tipLines = { L["No offer"], L["Offer and Trade are shown for members it is an upgrade or an equal for."] }
        return
    end
    row.offer.dropId, row.offer.target = drop.id, e.name
    row.trade.dropId, row.trade.target = drop.id, e.name
    local look = MC.OfferButton(NS.Asks.StateOf("offer", e.name, drop.id), nil, e.short)
    look.toneState = MC.ToneState(NS.History.OutcomeOf(drop.id), look.state)
    NS.WindowMine.SetButtonLook(row.offer, look)
    local ok, reason = NS.TradeHelper.CanGive(drop.id, e.name)
    local tb = MC.TradeButton(ok, NS.TradeHelper.ReasonText(reason), e.short)
    row.trade:SetEnabled(tb.enabled)
    row.trade:SetAlpha(tb.enabled and 1 or 0.5)
    row.trade.tipLines = tb.tip
end

local function paintRow(row, e, drop)
    row.guid = e.guid
    classStripe(row, e.classFile)
    row.member.text:SetText(e.short)
    row.member.tipLines = { e.short, e.name ~= e.short and tostring(e.name) or L["A member of your group."] }
    row.eq.text:SetText(e.eq)
    setTone(row.eq.text, "muted")
    row.eq.tipLines = { L["Eq → drop"], L["What %s wears in that slot, then your drop's item level."]:format(e.short) }
    row.pill.text:SetText(e.pill.text)
    setTone(row.pill.text, e.pill.tone)
    row.pill.tipLines = e.pill.tip
    paintButtons(row, e, drop)
end

local function paintList(p, drop, list)
    NS.Pool.ReleaseAll(p.rowPool)
    local width = K.OFFER_W - K.SCROLL_W - 24
    for i, e in ipairs(list) do
        local r = NS.Pool.Acquire(p.rowPool, function() return newRow(p.content) end)
        r:ClearAllPoints()
        r:SetPoint("TOPLEFT", p.content, "TOPLEFT", 0, -(i - 1) * K.OFFER_ROW_H)
        r:SetWidth(width)
        paintRow(r, e, drop)
    end
    p.content:SetSize(width, max(#list * K.OFFER_ROW_H, 1))
    p.empty:SetShown(#list == 0)
    p.empty:SetText(L["Nobody else in your group to offer it to."])
    p.list = list
end

local function paintFoot(p, drop, n)
    local state, reason = NS.Asks.StateOf("announce", nil, drop.id)
    local look = MC.AnnounceButton(state, reason)
    look.toneState = MC.ToneState(NS.History.OutcomeOf(drop.id), look.state)
    local tradeable = drop.trade and drop.trade.state ~= "no"
    NS.WindowMine.SetButtonLook(p.announce, look)
    p.announce.label:SetText(look.state == "ready" and L["Announce to group"] or look.text)
    if not tradeable then
        p.announce:SetEnabled(false)
        p.announce:SetAlpha(0.5)
        p.announce.tipLines = { L["Announce to group"], L["Not tradeable, so there is nothing to announce."] }
    end
    p.note.text:SetText(L["%d members · sorted by gain"]:format(n))
    setTone(p.note.text, "muted")
    p.note.tipLines = { L["Order"], L["Upgrades first, by how much they gain; then equal, no upgrade, can't use, checking and unavailable. The list scrolls in a raid."] }
end

--- Repaint the panel from its drop, or close it when the drop is gone. Called by Window.Refresh.
function OP.Refresh()
    if not (panel and panel:IsShown()) then return end
    local id = sink().dropId
    local drop = id ~= nil and NS.LootFeed.Get(id) or nil
    if not (drop and drop.isMine) then return OP.Close() end
    panel.dropId = id
    dock(panel)
    local now = GetTime()
    paintHeader(panel, drop, now, NS.TradeTimer.WarnAt())
    local list = MC.Candidates(drop)
    paintList(panel, drop, list)
    paintFoot(panel, drop, #list)
end

--- Open the panel for one of your drops (its row's Offer). It reveals the drop's Best candidates
--- when it is an upgrade for you: the player chose to offer it.
--- @param dropID number
--- @return table|nil the panel, or nil before the window is built or for a drop that is not yours
function OP.Open(dropID)
    local drop = dropID ~= nil and NS.LootFeed.Get(dropID) or nil
    if not (drop and drop.isMine and NS.Window.Frame()) then return nil end
    panel = panel or build()
    sink().dropId = dropID
    NS.WindowMine.Reveal(dropID)
    NS.Debug("UI", "offer panel: drop %s", tostring(dropID))
    panel:Show()
    if NS.Window.IsShown() then NS.Window.Refresh() else OP.Refresh() end
    return panel
end

--- Close the panel.
function OP.Close()
    State.offerPanel = nil
    if panel then panel:Hide() end
end

--- @return boolean
function OP.IsShown() return panel ~= nil and panel:IsShown() == true end

--- The drop the panel shows, or nil.
--- @return number|nil
function OP.DropId() return State.offerPanel and State.offerPanel.dropId or nil end

--- The built panel and its drawn rows, for the suites: { panel, rows, list }, or nil before the build.
--- @return table|nil
function OP.Drawn()
    if not panel then return nil end
    return { panel = panel, rows = panel.rowPool.active, list = panel.list or {} }
end
