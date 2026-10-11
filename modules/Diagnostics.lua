local _, NS = ...
-- modules/Diagnostics.lua — the addon's sections of `/dw diagnostics` (debug-logging-§14).
--
-- Sections only: the markers, the identity header's library half, the per-section pcall, the cap
-- and the Add loop are LibKa0s-DebugLog-1.0's. Every section READS state and never acts: no hold,
-- no event, no timer, safe in combat and while stood down. `out:add` formats %s-only and runs every
-- argument through safeToString, so raw values are passed, never pre-built strings. Every section
-- of design spec §13 is here: State, Feed, Inspect, Gear, Trade, Scoring and Messaging, beside the
-- standard's identity, settings, registration and integrations.

NS.Diagnostics = NS.Diagnostics or {}

local TAG = "Diag"

local function stoodDown() return NS.IsStoodDown and NS.IsStoodDown() or false end

local function read(fn, ...)
    if type(fn) ~= "function" then return "unavailable" end
    local ok, v = pcall(fn, ...)
    if not ok then return "unreadable" end
    return v
end

-- The report runs after OnInitialize, so the db exists; a section that raises costs one line
-- (the library pcalls each section).
local function identity(out)
    local db = NS.addon.db
    out:add(TAG, "schema stored=%s code=%s", db.global.schemaVersion, NS.SCHEMA_VERSION)
    out:add(TAG, "profile=%s", db:GetCurrentProfile())
    out:add(TAG, "enabled=%s stoodDown=%s", db.profile.enabled, stoodDown())
    out:joined(TAG, "holds", NS.Lifecycle:Holds())
end

local function settings(out)
    local S = NS.SchemaRuntime
    local Settings = NS.addon and NS.addon.Settings
    out:nonDefaults(Settings and Settings.Schema, function(row) return S.Get(row.path) end, nil, nil,
        { always = { "enabled" } })
end

local function profile()
    local db = NS.addon and NS.addon.db
    return db and db.profile or {}
end

-- Design spec §13's State section: the one line that answers "is it on, where am I, can it talk".
-- The situation is classified live (the classifier's edge only reads); the rest is stored state.
local function state(out)
    local p = profile()
    local key = read(function() return NS.Situations.Classify(NS.Situations.ReadInputs()) end)
    local snap = NS.Restrictions.Snapshot()
    out:add(TAG, "state: enabled=%s situation=%s testMode=%s restriction=%s queuedSends=%s",
        p.enabled ~= false, key, NS.State.testMode == true, snap.reason or "none", NS.Asks.Stats().queued)
end

-- The window's show decision and its inputs, so "why is the window not showing" is one read.
local function window(out)
    local W, State, p = NS.Window, NS.State, profile()
    out:add(TAG, "window: built=%s shown=%s shouldShow=%s", W.Frame() ~= nil, read(W.IsShown),
        read(W.ShouldShow))
    out:add(TAG, "window: open=%s testMode=%s visibility=%s locked=%s", State.windowOpen,
        State.testMode, p.visibility, p.locked)
    local g = type(p.window) == "table" and p.window or {}
    local point = type(g.point) == "table" and g.point or { "default" }
    out:joined(TAG, "window: point", point)
    out:add(TAG, "window: size=%sx%s", g.width or "default", g.height or "default")
    out:add(TAG, "window: tab=%s minimized=%s new=%s", read(W.ActiveTab), g.minimized == true, read(W.NewCount))
end

-- Where the addon thinks the player is, the inputs it read and that situation's settings
-- (design spec §6.1, §13). The inputs are read live: the classifier's edge only reads.
local function situation(out)
    local Sit = NS.Situations
    local i = Sit.ReadInputs()
    local key = Sit.Classify(i)
    local s = Sit.Settings(key)
    out:add(TAG, "situation: %s (last announced %s) track=%s autoOpen=%s quality=%s", key,
        NS.State.situation or "none", s.track, s.autoOpen, s.quality or "global")
    out:add(TAG, "situation inputs: inInstance=%s type=%s difficulty=%s challengeMode=%s",
        i.inInstance, i.instanceType, i.difficultyID or "none", i.isChallengeModeActive)
    out:add(TAG, "situation inputs: delve=%s follower=%s group=%s raid=%s pvp=%s", i.isDelve,
        i.isFollowerDungeon, i.inGroup, i.inRaid, i.isPvP)
end

-- What the restrictions allow now, every reason in effect (sorted, the Map type included) and
-- what was last announced (design spec §4, §13). Read live: the tracker only reads.
local function restrictions(out)
    local Rs = NS.Restrictions
    local snap = Rs.Snapshot()
    out:add(TAG, "restrictions: reason=%s canSendChat=%s canInspect=%s canTrade=%s",
        snap.reason or "none", snap.canSendChat, snap.canInspect, snap.canTrade)
    local active = {}
    for reason in pairs(Rs.ActiveSet()) do active[#active + 1] = reason end
    table.sort(active)
    out:joined(TAG, "restrictions: active", active)
    out:add(TAG, "restrictions: last announced %s", NS.State.restrictionSignature or "none")
end

-- The group as the roster last read it (design spec §4): stored state only, so the report never
-- triggers the roster's lazy read. One line per member.
local function roster(out)
    local r = NS.State.roster
    if not r then return out:add(TAG, "roster: not read yet") end
    out:add(TAG, "roster: %s members", #r.list)
    for _, m in ipairs(r.list) do
        out:add(TAG, "roster: %s unit=%s class=%s online=%s spec=%s player=%s", m.fullName or "?",
            m.unit, m.classFile or "?", m.online, m.specID or "unknown", m.isPlayer)
    end
end

-- The inspect broker (design spec §8, §13): the queue's length, the job in flight, whether it is
-- parked and the spacing left, then one line per entry with its status, reason, spec, slots read
-- and age. Stored state only.
local function inspect(out)
    local s = NS.State.inspect
    if not s then return out:add(TAG, "inspect: nothing asked yet") end
    local q = NS.Inspect.QueueState()
    out:add(TAG, "inspect: queued=%s inFlight=%s parked=%s spacingLeft=%s", q.queued,
        q.inFlight or "none", q.parked, ("%.1f"):format(q.spacingLeft))
    local r = NS.State.roster
    for guid, e in pairs(s.entries) do
        local m = r and r.byGUID[guid]
        out:add(TAG, "inspect: %s status=%s reason=%s spec=%s slots=%s age=%ss stale=%s",
            m and m.fullName or guid, e.status, e.reason or "none", e.specID or "unknown", e.worn or 0,
            e.at and math.floor(GetTime() - e.at) or "never", e.stale == true)
    end
end

-- Inventory slot id -> its C.SLOT name, for the gear lines.
local function slotNames()
    local names = {}
    for name, id in pairs(NS.Constants.SLOT) do names[id] = name end
    return names
end

-- One worn slot as the gear line shows it: the level and quality, "empty" or "loading".
local function wornText(e)
    if e == false then return "empty" end
    if e == nil then return "loading" end
    return ("ilvl=%s quality=%s"):format(tostring(e.ilvl), tostring(e.quality))
end

-- The player's gear snapshot as last read (design spec §4, §13): stored state only, so the report
-- never triggers the snapshot's lazy read. One line per slot, with the owned best when it is not
-- the worn item.
local function gear(out)
    local s = NS.State.gear
    if not s then return out:add(TAG, "gear: not read yet") end
    out:add(TAG, "gear: class=%s spec=%s dualWield=%s titanGrip=%s loading=%s", s.classFile or "?",
        s.specID or "unknown", s.dualWield, s.titanGrip, s.loading)
    local names = slotNames()
    for _, id in ipairs(NS.Gear.SLOTS) do
        local worn, owned = s.equipped[id], s.owned[id]
        local better = owned and owned ~= worn and (" owned=" .. tostring(owned.ilvl)) or ""
        out:add(TAG, "gear: %s %s%s", names[id], wornText(worn), better)
    end
end

-- What the loot parser has read since login: the lines it turned into loot, the ones it ignored,
-- rejected (upgrade and crafting echoes) and found secret, and the last loot seen.
local function parserLines(out)
    local s = NS.State.lootParser
    if not s then return out:add(TAG, "feed: parser has read no loot line yet") end
    out:add(TAG, "feed: parser hits=%s ignored=%s rejected=%s secret=%s", s.hits, s.ignored,
        s.rejected, s.secret)
    if not s.lastAt then return out:add(TAG, "feed: no loot seen yet") end
    out:add(TAG, "feed: last loot %ss ago (chat, %s) by %s", math.floor(GetTime() - s.lastAt),
        s.lastKind, s.lastLooter or "?")
end

-- The feed's drops per tab, its groups, merges and pending loads, the drops hidden by reason, and
-- the encounter and keystone run in progress.
local function dropLines(out)
    local st = NS.LootFeed.Stats()
    if not st then return out:add(TAG, "feed: no drop received yet") end
    out:add(TAG, "feed: drops group=%s mine=%s test=%s groups=%s merged=%s loading=%s", st.group,
        st.mine, st.test, st.groups, st.merged, st.loading)
    local hidden = {}
    for reason, n in pairs(st.hidden) do hidden[#hidden + 1] = reason .. "=" .. n end
    table.sort(hidden)
    out:joined(TAG, "feed: hidden", hidden)
    out:add(TAG, "feed: encounter=%s run=%s", st.encounter or "none", st.run or "none")
end

-- The quality mode in force here and its threshold; for the per-slot mode, each slot's (compact).
-- The worn qualities come from the stored gear snapshot, so the report never triggers a read.
local function qualityLine(out)
    local QG, cfg, g = NS.QualityGate, NS.LootFeed.Config(), NS.State.gear
    local mode = QG.ResolveMode(cfg.qualityMode, NS.Situations.QualityOverride())
    local worn = {}
    for slot, e in pairs(g and g.equipped or {}) do worn[slot] = e and e.quality or false end
    local ctx = { fixed = cfg.fixed, floor = cfg.floor, gear = worn }
    if mode ~= "dynamicSlot" then
        return out:add(TAG, "feed: quality mode=%s threshold=%s (%s)", mode, QG.Threshold(mode, ctx))
    end
    local names, parts = slotNames(), {}
    for _, slot in ipairs(NS.Gear.SLOTS) do
        if not NS.Constants.QUALITY_IGNORED_SLOT[slot] then
            ctx.baselineSlot = slot
            parts[#parts + 1] = names[slot] .. "=" .. QG.Threshold(mode, ctx)
        end
    end
    out:joined(TAG, "feed: quality mode=dynamicSlot thresholds", parts)
end

-- Design spec §13's Feed section. Stored state only, apart from the situation read live.
local function feed(out)
    parserLines(out)
    dropLines(out)
    qualityLine(out)
end

-- The trade helper's counts (once it has been used), then the trade timer's entries (design spec
-- §7.4, §13): the live and expired counts, the scans and the ticker's period, then one line per
-- entry. Stored state only.
local function trade(out)
    local th = NS.TradeHelper.Stats()
    if th then
        out:add(TAG, "trade helper: gives=%s opens=%s refused=%s last=%s", th.gives, th.opens, th.refused,
            th.lastReason or "none")
    end
    local st = NS.TradeTimer.Stats()
    if not st then return out:add(TAG, "trade: no scan yet") end
    out:add(TAG, "trade: timers live=%s expired=%s boe=%s scans=%s ticker=%s", st.live, st.expired,
        st.permanent, st.scans, st.period and (st.period .. "s") or "off")
    for guid, e in pairs(NS.TradeTimer.Entries()) do
        out:add(TAG, "trade: drop %s %s left=%ss expired=%s boe=%s warned=%s guid=%s", e.dropID, e.link,
            math.floor(NS.TradeTimer.Remaining(e)), e.expired, e.permanent == true, e.warned, guid)
    end
end

-- The messaging edge (design spec §9.2, §13): the one-ask registry by state, the sends, failures,
-- refusals and flushes, each template's length, then one line per queued ask. Stored state only.
local function messaging(out)
    local A, M = NS.Asks, NS.Messaging
    local st = A.Stats()
    out:add(TAG, "messaging: asks=%s queued=%s sent=%s failed=%s ready=%s", st.asks, st.queued, st.sent,
        st.failed, st.ready)
    out:add(TAG, "messaging: sends=%s failures=%s refusals=%s flushes=%s flushing=%s", st.sends,
        st.failures, st.refusals, st.flushes, st.flushing)
    local cfg = A.Settings()
    local lengths = {}
    for i, kind in ipairs(NS.Constants.MESSAGE_KINDS) do
        lengths[i] = kind .. "=" .. #M.Template(kind, cfg.templates)
    end
    out:joined(TAG, "messaging: template lengths", lengths)
    out:add(TAG, "messaging: oneAsk=%s announceChannel=%s", cfg.oneAsk, cfg.announceChannel)
    for _, a in ipairs(A.Queued()) do
        out:add(TAG, "messaging: queued %s to %s, drop %s", a.kind, a.target, a.dropID)
    end
end

-- Your Pawn scale, read from the stored gear snapshot's class and spec (never a fresh read).
local function pawnScale()
    local g = NS.State.gear
    local classID = g and NS.ClassData.CLASS_ID[g.classFile]
    if not (classID and g.specID) then return nil end
    return NS.Compat.PawnScaleForSpec(classID, g.specID)
end

-- Design spec §5.4, §13's Scoring section: the scorer chosen, whether its adapter is built (the
-- adapters land with the scoring item), Pawn's readiness and your scale, and the score retries.
local function scoring(out)
    local S = NS.Scoring
    local adapter = type(S) == "table" and type(S.Scorer) == "function" and "ready" or "none"
    out:add(TAG, "scoring: scorer=%s adapter=%s", NS.SchemaRuntime.Get("comparison.scorer"), adapter)
    out:add(TAG, "scoring: pawn ready=%s scale=%s", NS.Compat.PawnIsReady(), read(pawnScale) or "none")
    local r = NS.LootFeed.ScoreRetries()
    out:add(TAG, "scoring: retries pending=%s spent=%s timer=%s", r.pending, r.spent, r.armed and "on" or "off")
end

local function registration(out)
    local names = NS.FeatureEventNames and NS.FeatureEventNames() or {}
    out:joined(TAG, "feature events (declared)", names)
    -- Stood down, the latch has unregistered them; the declared list is printed either way.
    out:add(TAG, "feature events registered=%s", not stoodDown())
    out:list(TAG, "rejected events", NS.rejectedEvents or {})
end

local function integrations(out)
    local Lc = NS.Launcher
    out:add(TAG, "launcher: registered=%s shown=%s", Lc and read(Lc.IsRegistered, Lc),
        Lc and read(Lc.IsShown, Lc))
    local loaded = C_AddOns and C_AddOns.IsAddOnLoaded
    out:add(TAG, "optional: Pawn=%s CanIMogIt=%s", loaded and read(loaded, "Pawn") or false,
        loaded and read(loaded, "CanIMogIt") or false)
end

--- The sections, in report order. Read at RUN time by core/DebugLogSetup.lua's descriptor.
--- @return table
function NS.Diagnostics.Sections()
    return {
        { "identity",     identity },
        { "state",        state },
        { "settings",     settings },
        { "window",       window },
        { "situation",    situation },
        { "restrictions", restrictions },
        { "roster",       roster },
        { "inspect",      inspect },
        { "gear",         gear },
        { "feed",         feed },
        { "trade",        trade },
        { "scoring",      scoring },
        { "messaging",    messaging },
        { "registration", registration },
        { "integrations", integrations },
    }
end
