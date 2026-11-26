local _, NS = ...
-- modules/ItemSearchVerdictPanel.lua — the Item Search window's verdict panel (round 4 addendum A1,
-- R4-DW-11): the score and verdict of the item the window shows, explained, at the bottom of the
-- left column under Matches. WoW Forever's alone, as the window is (C.FEATURE.itemSearch, clients-§4).
--
-- WHEN IT SHOWS. Only while this character holds the item shown, in the bags or the bank: the bank
-- counted from the client's cached count (NS.Compat.ItemCount, C_Item.GetItemCount with the bank),
-- so it works with the bank closed; what you wear is not held. Otherwise it hides and the Matches
-- list takes the full height again.
--
-- WHAT IT SHOWS. A section header ("Verdict", "You have N"), then the tooltip's badge (the same two
-- filled boxes, from the one builder: NS.ItemSearchTip.MakeBadge, .Badge, .FillBadge), then one line
-- per part that counted, with its points, in the order the score adds them: the quests by quest; the
-- known recipes by skill-up color, the recipes you could learn and the other professions, with a cap
-- shown when it was hit; gear; the dampers; the 0..100 clamp, the poor-quality cap and the quest
-- item's floor when they apply. Then the total ("Score  65"), the line the verdict word comes from
-- ("Keep from 50") and, below a High confidence, the missing input's fix as a plain hint ("Open your
-- profession window to rank recipes"). No confidence tier. Every number is the verdict module's
-- (NS.ItemSearchVerdict.Breakdown, IS.Breakdown): the panel adds nothing up, so it and the
-- tooltip's reasons cannot disagree.
--
-- SPACE. The panel is the header, the badge and up to C.ITEM_SEARCH.PANEL.LINES lines tall, in the
-- main window's table font and row height (NS.WindowRows.Metrics); more lines scroll inside it. The
-- Matches list keeps C.ITEM_SEARCH.PANEL.MIN_ROWS rows at least: in a window too short for both the
-- panel gives way (down to its header, the badge and one line) and scrolls.
--
-- WHEN IT UPDATES. Every window repaint, from a kept breakdown: it is worked out again only when the
-- item, the count you hold, the verdict memo's generation (NS.ItemSearchVerdict.Generation) or, for
-- gear, your gear's signature (NS.ItemSearchVerdict.GearSignature, the memo's own stale rule, so the
-- panel and the tooltip's badge judge the same gear) moved, so a corner drag re-lays it without
-- working it out. A breakdown still unsettled (the item's info or its gear verdict loading) is worked
-- out again C.ITEM_SEARCH.VERDICT.RETRY seconds on, PANEL.RETRIES times each time the item is shown,
-- and after that on every window repaint. A bag or bank change (BAG_UPDATE_DELAYED,
-- PLAYERBANKSLOTS_CHANGED), a verdict event (a quest, skill, level or recipe change) or your gear
-- moving (GearChanged) while the window is open repaints the panel alone, at most once each
-- C.ITEM_SEARCH.PANEL.THROTTLE seconds. Never on a hover.

NS.ItemSearchVerdictPanel = NS.ItemSearchVerdictPanel or {}
local IVP = NS.ItemSearchVerdictPanel
local IS  = NS.ItemSearch
local IVD = NS.ItemSearchVerdict
local ISG = NS.ItemSearchGrid
local C   = NS.Constants
local L   = NS.L

local Compat = NS.Compat
local WIN = C.ITEM_SEARCH.WINDOW
local P   = C.ITEM_SEARCH.PANEL
local B   = C.ITEM_SEARCH.BADGE
local K   = C.WINDOW

local function IST() return NS.ItemSearchTip end

-- The badge's row under the header, and the lines' top under it.
local BADGE_TOP = ISG.HEADER_H + P.GAP
local LINES_TOP = BADGE_TOP + B.HEIGHT + P.GAP

-- The left column's top part above the Matches list (the title band, the search box, the Matches
-- header, their gaps: modules/ItemSearchWindow.lua's buildTitle, buildSearch and buildLeft), and
-- the footer's room below it.
local function columnTop()
    return 1 + K.TITLE_H + 8 + K.CONTROL_H + 8 + ISG.HEADER_H + 2
end

local function columnBottom()
    return NS.FooterMetric("HEIGHT") + 4
end

-- ── building ────────────────────────────────────────────────────────────────────────────────

local function lineText(parent, justify)
    local fs = parent:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    NS.Skin.Font(fs)
    fs:SetJustifyH(justify)
    fs:SetWordWrap(false)
    return fs
end

-- One breakdown line: the part's words on the left, its points on the right, in the table font
-- (`cells`, as NS.WindowRows.ApplyRowFont reads them).
local function newLine(content)
    local row = CreateFrame("Frame", nil, content)
    local text, points = lineText(row, "LEFT"), lineText(row, "RIGHT")
    text:SetPoint("LEFT", row, "LEFT", 4, 0)
    text:SetPoint("RIGHT", points, "LEFT", -6, 0)
    points:SetPoint("RIGHT", row, "RIGHT", -4, 0)
    row.cells = { text = { text = text }, points = { text = points } }
    return row
end

--- Build the panel on the window `f` (hidden): `f.verdict`, with its `head` (ISG.Header's), `badge`
--- (NS.ItemSearchTip.MakeBadge's regions), `scroll`, `content` and `lines`.
--- @param f table the Item Search window
--- @return table
function IVP.Build(f)
    local p = CreateFrame("Frame", nil, f)
    p:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", K.INSET, columnBottom())
    p:SetWidth(WIN.LEFT_W)
    p:Hide()
    p.head = ISG.Header(p, {})
    p.head:SetPoint("TOPLEFT", p, "TOPLEFT", 0, 0)
    p.head:SetWidth(WIN.LEFT_W)
    p.badge = IST().MakeBadge(p)
    p.scroll, p.content = ISG.ScrollArea(p)
    p.scroll:SetPoint("TOPLEFT", p, "TOPLEFT", 0, -LINES_TOP)
    p.scroll:SetPoint("BOTTOMLEFT", p, "BOTTOMLEFT", 0, 0)
    p.scroll:SetWidth(WIN.LEFT_W - K.SCROLL_W)
    p.lines = {}
    f.verdict = p
    return p
end

-- ── the lines ───────────────────────────────────────────────────────────────────────────────

local function signed(points)
    if points > 0 then return "+" .. points end
    return tostring(points)
end

-- The lines to draw for a breakdown `b`: `{ text, right, tone }` each, the parts, the total, the
-- word's line and the hint. Built once per breakdown (the panel keeps them).
local function rowsOf(b)
    local out = {}
    for _, line in ipairs(b.lines) do
        out[#out + 1] = { text = line.text, right = signed(line.points), tone = "plain" }
    end
    out[#out + 1] = { text = L["Score"], right = tostring(b.score), tone = "plain", total = true }
    out[#out + 1] = { text = b.from, tone = "plain" }
    if b.hint then out[#out + 1] = { text = b.hint, tone = "muted" } end
    return out
end

local function paintLines(p, rows, m)
    local w = WIN.LEFT_W - K.SCROLL_W
    for i, r in ipairs(rows) do
        local row = p.lines[i]
        if not row then
            row = newLine(p.content)
            p.lines[i] = row
        end
        NS.WindowRows.ApplyRowFont(row, m.fontSize, m.font)
        row:ClearAllPoints()
        row:SetPoint("TOPLEFT", p.content, "TOPLEFT", 0, -(i - 1) * m.height)
        row:SetSize(w, m.height)
        row.cells.text.text:SetText(r.text)
        row.cells.points.text:SetText(r.right or "")
        NS.WindowRows.SetTone(row.cells.text.text, r.tone)
        NS.WindowRows.SetTone(row.cells.points.text, r.tone)
        row:Show()
    end
    for i = #rows + 1, #p.lines do p.lines[i]:Hide() end
    p.content:SetSize(w, math.max(1, #rows * m.height))
end

-- ── sizing ──────────────────────────────────────────────────────────────────────────────────

local function windowHeight(f)
    local h = f:GetHeight()
    if type(h) ~= "number" or h <= 0 then h = f.dwH or WIN.HEIGHT end
    return h
end

--- The panel's height for the window `f` at row height `rowH`: the header, the badge and
--- C.ITEM_SEARCH.PANEL.LINES lines, less what the Matches list's MIN_ROWS rows need, down to the
--- header, the badge and one line.
--- @param f table
--- @param rowH number
--- @return number
function IVP.Height(f, rowH)
    local full = LINES_TOP + P.LINES * rowH + P.GAP
    local least = LINES_TOP + rowH
    local room = windowHeight(f) - columnTop() - columnBottom() - P.MIN_ROWS * rowH - P.GAP
    return math.max(least, math.min(full, room))
end

-- The Matches list ends above the panel while it shows, at the footer otherwise.
local function placeMatches(f, shown)
    local s = f.matchScroll
    s:ClearAllPoints()
    s:SetPoint("TOPLEFT", f.matchHead, "BOTTOMLEFT", 0, -2)
    if shown then
        s:SetPoint("BOTTOMLEFT", f.verdict, "TOPLEFT", 0, P.GAP)
    else
        s:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", K.INSET, columnBottom())
    end
end

-- ── painting ────────────────────────────────────────────────────────────────────────────────

-- What the panel drew last: the item, the count, the verdict generation, the gear signature it was
-- judged under (gear only), the breakdown and its rows, whether it was settled and, while it was not
-- and retries were left, when to work it out again.
local kept = { item = nil, total = nil, gen = nil, gearSig = nil, b = nil, rows = nil, settled = true, retryAt = nil }
-- The retries spent on the item shown; a new item shown (IVP.Paint) starts them again.
local tries = 0

local function now()
    return type(GetTime) == "function" and GetTime() or 0
end

local function fresh(itemID, total)
    if not (kept.b and kept.item == itemID and kept.total == total and kept.gen == IVD.Generation()) then return false end
    if kept.gearSig ~= nil and IVD.GearSignature() ~= kept.gearSig then return false end
    if kept.settled then return true end
    -- unsettled: kept until its retry is due, and with the retries spent, worked out on each repaint
    return kept.retryAt ~= nil and now() < kept.retryAt
end

-- An unsettled breakdown (the item's info or its gear verdict still loading): ask the client for the
-- item and repaint C.ITEM_SEARCH.VERDICT.RETRY seconds on, at most PANEL.RETRIES times each time the
-- item is shown.
local repaint
local function retryLater(itemID)
    if tries >= P.RETRIES then return nil end
    tries = tries + 1
    Compat.RequestItem(itemID)
    C_Timer.After(C.ITEM_SEARCH.VERDICT.RETRY, function() repaint() end)
    return now() + C.ITEM_SEARCH.VERDICT.RETRY
end

local function breakdownFor(itemID, total)
    if fresh(itemID, total) then return kept.b, kept.rows end
    local facts = IS.Get(itemID)
    local b, settled, gearSig = IVD.Breakdown(itemID, facts, IS.Me(facts and facts.ranks))
    kept.item, kept.total, kept.gen, kept.gearSig = itemID, total, IVD.Generation(), gearSig
    kept.b, kept.rows, kept.settled = b, rowsOf(b), settled
    kept.retryAt = (not settled) and retryLater(itemID) or nil
    return kept.b, kept.rows
end

local function paintBadge(p, b)
    local tip = IST()
    local st = p.badge
    if not st then return end
    tip.FillBadge(st, tip.Badge(b))
    local wl = st.boxL:GetWidth()
    wl = type(wl) == "number" and wl or 0
    st.boxR:ClearAllPoints()
    st.boxR:SetPoint("TOPLEFT", p, "TOPLEFT", 4 + wl, -BADGE_TOP)
    tip.ShowBadge(st, true)
end

local function hide(f)
    local p = f.verdict
    if p:IsShown() then p:Hide() end
    placeMatches(f, false)
    p.dwItem, p.dwTotal = nil, nil
    return false
end

--- Paint the panel on the window `f` for `itemID` (the item the window shows, or nil) at the row
--- metrics `m` (NS.WindowRows.Metrics'): shown while you hold the item, the Matches list above it;
--- hidden otherwise, the Matches list to the footer. Answers whether it shows.
--- @param f table the Item Search window (IVP.Build's `f.verdict` on it)
--- @param itemID number|nil
--- @param m table
--- @return boolean
function IVP.Paint(f, itemID, m)
    if not (f and f.verdict) then return false end
    if not itemID then return hide(f) end
    local _, total = Compat.ItemCount(itemID)
    if total <= 0 then return hide(f) end
    local p = f.verdict
    if p.dwItem ~= itemID then tries = 0 end
    local b, rows = breakdownFor(itemID, total)
    p:SetHeight(IVP.Height(f, m.height))
    ISG.PaintHeader(p.head, { title = L["Verdict"], note = L["You have %d"]:format(total) })
    paintBadge(p, b)
    paintLines(p, rows, m)
    p.dwItem, p.dwTotal, p.dwBreakdown = itemID, total, b
    p:Show()
    placeMatches(f, true)
    return true
end

--- The panel's lines on screen now, `{ text, right }` each in order (for the tests).
--- @param f table
--- @return table
function IVP.Lines(f)
    local out = {}
    local p = f and f.verdict
    if not (p and p:IsShown()) then return out end
    for _, row in ipairs(p.lines) do
        if row:IsShown() then
            out[#out + 1] = { text = row.cells.text.text:GetText(), right = row.cells.points.text:GetText() }
        end
    end
    return out
end

-- ── events: a bag, bank or verdict change while the window is open ──────────────────────────

local pending = false

function repaint()
    pending = false
    local W = NS.ItemSearchWindow
    if not (W and W.IsShown()) then return end
    local f = W.Frame()
    IVP.Paint(f, W.ShownItem(), NS.WindowRows.Metrics())
end

--- A bag, bank or verdict event: repaint the panel alone, at most once each
--- C.ITEM_SEARCH.PANEL.THROTTLE seconds, and only while the window shows an item.
function NS.addon.OnItemSearchPanelEvent()
    if pending then return end
    local W = NS.ItemSearchWindow
    if not (W and W.IsShown() and W.ShownItem()) then return end
    pending = true
    C_Timer.After(P.THROTTLE, repaint)
end

-- WoW Forever's alone; each event is shared with its other rows through core/DropWatcher.lua's
-- dispatcher (the verdict's own events: modules/ItemSearchVerdict.lua, which bumps the memo first).
for _, event in ipairs({ "BAG_UPDATE_DELAYED", "PLAYERBANKSLOTS_CHANGED", "QUEST_LOG_UPDATE", "QUEST_TURNED_IN",
    "SKILL_LINES_CHANGED", "TRADE_SKILL_SHOW", "PLAYER_LEVEL_UP", "NEW_RECIPE_LEARNED" }) do
    NS.FEATURE_EVENTS[#NS.FEATURE_EVENTS + 1] = { event, "OnItemSearchPanelEvent", clients = { "forever" } }
end

-- Your gear moved: GearChanged, sent once NS.Gear's snapshot was rebuilt under its new signature
-- (not PLAYER_EQUIPMENT_CHANGED, which comes before that rebuild). The bus receiver is tracked, so
-- the stand-down takes it down and the stand-up replays it (NS.Bus.tracked); on Retail the window
-- never shows, so the handler answers at once.
local target = NS.Bus:NewTarget()
if target then
    target:RegisterMessage(NS.MSG.GEAR_CHANGED, function() NS.addon.OnItemSearchPanelEvent() end)
end
