local _, NS = ...
-- modules/SimWorld.lua — what the client answers about the simulated world (simulator spec §2):
-- the invented group, where it is, the members' inspect replies, your own drops in your bags with
-- their trade windows, and the simulated trade window. Every answer is a provider on the seam
-- (NS.SimSeam:SetProvider, core/SimSetup.lua), consulted by the NS.Compat member the engine already
-- reads; anything the simulation did not invent falls through to the client.
--
-- THE GROUP. Once modules/SimRoster.lua has drawn the members, the group's size, kind and unit
-- tokens answer for them (party1.. in a party; raid1 is you and raid2.. the members in a raid), and
-- each token's GUID, name, realm (nil on your own realm, as the client answers), class and
-- connection are the member's; every unit read of raid1 in a raid is yours (DW-90). Raid Finder's
-- group is matchmade: IsInGroup answers for the instance category alone. A member can be marked
-- out of range, failing (its inspect never answers) or offline (SetMember).
--
-- WHERE. The session's situation answers IsInInstance, GetInstanceInfo (the journal instance the
-- pool came from, its type and the situation's difficulty) and the keystone state (a run in
-- progress, modules/SimEvents.lua's, and its level). The difficulty's name is the client's
-- (GetDifficultyInfo of the situation's real difficulty id), so a header reads as a real one. The real world is read with NS.SimSeam:Live, never through here.
--
-- INSPECT REPLIES. A member's worn gear is unknown to the client until an inspect of it answers,
-- so the broker's fast path never fires for it and every read goes through the broker's real queue:
-- NotifyInspect (guarded: no client call) schedules INSPECT_READY(guid) after a random delay in
-- INSPECT_DELAY (the session's seeded random source, so a suite replays it), unless the member is
-- failing. From then on the member's slots, item ids, worn levels (the roster's) and spec answer,
-- until ClearInspectPlayer lets the data go, as the client's does. Only the last inspected
-- member's data is held.
--
-- YOUR BAGS. Your own simulated drops sit in the backpack after its real slots (AddBagItem), each
-- with a GUID and a trade window: TradeTimeRemaining answers the seconds left until it closes, then
-- nothing, as the tooltip line does. The trade timer, the gear snapshot and the Offer panel's Give
-- read them through their usual members; their exact level and quality (BagItemLevelQuality) are
-- their link's, and their tooltip (TooltipBagItem) is their link's (DW-80).
--
-- THE TRADE WINDOW. While a simulated trade is open (OpenTrade), its partner and both sides' items
-- answer TradePartnerName and TradeItemLinks, and a UI_INFO_MESSAGE of type TRADE_COMPLETE is
-- the client's "Trade complete." modules/SimEvents.lua drives the events.
--
-- THE ROLLS (Forever port design §8, DW-FP17). A simulated group-loot roll (AddRoll, opened by
-- modules/SimEvents.lua's Roll) answers every core/CompatLoot.lua reader for its own encounter
-- and key: its roll table (you and the members, each as chat names them, with their choices and,
-- from the close, their numbers and the winner), its drop once won, the encounter's drops and
-- name, the history's clock (the session's GetTime while a roll exists), and your popup (its
-- rollID among ActiveLootRolls while open, its item for LootRollInfo). A roll's key is counted
-- across sessions, so the pending store and the feed, which remember a resolved key, never meet
-- one twice.
--
-- MASTER LOOT (Forever port design §8, plan DW-FP19). Once AddMasterLoot (modules/SimEvents.lua's
-- MasterLoot, `/dw sim ml`) has run, the session's group answers master loot with that member as
-- the master looter (their unit, whole name and GUID) and a threshold of Epic (ML_THRESHOLD: the
-- sim plays WoW Forever's rule on both clients), and the loot window answers the item as one
-- locked slot of an invented corpse until AssignMasterLoot hands it out. Before it, a simulated
-- group plays group loot and opens no loot window.
--
--   NS.Sim:Session().world = { members (the list the token map was built from), units = { [token] =
--     member }, kind = "party"|"raid", marks = { [guid] = { far, failing, offline } }, held (guid),
--     bag = { item }, nextItem, trade = { partner, given, received } | nil, inspects,
--     rolls = { ["encounterID:key"] = roll }, rollList = { roll }, masterLoot = loot | nil,
--     mlKeys = { [pending key] = true } }
--   loot = { member, link, quality, sourceGUID, key, assigned }
--   roll = { encounterID, encounterName, key, link, startTime, duration, rows = { { member, state,
--     roll, isWinner } }, rollID, popupOpen, allPassed, winner }
--   item = { sim = true, link, guid, expiresAt }

NS.SimWorld = NS.SimWorld or {}
local W = NS.SimWorld
local Sim = NS.Sim
local C = NS.Constants
local L = NS.L
local D = C.DIFFICULTY

local TAG = "SIM"

--- Seconds an inspect reply takes: a random delay between the two.
W.INSPECT_DELAY = { 0.4, 1.6 }

--- The backpack, where your simulated drops sit after its real slots.
W.BAG = 0

--- The UI_INFO_MESSAGE type a simulated trade completes with.
W.TRADE_COMPLETE = "SIM_TRADE_COMPLETE"

--- situation -> what the client answers there: in an instance, its type, its difficulty, and
--- whether the group is a matchmade instance group (Raid Finder: IsInGroup answers for the instance
--- category only, so the announce channel is INSTANCE_CHAT).
W.PLACES = {
    mythicPlus     = { inInstance = true, instanceType = "party", difficulty = D.MYTHIC_KEYSTONE },
    dungeon        = { inInstance = true, instanceType = "party", difficulty = D.MYTHIC_DUNGEON },
    raid           = { inInstance = true, instanceType = "raid", difficulty = D.HEROIC_RAID },
    raidLFR        = { inInstance = true, instanceType = "raid", difficulty = D.LFR, instanceGroup = true },
    delve          = { inInstance = true, instanceType = "scenario", difficulty = D.DELVE },
    openWorldGroup = { inInstance = false, instanceType = "none", difficulty = 0 },
}

-- ── the session's state ─────────────────────────────────────────────────────────────────────

-- The world of the running session, made on first use; nil when none runs.
local function world()
    local s = NS.Sim:Session()
    if not s then return nil end
    local w = s.world
    if not w then
        w = { marks = {}, bag = {}, nextItem = 0, inspects = 0 }
        s.world = w
    end
    return w
end

-- The token map, rebuilt whenever the roster drew a new list.
local function units(w, members)
    if w.members == members then return w.units end
    w.members, w.units, w.kind = members, {}, "party"
    for _, m in ipairs(members) do
        w.units[m.unit] = m
        if m.unit:find("^raid") then w.kind = "raid" end
    end
    return w.units
end

-- The running session's world and members, when it has a group; nil otherwise.
local function group()
    local s = NS.Sim:Session()
    local members = s and s.members
    if not (members and #members > 0) then return nil end
    local w = world()
    units(w, members)
    return w, members
end

--- The member a unit token names in the simulated group, or nil.
--- @param unit any
--- @return table|nil
function W.MemberOfUnit(unit)
    local w = group()
    return w and type(unit) == "string" and w.units[unit] or nil
end

--- The member with this GUID, or nil.
--- @param guid any
--- @return table|nil
function W.Member(guid)
    local _, members = group()
    for _, m in ipairs(members or {}) do
        if m.guid == guid then return m end
    end
    return nil
end

--- The group's kind, `party` or `raid`; nil without a simulated group.
--- @return string|nil
function W.Kind()
    local w = group()
    return w and w.kind
end

--- Mark a member (by GUID): { far = bool, failing = bool, offline = bool }, each field optional.
--- Answers whether the member exists.
--- @param guid string
--- @param marks table
--- @return boolean
function W.SetMember(guid, marks)
    local w = world()
    if not (w and W.Member(guid)) then return false end
    local m = w.marks[guid] or {}
    for _, k in ipairs({ "far", "failing", "offline" }) do
        if marks[k] ~= nil then m[k] = marks[k] == true end
    end
    w.marks[guid] = m
    return true
end

local function mark(m, key)
    local w = world()
    local t = w and w.marks[m.guid]
    return t ~= nil and t[key] == true
end

--- The session's seeded random source (modules/SimRoster.lua's), made on first use.
--- @return function
function W.Random()
    local s = NS.Sim:Session()
    if not s then return math.random end
    s.rnd = s.rnd or NS.SimRoster.Random(s.seed or math.floor(GetTime() * 1000))
    return s.rnd
end

-- ── where ───────────────────────────────────────────────────────────────────────────────────

--- What the client answers about where the running simulation is: W.PLACES' row with the
--- instance's name, or nil when the session names no known situation.
--- @return table|nil { inInstance, instanceType, difficulty, name, instanceGroup }
function W.Place()
    local s = NS.Sim:Session()
    local row = s and W.PLACES[s.situation]
    if not row then return nil end
    local name = L["Open world"]
    if row.inInstance then
        local drops = NS.SimPool.Drops(s.pool)
        name = drops[1] and drops[1].instance or L["Simulated instance"]
    end
    return { inInstance = row.inInstance, instanceType = row.instanceType, difficulty = row.difficulty,
        name = name, instanceGroup = row.instanceGroup == true }
end

-- ── the bags ────────────────────────────────────────────────────────────────────────────────

--- Put one of your simulated drops in the backpack with a trade window of `window` seconds (none
--- for nil). Answers the item.
--- @param link string
--- @param window number|nil
--- @return table|nil item
function W.AddBagItem(link, window)
    local w = world()
    if not w then return nil end
    w.nextItem = w.nextItem + 1
    local item = { sim = true, link = link, guid = ("Item-3900-0-SIM%08X"):format(w.nextItem),
        expiresAt = window and (GetTime() + window) or nil }
    w.bag[#w.bag + 1] = item
    return item
end

--- Take a simulated item out of the backpack (a trade gave it away). Answers whether it was there.
--- @param guid string
--- @return boolean
function W.RemoveBagItem(guid)
    local w = world()
    for i, item in ipairs(w and w.bag or {}) do
        if item.guid == guid then
            table.remove(w.bag, i)
            return true
        end
    end
    return false
end

--- The first simulated bag item with this link still in the backpack, or nil.
--- @param link string
--- @return table|nil
function W.BagItemFor(link)
    local w = world()
    for _, item in ipairs(w and w.bag or {}) do
        if item.link == link then return item end
    end
    return nil
end

--- Every simulated bag item. Read them, never write them.
--- @return table
function W.BagItems()
    local w = world()
    return w and w.bag or {}
end

-- The simulated item at a backpack slot past the real ones, or nil.
local function bagItem(bag, slot)
    local w = world()
    if bag ~= W.BAG or not w or #w.bag == 0 or type(slot) ~= "number" then return nil end
    local base = NS.SimSeam:Live(NS.Compat.BagSlotCount, bag)
    return w.bag[slot - base]
end

-- ── the trade window ────────────────────────────────────────────────────────────────────────

--- Open (or, with nil, close) the simulated trade window: { partner, given, received }.
--- @param t table|nil
function W.SetTrade(t)
    local w = world()
    if w then w.trade = t end
end

-- ── the inspect replies ─────────────────────────────────────────────────────────────────────

local function inspectDelay()
    local lo, hi = W.INSPECT_DELAY[1], W.INSPECT_DELAY[2]
    return lo + W.Random()() * (hi - lo)
end

-- An inspect of `m` was asked for: its reply after a random delay, unless it is failing.
local function reply(m)
    local w = world()
    w.inspects = w.inspects + 1
    if mark(m, "failing") then
        NS.Debug(TAG, "inspect of %s: no reply (failing)", m.fullName)
        return
    end
    local delay = inspectDelay()
    NS.Debug(TAG, "inspect of %s: reply in %.1fs", m.fullName, delay)
    Sim:After(delay, function()
        if not W.Member(m.guid) then return end
        world().held = m.guid
        Sim:Fire("INSPECT_READY", m.guid)
    end)
end

-- The member at `unit` whose inspect data the client holds now, or nil.
local function held(unit)
    local m = W.MemberOfUnit(unit)
    if m and world().held == m.guid then return m end
    return nil
end

local function itemID(link)
    return link and tonumber(link:match("item:(%d+)")) or nil
end

-- ── the group-loot rolls ────────────────────────────────────────────────────────────────────

-- The keys and popup ids a roll takes, counted across sessions: the store and the feed remember a
-- drop's key once it resolved (modules/Pending.lua, LootFeed's history keys), so a later session
-- never reuses one.
local rollSeq = 0

--- The first id your simulated roll popups take (START_LOOT_ROLL's rollID), far from the client's.
W.ROLL_ID_BASE = 990000

-- The roll at `encounterID:key`, or nil.
local function rollAt(encounterID, key)
    local w = world()
    return w and w.rolls and w.rolls[tostring(encounterID) .. ":" .. tostring(key)] or nil
end

--- Open a simulated roll: { encounterID, encounterName, link, duration, rows } where each row is
--- { member (nil for you) }. Every row starts waiting (state 4) with no number; yours gets a popup
--- id. Answers the roll: { encounterID, encounterName, key, link, startTime, duration, rows,
--- rollID, allPassed, winner (a row index) }; nil when no simulation runs.
--- @param spec table
--- @return table|nil
function W.AddRoll(spec)
    local w = world()
    if not w then return nil end
    rollSeq = rollSeq + 1
    local r = { encounterID = spec.encounterID, encounterName = spec.encounterName, key = rollSeq, link = spec.link,
        startTime = GetTime(), duration = spec.duration, rows = {}, allPassed = false, popupOpen = false }
    for i, row in ipairs(spec.rows or {}) do
        r.rows[i] = { member = row.member, state = 4 }
        if row.member == nil then r.rollID, r.popupOpen = W.ROLL_ID_BASE + rollSeq, true end
    end
    w.rolls = w.rolls or {}
    w.rollList = w.rollList or {}
    w.rolls[r.encounterID .. ":" .. r.key] = r
    w.rollList[#w.rollList + 1] = r
    return r
end

-- ── master loot ─────────────────────────────────────────────────────────────────────────────

--- The master-loot threshold a simulated master looter answers: Epic.
W.ML_THRESHOLD = 4

-- The corpses a simulated master-loot item lies on, counted across sessions (the pending store
-- remembers a key once it closed).
local mlSeq = 0

--- Make `spec.member` the simulated group's master looter with `spec.link` waiting on a corpse of
--- `spec.encounterID` (`/dw sim ml`). Answers the loot: { member, link, quality, sourceGUID, key
--- (the pending store's `sourceGUID:itemID`), assigned = false }; nil when no simulation runs.
--- @param spec table { member, link, encounterID }
--- @return table|nil
function W.AddMasterLoot(spec)
    local w = world()
    if not (w and spec.member and spec.link) then return nil end
    mlSeq = mlSeq + 1
    local source = ("Creature-0-3900-0-0-%d-SIM%06X"):format(tonumber(spec.encounterID) or 0, mlSeq)
    local loot = { member = spec.member, link = spec.link, quality = NS.ItemRead.QualityOf(spec.link) or W.ML_THRESHOLD,
        sourceGUID = source, key = source .. ":" .. tostring(itemID(spec.link)), assigned = false }
    w.masterLoot = loot
    w.mlKeys = w.mlKeys or {}
    w.mlKeys[loot.key] = true
    return loot
end

--- The master looter hands the item out: the loot window no longer holds it.
--- @param loot table W.AddMasterLoot's
function W.AssignMasterLoot(loot)
    if type(loot) == "table" then loot.assigned = true end
end

--- Whether a pending key is one of the session's master-loot items (its stop takes them away).
--- @param key any
--- @return boolean
function W.IsMasterLootKey(key)
    local w = world()
    return w ~= nil and w.mlKeys ~= nil and w.mlKeys[key] == true
end

--- Every simulated roll, oldest first. Read them; only the drivers write them.
--- @return table
function W.Rolls()
    local w = world()
    return w and w.rollList or {}
end

-- You, as a roll table names you.
local function you()
    local Compat = NS.Compat
    local _, classFile = Compat.UnitClass("player")
    return { name = (Compat.UnitCharacterName("player")), guid = Compat.UnitGUID("player"), classFile = classFile }
end

-- One row as Compat.LootHistoryRolls answers it: a member named as chat names them.
local function rollRow(row, me, ownRealm)
    local m = row.member
    local p = m and { name = NS.SimEvents.ChatName(m, ownRealm), guid = m.guid, classFile = m.classFile } or me
    return { name = p.name, guid = p.guid, classFile = p.classFile, isSelf = m == nil, state = row.state,
        roll = row.roll, isWinner = row.isWinner == true }
end

local function playerOf(row) return row and { name = row.name, guid = row.guid, classFile = row.classFile,
    isSelf = row.isSelf, roll = row.roll } or nil end

-- The highest numbered row so far, Need before Greed (the client's currentLeader), or nil.
local function leaderOf(rows)
    local best
    for _, r in ipairs(rows) do
        if r.roll and (not best or r.state < best.state or (r.state == best.state and r.roll > best.roll)) then
            best = r
        end
    end
    return best
end

-- A roll's table, freshly built, in Compat.LootHistoryRolls' shape.
local function rollTable(r)
    local me, ownRealm = you(), NS.SimSeam:Live(NS.Compat.NameRealm)
    local rows, mine = {}, nil
    for i, row in ipairs(r.rows) do
        rows[i] = rollRow(row, me, ownRealm)
        if row.member == nil then mine = row.state end
    end
    local winner = r.winner and rows[r.winner] or nil
    return { link = r.link, key = r.key, startTime = r.startTime, duration = r.duration, allPassed = r.allPassed,
        isTied = false, myState = mine, won = r.winner ~= nil, leader = playerOf(leaderOf(rows)), winner = playerOf(winner), rolls = rows }
end

-- ── the providers ───────────────────────────────────────────────────────────────────────────

-- Keyed by the NS.Compat member names, written as fields (test_compat's seam-only scan never
-- mistakes a key for a client call). Each is `fn(fallback, ...)`.
local P = {}

-- The group.

function P.GroupSize(live)
    local _, members = group()
    if not members then return live() end
    return #members + 1
end

function P.InRaid(live)
    local w = group()
    if not w then return live() end
    return w.kind == "raid"
end

-- A matchmade group (W.PLACES' instanceGroup) answers for the instance category alone; any other
-- for every category but that one. No category asks for any group.
function P.InGroup(live, category)
    if not group() then return live(category) end
    if category == nil then return true end
    local p = W.Place()
    local matchmade = p ~= nil and p.instanceGroup == true
    return (category == NS.Compat.InstanceGroupCategory()) == matchmade
end

-- In a raid, raid1 is you: its answers are the player's, for every unit read (M7 review).
local function liveUnit(unit)
    if unit == "raid1" and W.Kind() == "raid" then return "player" end
    return unit
end

function P.UnitGUID(live, unit)
    local m = W.MemberOfUnit(unit)
    if m then return m.guid end
    return live(liveUnit(unit))
end

-- A member's whole name (UnitCharacterName's shape, client-quirks-§5): its realm only when it is
-- not yours, and none on Forever, where a sim member is "First Surname" with no realm.
function P.UnitCharacterName(live, unit)
    local m = W.MemberOfUnit(unit)
    if not m then return live(liveUnit(unit)) end
    local own = NS.SimSeam:Live(NS.Compat.NameRealm)
    if m.realm == nil or m.realm == own then return m.name, nil end
    return m.name, m.realm
end

function P.UnitClass(live, unit)
    local m = W.MemberOfUnit(unit)
    if not m then return live(liveUnit(unit)) end
    return m.classFile, m.classFile, m.classID
end

function P.UnitIsConnected(live, unit)
    local m = W.MemberOfUnit(unit)
    if not m then return live(liveUnit(unit)) end
    return not mark(m, "offline")
end

-- The simulated group is players, every one (a follower or a companion is never invented).
function P.UnitIsPlayer(live, unit)
    if W.MemberOfUnit(unit) then return true end
    return live(liveUnit(unit))
end

-- Where.

function P.InstanceState(live)
    local p = W.Place()
    if not p then return live() end
    return p.inInstance, p.instanceType
end

function P.InstanceInfo(live)
    local p = W.Place()
    if not p then return live() end
    return p.name, p.instanceType, p.difficulty
end

function P.ChallengeModeActive(live)
    local p = W.Place()
    if not p then return live() end
    local run = NS.SimEvents and NS.SimEvents.Run()
    return run ~= nil and not run.ended
end

function P.KeystoneLevel(live)
    local p = W.Place()
    if not p then return live() end
    local run = NS.SimEvents and NS.SimEvents.Run()
    return run and run.level or nil
end

function P.ChallengeMapName(live, mapID)
    local run = NS.SimEvents and NS.SimEvents.Run()
    if run and run.mapID == mapID then return run.name end
    return live(mapID)
end

-- The inspect.

function P.CanInspectUnit(live, unit)
    local m = W.MemberOfUnit(unit)
    if not m then return live(liveUnit(unit)) end
    return not mark(m, "offline")
end

function P.InInspectRange(live, unit)
    local m = W.MemberOfUnit(unit)
    if not m then return live(liveUnit(unit)) end
    return not mark(m, "far")
end

P.InTradeRange = P.InInspectRange

function P.NotifyInspect(guarded, unit)
    local m = W.MemberOfUnit(unit)
    local out = guarded(unit)
    if m then reply(m) end
    return out
end

function P.ClearInspectPlayer(guarded)
    local w = world()
    if w then w.held = nil end
    return guarded()
end

function P.InventoryItemLink(live, unit, slot)
    if not W.MemberOfUnit(unit) then return live(liveUnit(unit), slot) end
    local m = held(unit)
    return m and m.gear and m.gear[slot] or nil
end

function P.InventoryItemID(live, unit, slot)
    if not W.MemberOfUnit(unit) then return live(liveUnit(unit), slot) end
    local m = held(unit)
    return itemID(m and m.gear and m.gear[slot])
end

-- The worn level the roster drew inside its band (modules/SimRoster.lua), else the link's.
function P.InventoryItemLevel(live, unit, slot)
    if not W.MemberOfUnit(unit) then return live(liveUnit(unit), slot) end
    local m = held(unit)
    local link = m and m.gear and m.gear[slot]
    if not link then return nil end
    return (m.levels and m.levels[slot]) or NS.Compat.GetDetailedItemLevel(link)
end

function P.InspectSpecID(live, unit)
    if not W.MemberOfUnit(unit) then return live(liveUnit(unit)) end
    local m = held(unit)
    return m and m.specID or nil
end

-- The bags.

function P.BagSlotCount(live, bag)
    local n = live(bag)
    local w = world()
    if bag == W.BAG and w then n = n + #w.bag end
    return n
end

function P.BagItemLink(live, bag, slot)
    local item = bagItem(bag, slot)
    if item then return item.link end
    return live(bag, slot)
end

function P.GetBagItemGUID(live, bag, slot)
    local item = bagItem(bag, slot)
    if item then return item.guid end
    return live(bag, slot)
end

-- A simulated bag item has no ItemLocation: its level and quality are its link's (core/ItemRead.lua).
function P.BagItemLevelQuality(live, bag, slot)
    local item = bagItem(bag, slot)
    if not item then return live(bag, slot) end
    return NS.Compat.GetDetailedItemLevel(item.link), (NS.ItemRead.QualityOf(item.link))
end

-- Nor a slot the client can show: its tooltip is its link's.
function P.TooltipBagItem(live, tip, bag, slot)
    local item = bagItem(bag, slot)
    if not item then return live(tip, bag, slot) end
    return NS.Compat.TooltipHyperlink(tip, item.link)
end

function P.TradeTimeRemaining(live, bag, slot)
    local item = bagItem(bag, slot)
    if not item then return live(bag, slot) end
    local left = item.expiresAt and item.expiresAt - GetTime()
    if left and left > 0 then return left end
    return nil
end

-- The trade window.

function P.TradePartnerName(live)
    local w = world()
    if w and w.trade then return w.trade.partner end
    return live()
end

local function copy(list)
    local out = {}
    for i, v in ipairs(list or {}) do out[i] = v end
    return out
end

function P.TradeItemLinks(live)
    local w = world()
    if w and w.trade then return copy(w.trade.given), copy(w.trade.received) end
    return live()
end

function P.IsTradeCompleteMessage(live, messageType, message)
    if messageType == W.TRADE_COMPLETE then return true end
    return live(messageType, message)
end

-- The group-loot rolls (core/CompatLoot.lua's readers): a simulated roll answers for its own
-- encounter and key; anything else is the client's.

function P.LootHistoryRolls(live, encounterID, key)
    local r = rollAt(encounterID, key)
    if not r then return live(encounterID, key) end
    return rollTable(r)
end

function P.LootHistoryDrop(live, encounterID, key)
    local r = rollAt(encounterID, key)
    if not r then return live(encounterID, key) end
    local w = r.winner and rollTable(r).winner
    if not w then return nil end
    return { link = r.link, name = w.name, guid = w.guid, classFile = w.classFile, isSelf = w.isSelf }
end

function P.LootHistoryDropsFor(live, encounterID)
    local out
    for _, r in ipairs(W.Rolls()) do
        if r.encounterID == encounterID then
            out = out or {}
            out[#out + 1] = { key = r.key, link = r.link, open = not (r.winner or r.allPassed) }
        end
    end
    return out or live(encounterID)
end

function P.LootHistoryEncounters(live)
    local out, seen = live(), {}
    for _, id in ipairs(out) do seen[id] = true end
    for _, r in ipairs(W.Rolls()) do
        if not seen[r.encounterID] then
            seen[r.encounterID] = true
            out[#out + 1] = r.encounterID
        end
    end
    return out
end

function P.LootHistoryEncounter(live, encounterID)
    for _, r in ipairs(W.Rolls()) do
        if r.encounterID == encounterID then return r.encounterName end
    end
    return live(encounterID)
end

-- The history's clock is the session's while it holds a roll (a roll's startTime is GetTime()).
function P.LootHistoryNow(live)
    if #W.Rolls() > 0 then return GetTime() end
    return live()
end

function P.ActiveLootRolls(live)
    local out = live()
    for _, r in ipairs(W.Rolls()) do
        if r.popupOpen then out[#out + 1] = r.rollID end
    end
    return out
end

-- Your simulated popup's time left, in seconds as the reader answers it: the roll's own startTime
-- + duration on the session's clock while its popup is open.
function P.LootRollTimeLeft(live, rollID)
    for _, r in ipairs(W.Rolls()) do
        if r.rollID == rollID then
            if not (r.popupOpen and r.duration) then return nil end
            return math.max(0, r.startTime + r.duration - GetTime())
        end
    end
    return live(rollID)
end

-- Your simulated popup's item: an epic you can Need or Greed, bound on pickup.
function P.LootRollInfo(live, rollID)
    for _, r in ipairs(W.Rolls()) do
        if r.rollID == rollID then
            return { link = r.link, quality = (NS.ItemRead.QualityOf(r.link)), bop = true, canNeed = true,
                canGreed = true, canTransmog = false }
        end
    end
    return live(rollID)
end

-- The loot method and the loot window (DW-FP18, DW-FP19): a simulated group rolls under group
-- loot and opens no loot window (the threshold is the client's) until `/dw sim ml` makes a member
-- its master looter; from then on it is master loot, and the window holds the item until it is
-- handed out.
function P.LootMethod(live)
    local w = group()
    if not w then return live() end
    local loot = w.masterLoot
    if loot then
        local m = loot.member
        return { method = "master", isML = false, mlUnit = m.unit, mlName = m.name, mlRealm = m.realm,
            mlGUID = m.guid, threshold = W.ML_THRESHOLD }
    end
    local real = live()
    return { method = "group", isML = false, threshold = real and real.threshold or nil }
end

function P.LootSlots(live)
    local w = group()
    if not w then return live() end
    local loot = w.masterLoot
    if not loot or loot.assigned then return {} end
    return { { slot = 1, link = loot.link, quality = loot.quality, locked = true, sourceGUID = loot.sourceGUID } }
end

-- The roll popups and the gamepad switch (DW-FP20): a simulation invents no Blizzard popup (its
-- roll is drawn on modules/RollPopup.lua's stand-in), so the client's own frames and its input mode
-- answer while one runs.
local function client(live, ...) return live(...) end
P.RollPopupFrame, P.HookRollPopup, P.RollPopupOpen, P.GamepadUI = client, client, client, client

W.PROVIDERS = P
for key, fn in pairs(P) do NS.SimSeam:SetProvider(key, fn) end
