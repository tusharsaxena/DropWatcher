local _, NS = ...
-- modules/Gear.lua — your own gear snapshot (design spec §4, §5.3, §6.2): what you wear in each
-- slot, the best item you own for each slot (bags included), and the candidate table the verdict
-- kernel takes for you.
--
--   snapshot = { equipped = { [slot] = entry | false },   -- false = empty; absent = still loading
--                owned    = { [slot] = entry },           -- the best you own per slot, worn or not
--                classFile, specID, dualWield, titanGrip,
--                loading  = n,                            -- links still loading
--                signature }
--
-- An entry is a copy of the item's facts (modules/ItemFacts.lua) with `ilvl` set to the CURRENT
-- level and `slot` (worn) or `bag`/`bagSlot` (in a bag) added. A worn item's current level is its
-- tooltip's ItemLevel line (NS.Compat.InventoryItemLevel: the level the client shows, scaling
-- included), else the link's effective level. The copies are the snapshot's own; the cached facts
-- are never written.
--
-- THE CANDIDATE. Candidate() answers spec §5.1's candidate for you: classFile (UnitClass), specID
-- (NS.Compat.PlayerSpecID), dualWield and titanGrip (NS.ClassData for that spec, else for the
-- class when every spec agrees, else nil), `gear` = equipped and `owned`. `prefs` is left for the
-- feed to add from the `comparison.undesired` setting.
--
-- OWNED. A bag item is first read for its equip location (NS.Compat.ItemEquipLoc, no item cache
-- needed), and only one with a slot plan is requested from the item facts, so reagents and
-- consumables never fill the facts cache. Every worn item and every bag item you can equip (Evaluate.Equippability "ok" for you; a
-- tier token, or an item with no slot plan, is not gear) is placed by its slot plan: a single-slot
-- item in its slot; a ring or trinket in either of its pair; a one-hander in the main hand, and in
-- the off hand too for a dual wielder; a two-hander or ranged weapon in the main hand, and in the
-- off hand too with Titan's Grip; an off hand, shield or held item in the off hand. The slots are
-- filled in id order, each with the highest-level item that fits and is not already placed, so a
-- pair gets your best two and one item never fills two slots. It is a per-slot best, not a loadout
-- planner: unique-equipped limits and a two-hander's claim on both hands are not weighed.
--
-- THE EDGE AND THE THROTTLE. PLAYER_EQUIPMENT_CHANGED, BAG_UPDATE_DELAYED and the player's
-- PLAYER_SPECIALIZATION_CHANGED arm one THROTTLE-second timer; the events inside it share one
-- rebuild. A link not cached yet is requested through ItemFacts.Request, and its load arms the
-- same timer. A rebuild whose signature (spec, class and every worn and owned link with its
-- level) moved sends GearChanged (no payload). The first read, lazily from a caller, announces
-- nothing: nobody has judged against the old one. Stood down, the timer is canceled and the
-- snapshot dropped; the stand-up rebuilds it.

NS.Gear = NS.Gear or {}
local G = NS.Gear
local C = NS.Constants
local CD = NS.ClassData
local State = NS.State
local Perf = NS.Perf

local TAG = "GEAR"

G.THROTTLE = 0.5

local MH, OH = C.SLOT.MAINHAND, C.SLOT.OFFHAND

-- Every inventory slot id, ascending: the order the owned slots are filled in. Read, never write.
local SLOTS = {}
for _, id in pairs(C.SLOT) do SLOTS[#SLOTS + 1] = id end
table.sort(SLOTS)
G.SLOTS = SLOTS

local timer
local pendingFull = false     -- a cause other than a bag event shares the armed rebuild
local deferredBags = false    -- a bag event came in combat; the combat's end rebuilds

-- The causes that move only your bags: their rebuild keeps the worn slots whose link stayed.
local BAG_ONLY = { BAG_UPDATE_DELAYED = true, afterCombat = true }

-- ── reading the client ──────────────────────────────────────────────────────────────────────

local function copy(facts)
    local out = {}
    for k, v in pairs(facts) do out[k] = v end
    return out
end

-- Arms the rebuild when a requested item arrives. An item given up on (nil) arms nothing, so an
-- item that never loads is not requested in a loop; the next gear event asks for it again.
local function onItemLoaded(facts)
    if facts then G.Schedule("itemLoaded") end
end

-- The facts of a link now, or nil while it loads (counted in `waiting`; its arrival re-arms the
-- timer) or when it names no item.
local function factsOf(link, waiting)
    local facts, status = NS.ItemFacts.Request(link, onItemLoaded)
    if status == "loading" then waiting.n = waiting.n + 1 end
    return facts
end

-- A worn slot: its entry, false when empty, nil while its item loads. With `prev` (the last
-- snapshot's equipped, on a bag-only rebuild) a slot whose link has not moved is kept as read.
local function wornEntry(slot, waiting, prev)
    local link = NS.Compat.InventoryItemLink("player", slot)
    local kept = prev and prev[slot]
    if kept ~= nil and ((kept == false and not link) or (kept and kept.link == link)) then return kept end
    if not link then return false end
    local facts = factsOf(link, waiting)
    if not facts then return nil end
    local e = copy(facts)
    e.ilvl = NS.Compat.InventoryItemLevel("player", slot) or facts.ilvl
    e.slot = slot
    return e
end

local function readEquipped(waiting, prev)
    local equipped = {}
    for _, slot in ipairs(SLOTS) do
        local e = wornEntry(slot, waiting, prev)
        if e ~= nil then equipped[slot] = e end
    end
    return equipped
end

local function classFileOf()
    local _, classFile = UnitClass("player")
    if NS.Compat.IsSecret(classFile) or type(classFile) ~= "string" then return nil end
    return classFile
end

-- The candidate fields that are not gear: class, spec and the two hand flags.
local function readIdentity()
    local classFile, specID = classFileOf(), NS.Compat.PlayerSpecID()
    return {
        classFile = classFile, specID = specID,
        dualWield = CD.DualWieldFor(classFile, specID), titanGrip = CD.TitanGripFor(classFile, specID),
    }
end

-- Whether a bag item is gear you could put on. `who` carries the candidate's identity fields.
local function wearable(facts, who)
    if facts.isTierToken or not C.SLOT_PLAN[facts.equipLoc or ""] then return false end
    if type(facts.ilvl) ~= "number" then return false end
    return NS.Evaluate.Equippability(facts, who) == "ok"
end

-- Whether a bag link may be gear, by its equip location (no item cache needed): one with no slot
-- plan (a reagent, a consumable, a tier token) is never requested from the item facts. An answer
-- the client does not give lets the link through, to be judged on its facts.
local function mayBeGear(link)
    local equipLoc = NS.Compat.ItemEquipLoc(link)
    return equipLoc == nil or C.SLOT_PLAN[equipLoc] ~= nil
end

local function readBags(who, waiting)
    local items = {}
    for _, bag in ipairs(C.BAG_IDS) do
        for bagSlot = 1, NS.Compat.BagSlotCount(bag) do
            local link = NS.Compat.BagItemLink(bag, bagSlot)
            local facts = link and mayBeGear(link) and factsOf(link, waiting)
            if facts and wearable(facts, who) then
                local e = copy(facts)
                e.bag, e.bagSlot = bag, bagSlot
                items[#items + 1] = e
            end
        end
    end
    return items
end

-- ── the best owned per slot ─────────────────────────────────────────────────────────────────

-- The slots an item may fill, as a set, by its slot plan and your hand flags.
local function fitsOf(e, who)
    local plan = C.SLOT_PLAN[e.equipLoc or ""]
    if not plan then return nil end
    local kind, fits = plan.kind, {}
    if kind == "single" or kind == "pair" then
        for _, slot in ipairs(plan.slots) do fits[slot] = true end
    elseif kind == "offhand" then
        fits[OH] = true
    else
        fits[MH] = true
        local second = (kind == "weapon1H" and who.dualWield) or (kind == "weapon2H" and who.titanGrip)
        if second then fits[OH] = true end
    end
    return fits
end

-- Every worn entry and bag entry with the slots it fits.
local function pool(equipped, bagItems, who)
    local out = {}
    local function add(e)
        local fits = fitsOf(e, who)
        if fits then out[#out + 1] = { entry = e, fits = fits } end
    end
    for _, slot in ipairs(SLOTS) do
        if type(equipped[slot]) == "table" then add(equipped[slot]) end
    end
    for _, e in ipairs(bagItems) do add(e) end
    return out
end

-- The highest-level unplaced item that fits `slot`; the first found wins a tie (worn before bags).
local function bestFor(slot, items)
    local best
    for _, it in ipairs(items) do
        if not it.used and it.fits[slot] and (not best or it.entry.ilvl > best.entry.ilvl) then
            best = it
        end
    end
    return best
end

local function readOwned(equipped, bagItems, who)
    local items, owned = pool(equipped, bagItems, who), {}
    for _, slot in ipairs(SLOTS) do
        local best = bestFor(slot, items)
        if best then
            best.used = true
            owned[slot] = best.entry
        end
    end
    return owned
end

-- ── the snapshot ────────────────────────────────────────────────────────────────────────────

local function entryKey(e)
    if e == false then return "-" end
    if e == nil then return "?" end
    return e.link .. "@" .. tostring(e.ilvl)
end

local function signature(snap)
    local parts = { tostring(snap.classFile), tostring(snap.specID) }
    for _, slot in ipairs(SLOTS) do
        parts[#parts + 1] = slot .. "=" .. entryKey(snap.equipped[slot]) .. "/" .. entryKey(snap.owned[slot] or false)
    end
    return table.concat(parts, ";")
end

--- A fresh snapshot read from the client, unstored. With `prevEquipped` (a bag-only rebuild) each
--- worn slot whose link has not moved is kept as that table holds it.
--- @param prevEquipped table|nil
--- @return table
function G.Read(prevEquipped)
    local waiting = { n = 0 }
    local snap = readIdentity()
    snap.equipped = readEquipped(waiting, prevEquipped)
    -- The identity fields are the candidate Equippability needs; the snapshot is that table.
    snap.owned = readOwned(snap.equipped, readBags(snap, waiting), snap)
    snap.loading = waiting.n
    snap.signature = signature(snap)
    return snap
end

--- Re-read the snapshot now. Sends GearChanged when it moved, unless `quiet`. With `bagsOnly`
--- the worn slots whose link stayed are kept from the last snapshot.
--- @param cause string|nil the event (or `standUp`, `lazy`, `itemLoaded`, `afterCombat`) that asked
--- @param quiet boolean|nil
--- @param bagsOnly boolean|nil
--- @return boolean changed
function G.Refresh(cause, quiet, bagsOnly)
    local prev = State.gear
    local t0 = Perf.on and debugprofilestop()
    deferredBags = false
    local snap = G.Read(bagsOnly and prev and prev.equipped or nil)
    if t0 then Perf.Note("gear.rebuild", debugprofilestop() - t0) end
    State.gear = snap
    local changed = not prev or prev.signature ~= snap.signature
    if not changed then return false end
    NS.Debug(TAG, "gear: spec %s, %d loading (%s)", tostring(snap.specID), snap.loading, tostring(cause))
    if not quiet then NS.addon:SendMessage(NS.MSG.GEAR_CHANGED) end
    return true
end

--- Arm the rebuild timer, unless it is armed already or the addon is stood down.
--- @param cause string|nil
function G.Schedule(cause)
    if NS.IsStoodDown and NS.IsStoodDown() then return end
    if not BAG_ONLY[cause] then pendingFull = true end
    if timer then return end
    timer = C_Timer.NewTimer(G.THROTTLE, function()
        timer = nil
        local bagsOnly = not pendingFull
        pendingFull = false
        G.Refresh(cause, nil, bagsOnly)
    end)
end

--- A gear event: BAG_UPDATE_DELAYED in combat is noted for the combat's end; anything else arms
--- the rebuild.
--- @param event string
function G.OnEvent(event)
    if event == "BAG_UPDATE_DELAYED" and NS.Restrictions.InCombat() then
        deferredBags = true
        return
    end
    G.Schedule(event)
end

--- The PLAYER_REGEN_ENABLED edge: a bag event that came in combat rebuilds now.
function G.OnCombatEnd()
    if deferredBags then G.Schedule("afterCombat") end
end

--- Whether a rebuild is armed.
--- @return boolean
function G.IsScheduled()
    return timer ~= nil
end

--- The stored snapshot, read lazily (and quietly) on first use. Read it, never write it.
--- @return table
function G.Snapshot()
    if not State.gear then G.Refresh("lazy", true) end
    return State.gear
end

--- Spec §5.1's candidate for you, for NS.Evaluate.Evaluate. A fresh outer table over the
--- snapshot's own (read-only) gear tables.
--- @return table
function G.Candidate()
    local s = G.Snapshot()
    return {
        classFile = s.classFile, specID = s.specID, dualWield = s.dualWield, titanGrip = s.titanGrip,
        gear = s.equipped, owned = s.owned, isPlayer = true,
    }
end

--- The quality worn in each slot, `{ [slot] = quality | false }` (false = empty), for the
--- minimum-quality gate's ctx.gear (design spec §6.2). A slot still loading is absent.
--- @return table
function G.Qualities()
    local out = {}
    for slot, e in pairs(G.Snapshot().equipped) do
        if e == false then out[slot] = false else out[slot] = e.quality end
    end
    return out
end

--- Whether every worn and bag item has loaded.
--- @return boolean
function G.IsComplete()
    return G.Snapshot().loading == 0
end

-- ── events and the lifecycle ────────────────────────────────────────────────────────────────

NS.FEATURE_EVENTS[#NS.FEATURE_EVENTS + 1] = { "PLAYER_EQUIPMENT_CHANGED", "OnGearEvent" }
NS.FEATURE_EVENTS[#NS.FEATURE_EVENTS + 1] = { "BAG_UPDATE_DELAYED", "OnGearEvent" }
NS.FEATURE_EVENTS[#NS.FEATURE_EVENTS + 1] = { "PLAYER_SPECIALIZATION_CHANGED", "OnGearSpecEvent" }
-- Shared (core/DropWatcher.lua's dispatcher): this row comes after core/DropWatcher.lua's, which
-- hands the edge to the restriction tracker first, so InCombat already reads false.
NS.FEATURE_EVENTS[#NS.FEATURE_EVENTS + 1] = { "PLAYER_REGEN_ENABLED", "OnGearRegenEvent" }

function NS.addon.OnGearEvent(_, event)
    G.OnEvent(event)
end

function NS.addon.OnGearRegenEvent()
    G.OnCombatEnd()
end

-- Fires for any group member's unit; only yours moves the snapshot. A secret unit is assumed to
-- be yours: a spare rebuild costs less than a stale spec.
function NS.addon.OnGearSpecEvent(_, event, unit)
    if NS.Compat.IsSecret(unit) or unit == nil or unit == "player" then G.Schedule(event) end
end

NS.STAND_DOWN[#NS.STAND_DOWN + 1] = function()
    if timer then timer:Cancel() end
    timer, pendingFull, deferredBags = nil, false, false
    State.gear = nil
end
NS.STAND_UP[#NS.STAND_UP + 1] = function() G.Refresh("standUp") end
