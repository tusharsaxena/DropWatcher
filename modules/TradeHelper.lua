local _, NS = ...
-- modules/TradeHelper.lua — opens a trade with a group member (design spec §4). Called only from a
-- click (the detail card's Trade, NS.TradeWithLooter); it registers no event and keeps no timer.
--
-- OPEN. Open(target) is NS.Compat.InitiateTrade: an empty trade window. The give path that placed
-- one of your drops in the trade (Give, for the Offer panel's Trade button) was retired with that
-- button (feedback-7 spec §0).
--
-- THE GUARDS, checked in this order before anything touches the client, each refusal answered as
-- (false, reason) so the button can be disabled with the reason as its tooltip (ReasonText):
--   stoodDown   the addon is disabled
--   combat      NS.Restrictions.CanTrade() says no (the range read is protected in combat too)
--   noTarget    the target is not a member of the group (NS.Roster.Resolve: a GUID or a name)
--   self        the target is you
--   offline     the member is offline
--   range       the member is outside trade range (NS.Compat.InTradeRange)
--   noApi       the client lacks the call
--
-- SECRETS. The target and the member's fields come through NS.Roster, which guards every unit
-- answer; the range read answers a secret as "out of range".

NS.TradeHelper = NS.TradeHelper or {}
local TH = NS.TradeHelper
local L = NS.L
local State = NS.State

local TAG = "TRADE"

-- Every refusal reason, with the tooltip line the button shows.
TH.REASON_TEXT = {
    stoodDown  = L["%s is disabled."]:format(NS.BRAND),
    combat     = L["You cannot trade in combat."],
    noTarget   = L["That player is not in your group."],
    self       = L["You cannot trade with yourself."],
    offline    = L["That player is offline."],
    range      = L["That player is out of trade range."],
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
        s = { opens = 0, refused = 0 }
        State.tradeHelper = s
    end
    return s
end

--- Diagnostics: { opens, refused, lastReason }, or nil before the first call.
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

-- ── the action ──────────────────────────────────────────────────────────────────────────────

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
