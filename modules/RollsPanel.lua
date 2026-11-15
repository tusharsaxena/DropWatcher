local _, NS = ...
-- modules/RollsPanel.lua — the Rolls panel (rolls panel design, plan RX-17; round 2, the 2026-11-15
-- design part A, plan RX-21): a small read-only panel docked beside the window that lists every
-- watched roll and every player's roll on it, while loot is rolled and for a short time after. What
-- it says is modules/RollsPanelRows.lua's (pure); this file is the frame edge and the lifecycle.
--
-- THE ITEMS (owner ruling 1) are Rolling now's: NS.WindowPending.Items(), the shown feed's pending
-- items past the feed's own gates, less a master-loot hold (kind `ml`, which rolls nothing). The
-- panel keeps a block per roll it has seen, in the order the rolls started, so a roll the store
-- has closed (a won roll leaves Pending at once) still shows its winner: the block keeps the item
-- table the store handed out, whose final roll the store wrote before it closed it. A block whose
-- item the store still holds but Rolling now no longer lists (`rolls.show` off, test mode turned
-- on), or a test sample the store let go (test mode turned off), leaves at once, with no linger;
-- a sample's id is never kept as left, since the next test mode numbers its samples from 1 again.
-- A finished live roll still lingering leaves at once too when test mode turns on or a simulation
-- starts (RX-23): a real result never shows under the TEST or SIM strip.
-- A roll that joined during a simulation (`sim`) leaves at once, open or finished, when the
-- simulation stops (NS.Sim:OnStop): placeholder data never shows without its strip (preview-mode).
--
-- THE LIFECYCLE (round 2 ruling A9: a panel-level linger). PendingChanged reconciles the blocks: a
-- new roll adds one (and clears the close button's dismissal); a roll that is over (won, everyone
-- passed, expired, or closed by the store) is `done` and stays, its winner washed and its result
-- line read, while any other roll runs. Once every block is done the panel counts
-- `rolls.panel.linger` seconds (0: at once) and then closes, every block with it; a new roll in
-- that time cancels the count. While the pointer is over the panel nothing closes, and the count
-- starts over when it leaves. When the blocks leave, WindowAutoClose's count starts over (AC.Bump):
-- it treats a panel with blocks as not idle (HasBlocks), so the window waits for it. The blocks are
-- tracked while the window is closed or minimized, and the panel shows with the window again while
-- it holds any. It never opens the window itself (RX-16 does that).
--
-- SHOWN while `rolls.panel.enabled` is on (its rows need `rolls.show`), the addon is up, the window
-- is shown and not minimized, the close button has not dismissed it since the last roll started,
-- and it holds a block or was shown by hand (`/dw rolls`, RP.Toggle: an empty panel reads `No rolls
-- right now`, and stays until closed). Its close button hides it until the next roll starts.
--
-- THE DOCK (design §3.1, ruling A10). A child of the window frame (so it hides, scales and fades
-- with it), in the window's strata at its docked level (frame-layering-§3, as the Offer panel
-- docked), in the window's skin (NS.ApplySkin's panel, edge and title band; the title `Rolls`, no
-- count (ruling A8), Expand all, Collapse all and the close on the band through NS.Skin.Header).
-- Flush with the window (RP.GAP 0) and top-aligned: its TOPLEFT on the window's TOPRIGHT (`right`),
-- or its TOPRIGHT on the window's TOPLEFT (`left`): `rolls.panel.side`, flipped when the screen has
-- no room there (RollsPanelRows.Side, in pixels: the window's edges and the panel's width at the
-- window's effective scale, the screen at UIParent's). The Offer panel docked on that side (the one
-- the player opened to act) sends it to the other side when that fits, else it waits hidden until
-- the Offer panel closes or moves (RollsPanelRows.Beside, RX-20; the Offer panel repaints it).
-- Re-checked on every paint: the window's show, move, resize, layout and minimize
-- (Window.AddVisibilityListener, Window.AddGeometryListener). RP.WIDTH wide (RP.WIDTH_COMPACT in the
-- compact layout, ruling A3); as tall as its blocks, never taller than the window: beyond that its
-- body scrolls (a scroll frame under the title band, its bar shown only then).
--
-- THE MODE STRIP (ruling A1, preview-mode: a frame with a title band is a window, and every display
-- of placeholder data says so). In test mode LibKa0s Widgets' TestStrip (NS.MakeTestStrip) sits
-- directly under the title band, full width, saying the panel's own words; during a simulation its
-- sim flavor does. The library docks it (`dock = "title"`, Widgets minor 27) under `p.titleBar`, a
-- bare frame NS.Skin.Header lays on the band's rect in every skin; the body moves down by the strip's
-- `BodyOffset` while one shows; the band carries no mode word.
--
-- RAID MODE (design §3.3, plan RX-18): a group of more than five (RollsPanelRows.IsRaid on
-- NS.Compat.GroupSize, read on every paint), or a watched roll of more than five players (a roll
-- lists the group's players, so that many is a raid's too; RX-19: the simulated raid roll's raiders
-- are no group's members, and test mode's sample roll is nine players with no group at all). With
-- `rolls.panel.foldInRaid` on, Pass and Waiting are one line each, hovering lists every name, and a
-- click lists that group's players for that block (the block's `unfolded`). Round 2 removed its
-- one-open rule: every block starts open in any group size.
--
-- THE LAYOUT (round 2). Each block is an item header in the window's section-header look (the list
-- box band, the gold chevron, as Rolling now's): the item's icon, its name in its quality color,
-- cut by the font string, the time left or `done`; a click collapses or expands it (ruling A2: a
-- manual state that sticks while the roll is listed), and its tooltip is the item's own with every
-- roll under it. The countdown bar under an open roll's header (the time left over the longest time
-- left the block has read), a row per player (RollsPanelRows.Rows: the choice's mark, the name in
-- class color, `[YOU]`, the roll on every row that rolled), alternately shaded (`list.stripe`,
-- ruling A5), the winner's row washed in the skin's accent, each with its player's tooltip; the
-- result line once it is over. No verdict line (ruling A4). A collapsed block is its header with the
-- count line (or its result) under it. Headers and lines come from two pools (NS.Pool): a repaint
-- makes no frame once the pools hold enough. One RP.TICK ticker runs while the panel is shown with
-- an open roll, for the time left and the bar.

NS.RollsPanel = NS.RollsPanel or {}
local RP = NS.RollsPanel
local L = NS.L
local C = NS.Constants
local K = NS.Constants.WINDOW

local TAG = "UI"

RP.WIDTH = 290        -- the panel's width, in the window's units (ruling A3)
RP.WIDTH_COMPACT = 250   -- in the compact layout
RP.GAP = 0            -- between the window and the panel: flush (ruling A10)
RP.PAD = 8            -- inside the panel
RP.TOP = K.POPOVER_TOP   -- the title band and the gap under it
RP.HEADER_H = K.GROUP_H   -- an item header, the window's section header's height
RP.ICON = 16          -- the header's item icon
RP.BAR_H = 3          -- the countdown bar
RP.LINE_H = 16        -- a player's row, the result line, a collapsed header's count line
RP.BLOCK_GAP = 6      -- between two blocks
RP.TICK = 1           -- the time left's repaint
RP.LINGER_MAX = 60

local panel           -- built on its first show
local blocks = {}     -- the blocks, in the order the rolls started: { id, item, at, sim, done, gone, total, collapsed, unfolded }
local byId = {}       -- [item id] = its block
local left = {}       -- [item id] = true once its block has left: never added again
local manual = false  -- shown by hand (`/dw rolls`): stays with no block
local dismissed = false   -- the close button hid it: until the next roll starts
local linger          -- the panel's countdown once every block is done
local held = false    -- the countdown ran out while the pointer was over the panel
local ticker
local looks = 0       -- bumped on every skin switch: the kept rows carry the skin's colors
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

local function dropLinger()
    if linger then linger:Cancel() end
    linger, held = nil, false
end

local function drop(b)
    for i, x in ipairs(blocks) do
        if x == b then table.remove(blocks, i) break end
    end
    byId[b.id] = nil
end

local function allDone()
    if #blocks == 0 then return false end
    for _, b in ipairs(blocks) do
        if not b.done then return false end
    end
    return true
end

-- The countdown ran out: every block leaves and the panel closes, unless the pointer is over it.
local function closeAll()
    linger = nil
    if hovered() then
        held = true
        return
    end
    for _, b in ipairs(blocks) do
        -- a test sample's id (`test:<n>`) comes back the next time test mode starts
        if not b.item.test then left[b.id] = true end
    end
    NS.Debug(TAG, "rolls panel: %d finished rolls left", #blocks)
    blocks, byId, held = {}, {}, false
    NS.WindowAutoClose.Bump()
    paint()
end

-- Every block done: the countdown runs (once; a running or held one is left alone). A roll still
-- running cancels it.
local function armLinger()
    if not allDone() then return dropLinger() end
    if linger or held then return end
    local s = lingerSeconds()
    if s <= 0 then return closeAll() end
    linger = C_Timer.NewTimer(s, closeAll)
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
            b = { id = item.id, item = item, at = item.at, sim = not item.test and NS.Sim:IsActive() == true }
            blocks[#blocks + 1], byId[item.id] = b, b
            added = true
        elseif b then
            b.item = item
        end
    end
    if added then table.sort(blocks, byStart) end
    return added
end

-- A finished block from outside the mode now on: a live roll's result while test mode or a
-- simulation runs. Placeholder data and real results never
-- share a strip (preview-mode), and test mode's samples never finish, so its linger would never end.
local function foreign(b)
    if NS.State.testMode == true then return not b.item.test end
    return not b.sim and not b.item.test and NS.Sim:IsActive() == true
end

-- Each block against the store: an open one over, closed by the store, or no longer Rolling now's;
-- a finished one from outside the mode now on leaves at once, its id kept as left.
local function settle(shown)
    local stale = {}
    for _, b in ipairs(blocks) do
        if b.done then
            if foreign(b) then
                if not b.item.test then left[b.id] = true end
                stale[#stale + 1] = b
            end
        else
            local item = shown[b.id]
            if item then
                if item.state ~= "open" then b.done, b.gone = true, false end
            elseif NS.Pending.Get(b.id) or b.item.test then
                -- still held but no longer listed, or a test sample (test mode ended): leaves at once
                stale[#stale + 1] = b
            else
                b.done, b.gone = true, true     -- the store closed it (a won roll)
            end
        end
    end
    for _, b in ipairs(stale) do drop(b) end
end

-- The simulation is over: its rolls leave at once, their ids kept as left (a live id never recurs).
local function dropSim()
    if NS.Sim:IsActive() == true then return end
    local gone = {}
    for _, b in ipairs(blocks) do
        if b.sim then gone[#gone + 1] = b end
    end
    for _, b in ipairs(gone) do
        left[b.id] = true
        drop(b)
    end
end

local function clear()
    dropLinger()
    blocks, byId, left = {}, {}, {}
end

-- Read the store again: new rolls join, finished ones are marked; the countdown follows.
local function reconcile()
    if not enabled() or stoodDown() then
        clear()
        return
    end
    dropSim()
    local items = watched()
    local shown = {}
    for _, item in ipairs(items) do shown[item.id] = item end
    if adopt(items) then dismissed = false end
    settle(shown)
    armLinger()
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

local onLeave, onHeaderClick, onFoldClick, setAll

-- An item header's tooltip: the item's own, then every roll and the click's hint
-- (RollsPanelRows.HeaderTip), at the row tooltips' place (modules/RowTooltip.lua).
local function headerEnter(h)
    local b = byId[h.blockId]
    if not (b and GameTooltip) then return end
    GameTooltip:SetOwner(h, "ANCHOR_NONE")
    NS.Compat.TooltipHyperlink(GameTooltip, b.item.link)
    local lines = NS.RollsPanelRows.HeaderTip(b.item, NS.Compat.LootHistoryNow(), h.open)
    local tr, tg, tb = NS.Skin.Color("gtip.title")
    GameTooltip:AddLine(lines[1], tr, tg, tb)
    local r, g, bl = NS.Skin.Color("gtip.value")
    for i = 2, #lines do GameTooltip:AddLine(lines[i], r, g, bl, true) end
    GameTooltip:Show()
    NS.RowTooltip.PlaceOrFallback(GameTooltip, h)
end

local function headerLeave()
    if GameTooltip then GameTooltip:Hide() end
    onLeave()
end

-- An item header (ruling A2), the window's section header's look (WindowGroup.NewHeader): the list
-- box band, the gold chevron, then the item's icon, its name and the time left; the count line under
-- the band while collapsed, the countdown bar under it while open. A click toggles the block.
local function newHeader(p)
    local h = CreateFrame("Button", nil, p)
    h:SetHeight(RP.HEADER_H)
    h.fill = h:CreateTexture(nil, "BACKGROUND")
    h.fill:SetPoint("TOPLEFT", h, "TOPLEFT", 0, 0)
    h.fill:SetPoint("TOPRIGHT", h, "TOPRIGHT", 0, 0)
    h.fill:SetHeight(RP.HEADER_H)
    NS.SkinPaint(h.fill, function(t) t:SetColorTexture(NS.SkinColor("list.box")) end)
    h.chevron = h:CreateTexture(nil, "ARTWORK")
    h.chevron:SetSize(10, 10)
    h.chevron:SetPoint("LEFT", h, "TOPLEFT", K.CHEVRON_X, -RP.HEADER_H / 2)
    NS.SkinPaint(h.chevron, function(t) t:SetVertexColor(NS.SkinColor("text.heading")) end)
    h.icon = h:CreateTexture(nil, "ARTWORK")
    h.icon:SetSize(RP.ICON, RP.ICON)
    h.icon:SetPoint("LEFT", h.chevron, "RIGHT", 4, 0)
    h.time = faced(h, nil, "RIGHT")
    h.time:SetPoint("RIGHT", h, "TOPRIGHT", -4, -RP.HEADER_H / 2)
    h.name = faced(h, "GameFontNormalSmall")
    h.name:SetPoint("LEFT", h.icon, "RIGHT", 4, 0)
    h.name:SetPoint("RIGHT", h.time, "LEFT", -4, 0)
    h.counts = faced(h)
    h.counts:SetPoint("TOPLEFT", h, "TOPLEFT", K.CHEVRON_X + 14, -RP.HEADER_H - 1)
    h.counts:SetPoint("TOPRIGHT", h, "TOPRIGHT", -4, -RP.HEADER_H - 1)
    h:SetScript("OnClick", function(self) onHeaderClick(self) end)
    h:SetScript("OnEnter", headerEnter)
    h:SetScript("OnLeave", headerLeave)
    h.bar = h:CreateTexture(nil, "ARTWORK")
    h.bar:SetHeight(RP.BAR_H)
    h.bar:SetPoint("TOPLEFT", h, "BOTTOMLEFT", 0, -1)
    NS.SkinPaint(h.bar, accentPaint(0.8))
    return h
end

-- A line's tooltip: a folded group's every name, or a player's row (RollsPanelRows.RowTip).
local function lineTip(f)
    if f.foldTip then return unpack(f.foldTip) end
    if f.src then return unpack(NS.RollsPanelRows.RowTip(f.src)) end
end

-- One line: a player's row, a folded group or the result line. `text` holds the mark and the name,
-- `roll` the number at the right, `stripe` the alternate shade, `wash` the winner's gold. A row and a
-- folded group take the pointer for their tooltip; a click on a folded group unfolds it.
local function newLine(p)
    local f = CreateFrame("Frame", nil, p)
    f:SetHeight(RP.LINE_H)
    f.stripe = f:CreateTexture(nil, "BACKGROUND")
    f.stripe:SetAllPoints(f)
    NS.SkinPaint(f.stripe, function(t) t:SetColorTexture(NS.SkinColor("list.stripe")) end)
    f.wash = f:CreateTexture(nil, "BACKGROUND")
    f.wash:SetAllPoints(f)
    NS.SkinPaint(f.wash, accentPaint(0.2))
    f.roll = faced(f, nil, "RIGHT")
    f.roll:SetPoint("RIGHT", f, "RIGHT", -4, 0)
    f.text = faced(f)
    f.text:SetPoint("LEFT", f, "LEFT", 4, 0)
    f.text:SetPoint("RIGHT", f.roll, "LEFT", -4, 0)
    NS.Window.AttachTooltip(f, function() return lineTip(f) end)
    f:HookScript("OnLeave", function() onLeave() end)
    f:SetScript("OnMouseUp", function(self) onFoldClick(self) end)
    return f
end

-- Whether any listed item is open: the toggle then collapses every one (RX-25).
local function anyExpanded()
    for _, b in ipairs(blocks) do
        if not b.collapsed then return true end
    end
    return false
end

local function foldTip()
    local rest = L["every item in the Rolls panel"]
    if anyExpanded() then
        return L["Collapse all"], NS.TipMarks.Row(L["Closes"], rest), NS.TipMarks.Hint(L["Expand all opens them again."])
    end
    return L["Expand all"], NS.TipMarks.Row(L["Opens"], rest), NS.TipMarks.Hint(L["Collapse all closes them again."])
end

-- Expand all and Collapse all, one toggle (RX-25 ruling: they are mutually exclusive): Collapse
-- all with the catalog's chevron-up while any item is open, else Expand all with chevron-down.
local function buildFoldButton(p)
    p.foldButton = NS.WindowTitleBar.IconButton(p, "chevron-up", "^", function() setAll(anyExpanded()) end)
    NS.Window.AttachTooltip(p.foldButton, foldTip)
    p.foldButton:HookScript("OnLeave", function() onLeave() end)
end

-- The toggle's mark follows the items on every paint (a header's click, a new roll, Expand or
-- Collapse all, a refresh).
local function paintFoldButton(p)
    if anyExpanded() then
        NS.WindowTitleBar.SetIconMark(p.foldButton, "chevron-up", "^")
    else
        NS.WindowTitleBar.SetIconMark(p.foldButton, "chevron-down", "v")
    end
end

local function buildTitle(p)
    -- The band's rect as a frame (no mouse), for the strips to dock under; NS.Skin.Header lays it on
    -- the band (`bars`), so it follows the skin's edge and title height.
    p.titleBar = CreateFrame("Frame", nil, p)
    p.titleBar:SetPoint("TOPLEFT", p, "TOPLEFT", 1, -1)
    p.titleBar:SetPoint("TOPRIGHT", p, "TOPRIGHT", -1, -1)
    p.titleBar:SetHeight(K.TITLE_H)
    p.title = p:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    p.title:SetPoint("TOPLEFT", p, "TOPLEFT", 10, -9)
    p.title:SetText(L["Rolls"])
    NS.Skin.Text(p.title, "heading")   -- gold, in the skin's title face
    p.closeButton = NS.MakeCloseButton(p, function() RP.Close() end)
    buildFoldButton(p)
    local right = { p.foldButton }
    if p.closeButton then
        p.closeButton:SetPoint("TOPRIGHT", p, "TOPRIGHT", -6, -6)
        p.closeButton:HookScript("OnLeave", function() onLeave() end)
        NS.Window.AttachTooltip(p.closeButton, function()
            return L["Close the Rolls panel"], NS.TipMarks.Row(L["Until"], L["the next roll starts"]),
                NS.TipMarks.Row(L["Turn off"], L["Show the Rolls panel beside the window on Drops > Rolls > Panel"])
        end)
        table.insert(right, 1, p.closeButton)
        p.foldButton:SetPoint("RIGHT", p.closeButton, "LEFT", -4, 0)
    else
        p.foldButton:SetPoint("TOPRIGHT", p, "TOPRIGHT", -6, -6)
    end
    -- The band ApplySkin draws carries the title and the buttons, as the Offer panel's (R5-WIN).
    NS.Skin.Header(p, { title = p.title, right = right, bars = { p.titleBar } })
end

-- The mode strips (ruling A1): test mode's and the simulation's, born hidden, docked directly under
-- the title band and full width (the library places them), each with the title bar's tooltip for its
-- mode. Nil with no library.
local function buildStrips(p)
    local TB = NS.WindowTitleBar
    local dock = { titleBar = p.titleBar, window = p }
    local function strip(text, kind, tip)
        local s = NS.MakeTestStrip(p, text, kind, dock)
        if not s then return nil end
        NS.Window.AttachTooltip(s, tip)
        s:HookScript("OnLeave", function() onLeave() end)
        return s
    end
    p.testStrip = strip(L["TEST: sample rolls. Nothing is sent; combat ends it."], nil, TB.TestTip)
    p.simStrip = strip(L["SIM: simulated rolls. Nothing is sent. /dw sim stop ends it."], "sim", TB.SimTip)
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
    -- straight out from them: each restarts the countdown itself (ruling A9), as the close button.
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
    buildStrips(p)
    buildBody(p)
    p.empty = faced(p, "GameFontHighlight", "CENTER")
    NS.Skin.Text(p.empty, "text.highlight")
    p.empty:SetText(L["No rolls right now"])
    p:SetScript("OnLeave", function() onLeave() end)
    -- A child of the window, read-only: a press on it is no use of the window, so the auto-close
    -- walk hooks only the pointer under it (RX-20).
    NS.WindowAutoClose.PointerOnly(p)
    p:Hide()
    return p
end

-- ── painting ────────────────────────────────────────────────────────────────────────────────

local function screenPx()
    local w = geom(UIParent, "GetWidth")
    return w and w * (geom(UIParent, "GetEffectiveScale") or 1) or nil
end

-- Beside the window, flush, on the side the setting asks for, or the other with no room there; the
-- other one too while the Offer panel is docked there (RollsPanelRows.Beside). Answers false when
-- no side is free: the panel waits hidden.
local function dock(p, win, w)
    local s = geom(win, "GetEffectiveScale") or 1
    local l, r = geom(win, "GetLeft"), geom(win, "GetRight")
    l, r = l and l * s, r and r * s
    local RPR, screen = NS.RollsPanelRows, screenPx()
    local side = RPR.Side(NS.Setting("rolls.panel.side"), l, r, w * s, screen, RP.GAP * s)
    side = RPR.Beside(side, NS.OfferPanel.DockSide(), l, r, w * s, screen, RP.GAP * s)
    if not side then return false end
    p:ClearAllPoints()
    if side == "right" then
        p:SetPoint("TOPLEFT", win, "TOPRIGHT", RP.GAP, 0)
    else
        p:SetPoint("TOPRIGHT", win, "TOPLEFT", -RP.GAP, 0)
    end
    p:SetFrameLevel((geom(win, "GetFrameLevel") or 0) + C.LAYERS.LEVEL.DOCKED)
    p.dock = side
    return true
end

-- A pooled frame at `y` in the body, as wide as the body (both top corners anchored). The pools
-- hand each position the frame it had (NS.Pool), so a frame already at `y` is left where it is.
local function place(f, p, y)
    if f.placedY == y then return end
    f.placedY = y
    f:ClearAllPoints()
    f:SetPoint("TOPLEFT", p.content, "TOPLEFT", 0, -y)
    f:SetPoint("TOPRIGHT", p.content, "TOPRIGHT", 0, -y)
end

-- One line from row `r` ({ text, tone, roll, winner, fold, tip, src, group }) of block `id`, shaded
-- when `stripe`.
local function line(p, y, r, id, stripe)
    local f = NS.Pool.Acquire(p.linePool, function() return newLine(p.content) end)
    place(f, p, y)
    f.text:SetText(r.text)
    setTone(f.text, r.tone or "plain")
    f.roll:SetText(r.roll and tostring(r.roll) or "")
    setTone(f.roll, r.winner and "accent" or "plain")
    f.wash:SetShown(r.winner == true)
    f.stripe:SetShown(stripe == true)
    f.winner = r.winner == true
    f.fold, f.foldTip, f.src, f.group, f.blockId = r.fold, r.tip, r.src, r.group, id
    f:EnableMouse(r.fold ~= nil or r.src ~= nil)
    return y + RP.LINE_H
end

-- The header's band: the chevron, the icon, the name in its quality color, the time left or `done`.
local function paintTitleRow(h, m)
    h.chevron:SetTexture(NS.Icon(m.open and "chevron-down" or "chevron-right"))
    h.icon:SetTexture(NS.Compat.ItemIcon(m.link))
    h.name:SetText(m.name)
    local qr, qg, qb = NS.QualityColor(m.quality)
    if qr then h.name:SetTextColor(qr, qg, qb) else setTone(h.name, "plain") end
    h.time:SetText(m.time or "")
    setTone(h.time, m.done and "muted" or "plain")
end

-- A collapsed header's count line (the result once over, dimmed with the header).
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
    local tall = RP.HEADER_H + (m.counts and RP.LINE_H + 2 or 0)
    h:SetHeight(tall)
    return y + tall + (h.frac and RP.BAR_H + 2 or 0)
end

-- A block's rows (RollsPanelRows.Rows, each text led by its mark), kept while its roll reads the
-- same: the same table, or the store's next read of it with the same signature (Pending replaces
-- the table on every read, RX-17), the same state, fold and skin. The ticker repaints every second
-- while a roll runs, and a 40-player raid's six open blocks would compose some 200 rows each time
-- (tests/perf.lua's rollsPanelRaid). A folded line's click drops them (onFoldClick).
local function rowsOf(b, view)
    local item, c = b.item, b.rows
    local roll = type(item.roll) == "table" and item.roll or nil
    if c and c.looks == looks and c.fold == view.fold and c.state == item.state
        and (c.roll == roll or (c.sig ~= nil and c.sig == item.sig)) then
        return c.list
    end
    local list = NS.RollsPanelRows.Rows(roll, view.fold, b.unfolded)
    for _, r in ipairs(list) do r.text = r.mark .. " " .. r.text end
    b.rows = { roll = roll, sig = item.sig, state = item.state, fold = view.fold, looks = looks, list = list }
    return list
end

-- One block, top to bottom, from `y`; answers the y under it. A collapsed block is its header.
local function paintBlock(p, y, b, view)
    local open = not b.collapsed
    local m = NS.RollsPanelRows.Block(b.item, { now = view.now, gone = b.gone, open = open,
        fold = view.fold, unfolded = b.unfolded, rows = open and rowsOf(b, view) or nil })
    y = paintHeader(p, y, b, m)
    if not m.open then return y end
    for i, r in ipairs(m.rows) do y = line(p, y, r, b.id, i % 2 == 0) end
    if m.result then y = line(p, y, m.result) end
    return y
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

-- What this paint draws: raid mode or not, the fold, the clock, the width and the mode strip.
local function viewOf()
    local raid = NS.RollsPanelRows.IsRaid(math.max(num(NS.Compat.GroupSize()) or 0, mostRollers()))
    local test = NS.State.testMode == true
    return { now = NS.Compat.LootHistoryNow(), raid = raid, w = width(),
        fold = raid and NS.Setting("rolls.panel.foldInRaid") ~= false,
        test = test, sim = not test and NS.Sim:IsActive() == true }
end

-- The mode strip in force (ruling A1), and the top of the body under it.
local function paintStrips(p, view)
    local strip = view.test and p.testStrip or view.sim and p.simStrip or nil
    if p.testStrip then p.testStrip:SetShown(strip == p.testStrip) end
    if p.simStrip then p.simStrip:SetShown(strip == p.simStrip) end
    return RP.TOP + (strip and strip:BodyOffset() or 0)
end

-- The body's height `y` under `top` against the most the panel may be: the bar shows past it, the
-- body narrows for it, and each countdown bar is laid at the body's width.
local function fit(p, y, w, cap, top)
    local h = top + y + RP.PAD
    local over = cap ~= nil and cap > 0 and h > cap
    local inner = w - 2 * RP.PAD - (over and K.SCROLL_W + 4 or 0)
    p.scroll:ClearAllPoints()
    p.scroll:SetPoint("TOPLEFT", p, "TOPLEFT", RP.PAD, -top)
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
    paintFoldButton(panel)
    local top = paintStrips(panel, view)
    panel.empty:SetShown(#blocks == 0)
    panel.empty:ClearAllPoints()
    panel.empty:SetPoint("TOP", panel, "TOP", 0, -top - 4)
    if #blocks == 0 then y = y + RP.LINE_H + 4 end
    panel:SetSize(view.w, fit(panel, y, view.w, geom(win, "GetHeight"), top))
    if not dock(panel, win, view.w) then
        panel:Hide()   -- the Offer panel holds the one side with room: back when it closes or moves
        return syncTicker()
    end
    panel:Show()
    syncTicker()
end

-- The pointer left the panel (or one of its parts that take the mouse): with every roll over, the
-- countdown starts over, so nothing closes while it is read.
onLeave = function()
    if hovered() or not allDone() then return end
    dropLinger()
    armLinger()
end

-- An item header was clicked: its block collapses or expands, and stays so while it is listed.
onHeaderClick = function(h)
    local b = byId[h.blockId]
    if not b then return end
    b.collapsed = h.open == true
    paint()
end

-- Expand all (false) or Collapse all (true): the title bar's one toggle.
setAll = function(collapsed)
    for _, b in ipairs(blocks) do b.collapsed = collapsed end
    paint()
end

-- A folded group's line was clicked: that block lists the group's players.
onFoldClick = function(f)
    local b = f.fold and byId[f.blockId]
    if not b then return end
    b.unfolded = b.unfolded or {}
    b.unfolded[f.fold] = true
    b.rows = nil
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
--- `No rolls right now`, and stays until closed). Says why when it cannot show: the panel off, Show
--- rolls off (Rolling now, its list, empty) or the window closed or minimized.
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
    if not NS.WindowPending.Shown() then   -- `rolls.show` off: Rolling now, its list, is empty
        NS.Print(L["The Rolls panel lists Rolling now's rolls: turn on Show rolls on Drops > Rolls > Window and popup."])
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

-- A simulation's stop: its rolls leave, and the sim strip with them, though no roll was open.
NS.Sim:OnStop(function()
    if not stoodDown() then RP.Refresh() end
end)

-- A skin switch recolors `[YOU]` and the marks the kept rows carry.
if NS.Skin.OnLooksChanged then NS.Skin.OnLooksChanged(function() looks = looks + 1 end) end

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
