local _, NS = ...
-- core/VerdictSetup.lua — NS.Verdict and NS.VerdictEngine, the LibKa0s-Verdict-1.0 seam
-- (library-stack-§7; Item Search split plan, task C1, DropWatcher#19).
--
-- The verdict engine ("what is this item to me": an upgrade, a sidegrade, a downgrade, something
-- you cannot use or do not want) is the library's: Drop Watcher's own engine moved there so Ka0s
-- Item Search judges the same item the same way. This file holds the descriptor, the one instance
-- and the library-absent stand-in; core/VerdictViews.lua holds the views Drop Watcher's readers
-- reach it through (NS.Evaluate, NS.ClassData, NS.OffSpec, NS.TierTokens, NS.ItemRead,
-- NS.ItemFacts, NS.Gear, NS.Scoring, NS.Collectibles).
--
-- NS.Verdict is the major (its pure kernel: Evaluate, ClassData, OffSpec, TierTokens, C, Collect,
-- Score, ItemRead, Settings). NS.VerdictEngine is this addon's one instance, `V:New(host)`, which
-- keeps the item facts cache, your gear snapshot, the scorer and the collection re-read. The host:
--
--   client     NS.Compat.ClientKey(), once: the class list, the slots, the off-spec and transmog
--              gates, the default verdict mode and the events are this client's.
--   config     NS.LootFeed.VerdictConfig(): the six `comparison.*` values and LF.VERDICT_MODE.
--   reads      PlayerRole alone, NS.Compat's (this addon's role store: the override and the saved
--              answer, which the library's own read does not know). Every other read is the
--              library's (lib.Reads), resolved at each call through the instance's forwarders
--              (v.R, Verdict minor 3, LibKa0s#111), and the simulator's seam covers v.R in place
--              (Sim:Cover, below), so a provider or a guard keyed by a read's name answers the
--              instance's read too.
--   deferWhile NS.Restrictions.InCombat: a bag event in combat waits for the combat's end.
--   events     registered through NS.FEATURE_EVENTS (core/DropWatcher.lua), one row per event the
--              instance listens to, so the stand-down drops them with every other row and the
--              simulator's replay (NS.DeliverEvent) reaches them. host.registerEvent only keeps
--              the instance's handler for its row.
--   onChange   "gear" sends NS.MSG.GEAR_CHANGED; "collection" runs the feed's re-judge
--              (NS.CollectFeed.OnCollectionsChanged).
--
-- THE LIFECYCLE. The instance stands up at OnEnable (NS.VerdictEnable, core/DropWatcher.lua) lazily
-- (`v:StandUp{ lazy = true }`, LibKa0s#108): its handlers kept and no gear read, so the first ask for
-- your gear reads it, quietly, and a gear event before that ask rebuilds and announces as ever. At
-- every later stand-up (NS.VerdictStandUp) it reads your gear at once and announces it. It stands
-- down with the addon (NS.STAND_DOWN), which drops its timers and caches.
--
-- Absent library: NS.Verdict is a stand-in whose kernel answers `unknown` for every item, and
-- NS.VerdictEngine one that reads nothing, so every verdict reads "unknown" and nothing raises.

local V = LibStub and LibStub("LibKa0s-Verdict-1.0", true)
local Sim = LibStub and LibStub("LibKa0s-Sim-1.0", true)

-- ── the library-absent stand-in ────────────────────────────────────────────────────────────

local function none() return nil end
local function empty() return {} end
local MISSING = "LibKa0s-Verdict-1.0 is missing"

local function unknownVerdict()
    return { verdict = "unknown", equip = "unknown", reasons = { { key = "error", detail = MISSING } } }
end

-- A class list with no class in it: every lookup answers nothing.
local function emptyList()
    local list = { CLASS_ID = {}, ARMOR = {}, WEAPONS = {}, SPECS = {}, CLASS_SPECS = {}, SPEC_INDEX = {},
        STAT_GATE = {}, STAT = {} }
    for _, name in ipairs({ "Spec", "OwnSpec", "SpecKey", "PrimaryStat", "DualWieldFor", "TitanGripFor",
        "CanUseShield", "CanUseOffhand", "SpecIndex", "ArmorFor", "CanWearArmor", "CanUseRelic",
        "CanUseWeapon" }) do
        list[name] = none
    end
    return list
end

local function stubLib()
    local lists = { retail = emptyList(), forever = emptyList() }
    return {
        MISSING = true,
        Evaluate = unknownVerdict,
        Equippability = function() return "unknown", "error" end,
        ItemVerdict = none, TrackDelta = none,
        SubClassKey = function(classID, subClassID) return tostring(classID) .. ":" .. tostring(subClassID) end,
        VerdictModeFor = function(client) return client == "forever" and "scoreFirst" or "ilvlFirst" end,
        ClassData = { LISTS = lists, ForClient = function(key) return lists[key] or lists.retail end },
        OffSpec = {
            SPEC_REASONS = {}, Enabled = function() return false end,
            Who = function(classFile, specID) return { classFile = classFile, specID = specID } end,
            WornGear = empty, Of = none, EvalFor = function(eval) return eval end, Attach = none,
        },
        TierTokens = { Listed = function() return false end, UseNamesClass = function() return false end,
            UseSlot = none, NameSlot = none, IsCurio = function() return false end, Users = none,
            SlotOf = none, Fold = unknownVerdict },
        ItemRead = { GEAR_CLASSES = {}, ItemString = none, LinkDetail = none,
            BetterLink = function(a, b) return a or b end, IdentityKey = function(link) return link end },
        Facts = { TrackTier = none },
        Collect = { REREAD_DELAY = 0.5, CategoryOf = none, IsCollectible = function() return false end,
            Verdict = none, Read = none },
        Score = { PAWN_STATS = {}, STAT_KEYS = {}, SCORERS = { auto = true, pawn = true, weights = true, none = true },
            ParseImport = function() return {} end, ImportInto = function(map) return map, 0 end,
            WeightsScore = function() return 0 end, HasWeights = function() return false end,
            Resolve = function() return "none" end, WeightsFor = none, WeightsScorer = function() return none end },
        Gear = { THROTTLE = 0.5, SlotsFor = empty },
        -- No instance stands up, so it listens to nothing and no event gets a row.
        EventsFor = empty,
    }
end

-- The instance stand-in: no facts, an empty snapshot, no scorer; every method answers its nothing.
-- Its methods are plain functions (called with `:`, they ignore the instance).
local function stubEngine(client)
    local snap = { equipped = {}, owned = {}, pool = {}, bySpec = {}, loading = 0, signature = false }
    local function answer(...)
        local n, out = select("#", ...), { ... }
        return function() return unpack(out, 1, n) end
    end
    local nothing = function() end
    local e = {
        Client = answer(client), Judge = answer(nil, false), JudgeFacts = unknownVerdict, Facts = none,
        ReadFacts = none, Request = answer(nil, "unavailable"), FactsCounts = answer(0, 0),
        RereadCollections = answer(0), EffectiveItemLevel = none, QualityOf = none, ItemLevelAt = none,
        QualityAt = none, Snapshot = answer(snap), Signature = answer(false),
        Candidate = function() return { gear = snap.equipped, owned = snap.owned, isPlayer = true } end,
        OffSpecGear = none, ReadGear = answer(snap), RefreshGear = answer(false), ScheduleGear = nothing,
        GearScheduled = answer(false), OnGearEvent = nothing, OnGearDeferEnd = nothing, Scorer = none,
        ScorerInUse = answer("none"), ScoreFor = none,
        CollectionsChanged = nothing, Events = empty, StandUp = nothing, StandDown = nothing, IsStoodDown = answer(false),
    }
    -- Set apart: the compat gate reads a Pawn name in a table constructor as a client call.
    e.PawnScale, e.PawnScorer = none, none
    return e
end

NS.Verdict = V or stubLib()

-- ── the host ───────────────────────────────────────────────────────────────────────────────

local CLIENT = NS.Compat.ClientKey()

-- The instance's events, by client, read from the library (NS.Verdict.EventsFor, the stand-in's
-- answering none), so an event a later minor adds gets its row with no edit here (DropWatcher#21).
-- Each is one NS.FEATURE_EVENTS row whose handler hands the event to the instance's handler for it
-- (host.registerEvent): an event both clients listen to carries no clients tag, one only a single
-- client listens to carries that client's.
local CLIENTS = { "retail", "forever" }
local ROUTED, ORDER = {}, {}
for _, client in ipairs(CLIENTS) do
    for _, event in ipairs(NS.Verdict.EventsFor(client)) do
        if ROUTED[event] then
            ROUTED[event] = "both"
        else
            ROUTED[event], ORDER[#ORDER + 1] = client, event
        end
    end
end
for _, event in ipairs(ORDER) do
    local only = ROUTED[event]
    NS.FEATURE_EVENTS[#NS.FEATURE_EVENTS + 1] = { event, "OnVerdictEvent",
        clients = only ~= "both" and { only } or nil }
end

-- The instance's handler per event, kept while it is stood up.
local handlers = {}

function NS.addon.OnVerdictEvent(_, event, ...)
    local fn = handlers[event]
    if fn then fn(event, ...) end
end

local host = {
    client = CLIENT,
    L = NS.L,
    -- The one read this addon answers itself; NS.Compat's member is the seam-wrapped one.
    reads = { PlayerRole = NS.Compat.PlayerRole },
    config = function() return NS.LootFeed and NS.LootFeed.VerdictConfig() or nil end,
    debug = function(tag, msg) NS.Debug(tag, "%s", msg) end,
    deferWhile = function() return NS.Restrictions ~= nil and NS.Restrictions.InCombat() end,
    registerEvent = function(event, fn)
        if not ROUTED[event] then
            NS.Debug("Init", "verdict: %s has no NS.FEATURE_EVENTS row; it is not heard", tostring(event))
        end
        handlers[event] = fn
    end,
    unregisterEvent = function(event) handlers[event] = nil end,
    onChange = function(kind)
        if kind == "gear" then
            NS.State.gear = NS.VerdictEngine:Snapshot()   -- the mirror (core/VerdictViews.lua's NS.Gear)
            NS.addon:SendMessage(NS.MSG.GEAR_CHANGED)
        elseif kind == "collection" and NS.CollectFeed then
            NS.CollectFeed.OnCollectionsChanged()
        end
    end,
}

-- The perf harness (core/PerfSetup.lua, loaded before this file; its stand-in when the library is
-- absent) times the instance's gear rebuild (`gear.rebuild`) while a capture is on: the host's perf
-- is NS.Perf itself, so the dormant bracket reads its plain `on` field. The feed times its own
-- verdicts (modules/LootFeed.lua's `evaluate`, inside `feed.add`): it judges through the kernel
-- views, never v:JudgeFacts.
host.perf = NS.Perf

NS.VerdictEngine = V and V:New(host) or stubEngine(CLIENT)

-- The simulator's seam (core/SimSetup.lua) covers the instance's reads in place, before
-- modules/Sim*.lua register their providers (the TOC loads this file first): a provider or guard
-- keyed by a read's name answers v.R's member too, and the seam's Unwrapped() takes v.R in.
-- PlayerRole is pure here: it is NS.Compat's member, wrapped already, so covering it again would
-- consult its provider twice.
if V and Sim then Sim:Cover(NS.SimSeam, NS.VerdictEngine.R, { pure = { PlayerRole = true } }) end

--- Stand the instance up at the latch's stand-up: its handlers kept and your gear read and
--- announced (NS.STAND_UP).
function NS.VerdictStandUp()
    NS.VerdictEngine:StandUp()
end

--- Stand the instance up at OnEnable (core/DropWatcher.lua): its handlers kept and no gear read; the
--- first ask reads it, quietly, as it did when the snapshot was this addon's own (nobody has judged
--- against an older one).
function NS.VerdictEnable()
    NS.VerdictEngine:StandUp{ lazy = true }
end

NS.STAND_DOWN[#NS.STAND_DOWN + 1] = function()
    NS.VerdictEngine:StandDown()
    NS.State.gear = nil
end
NS.STAND_UP[#NS.STAND_UP + 1] = NS.VerdictStandUp
