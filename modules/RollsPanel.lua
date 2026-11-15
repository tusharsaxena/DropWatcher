local _, NS = ...
-- modules/RollsPanel.lua — the Rolls panel (rolls panel design, plan RX-17): a small read-only panel
-- docked beside the window that lists every watched roll and every player's roll on it, while loot
-- is rolled and for a short time after. What it says is modules/RollsPanelRows.lua's (pure); this
-- file is the frame edge and the lifecycle.
--
-- THE ITEMS (owner ruling 1) are Rolling now's: NS.WindowPending.Items(), the shown feed's pending
-- items past the feed's own gates, less a master-loot hold (kind `ml`, which rolls nothing). The
-- panel keeps a block per roll it has seen, in the order the rolls started, so a roll the store
-- has closed (a won roll leaves Pending at once) still shows its winner: the block keeps the item
-- table the store handed out, whose final roll the store wrote before it closed it. A block whose
-- item the store still holds but Rolling now no longer lists (`rolls.show` off, test mode turned
-- on), or a test sample the store let go (test mode turned off), leaves at once, with no linger;
-- a sample's id is never kept as left, since the next test mode numbers its samples from 1 again.
--
-- THE LIFECYCLE (design §3.4). PendingChanged reconciles the blocks: a new roll adds one (and
-- clears the close button's dismissal); a roll that is over (won, everyone passed, expired, or
-- closed by the store) is `done` and leaves `rolls.panel.linger` seconds later (0: at once). While
-- the pointer is over the panel nothing leaves, and every finished roll's count starts over when it
-- leaves. When the last block leaves the panel hides, and WindowAutoClose's count starts over
-- (AC.Bump): it treats a panel with blocks as not idle (HasBlocks), so the window waits for it.
-- The blocks are tracked while the window is closed or minimized, and the panel shows with the
-- window again while it holds any. It never opens the window itself (RX-16 does that).
--
-- SHOWN while `rolls.panel.enabled` is on, the addon is up, the window is shown and not minimized,
-- the close button has not dismissed it since the last roll started, and it holds a block or was
-- shown by hand (`/dw rolls`, RP.Toggle: an empty panel reads `No rolls right now`, and stays until
-- closed). Its close button hides it until the next roll starts.
--
-- THE DOCK (design §3.1). A child of the window frame (so it hides, scales and fades with it), in
-- the window's strata at its docked level (frame-layering-§3, as the Offer panel docked), in the
-- window's skin (NS.ApplySkin's panel, edge and title band; the title and close on the band through
-- NS.Skin.Header). Its TOPLEFT on the window's TOPRIGHT, RP.GAP out (`right`), or its TOPRIGHT on
-- the window's TOPLEFT (`left`): `rolls.panel.side`, flipped when the screen has no room there
-- (RollsPanelRows.Side, in pixels: the window's edges and the panel's width at the window's
-- effective scale, the screen at UIParent's). Re-checked on every paint: the window's show, move,
-- resize, layout and minimize (Window.AddVisibilityListener, Window.AddGeometryListener).
-- RP.WIDTH wide (RP.WIDTH_COMPACT in the compact layout); as tall as its blocks, never taller than
-- the window: beyond that its body scrolls (a scroll frame under the title band, its bar shown only
-- then).
--
-- RAID MODE (design §3.3, plan RX-18): a group of more than five (RollsPanelRows.IsRaid on
-- NS.Compat.GroupSize, read on every paint), or a watched roll of more than five players (a roll
-- lists the group's players, so that many is a raid's too; RX-19: the simulated raid roll's raiders
-- are no group's members, and test mode's sample roll is nine players with no group at all). The
-- title reads `Rolls · N`; one block is open (RollsPanelRows.PickOpen); the rest are headers with
-- the count line, a resolved one dimmed with its winner. A closed header the player clicks opens
-- (`sticky`) until its roll is over; with `rolls.panel.foldInRaid` on, Pass and Waiting are one line
-- each, hovering lists every name, and a click lists that group's players for that block (the
-- block's `unfolded`).
--
-- THE LAYOUT. Every block open (the dungeon layout; raid mode opens one): the header (the
-- item's icon, its name in its quality color, cut by the font string, the time left or `done`), the
-- countdown bar under an open roll's header (the time left over the longest time left the block
-- has read), a row per player (RollsPanelRows.Rows: the choice's mark, the name in class color,
-- `[YOU]`, the roll; the winner's row washed in the skin's accent), the result line once it is
-- over, and your verdict at the foot. Headers and lines come from two pools (NS.Pool): a repaint
-- makes no frame once the pools hold enough. One RP.TICK ticker runs while the panel is shown with
-- an open roll, for the time left and the bar.

NS.RollsPanel = NS.RollsPanel or {}
local RP = NS.RollsPanel
local L = NS.L
local C = NS.Constants
local K = NS.Constants.WINDOW

local TAG = "UI"

RP.WIDTH = 250        -- the panel's width, in the window's units (design §3.1)
RP.WIDTH_COMPACT = 220   -- in the compact layout
RP.GAP = 3            -- between the window and the panel
RP.PAD = 8            -- inside the panel
RP.TOP = K.POPOVER_TOP   -- the title band and the gap under it
RP.HEADER_H = 18      -- a block's header
RP.ICON = 16          -- the header's item icon
RP.BAR_H = 3          -- the countdown bar
RP.LINE_H = 16        -- a player's row, the result line, the foot
RP.BLOCK_GAP = 8      -- between two blocks
RP.TICK = 1           -- the time left's repaint
RP.LINGER_MAX = 60

local panel           -- built on its first show
local blocks = {}     -- the blocks, in the order the rolls started: { id, item, at, done, gone, total, timer, held }
local byId = {}       -- [item id] = its block
local left = {}       -- [item id] = true once its block has left: never added again
local manual = false  -- shown by hand (`/dw rolls`): stays with no block
local dismissed = false   -- the close button hid it: until the next roll starts
local sticky          -- raid mode: the block the player clicked open, while its roll runs
local ticker
local paint           -- defined with the painting below

local function stoodDown() return NS.IsStoodDown ~= nil and NS.IsStoodDown() end

local function enabled() return NS.Setting("rolls.panel.enabled") ~= false end

local function lingerSeconds()
    local v = NS.Setting("rolls.panel.linger")
    if type(v) ~= "number" then return NS.C.PROFILE.rolls.panel.linger end
    return math.max(0, math.min(RP.LINGER_MAX, v))
end

local function num(v) return type(v) == "number" and v or nil end

local function width()
    local WC = NS.WindowCompact
    return (WC and WC.Mode() == "compact") and RP.WIDTH_COMPACT or RP.WIDTH
end

-- A plain geometry read, a number or nil (an unplaced frame, a secret, the mock's catch-all).
local function geom(f, method)
    local fn = f and f[method]
    local v = type(fn) == "function" and fn(f) or nil
    if NS.Compat.IsSecret(v) then return nil end
    return num(v)
end

-- ── the blocks ──────────────────────────────────────────────────────────────────────────────

-- The rolls the panel follows: Rolling now's items, less a master-loot hold.
local function watched()
    local out = {}
    if NS.WindowPending.None() then return out end
    for _, item in ipairs(NS.WindowPending.Items()) do
        if item.kind ~= "ml" then out[#out + 1] = item end
    end
    return out
end

local function hovered() return panel ~= nil and panel:IsShown() and panel:IsMouseOver() == true end

local function cancel(b)
    if b.timer then b.timer:Cancel() end
    b.timer = nil
end

local function drop(b)
    cancel(b)
    for i, x in ipairs(blocks) do
        if x == b then table.remove(blocks, i) break end
    end
    byId[b.id] = nil
end

-- A finished block leaves: after the linger, unless the pointer is over the panel.
local function leave(b)
    if hovered() then
        b.held = true
        return
    end
    drop(b)
    -- a test sample's id (`test:<n>`) comes back the next time test mode starts
    if not b.item.test then left[b.id] = true end
    NS.Debug(TAG, "rolls panel: roll %s left (%d left)", tostring(b.id), #blocks)
    if #blocks == 0 then NS.WindowAutoClose.Bump() end
    paint()
end

local function startLinger(b)
    cancel(b)
    b.held = false
    local s = lingerSeconds()
    if s <= 0 then return leave(b) end
    b.timer = C_Timer.NewTimer(s, function()
        b.timer = nil
        if byId[b.id] == b then leave(b) end
    end)
end

local function finish(b, gone)
    b.done, b.gone = true, gone
    startLinger(b)
end

local function byStart(a, b)
    if a.at ~= b.at then return (a.at or 0) < (b.at or 0) end
    return tostring(a.id) < tostring(b.id)
end

-- A roll the panel has not seen yet joins it; answers whether one did.
local function adopt(items)
    local added = false
    for _, item in ipairs(items) do
        local b = byId[item.id]
        if not b and not left[item.id] then
            b = { id = item.id, item = item, at = item.at }
            blocks[#blocks + 1], byId[item.id] = b, b
            added = true
        elseif b then
            b.item = item
        end
    end
    if added then table.sort(blocks, byStart) end
    return added
end

-- Each open block against the store: over, closed by the store, or no longer Rolling now's.
local function settle(shown)
    local stale = {}
    for _, b in ipairs(blocks) do
        if not b.done then
            local item = shown[b.id]
            if item then
                if item.state ~= "open" then stale[#stale + 1] = { b, false } end
            elseif NS.Pending.Get(b.id) or b.item.test then
                -- still held but no longer listed, or a test sample (test mode ended): leaves at once
                stale[#stale + 1] = { b }
            else
                stale[#stale + 1] = { b, true }     -- the store closed it (a won roll)
            end
        end
    end
    for _, e in ipairs(stale) do
        if e[2] == nil then drop(e[1]) else finish(e[1], e[2]) end
    end
end

local function clear()
    for _, b in ipairs(blocks) do cancel(b) end
    blocks, byId, left, sticky = {}, {}, {}, nil
end

-- Read the store again: new rolls join, finished ones start their linger.
local function reconcile()
    if not enabled() or stoodDown() then
        clear()
        return
    end
    local items = watched()
    local shown = {}
    for _, item in ipairs(items) do shown[item.id] = item end
    if adopt(items) then dismissed = false end
    settle(shown)
end

-- ── the frames ──────────────────────────────────────────────────────────────────────────────

local function setTone(fs, tone) NS.WindowRows.SetTone(fs, tone) end

local function faced(parent, template, justify)
    local fs = parent:CreateFontString(nil, "OVERLAY", template or "GameFontHighlightSmall")
    fs:SetJustifyH(justify or "LEFT")
    fs:SetWordWrap(false)
    NS.Skin.Font(fs)
    return fs
end

local function accentPaint(alpha)
    return function(t)
        local r, g, b = NS.SkinColor("accent")
        if r then t:SetColorTexture(r, g, b, alpha) end
    end
end

local onLeave, onHeaderClick, onFoldClick

-- A block's header: the item's icon, its name, the time left, the count line under them (a closed
-- raid header), and the countdown bar under it (an open one). A closed raid header takes a click.
local function newHeader(p)
    local h = CreateFrame("Frame", nil, p)
    h:SetHeight(RP.HEADER_H)
    h.icon = h:CreateTexture(nil, "ARTWORK")
    h.icon:SetSize(RP.ICON, RP.ICON)
    h.icon:SetPoint("TOPLEFT", h, "TOPLEFT", 0, -(RP.HEADER_H - RP.ICON) / 2)
    h.time = faced(h, nil, "RIGHT")
    h.time:SetPoint("RIGHT", h, "TOPRIGHT", 0, -RP.HEADER_H / 2)
    h.name = faced(h, "GameFontNormalSmall")
    h.name:SetPoint("LEFT", h.icon, "RIGHT", 4, 0)
    h.name:SetPoint("RIGHT", h.time, "LEFT", -4, 0)
    h.counts = faced(h)
    h.counts:SetPoint("TOPLEFT", h, "TOPLEFT", RP.ICON + 4, -RP.HEADER_H)
    h.counts:SetPoint("TOPRIGHT", h, "TOPRIGHT", 0, -RP.HEADER_H)
    h:SetScript("OnMouseUp", function(self) onHeaderClick(self) end)
    h:SetScript("OnLeave", function() onLeave() end)
    h.bar = h:CreateTexture(nil, "ARTWORK")
    h.bar:SetHeight(RP.BAR_H)
    h.bar:SetPoint("TOPLEFT", h, "BOTTOMLEFT", 0, -1)
    NS.SkinPaint(h.bar, accentPaint(0.8))
    return h
end

-- One line: a player's row, a folded group, the result line or the foot. `text` holds the mark and
-- the name, `roll` the number at the right, `wash` the winner's gold. A folded group's line takes
-- the pointer: its tooltip lists every name (`foldTip`), a click unfolds it.
local function newLine(p)
    local f = CreateFrame("Frame", nil, p)
    f:SetHeight(RP.LINE_H)
    f.wash = f:CreateTexture(nil, "BACKGROUND")
    f.wash:SetAllPoints(f)
    NS.SkinPaint(f.wash, accentPaint(0.2))
    f.roll = faced(f, nil, "RIGHT")
    f.roll:SetPoint("RIGHT", f, "RIGHT", 0, 0)
    f.text = faced(f)
    f.text:SetPoint("LEFT", f, "LEFT", 0, 0)
    f.text:SetPoint("RIGHT", f.roll, "LEFT", -4, 0)
    NS.Window.AttachTooltip(f, function()
        if f.foldTip then return unpack(f.foldTip) end
    end)
    f:HookScript("OnLeave", function() onLeave() end)
    f:SetScript("OnMouseUp", function(self) onFoldClick(self) end)
    return f
end

local function buildTitle(p)
    p.title = p:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    p.title:SetPoint("TOPLEFT", p, "TOPLEFT", 10, -9)
    p.title:SetText(L["Rolls"])
    NS.Skin.Text(p.title, "heading")   -- gold, in the skin's title face
    p.closeButton = NS.MakeCloseButton(p, function() RP.Close() end)
    if p.closeButton then
        p.closeButton:SetPoint("TOPRIGHT", p, "TOPRIGHT", -6, -6)
        p.closeButton:HookScript("OnLeave", function() onLeave() end)
        NS.Window.AttachTooltip(p.closeButton, function()
            return L["Close the Rolls panel"], NS.TipMarks.Row(L["Until"], L["the next roll starts"]),
                NS.TipMarks.Row(L["Turn off"], L["Show the Rolls panel beside the window on Drops > Rolls > Panel"])
        end)
    end
    -- The band ApplySkin draws carries the title and the close, as the Offer panel's (R5-WIN).
    NS.Skin.Header(p, { title = p.title, right = { p.closeButton } })
end

-- The body under the title band: a scroll frame whose child holds the blocks; its bar shows only
-- while the blocks are taller than the panel may be (paint).
local function buildBody(p)
    local scroll = CreateFrame("ScrollFrame", nil, p, "UIPanelScrollFrameTemplate")
    scroll.scrollBarHideable = true
    local content = CreateFrame("Frame", nil, scroll)
    content:SetSize(1, 1)
    scroll:SetScrollChild(content)
    p.scroll, p.content = scroll, content
    local bar = rawget(scroll, "ScrollBar")
    if bar then NS.Skin.ScrollBar(bar) end   -- the skin's corridor and knob (D2)
    p.bar = bar
    -- The body and its bar take the pointer, so the panel hears no leave when the pointer goes
    -- straight out from them: each restarts the linger itself (design §3.4), as the close button.
    local function holds(f)
        if f and f.HookScript then f:HookScript("OnLeave", function() onLeave() end) end
    end
    holds(scroll)
    holds(bar)
    if bar then
        holds(rawget(bar, "ScrollUpButton"))
        holds(rawget(bar, "ScrollDownButton"))
    end
    p.headerPool, p.linePool = NS.Pool.New(), NS.Pool.New()
end

local function build()
    local win = NS.Window.Frame()
    local p = CreateFrame("Frame", nil, win, "BackdropTemplate")
    p:SetFrameStrata(C.LAYERS.STRATA.WINDOW)
    p:SetSize(RP.WIDTH, RP.TOP + RP.PAD)
    p:EnableMouse(true)
    p:SetClipsChildren(true)
    NS.ApplySkin(p)
    buildTitle(p)
    buildBody(p)
    p.empty = faced(p, "GameFontHighlight", "CENTER")
    p.empty:SetPoint("TOP", p, "TOP", 0, -RP.TOP - 4)
    NS.Skin.Text(p.empty, "text.highlight")
    p.empty:SetText(L["No rolls right now"])
    p:SetScript("OnLeave", function() onLeave() end)
    p:Hide()
    return p
end

-- ── painting ────────────────────────────────────────────────────────────────────────────────

local function screenPx()
    local w = geom(UIParent, "GetWidth")
    return w and w * (geom(UIParent, "GetEffectiveScale") or 1) or nil
end

-- Beside the window, on the side the setting asks for, or the other with no room there.
local function dock(p, win, w)
    local s = geom(win, "GetEffectiveScale") or 1
    local l, r = geom(win, "GetLeft"), geom(win, "GetRight")
    local side = NS.RollsPanelRows.Side(NS.Setting("rolls.panel.side"), l and l * s, r and r * s, w * s,
        screenPx(), RP.GAP * s)
    p:ClearAllPoints()
    if side == "right" then
        p:SetPoint("TOPLEFT", win, "TOPRIGHT", RP.GAP, 0)
    else
        p:SetPoint("TOPRIGHT", win, "TOPLEFT", -RP.GAP, 0)
    end
    p:SetFrameLevel((geom(win, "GetFrameLevel") or 0) + C.LAYERS.LEVEL.DOCKED)
    p.dock = side
end

-- A pooled frame at `y` in the body, as wide as the body (both top corners anchored).
local function place(f, p, y)
    f:ClearAllPoints()
    f:SetPoint("TOPLEFT", p.content, "TOPLEFT", 0, -y)
    f:SetPoint("TOPRIGHT", p.content, "TOPRIGHT", 0, -y)
end

-- One line from row `r` ({ text, tone, roll, winner, fold, tip }) of block `id`.
local function line(p, y, r, id)
    local f = NS.Pool.Acquire(p.linePool, function() return newLine(p.content) end)
    place(f, p, y)
    f.text:SetText(r.text)
    setTone(f.text, r.tone or "plain")
    f.roll:SetText(r.roll and tostring(r.roll) or "")
    setTone(f.roll, r.winner and "accent" or "plain")
    f.wash:SetShown(r.winner == true)
    f.winner = r.winner == true
    f.fold, f.foldTip, f.blockId = r.fold, r.tip, id
    f:EnableMouse(r.fold ~= nil)
    return y + RP.LINE_H
end

-- The header's top row: the icon, the name in its quality color, the time left or `done`.
local function paintTitleRow(h, m)
    h.icon:SetTexture(NS.Compat.ItemIcon(m.link))
    h.name:SetText(m.name)
    local qr, qg, qb = NS.QualityColor(m.quality)
    if qr then h.name:SetTextColor(qr, qg, qb) else setTone(h.name, "plain") end
    h.time:SetText(m.time or "")
    setTone(h.time, m.done and "muted" or "plain")
end

-- A closed raid header's count line (the result once over, dimmed with the header).
local function paintCounts(h, m)
    h.counts:SetText(m.counts or "")
    h.counts:SetShown(m.counts ~= nil)
    setTone(h.counts, m.dim and "muted" or "plain")
    h:SetAlpha(m.dim and 0.5 or 1)
end

local function paintHeader(p, y, b, m)
    local h = NS.Pool.Acquire(p.headerPool, function() return newHeader(p.content) end)
    place(h, p, y)
    paintTitleRow(h, m)
    paintCounts(h, m)
    if m.left then b.total = math.max(b.total or 0, m.left) end
    h.frac = (m.open and not m.done) and NS.RollsPanelRows.Fraction(m.left, b.total) or nil
    h.bar:SetShown(h.frac ~= nil)
    h.blockId, h.open, h.done, h.dim = b.id, m.open, m.done, m.dim == true
    h:EnableMouse(m.counts ~= nil and not m.done)   -- a closed raid header opens on a click
    local tall = RP.HEADER_H + (m.counts and RP.LINE_H or 0)
    h:SetHeight(tall)
    return y + tall + (h.frac and RP.BAR_H + 2 or 0)
end

-- One block, top to bottom, from `y`; answers the y under it. A closed raid block is its header.
local function paintBlock(p, y, b, view)
    local open = not view.raid or b.id == view.openId
    local m = NS.RollsPanelRows.Block(b.item, { now = view.now, gone = b.gone, open = open, raid = view.raid,
        fold = view.fold, unfolded = b.unfolded })
    y = paintHeader(p, y, b, m)
    if not open then return y end
    for _, r in ipairs(m.rows) do
        r.text = r.mark .. " " .. r.text
        y = line(p, y, r, b.id)
    end
    if m.result then y = line(p, y, m.result) end
    return line(p, y, m.foot)
end

-- Raid mode's open block (RollsPanelRows.PickOpen); a click's `sticky` lapses once its roll is over.
local function pickOpen(now)
    local RC, list = NS.RollCells, {}
    for i, b in ipairs(blocks) do
        local roll = type(b.item.roll) == "table" and b.item.roll or nil
        list[i] = { id = b.id, done = b.done or NS.RollsPanelRows.IsDone(b.item, b.gone),
            pending = NS.RollsPanelRows.YoursPending(roll), left = RC.Left(roll, now, b.item.rollID) }
    end
    local id = NS.RollsPanelRows.PickOpen(list, sticky)
    if id ~= sticky then sticky = nil end
    return id
end

-- The most players on one block's roll table.
local function mostRollers()
    local n = 0
    for _, b in ipairs(blocks) do
        local roll = b.item.roll
        local rows = type(roll) == "table" and type(roll.rolls) == "table" and #roll.rolls or 0
        if rows > n then n = rows end
    end
    return n
end

-- What this paint draws: raid mode or not, its open block, the fold, the clock and the width.
local function viewOf()
    local now = NS.Compat.LootHistoryNow()
    local raid = NS.RollsPanelRows.IsRaid(math.max(num(NS.Compat.GroupSize()) or 0, mostRollers()))
    return { now = now, raid = raid, w = width(), openId = raid and pickOpen(now) or nil,
        fold = raid and NS.Setting("rolls.panel.foldInRaid") ~= false }
end

-- The body's height `y` against the most the panel may be: the bar shows past it, the body narrows
-- for it, and each countdown bar is laid at the body's width.
local function fit(p, y, w, cap)
    local h = RP.TOP + y + RP.PAD
    local over = cap ~= nil and cap > 0 and h > cap
    local inner = w - 2 * RP.PAD - (over and K.SCROLL_W + 4 or 0)
    p.scroll:ClearAllPoints()
    p.scroll:SetPoint("TOPLEFT", p, "TOPLEFT", RP.PAD, -RP.TOP)
    p.scroll:SetPoint("BOTTOMRIGHT", p, "BOTTOMRIGHT", -(w - RP.PAD - inner), RP.PAD)
    p.content:SetSize(inner, math.max(1, y))
    if p.bar then p.bar:SetShown(over) end
    if not over then p.scroll:SetVerticalScroll(0) end
    for _, hd in ipairs(p.headerPool.active) do
        if hd.frac then hd.bar:SetWidth(math.max(1, hd.frac * inner)) end
    end
    p.overflow = over
    return over and cap or h
end

local function anyOpen()
    for _, b in ipairs(blocks) do
        if not b.done then return true end
    end
    return false
end

local function stopTicker()
    if ticker then ticker:Cancel() end
    ticker = nil
end

local function syncTicker()
    local want = panel ~= nil and panel:IsShown() and anyOpen()
    if want and not ticker then
        ticker = C_Timer.NewTicker(RP.TICK, function() paint() end)
    elseif not want then
        stopTicker()
    end
end

local function wanted()
    if not enabled() or stoodDown() or dismissed then return false end
    local W = NS.Window
    if not W.IsShown() or W.IsMinimized() then return false end
    return #blocks > 0 or manual
end

paint = function()
    if not wanted() then
        if panel then panel:Hide() end
        return syncTicker()
    end
    local win = NS.Window.Frame()
    panel = panel or build()
    NS.Pool.ReleaseAll(panel.headerPool)
    NS.Pool.ReleaseAll(panel.linePool)
    local view, y = viewOf(), 0
    for i, b in ipairs(blocks) do
        if i > 1 then y = y + RP.BLOCK_GAP end
        y = paintBlock(panel, y, b, view)
    end
    panel.raid = view.raid
    panel.title:SetText(NS.RollsPanelRows.Title(view.raid, #blocks))
    panel.empty:SetShown(#blocks == 0)
    if #blocks == 0 then y = y + RP.LINE_H + 4 end
    panel:SetSize(view.w, fit(panel, y, view.w, geom(win, "GetHeight")))
    dock(panel, win, view.w)
    panel:Show()
    syncTicker()
end

-- The pointer left the panel (or its close button, which takes the mouse): every finished roll's
-- count starts over, so nothing leaves while it is read. The finished blocks are listed first: a
-- linger of 0 leaves at once, and a leave takes its block out of `blocks`.
onLeave = function()
    if hovered() then return end
    local done = {}
    for _, b in ipairs(blocks) do
        if b.done then done[#done + 1] = b end
    end
    for _, b in ipairs(done) do
        if byId[b.id] == b then startLinger(b) end
    end
end

-- A closed raid header was clicked: it opens, and stays open until its roll is over.
onHeaderClick = function(h)
    local b = byId[h.blockId]
    if not (panel and panel.raid) or h.open or not b or b.done then return end
    sticky = b.id
    paint()
end

-- A folded group's line was clicked: that block lists the group's players.
onFoldClick = function(f)
    local b = f.fold and byId[f.blockId]
    if not b then return end
    b.unfolded = b.unfolded or {}
    b.unfolded[f.fold] = true
    paint()
end

-- ── the surface ─────────────────────────────────────────────────────────────────────────────

--- Read the store again and repaint (PendingChanged, a `rolls.panel.*` row, the window's show and
--- geometry). The panel hides when it has nothing to show.
function RP.Refresh()
    reconcile()
    paint()
end

--- Whether the panel holds a block (a roll running, or finished and lingering): WindowAutoClose's
--- idle check (modules/WindowAutoClose.lua) waits while it does.
--- @return boolean
function RP.HasBlocks() return #blocks > 0 end

--- @return boolean
function RP.IsShown() return panel ~= nil and panel:IsShown() == true end

--- The close button: hidden until the next roll starts (a hand-shown panel too).
function RP.Close()
    manual, dismissed = false, true
    stopTicker()
    if panel then panel:Hide() end
end

--- `/dw rolls`: hide a shown panel, or show it by hand beside the shown window (empty, it reads
--- `No rolls right now`, and stays until closed). Says why when it cannot show.
--- @return boolean shown
function RP.Toggle()
    if RP.IsShown() then
        RP.Close()
        return false
    end
    if not enabled() then
        NS.Print(L["The Rolls panel is off: turn on Show the Rolls panel beside the window on Drops > Rolls > Panel."])
        return false
    end
    if not NS.Window.IsShown() or NS.Window.IsMinimized() then
        NS.Print(L["The Rolls panel shows beside the window: open the window first."])
        return false
    end
    manual, dismissed = true, false
    RP.Refresh()
    return RP.IsShown()
end

--- The built panel and what it drew, for the suites: { panel, headers, lines, blocks, raid }, or nil
--- before the build.
--- @return table|nil
function RP.Drawn()
    if not panel then return nil end
    return { panel = panel, headers = panel.headerPool.active, lines = panel.linePool.active, blocks = blocks,
        raid = panel.raid == true }
end

-- ── listening ───────────────────────────────────────────────────────────────────────────────

local target = NS.Bus:NewTarget()

local function listen()
    if not target then return end
    -- An item opened, changed (its rolls, your verdict) or closed.
    target:RegisterMessage(NS.MSG.PENDING_CHANGED, function() RP.Refresh() end)
end
listen()

-- The window shows or hides (the panel goes with it, a child), moves, resizes, rescales or
-- minimizes: the panel follows, and re-checks its side.
NS.Window.AddVisibilityListener(function()
    if not stoodDown() then paint() end
end)
NS.Window.AddGeometryListener(function()
    if not stoodDown() then paint() end
end)

NS.STAND_DOWN[#NS.STAND_DOWN + 1] = function()
    if target and not NS.Bus.tracked then target:UnregisterAllMessages() end
    clear()
    manual, dismissed = false, false
    stopTicker()
    if panel then panel:Hide() end
end
NS.STAND_UP[#NS.STAND_UP + 1] = function()
    if not NS.Bus.tracked then listen() end
end
