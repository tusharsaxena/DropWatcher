local _, NS = ...
-- modules/ItemSearchVerdictTips.lua — the tooltips on the Item Search verdict panel's lines
-- (R7-DW-02, the owner: "Add tooltips over each of the elements here, giving more details").
--
-- Each line the panel draws (NS.ItemSearchVerdictPanel's rows) carries a `tip`: `{ key, points }`,
-- where `key` names the rule behind the line: a part of the use value (NS.ItemSearchVerdict's
-- breakdown line `key`), a How sure line (its `sure` row `key`), a section header, the use value's
-- line, a price or the hint. IVT.Lines turns it into the tooltip: a title, then plain lines that
-- wrap. Every number is read from C.ITEM_SEARCH.VERDICT and the live Auction rule
-- (NS.ItemSearchAuction's IAU.Rule) on each hover, never copied by hand, so a tooltip moves with
-- the scorer and the settings, as the (?) help does.

local C, L = NS.Constants, NS.L

local IVT = {}
NS.ItemSearchVerdictTips = IVT

local floor = math.floor

local function V() return C.ITEM_SEARCH.VERDICT end

local function pct(x) return floor(100 * x + 0.5) end

local function coin(copper)
    return NS.Compat.CoinText(copper) or tostring(copper)
end

-- What a cap line took off: its points are negative, the size of the excess.
local function cut(t)
    return L["Taken off here: %d."]:format(math.abs(t.points or 0))
end

local function bands()
    local v = V()
    return L["Keep at %d or more, Hold from %d to %d, and under %d Auction, Vendor or Toss."]:format(v.KEEP, v.HOLD,
        v.KEEP - 1, v.HOLD)
end

-- ── the parts of the use value ──────────────────────────────────────────────────────────────

local PART = {}

PART.questLog = function()
    local v = V()
    return L["A quest that wants it"], {
        L["A quest in your log, or ready to hand in, that needs this item adds %d."]:format(v.QUEST_LOG),
        L["Your quests count %d at most in all."]:format(v.QUESTS_CAP) }
end

PART.questCan = function()
    local v = V()
    return L["Quests you could pick up"], {
        L["Each quest that wants this item and that you could pick up, up to %d levels above you, adds %d."]
            :format(v.QUEST_CAN_ABOVE, v.QUEST_CAN),
        L["Your quests count %d at most in all."]:format(v.QUESTS_CAP),
        L["The Quests tab lists them."] }
end

PART.starts = function()
    return L["Starts a quest"], { L["This item starts a quest you have not done yet: %d."]:format(V().STARTS) }
end

PART.questsCap = function(t)
    return L["Quests count %d at most"]:format(V().QUESTS_CAP), {
        L["The quest parts above add up to more than that, so one long quest list cannot decide the verdict alone."],
        cut(t) }
end

PART.craft = function()
    local c = V().CRAFT
    return L["Your known recipes"], {
        L["Each recipe you know that uses it adds by the skill-up it gives you now: orange %d, yellow %d, green %d, gray nothing."]
            :format(c.orange, c.yellow, c.green),
        L["Your recipes count %d at most."]:format(V().CRAFT_CAP),
        L["The Crafting tab lists them."] }
end

PART.learn = function()
    return L["Recipes you could learn"], {
        L["Each recipe in your professions that uses it and that you don't know yet adds %d."]:format(V().LEARN),
        L["Your recipes count %d at most."]:format(V().CRAFT_CAP) }
end

PART.craftCap = function(t)
    return L["Crafting counts %d at most"]:format(V().CRAFT_CAP), {
        L["Your recipes above add up to more than that, so a long recipe list cannot decide the verdict alone."],
        cut(t) }
end

PART.others = function()
    return L["Other professions"], {
        L["Each recipe in a profession you don't have that uses it adds %d."]:format(V().OTHERS),
        L["Other professions count %d at most."]:format(V().OTHERS_CAP) }
end

PART.othersCap = function(t)
    return L["Other professions count %d at most"]:format(V().OTHERS_CAP), {
        L["Recipes you can't make count for little: a reagent many professions use still isn't one you need."],
        cut(t) }
end

PART.upgrade = function()
    return L["Upgrade for you"], {
        L["Drop Watcher's gear check says it beats what you wear in that slot: %d."]:format(V().UPGRADE) }
end

PART.sidegrade = function()
    return L["Sidegrade"], {
        L["Drop Watcher's gear check says it is about as good as what you wear in that slot: %d."]:format(V().SIDEGRADE) }
end

PART.rebuy = function()
    local v = V()
    return L["Easy to buy again"], {
        L["%d or more vendors sell it, or one sells it for %s or less, so you can buy it back when you need it: %d."]
            :format(v.REBUY_VENDORS, coin(v.REBUY_PRICE), v.REBUY) }
end

PART.trivial = function()
    return L["Every use is gray or done"], {
        L["Every recipe of yours that uses it is gray, and every quest that wants it is done: %d."]:format(V().TRIVIAL) }
end

PART.poorCap = function(t)
    return L["Poor quality counts %d at most"]:format(V().POOR_CAP), {
        L["A gray item counts little, unless a quest wants it."], cut(t) }
end

PART.questFloor = function(t)
    return L["A quest item counts %d at least"]:format(V().QUEST_FLOOR), {
        L["So a quest item is never sold or tossed by mistake."],
        L["Added here: %d."]:format(math.abs(t.points or 0)) }
end

PART.collect = function()
    return L["New to your collection"], {
        L["Something you can collect and don't have yet. It is a Keep, whatever else it is good for: %d."]
            :format(V().COLLECT) }
end

-- ── How sure's lines ────────────────────────────────────────────────────────────────────────

local SURE = {}

SURE.use = function()
    local v, s = V(), V().SURE
    return L["How clear the use value makes it"], {
        L["How far into its band the use value sits. 100%% is a clear call:"],
        L["Keep: %d or more past %d."]:format(s.KEEP_FULL, v.KEEP),
        L["Hold: %d or more from the nearer edge of %d to %d."]:format(s.HOLD_FULL, v.HOLD, v.KEEP - 1),
        L["Auction, Vendor or Toss: %d or more under %d."]:format(s.USE_FULL, v.HOLD) }
end

SURE.money = function()
    local NSA = NS.ItemSearchAuction
    local out = { NSA.ScoreHelp() }
    for _, line in ipairs(NSA.HelpLines(V().HOLD)) do out[#out + 1] = line end
    return L["How clear the money is"], out
end

SURE.evidence = function()
    local s = V().SURE
    return L["Evidence for the word"], {
        L["%d%% for the word, plus %d%% of how clear the call is: the line above, or the weaker of the two above for Auction, Vendor or Toss."]
            :format(pct(s.EDGE), pct(1 - s.EDGE)) }
end

SURE.fallback = function()
    return L["Evidence for Hold, too little known to say more"], {
        L["Under %d, but the sell price is unknown, the gear check is still running or too little is known: Drop Watcher holds instead of guessing, at %d%%."]
            :format(V().HOLD, pct(V().SURE.FALLBACK)) }
end

SURE.data = function()
    local v, w = V(), V().WEIGHT
    return L["Data known"], {
        L["How much of what the verdict needs Drop Watcher has, by weight: ForeverDB loaded %d, your quests %d, your profession skills %d, the item's info %d, the gear check %d (gear only), the item in ForeverDB %d."]
            :format(w.fdb, w.quests, w.ranks, w.item, w.gear, w.source),
        L["Data known is how much of what the verdict needs is known. Under %d%% a hint says what is missing; under %d%% it never says Toss, and holds instead."]
            :format(v.HIGH, v.MEDIUM) }
end

SURE.score = function()
    return L["Score"], {
        L["Evidence for the word times data known, 0 to 100: how sure Drop Watcher is of the word. It is the number on the badge."],
        L["It is not how useful the item is: that is the use value, under Why this verdict."] }
end

-- ── the rest of the panel ───────────────────────────────────────────────────────────────────

local OTHER = {}

OTHER.whyHead = function()
    return L["Why this verdict"], {
        L["The parts below add up to the use value: what the item is still good for to this character. Green adds, red takes away."],
        L["The use value picks the word: %s"]:format(bands()) }
end

OTHER.sureHead = function()
    return L["How sure"], {
        L["How sure Drop Watcher is of the word. The score is the evidence for the word times how much is known."] }
end

OTHER.from = function()
    return L["The use value"], {
        L["The parts above added up. It picks the word: %s"]:format(bands()),
        L["Under %d it holds instead while the sell price is unknown or too little is known."]:format(V().HOLD) }
end

OTHER.vendor = function()
    return L["Vendor price"], { L["What a vendor pays you for one."] }
end

OTHER.noVendor = function()
    return L["No vendor buys it"], { L["It can only be auctioned or tossed: Auction when an auction brings anything after the cut and deposit, else Toss."] }
end

OTHER.auction = function()
    return L["Auction price (Auctionator)"], {
        L["The price Auctionator last saw for one on the auction house. Scan the auction house to bring it up to date."] }
end

OTHER.net = function()
    local A = C.ITEM_SEARCH.AUCTION
    local r = NS.ItemSearchAuction.Rule()
    local rate = pct(A.DEPOSIT[r.duration] or 0)
    return L["Auction after the cut and deposit"], {
        L["What one brings after the house's %d%% cut and the %d-hour deposit (%d%% of the vendor price, %s a listing at least)."]
            :format(r.cut, r.duration, rate, coin(A.MIN_DEPOSIT)),
        L["Auction when this beats the vendor price by over %d%%. Settings › Item Search › Item tooltip › Auction prices changes these."]
            :format(r.margin) }
end

OTHER.noPrice = function()
    return L["No auction price known (Auctionator)"], {
        L["Auctionator has never seen it listed. Scan the auction house; until then a sale is Vendor."] }
end

OTHER.hint = function()
    return L["What is missing"], {
        L["Drop Watcher doesn't yet know everything the verdict needs; this is the biggest gap. Data known, and the score, rise once it is known."] }
end

local BOOKS = { PART, SURE, OTHER }

--- The tooltip for a verdict panel line's `tip` (`{ key, points }`): the title, then each line, or
--- an empty list for no tooltip (a blank line, or a key with no rule).
--- @param tip table|nil
--- @return table
function IVT.Lines(tip)
    if type(tip) ~= "table" or type(tip.key) ~= "string" then return {} end
    for _, book in ipairs(BOOKS) do
        local fn = book[tip.key]
        if fn then
            local title, lines = fn(tip)
            local out = { title }
            for _, line in ipairs(lines) do out[#out + 1] = line end
            return out
        end
    end
    return {}
end

--- Whether `key` has a tooltip (for the tests).
--- @param key string
--- @return boolean
function IVT.Has(key)
    return PART[key] ~= nil or SURE[key] ~= nil or OTHER[key] ~= nil
end
