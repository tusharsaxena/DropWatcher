local _, NS = ...
-- modules/Toast.lua — the upgrade toast (design spec §11.5, board 06 C): an opt-in alert for a drop
-- someone else looted that is a big upgrade for you and likely tradeable.
--
-- OFF BY DEFAULT (`toast.enabled`). A drop toasts when it is not yours, its verdict for you is
-- `upgrade` with an item-level gain of at least `toast.minGain` (default 10), and its trade
-- estimate is `likely` or `yes` (Qualifies, pure). An upgrade into an empty slot (the kernel's
-- `emptySlot` reason, with no item-level change) clears any least gain and reads `empty`. Each drop is considered on DropAdded and again
-- on each DropUpdated until it has toasted once (an inspect can turn its trade `likely` later).
--
-- ONE AT A TIME. Qualifying drops wait in a queue (MAX_QUEUE, the oldest dropped first); the next
-- shows when the current one goes. A toast goes after `toast.duration` seconds (default 8) or when
-- its close mark is clicked; the countdown pauses while the pointer is over it and resumes with the
-- time it had left. A drop asked for meanwhile, or no longer qualifying, is skipped when its turn
-- comes.
--
-- IT FOLLOWS ITS DROP AND ITS SWITCH. A drop that leaves the feed (a Clear or the cap's trim: the
-- feed's removal sink, Prune) takes its toast and its place in the queue with it, and an Ask on a drop already gone only takes the toast down.
-- Turning `toast.enabled` off (its row's reaction, OnEnabledChanged) or switching to a profile with
-- it off (OnProfileReloaded) takes the toast down and empties the queue.
--
-- COMBAT. Unless `toast.inCombat` is set, nothing shows in combat: the queue waits for
-- PLAYER_REGEN_ENABLED, and a toast on screen when combat starts goes back to the head of the queue.
--
-- TEST MODE. Test mode's placeholders toast like live drops (with `toast.enabled` on), so the toast
-- can be seen and placed: only in test mode can it be dragged, and its position is saved in the
-- profile's `toast.point` (named state, like the window's point). A test drop's toast stays until it
-- is closed or test mode ends, since placing it takes longer than its duration.
--
-- SOUND. With `toast.sound` on, each toast plays the client's alert sound (core/Compat.lua's
-- PlayAlertSound, a SOUNDKIT entry).
--
-- PURE: Qualifies and Compose take a drop record and read nothing else; test_toast drives them. The
-- edge below reads the feed, the settings and the asks, and builds its frame on the first toast.

NS.Toast = NS.Toast or {}
local Toast = NS.Toast
local C = NS.Constants
local L = NS.L

local TAG = "UI"

Toast.NAME = "DropWatcherToast"
Toast.MAX_QUEUE = 5
Toast.WIDTH, Toast.HEIGHT, Toast.ICON = 340, 58, 40
Toast.POINT = { "TOP", "TOP", 0, -160 }

local TRADE_WORD = { likely = L["Likely tradeable"], yes = L["Tradeable"] }

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

--- Whether `drop` earns a toast: someone else's drop, an upgrade for you by at least `minGain` item
--- levels (or into an empty slot, whatever `minGain`), with a trade estimate of `likely` or `yes`.
--- @param drop table a feed record
--- @param minGain number
--- @return boolean ok, string|nil why (`mine`, `notUpgrade`, `gain` or `trade`) when not
function Toast.Qualifies(drop, minGain)
    if type(drop) ~= "table" or drop.isMine then return false, "mine" end
    local me = type(drop.me) == "table" and drop.me or {}
    if me.verdict ~= "upgrade" then return false, "notUpgrade" end
    if not gainPasses(me, minGain) then return false, "gain" end
    local t = type(drop.trade) == "table" and drop.trade.state
    if not TRADE_WORD[t] then return false, "trade" end
    return true
end

local function shortName(name)
    if type(name) ~= "string" then return L["Unknown"] end
    return (name:gsub("%-.*$", ""))
end

-- The gain as the line shows it: `+19`, or `empty` for an upgrade into an empty slot (the Me
-- column's word).
local function gainText(me)
    local gain = num(me.ilvlDelta)
    if not gain and intoEmptySlot(me) then return L["empty"] end
    return NS.WindowCells.Signed(gain or 0)
end

--- The toast's texts for a qualifying drop: { title, item, line, link }. `line` reads
--- `Looted by Seta · +19 [arrow] · Likely tradeable` (`empty` in place of the gain into an empty slot).
--- The arrow is NS.TipMarks' green `arrow-up` texture: the toast's face draws no `▲` (DW-F5).
--- @param drop table
--- @return table
function Toast.Compose(drop)
    local who = type(drop.looter) == "table" and drop.looter.name or nil
    local me = type(drop.me) == "table" and drop.me or {}
    local trade = TRADE_WORD[drop.trade and drop.trade.state] or ""
    return {
        title = L["Big upgrade for you"],
        item = NS.WindowCells.ItemName(drop.link) or "?",
        link = drop.link,
        line = L["Looted by %s · %s %s · %s"]:format(shortName(who), gainText(me),
            NS.TipMarks.Mark("upgrade"), trade),
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

local function hoverPauses(widget)
    widget:HookScript("OnEnter", onEnter)
    widget:HookScript("OnLeave", onLeave)
end

local function text(f, template, r, g, b)
    local fs = f:CreateFontString(nil, "OVERLAY", template)
    fs:SetJustifyH("LEFT")
    fs:SetWordWrap(false)
    if r then fs:SetTextColor(r, g, b) end
    return fs
end

local function buildClose(f)
    local close = NS.MakeCloseButton(f, function() Toast.Dismiss() end)
    if not close then
        close = NS.Window.TextButton(f, 20, nil, "×", function() Toast.Dismiss() end)
    end
    close:SetPoint("TOPRIGHT", f, "TOPRIGHT", -4, -4)
    return close
end

local function buildTexts(f)
    f.title = text(f, "GameFontNormalSmall", C.GOLD.r, C.GOLD.g, C.GOLD.b)
    f.title:SetPoint("TOPLEFT", f.icon, "TOPRIGHT", 8, 0)
    f.item = text(f, "GameFontHighlight")
    f.item:SetPoint("LEFT", f.icon, "RIGHT", 8, 0)
    f.item:SetPoint("RIGHT", f.ask, "LEFT", -6, 0)
    f.line = text(f, "GameFontHighlightSmall", C.IDLE.r, C.IDLE.g, C.IDLE.b)
    f.line:SetPoint("BOTTOMLEFT", f.icon, "BOTTOMRIGHT", 8, 0)
    f.line:SetPoint("RIGHT", f.ask, "LEFT", -6, 0)
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
    f:Hide()
    NS.ApplySkin(f)
    f.icon = NS.WindowGroup.ItemButton(f, Toast.ICON)
    f.icon:SetPoint("LEFT", f, "LEFT", 9, 0)
    f.close = buildClose(f)
    f.ask = NS.Window.TextButton(f, 64, "chat", L["Ask"], function() Toast.Ask() end)
    f.ask:SetPoint("RIGHT", f.close, "LEFT", -6, 0)
    buildTexts(f)
    hoverPauses(f.icon)
    hoverPauses(f.ask)
    hoverPauses(f.close)
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
    b.label:SetText(a.text)
    b.art:SetTexture(a.icon and NS.Icon(a.icon) or nil)
    b.art:SetShown(a.icon ~= nil)
    b.label:ClearAllPoints()
    b.label:SetPoint("CENTER", b, "CENTER", a.icon and 7 or 0, 0)
    b:SetEnabled(a.enabled == true)
end

local function paint(rec)
    local t = Toast.Compose(rec)
    frame.title:SetText(t.title)
    frame.item:SetText(t.item)
    frame.line:SetText(t.line)
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
    if not (rec and Toast.Qualifies(rec, setting("minGain"))) then return false end
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
    if frame then frame:Hide() end
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
    if frame then frame:Hide() end
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
