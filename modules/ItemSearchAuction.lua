local _, NS = ...
-- modules/ItemSearchAuction.lua — a Sell verdict's Auction or Vendor answer (R5-DW-13..16, the
-- owner: "if auction price (plus auction house cut) > vendor price by X% then give an AUCTION
-- verdict, else give a VENDOR verdict"). WoW Forever's alone today, as the verdict is
-- (C.FEATURE.itemSearch); the rule and its constants are both clients' (C.ITEM_SEARCH.AUCTION).
--
-- THE RULE (IAU.Via, pure: every input is an argument). Per unit, from the client's facts the
-- verdict reads (`item.sellPrice`, the vendor's price; `item.bindType`; `item.stackCount`) and the
-- price Auctionator last saw (`item.auctionPrice`, NS.Compat.AuctionPrice's, the edge's read):
--   net = price x (1 - cut / 100) - deposit
--   deposit = max(vendor x C.ITEM_SEARCH.AUCTION.DEPOSIT[duration], MIN_DEPOSIT / stackCount)
-- The deposit counts as a cost: it is lost when the auction does not sell, so the cautious
-- reading charges it. Auction when net > vendor x (1 + margin / 100), else Vendor. A bound item
-- (C.ITEM_SEARCH.AUCTION.BOUND), no price (Auctionator absent, not loaded, or no scan of the item)
-- or the comparison switched off answers Vendor. `rule` is IAU.Rule's: { on, duration, cut,
-- margin }, the settings `itemSearch.auction.*` read and bounded.
--
-- THE WORDS. The verdict key stays "sell" (score bands, sorting and every reader of it unchanged);
-- `sellVia` ("auction" | "vendor") is the sub-answer, with the prices used. IAU.Look names the
-- badge's look key (keep, hold, auction, vendor, toss), IAU.Word its word, IAU.Reason the reason
-- line ("Auction ~1g 20s after the cut and deposit, vendor 80s"), IAU.From the breakdown's word line
-- and IAU.HelpLines the (?) help's lines, from the live settings.

NS.ItemSearchAuction = NS.ItemSearchAuction or {}
local IAU = NS.ItemSearchAuction
local C = NS.Constants
local L = NS.L

local A = C.ITEM_SEARCH.AUCTION
local floor, max = math.floor, math.max

local function num(v)
    if type(v) == "number" and v == v then return v end
    return nil
end

-- ── the rule ────────────────────────────────────────────────────────────────────────────────

--- Whether an auction takes an item of bind type `bindType` (C.ITEM_SEARCH.AUCTION.BOUND's are
--- never auctioned; an unknown bind type is not held against it).
--- @param bindType number|nil
--- @return boolean
function IAU.Auctionable(bindType)
    return not A.BOUND[bindType or 0]
end

--- Whether `hours` is one of this client's auction lengths (C.ITEM_SEARCH.AUCTION.DURATIONS).
--- @param hours any
--- @return boolean
function IAU.ValidDuration(hours)
    return A.DEPOSIT[hours] ~= nil
end

--- The deposit a unit pays, in copper (see the header): the vendor price's share by the auction's
--- length (an unknown length reads the default one), at least MIN_DEPOSIT over a stack of
--- `stackCount` (1 when unknown).
--- @param vendor number
--- @param hours number
--- @param stackCount number|nil
--- @return number
function IAU.Deposit(vendor, hours, stackCount)
    local rate = A.DEPOSIT[hours] or A.DEPOSIT[A.DURATION]
    local stack = max(1, num(stackCount) or 1)
    return max(vendor * rate, A.MIN_DEPOSIT / stack)
end

--- What a unit's auction brings after the house's cut and the deposit, in copper (may be negative).
--- @param price number Auctionator's price a unit
--- @param vendor number the vendor's price a unit
--- @param rule table IAU.Rule's
--- @param stackCount number|nil
--- @return number
function IAU.Net(price, vendor, rule, stackCount)
    return price * (1 - rule.cut / 100) - IAU.Deposit(vendor, rule.duration, stackCount)
end

--- A Sell verdict's answer: "auction" or "vendor", and the net and the price it was judged on (nil
--- each when there was no comparison: the switch off, a bound item, no price). Pure.
--- @param item table the client's facts (sellPrice, bindType, stackCount, auctionPrice)
--- @param rule table|nil IAU.Rule's; nil compares nothing
--- @return string via, number|nil net, number|nil price
function IAU.Via(item, rule)
    local vendor = num(item.sellPrice) or 0
    if not (rule and rule.on) or not IAU.Auctionable(item.bindType) then return "vendor", nil, nil end
    local price = num(item.auctionPrice)
    if not price or price <= 0 then return "vendor", nil, nil end
    local net = IAU.Net(price, vendor, rule, item.stackCount)
    if net > vendor * (1 + rule.margin / 100) then return "auction", net, price end
    return "vendor", net, price
end

-- A whole number setting within lo..hi, else `default`.
local function within(v, lo, hi, default)
    v = num(v)
    if not v or v < lo or v > hi then return default end
    return v
end

local rule = {}

--- The comparison's settings now, bounded (`itemSearch.auction.*`: on, duration, cut, margin): one
--- table, filled again on each call (read, never kept by a caller past its own work).
--- @return table
function IAU.Rule()
    local S = NS.Setting
    rule.on = S("itemSearch.auction.enabled") ~= false
    local hours = S("itemSearch.auction.duration")
    rule.duration = IAU.ValidDuration(hours) and hours or A.DURATION
    rule.cut = within(S("itemSearch.auction.cut"), 0, A.CUT_MAX, A.CUT)
    rule.margin = within(S("itemSearch.auction.margin"), 0, A.MARGIN_MAX, A.MARGIN)
    return rule
end

-- ── the words ───────────────────────────────────────────────────────────────────────────────

--- The badge's look key for a verdict answer: "auction" or "vendor" for a Sell, else its verdict.
--- @param v table
--- @return string
function IAU.Look(v)
    if v.verdict ~= "sell" then return v.verdict or "hold" end
    return v.sellVia == "auction" and "auction" or "vendor"
end

--- A Sell's word: "Auction" or "Vendor".
--- @param via string|nil
--- @return string
function IAU.Word(via)
    if via == "auction" then return L["Auction"] end
    return L["Vendor"]
end

local function money(copper)
    copper = floor(max(0, copper) + 0.5)
    return NS.Compat.CoinText(copper) or tostring(copper)
end

--- A Sell's reason line, the prices first: Auction's "Auction ~<net> after the cut and deposit,
--- vendor <price>", a Vendor judged against a price "Vendor <price>, auction ~<net> after the cut
--- and deposit", else the vendor's price alone ("Sells for <price>").
--- @param via string
--- @param vendor number
--- @param net number|nil
--- @return string
function IAU.Reason(via, vendor, net)
    if net and via == "auction" then
        return L["Auction ~%s after the cut and deposit, vendor %s"]:format(money(net), money(vendor))
    end
    if net then return L["Vendor %s, auction ~%s after the cut and deposit"]:format(money(vendor), money(net)) end
    return L["Sells for %s"]:format(money(vendor))
end

--- The breakdown's word line for a Sell, in plain words (as the other verdicts' lines).
--- @param via string
--- @param net number|nil
--- @param bar number the score under which a verdict sells
--- @param margin number the rule's margin, in percent
--- @return string
function IAU.From(via, net, bar, margin)
    if via == "auction" then
        return L["Auction: a score under %d, and an auction beats the vendor by over %d%%"]:format(bar, margin)
    end
    if net then
        return L["Vendor: a score under %d, and an auction does not beat the vendor by over %d%%"]:format(bar, margin)
    end
    return L["Vendor: a score under %d, and a vendor buys it"]:format(bar)
end

--- The (?) help's lines on Auction and Vendor, from the live settings (IAU.Rule) and whether
--- Auctionator is loaded: a new list each call (a hover's).
--- @param bar number the score under which a verdict sells
--- @return table
function IAU.HelpLines(bar)
    local r = IAU.Rule()
    local out = { L["  Under %d: Auction or Vendor when a vendor buys it, else Toss."]:format(bar) }
    if not r.on then
        out[#out + 1] = L["  Compare with Auctionator prices is off: a sale is always Vendor."]
    elseif not NS.Compat.AuctionatorLoaded() then
        out[#out + 1] = L["  Auctionator is not loaded: a sale is always Vendor."]
    else
        local rate = floor((A.DEPOSIT[r.duration] or 0) * 100 + 0.5)
        out[#out + 1] = L["  Auction when Auctionator's price, less the %d%% cut and the %d-hour deposit (%d%% of the vendor price), beats the vendor by over %d%%; else Vendor. A bound item, or one with no price, is Vendor."]
            :format(r.cut, r.duration, rate, r.margin)
    end
    return out
end
