local _, NS = ...
-- modules/SimEvents.lua — the simulator's event drivers (simulator spec §2): loot lines, boss
-- pulls and kills, a keystone run, combat and the restrictions they raise, your own drops' trade
-- windows and a completed trade. Each is delivered through NS.Sim.Fire, which calls the very
-- handlers the event registration calls, with the client's payload shapes; the engine computes
-- everything that follows. Nothing here sets a verdict, a trade estimate or an inspect state.
--
-- LOOT LINES are written from the client's own LOOT_ITEM* GlobalStrings, read through
-- NS.Compat.GlobalString (the self or the third-person form of a loot, a bonus roll or a pushed
-- item, each with its *_MULTIPLE twin, a positional locale read in its own order), so the real
-- parser reads them. A looter on your realm
-- is named bare, one from another realm Name-Realm, as chat names them. The payload is
-- CHAT_MSG_LOOT's: text, playerName, languageName, channelName, playerName2, specialFlags,
-- zoneChannelID, channelIndex, channelBaseName, languageID, lineID, guid. Plan draws a burst: one to
-- three lines by default, random looters (you and a member always among them in a burst of two
-- or more), occasional multiples and bonus rolls, and a looter from another realm whenever the
-- group has one and the burst has room.
--
-- YOUR OWN DROPS land in your bags first, each with a trade window (TRADE_WINDOW seconds by
-- default; Configure sets it per scenario, and the first ENDING_SOON_COUNT of them close in
-- ENDING_SOON seconds), then the line, then BAG_UPDATE_DELAYED, so the trade timer reads the
-- countdown through its usual scan.
--
-- THE GROUP. Join delivers GROUP_ROSTER_UPDATE and PLAYER_ENTERING_WORLD once the roster is drawn,
-- so every reader of the group and the situation reads the simulated one (modules/SimWorld.lua).
--
-- ENCOUNTERS. Pull delivers ENCOUNTER_START(id, name, difficultyID, groupSize) with an invented id
-- and name, the combat edge and the Encounter restriction; Kill delivers ENCOUNTER_END(id, name,
-- difficultyID, groupSize, success) first, then the combat edge, then lifts the restriction, as
-- the client may report it after the kill. A run (RunStart, RunEnd) is CHALLENGE_MODE_START(mapID)
-- and CHALLENGE_MODE_COMPLETED with the ChallengeMode restriction held between them. Combat is the
-- PLAYER_REGEN_DISABLED / PLAYER_REGEN_ENABLED edge with the Combat restriction.
--
-- A TRADE (Trade(dropID)) for a simulated drop: your own drop is given to a member, anyone else's is
-- received from its looter. TRADE_SHOW opens the simulated window (modules/SimWorld.lua answers its
-- partner and items), the item changes, both accepts, TRADE_CLOSED and the "Trade complete."
-- UI_INFO_MESSAGE follow; the history's own trade reader settles the outcome. A given item leaves
-- your bags.
--
-- COMBAT FLAGS. While the simulated combat edge is up, InCombatLockdown and the player's combat
-- flag answer true through the seam; otherwise the client answers.
--
-- THE STOP. A cleanup step ends the combat edge it raised (unless you really are fighting) and
-- re-reads your real bags (BAG_UPDATE_DELAYED), both delivered once the seam is off.
--
--   State.sim.drive = { lines, pulls, kills, encounter = { id, name } | nil, run = { mapID, name,
--     level, ended } | nil, combat, trade = { window, soon, soonLeft }, trades }

NS.SimEvents = NS.SimEvents or {}
local E = NS.SimEvents
local Sim = NS.Sim
local L = NS.L

local TAG = "SIM"

--- Seconds your own simulated drop stays tradeable, unless the scenario says otherwise.
E.TRADE_WINDOW = 2 * 60 * 60
--- Seconds the "ending soon" drops stay tradeable, and how many of them a session has.
E.ENDING_SOON = 9 * 60
E.ENDING_SOON_COUNT = 1

--- The keystone level a simulated run answers (C_ChallengeMode through the seam, feedback-3 spec §4).
E.KEY_LEVEL = 12

--- The first invented encounter id and keystone map id.
E.ENCOUNTER_BASE = 99000
E.MAP_BASE = 9900

-- Invented boss names, used in turn.
local BOSSES = {
    "Warden Ashvane", "The Hollow Choir", "Grimtusk the Unbowed", "Matron Seyla", "Korvath, Iron Tide",
    "The Gilded Engine", "Thessaly Duskborn", "Vorruk and Mag",
}
E.BOSSES = BOSSES

-- ── the loot lines (pure) ───────────────────────────────────────────────────────────────────

local KIND_PART = { loot = "", bonus = "_BONUS_ROLL", pushed = "_PUSHED" }

--- The GlobalString a line of this shape is written from: LOOT_ITEM, then _BONUS_ROLL or
--- _PUSHED, then _SELF, then _MULTIPLE.
--- @param kind string `loot`, `bonus` or `pushed`
--- @param isSelf boolean
--- @param multiple boolean
--- @return string
function E.GlobalFor(kind, isSelf, multiple)
    return "LOOT_ITEM" .. (KIND_PART[kind] or "") .. (isSelf and "_SELF" or "") .. (multiple and "_MULTIPLE" or "")
end

--- A printf-style GlobalString filled with `args` in printf order; a positional marker (`%2$s`)
--- takes its own argument, as a locale that reorders them does.
--- @param fmt string
--- @param args table
--- @return string
function E.Render(fmt, args)
    local i = 0
    return (fmt:gsub("%%(%d*)%$?([sd%%])", function(n, c)
        if c == "%" then return "%" end
        if n ~= "" then return tostring(args[tonumber(n)]) end
        i = i + 1
        return tostring(args[i])
    end))
end

--- One CHAT_MSG_LOOT line, or nil when the GlobalString is missing. `G` reads the GlobalStrings:
--- a reader `G(name)` (NS.Compat.GlobalString, so the seam covers it) or a table of them.
--- @param G function|table
--- @param kind string
--- @param isSelf boolean
--- @param name string|nil the looter as chat names them (ignored for your own line)
--- @param link string
--- @param qty number|nil
--- @return string|nil
function E.WriteLine(G, kind, isSelf, name, link, qty)
    local multiple = (tonumber(qty) or 1) > 1
    local key = E.GlobalFor(kind, isSelf, multiple)
    local fmt
    if type(G) == "function" then fmt = G(key) else fmt = G[key] end
    if type(fmt) ~= "string" or fmt == "" then return nil end
    local args = isSelf and { link } or { name, link }
    if multiple then args[#args + 1] = qty end
    return E.Render(fmt, args)
end

--- How chat names a member: bare on your own realm, Name-Realm from another.
--- @param m table
--- @param ownRealm string|nil
--- @return string
function E.ChatName(m, ownRealm)
    if m.realm == ownRealm then return m.name end
    return m.fullName
end

-- The looter of one line: `me` (nil), a named member, or a random one with you among them.
local function pickLooter(members, who, rnd)
    if who == "me" then return nil end
    if type(who) == "table" then return who end
    local i = rnd(#members + 1)
    return members[i]
end

local function crossRealm(members, ownRealm)
    for _, m in ipairs(members) do
        if m.realm ~= ownRealm then return m end
    end
    return nil
end

-- The last line a cross-realm looter may take: never your only line in the burst.
local function lastSpare(plan)
    local mine = 0
    for _, line in ipairs(plan) do
        if line.looter == nil then mine = mine + 1 end
    end
    for i = #plan, 1, -1 do
        if plan[i].looter ~= nil or mine > 1 then return i end
    end
    return nil
end

-- A random burst gives its last spare line to a looter from another realm when none has one yet.
local function ensureCrossRealm(plan, members, ownRealm)
    if #plan < 2 then return end
    for _, line in ipairs(plan) do
        if line.looter and line.looter.realm ~= ownRealm then return end
    end
    local m, i = crossRealm(members, ownRealm), lastSpare(plan)
    if m and i then plan[i].looter = m end
end

-- A random burst of two or more lines gives you its first line when none is yours, so every
-- such burst lists a drop of yours on Drops beside the others' (sim feedback §0).
local function ensureMine(plan)
    if #plan < 2 then return end
    for _, line in ipairs(plan) do
        if line.looter == nil then return end
    end
    plan[1].looter = nil
end

-- A random burst of two or more lines gives a member its last line when every line is yours, so
-- Drops has another player's drop too.
local function ensureTheirs(plan, members, rnd)
    if #plan < 2 or #members == 0 then return end
    for _, line in ipairs(plan) do
        if line.looter ~= nil then return end
    end
    plan[#plan].looter = members[rnd(#members)]
end

-- A random burst's members always get one plain loot line: a bonus roll is never tradeable, so a
-- burst of bonus rolls alone would leave nothing spare for the window's Interesting view.
local function ensurePlainLoot(plan)
    local first
    for _, line in ipairs(plan) do
        if line.looter ~= nil then
            if line.kind == "loot" then return end
            first = first or line
        end
    end
    if first then first.kind = "loot" end
end

--- A burst of loot lines (pure): `n` lines (1 to 3 at random when nil), each { looter (a member,
--- or nil for you), entry (a pool drop), qty, kind }. `who` is `me`, a member, or nil for random
--- looters; about one line in eight is a multiple and one in six a bonus roll. A random burst of
--- two or more has a line of yours, a member's and, when the group has one, a looter from
--- another realm; its members' lines are never all bonus rolls.
--- @param n number|nil
--- @param members table
--- @param drops table pool entries with a link
--- @param rnd function a random source (NS.SimRoster.Random)
--- @param who any
--- @param ownRealm string|nil
--- @return table plan
function E.Plan(n, members, drops, rnd, who, ownRealm)
    local plan = {}
    if #drops == 0 then return plan end
    n = tonumber(n) or rnd(1, 3)
    for i = 1, math.max(0, math.floor(n)) do
        plan[i] = {
            looter = pickLooter(members, who, rnd), entry = drops[rnd(#drops)],
            qty = rnd(8) == 1 and 2 or 1, kind = rnd(6) == 1 and "bonus" or "loot",
        }
    end
    if who == nil then
        ensureMine(plan)
        ensureTheirs(plan, members, rnd)
        ensureCrossRealm(plan, members, ownRealm)
        ensurePlainLoot(plan)
    end
    return plan
end

-- ── the session's state ─────────────────────────────────────────────────────────────────────

local function drive()
    local s = Sim.Session()
    if not s then return nil end
    local d = s.drive
    if not d then
        d = { lines = 0, pulls = 0, kills = 0, trades = 0, combat = false,
            trade = { window = E.TRADE_WINDOW, soon = E.ENDING_SOON, soonLeft = E.ENDING_SOON_COUNT } }
        s.drive = d
    end
    return d
end

--- Set the scenario's own-drop trade windows: { window, endingSoon, endingSoonCount } (seconds;
--- an ending-soon count of 0 has none). False when no simulation runs.
--- @param opts table
--- @return boolean
function E.Configure(opts)
    local d = drive()
    if not d or type(opts) ~= "table" then return false end
    local t = d.trade
    t.window = tonumber(opts.window) or t.window
    t.soon = tonumber(opts.endingSoon) or t.soon
    t.soonLeft = tonumber(opts.endingSoonCount) or t.soonLeft
    return true
end

--- The drivers at a glance: { lines, pulls, kills, trades, combat, encounter, run }; nil when
--- no simulation runs.
--- @return table|nil
function E.Status()
    local d = Sim.Session() and drive()
    if not d then return nil end
    return { lines = d.lines, pulls = d.pulls, kills = d.kills, trades = d.trades, combat = d.combat,
        encounter = d.encounter, run = d.run }
end

--- The keystone run in progress (or ended, until the next starts), or nil.
--- @return table|nil { mapID, name, level, ended }
function E.Run()
    local d = Sim.Session() and drive()
    return d and d.run
end

-- ── the group ───────────────────────────────────────────────────────────────────────────────

--- The simulated group forms where the scenario is: GROUP_ROSTER_UPDATE, then
--- PLAYER_ENTERING_WORLD (isInitialLogin, isReloadingUi false), so the roster, the situation, the
--- inspect warm-up and every other reader of those events see it. Answers how many handlers ran.
--- @return number
function E.Join()
    if not drive() then return 0 end
    return Sim.Fire("GROUP_ROSTER_UPDATE") + Sim.Fire("PLAYER_ENTERING_WORLD", false, false)
end

-- ── combat and the encounters ───────────────────────────────────────────────────────────────

--- The combat edge: PLAYER_REGEN_DISABLED (on) or PLAYER_REGEN_ENABLED (off), with the Combat
--- restriction. Answers whether it moved.
--- @param on boolean
--- @return boolean
function E.Combat(on)
    local d = drive()
    on = on == true
    if not d or d.combat == on then return false end
    d.combat = on
    Sim.Fire(on and "PLAYER_REGEN_DISABLED" or "PLAYER_REGEN_ENABLED")
    Sim.SetRestriction("Combat", on)
    return true
end

local function encounterArgs(enc)
    local place = NS.SimWorld.Place()
    return enc.id, enc.name, place and place.difficulty or 0, NS.Compat.GroupSize()
end

--- A boss pull: ENCOUNTER_START, combat and the Encounter restriction. `opts` = { id, name }
--- (invented when absent). Answers the encounter, or nil and `engaged` / `notRunning`.
--- @param opts table|nil
--- @return table|nil encounter, string|nil why
function E.Pull(opts)
    local d = drive()
    if not d then return nil, "notRunning" end
    if d.encounter then return nil, "engaged" end
    opts = type(opts) == "table" and opts or {}
    d.pulls = d.pulls + 1
    local enc = { id = tonumber(opts.id) or (E.ENCOUNTER_BASE + d.pulls),
        name = opts.name or BOSSES[(d.pulls - 1) % #BOSSES + 1] }
    d.encounter = enc
    Sim.Fire("ENCOUNTER_START", encounterArgs(enc))
    E.Combat(true)
    Sim.SetRestriction("Encounter", true)
    return enc
end

--- The encounter's end: ENCOUNTER_END (a kill unless `success` is false), then the combat edge,
--- then the Encounter restriction lifted. Answers the encounter, or nil and `notEngaged`.
--- @param success boolean|nil
--- @return table|nil encounter, string|nil why
function E.Kill(success)
    local d = drive()
    local enc = d and d.encounter
    if not enc then return nil, "notEngaged" end
    local kill = success ~= false
    d.encounter = nil
    if kill then d.kills = d.kills + 1 end
    local id, name, difficulty, size = encounterArgs(enc)
    Sim.Fire("ENCOUNTER_END", id, name, difficulty, size, kill and 1 or 0)
    E.Combat(false)
    Sim.SetRestriction("Encounter", false)
    return enc
end

--- A keystone run starts: CHALLENGE_MODE_START(mapID) and the ChallengeMode restriction. Answers
--- the run, or nil and why (`notRunning`, `inRun`).
--- @return table|nil run, string|nil why
function E.RunStart()
    local d = drive()
    if not d then return nil, "notRunning" end
    if d.run and not d.run.ended then return nil, "inRun" end
    local place = NS.SimWorld.Place()
    local run = { mapID = E.MAP_BASE + d.pulls, name = place and place.name or L["Simulated instance"],
        level = E.KEY_LEVEL }
    d.run = run
    Sim.Fire("CHALLENGE_MODE_START", run.mapID)
    Sim.SetRestriction("ChallengeMode", true)
    return run
end

--- The run completes: CHALLENGE_MODE_COMPLETED, then the ChallengeMode restriction lifted.
--- Answers the run, or nil and `noRun`.
--- @return table|nil run, string|nil why
function E.RunEnd()
    local d = drive()
    local run = d and d.run
    if not run or run.ended then return nil, "noRun" end
    run.ended = true
    Sim.Fire("CHALLENGE_MODE_COMPLETED")
    Sim.SetRestriction("ChallengeMode", false)
    return run
end

-- ── loot ────────────────────────────────────────────────────────────────────────────────────

-- The trade window of your next own drop: the ending-soon one while any are left.
local function nextWindow(d)
    local t = d.trade
    if t.soonLeft > 0 then
        t.soonLeft = t.soonLeft - 1
        return t.soon
    end
    return t.window
end

-- One line delivered: your own drop goes to your bags first.
local function deliverLine(d, line, me, ownRealm)
    local link, m = line.entry.link, line.looter
    local name, guid = me.name, me.guid
    if m then name, guid = E.ChatName(m, ownRealm), m.guid end
    local text = E.WriteLine(NS.Compat.GlobalString, line.kind, m == nil, name, link, line.qty)
    if not text then return false end
    if not m then NS.SimWorld.AddBagItem(link, nextWindow(d)) end
    d.lines = d.lines + 1
    local full = m and m.fullName or me.name
    Sim.Fire("CHAT_MSG_LOOT", text, full, "", "", name, "", 0, 0, "", 0, d.lines, guid)
    return true
end

-- You, as the loot line names you.
local function player()
    local Compat = NS.Compat
    return { name = Compat.UnitName("player"), guid = Compat.UnitGUID("player") }
end

-- `who` resolved: `me`, a member (by GUID or name), or nil for random looters.
local function looterOf(who)
    if who == nil or who == "me" then return who end
    local member = NS.Roster.Resolve(who)
    return member and NS.SimWorld.Member(member.guid) or false
end

--- Loot now (spec §4's `/dw sim loot [n] [player|me]`): `n` lines (1 to 3 when nil) from the pool's
--- drops, by `who` (`me`, a member's name, or random). Answers how many lines went out, or 0 and
--- why: `notRunning`, `noPool`, `noLooter`.
--- @param n number|nil
--- @param who string|nil
--- @return number, string|nil
function E.Loot(n, who)
    local d, s = drive(), Sim.Session()
    if not d then return 0, "notRunning" end
    local drops = NS.SimPool.Drops(s.pool)
    if #drops == 0 then return 0, "noPool" end
    local looter = looterOf(who)
    if looter == false then return 0, "noLooter" end
    local ownRealm = NS.Compat.NormalizedRealm()
    local plan = E.Plan(n, s.members or {}, drops, NS.SimWorld.Random(), looter, ownRealm)
    local me, sent, mine = player(), 0, false
    for _, line in ipairs(plan) do
        if deliverLine(d, line, me, ownRealm) then sent = sent + 1 end
        mine = mine or line.looter == nil
    end
    if mine then Sim.Fire("BAG_UPDATE_DELAYED") end
    NS.Debug(TAG, "loot: %d lines", sent)
    return sent
end

-- ── a completed trade ───────────────────────────────────────────────────────────────────────

-- Who the trade is with and what moves: your drop to the first member, else from its looter.
local function tradeOf(rec)
    if rec.isMine then
        local item = NS.SimWorld.BagItemFor(rec.link)
        if not item then return nil, "notInBags" end
        if not (item.expiresAt and item.expiresAt > GetTime()) then return nil, "expired" end
        local m = (Sim.Session().members or {})[1]
        if not m then return nil, "noPartner" end
        return { partner = m.fullName, given = { rec.link }, received = {}, item = item }
    end
    local m = rec.looter and NS.SimWorld.Member(rec.looter.guid)
    if not m then return nil, "noPartner" end
    return { partner = m.fullName, given = {}, received = { rec.link } }
end

--- A simulated completed trade for drop `dropID` (spec §4's `/dw sim trade`): your own drop is
--- given to a member, anyone else's received from its looter, through the trade events the
--- history reads. Answers true, or false and why: `notRunning`, `noDrop`, `notSim`, `notInBags`,
--- `expired`, `noPartner`.
--- @param dropID any
--- @return boolean, string|nil
function E.Trade(dropID)
    local d = drive()
    if not d then return false, "notRunning" end
    local rec = NS.LootFeed.Get(tonumber(dropID) or dropID)
    if not rec then return false, "noDrop" end
    if not rec.sim then return false, "notSim" end
    local t, why = tradeOf(rec)
    if not t then return false, why end
    local W = NS.SimWorld
    W.SetTrade(t)
    Sim.Fire("TRADE_SHOW")
    Sim.Fire(rec.isMine and "TRADE_PLAYER_ITEM_CHANGED" or "TRADE_TARGET_ITEM_CHANGED", 1)
    Sim.Fire("TRADE_ACCEPT_UPDATE", 1, 1)
    Sim.Fire("TRADE_CLOSED")
    Sim.Fire("UI_INFO_MESSAGE", W.TRADE_COMPLETE, L["Trade complete."])
    W.SetTrade(nil)
    d.trades = d.trades + 1
    if t.item and W.RemoveBagItem(t.item.guid) then Sim.Fire("BAG_UPDATE_DELAYED") end
    return true
end

-- ── the combat answers ──────────────────────────────────────────────────────────────────────

-- The seam's providers for the client's combat flags, keyed by their NS.Compat member names
-- (written as fields, so test_compat's seam-only scan never mistakes a key for a client call): the
-- simulated combat edge reads as fighting. Out of it the client answers, so real combat is never
-- hidden from a caller that must not act in it.
local PROVIDERS = {}

local function simCombat()
    local s = Sim.Session()
    return s ~= nil and s.drive ~= nil and s.drive.combat == true
end

function PROVIDERS.InCombatLockdown(live)
    return simCombat() or live()
end

function PROVIDERS.PlayerInCombat(live)
    return simCombat() or live()
end

for key, fn in pairs(PROVIDERS) do Sim.SetProvider(key, fn) end

-- ── the stop ────────────────────────────────────────────────────────────────────────────────

Sim.AddCleanup(function(s)
    local d, w = s.drive, s.world
    if d and d.combat and not NS.Compat.InCombatLockdown() then Sim.DeliverForCleanup("PLAYER_REGEN_ENABLED") end
    if w and #w.bag > 0 then Sim.DeliverForCleanup("BAG_UPDATE_DELAYED") end
end)
