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
-- THE LEARNED RECIPES (spec §4.2 B) live account-wide in `db.global.itemSearch.learnedRecipes`
-- (modules/ItemSearchLearn.lua writes them). IS.Learned() answers that table, made on first use on
-- WoW Forever alone, and drops, once a session, every entry the shipped table covers.

NS.ItemSearch = NS.ItemSearch or {}
local IS = NS.ItemSearch
local C  = NS.Constants

local cache = {}
local load = { armed = false, timer = nil, waitCombat = false, done = false, ok = false, reason = nil }
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

--- Empty the per-item cache (a recipe learned, ForeverDB's state moved).
function IS.Invalidate()
    cache = {}
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
    if load.ok then warmIndexes() end
    return load.ok
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
    }
end

local function questState(questID)
    if NS.Compat.QuestInLog(questID) then return "log" end
    if NS.Compat.QuestDone(questID) then return "done" end
    return "todo"
end

local function liveContext()
    return { questState = questState, knows = NS.Compat.SpellKnown, ranks = NS.Compat.SkillLineRanks() }
end

--- The ranking's context for the player now (Item Search feedback spec §3, IS.Rank's `me`): level,
--- zone and continent, side, ranks, the known-spell and quest-state reads, and ForeverDB's spots
--- once it is loaded (never a load). `ranks`, when given (a facts table's, read by IS.Get this call),
--- saves a second read of the skill list.
--- @param ranks table|nil
--- @return table
function IS.Me(ranks)
    local Compat = NS.Compat
    local zone, continent = Compat.PlayerZone()
    local db = IS.State() == "loaded" and NS.ForeverDB or nil
    return {
        level = Compat.UnitLevel("player"), mapID = zone, continentID = continent, continentOf = Compat.ContinentOf,
        faction = Compat.PlayerFactionLetter(), ranks = ranks or Compat.SkillLineRanks(), known = Compat.SpellKnown,
        questState = questState, spots = db and db.Spots or nil,
    }
end

--- Whether the views show only the professions the player knows (spec §4: one setting for the
--- tooltip and the window's default, on by default).
--- @return boolean
function IS.MyProfessionsOnly()
    return NS.Setting("itemSearch.myProfessionsOnly") ~= false
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
        if (static.unnamedObjects or 0) > 0 then
            NS.Debug("SEARCH", "item %d: %d unnamed object source(s) left out", itemID, static.unnamedObjects)
        end
        if static.item.name then cache[itemID] = static end
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
    if NS.ItemSearchKey then NS.ItemSearchKey.OnRegen() end
end

-- A stand-down takes the timer back; the stand-up arms it again unless ForeverDB is loaded.
NS.STAND_DOWN[#NS.STAND_DOWN + 1] = function()
    if load.timer then load.timer:Cancel() end
    load.timer, load.armed, load.waitCombat = nil, false, false
end
NS.STAND_UP[#NS.STAND_UP + 1] = function()
    IS.Arm()
end
