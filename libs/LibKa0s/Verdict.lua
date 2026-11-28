-- LibKa0s-Verdict-1.0 -- "what is this item to me": the upgrade verdict engine. This file is the
-- shell: the major, its MODULES registry and the instance constructor. The pure kernel is in the
-- secondary files loaded after it, each paired on this file's minor:
--
--   VerdictConstants.lua  the item, slot and quality numbers the kernel reads (lib.C)
--   VerdictClassData.lua  the class lists, one per client (lib.ClassData)
--   VerdictTierTokens.lua tier tokens judged as gear (lib.TierTokens)
--   VerdictEvaluate.lua   the kernel and the off-spec pass (lib.Evaluate, lib.Equippability,
--                         lib.ItemVerdict, lib.TrackDelta, lib.SubClassKey, lib.OffSpec)
--   VerdictReads.lua      the client reads an instance makes (lib.Reads)
--   VerdictCollect.lua    the category and the collection verdict (lib.Collect; v:ReadCollect)
--   VerdictFacts.lua      an item link's facts, cached per instance (lib.ItemRead; v:Facts, v:Request)
--   VerdictScore.lua      the scorers (lib.Score; v:Scorer, v:ScoreFor)
--   VerdictGear.lua       your gear snapshot and candidate, and the judge (v:Snapshot, v:Judge)
--   VerdictSettings.lua   the Comparison section a host drops into its panel, its six rows,
--                         defaults and two editors (lib.Settings)
--
-- == WHY THIS EXISTS ===========================================================================
--
-- Ka0s Drop Watcher grew a verdict engine for its loot feed: is a drop an upgrade, a sidegrade, a
-- downgrade, or something you cannot use, for you or for another member of your group. Its Item
-- Search then judged every item it showed with the same engine, and Item Search leaves Drop Watcher
-- to become Ka0s Item Search (DropWatcher#19). Both addons need the same answer for the same item,
-- so the engine is promoted here, once, on the owner's ruling (R4 of Drop Watcher's
-- docs/superpowers/specs/2026-11-27-itemsearch-split-design.md), rather than copied into the second
-- addon. The code is Drop Watcher's, moved: modules/Evaluate.lua, modules/OffSpec.lua,
-- modules/TierTokens.lua, core/ClassData.lua, core/ClassDataForever.lua, the tier token parts of
-- core/TextParse.lua and the subset of core/Constants.lua they read, pinned on both sides by the
-- same golden table (tests/fixtures/verdict_golden.lua).
--
-- == THE CLIENT IS THE CALLER'S ================================================================
--
-- Drop Watcher picked its class list, slot plans and off-spec gate once, at file load, from the
-- client it runs on. A library shared through LibStub cannot: the client is named per call.
-- `opts.client` ("retail" | "forever") picks the class list, the ranged slot plans and the off-spec
-- gate of an evaluation; left out, the class list and the slot plans are Retail's and the off-spec
-- pass does not run (no client named, no off-spec). The verdict mode stays the caller's
-- (`opts.verdictMode`). Nothing here reads the client it runs on, so a suite judges both clients'
-- lists on one profile.
--
-- == THE INSTANCE ==============================================================================
--
-- `Verdict:New(host)` answers an instance bound to one host, and every instance keeps its own state
-- (its facts cache, its gear snapshot, its timers), so two addons that each made one never share a
-- verdict, a cache or a timer even when LibStub hands them the same major. The host:
--
--   host = { client = "retail" | "forever",            -- picks the class list, slots and gates
--            config = function() -> vcfg,               -- the verdict's settings, read per judge:
--                     { sidegradeBand, compareOwned, undesired, heirloomProtect, scorer, weights,
--                       verdictMode }   (verdictMode nil: the client's, VerdictModeFor)
--            L = table,                                 -- the host's locale (TierTokens.WORDS keys)
--            reads = { [member] = fn } | nil,           -- per-read overrides of lib.Reads
--            debug = function(tag, msg) | nil,
--            perf = { on, Note(key, ms) } | nil,
--            deferWhile = function() -> boolean | nil,  -- hold bag events (Drop Watcher: combat)
--            registerEvent = function(event, handler), unregisterEvent = function(event),
--            onChange = function(kind, ...) }           -- "gear" | "collection" | "score" | "item"
--
-- THE READS. `v.R` is the instance's read table: `R.<member>(...)` calls `host.reads[member]` when
-- the host gave one, else `lib.Reads[member]`, looked up at every call (VerdictReads.lua's header).
-- So a host names only the reads it must answer itself (Drop Watcher: PlayerRole, from its role
-- store) and the library answers the rest. Since minor 3 (LibKa0s#111) every read is a real
-- function member of `v.R`, a forwarder built at New for each name in lib.Reads and in a plain
-- host.reads table, so a host's simulator wraps the instance's reads in place, as it wraps its own
-- Compat table: `Sim:Cover(seam, v.R, opts)` (LibKa0s-Sim-1.0 minor 6) puts them under the seam's
-- providers and guards with no host copy of a read. A name a newer minor adds after New still
-- resolves, through the table's __index, outside any seam until the next reload. A forwarder is
-- never the host's or the library's function itself (no rawequal); its answers are theirs.
--
-- THE LIFECYCLE. An instance answers from the moment it is made, reading lazily. Its events are
-- registered by `v:StandUp()` (through host.registerEvent, one handler per event) and dropped by
-- `v:StandDown()`, which also cancels every timer and drops every cache: while stood down nothing
-- arms and `onChange` never fires. `v:StandUp()` reads your gear at once and announces it
-- (onChange("gear")); `v:StandUp{ lazy = true }` keeps the handlers and reads nothing, so the first
-- `Judge` or gear ask reads your gear, quietly, as an instance never stood up does (LibKa0s#108).
-- The secondary files add their state lazily, their events to lib.__events and their stand-down
-- and stand-up steps to lib.__lifecycle, so an instance built before a file loads still gets what
-- it adds.
--
-- == DEPENDENCIES ==============================================================================
--
-- LibStub and LibKa0s-Core-1.0 minor 1 or newer, for the same reason Glow and Charts gate on it: a
-- partial payload gets every module absent rather than a working half. Nothing here is a protected
-- call, so it works in combat.

local core = LibStub and LibStub("LibKa0s-Core-1.0", true)
local NEEDS_CORE = 1
if not core or (core.MINOR or 0) < NEEDS_CORE then return end   -- no NewLibrary; module absent

-- Minor 1 (DropWatcher#19, task B1 of Drop Watcher's
-- docs/superpowers/plans/2026-11-27-itemsearch-split.md): the shell and the pure kernel.
-- Minor 2 (LibKa0s#108): StandUp(opts), `opts.lazy` handed to each stand-up step.
-- Minor 3 (LibKa0s#111): v.R holds a forwarder per read, so a seam can wrap the instance's reads.
local MAJOR, MINOR = "LibKa0s-Verdict-1.0", 3
local lib = LibStub:NewLibrary(MAJOR, MINOR)
if not lib then return end

lib.MAJOR, lib.MINOR = MAJOR, MINOR

lib.MODULES = lib.MODULES or {}
lib.MODULES.Verdict = MINOR

--- The clients an instance may name.
lib.CLIENTS = { retail = true, forever = true }

-- The instance methods, shared by every instance. The instance API's files add to this table, so
-- an instance built before they load still answers what they add.
lib.__methods = lib.__methods or {}
local methods = lib.__methods
local instanceMeta = { __index = methods }

-- What the secondary files hang on the shell: their events (`[key] = { event, clients, fn }`,
-- fn(v, event, ...)) and their lifecycle steps (`[key] = { down = fn(v), up = fn(v, opts), order }`,
-- `opts` the stand-up's: `{ lazy = boolean }`).
lib.__events = lib.__events or {}
lib.__lifecycle = lib.__lifecycle or {}

-- Which secondary file ran last at which generation (`[order] = generation`; each file's ORDER is
-- its place in LibKa0s.xml, spaced by ten). A secondary's minor gates it alone, but the files after
-- it capture what it builds (lib.C, lib.ClassData) at their load: so when one runs, every file after
-- it in load order runs again on what it built, even at a minor already loaded. Without that, a
-- release that bumps VerdictConstants alone, loaded after an older copy, left the older copy's
-- kernel judging on the constants it captured, and which set a verdict read hung on load order.
lib.__ranAt = lib.__ranAt or {}
lib.__generation = lib.__generation or 0

--- Whether the secondary at `order` must run again: a file before it in load order ran after it did.
--- @param order number
--- @return boolean
function lib.__Stale(order)
  local mine = lib.__ranAt[order] or 0
  for o, g in pairs(lib.__ranAt) do
    if o < order and g > mine then return true end
  end
  return false
end

--- Record that the secondary at `order` ran.
--- @param order number
function lib.__Ran(order)
  lib.__generation = lib.__generation + 1
  lib.__ranAt[order] = lib.__generation
end

-- The read `name` of one host now: host.reads' member, else lib.Reads'.
local function resolveRead(host, name)
  local own = type(host.reads) == "table" and host.reads[name] or nil
  if own ~= nil then return own end
  return lib.Reads and lib.Reads[name]
end

-- One read's forwarder: the host's or the library's member, resolved at each call; a read that
-- resolves to nothing answers nothing.
local function forwarder(host, name)
  return function(...)
    local fn = resolveRead(host, name)
    if fn then return fn(...) end
  end
end

-- The read table of one host: a forwarder for each function lib.Reads and a plain host.reads
-- carry now, and any other name resolved at each access (a read a later minor adds).
local function readsFor(host)
  local R = setmetatable({}, { __index = function(_, name) return resolveRead(host, name) end })
  local sources = { lib.Reads }
  if type(host.reads) == "table" then sources[2] = host.reads end
  for _, source in ipairs(sources) do
    for name, fn in pairs(source) do
      if type(fn) == "function" and rawget(R, name) == nil then rawset(R, name, forwarder(host, name)) end
    end
  end
  return R
end

--- An instance bound to `host` (see the header). Raises on a host that is not a table or names no
--- known client: a host that cannot say which client it judges for has no verdict to give.
--- @param host table { client = "retail" | "forever", ... }
--- @return table
function lib:New(host)
  if type(host) ~= "table" then error(MAJOR .. ": New(host) needs a host table", 2) end
  if not lib.CLIENTS[host.client] then
    error(MAJOR .. ": host.client must be \"retail\" or \"forever\", got " .. tostring(host.client), 2)
  end
  return setmetatable({ host = host, client = host.client, R = readsFor(host), down = false }, instanceMeta)
end

--- The verdict mode a client judges in when its host's config names none: "scoreFirst" on WoW
--- Forever (the score decides), "ilvlFirst" anywhere else (Drop Watcher's LF.VERDICT_MODE).
--- @param client string|nil
--- @return string
function lib.VerdictModeFor(client)
  return client == "forever" and "scoreFirst" or "ilvlFirst"
end

--- The instance's client ("retail" | "forever").
--- @return string
function methods:Client() return self.client end

--- The class list of the instance's client (lib.ClassData.ForClient).
--- @return table
function methods:ClassData() return lib.ClassData.ForClient(self.client) end

--- The host's verdict config now (host.config()), a fresh table: a key the host leaves out (or
--- every key, with no config) reads lib.Settings.DEFAULTS' value, a map as a fresh copy, and the
--- verdict mode is the client's when the host names none. A host with no config judges on the
--- defaults, heirloom protection on.
--- @return table
function methods:Config()
  local cfg = type(self.host.config) == "function" and self.host.config() or nil
  local out = {}
  for k, v in pairs(type(cfg) == "table" and cfg or {}) do out[k] = v end
  local St, defaults = lib.Settings, nil
  for _, key in ipairs(St and St.KEYS or {}) do
    if out[key] == nil then
      defaults = defaults or St.Defaults()
      out[key] = defaults[key]
    end
  end
  if out.verdictMode == nil then out.verdictMode = lib.VerdictModeFor(self.client) end
  return out
end

--- Hand the host a debug line, `fmt` formatted with the rest (host.debug; nothing without one).
function methods:Debug(tag, fmt, ...)
  local fn = self.host.debug
  if type(fn) == "function" then fn(tag, select("#", ...) > 0 and fmt:format(...) or fmt) end
end

--- The same line once per `key` for the instance's life (an unknown stat weight, say).
function methods:DebugOnce(key, tag, fmt, ...)
  self.__once = self.__once or {}
  if self.__once[key] then return end
  self.__once[key] = true
  self:Debug(tag, fmt, ...)
end

--- A start stamp for a perf note, or nil while the host's perf capture is off.
function methods:PerfStart()
  local p = self.host.perf
  if type(p) == "table" and p.on and type(p.Note) == "function" and debugprofilestop then
    return debugprofilestop()
  end
  return nil
end

--- Note `key`'s time since `t0` (PerfStart's), when there is one.
function methods:PerfNote(key, t0)
  if t0 then self.host.perf.Note(key, debugprofilestop() - t0) end
end

--- Tell the host something it judged may answer otherwise now: `kind` is "gear" (your snapshot
--- moved), "collection" (a collection was learned), "score" (a pending score answered) or "item"
--- (an item asked for has loaded, its link second). Never while stood down.
function methods:Changed(kind, ...)
  if self.down then return end
  local fn = self.host.onChange
  if type(fn) == "function" then fn(kind, ...) end
end

--- Whether the instance is stood down.
--- @return boolean
function methods:IsStoodDown() return self.down == true end

-- Each lifecycle step in its declared order.
local function steps()
  local out = {}
  for key, step in pairs(lib.__lifecycle) do out[#out + 1] = { key = key, step = step } end
  table.sort(out, function(a, b)
    local x, y = a.step.order or 50, b.step.order or 50
    if x ~= y then return x < y end
    return a.key < b.key
  end)
  return out
end

-- The events this instance's client listens to, each with its handlers in key order.
local function eventsFor(client)
  local byEvent, keys = {}, {}
  for key in pairs(lib.__events) do keys[#keys + 1] = key end
  table.sort(keys)
  for _, key in ipairs(keys) do
    local e = lib.__events[key]
    local serves = e.clients == nil
    for _, c in ipairs(e.clients or {}) do serves = serves or c == client end
    if serves then
      byEvent[e.event] = byEvent[e.event] or {}
      table.insert(byEvent[e.event], e.fn)
    end
  end
  return byEvent
end

--- The events an instance of `client` listens to, sorted, a fresh array: the set `StandUp` hands to
--- host.registerEvent, for a host that registers it ahead of the instance (its SafeRegisterEvents
--- rows), so an event a later minor adds reaches it with no edit.
--- @param client string "retail" | "forever"
--- @return table event names
function lib.EventsFor(client)
  local out = {}
  for event in pairs(eventsFor(client)) do out[#out + 1] = event end
  table.sort(out)
  return out
end

--- The instance's events (lib.EventsFor of its client).
--- @return table event names
function methods:Events() return lib.EventsFor(self.client) end

--- Register the instance's events through the host and run every stand-up step (the gear snapshot
--- is read again and announced). Safe to call twice. Each registration is protected on its own
--- (events-frames-taint-§1): one the host refuses costs that event, with a debug line, not the rest
--- of the block or the stand-up. With `opts.lazy` the steps read nothing: the gear snapshot is read
--- by the first Judge or gear ask, quietly (no onChange("gear") for that read), and a snapshot the
--- instance still holds is kept. Anything but a table with `lazy = true` stands up as with no
--- argument.
--- @param opts table|nil { lazy = boolean }
function methods:StandUp(opts)
  local step = { lazy = type(opts) == "table" and opts.lazy == true }
  self.down = false
  local host = self.host
  if not self.__registered and type(host.registerEvent) == "function" then
    self.__registered = {}
    for event, fns in pairs(eventsFor(self.client)) do
      local ok, err = pcall(host.registerEvent, event, function(_, ...)
        if self.down then return end
        for _, fn in ipairs(fns) do fn(self, event, ...) end
      end)
      if ok then
        self.__registered[#self.__registered + 1] = event
      else
        self:Debug("VERDICT", "StandUp: the host refused %s: %s", event, tostring(err))
      end
    end
  end
  for _, s in ipairs(steps()) do
    if s.step.up then s.step.up(self, step) end
  end
end

--- Drop the instance's events, cancel its timers and drop its caches: nothing arms and onChange
--- never fires until StandUp.
function methods:StandDown()
  self.down = true
  local host = self.host
  if self.__registered and type(host.unregisterEvent) == "function" then
    for _, event in ipairs(self.__registered) do host.unregisterEvent(event) end
  end
  self.__registered = nil
  for _, s in ipairs(steps()) do
    if s.step.down then s.step.down(self) end
  end
end
