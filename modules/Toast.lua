local _, NS = ...
-- modules/Toast.lua — the upgrade toast (design spec §11.5, board 06 C; feedback-9 spec §0): an
-- opt-in alert for a drop someone else looted that is a big upgrade for you and likely tradeable.
--
-- FOUR ROWS BESIDE A FOUR-ROW ICON (feedback-9 spec §0, DW-I0). The item button spans all four:
--
--   [icon]  Big upgrade for you                                   [Ask] [x]
--           Nalorakk's Nightmare 295
--           Looted by Seta · You ▲19 · Them ▼13
--           Likely tradeable · not an upgrade for Seta
--
-- Row 2 is the item name in its quality color (NS.TipMarks.ItemName) and its item level after it in
-- a second, smaller muted FontString (NS.WindowRows' mark, as the looter's `[YOU]` is drawn): the
-- name is cut first, the level always shows. Row 3 is the looter in their class color
-- (NS.TipMarks.ClassName) and the drop judged for you and for them, each as the table's Me and Them
-- cells draw a verdict (NS.SideCells.Merge of WindowCells.Me / Them): the monospace glyph
-- (WindowCells.GLYPH, C.FONT_MONO) and the unsigned difference, both in the verdict's tone, or the
-- word (`Can't use`, `Not wanted`, `?`); a FontString has one face, so the row is segments laid
-- out left to right. Row 4 is the trade word in the Trade cell's tone (WindowCells.TRADE_TONE) and a
-- short reason, muted (cut with an ellipsis at the right inset); the toast's tooltip is the Trade
-- cell's, with the full reason (WindowCells.TradeReason). Only row 1 shares its width with Ask and
-- the close mark; rows 2 to 4 run to the right inset.
--
-- OFF BY DEFAULT (`toast.enabled`). A drop toasts when it is not yours, its verdict for you is
-- `upgrade` with an item-level gain of at least `toast.minGain` (default 10), and its trade
-- estimate is `likely` or `yes` (Qualifies, pure). An upgrade into an empty slot (the kernel's
-- `emptySlot` reason, with no item-level change) clears any least gain and reads `empty`. Each drop
-- is considered on DropAdded and again on each DropUpdated until it has toasted once (an inspect can
-- turn its trade `likely` later).
--
-- OFF-SPEC (feedback-19 spec §2). A drop your spec can't use toasts the same way when another spec
-- of your class finds it an upgrade (NS.OffSpec.Of), the least gain tested on the off-spec
-- difference; Qualifies says so with a third value, `offSpec`, and row 1 reads `Off-spec upgrade
-- for you (Holy)`. Its Ask sends the off-spec template, which the shared ask path picks.
--
-- ONE AT A TIME. Qualifying drops wait in a queue (MAX_QUEUE, the oldest dropped first); the next
-- shows when the current one goes. A toast goes after `toast.duration` seconds (default 8), when its
-- close mark is clicked, or on a right-click anywhere on it (the close mark's path: the drop is not
-- asked for and does not toast again); the countdown pauses while the pointer is over it and
-- resumes with the time it had left. A drop asked for meanwhile, or no longer qualifying, is skipped
-- when its turn comes.
--
-- IT FOLLOWS ITS DROP AND ITS SWITCH. A drop that leaves the feed (a Clear or the cap's trim: the
-- feed's removal sink, Prune) takes its toast and its place in the queue with it, and an Ask on a
-- drop already gone only takes the toast down. Turning `toast.enabled` off (its row's reaction,
-- OnEnabledChanged) or switching to a profile with it off (OnProfileReloaded) takes the toast down
-- and empties the queue.
--
-- COMBAT. Unless `toast.inCombat` is set, nothing shows in combat: the queue waits for
-- PLAYER_REGEN_ENABLED, and a toast on screen when combat starts goes back to the head of the queue.
--
-- TEST MODE. Test mode's placeholders toast like live drops (with `toast.enabled` on), so the toast
-- can be seen and placed: only in test mode can it be dragged (with the left button), and its
-- position is saved in the profile's `toast.point` (named state, like the window's point). A test
-- drop's toast stays until it is closed or test mode ends, since placing it takes longer than its
-- duration.
--
-- SOUND. With `toast.sound` on, each toast plays the client's alert sound (core/Compat.lua's
-- PlayAlertSound, a SOUNDKIT entry).
--
-- PURE: Qualifies and Compose take a drop record and read nothing else (Compose answers the rows'
-- parts, not joined lines); test_toast drives them. The edge below reads the feed, the settings and
-- the asks, and builds its frame on the first toast.

NS.Toast = NS.Toast or {}
local Toast = NS.Toast
local C = NS.Constants
local L = NS.L

local TAG = "UI"

Toast.NAME = "DropWatcherToast"
Toast.MAX_QUEUE = 5
-- The icon spans the four rows; the frame keeps INSET all round (feedback-9 spec §0). TEXT_GAP is
-- between the icon and the rows, ROW_Y each row's top under the icon's (row 4 sits on its bottom).
-- WIDTH is 350, not the spec's first 340: row 3 with a 12-character looter, an empty slot and a Them
-- word (`Not wanted`) needs 267 of the rows' width (test_toast).
Toast.WIDTH, Toast.ICON, Toast.INSET, Toast.TEXT_GAP = 350, 56, 9, 8
Toast.HEIGHT = Toast.ICON + 2 * Toast.INSET
Toast.ROW_Y = { 0, -15, -30 }
-- Between row 3's and row 4's segments (a verdict after its label, a reason after its word).
Toast.SEG_GAP = 4
Toast.POINT = { "TOP", "TOP", 0, -160 }

local TRADE_WORD = { likely = L["Likely tradeable"], yes = L["Tradeable"] }

-- Row 4's reason, short (feedback-9 spec §0: one line) for the estimates a toast can carry; any
-- other is the Trade cell's own reason (WindowCells.TradeReason), cut at the row's end.
local SHORT_REASON = {
    notUpgrade = function(who) return L["not an upgrade for %s"]:format(who) end,
    groupLoot = function() return L["group loot: four hours to trade"] end,
    boe = function() return L["bind on equip"] end,
}

-- ── the pure core ───────────────────────────────────────────────────────────────────────────

local function num(v)
    if type(v) == "number" and v == v then return v end
    return nil
end

-- True when the verdict is an upgrade into an empty slot (design spec §5.2: no baseline item).
local function intoEmptySlot(eval)
    for _, r in ipairs(type(eval.reasons) == "table" and eval.reasons or {}) do
        if type(r) == "table" and r.key == "emptySlot" then return true end
    end
    return false
end

local function gainPasses(eval, minGain)
    local gain = num(eval.ilvlDelta)
    if not gain then return intoEmptySlot(eval) end
    return gain >= (num(minGain) or 0)
end

-- The verdict a drop qualifies through: your own `upgrade`, else (your spec can't use it) another
-- spec's off-spec upgrade (NS.OffSpec.Of, feedback-19 spec §2) and `offSpec`; nil when neither.
local function upgradeOf(me)
    if me.verdict == "upgrade" then return me end
    local off = NS.OffSpec.Of(me)
    if off and off.verdict == "upgrade" then return off, "offSpec" end
    return nil
end

--- Whether `drop` earns a toast: someone else's drop, an upgrade for you by at least `minGain` item
--- levels (or into an empty slot, whatever `minGain`), with a trade estimate of `likely` or `yes`.
--- A drop your spec can't use qualifies the same way through another spec's off-spec upgrade, its
--- gain tested on the off-spec difference; the third value then says so.
--- @param drop table a feed record
--- @param minGain number
--- @return boolean ok, string|nil why (`mine`, `notUpgrade`, `gain` or `trade`) when not,
--- string|nil how (`offSpec` when it qualifies through the off-spec result)
function Toast.Qualifies(drop, minGain)
    if type(drop) ~= "table" or drop.isMine then return false, "mine" end
    local eval, how = upgradeOf(type(drop.me) == "table" and drop.me or {})
    if not eval then return false, "notUpgrade" end
    if not gainPasses(eval, minGain) then return false, "gain" end
    local t = type(drop.trade) == "table" and drop.trade.state
    if not TRADE_WORD[t] then return false, "trade" end
    return true, nil, how
end

--- The width rows 2 to 4 have: the toast's, less the insets, the icon and the gap after it.
--- @return number
function Toast.RowWidth()
    return Toast.WIDTH - 2 * Toast.INSET - Toast.ICON - Toast.TEXT_GAP
end

-- A verdict as the table's Me and Them cells draw it with no gear part (NS.SideCells.Merge): the
-- glyph and the unsigned difference (or `empty`), else the word; one tone for both.
local function verdictPart(cell)
    local c = NS.SideCells.Merge(cell)
    return { glyph = c.glyph, text = c.text, tone = c.tone }
end

local function shortReason(trade, who)
    local fn = SHORT_REASON[trade.reasonKey]
    if fn then return fn(who) end
    return (NS.WindowCells.TradeReason(trade, who):gsub("%.$", ""))
end

-- Row 1: `Big upgrade for you`, or for an off-spec upgrade `Off-spec upgrade for you (Holy)`.
local function titleOf(drop)
    local off, how = upgradeOf(type(drop.me) == "table" and drop.me or {})
    if how ~= "offSpec" then return L["Big upgrade for you"] end
    return L["Off-spec upgrade for you (%s)"]:format(NS.OffSpecCells.SpecName(off.specID))
end

--- The toast's parts for a qualifying drop (feedback-9 spec §0), each row's pieces apart:
--- { title, link, item, itemText (the name in its quality color), ilvl, looter, classFile,
--- looterText (in its class color), me, them ({ glyph, text, tone } each), trade, tradeTone,
--- reason (short), tip (the Trade cell's tooltip: its title and the full reason) }.
--- @param drop table
--- @return table
function Toast.Compose(drop)
    local WC = NS.WindowCells
    local looter = type(drop.looter) == "table" and drop.looter or {}
    local who = WC.ShortName(looter.name)
    local f = type(drop.facts) == "table" and drop.facts or {}
    local name = WC.ItemName(drop.link) or "?"
    local trade = type(drop.trade) == "table" and drop.trade or {}
    return {
        title = titleOf(drop), link = drop.link,
        item = name, itemText = NS.TipMarks.ItemName(name, f.quality, drop.link), ilvl = num(f.ilvl),
        looter = who, classFile = looter.classFile, looterText = NS.TipMarks.ClassName(who, looter.classFile),
        me = verdictPart(WC.Me(drop)), them = verdictPart(WC.Them(drop)),
        trade = TRADE_WORD[trade.state] or "", tradeTone = WC.TRADE_TONE[trade.state] or "muted",
        reason = trade.reasonKey and shortReason(trade, who) or "", tip = WC.Trade(drop).tip,
    }
end

-- ── the edge's state ────────────────────────────────────────────────────────────────────────

local queue = {}       -- drop ids waiting, oldest first
local toasted = {}     -- drop ids already queued or shown this session: each toasts once
local frame            -- built on the first toast
local shownId          -- the drop on screen
local timer            -- the dismissal countdown
local dueAt            -- GetTime() when the countdown ends
local remaining        -- the seconds it had left when a hover paused it

local function setting(key) return NS.Setting("toast." .. key) end

local function store()
    local db = NS.addon and NS.addon.db
    local p = db and db.profile
    if not p then return {} end
    if type(p.toast) ~= "table" then p.toast = {} end
    return p.toast
end

local function inCombat() return NS.Compat.InCombatLockdown() end

local function held()
    return inCombat() and setting("inCombat") ~= true
end

local function cancelTimer()
    if timer then timer:Cancel() end
    timer, dueAt = nil, nil
end

-- ── the frame ───────────────────────────────────────────────────────────────────────────────

local function savePoint()
    local point, _, relativePoint, x, y = frame:GetPoint(1)
    if point then store().point = { point, relativePoint, x, y } end
end

local function applyPoint()
    local pt = store().point
    if type(pt) ~= "table" then pt = Toast.POINT end
    frame:ClearAllPoints()
    frame:SetPoint(pt[1], UIParent, pt[2], pt[3] or 0, pt[4] or 0)
end

local function onDragStart()
    if NS.State.testMode == true then frame:StartMoving() end
end

local function onDragStop()
    frame:StopMovingOrSizing()
    savePoint()
end

local function onEnter() Toast.Pause() end

local function onLeave()
    if not (frame and frame:IsMouseOver()) then Toast.Resume() end
end

-- A right-click anywhere on the toast closes it, as its close mark does (feedback-9 spec §0): the
-- drop is not asked for and does not toast again. The left button keeps each control's own click
-- and test mode's drag.
local function onMouseUp(_, button)
    if button == "RightButton" then Toast.Dismiss() end
end

-- A control on the toast: hovering it holds the countdown, and a right-click on it closes the toast.
local function onToast(widget)
    widget:HookScript("OnEnter", onEnter)
    widget:HookScript("OnLeave", onLeave)
    widget:HookScript("OnMouseUp", onMouseUp)
end

local function setTone(fs, tone)
    local c = C.TONE[tone] or C.TONE.plain
    fs:SetTextColor(c.r, c.g, c.b)
end

local function text(f, template, tone)
    local fs = f:CreateFontString(nil, "OVERLAY", template)
    fs:SetJustifyH("LEFT")
    fs:SetWordWrap(false)
    if tone then setTone(fs, tone) end
    return fs
end

-- A verdict's glyph, in the monospace face (the default face has no ▲ ≈ ▼).
local function glyph(f)
    local fs = f:CreateFontString(nil, "OVERLAY")
    fs:SetFont(C.FONT_MONO, 12, "")
    fs:SetWordWrap(false)
    return fs
end

-- A row's top-left, ROW_Y under the icon's top, TEXT_GAP right of it.
local function atRow(fs, f, i)
    fs:SetPoint("TOPLEFT", f.icon, "TOPRIGHT", Toast.TEXT_GAP, Toast.ROW_Y[i])
end

-- The close mark, or nil: without LibKa0s it degrades to nothing, as every other close control does
-- (standalone-windows; no one-off mark). A right-click anywhere still closes the toast.
local function buildClose(f)
    local close = NS.MakeCloseButton(f, function() Toast.Dismiss() end)
    if close then close:SetPoint("TOPRIGHT", f, "TOPRIGHT", -4, -4) end
    return close
end

-- Rows 1 and 2: the gold title beside Ask; the item name (cut first) and its item level after it.
local function buildTop(f)
    f.title = text(f, "GameFontNormalSmall")
    f.title:SetTextColor(C.GOLD.r, C.GOLD.g, C.GOLD.b)
    atRow(f.title, f, 1)
    f.title:SetPoint("RIGHT", f.ask, "LEFT", -6, 0)
    f.item = text(f, "GameFontHighlight")
    atRow(f.item, f, 2)
    f.ilvl = NS.WindowRows.NewMark(f, f.item)
    setTone(f.ilvl, "muted")
end

-- Row 3: `Looted by Seta · You`, the Me verdict, `· Them`, the Them verdict (the segments are
-- placed on each paint: a verdict with no glyph takes no glyph's room; the last runs to the right
-- inset and is cut there, as row 4's reason is).
local function buildVerdicts(f)
    f.looted = text(f, "GameFontHighlightSmall", "muted")
    atRow(f.looted, f, 3)
    f.meGlyph, f.meText = glyph(f), text(f, "GameFontHighlightSmall")
    f.themLabel = text(f, "GameFontHighlightSmall", "muted")
    f.themGlyph, f.themText = glyph(f), text(f, "GameFontHighlightSmall")
end

-- Row 4: the trade word, and the reason after it to the right inset (cut there).
local function buildTrade(f)
    f.trade = text(f, "GameFontHighlightSmall")
    f.trade:SetPoint("BOTTOMLEFT", f.icon, "BOTTOMRIGHT", Toast.TEXT_GAP, 0)
    f.reason = text(f, "GameFontHighlightSmall", "muted")
    f.reason:SetPoint("LEFT", f.trade, "RIGHT", Toast.SEG_GAP, 0)
    f.reason:SetPoint("RIGHT", f, "RIGHT", -Toast.INSET, 0)
end

local function build()
    local f = CreateFrame("Frame", Toast.NAME, UIParent, "BackdropTemplate")
    frame = f
    f:SetFrameStrata("HIGH")
    f:SetSize(Toast.WIDTH, Toast.HEIGHT)
    f:SetMovable(true)
    f:SetClampedToScreen(true)
    f:EnableMouse(true)
    f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", onDragStart)
    f:SetScript("OnDragStop", onDragStop)
    f:SetScript("OnEnter", onEnter)
    f:SetScript("OnLeave", onLeave)
    f:SetScript("OnMouseUp", onMouseUp)
    f:Hide()
    NS.ApplySkin(f)
    f.icon = NS.WindowGroup.ItemButton(f, Toast.ICON)
    f.icon:SetPoint("TOPLEFT", f, "TOPLEFT", Toast.INSET, -Toast.INSET)
    f.close = buildClose(f)
    f.ask = NS.Window.TextButton(f, 64, "chat", L["Ask"], function() Toast.Ask() end)
    if f.close then
        f.ask:SetPoint("RIGHT", f.close, "LEFT", -6, 0)
    else
        f.ask:SetPoint("TOPRIGHT", f, "TOPRIGHT", -4, -4)
    end
    buildTop(f)
    buildVerdicts(f)
    buildTrade(f)
    -- The toast's tooltip is the Trade cell's: the full reason row 4 may cut (feedback-9 spec §0).
    NS.Window.AttachTooltip(f, function() return unpack(f.tipLines or {}) end)
    onToast(f.icon)
    onToast(f.ask)
    if f.close then onToast(f.close) end
    applyPoint()
    return f
end

local function ensureFrame() return frame or build() end

local function askState(rec)
    local target = NS.AskTargetOf(rec)
    if not target then return "ready" end
    return NS.Asks.StateOf("ask", target, rec.id)
end

-- The Ask in the row's look: its state's word and mark (feedback-7 spec §1: `chat`, `clock`, ...).
local function paintAsk(rec)
    local a = NS.WindowCells.Ask(rec, askState(rec))
    local b = frame.ask
    NS.Window.SetButtonMark(b, a.text, a.icon)
    b:SetEnabled(a.enabled == true)
end

-- One verdict after `after`: its glyph (when it has one) and its difference or word, in its tone.
-- Answers the last segment placed.
local function paintVerdict(after, glyphFs, textFs, part)
    glyphFs:ClearAllPoints()
    textFs:ClearAllPoints()
    glyphFs:SetText(part.glyph or "")
    glyphFs:SetShown(part.glyph ~= nil)
    textFs:SetText(part.text or "")
    setTone(glyphFs, part.tone)
    setTone(textFs, part.tone)
    if part.glyph then
        glyphFs:SetPoint("LEFT", after, "RIGHT", Toast.SEG_GAP, 0)
        textFs:SetPoint("LEFT", glyphFs, "RIGHT", NS.WindowGroup.SIDE.GLYPH_GAP, 0)
    else
        textFs:SetPoint("LEFT", after, "RIGHT", Toast.SEG_GAP, 0)
    end
    return textFs
end

local function paintRows(t)
    frame.title:SetText(t.title)
    frame.item:SetText(t.itemText)
    NS.WindowRows.PlaceMark(frame.item, frame.ilvl, t.ilvl and tostring(t.ilvl) or nil, Toast.RowWidth())
    frame.looted:SetText(L["Looted by %s · You"]:format(t.looterText))
    local last = paintVerdict(frame.looted, frame.meGlyph, frame.meText, t.me)
    frame.themLabel:ClearAllPoints()
    frame.themLabel:SetPoint("LEFT", last, "RIGHT", Toast.SEG_GAP, 0)
    frame.themLabel:SetText(L["· Them"])
    paintVerdict(frame.themLabel, frame.themGlyph, frame.themText, t.them)
    frame.themText:SetPoint("RIGHT", frame, "RIGHT", -Toast.INSET, 0)
    frame.trade:SetText(t.trade)
    setTone(frame.trade, t.tradeTone)
    frame.reason:SetText(t.reason ~= "" and ("· " .. t.reason) or "")
end

local function paint(rec)
    local t = Toast.Compose(rec)
    paintRows(t)
    frame.tipLines = t.tip
    NS.WindowGroup.SetItem(frame.icon, t.link, NS.WindowGroup.Where(rec))
    frame.icon.dropId = nil
    paintAsk(rec)
end

-- ── the queue ───────────────────────────────────────────────────────────────────────────────

local function startTimer(seconds)
    cancelTimer()
    dueAt = GetTime() + seconds
    timer = C_Timer.NewTimer(seconds, function()
        timer, dueAt = nil, nil
        Toast.Dismiss()
    end)
end

-- Still worth showing when its turn comes: in the feed, qualifying, and not asked for yet.
local function wanted(id)
    local rec = NS.LootFeed.Get(id)
    if not rec or not Toast.Qualifies(rec, setting("minGain")) then return nil end
    local s = askState(rec)
    if s == "sent" or s == "queued" then return nil end
    return rec
end

local function show(rec)
    ensureFrame()
    shownId, remaining = rec.id, nil
    paint(rec)
    applyPoint()
    frame:Show()
    if setting("sound") == true then NS.Compat.PlayAlertSound() end
    if not rec.test then startTimer(setting("duration")) end
    NS.Debug(TAG, "toast shown: drop %s %s", tostring(rec.id), tostring(rec.link))
end

--- Show the next waiting toast, unless one is on screen, the toast is off, or combat holds it.
function Toast.Pump()
    if shownId or setting("enabled") ~= true or held() then return end
    while #queue > 0 do
        local rec = wanted(table.remove(queue, 1))
        if rec then return show(rec) end
    end
end

local function enqueue(id, front)
    if front then table.insert(queue, 1, id) else queue[#queue + 1] = id end
    while #queue > Toast.MAX_QUEUE do table.remove(queue, front and #queue or 1) end
end

--- Consider a drop for a toast (DropAdded, DropUpdated): queued once when it qualifies.
--- @param id number
--- @return boolean queued
function Toast.Consider(id)
    if toasted[id] or setting("enabled") ~= true then return false end
    local rec = NS.LootFeed.Get(id)
    -- A drop restored after a reload (feedback-15 spec §0) was toasted, if ever, before it.
    if not rec or rec.source == "restore" or not Toast.Qualifies(rec, setting("minGain")) then return false end
    toasted[id] = true
    enqueue(id)
    NS.Debug(TAG, "toast queued: drop %s (%d waiting)%s", tostring(id), #queue, held() and ", held in combat" or "")
    Toast.Pump()
    return true
end

--- Take the toast off screen and show the next one.
function Toast.Dismiss()
    cancelTimer()
    remaining = nil
    if frame then
        frame:Hide()
    end
    if shownId == nil then return end
    shownId = nil
    Toast.Pump()
end

--- The pointer is over the toast: its countdown stops, keeping the time it had left.
function Toast.Pause()
    if not dueAt then return end
    remaining = math.max(dueAt - GetTime(), 0)
    cancelTimer()
end

--- The pointer left the toast: its countdown resumes with the time it had left.
function Toast.Resume()
    if not (shownId and remaining) then return end
    local left = remaining
    remaining = nil
    startTimer(math.max(left, 1))
end

--- The toast's Ask: the shared host handler, so a second click cancels a queued ask.
function Toast.Ask()
    if not shownId then return end
    if not NS.LootFeed.Get(shownId) then return Toast.Dismiss() end
    NS.PressAsk(shownId)
    local rec = NS.LootFeed.Get(shownId)
    if rec and frame then paintAsk(rec) end
end

-- ── edges ───────────────────────────────────────────────────────────────────────────────────

local function onUpdated(id)
    if id == shownId then
        local rec = NS.LootFeed.Get(id)
        if rec then paintAsk(rec) end
    end
    Toast.Consider(id)
end

--- PLAYER_REGEN_DISABLED: a toast on screen goes back to the head of the queue, unless toasts may
--- show in combat.
function Toast.OnCombatStart()
    if not shownId or setting("inCombat") == true then return end
    local id = shownId
    cancelTimer()
    shownId, remaining = nil, nil
    if frame then
        frame:Hide()
    end
    enqueue(id, true)
    NS.Debug(TAG, "toast held for combat: drop %s", tostring(id))
end

--- PLAYER_REGEN_ENABLED: what combat held shows now.
function Toast.OnCombatEnd() Toast.Pump() end

--- Drops gone from the feed leave the queue, and a toast whose drop is gone goes (the next one
--- shows). The feed's removal sink: a Clear or the cap's trim. Answers how many it let go.
--- @return number
function Toast.Prune()
    local n = 0
    for i = #queue, 1, -1 do
        if not NS.LootFeed.Get(queue[i]) then
            table.remove(queue, i)
            n = n + 1
        end
    end
    if shownId and not NS.LootFeed.Get(shownId) then
        n = n + 1
        Toast.Dismiss()
    end
    if n > 0 then NS.Debug(TAG, "toast: %d gone with their drops", n) end
    return n
end

-- Toasts turned off: the one on screen goes and nothing waits.
local function stopAll(why)
    if #queue == 0 and shownId == nil then return end
    queue = {}
    Toast.Dismiss()
    NS.Debug(TAG, "toast off (%s): queue emptied", why)
end

--- The `toast.enabled` row's reaction: off takes the toast down and empties the queue; on shows
--- nothing old (what was dropped stays dropped), and the next qualifying drop toasts.
--- @param on boolean
function Toast.OnEnabledChanged(on)
    if on ~= true then return stopAll("setting") end
    Toast.Pump()
end

--- A profile switch, copy or reset (core/DropWatcher.lua's reloadProfile): no row reaction runs,
--- so the incoming `toast.enabled` is read here.
function Toast.OnProfileReloaded()
    if setting("enabled") ~= true then stopAll("profile") end
end

--- Test mode turned on or off (core/DropWatcher.lua NS.SetTestMode): turned off, a test drop's
--- toast goes, and the test drops leave the queue (their feed is already empty).
--- @param on boolean
function Toast.OnTestModeChanged(on)
    if on then return end
    Toast.Prune()
end

--- Forget the saved position: the toast goes back under the top of the screen.
function Toast.ResetPosition()
    store().point = nil
    if frame then applyPoint() end
end

--- The toast's state, for the diagnostics report and the suites: { built, shown, dropId, waiting,
--- held, point }.
--- @return table
function Toast.Stats()
    return { built = frame ~= nil, shown = frame ~= nil and frame:IsShown() == true, dropId = shownId,
        waiting = #queue, held = held(), point = store().point }
end

--- The built frame, or nil before the first toast. For the suites.
function Toast.Frame() return frame end

local EVENTS = {
    { "PLAYER_REGEN_DISABLED", "OnToastCombatStart", Toast.OnCombatStart },
    { "PLAYER_REGEN_ENABLED", "OnToastCombatEnd", Toast.OnCombatEnd },
}
for _, row in ipairs(EVENTS) do
    local fn = row[3]
    NS.FEATURE_EVENTS[#NS.FEATURE_EVENTS + 1] = { row[1], row[2] }
    NS.addon[row[2]] = function() fn() end
end

-- Tracked, so the stand-down takes them down and the stand-up replays them. Without the bus
-- library it is a bare target, unregistered here instead (NS.Bus.tracked says which).
local target = NS.Bus:NewTarget()

-- Not a registration: a plain function the feed calls, so nothing to take down on the stand-down.
NS.LootFeed.AddRemovalSink(function() Toast.Prune() end)

local function listen()
    if not target then return end
    local M = NS.MSG
    target:RegisterMessage(M.DROP_ADDED, function(_, id) Toast.Consider(id) end)
    target:RegisterMessage(M.DROP_UPDATED, function(_, id) onUpdated(id) end)
    target:RegisterMessage(M.ASK_STATE_CHANGED, function(_, id) if id == shownId then onUpdated(id) end end)
end
listen()

NS.STAND_DOWN[#NS.STAND_DOWN + 1] = function()
    queue, toasted = {}, {}
    Toast.Dismiss()
    if target and not NS.Bus.tracked then target:UnregisterAllMessages() end
end
NS.STAND_UP[#NS.STAND_UP + 1] = function()
    if not NS.Bus.tracked then listen() end
end
