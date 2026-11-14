local _, NS = ...
-- modules/RollPopup.lua — your verdict on Blizzard's roll popup (Forever port design §7, plan
-- DW-FP20; the side card, rolls UX design §3.3, ruling 1, RX-07), on both clients: a small owned
-- card beside each GroupLootFrame1..4 while it is up.
--
--   line 1  the verdict's mark and word, and the gain: `▲ Upgrade +12 · score +4.1`, `Can't use`.
--           On WoW Forever a bound-on-pickup drop (soulbound once looted, design §4.6) reads
--           `▲ Need: upgrade +12` when it is an upgrade and `Greed / Pass: you can't use it` when you
--           can't use it; any other verdict keeps its word. A non-gear item (a lockbox, a bag, an
--           item of no kind, RX-04) reads its kind word in the neutral tone, with no gain.
--   line 2  the count line while the roll is open (NS.RollCells.CountLine, RX-06): an icon and a
--           count per choice, Need, Greed, Disenchant (Retail only), Pass and still to roll, of the
--           pending roll this popup claimed (NS.Pending.ForRoll: joined by item ID, the oldest
--           unclaimed item first, so two copies of one item keep their own counts, Review Focus 1).
--           None when the drop is not pending (the feed's gates refused it, design §11.1: the mark
--           is shown for every roll, because Blizzard already shows the popup).
--   hover   every roll (NS.RollCells.Tooltip): the item, a row per choice highest roll first, those
--           still to roll, the time left and your verdict at the foot; read on every hover.
--
-- THE FRAMES. One card per popup, created at enable (RP.Install, from core/DropWatcher.lua's
-- OnEnable), parented to UIParent, at the alert tier (C.LAYERS.STRATA.ALERT), in the window's own
-- skin (NS.ApplySkin and S.Shell, as modules/Window.lua builds the main window: `win.bg` under
-- `win.border`, following every skin). Placed on every paint: its TOPLEFT on the popup's TOPRIGHT,
-- RP.GAP out, or, when the popup's right edge plus the gap and the card's width is past the
-- screen's (UIParent's width), its TOPRIGHT on the popup's TOPLEFT (RP.Side). A card is shorter
-- than its popup, so four stacked popups keep four cards apart. Blizzard's popups are read through
-- NS.Compat (core/CompatLoot.lua): RollPopupFrame (for the anchor), RollPopupRight (its right edge,
-- a read), HookRollPopup and RollPopupOpen. Nothing is ever written to a Blizzard frame or its
-- table: no field, no SetScript, SetParent, SetPoint or strata change; the one call made on it is
-- HookScript, once (R2 §10.2, events-frames-taint-§6).
--
-- THE HOOKS are one-way (HookScript can't be removed), so their bodies gate on the disabled state
-- (slash-commands-§7). OnShow re-checks that the popup is still shown with a plain rollID
-- (Compat.RollPopupOpen), because Blizzard's own OnShow can remove it again at once (R2, skeptic
-- correction 6); OnHide takes the card down.
--
-- THE DATA. START_LOOT_ROLL(rollID) reads Compat.LootRollInfo (link, bop) and judges the item for
-- you through the feed's own judge (NS.LootFeed.JudgeMe over NS.ItemFacts), cached by rollID;
-- CANCEL_LOOT_ROLL drops it. A popup shown with no cached entry (a reload) asks once. A pending
-- item's verdict is preferred when it has one (the store re-judges it on the score retry). The
-- shown cards repaint on PendingChanged (a Need lands), GearChanged (your verdict is judged
-- again), the `rolls.popupMark` row (Drops › Rolls) and the stand-up.
--
-- NOT DRAWN while the addon is disabled, while `rolls.popupMark` is off, and while the client's
-- gamepad UI is on (Compat.GamepadUI): WoW Forever then shows its rolls in
-- GamepadGroupLootRollFrame and GroupLootFrame1..4 are not used (a recorded limitation).
--
-- THE SIMULATOR invents no Blizzard popup, so a simulated roll (START_LOOT_ROLL delivered by
-- NS.Sim) is drawn on an owned stand-in of the popup's size (RP.StandIn(n)), one per open roll up
-- to RP.STAND_INS, the first centered above the middle of the screen and each next one stacked
-- above it, as the game stacks its own, each with its own side card; a stand-in goes with its
-- roll's CANCEL_LOOT_ROLL. `/dw sim roll` twice shows two, to show the placement.

NS.RollPopup = NS.RollPopup or {}
local RP = NS.RollPopup
local L = NS.L
local C = NS.Constants

local TAG = "POPUP"

RP.WIDTH = 150        -- the card's least width
RP.PAD = 6            -- inside the card
RP.LINE = 14          -- one line's height
RP.GAP = 4            -- between the popup's edge and the card
RP.STAND_IN_W, RP.STAND_IN_H = 280, 82   -- the size of Blizzard's popup, for the simulator's stand-ins
RP.STAND_IN_Y = 140   -- the first stand-in's offset above the screen's center
RP.STAND_IN_GAP = 4   -- between two stacked stand-ins
RP.STAND_INS = 4      -- as many as the game's popups
RP.STAND_IN = "standIn"   -- the stand-in cards' key prefix (RP.StandInKey)

--- The card key of stand-in `n` (`standIn1`..).
--- @param n number
--- @return string
function RP.StandInKey(n) return RP.STAND_IN .. n end

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

local overlays = {}   -- [1..4] and [RP.StandInKey(n)]: the owned cards
local drawn = {}      -- [key] = the rollID that card shows
local cache = {}      -- [rollID] = { rollID, link, itemID, bop, facts, me }
local standIns = {}   -- [n] = the simulator's stand-in popup n
local standInRolls = {}   -- [n] = the rollID stand-in n shows
local installed = false
local generation = 0  -- bumped at every stand-down: an item load answering after it is ignored

local function stoodDown()
    return NS.IsStoodDown ~= nil and NS.IsStoodDown()
end

local function num(v) return type(v) == "number" and v or nil end

-- ── the lines (pure) ────────────────────────────────────────────────────────────────────────

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

--- What one card says: line 1 (RP.Verdict) and `counts`, line 2 (NS.RollCells.CountLine) while
--- the pending roll `item` is open with someone on it, else nil.
--- @param me table|nil
--- @param bop boolean|nil
--- @param item table|nil the NS.Pending item the popup claimed
--- @param client string|nil
--- @return table { text, tone, verdict, counts }
function RP.Lines(me, bop, item, client)
    local out = RP.Verdict(me, bop, client)
    if type(item) == "table" and item.state == "open" and type(item.roll) == "table" then
        local line = NS.RollCells.CountLine(item.roll)
        if line ~= "" then out.counts = line end
    end
    return out
end

--- Which side of its popup a card goes: `right` when the popup's right edge, RP.GAP and the card's
--- width fit inside the screen's width (all in UIParent's units), else `left`. Unknown geometry
--- answers `right`, the design's place.
--- @param right number|nil the popup's right edge
--- @param cardW number|nil
--- @param screenW number|nil
--- @return string
function RP.Side(right, cardW, screenW)
    right, cardW, screenW = num(right), num(cardW), num(screenW)
    if not (right and cardW and screenW and screenW > 0) then return "right" end
    return right + RP.GAP + cardW <= screenW and "right" or "left"
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

local function faced(parent, justify)
    local fs = parent:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    fs:SetJustifyH(justify or "LEFT")
    fs:SetWordWrap(false)
    NS.Skin.Font(fs)
    return fs
end

-- An owned frame in the window's skin: the skin's backdrop (NS.ApplySkin) and S.Shell over it, as
-- modules/Window.lua paints the main window, with no title band.
local function skinned(w, h)
    local f = CreateFrame("Frame", nil, UIParent, "BackdropTemplate")
    f:SetFrameStrata(C.LAYERS.STRATA.ALERT)
    f:SetSize(w, h)
    NS.ApplySkin(f)
    NS.Skin.Shell(f, { noTopBar = true })
    return f
end

local tipOf

-- One owned card, hidden, its anchor `anchor` (placed beside it on every paint, never the other
-- way round), its tooltip every roll of the roll it shows.
local function newOverlay(anchor)
    local f = skinned(RP.WIDTH, RP.LINE + 2 * RP.PAD)
    f.anchor = anchor
    f.line1 = faced(f)
    f.line1:SetPoint("TOPLEFT", f, "TOPLEFT", RP.PAD, -RP.PAD)
    f.line2 = faced(f)
    f.line2:SetPoint("TOPLEFT", f.line1, "BOTTOMLEFT", 0, -2)
    f.line2:Hide()
    NS.Window.AttachTooltip(f, function() return unpack(tipOf(f)) end)
    f:Hide()
    return f
end

local function setTone(fs, tone) NS.WindowRows.SetTone(fs, tone) end

-- A plain geometry read on an owned frame, a number or nil (an unplaced frame answers nil).
local function geom(f, method)
    local fn = f and f[method]
    local v = type(fn) == "function" and fn(f) or nil
    if NS.Compat.IsSecret(v) then return nil end
    return num(v)
end

-- The right edge of card `key`'s popup in UIParent's units: Blizzard's through NS.Compat, a
-- stand-in's read off the owned frame.
local function anchorRight(key, o)
    if type(key) == "number" then return NS.Compat.RollPopupRight(key) end
    return geom(o.anchor, "GetRight")
end

-- Card `key` beside its popup: right of it, or left of it near the screen's right edge.
local function place(key, o)
    local side = RP.Side(anchorRight(key, o), geom(o, "GetWidth"), geom(UIParent, "GetWidth"))
    o:ClearAllPoints()
    if side == "right" then
        o:SetPoint("TOPLEFT", o.anchor, "TOPRIGHT", RP.GAP, 0)
    else
        o:SetPoint("TOPRIGHT", o.anchor, "TOPLEFT", -RP.GAP, 0)
    end
end

-- What a hover over card `o` shows, read now: every roll of the pending roll its popup claimed
-- (the popup's item alone when none), the time left, and your verdict at the foot.
tipOf = function(o)
    local rollID = o.rollID
    local e = rollID and cache[rollID]
    if not e then return {} end
    local item = NS.Pending.ForRoll(rollID)
    local roll = item and type(item.roll) == "table" and item.roll or { link = e.link }
    return NS.RollCells.Tooltip(roll, { verdict = o.verdict, now = NS.Compat.LootHistoryNow(), rollID = rollID })
end

local function hideKey(key)
    local o = overlays[key]
    if o then o:Hide() end
    drawn[key] = nil
end

-- Whether the mark may be drawn now (a stand-in is the addon's own frame: no gamepad gate).
local function allowed(key)
    if stoodDown() or NS.Setting("rolls.popupMark") == false then return false end
    return type(key) ~= "number" or not NS.Compat.GamepadUI()
end

-- Line 2: the count line, or hidden. Answers the lines drawn.
local function paintCounts(o, counts)
    if not counts then
        o.line2:SetText("")
        o.line2:Hide()
        return 1
    end
    o.line2:SetText(counts)
    setTone(o.line2, "plain")
    o.line2:Show()
    return 2
end

-- Draw card `key` for `rollID`: its lines, its size, its place, shown.
local function paint(key, rollID)
    local o = overlays[key]
    local e = cache[rollID] or learn(rollID)
    if not (o and e) then return hideKey(key) end
    local item = NS.Pending.ForRoll(rollID)
    local model = RP.Lines((item and item.me) or e.me, e.bop, item)
    o.line1:SetText(model.text)
    setTone(o.line1, model.tone)
    local lines = paintCounts(o, model.counts)
    o.rollID, o.verdict = rollID, { text = model.text, tone = model.tone }
    local w = math.max(num(o.line1:GetStringWidth()) or 0, num(o.line2:GetStringWidth()) or 0)
    o:SetSize(math.max(RP.WIDTH, w + 2 * RP.PAD), lines * RP.LINE + (lines - 1) * 2 + 2 * RP.PAD)
    place(key, o)
    o:Show()
    drawn[key] = rollID
end

-- Every card drawn again from the current state: a shown popup, and each stand-in's roll.
refresh = function()
    for i = 1, NS.Compat.ROLL_POPUPS do
        local rollID = overlays[i] and NS.Compat.RollPopupOpen(i)
        if rollID and allowed(i) then paint(i, rollID) else hideKey(i) end
    end
    for n = 1, RP.STAND_INS do
        local key, rollID = RP.StandInKey(n), standInRolls[n]
        if rollID and allowed(key) then
            paint(key, rollID)
            standIns[n]:Show()
        else
            hideKey(key)
            if standIns[n] then standIns[n]:Hide() end
        end
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

--- Create the cards and install the hooks, once (core/DropWatcher.lua's OnEnable). A popup the
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

--- The card `key` (1..4, or RP.StandInKey(n)), or nil (the suites and the diagnostics).
function RP.Overlay(key) return overlays[key] end

--- The simulator's stand-in popup `n` (1 by default), or nil before a simulated roll needed it.
--- @param n number|nil
function RP.StandIn(n) return standIns[n or 1] end

-- Stand-in `n`: an owned frame of the popup's size, titled, stacked above stand-in n - 1, built
-- when a simulated roll first needs it, with its side card.
local function buildStandIn(n)
    local f = skinned(RP.STAND_IN_W, RP.STAND_IN_H)
    f:SetPoint("CENTER", UIParent, "CENTER", 0, RP.STAND_IN_Y + (n - 1) * (RP.STAND_IN_H + RP.STAND_IN_GAP))
    f.title = faced(f, "CENTER")
    f.title:SetPoint("TOP", f, "TOP", 0, -RP.PAD)
    NS.Skin.Text(f.title, "dw.idle")
    f.title:SetText(L["Roll popup (simulated)"])
    f.item = faced(f, "CENTER")
    f.item:SetPoint("CENTER", f, "CENTER", 0, 0)
    f:Hide()
    overlays[RP.StandInKey(n)] = newOverlay(f)
    return f
end

-- The first stand-in with no roll, or nil when every one shows a roll.
local function freeStandIn()
    for n = 1, RP.STAND_INS do
        if not standInRolls[n] then return n end
    end
    return nil
end

local function showStandIn(rollID)
    local n = freeStandIn()
    if not n then return NS.Debug(TAG, "every stand-in is up: roll %s not drawn", tostring(rollID)) end
    standIns[n] = standIns[n] or buildStandIn(n)
    standInRolls[n] = rollID
    local e = cache[rollID]
    standIns[n].item:SetText(e and e.link or "")
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
    for n = 1, RP.STAND_INS do
        if standInRolls[n] == rollID then
            standInRolls[n] = nil
            if standIns[n] then standIns[n]:Hide() end
        end
    end
    for key, id in pairs(drawn) do
        if id == rollID then hideKey(key) end
    end
end

--- Your gear moved: every cached verdict judged again, the shown cards repainted.
function RP.OnGearChanged()
    if stoodDown() then return end
    for _, e in pairs(cache) do
        if e.facts then judge(e, e.facts) end
    end
    refresh()
end

--- Repaint the shown cards (PendingChanged, the `rolls.popupMark` row).
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
    for _, f in pairs(standIns) do f:Hide() end
    cache, drawn, standInRolls = {}, {}, {}
end
NS.STAND_UP[#NS.STAND_UP + 1] = function()
    if not NS.Bus.tracked then listen() end
    for _, rollID in ipairs(NS.Compat.ActiveLootRolls()) do learn(rollID) end
    refresh()
end
