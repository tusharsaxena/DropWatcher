local _, NS = ...
-- modules/ItemSearchPrices.lua — the vendor prices Drop Watcher records (Item Search round 3 spec
-- §4.4, item 8). WoW Forever's alone (C.FEATURE.itemSearch, clients-§4): its event rows are WoW
-- Forever's, and on Retail nothing here runs.
--
-- WHY. ForeverDB knows a price for very few vendors (its `vp` and `vendx` tables, some 500 entries
-- in all), so the Sold by tab showed a dash on almost every row. The merchant window shows the exact
-- price, so Drop Watcher writes down what it shows: the next search of that item names it.
--
-- WHEN. On MERCHANT_SHOW, and on MERCHANT_UPDATE while the merchant is open, debounced to
-- C.ITEM_SEARCH.PRICE_DEBOUNCE seconds (the window refills slot by slot as the client learns the
-- items). Only while Item Search is wanted (its tooltip block or its window on, the addon standing
-- up) and while `itemSearch.recordPrices` is on (on by default, "Record vendor prices").
--
-- WHAT. The vendor is NS.Compat.MerchantNpcID (UnitGUID("npc")'s creature id; none, and the visit
-- is not recorded); each slot is NS.Compat.MerchantItems' `{ item, price, quantity }` (a token
-- vendor's slots, an extended cost with no copper price, are not in it).
--
-- WHERE. `db.global.itemSearch.prices[npcID][itemID] = { p = copper, q = quantity, t = time() }`,
-- account-wide: a vendor's price is the same for every character, but for a reputation discount
-- (docs/known-limitations.md). A later visit overwrites the entry. Past C.ITEM_SEARCH.PRICE_CAP
-- entries the oldest tenth by `t` goes (IP.Prune). A visit that wrote anything empties Item Search's
-- per-item cache, so the next read shows the new price; nothing is read per hover from here.

NS.ItemSearchPrices = NS.ItemSearchPrices or {}
local IP = NS.ItemSearchPrices
local IS = NS.ItemSearch
local C  = NS.Constants

local open = false        -- a merchant window is open
local pending = nil       -- the debounce timer while MERCHANT_UPDATE waits

local function num(v)
    if type(v) == "number" and v == v then return v end
    return nil
end

--- Whether prices are recorded now: WoW Forever, Item Search wanted, the setting on.
--- @return boolean
function IP.Recording()
    if not IS.Enabled() or not IS.Wanted() then return false end
    return NS.Setting("itemSearch.recordPrices") ~= false
end

--- The account-wide price store, `{ [npcID] = { [itemID] = { p, q, t } } }`, made on first use; nil
--- on Retail or before the database exists.
--- @return table|nil
function IP.Store()
    if not IS.Enabled() then return nil end
    local db = NS.addon and NS.addon.db
    local g = db and db.global
    if type(g) ~= "table" then return nil end
    if type(g.itemSearch) ~= "table" then g.itemSearch = {} end
    if type(g.itemSearch.prices) ~= "table" then g.itemSearch.prices = {} end
    return g.itemSearch.prices
end

--- How many entries `store` holds, over every vendor.
--- @param store table
--- @return number
function IP.Count(store)
    local n = 0
    for _, items in pairs(store) do
        if type(items) == "table" then
            for _ in pairs(items) do n = n + 1 end
        end
    end
    return n
end

--- Keep `store` within `cap` entries: past it, the oldest tenth of the entries by their time goes
--- (at least one), and a vendor left with none goes too. Answers how many went. Pure over `store`.
--- @param store table
--- @param cap number
--- @return number
function IP.Prune(store, cap)
    local total = IP.Count(store)
    if total <= cap then return 0 end
    local all = {}
    for npc, items in pairs(store) do
        for item, e in pairs(type(items) == "table" and items or {}) do
            all[#all + 1] = { npc = npc, item = item, t = type(e) == "table" and num(e.t) or 0 }
        end
    end
    table.sort(all, function(a, b)
        if a.t ~= b.t then return a.t < b.t end
        if a.npc ~= b.npc then return a.npc < b.npc end
        return a.item < b.item
    end)
    local drop = math.max(1, math.floor(total / 10))
    for i = 1, drop do
        local e = all[i]
        store[e.npc][e.item] = nil
        if next(store[e.npc]) == nil then store[e.npc] = nil end
    end
    return drop
end

--- Write one vendor's slots into `store`, at `now`: each `{ item, price, quantity }` overwrites that
--- vendor's entry for the item. Answers how many entries were new or changed. Pure over `store`.
--- @param store table
--- @param npc number
--- @param slots table NS.Compat.MerchantItems' answer
--- @param now number time()
--- @return number
function IP.Record(store, npc, slots, now)
    local changed = 0
    local items = store[npc]
    for _, s in ipairs(slots) do
        if num(s.item) and num(s.price) then
            items = items or {}
            store[npc] = items
            local old = items[s.item]
            if not (type(old) == "table" and old.p == s.price and old.q == s.quantity) then changed = changed + 1 end
            items[s.item] = { p = s.price, q = num(s.quantity) or 1, t = now }
        end
    end
    return changed
end

--- The price Drop Watcher saw `npcID` sell `itemID` for, `{ p, q, t }`, or nil. The model's
--- `seenPrice` (modules/ItemSearchModel.lua), read when an item's static facts are built.
--- @param npcID number
--- @param itemID number
--- @return table|nil
function IP.Seen(npcID, itemID)
    local db = NS.addon and NS.addon.db
    local g = db and db.global
    local prices = type(g) == "table" and type(g.itemSearch) == "table" and g.itemSearch.prices or nil
    local items = type(prices) == "table" and prices[npcID] or nil
    local e = type(items) == "table" and items[itemID] or nil
    return type(e) == "table" and e or nil
end

--- Record what the open merchant sells, now (MERCHANT_SHOW, and the debounced MERCHANT_UPDATE).
--- Answers how many entries were new or changed (0 when nothing was recorded).
--- @return number
function IP.Visit()
    pending = nil
    if not open or not IP.Recording() then return 0 end
    local npc = NS.Compat.MerchantNpcID()
    local store = npc and IP.Store()
    if not store then return 0 end
    local changed = IP.Record(store, npc, NS.Compat.MerchantItems(), time())
    local pruned = IP.Prune(store, C.ITEM_SEARCH.PRICE_CAP)
    if changed > 0 then
        NS.Debug("SEARCH", "vendor %d: %d price(s) recorded", npc, changed)
        IS.Invalidate()
    end
    if pruned > 0 then NS.Debug("SEARCH", "prices: %d oldest entr(ies) pruned past the cap", pruned) end
    return changed
end

-- ── events ──────────────────────────────────────────────────────────────────────────────────

NS.FEATURE_EVENTS[#NS.FEATURE_EVENTS + 1] = { "MERCHANT_SHOW", "OnItemSearchMerchantShow", clients = { "forever" } }
NS.FEATURE_EVENTS[#NS.FEATURE_EVENTS + 1] = { "MERCHANT_UPDATE", "OnItemSearchMerchantUpdate", clients = { "forever" } }
NS.FEATURE_EVENTS[#NS.FEATURE_EVENTS + 1] = { "MERCHANT_CLOSED", "OnItemSearchMerchantClosed", clients = { "forever" } }

function NS.addon.OnItemSearchMerchantShow()
    open = true
    if pending then pending:Cancel(); pending = nil end
    IP.Visit()
end

function NS.addon.OnItemSearchMerchantUpdate()
    if not open or pending or not IP.Recording() then return end
    pending = C_Timer.NewTimer(C.ITEM_SEARCH.PRICE_DEBOUNCE, IP.Visit)
end

function NS.addon.OnItemSearchMerchantClosed()
    open = false
    if pending then pending:Cancel(); pending = nil end
end

-- A stand-down drops a waiting update.
NS.STAND_DOWN[#NS.STAND_DOWN + 1] = function()
    if pending then pending:Cancel(); pending = nil end
end
