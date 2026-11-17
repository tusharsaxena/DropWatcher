local _, NS = ...
-- modules/OfferPanel.lua — the Offer panel, "Who could use this?" (design spec §11.4, board 04 and
-- AskFlow B3-B4): one of your drops against every other member's inspected gear, with Offer for
-- each and Announce to group.
--
-- WHAT IT HOLDS, top to bottom: the title (`Who could use this?` and `YOUR DROP`) with the shared
-- close mark; the item header (a real item button, the name in its quality color, and `You: -5 ilvl ·
-- 305 · Trade window 1:47:12`); the column labels (Member, Their eq, Actions); the candidates,
-- ranked (upgrades first by their gain; off-spec upgrades and equals after the main-spec ones,
-- feedback-19 spec §3), every second row striped as the main window's, each with
-- the name in its class color, Their eq in the Drops table's Them look (feedback-7 spec §0: the
-- worn item icons, their item level, the verdict glyph and the difference, `292 ▼4` (a mark per worn
-- item on a two-item slot read in full, `321 ▼10 / 308 ▲3`, feedback-21 H7), or a word:
-- `Can't use`, `…`, `Unavailable`; NS.SideCells.Candidate, painted by WindowGroup.PaintSide) and,
-- for an upgrade or an equal (an off-spec one too), the Offer button (the Trade button went with feedback-7 spec §0); the
-- list scrolls in a raid. The footer (LibKa0s Widgets' Footer, RX-23, spec B.2: no fill, a hairline in
-- the skin's `divider`, FOOTER.HEIGHT tall) holds the note on the order on its right line, in
-- `text.muted`, with the order's tooltip, and Announce to group as its one mark in the corner (RX-24,
-- WowAddonStandards v2.110.0 *The footer*: a footer's controls are catalog marks), its art and
-- tooltip following its ask state (MineCells.AnnounceButton) and the state's word, once it is not
-- ready (`Announced`, `Queued`, `Retry`), on the footer's left line. What each
-- part says is modules/MineCells.lua's and modules/SideCells.lua's (pure); this file is the frame
-- edge. Nothing is ever blank: a member with no Offer shows the gray No action with the reason
-- (feedback-11 spec §1).
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
-- (TradeTimerTick). It closes itself when its drop is gone, and when no other player is left in your
-- group to take it (DW-07: NS.WindowOwn.Alone; it will not open then either). Offer goes through
-- NS.PressOffer, Announce to group through NS.PressAnnounce.
--
-- THE MODE STRIP (RX-23; preview-mode, *Where the strip sits*: a frame with a title band is a
-- window, and every window of test or simulated data carries the strip directly under its title
-- bar). Test mode's sample drops open the panel on their sample candidates (WindowOwn.Alone is never
-- true for a test drop), and a simulation's drops on its simulated members, so a test drop
-- (`drop.test`) shows LibKa0s Widgets' TestStrip and a simulated one (`drop.sim`) its sim flavor,
-- docked by the library under `p.titleBar` (a bare frame NS.Skin.Header lays on the band's rect);
-- the body (the item header, the column labels, the list) moves down by the strip's `BodyOffset`
-- while one shows (relayBody). The band carries no mode word.

NS.OfferPanel = NS.OfferPanel or {}
local OP    = NS.OfferPanel
local K     = NS.Constants.WINDOW
local C     = NS.Constants
local L     = NS.L
local State = NS.State
local MC    = NS.MineCells
local SC    = NS.SideCells
local TM    = NS.TipMarks

local max = math.max

local panel   -- built on the first Open

-- The columns (feedback-7 spec §0): Their eq is at least the Drops table's Them width, so
-- `321/308 ▼13` and two icons fit, and a dual mark's `321 ▼10 / 308 ▲3` (feedback-21 H7); Actions
-- holds the Offer button.
local COLS = {
    { key = "member", label = L["Member"], x = 8, tip = { TM.Row(L["Shows"], L["a member of your group, in their class color"]) } },
    { key = "eq", label = L["Their eq"], x = 124,
      tip = NS.OffSpecCells.WithLegend({ TM.Row(L["Shows"], L["what they wear there (two for rings, trinkets, one-hand weapons), its item level"]),
          TM.Row(L["Then"], L["your drop judged for them, and the item-level difference"]),
          TM.Row(L["Two worn"], L["a mark each, the drop against each"]),
          TM.Row(L["Colors"], L["%s upgrade, %s sidegrade, %s downgrade"]:format(TM.Mark("upgrade"), TM.Mark("sidegrade"),
              TM.Mark("downgrade"))) }, TM.Hint(L["Hover for why."])) },
    { key = "actions", label = L["Actions"], x = 314, tip = { TM.Row(L["Offer"], L["whispers them your offer template"]) } },
}
OP.COLS = COLS

-- The note's tooltip: the list's order. Off-spec upgrades are Retail's alone (Forever port design
-- §4.4), so WoW Forever's second tier is the equals alone.
OP.ORDER_TIP = { L["Order"], TM.Row(L["First"], L["upgrades, by how much they gain"]),
    TM.Row(L["Then"], NS.OffSpec.Initialized() and L["equals, off-spec upgrades and equals"] or L["equals"]),
    TM.Row(L["Last"], L["no upgrade, can't use, checking, unavailable"]), TM.Hint(L["The list scrolls in a raid."]) }

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

-- `template` is the text's size (GameFontHighlightSmall when nil); its face is the skin's and its
-- color the tone set at paint time.
local function tipFrame(parent, place, template)
    local f = CreateFrame("Frame", nil, parent)
    f.text = f:CreateFontString(nil, "OVERLAY", template or "GameFontHighlightSmall")
    f.text:SetPoint("LEFT", f, "LEFT", 0, 0)
    f.text:SetJustifyH("LEFT")
    f.text:SetWordWrap(false)
    NS.Skin.Font(f.text)
    attach(f, place)
    return f
end

-- ── building a candidate row ────────────────────────────────────────────────────────────────

local function rowButtons(row)
    local W = NS.Window
    row.offer = W.TextButton(row, K.PANEL_BTN_W, "external-link", L["Offer"], function(b) NS.PressOffer(b.dropId, b.target) end)
    row.offer:SetPoint("LEFT", row, "LEFT", COLS[3].x, 0)
    attach(row.offer, "row")
end

local function newRow(content)
    local row = CreateFrame("Frame", nil, content)
    row:SetHeight(K.OFFER_ROW_H)
    row.tipRow = true
    NS.WindowRows.HoverWash(row)
    -- Every second row's faint stripe, as the main window's rows (WindowGroup, WindowHistory).
    row.stripe = row:CreateTexture(nil, "BACKGROUND")
    row.stripe:SetAllPoints(row)
    NS.SkinPaint(row.stripe, function(t) t:SetColorTexture(NS.SkinColor("list.stripe")) end)
    row.member = tipFrame(row, "row")
    row.member:SetPoint("LEFT", row, "LEFT", COLS[1].x, 0)
    row.member:SetSize(COLS[2].x - COLS[1].x - 6, K.OFFER_ROW_H)
    row.member.text:SetPoint("RIGHT", row.member, "RIGHT", 0, 0)
    row.eq = NS.WindowGroup.SideCell(row, "eq")
    row.eq:SetPoint("LEFT", row, "LEFT", COLS[2].x, 0)
    row.eq:SetSize(COLS[3].x - COLS[2].x - 6, K.OFFER_ROW_H)
    rowButtons(row)
    return row
end

-- ── building the panel ──────────────────────────────────────────────────────────────────────

local function buildTitle(p)
    -- The band's rect as a frame (no mouse), for the strips to dock under; NS.Skin.Header lays it on
    -- the band (`bars`), so it follows the skin's edge and title height (as the Rolls panel's).
    p.titleBar = CreateFrame("Frame", nil, p)
    p.titleBar:SetPoint("TOPLEFT", p, "TOPLEFT", 1, -1)
    p.titleBar:SetPoint("TOPRIGHT", p, "TOPRIGHT", -1, -1)
    p.titleBar:SetHeight(K.TITLE_H)
    p.title = p:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    p.title:SetPoint("TOPLEFT", p, "TOPLEFT", 10, -9)
    p.title:SetText(L["Who could use this?"])
    NS.Skin.Text(p.title, "heading")   -- gold, in the skin's title face
    p.kind = p:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    p.kind:SetPoint("LEFT", p.title, "RIGHT", 8, 0)
    NS.Skin.Text(p.kind, "disabled")
    p.kind:SetText(L["YOUR DROP"])
    -- The strip (AD-86-DW, LibKa0s#86): settings and close, from the corner the old close sat at. The
    -- panel is in the window tier, under the settings panel, so settings does not hide it first.
    local hb = NS.WindowTitleBar.Marks(p, { frame = p, point = "TOPRIGHT", y = -6,
        close = function() OP.Close() end })
    p.closeButton = hb.close
    -- The popover keeps the band S.Shell draws (NS.ApplySkin), and its title and marks sit on the
    -- band's middle, the title by the skin's `title.align`, in every skin (R5-WIN, the lead's call 3).
    -- With no library the strip's anchors stand.
    NS.Skin.Header(p, { title = p.title, right = hb.right, bars = { p.titleBar } })
end

local function buildHeader(p)
    p.item = NS.WindowGroup.ItemButton(p, K.CARD_ICON)
    p.name = tipFrame(p, nil, "GameFontNormal")
    NS.WindowGroup.ItemHover(p.name, p.item)
    p.name:SetPoint("TOPLEFT", p.item, "TOPRIGHT", 8, 0)
    p.name:SetSize(K.OFFER_W - K.CARD_ICON - 40, 16)
    p.line = tipFrame(p)
    p.line:SetPoint("TOPLEFT", p.name, "BOTTOMLEFT", 0, -2)
    p.line:SetSize(K.OFFER_W - K.CARD_ICON - 40, 14)
end

local function buildHeads(p)
    p.heads = {}
    for _, col in ipairs(COLS) do
        local f = CreateFrame("Frame", nil, p)
        f:SetSize(100, K.COLHEAD_H)
        f.x = 10 + col.x
        f.text = f:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        f.text:SetPoint("LEFT", f, "LEFT", 0, 0)
        f.text:SetText(col.label)
        NS.Skin.Text(f.text, "dw.idle")
        NS.Window.AttachTooltip(f, function() return col.label, unpack(col.tip) end)
        p.heads[col.key] = f
    end
end

local function announceTip(p)
    return unpack(p.announce.tipLines or { L["Announce to group"] })
end

-- Announce to group is the footer's one mark, the library's or, with no library, NS.BareFooter's
-- (RX-30), so it stays in reach on a degraded install.
local function buildFoot(p)
    local W = NS.Window
    local opts = { marks = { { icon = NS.Icon("speech-bubble"),
        onClick = function() NS.PressAnnounce(p.dropId) end } } }
    local foot = NS.MakeFooter(p, opts) or NS.BareFooter(p, opts)
    p.foot = foot
    p.announce = foot.marks[1]
    W.AttachTooltip(p.announce, function() return announceTip(p) end, "above")
    -- The note is the footer's right line (the library paints it `text.muted`); a frame over it
    -- carries the order's tooltip.
    p.note = CreateFrame("Frame", nil, foot)
    p.note.text = foot.right
    p.note:SetPoint("TOPLEFT", foot.right, "TOPLEFT", 0, 0)
    p.note:SetPoint("BOTTOMRIGHT", foot.right, "BOTTOMRIGHT", 0, 0)
    W.AttachTooltip(p.note, function() return tipOf(p.note) end)
end

local function buildList(p)
    local scroll = CreateFrame("ScrollFrame", nil, p, "UIPanelScrollFrameTemplate")
    local content = CreateFrame("Frame", nil, scroll)
    content:SetSize(1, 1)
    scroll:SetScrollChild(content)
    p.scroll, p.content = scroll, content
    local bar = rawget(scroll, "ScrollBar")
    if bar then NS.Skin.ScrollBar(bar) end   -- the skin's corridor and knob (D2)
    p.rowPool = NS.Pool.New()
    p.empty = p:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    NS.Skin.Text(p.empty, "text.highlight")
end

-- The body under the title band, `off` lower while a strip shows: the item header, the column
-- labels, the list and its empty line.
local function relayBody(p)
    local strip = (p.testStrip and p.testStrip:IsShown() and p.testStrip)
        or (p.simStrip and p.simStrip:IsShown() and p.simStrip) or nil
    local off = strip and strip:BodyOffset() or 0
    p.item:ClearAllPoints()
    p.item:SetPoint("TOPLEFT", p, "TOPLEFT", 10, -K.POPOVER_TOP - off)
    for _, f in pairs(p.heads) do
        f:ClearAllPoints()
        f:SetPoint("TOPLEFT", p, "TOPLEFT", f.x, -(K.OFFER_HEAD_H - K.COLHEAD_H) - off)
    end
    p.scroll:ClearAllPoints()
    p.scroll:SetPoint("TOPLEFT", p, "TOPLEFT", 10, -K.OFFER_HEAD_H - 2 - off)
    p.scroll:SetPoint("BOTTOMRIGHT", p, "BOTTOMRIGHT", -K.SCROLL_W - 4, NS.FooterMetric("HEIGHT") + 4)
    p.empty:ClearAllPoints()
    p.empty:SetPoint("TOP", p, "TOP", 0, -K.OFFER_HEAD_H - 20 - off)
end

-- The mode strips (THE MODE STRIP): test mode's and the simulation's, born hidden, docked directly
-- under the title band, each with the title bar's tooltip for its mode. Nil with no library.
local function buildStrips(p)
    local TB = NS.WindowTitleBar
    local dock = { titleBar = p.titleBar, window = p, onOffset = function() relayBody(p) end }
    local function strip(text, kind, tip)
        local s = NS.MakeTestStrip(p, text, kind, dock)
        if s then NS.Window.AttachTooltip(s, tip) end
        return s
    end
    p.testStrip = strip(L["TEST: sample members. Nothing is whispered; combat ends it."], nil, TB.TestTip)
    p.simStrip = strip(L["SIM: simulated members. Nothing is sent. /dw sim stop ends it."], "sim", TB.SimTip)
end

-- The strip drop `drop` owes: test mode's for a test drop, the simulation's for a simulated one.
local function paintStrips(p, drop)
    if p.testStrip then p.testStrip:SetShown(drop.test == true) end
    if p.simStrip then p.simStrip:SetShown(drop.test ~= true and drop.sim == true) end
    relayBody(p)
end

local function build()
    local win = NS.Window.Frame()
    local p = CreateFrame("Frame", nil, win, "BackdropTemplate")
    p:SetSize(K.OFFER_W, win:GetHeight() > 0 and win:GetHeight() or K.HEIGHT)
    p:SetFrameStrata(C.LAYERS.STRATA.WINDOW)   -- the window's, docked or floating: never switched
    p.tipHost = true   -- its item tooltip goes beside the panel, not the window under it (modules/RowTooltip.lua)
    win.tipDocks = win.tipDocks or {}
    win.tipDocks.offer = p   -- and a window row's tooltip goes beside the docked panel, not over it
    p:EnableMouse(true)
    NS.ApplySkin(p)
    buildTitle(p)
    buildHeader(p)
    buildHeads(p)
    buildList(p)
    buildFoot(p)
    buildStrips(p)
    relayBody(p)
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

-- The Rolls panel docks on the side this panel leaves free (RX-20): it repaints when this one
-- opens, closes or changes side (modules/RollsPanel.lua, read at call time: it loads later).
local function besideMoved()
    if NS.RollsPanel then NS.RollsPanel.Refresh() end
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
        p:SetPoint("BOTTOMRIGHT", win, "BOTTOMRIGHT", -K.INSET, NS.FooterMetric("HEIGHT"))   -- over the footer line (RX-09)
    end
    -- Floating over the window, it is drawn above the window's rows by its level, in the window's own
    -- strata (a popover, frame-layering-§3); docked beside it, at the window's chrome level.
    local LV = C.LAYERS.LEVEL
    p:SetFrameLevel(win:GetFrameLevel() + (side == "float" and LV.POPOVER_OFFER or LV.DOCKED))
    p:SetWidth(K.OFFER_W)
    local moved = p.dock ~= side
    p.dock = side
    if moved then besideMoved() end
end

-- ── painting ────────────────────────────────────────────────────────────────────────────────

local function paintHeader(p, drop, now, warnAt)
    local h = MC.PanelHeader(drop, now, warnAt)
    NS.WindowGroup.SetItem(p.item, drop.link, NS.WindowGroup.Where(drop))
    p.name.text:SetText(h.name)
    p.name.showItem = true   -- the real item tooltip (WindowGroup.ItemHover, DW-80)
    local q = type(drop.facts) == "table" and drop.facts.quality or nil
    local r, g, b = NS.QualityColor(q)   -- the skin's q.* token, else the client's color (E4)
    if r then p.name.text:SetTextColor(r, g, b) end
    p.line.text:SetText(h.text)
    setTone(p.line.text, h.tone == "warn" and "warn" or "muted")
    p.line.tipLines = h.tip
end

-- A member it is not an upgrade or equal for, or a drop that cannot be traded: the gray No action
-- with its reason (feedback-11 spec §1).
local function noOffer(drop)
    if NS.Collectibles.IsFeedOnly(drop) then return NS.WindowCells.NoAction({ TM.Row(L["Why"], NS.CollectCells.NO_OFFER) }) end
    if drop.trade and drop.trade.state == "no" then
        local WC = NS.WindowCells
        return WC.NoAction(WC.Append({ TM.Row(L["Why"], L["not tradeable"]) }, WC.TradeRows(drop.trade, L["you"])))
    end
    return NS.WindowCells.NoAction({ TM.Row(L["Offer"], L["for members it upgrades or equals"]) })
end

local function paintButtons(row, e, drop)
    local show = e.offerable and drop.trade and drop.trade.state ~= "no"
    if not show then
        row.offer.dropId, row.offer.target = nil, nil
        NS.WindowOwn.SetButtonLook(row.offer, noOffer(drop))
        return
    end
    row.offer.dropId, row.offer.target = drop.id, e.name
    local look = MC.OfferButton(NS.Asks.StateOf("offer", e.name, drop.id), nil, e.short)
    look.toneState = MC.ToneState(NS.History.OutcomeOf(drop.id), look.state)
    NS.WindowOwn.SetButtonLook(row.offer, look)
end

-- A candidate's inspect read (both worn items, the read's age); a test drop's candidates have none.
local function readOf(drop, e)
    if drop.test or not e.guid then return nil end
    return NS.Inspect.Get(e.guid)
end

-- One candidate: the name in its class color, Their eq (the Them cell's look: the icons' tooltips
-- read their links) and the Offer button.
local function paintRow(row, e, drop, now)
    row.guid = e.guid
    NS.WindowGroup.ClassTone(row.member.text, e.classFile, "plain")
    row.member.text:SetText(e.short)
    row.member.tipLines = { e.short, TM.Row(L["Name"], tostring(e.name)) }
    NS.WindowGroup.PaintSide(row.eq, SC.Candidate(drop, e, readOf(drop, e), now))
    paintButtons(row, e, drop)
end

local function paintList(p, drop, list, now)
    NS.Pool.ReleaseAll(p.rowPool)
    local width = K.OFFER_W - K.SCROLL_W - 24
    for i, e in ipairs(list) do
        local r = NS.Pool.Acquire(p.rowPool, function() return newRow(p.content) end)
        r:ClearAllPoints()
        r:SetPoint("TOPLEFT", p.content, "TOPLEFT", 0, -(i - 1) * K.OFFER_ROW_H)
        r:SetWidth(width)
        r.stripe:SetShown(i % 2 == 0)
        paintRow(r, e, drop, now)
    end
    p.content:SetSize(width, max(#list * K.OFFER_ROW_H, 1))
    p.empty:SetShown(#list == 0)
    p.empty:SetText(L["Nobody else in your group to offer it to."])
    p.list = list
end

local function paintFoot(p, drop, n)
    local state, reason = NS.Asks.StateOf("announce", nil, drop.id)
    local look = MC.AnnounceButton(state, reason)
    local tradeable = drop.trade and drop.trade.state ~= "no"
    local b = p.announce
    b.icon:SetTexture(NS.Icon(look.icon))
    b.tipLines, b.state = look.tip, look.state
    local on = look.enabled and tradeable
    b:SetEnabled(on)
    b:SetAlpha(on and 1 or 0.4)
    if not tradeable then
        b.tipLines = { L["Announce to group"], TM.Row(L["Tradeable"], L["no"]), TM.Row(L["To announce"], L["nothing"]) }
    end
    p.foot:SetLeft(look.state ~= "ready" and look.text or "")
    p.note.text:SetText(L["%d members · sorted by gain"]:format(n))   -- the footer's right line
    p.note.tipLines = OP.ORDER_TIP
end

--- Repaint the panel from its drop, or close it when the drop is gone or nobody could take it
--- (DW-07). Called by Window.Refresh.
function OP.Refresh()
    if not (panel and panel:IsShown()) then return end
    local id = sink().dropId
    local drop = id ~= nil and NS.LootFeed.Get(id) or nil
    if not (drop and drop.isMine) or NS.WindowOwn.Alone(drop) or NS.Collectibles.IsFeedOnly(drop) then return OP.Close() end
    panel.dropId = id
    paintStrips(panel, drop)
    dock(panel)
    local now = GetTime()
    paintHeader(panel, drop, now, NS.TradeTimer.WarnAt())
    local list = MC.Candidates(drop)
    paintList(panel, drop, list, now)
    paintFoot(panel, drop, #list)
end

--- Open the panel for one of your drops (its Offer, through OP.Toggle, or `/dw offer`). It reveals
--- who the drop would help when it is an upgrade for you: the player chose to offer it
--- (NS.WindowOwn.Reveal).
--- @param dropID number
--- @return table|nil the panel, or nil before the window is built, for a drop that is not yours, a
---   collectible (feed-only, issue #13), or while no other player is in your group to take it
---   (DW-07, NS.WindowOwn.Alone)
function OP.Open(dropID)
    local drop = dropID ~= nil and NS.LootFeed.Get(dropID) or nil
    if not (drop and drop.isMine and NS.Window.Frame()) or NS.WindowOwn.Alone(drop) then return nil end
    if NS.Collectibles.IsFeedOnly(drop) then return nil end
    panel = panel or build()
    sink().dropId = dropID
    NS.WindowOwn.Reveal(dropID)
    NS.Debug("UI", "offer panel: drop %s", tostring(dropID))
    panel:Show()
    if NS.Window.IsShown() then NS.Window.Refresh() else OP.Refresh() end
    besideMoved()
    return panel
end

--- Close the panel.
function OP.Close()
    State.offerPanel = nil
    if panel then panel:Hide() end
    besideMoved()
end

--- A drop's Offer button (feedback-21 H4): it closes the panel when the panel already shows that
--- drop, else opens it for the drop (switching from another drop's). `/dw offer` keeps OP.Open.
--- @param dropID number
--- @return table|nil the panel when it opened, else nil
function OP.Toggle(dropID)
    if dropID ~= nil and OP.IsShown() and OP.DropId() == dropID then return OP.Close() end
    return OP.Open(dropID)
end

--- @return boolean
function OP.IsShown() return panel ~= nil and panel:IsShown() == true end

--- The side the shown panel is docked on (`right`, `left`, or `float` over the window), or nil
--- while it is closed: the Rolls panel takes the other side (RX-20).
--- @return string|nil
function OP.DockSide() return OP.IsShown() and panel.dock or nil end

--- The drop the panel shows, or nil.
--- @return number|nil
function OP.DropId() return State.offerPanel and State.offerPanel.dropId or nil end

--- The built panel and its drawn rows, for the suites: { panel, rows, list }, or nil before the build.
--- @return table|nil
function OP.Drawn()
    if not panel then return nil end
    return { panel = panel, rows = panel.rowPool.active, list = panel.list or {} }
end
