local _, NS = ...
-- modules/ItemSearch.lua — Item Search's gate, ForeverDB's delayed load and the cached model
-- (DropWatcher#17, Item Search spec §1, §2, §4.3). WoW Forever's alone (C.FEATURE.itemSearch,
-- clients-§4): on Retail every member answers its off value and nothing here registers.
--
-- THE LOAD (spec §2, the owner's "a few seconds after login, out of combat"). The session's first
-- PLAYER_ENTERING_WORLD (the login or a reload; a later zone change is not one) arms one timer of
-- C.ITEM_SEARCH.LOAD_DELAY seconds. When it fires out of combat, IS.TryLoad calls the adapter's
-- Available(), the one call that loads ForeverDB (some 12 MB); in combat it waits for
-- PLAYER_REGEN_ENABLED and tries then. Straight after a load the adapter's two session indexes
-- (the item -> quests index and the name index) are built, one per frame, so no hover pays for
-- them (spec §4.4). Nothing loads while Item Search is switched off entirely (its tooltip block and
-- its window both off) or the addon stands down; switching it on later loads it then (IS.Refresh).
--
-- THE READS NEVER LOAD. IS.State answers where ForeverDB stands without loading anything (the
-- adapter's Status() is a diagnostics read): "loaded" once this file's load answered true,
-- "failed" when it answered false (disabled, or a reshaped database), "missing" when the client
-- does not know the addon, "off" while Item Search is off, "loading" before the load, and "client"
-- on Retail. IS.Get reads ForeverDB only in "loaded".
--
-- THE CACHE (spec §4.3). IS.Get(itemID) keeps IS.Static's answer per item for the session and adds
-- the live reads (quest states, known recipes, ranks) on every call. The cache is emptied when
-- ForeverDB's state moves and when the profession window learns a recipe; an item the client has
-- not cached yet (no name) is not kept, so it is read again once it is.
--
-- FOREVERDB_FULL (round 3 spec §4.6). The uncapped companion addon holds the map spots the base
-- slice leaves out. LibKa0s's LoadFull() is its one loader; WHEN is this file's policy, the
-- `itemSearch.fullDB` setting: "window" (the default) loads it on the Item Search window's first
-- open of a session (IS.WantFull, from modules/ItemSearchWindow.lua), "never" never does. It loads
-- only once ForeverDB itself is loaded (LoadFull would otherwise load the base), and never in
-- combat: an open in combat waits for one PLAYER_REGEN_ENABLED, then tries once. The tooltip never
-- asks for it (its perf ceilings). After the load the per-item cache and the spot memo are emptied,
-- the debug log names its cost, and the open window repaints. When another addon already loaded
-- Full, the same reset runs once, with no load of ours.
--
-- THE LEARNED RECIPES (spec §4.2 B) live account-wide in `db.global.itemSearch.learnedRecipes`
-- (modules/ItemSearchLearn.lua writes them). IS.Learned() answers that table, made on first use on
-- WoW Forever alone, and drops, once a session, every entry the shipped table covers.

NS.ItemSearch = NS.ItemSearch or {}
local IS = NS.ItemSearch
local C  = NS.Constants

local cache = {}
local load = { armed = false, timer = nil, waitCombat = false, done = false, ok = false, reason = nil }
local full = { asked = false, waitCombat = false, done = false, ok = false, reason = nil }
local lastState
local pruned = false

-- ── the gate ────────────────────────────────────────────────────────────────────────────────

--- Whether this client has Item Search at all (WoW Forever).
--- @return boolean
function IS.Enabled()
    return C.FEATURE.itemSearch == true
end

--- Whether the player wants Item Search now: the client has it, the addon stands up, and its
--- tooltip block or its window is switched on.
--- @return boolean
function IS.Wanted()
    if not IS.Enabled() or (NS.IsStoodDown and NS.IsStoodDown()) then return false end
    return NS.Setting("itemSearch.tooltip.enabled") == true or NS.Setting("itemSearch.window.enabled") == true
end

--- Empty the per-item cache (a recipe learned, ForeverDB's state moved, ForeverDB_Full loaded, a
--- vendor's price recorded), and with it the tooltip badge's verdicts (round 3 spec §4.5), which read
--- those facts.
function IS.Invalidate()
    cache = {}
    local verdicts = NS.ItemSearchVerdict
    if verdicts and verdicts.Bump then verdicts.Bump() end
end

--- Where ForeverDB stands for Item Search, never loading it: "loaded", "failed", "missing", "off",
--- "loading" or "client" (see the header).
--- @return string
function IS.State()
    if not IS.Enabled() then return "client" end
    local state
    if load.done then
        state = load.ok and "loaded" or "failed"
    elseif NS.ForeverDB.Status().present ~= true then
        state = "missing"
    elseif not IS.Wanted() then
        state = "off"
    else
        state = "loading"
    end
    if state ~= lastState then
        lastState = state
        IS.Invalidate()
        if IS.ForgetSpots then IS.ForgetSpots() end
    end
    return state
end

--- The adapter's answer to "why not loaded", after a failed load ("disabled", "missing", ...), or nil.
--- @return string|nil
function IS.FailReason()
    return load.done and not load.ok and load.reason or nil
end

-- ── the load ────────────────────────────────────────────────────────────────────────────────

-- The adapter's session indexes, built now rather than on a hover: one per frame.
local function warmIndexes()
    local FDB = NS.ForeverDB
    C_Timer.After(0, function()
        FDB.QuestsForItem(1)
        C_Timer.After(0, function() FDB.SearchItems("zz", 1) end)
    end)
end

--- Load ForeverDB now if Item Search wants it, it is not loaded yet and the player is out of
--- combat; in combat the load waits for the combat's end. True when this call loaded it.
--- @return boolean
function IS.TryLoad()
    if load.done or not IS.Wanted() then return false end
    if NS.Compat.InCombatLockdown() then
        load.waitCombat = true
        return false
    end
    load.waitCombat = false
    local ok, reason = NS.ForeverDB.Available()
    load.done, load.ok, load.reason = true, ok == true, reason
    NS.Debug("SEARCH", "ForeverDB load: %s (%s)", tostring(ok == true), tostring(reason))
    IS.State()
    if load.ok then
        warmIndexes()
        -- A window opened before this load asked for ForeverDB_Full: the next frame, not this one.
        if full.asked then C_Timer.After(0, IS.TryFull) end
    end
    return load.ok
end

-- ── ForeverDB_Full (round 3 spec §4.6) ──────────────────────────────────────────────────────

--- The `itemSearch.fullDB` setting: "window" (load ForeverDB_Full on the window's first open) or
--- "never".
--- @return string
function IS.FullPolicy()
    return NS.Setting("itemSearch.fullDB") == "never" and "never" or "window"
end

-- ForeverDB_Full is in: what was read without it is read again, and an open window repaints.
local function onFull(measured)
    full.done, full.ok = true, true
    IS.Invalidate()
    if IS.ForgetSpots then IS.ForgetSpots() end
    local cost = measured and NS.ForeverDB.FullCost() or nil
    if type(cost) == "table" and type(cost.kb) == "number" then
        NS.Debug("SEARCH", "ForeverDB_Full loaded: %.1f MB, %s ms", cost.kb / 1024,
            type(cost.ms) == "number" and ("%d"):format(math.floor(cost.ms + 0.5)) or "?")
    else
        NS.Debug("SEARCH", "ForeverDB_Full already loaded by another addon")
    end
    local W = NS.ItemSearchWindow
    if W and W.Refresh then W.Refresh() end
end

--- Load ForeverDB_Full now if the window asked for it this session, the setting allows it,
--- ForeverDB itself is loaded, Full is installed and loadable, and the player is out of combat (in
--- combat it waits for the combat's end, once). Answers whether Full is in after this call.
--- @return boolean
function IS.TryFull()
    if full.done then return full.ok end
    if not full.asked or IS.FullPolicy() ~= "window" or IS.State() ~= "loaded" then return false end
    local FDB = NS.ForeverDB
    local status = FDB.FullStatus()
    if status == "loaded" then onFull(false); return true end
    if status ~= "available" then return false end
    if NS.Compat.InCombatLockdown() then
        full.waitCombat = true
        return false
    end
    full.waitCombat = false
    local ok, reason = FDB.LoadFull()
    if ok then onFull(true); return true end
    full.done, full.reason = reason ~= "combat", reason
    NS.Debug("SEARCH", "ForeverDB_Full load refused: %s", tostring(reason))
    return false
end

--- The Item Search window opened: the session's ForeverDB_Full load may happen now (IS.TryFull).
--- @return boolean
function IS.WantFull()
    full.asked = true
    return IS.TryFull()
end

--- Where ForeverDB_Full stands for Drop Watcher: `{ asked, waitingForCombat, done, ok, reason }`, a
--- new table (the diagnostics and the tests).
--- @return table
function IS.FullState()
    return { asked = full.asked, waitingForCombat = full.waitCombat, done = full.done, ok = full.ok,
        reason = full.reason }
end

--- Arm the login timer, once a session (and again after a stand-down took it back).
function IS.Arm()
    if load.armed or load.done or not IS.Enabled() or (NS.IsStoodDown and NS.IsStoodDown()) then return end
    load.armed = true
    load.timer = C_Timer.NewTimer(C.ITEM_SEARCH.LOAD_DELAY, function()
        load.timer = nil
        IS.TryLoad()
    end)
end

--- A switch moved: once the login timer has fired, a load Item Search now wants happens now.
function IS.Refresh()
    if load.armed and not load.timer then IS.TryLoad() end
    IS.State()
end

--- Whether the login timer is armed and has not fired yet; whether a load waits for combat's end.
--- For the diagnostics and the tests.
--- @return boolean pending, boolean waitingForCombat
function IS.LoadPending()
    return load.timer ~= nil, load.waitCombat == true
end

-- ── the model, cached ───────────────────────────────────────────────────────────────────────

local function shippedRecipes()
    local RR = NS.RecipeReagents
    return RR and RR.Get() or nil
end

--- The profession window's learned recipes, `{ [spell] = { skillLine, reagents, made, name, build } }`,
--- account-wide; nil on Retail or before the database exists. The first call of a session drops
--- every entry the shipped table now covers.
--- @return table|nil
function IS.Learned()
    if not IS.Enabled() then return nil end
    local db = NS.addon and NS.addon.db
    local g = db and db.global
    if type(g) ~= "table" then return nil end
    if type(g.itemSearch) ~= "table" then g.itemSearch = {} end
    local store = g.itemSearch
    if type(store.learnedRecipes) ~= "table" then store.learnedRecipes = {} end
    if not pruned then
        pruned = true
        local recipes = shippedRecipes()
        IS.PruneLearned(store.learnedRecipes, recipes and recipes.recipes)
    end
    return store.learnedRecipes
end

--- Drop every learned entry `shipped` (the table's recipes) covers. Answers how many went.
--- @param learned table
--- @param shipped table|nil
--- @return number
function IS.PruneLearned(learned, shipped)
    local n = 0
    if type(learned) ~= "table" or type(shipped) ~= "table" then return 0 end
    for spell in pairs(learned) do
        if shipped[spell] ~= nil then learned[spell] = nil; n = n + 1 end
    end
    return n
end

local function staticContext(state)
    local race, class = NS.Compat.PlayerRaceClassIDs()
    return {
        fdb = state, db = NS.ForeverDB, clientItem = NS.Compat.ItemInfoByID,
        recipes = shippedRecipes(), learned = IS.Learned(), race = race, class = class,
        seenPrice = NS.ItemSearchPrices and NS.ItemSearchPrices.Seen or nil,
    }
end

-- A quest's state for the player (round 3 spec §4.2): turned in, then in the log and complete
-- (waiting to be turned in), then in the log, else not picked up.
local function questState(questID)
    local Compat = NS.Compat
    if Compat.QuestDone(questID) then return "done" end
    if Compat.QuestInLog(questID) then
        return Compat.QuestReady(questID) == true and "ready" or "log"
    end
    return "todo"
end

local function liveContext()
    return { questState = questState, knows = NS.Compat.SpellKnown, ranks = NS.Compat.SkillLineRanks() }
end

--- The ranking's context for the player now (Item Search feedback spec §3, IS.Rank's `me`): level,
--- zone and continent, side, ranks, the known-spell and quest-state reads, and ForeverDB's spots
--- once it is loaded (never a load). `ranks`, when given (a facts table's, read by IS.Get this call),
--- saves a second read of the skill list. `into`, when given, is filled and answered in place of a
--- new table (the tooltip's hover reuses one: it runs on every post call and never keeps it).
--- @param ranks table|nil
--- @param into table|nil
--- @return table
function IS.Me(ranks, into)
    local Compat = NS.Compat
    local zone, continent = Compat.PlayerZone()
    local db = IS.State() == "loaded" and NS.ForeverDB or nil
    local me = into or {}
    me.level, me.mapID, me.continentID, me.continentOf = Compat.UnitLevel("player"), zone, continent, Compat.ContinentOf
    me.faction, me.ranks, me.known = Compat.PlayerFactionLetter(), ranks or Compat.SkillLineRanks(), Compat.SpellKnown
    me.questState, me.spots = questState, db and db.Spots or nil
    return me
end

--- Whether the views show only the professions the player knows (spec §4: one setting for the
--- tooltip and the window's default, on by default).
--- @return boolean
function IS.MyProfessionsOnly()
    return NS.Setting("itemSearch.myProfessionsOnly") ~= false
end

--- Whether the views leave out the vendors only the other faction can buy from (R4-DW-08: one
--- setting for the tooltip and the window's default, on by default).
--- @return boolean
function IS.HideOtherFaction()
    return NS.Setting("itemSearch.hideOtherFaction") ~= false
end

--- The window's view defaults the settings give (NS.ItemSearchTabs.DefaultState's `opts`): the
--- Crafting tab's "Only my professions" and the Sold by tab's "Only my faction".
--- @return table { mine, faction }
function IS.ViewDefaults()
    return { mine = IS.MyProfessionsOnly(), faction = IS.HideOtherFaction() }
end

-- The static facts' counts, written to the debug log once per item: the nameless objects and the
-- test-named sources left out (round 3 spec §4.3), and the fishing nodes that yield a herb.
local function logStatic(itemID, static)
    if (static.unnamedObjects or 0) > 0 then
        NS.Debug("SEARCH", "item %d: %d unnamed object source(s) left out", itemID, static.unnamedObjects)
    end
    if (static.testSources or 0) > 0 then
        NS.Debug("SEARCH", "item %d: %d test-named source(s) left out", itemID, static.testSources)
    end
    if (static.fishingHerbs or 0) > 0 then
        NS.Debug("SEARCH", "item %d: %d fishing node(s) yield this herb (ForeverDB's data)", itemID, static.fishingHerbs)
    end
end

--- Everything Item Search knows about `itemID` (IS.Facts' shape), or nil on Retail or for no item
--- id. Reads ForeverDB only once it is loaded; never loads it.
--- @param itemID number
--- @return table|nil
function IS.Get(itemID)
    if not IS.Enabled() or type(itemID) ~= "number" then return nil end
    local state = IS.State()
    local static = cache[itemID]
    if not static then
        static = IS.Static(itemID, staticContext(state))
        if not static then return nil end
        -- Logged once, when the facts are kept: an item the client has not named yet misses the
        -- cache on every hover, and would log on every tooltip show until its name arrives.
        if static.item.name then
            cache[itemID] = static
            logStatic(itemID, static)
        end
    end
    return IS.Live(static, liveContext())
end

-- ── events and the lifecycle ────────────────────────────────────────────────────────────────

-- PLAYER_ENTERING_WORLD and PLAYER_REGEN_ENABLED are shared (core/DropWatcher.lua's dispatcher);
-- both rows are WoW Forever's alone.
NS.FEATURE_EVENTS[#NS.FEATURE_EVENTS + 1] = { "PLAYER_ENTERING_WORLD", "OnItemSearchWorld", clients = { "forever" } }
NS.FEATURE_EVENTS[#NS.FEATURE_EVENTS + 1] = { "PLAYER_REGEN_ENABLED", "OnItemSearchRegen", clients = { "forever" } }

function NS.addon.OnItemSearchWorld()
    IS.Arm()
    if NS.ItemSearchKey then NS.ItemSearchKey.OnWorld() end
end

function NS.addon.OnItemSearchRegen()
    if load.waitCombat then IS.TryLoad() end
    if full.waitCombat then IS.TryFull() end
    if NS.ItemSearchKey then NS.ItemSearchKey.OnRegen() end
    if NS.ItemSearchPrices then NS.ItemSearchPrices.OnRegen() end
end

-- A stand-down takes the timer back; the stand-up arms it again unless ForeverDB is loaded.
NS.STAND_DOWN[#NS.STAND_DOWN + 1] = function()
    if load.timer then load.timer:Cancel() end
    load.timer, load.armed, load.waitCombat = nil, false, false
    full.waitCombat = false
end
NS.STAND_UP[#NS.STAND_UP + 1] = function()
    IS.Arm()
end
