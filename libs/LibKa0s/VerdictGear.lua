-- LibKa0s-Verdict-1.0 -- your own gear snapshot and the candidate the kernel takes for you, per
-- instance, and the judge that puts them together (v:Judge, v:JudgeFacts). Moved from Ka0s Drop
-- Watcher's modules/Gear.lua (all of it but `Qualities`, the feed's gate input, which stays in Drop
-- Watcher) and the verdict half of its modules/LootFeed.lua's judgeMe (DropWatcher#19).
--
--   snapshot = { equipped = { [slot] = entry | false },   -- false = empty; absent = still loading
--                owned    = { [slot] = entry },           -- the best you own per slot, worn or not
--                pool     = { entry, ... },               -- every gear item read, worn and in bags
--                bySpec   = { [specID] = gear },          -- OffSpecGear's memo
--                classFile, specID, tree, level, dualWield, titanGrip,
--                loading  = n,                            -- links still loading
--                signature }
--
-- An entry is a copy of the item's facts (v:Facts) with `ilvl` set to the CURRENT level and `slot`
-- (worn) or `bag`/`bagSlot` (in a bag) added. A worn item's current level is its tooltip's
-- ItemLevel line, else the link's effective level. The copies are the snapshot's own.
--
-- THE SLOTS AND PLANS are the instance's client's (C.SlotsFor, C.SlotPlanFor): on WoW Forever a
-- ranged or thrown weapon, a wand or a relic fills slot 18.
--
-- THE CANDIDATE. v:Candidate() answers you: classFile, specID (class-wide on WoW Forever), tree
-- (your top talent tree on WoW Forever; nil on Retail, and on a tie or with no points), level, the
-- two hand flags (the client's class list, for that spec or tree, else for the class when every spec
-- agrees), `gear` = equipped, `owned`, isPlayer, and on a client the off-spec pass serves
-- `offSpecGear` (v:OffSpecGear). The judge adds the host's undesired list as `prefs`.
--
-- OWNED. A bag item is first read for its equip location (no item cache needed), and only one with
-- a slot plan is asked of the facts. Every worn item and every bag item you can equip is placed by
-- its slot plan, filled in slot id order with the highest-level item that fits and is not already
-- placed: a per-slot best, not a loadout planner.
--
-- THE EDGE AND THE THROTTLE. PLAYER_EQUIPMENT_CHANGED, BAG_UPDATE_DELAYED and a spec change (Retail:
-- the player's PLAYER_SPECIALIZATION_CHANGED; WoW Forever: TRAIT_CONFIG_UPDATED,
-- CHARACTER_POINTS_CHANGED, and PLAYER_LEVEL_UP for the armor by level) arm one THROTTLE-second
-- timer; the events inside it share one rebuild. A link not cached is requested, and its load arms
-- the same timer. A rebuild whose signature moved tells the host onChange("gear"). The first read,
-- lazily from a caller, announces nothing. While the host's deferWhile() holds, a BAG_UPDATE_DELAYED
-- arms nothing and the next PLAYER_REGEN_ENABLED rebuilds (Drop Watcher's is combat). Stood down,
-- the timer is canceled and the snapshot dropped; the stand-up rebuilds it and announces the read,
-- and a lazy stand-up (StandUp{ lazy = true }, LibKa0s#108) reads nothing, so the first ask reads it,
-- quietly. A gear event before that ask rebuilds and announces, as ever: its snapshot is the real
-- one.
--
-- THE JUDGE. v:JudgeFacts(facts, opts) is the collection verdict first (lib.Collect.Verdict, nil
-- for gear and a tier token), else the kernel for your candidate (or `opts.candidate`) on the
-- host's config: the sidegrade band, compareOwned, the scorer (v:Scorer), the verdict mode and, for
-- you alone, heirloomProtect. v:Judge(link) reads the facts first and answers `me, pending`:
-- pending while the item loads (it is asked for, and onChange("item", link) fires when it arrives)
-- or while the score is pending (the link is retried every SCORE_RETRY seconds, SCORE_TRIES times,
-- and onChange("score", link) fires when one answers).
--
-- Depends on the Verdict shell (Verdict.lua), VerdictConstants.lua, VerdictClassData.lua and
-- VerdictEvaluate.lua; the facts, the collection verdict and the scorer are read at call time.

local lib = LibStub and LibStub("LibKa0s-Verdict-1.0", true)
if not lib or not lib.C or not lib.Evaluate then return end

local GEAR_MINOR = 2
local ORDER = 90   -- its place in LibKa0s.xml (Verdict.lua, lib.__Stale)
-- Minor 1 (DropWatcher#19, task B2): Drop Watcher's gear snapshot and the verdict half of its
-- judge, per instance.
-- Minor 2 (LibKa0s#108): the stand-up step reads nothing on a lazy stand-up (shell minor 2's
-- StandUp{ lazy = true }), leaving the first read to the first ask.
if lib.__gearMinor and lib.__gearMinor >= GEAR_MINOR
  and lib.__gearShellMinor == lib.MINOR and not lib.__Stale(ORDER) then return end
lib.__gearMinor      = GEAR_MINOR
lib.__gearShellMinor = lib.MINOR
lib.__Ran(ORDER)

lib.MODULES = lib.MODULES or {}
lib.MODULES.VerdictGear = GEAR_MINOR

local C = lib.C
local methods = lib.__methods

local G = {}
lib.Gear = G
G.THROTTLE = 0.5
G.SCORE_RETRY = 1
G.SCORE_TRIES = 5

local TAG = "GEAR"

-- Every slot id of a client, ascending: the order the owned slots are filled in.
local slotLists = {}
local function slotsOf(client)
  local key = client == "forever" and "forever" or "retail"
  if not slotLists[key] then
    local list = {}
    for _, id in pairs(C.SlotsFor(key)) do list[#list + 1] = id end
    table.sort(list)
    slotLists[key] = list
  end
  return slotLists[key]
end

--- The slot ids an instance of `client` reads, ascending. Read, never write.
--- @return table
function G.SlotsFor(client) return slotsOf(client) end

local BAG_ONLY = { BAG_UPDATE_DELAYED = true, afterCombat = true }

local function state(v)
  local s = v.__gear
  if not s then
    s = { timer = nil, pendingFull = false, deferredBags = false, snap = nil }
    v.__gear = s
  end
  return s
end

-- ---------------------------------------------------------------------------------------------
-- Reading the client
-- ---------------------------------------------------------------------------------------------

local function copy(facts)
  local out = {}
  for k, val in pairs(facts) do out[k] = val end
  return out
end

local function factsOf(v, link, waiting)
  local facts, status = v:Request(link, function(f) if f then v:ScheduleGear("itemLoaded") end end)
  if status == "loading" then waiting.n = waiting.n + 1 end
  return facts
end

local function wornEntry(v, slot, waiting, prev)
  local link = v.R.InventoryItemLink("player", slot)
  local kept = prev and prev[slot]
  if kept ~= nil and ((kept == false and not link) or (kept and kept.link == link)) then return kept end
  if not link then return false end
  local facts = factsOf(v, link, waiting)
  if not facts then return nil end
  local e = copy(facts)
  e.ilvl = v.R.InventoryItemLevel("player", slot) or facts.ilvl
  e.slot = slot
  return e
end

local function readEquipped(v, waiting, prev)
  local equipped = {}
  for _, slot in ipairs(slotsOf(v.client)) do
    local e = wornEntry(v, slot, waiting, prev)
    if e ~= nil then equipped[slot] = e end
  end
  return equipped
end

local function classFileOf(R)
  local _, classFile = R.UnitClass("player")
  if R.IsSecret(classFile) or type(classFile) ~= "string" then return nil end
  return classFile
end

local function readIdentity(v)
  local R, CD = v.R, v:ClassData()
  local classFile, specID = classFileOf(R), R.PlayerSpecID()
  local talents = R.PlayerTalentTree()
  local tree = talents and talents.index or nil
  return {
    classFile = classFile, specID = specID, tree = tree, level = R.UnitLevel("player"),
    dualWield = CD.DualWieldFor(classFile, specID, tree), titanGrip = CD.TitanGripFor(classFile, specID, tree),
  }
end

local function isGear(plan, facts)
  if facts.isTierToken or not plan[facts.equipLoc or ""] then return false end
  return type(facts.ilvl) == "number"
end

local function wearable(v, items, who)
  local out = {}
  for _, e in ipairs(items) do
    if lib.Equippability(e, who, v.client) == "ok" then out[#out + 1] = e end
  end
  return out
end

local function mayBeGear(v, plan, link)
  local equipLoc = v.R.ItemEquipLoc(link)
  return equipLoc == nil or plan[equipLoc] ~= nil
end

local function readBags(v, waiting)
  local R, plan, items = v.R, C.SlotPlanFor(v.client), {}
  for _, bag in ipairs(C.BAG_IDS) do
    for bagSlot = 1, R.BagSlotCount(bag) do
      local link = R.BagItemLink(bag, bagSlot)
      local facts = link and mayBeGear(v, plan, link) and factsOf(v, link, waiting)
      if facts and isGear(plan, facts) then
        local e = copy(facts)
        e.bag, e.bagSlot = bag, bagSlot
        items[#items + 1] = e
      end
    end
  end
  return items
end

-- ---------------------------------------------------------------------------------------------
-- The best owned per slot
-- ---------------------------------------------------------------------------------------------

local function fitsOf(plan, e, who)
  local p = plan[e.equipLoc or ""]
  if not p then return nil end
  local MH, OH = C.SLOT.MAINHAND, C.SLOT.OFFHAND
  local kind, fits = p.kind, {}
  if kind == "single" or kind == "pair" then
    for _, slot in ipairs(p.slots) do fits[slot] = true end
  elseif kind == "offhand" then
    fits[OH] = true
  else
    fits[MH] = true
    local second = (kind == "weapon1H" and who.dualWield) or (kind == "weapon2H" and who.titanGrip)
    if second then fits[OH] = true end
  end
  return fits
end

local function pool(v, equipped, bagItems, who)
  local plan, out = C.SlotPlanFor(v.client), {}
  local function add(e)
    local fits = fitsOf(plan, e, who)
    if fits then out[#out + 1] = { entry = e, fits = fits } end
  end
  for _, slot in ipairs(slotsOf(v.client)) do
    if type(equipped[slot]) == "table" then add(equipped[slot]) end
  end
  for _, e in ipairs(bagItems) do add(e) end
  return out
end

local function bestFor(slot, items)
  local best
  for _, it in ipairs(items) do
    if not it.used and it.fits[slot] and (not best or it.entry.ilvl > best.entry.ilvl) then best = it end
  end
  return best
end

local function readOwned(v, equipped, bagItems, who)
  local items, owned = pool(v, equipped, bagItems, who), {}
  for _, slot in ipairs(slotsOf(v.client)) do
    local best = bestFor(slot, items)
    if best then
      best.used = true
      owned[slot] = best.entry
    end
  end
  return owned
end

-- ---------------------------------------------------------------------------------------------
-- The snapshot
-- ---------------------------------------------------------------------------------------------

local function entryKey(e)
  if e == false then return "-" end
  if e == nil then return "?" end
  return e.link .. "@" .. tostring(e.ilvl)
end

local function signature(v, snap, bagItems)
  local parts = { tostring(snap.classFile), tostring(snap.specID), tostring(snap.tree), tostring(snap.level) }
  for _, slot in ipairs(slotsOf(v.client)) do
    parts[#parts + 1] = slot .. "=" .. entryKey(snap.equipped[slot]) .. "/" .. entryKey(snap.owned[slot] or false)
  end
  local bags = {}
  for _, e in ipairs(bagItems) do bags[#bags + 1] = entryKey(e) end
  table.sort(bags)
  parts[#parts + 1] = table.concat(bags, ",")
  return table.concat(parts, ";")
end

local function poolOf(v, equipped, bagItems)
  local out = {}
  for _, slot in ipairs(slotsOf(v.client)) do
    if type(equipped[slot]) == "table" then out[#out + 1] = equipped[slot] end
  end
  for _, e in ipairs(bagItems) do out[#out + 1] = e end
  return out
end

--- A fresh snapshot read from the client, unstored. With `prevEquipped` (a bag-only rebuild) each
--- worn slot whose link has not moved is kept as that table holds it.
--- @param prevEquipped table|nil
--- @return table
function methods:ReadGear(prevEquipped)
  local waiting = { n = 0 }
  local snap = readIdentity(self)
  snap.equipped = readEquipped(self, waiting, prevEquipped)
  local bagItems = readBags(self, waiting)
  snap.owned = readOwned(self, snap.equipped, wearable(self, bagItems, snap), snap)
  snap.pool, snap.bySpec = poolOf(self, snap.equipped, bagItems), {}
  snap.loading = waiting.n
  snap.signature = signature(self, snap, bagItems)
  return snap
end

--- Re-read the snapshot now; tells the host onChange("gear") when it moved, unless `quiet`. With
--- `bagsOnly` the worn slots whose link stayed are kept from the last snapshot.
--- @param cause string|nil
--- @param quiet boolean|nil
--- @param bagsOnly boolean|nil
--- @return boolean changed
function methods:RefreshGear(cause, quiet, bagsOnly)
  local s = state(self)
  local prev = s.snap
  local t0 = self:PerfStart()
  s.deferredBags = false
  local snap = self:ReadGear(bagsOnly and prev and prev.equipped or nil)
  self:PerfNote("gear.rebuild", t0)
  s.snap = snap
  local changed = not prev or prev.signature ~= snap.signature
  if not changed then return false end
  self:Debug(TAG, "gear: spec %s, %d loading (%s)", tostring(snap.specID), snap.loading, tostring(cause))
  if not quiet then self:Changed("gear") end
  return true
end

--- Arm the rebuild timer, unless it is armed already or the instance is stood down.
--- @param cause string|nil
function methods:ScheduleGear(cause)
  if self.down then return end
  local s = state(self)
  if not BAG_ONLY[cause] then s.pendingFull = true end
  if s.timer then return end
  s.timer = C_Timer.NewTimer(G.THROTTLE, function()
    s.timer = nil
    local bagsOnly = not s.pendingFull
    s.pendingFull = false
    if self.down then return end
    self:RefreshGear(cause, nil, bagsOnly)
  end)
end

--- Whether a rebuild is armed.
--- @return boolean
function methods:GearScheduled()
  return self.__gear ~= nil and self.__gear.timer ~= nil
end

--- A gear event: BAG_UPDATE_DELAYED while the host's deferWhile() holds is noted for the next
--- PLAYER_REGEN_ENABLED; anything else arms the rebuild.
--- @param event string
function methods:OnGearEvent(event)
  local hold = self.host.deferWhile
  if event == "BAG_UPDATE_DELAYED" and type(hold) == "function" and hold() then
    state(self).deferredBags = true
    return
  end
  self:ScheduleGear(event)
end

--- The PLAYER_REGEN_ENABLED edge: a bag event held by deferWhile rebuilds now.
function methods:OnGearDeferEnd()
  if state(self).deferredBags then self:ScheduleGear("afterCombat") end
end

--- The stored snapshot, read lazily (and quietly) on first use. Read it, never write it.
--- @return table
function methods:Snapshot()
  local s = state(self)
  if not s.snap then self:RefreshGear("lazy", true) end
  return s.snap
end

--- Your gear snapshot's signature, false when there is none: a reader that keeps a gear verdict
--- works it out again when it moved.
--- @return string|boolean
function methods:Signature()
  local snap = self:Snapshot()
  return type(snap) == "table" and snap.signature or false
end

--- Your candidate for lib.Evaluate: a fresh outer table over the snapshot's own (read-only) gear.
--- @return table
function methods:Candidate()
  local s = self:Snapshot()
  return {
    classFile = s.classFile, specID = s.specID, tree = s.tree, level = s.level,
    dualWield = s.dualWield, titanGrip = s.titanGrip, gear = s.equipped, owned = s.owned, isPlayer = true,
    offSpecGear = lib.OffSpec.Enabled(self.client) and function(specID) return self:OffSpecGear(specID) end or nil,
  }
end

local function offSpecGearOf(v, s, specID)
  local who = lib.OffSpec.Who(s.classFile, specID, v.client)
  local owned, gear = readOwned(v, {}, wearable(v, s.pool, who), who), {}
  for _, slot in ipairs(slotsOf(v.client)) do
    if s.equipped[slot] ~= nil then gear[slot] = owned[slot] or false end
  end
  return gear
end

--- Another spec of your class's gear for the kernel: the best item you own per slot that the spec
--- could wear, false where nothing fits. Nil for a spec that is not your class's, and nil while any
--- item still loads. Memoized on the snapshot; read it, never write it.
--- @param specID number
--- @return table|nil
function methods:OffSpecGear(specID)
  local s = self:Snapshot()
  local row = type(specID) == "number" and self:ClassData().SPECS[specID]
  if not row or row.class ~= s.classFile or s.loading > 0 then return nil end
  if not s.bySpec[specID] then s.bySpec[specID] = offSpecGearOf(self, s, specID) end
  return s.bySpec[specID]
end

-- ---------------------------------------------------------------------------------------------
-- The judge
-- ---------------------------------------------------------------------------------------------

local function scorePending(me)
  for _, r in ipairs(type(me) == "table" and type(me.reasons) == "table" and me.reasons or {}) do
    if type(r) == "table" and r.key == "scorePending" then return true end
  end
  return false
end

--- True when a verdict waits on its score (the reason `scorePending`).
--- @param me table|nil
--- @return boolean
function G.ScorePending(me) return scorePending(me) end

-- Your candidate, with the item types you do not want for your spec (on WoW Forever your talent
-- tree's), and each off-spec's own list.
local function myCandidate(v, cfg)
  local cand = v:Candidate()
  local key = v:ClassData().SpecKey(cand.classFile, cand.specID, cand.tree) or cand.specID
  local undesired = cfg.undesired and key and cfg.undesired[key]
  if type(undesired) == "table" then cand.prefs = { undesired = undesired } end
  cand.undesiredBySpec = cfg.undesired
  return cand
end

--- The verdict on `facts`: the collection verdict, else the kernel's for your candidate, or for
--- `opts.candidate` (another player's: no heirloom protection, which is yours alone).
--- @param facts table
--- @param opts table|nil { forced = boolean, candidate = table }
--- @return table
function methods:JudgeFacts(facts, opts)
  opts = type(opts) == "table" and opts or {}
  local me = lib.Collect and lib.Collect.Verdict(facts, opts.forced == true, self.client)
  if me then return me end
  local cfg = self:Config()
  local eval = { sidegradeBand = cfg.sidegradeBand, compareOwned = cfg.compareOwned, scorer = self:Scorer(cfg),
    verdictMode = cfg.verdictMode, client = self.client }
  local candidate = opts.candidate
  if candidate == nil then
    candidate = myCandidate(self, cfg)
    eval.heirloomProtect = cfg.heirloomProtect == true
  end
  local t0 = self:PerfStart()
  local out = lib.Evaluate(facts, candidate, eval)
  self:PerfNote("evaluate", t0)
  return out
end

local retryScores

local function armScoreRetry(v)
  if v.down or v.__scoreTimer then return end
  v.__scoreTimer = C_Timer.NewTimer(G.SCORE_RETRY, function()
    v.__scoreTimer = nil
    retryScores(v)
  end)
end

retryScores = function(v)
  if v.down then return end
  local again = false
  for link, tries in pairs(v.__scorePending or {}) do
    local facts = v:Facts(link)
    local me = facts and v:JudgeFacts(facts)
    if me and not scorePending(me) then
      v.__scorePending[link] = nil
      v:Changed("score", link)
    elseif tries + 1 >= G.SCORE_TRIES then
      v.__scorePending[link] = nil
      v:Debug("SCORE", "score retry: gave up on %s after %d tries", link, tries + 1)
    else
      v.__scorePending[link] = tries + 1
      again = true
    end
  end
  if again then armScoreRetry(v) end
end

--- Your verdict on the item a link names, and whether it is pending: `nil, true` while the client
--- loads the item (it is asked for; onChange("item", link) when it arrives), `me, true` while its
--- score waits (retried; onChange("score", link) when it answers), `me, false` when settled, and
--- `nil, false` for a link that names no item or an item the client cannot load.
--- @param link string
--- @param forced boolean|nil
--- @return table|nil me, boolean pending
function methods:Judge(link, forced)
  -- One callback per instance, so a link judged again while it loads is announced once.
  self.__onItem = self.__onItem or function(f, l) if f then self:Changed("item", l) end end
  local facts, status = self:Request(link, self.__onItem)
  if not facts then return nil, status == "loading" end
  local me = self:JudgeFacts(facts, { forced = forced })
  if not scorePending(me) then return me, false end
  self.__scorePending = self.__scorePending or {}
  if self.__scorePending[link] == nil then self.__scorePending[link] = 0 end
  armScoreRetry(self)
  return me, true
end

-- ---------------------------------------------------------------------------------------------
-- Events and the lifecycle
-- ---------------------------------------------------------------------------------------------

local function onGear(v, event) v:OnGearEvent(event) end
local function rebuild(v, event) v:ScheduleGear(event) end

lib.__events["gear:PLAYER_EQUIPMENT_CHANGED"] = { event = "PLAYER_EQUIPMENT_CHANGED", fn = onGear }
lib.__events["gear:BAG_UPDATE_DELAYED"] = { event = "BAG_UPDATE_DELAYED", fn = onGear }
-- Fires for any unit; only yours moves the snapshot. A secret unit is assumed to be yours.
lib.__events["gear:PLAYER_SPECIALIZATION_CHANGED"] = { event = "PLAYER_SPECIALIZATION_CHANGED",
  clients = { "retail" }, fn = function(v, event, unit)
    if v.R.IsSecret(unit) or unit == nil or unit == "player" then v:ScheduleGear(event) end
  end }
-- WoW Forever's spec change is a talent change (the trees are the specs); a level gained moves
-- the armor you wear.
lib.__events["gear:TRAIT_CONFIG_UPDATED"] = { event = "TRAIT_CONFIG_UPDATED", clients = { "forever" }, fn = rebuild }
lib.__events["gear:CHARACTER_POINTS_CHANGED"] = { event = "CHARACTER_POINTS_CHANGED", clients = { "forever" },
  fn = rebuild }
lib.__events["gear:PLAYER_LEVEL_UP"] = { event = "PLAYER_LEVEL_UP", clients = { "forever" }, fn = rebuild }
lib.__events["gear:PLAYER_REGEN_ENABLED"] = { event = "PLAYER_REGEN_ENABLED",
  fn = function(v) v:OnGearDeferEnd() end }

lib.__lifecycle.gear = { order = 30,
  down = function(v)
    local s = v.__gear
    if s and s.timer then s.timer:Cancel() end
    v.__gear = nil
    if v.__scoreTimer then v.__scoreTimer:Cancel() end
    v.__scoreTimer, v.__scorePending = nil, nil
  end,
  -- A lazy stand-up reads nothing: the first ask (Snapshot, through Judge) reads, quietly.
  up = function(v, opts)
    if opts and opts.lazy then return end
    v:RefreshGear("standUp")
  end,
}
