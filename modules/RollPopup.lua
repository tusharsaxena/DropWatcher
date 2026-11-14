local _, NS = ...
-- modules/RollPopup.lua — your verdict on Blizzard's roll popup (Forever port design §7, plan
-- DW-FP20), on both clients: a small owned card just above each GroupLootFrame1..4 while it is up.
--
--   line 1  the verdict's mark and word, and the gain: `▲ Upgrade +12 · score +4.1`, `Can't use`.
--           On WoW Forever a bound-on-pickup drop (soulbound once looted, design §4.6) reads
--           `▲ Need: upgrade +12` when it is an upgrade and `Greed / Pass: you can't use it` when you
--           can't use it; any other verdict keeps its word.
--   line 2  `Need so far: N`, muted, while the roll is open: the Need choices (off-spec included)
--           of the pending roll this popup claimed (NS.Pending.ForRoll: joined by item ID, the oldest
--           unclaimed item first, so two copies of one item keep their own counts, Review Focus 1).
--           None when the drop is not pending (the feed's gates refused it, design §11.1: the mark
--           is shown for every roll, because Blizzard already shows the popup).
--
-- THE FRAMES. One overlay per popup, created at enable (RP.Install, from core/DropWatcher.lua's
-- OnEnable), parented to UIParent, at the alert tier (C.LAYERS.STRATA.ALERT), anchored once
-- BOTTOM to the popup's TOP. Blizzard's popups are read through NS.Compat (core/CompatLoot.lua):
-- RollPopupFrame (for the anchor), HookRollPopup and RollPopupOpen. Nothing is ever written to a
-- Blizzard frame or its table: no field, no SetScript, SetParent, SetPoint or strata change; the
-- one call made on it is HookScript, once (R2 §10.2, events-frames-taint-§6).
--
-- THE HOOKS are one-way (HookScript can't be removed), so their bodies gate on the disabled state
-- (slash-commands-§7). OnShow re-checks that the popup is still shown with a plain rollID
-- (Compat.RollPopupOpen), because Blizzard's own OnShow can remove it again at once (R2, skeptic
-- correction 6); OnHide takes the overlay down.
--
-- THE DATA. START_LOOT_ROLL(rollID) reads Compat.LootRollInfo (link, bop) and judges the item for
-- you through the feed's own judge (NS.LootFeed.JudgeMe over NS.ItemFacts), cached by rollID;
-- CANCEL_LOOT_ROLL drops it. A popup shown with no cached entry (a reload) asks once. A pending
-- item's verdict is preferred when it has one (the store re-judges it on the score retry). The
-- shown overlays repaint on PendingChanged (a Need lands), GearChanged (your verdict is judged
-- again), the `rolls.popupMark` row (Drops › Rolls) and the stand-up.
--
-- NOT DRAWN while the addon is disabled, while `rolls.popupMark` is off, and while the client's
-- gamepad UI is on (Compat.GamepadUI): WoW Forever then shows its rolls in
-- GamepadGroupLootRollFrame and GroupLootFrame1..4 are not used (a recorded limitation).
--
-- THE SIMULATOR invents no Blizzard popup, so a simulated roll (START_LOOT_ROLL delivered by
-- NS.Sim) is drawn on an owned stand-in of the popup's size (RP.StandIn), centered above the
-- middle of the screen, with its own overlay; it goes with the roll's CANCEL_LOOT_ROLL.

NS.RollPopup = NS.RollPopup or {}
local RP = NS.RollPopup
local L = NS.L
local C = NS.Constants

local TAG = "POPUP"

RP.WIDTH = 220        -- the overlay's least width
RP.PAD = 5            -- inside the card
RP.LINE = 14          -- one line's height
RP.GAP = 2            -- above the popup's top edge
RP.STAND_IN_W, RP.STAND_IN_H = 280, 82   -- the size of Blizzard's popup, for the simulator's stand-in
RP.STAND_IN_Y = 140   -- the stand-in's offset above the screen's center
RP.STAND_IN = "standIn"   -- the stand-in overlay's key

-- The client, read once at load (clients-§5): the BoP wording is WoW Forever's.
local CLIENT = NS.Compat.ClientKey()

local WORD = {
    upgrade = L["Upgrade"], sidegrade = L["Sidegrade"], downgrade = L["Downgrade"],
    cantUse = L["Can't use"], doesntWant = L["Doesn't want"], unknown = L["Unknown"],
}
local TONE = {
    upgrade = "good", sidegrade = "yellow", downgrade = "red", cantUse = "redMuted", doesntWant = "bad", unknown = "muted",
}
local GAINS = { upgrade = true, sidegrade = true, downgrade = true }

local overlays = {}   -- [1..4] and [RP.STAND_IN]: the owned cards
local drawn = {}      -- [key] = the rollID that overlay shows
local cache = {}      -- [rollID] = { rollID, link, itemID, bop, facts, me }
local standIn, standInRoll
local installed = false
local generation = 0  -- bumped at every stand-down: an item load answering after it is ignored

local function stoodDown()
    return NS.IsStoodDown ~= nil and NS.IsStoodDown()
end

local function num(v) return type(v) == "number" and v or nil end

-- ── the lines (pure) ────────────────────────────────────────────────────────────────────────

--- The Need choices so far in a plain roll table (states 0 Need and 1 Need (off-spec)).
--- @param roll table|nil NS.Compat.LootHistoryRolls' table
--- @return number
function RP.NeedSoFar(roll)
    local n = 0
    for _, r in ipairs(type(roll) == "table" and roll.rolls or {}) do
        if r.state == NS.RollCells.NEED or r.state == NS.RollCells.OFFSPEC then n = n + 1 end
    end
    return n
end

-- The gain: the signed item-level change, then the score's, ` · ` apart; nil with neither.
local function gainOf(me)
    local parts = {}
    local d = num(me.ilvlDelta)
    if d then parts[#parts + 1] = NS.WindowCells.Signed(d) end
    local sd = num(me.scoreDelta)
    if sd then parts[#parts + 1] = L["score %s"]:format(("%+.1f"):format(sd)) end
    if #parts == 0 then return nil end
    return table.concat(parts, " · ")
end

-- The word of verdict `v`, on a drop bound on pickup or not, on `client`.
local function wordOf(v, bop, client)
    if client == "forever" and bop == true and v == "upgrade" then return L["Need: upgrade"] end
    return WORD[v] or WORD.unknown
end

--- Line 1, the verdict: { text, tone, verdict }. `me` is NS.Evaluate's answer for you (nil while
--- the item loads: Unknown); `bop` the popup's bindOnPickUp; `client` NS.Compat.ClientKey() (this
--- client by default).
--- @param me table|nil
--- @param bop boolean|nil
--- @param client string|nil
--- @return table
function RP.Verdict(me, bop, client)
    client = client or CLIENT
    if type(me) ~= "table" or type(me.verdict) ~= "string" then return { text = WORD.unknown, tone = "muted", verdict = "unknown" } end
    local v = me.verdict
    if me.collect then return { text = NS.CollectCells.Text(me), tone = NS.CollectCells.TONE[v] or "muted", verdict = v } end
    if client == "forever" and bop == true and v == "cantUse" then
        return { text = L["Greed / Pass: you can't use it"], tone = TONE.cantUse, verdict = v }
    end
    local text = wordOf(v, bop, client)
    local gain = GAINS[v] and gainOf(me)
    if gain then text = text .. " " .. gain end
    local mark = NS.TipMarks.Mark(v)
    if mark ~= "" then text = mark .. " " .. text end
    return { text = text, tone = TONE[v] or "muted", verdict = v }
end

--- What one overlay says: line 1 (RP.Verdict) and `need`, line 2 (`Need so far: N`) while the
--- pending roll `item` is open, else nil.
--- @param me table|nil
--- @param bop boolean|nil
--- @param item table|nil the NS.Pending item the popup claimed
--- @param client string|nil
--- @return table { text, tone, verdict, need }
function RP.Lines(me, bop, item, client)
    local out = RP.Verdict(me, bop, client)
    if type(item) == "table" and item.state == "open" and type(item.roll) == "table" then
        out.need = L["Need so far: %d"]:format(RP.NeedSoFar(item.roll))
    end
    return out
end

-- ── the cache ───────────────────────────────────────────────────────────────────────────────

local function judge(e, facts)
    e.facts = facts
    e.me = facts and NS.LootFeed.JudgeMe(facts) or nil
end

local refresh

-- Your popup `rollID`'s item, read and judged (once its facts load), cached; nil with no plain link.
local function learn(rollID)
    local info = NS.Compat.LootRollInfo(rollID)
    if not info then return nil end
    local e = { rollID = rollID, link = info.link, itemID = NS.Item.ItemIDFromLink(info.link), bop = info.bop }
    cache[rollID] = e
    local gen = generation
    local facts, status = NS.ItemFacts.Request(info.link, function(f)
        if gen ~= generation or cache[rollID] ~= e or stoodDown() then return end
        judge(e, f)
        refresh()
    end)
    if status == "ready" then judge(e, facts) end
    return e
end

-- ── the frames ──────────────────────────────────────────────────────────────────────────────

local function faced(parent)
    local fs = parent:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    fs:SetJustifyH("CENTER")
    fs:SetWordWrap(false)
    NS.Skin.Font(fs)
    return fs
end

-- One owned card, hidden, anchored once BOTTOM to `anchor`'s TOP (never the other way round).
local function newOverlay(anchor)
    local f = NS.DetailCard.Box(UIParent)
    f:SetFrameStrata(C.LAYERS.STRATA.ALERT)
    f:SetSize(RP.WIDTH, RP.LINE + 2 * RP.PAD)
    f:SetPoint("BOTTOM", anchor, "TOP", 0, RP.GAP)
    f.line1 = faced(f)
    f.line1:SetPoint("TOP", f, "TOP", 0, -RP.PAD)
    f.line2 = faced(f)
    f.line2:SetPoint("TOP", f.line1, "BOTTOM", 0, -2)
    f.line2:Hide()
    f:Hide()
    return f
end

local function setTone(fs, tone) NS.WindowRows.SetTone(fs, tone) end

local function hideKey(key)
    local o = overlays[key]
    if o then o:Hide() end
    drawn[key] = nil
end

-- Whether the mark may be drawn now (the stand-in is the addon's own frame: no gamepad gate).
local function allowed(key)
    if stoodDown() or NS.Setting("rolls.popupMark") == false then return false end
    return key == RP.STAND_IN or not NS.Compat.GamepadUI()
end

-- Draw overlay `key` for `rollID`: its lines, its height, shown.
local function paint(key, rollID)
    local o = overlays[key]
    local e = cache[rollID] or learn(rollID)
    if not (o and e) then return hideKey(key) end
    local item = NS.Pending.ForRoll(rollID)
    local model = RP.Lines((item and item.me) or e.me, e.bop, item)
    o.line1:SetText(model.text)
    setTone(o.line1, model.tone)
    local lines = 1
    if model.need then
        o.line2:SetText(model.need)
        setTone(o.line2, "muted")
        o.line2:Show()
        lines = 2
    else
        o.line2:SetText("")
        o.line2:Hide()
    end
    local w = math.max(num(o.line1:GetStringWidth()) or 0, num(o.line2:GetStringWidth()) or 0)
    o:SetSize(math.max(RP.WIDTH, w + 2 * RP.PAD), lines * RP.LINE + (lines - 1) * 2 + 2 * RP.PAD)
    o:Show()
    drawn[key] = rollID
end

-- Every overlay drawn again from the current state: a shown popup, and the stand-in's roll.
refresh = function()
    for i = 1, NS.Compat.ROLL_POPUPS do
        local rollID = overlays[i] and NS.Compat.RollPopupOpen(i)
        if rollID and allowed(i) then paint(i, rollID) else hideKey(i) end
    end
    if standInRoll and allowed(RP.STAND_IN) then
        paint(RP.STAND_IN, standInRoll)
        standIn:Show()
    else
        hideKey(RP.STAND_IN)
        if standIn then standIn:Hide() end
    end
end

-- The hooks' bodies (one-way: they gate on the disabled state).
local function onShow(i)
    if stoodDown() then return end
    local rollID = NS.Compat.RollPopupOpen(i)
    if not (rollID and allowed(i)) then return hideKey(i) end
    paint(i, rollID)
end

local function onHide(i)
    if stoodDown() then return end
    hideKey(i)
end

--- Create the overlays and install the hooks, once (core/DropWatcher.lua's OnEnable). A popup the
--- client does not have gets neither.
function RP.Install()
    if installed then return end
    installed = true
    for i = 1, NS.Compat.ROLL_POPUPS do
        local popup = NS.Compat.RollPopupFrame(i)
        if popup then
            overlays[i] = newOverlay(popup)
            NS.Compat.HookRollPopup(i, onShow, onHide)
        end
    end
    NS.Debug(TAG, "installed on %d popups", #overlays)
end

--- The overlay `key` (1..4, or RP.STAND_IN), or nil (the suites and the diagnostics).
function RP.Overlay(key) return overlays[key] end

--- The simulator's stand-in popup, or nil before the first simulated roll.
function RP.StandIn() return standIn end

-- The stand-in: an owned card of the popup's size, titled, built on the first simulated roll.
local function buildStandIn()
    local f = NS.DetailCard.Box(UIParent)
    f:SetFrameStrata(C.LAYERS.STRATA.ALERT)
    f:SetSize(RP.STAND_IN_W, RP.STAND_IN_H)
    f:SetPoint("CENTER", UIParent, "CENTER", 0, RP.STAND_IN_Y)
    f.title = faced(f)
    f.title:SetPoint("TOP", f, "TOP", 0, -RP.PAD)
    NS.Skin.Text(f.title, "dw.idle")
    f.title:SetText(L["Roll popup (simulated)"])
    f.item = faced(f)
    f.item:SetPoint("CENTER", f, "CENTER", 0, 0)
    f:Hide()
    overlays[RP.STAND_IN] = newOverlay(f)
    return f
end

local function showStandIn(rollID)
    standIn = standIn or buildStandIn()
    standInRoll = rollID
    local e = cache[rollID]
    standIn.item:SetText(e and e.link or "")
end

-- ── the events ──────────────────────────────────────────────────────────────────────────────

--- START_LOOT_ROLL(rollID): your popup's item, read and judged; a simulated roll gets the stand-in.
function RP.OnStartRoll(rollID)
    if stoodDown() then return end
    if not learn(rollID) then return end
    if NS.Sim:IsDelivering() then showStandIn(rollID) end
    refresh()
end

--- CANCEL_LOOT_ROLL(rollID): that popup is gone.
function RP.OnCancelRoll(rollID)
    if stoodDown() then return end
    cache[rollID] = nil
    if standInRoll == rollID then standInRoll = nil end
    for key, id in pairs(drawn) do
        if id == rollID then hideKey(key) end
    end
    if standIn and not standInRoll then standIn:Hide() end
end

--- Your gear moved: every cached verdict judged again, the shown overlays repainted.
function RP.OnGearChanged()
    if stoodDown() then return end
    for _, e in pairs(cache) do
        if e.facts then judge(e, e.facts) end
    end
    refresh()
end

--- Repaint the shown overlays (PendingChanged, the `rolls.popupMark` row).
function RP.Refresh()
    if stoodDown() then return end
    refresh()
end

-- Both clients. START_LOOT_ROLL and CANCEL_LOOT_ROLL are modules/Pending.lua's too: its rows come
-- first, so a popup has claimed its pending item before it is drawn.
local EVENTS = {
    { "START_LOOT_ROLL", "OnRollPopupStart", RP.OnStartRoll },
    { "CANCEL_LOOT_ROLL", "OnRollPopupCancel", RP.OnCancelRoll },
}
for _, row in ipairs(EVENTS) do
    local fn = row[3]
    NS.FEATURE_EVENTS[#NS.FEATURE_EVENTS + 1] = { row[1], row[2] }
    NS.addon[row[2]] = function(_, _, ...) fn(...) end
end

-- The bus receivers: tracked, so the stand-down takes them down and the stand-up replays them;
-- without the bus library they are a bare target, unregistered here instead (NS.Bus.tracked).
local target = NS.Bus:NewTarget()

local function listen()
    if not target then return end
    target:RegisterMessage(NS.MSG.PENDING_CHANGED, function() RP.Refresh() end)
    target:RegisterMessage(NS.MSG.GEAR_CHANGED, function() RP.OnGearChanged() end)
end
listen()

NS.STAND_DOWN[#NS.STAND_DOWN + 1] = function()
    generation = generation + 1
    if target and not NS.Bus.tracked then target:UnregisterAllMessages() end
    for key in pairs(overlays) do hideKey(key) end
    if standIn then standIn:Hide() end
    cache, drawn, standInRoll = {}, {}, nil
end
NS.STAND_UP[#NS.STAND_UP + 1] = function()
    if not NS.Bus.tracked then listen() end
    for _, rollID in ipairs(NS.Compat.ActiveLootRolls()) do learn(rollID) end
    refresh()
end
