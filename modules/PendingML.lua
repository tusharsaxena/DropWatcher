local _, NS = ...
-- modules/PendingML.lua — the master-loot kind of the pending store (Forever port design §6, plan
-- DW-FP18): an item in the loot window you opened, at or above the group's loot threshold, held
-- beside the feed as "awaiting master looter" until a receipt names who got it. Split out of
-- modules/Pending.lua, which keeps the store, the roll kind and the verdict re-judge; this file
-- holds and closes its items through NS.Pending.Hold / Close.
--
--   item = { id, kind = "ml", key = "sourceGUID:itemID", link, itemID, at, state = awaiting |
--            assigned | expired, facts, forced, me, where, ml = { unit, name, realm, guid, slot,
--            sourceGUID, quality, threshold }, askedML }
--
-- THE ASK (plan DW-FP19). NS.PressAskML whispers the master looter for an awaiting item (the
-- `askML` message kind, modules/Asks.lua); once it is sent P.NoteAskedML marks the item `askedML`,
-- which the receipt that assigns it carries to the drop and History. An item that closes cancels
-- an ask still queued for it (NS.Asks.CancelFor).
--
-- THE SOURCE. On LOOT_READY / LOOT_OPENED, while the group's method is master loot and you are not
-- the master looter (Compat.LootMethod), every slot of the window (Compat.LootSlots) with a
-- readable link, a plain source GUID and a quality at or above the group's loot threshold
-- (Compat.LootThreshold, rolls UX RX-03) becomes one item, if
-- it passes the feed's pre-looter gates (design §11.1, NS.LootFeed.GateFor). `locked` is allowed:
-- it is the master looter's to give. The key is the source GUID and the item ID, so re-opening the
-- corpse adds nothing, and a key once assigned or gated is not held again. Whether a raider who is
-- not the master looter sees the slots at all is probe P-ML1; if not, nothing is ever held and the
-- drop arrives as a plain receipt when it is given.
--
-- RESOLUTION. A chat or encounter receipt for the same item ID within ASSIGN_WINDOW seconds
-- assigns the oldest awaiting item (P.ClaimML, called by the feed's receive): the receipt carries
-- the item's id as `pendingKey` and its `askedML`, and the item closes. EXPIRY: EXPIRE seconds
-- after it was seen, on leaving the group, on leaving the instance it was seen in (the next
-- PLAYER_ENTERING_WORLD), or when you become the master looter (PARTY_LOOT_METHOD_CHANGED). Both
-- clients: on Retail master loot is Guild Master Loot only (design §11.2).

local P = NS.Pending

local TAG = "PENDING"

P.ASSIGN_WINDOW = 600   -- seconds a receipt may follow the item it assigns
P.EXPIRE = 900          -- seconds an unassigned item stays held

local expiries = {}
local loading = {}
local generation = 0

local function stoodDown()
    return NS.IsStoodDown ~= nil and NS.IsStoodDown()
end

-- Where you are, as one comparable value: the instance id, else its name.
local function where()
    local name, _, _, _, instanceID = NS.Compat.InstanceInfo()
    if type(instanceID) == "number" then return instanceID end
    if type(name) == "string" then return name end
    return nil
end

local function mlItems()
    local out = {}
    for _, item in ipairs(P.All()) do
        if item.kind == "ml" and item.state == "awaiting" then out[#out + 1] = item end
    end
    return out
end

local function close(item, state)
    item.state = state
    if expiries[item.id] then expiries[item.id]:Cancel() end
    expiries[item.id] = nil
    P.Close(item)
    NS.Asks.CancelFor("askML", item.id)   -- an ask still queued for it never goes out
end

local function expire(item, why)
    NS.Debug(TAG, "ml item %s: expired (%s)", tostring(item.id), why)
    close(item, "expired")
end

-- One slot past its item load: the gates, then the item.
local function admit(slot, key, lm, facts)
    if P.Held(key) then return end
    local ok, why, out = NS.LootFeed.GateFor(facts, NS.Situations.Current())
    if not ok then
        P.Refuse(key)
        return NS.Debug(TAG, "ml slot %s: %s not pending (%s)", key, tostring(slot.link), tostring(why))
    end
    local item = P.Hold({ kind = "ml", key = key, link = slot.link, itemID = NS.Item.ItemIDFromLink(slot.link),
        at = GetTime(), state = "awaiting", facts = facts, forced = out.forced, me = out.me, where = where(),
        ml = { unit = lm.mlUnit, name = lm.mlName, realm = lm.mlRealm, guid = lm.mlGUID, slot = slot.slot,
            sourceGUID = slot.sourceGUID, quality = slot.quality, threshold = lm.threshold } })
    local gen = generation
    expiries[item.id] = C_Timer.NewTimer(P.EXPIRE, function()
        expiries[item.id] = nil
        if gen == generation and P.Get(item.id) == item then expire(item, "time") end
    end)
end

-- A slot not yet held: load its item, then admit it.
local function open(slot, lm)
    local itemID = NS.Item.ItemIDFromLink(slot.link)
    if not itemID then return end
    local key = slot.sourceGUID .. ":" .. itemID
    if P.Held(key) or loading[key] then return end
    local gen = generation
    local facts, status = NS.ItemFacts.Request(slot.link, function(f)
        loading[key] = nil
        if gen ~= generation or stoodDown() or not f then return end
        admit(slot, key, lm, f)
    end)
    if status == "loading" then
        loading[key] = true
    elseif status == "ready" then
        admit(slot, key, lm, facts)
    end
end

--- LOOT_READY / LOOT_OPENED: hold every slot at or above the group's loot threshold, under master
--- loot, when you are not the master looter. The threshold is read once per opening and rides on
--- the loot method's (fresh) table to the item.
function P.OnLootOpened()
    if stoodDown() then return end
    local lm = NS.Compat.LootMethod()
    if not (lm and lm.method == "master") or lm.isML then return end
    lm.threshold = NS.Compat.LootThreshold()
    for _, slot in ipairs(NS.Compat.LootSlots()) do
        if slot.link and slot.sourceGUID and slot.quality and slot.quality >= lm.threshold then open(slot, lm) end
    end
end

--- A receipt for `itemID` (the feed's chat or encounter source): the oldest awaiting ml item of
--- that item seen inside ASSIGN_WINDOW seconds is assigned and closed. Answers its id and its
--- askedML, or nil.
--- @param itemID number
--- @return number|nil id, any askedML
function P.ClaimML(itemID)
    if stoodDown() or itemID == nil then return nil end
    local t = GetTime()
    for _, item in ipairs(mlItems()) do   -- oldest first
        if item.itemID == itemID and t - item.at <= P.ASSIGN_WINDOW then
            NS.Debug(TAG, "ml item %s: assigned", tostring(item.id))
            close(item, "assigned")
            return item.id, item.askedML
        end
    end
    return nil
end

--- The master-loot ask for item `id` was sent (modules/Asks.lua): the item is `askedML`, and so is
--- the drop it turns into. Answers whether an ml item took it.
--- @param id any
--- @return boolean
function P.NoteAskedML(id)
    local item = P.Get(id)
    if not (item and item.kind == "ml") then return false end
    item.askedML = true
    NS.Debug(TAG, "ml item %s: asked", tostring(id))
    return true
end

--- The master looter a master-loot ask for item `item` whispers: their GUID when it was read (the
--- roster resolves it to the whole name, client-quirks-§5), else their name as read; nil for an
--- item with neither.
--- @param item table|nil
--- @return string|nil
function P.MLTargetOf(item)
    local ml = type(item) == "table" and item.kind == "ml" and type(item.ml) == "table" and item.ml or nil
    if not ml then return nil end
    return ml.guid or ml.name
end

--- PARTY_LOOT_METHOD_CHANGED: made master looter, nothing of yours stays pending.
function P.OnLootMethodChanged()
    if stoodDown() then return end
    local lm = NS.Compat.LootMethod()
    if not (lm and lm.isML) then return end
    for _, item in ipairs(mlItems()) do expire(item, "you are the master looter") end
end

--- GROUP_ROSTER_UPDATE / PLAYER_ENTERING_WORLD: out of the group, every item expires; out of the
--- instance an item was seen in, that item does.
function P.OnWhereChanged()
    if stoodDown() then return end
    local inGroup, here = NS.Compat.InGroup(), where()
    for _, item in ipairs(mlItems()) do
        if not inGroup then
            expire(item, "left the group")
        elseif item.where ~= here then
            expire(item, "left the instance")
        end
    end
end

-- Both clients (design §11.2). GROUP_ROSTER_UPDATE and PLAYER_ENTERING_WORLD are shared
-- (core/DropWatcher.lua's dispatcher).
local EVENTS = {
    { "LOOT_READY", "OnPendingLootReady", P.OnLootOpened },
    { "LOOT_OPENED", "OnPendingLootOpened", P.OnLootOpened },
    { "PARTY_LOOT_METHOD_CHANGED", "OnPendingLootMethod", P.OnLootMethodChanged },
    { "GROUP_ROSTER_UPDATE", "OnPendingRoster", P.OnWhereChanged },
    { "PLAYER_ENTERING_WORLD", "OnPendingWhere", P.OnWhereChanged },
}
for _, row in ipairs(EVENTS) do
    local fn = row[3]
    NS.FEATURE_EVENTS[#NS.FEATURE_EVENTS + 1] = { row[1], row[2] }
    NS.addon[row[2]] = function(_, _, ...) fn(...) end
end

NS.STAND_DOWN[#NS.STAND_DOWN + 1] = function()
    generation = generation + 1
    for _, t in pairs(expiries) do t:Cancel() end
    expiries, loading = {}, {}
end
