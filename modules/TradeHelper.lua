local _, NS = ...
-- modules/TradeHelper.lua — hands one of your drops to a group member, or opens a trade with one
-- (design spec §4). Called only from a click (the My drops tab and the Offer panel, DW-33); it
-- registers no event and keeps no timer.
--
-- GIVE. Give(dropID, target) finds the drop's bag item by its GUID (the trade timer's entry,
-- NS.TradeTimer.ForDrop), at the slot the entry last saw first and by a walk of the bags second, so
-- an item moved since the last scan is still found; then NS.Compat.PickupBagItem puts it on the
-- cursor and NS.Compat.DropItemOnUnit drops it on the member, which opens the trade with the item
-- in it. OPEN. Open(target) is NS.Compat.InitiateTrade: an empty trade window.
--
-- THE GUARDS, checked in this order before anything touches the client, each refusal answered as
-- (false, reason) so the button can be disabled with the reason as its tooltip (ReasonText):
--   stoodDown   the addon is disabled
--   combat      NS.Restrictions.CanTrade() says no (the range read is protected in combat too)
--   noTarget    the target is not a member of the group (NS.Roster.Resolve: a GUID or a name)
--   self        the target is you
--   offline     the member is offline
--   range       the member is outside trade range (NS.Compat.InTradeRange)
-- and for Give only, after those:
--   notInBags   no bag item carries the drop's GUID (not yours, never scanned, or gone)
--   expired     the trade timer read the item's window as passed (spec §7.4's `no expired`); a BoE
--               drop has no window (its entry is `permanent`) and is never refused for it
--   cursorBusy  the cursor already holds something, which a pickup would swap away
--   noApi       the client lacks the call; a pickup already made is put back (ClearCursor)
--
-- SECRETS. The target and the member's fields come through NS.Roster, which guards every unit
-- answer; the bag GUIDs come through NS.Compat.GetBagItemGUID, which answers nil for a secret one;
-- the range and cursor reads answer a secret as "no".

NS.TradeHelper = NS.TradeHelper or {}
local TH = NS.TradeHelper
local C = NS.Constants
local L = NS.L
local State = NS.State

local TAG = "TRADE"

-- Every refusal reason, with the tooltip line the button shows.
TH.REASON_TEXT = {
    stoodDown  = L["Drop Watcher is disabled."],
    combat     = L["You cannot trade in combat."],
    noTarget   = L["That player is not in your group."],
    self       = L["You cannot trade with yourself."],
    offline    = L["That player is offline."],
    range      = L["That player is out of trade range."],
    notInBags  = L["That item is not in your bags."],
    expired    = L["The trade window for that item has passed."],
    cursorBusy = L["Your cursor is holding an item."],
    noApi      = L["This client cannot open a trade."],
}

--- The tooltip line for a refusal reason, or nil for none.
--- @param reason string|nil
--- @return string|nil
function TH.ReasonText(reason)
    return reason and TH.REASON_TEXT[reason]
end

local function stats()
    local s = State.tradeHelper
    if not s then
        s = { gives = 0, opens = 0, refused = 0 }
        State.tradeHelper = s
    end
    return s
end

--- Diagnostics: { gives, opens, refused, lastReason }, or nil before the first call.
--- @return table|nil
function TH.Stats()
    return State.tradeHelper
end

local function refuse(what, reason)
    local s = stats()
    s.refused, s.lastReason = s.refused + 1, reason
    NS.Debug(TAG, "%s refused: %s", what, reason)
    return false, reason
end

-- ── the target ──────────────────────────────────────────────────────────────────────────────

-- The member a target names and the reason it cannot be traded with, or nil for none. Combat is
-- read before the range, whose call the client restricts in combat.
local function memberFor(target)
    if NS.IsStoodDown ~= nil and NS.IsStoodDown() then return nil, "stoodDown" end
    if not NS.Restrictions.CanTrade() then return nil, "combat" end
    local m = target and NS.Roster.Resolve(target)
    if not (m and m.unit) then return nil, "noTarget" end
    if m.isPlayer then return nil, "self" end
    if m.online == false then return nil, "offline" end
    if not NS.Compat.InTradeRange(m.unit) then return nil, "range" end
    return m, nil
end

--- Whether a trade with `target` (a member's GUID, "Name-Realm" or "Name") may be opened now.
--- @param target string
--- @return boolean ok
--- @return string|nil reason
function TH.CanTradeWith(target)
    local _, reason = memberFor(target)
    return reason == nil, reason
end

-- ── the item ────────────────────────────────────────────────────────────────────────────────

--- The bag and slot of the item with this GUID: the hinted slot first, then every bag.
--- @param guid string
--- @param hintBag number|nil
--- @param hintSlot number|nil
--- @return number|nil bag
--- @return number|nil slot
function TH.FindBagSlot(guid, hintBag, hintSlot)
    if not NS.Compat.IsSafeKey(guid) then return nil, nil end
    local Compat = NS.Compat
    if hintBag and hintSlot and Compat.GetBagItemGUID(hintBag, hintSlot) == guid then
        return hintBag, hintSlot
    end
    for _, bag in ipairs(C.BAG_IDS) do
        for slot = 1, Compat.BagSlotCount(bag) do
            if Compat.GetBagItemGUID(bag, slot) == guid then return bag, slot end
        end
    end
    return nil, nil
end

-- The drop's bag slot, or nil and the reason it cannot be given.
local function itemFor(dropID)
    local e = NS.TradeTimer.ForDrop(dropID)
    if not e then return nil, nil, "notInBags" end
    if e.expired then return nil, nil, "expired" end
    local bag, slot = TH.FindBagSlot(e.guid, e.bag, e.slot)
    if not bag then return nil, nil, "notInBags" end
    return bag, slot, nil
end

--- Whether drop `dropID` may be handed to `target` now: every guard of Give, nothing touched.
--- @param dropID number
--- @param target string
--- @return boolean ok
--- @return string|nil reason
function TH.CanGive(dropID, target)
    local _, reason = memberFor(target)
    if reason then return false, reason end
    local _, _, itemReason = itemFor(dropID)
    return itemReason == nil, itemReason
end

-- ── the actions ─────────────────────────────────────────────────────────────────────────────

-- Pick the item up and drop it on the unit. A pickup with nowhere to drop is put back.
local function handOver(bag, slot, unit)
    local Compat = NS.Compat
    if not Compat.PickupBagItem(bag, slot) then return "noApi" end
    if Compat.DropItemOnUnit(unit) then return nil end
    Compat.ClearCursor()
    return "noApi"
end

--- Hand drop `dropID` to `target`: its bag item onto the cursor, then onto the member, which opens
--- the trade with the item in it.
--- @param dropID number
--- @param target string a member's GUID, "Name-Realm" or "Name"
--- @return boolean ok
--- @return string|nil reason
function TH.Give(dropID, target)
    local m, reason = memberFor(target)
    if reason then return refuse("give", reason) end
    local bag, slot, itemReason = itemFor(dropID)
    if itemReason then return refuse("give", itemReason) end
    if NS.Compat.CursorHasItem() then return refuse("give", "cursorBusy") end
    local failed = handOver(bag, slot, m.unit)
    if failed then return refuse("give", failed) end
    stats().gives = stats().gives + 1
    NS.Debug(TAG, "give: drop %s from %d:%d to %s", tostring(dropID), bag, slot, m.unit)
    return true, nil
end

--- Open an empty trade with `target`.
--- @param target string a member's GUID, "Name-Realm" or "Name"
--- @return boolean ok
--- @return string|nil reason
function TH.Open(target)
    local m, reason = memberFor(target)
    if reason then return refuse("open", reason) end
    if not NS.Compat.InitiateTrade(m.unit) then return refuse("open", "noApi") end
    stats().opens = stats().opens + 1
    NS.Debug(TAG, "open: trade with %s", m.unit)
    return true, nil
end
