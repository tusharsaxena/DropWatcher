local _, NS = ...
-- modules/TestData.lua — test mode's sample data (design spec §11.6, boards 03, 04 and 06; ui
-- spec §4, FB-9 and FB-10), pure: the drops NS.LootFeed.AddTest takes and the History tab's
-- session-only entries, built over REAL items that modules/TestMode.lua takes from the
-- simulator's item pool (modules/SimPool.lua).
--
-- THE DROPS. Two groups (a boss and a key run): eleven drops of other members covering board 03
-- (Me and Them: upgrade, sidegrade, downgrade, can't use, doesn't want, unknown; Trade: yes,
-- likely, unknown, no; inspect: fresh, cached, pending, out of range, combat, failed, not in the
-- group; Ask: ready, queued, asked, retry, traded and the dash) and five of your own covering board
-- 04 (an exact countdown, one ending soon, an estimated one, a bind-on-equip drop and an expired
-- one, with candidates in every pill: +n UPGRADE, EQUAL, NO UPGRADE, CAN'T USE, CHECKING and
-- UNAVAILABLE). One drop's look is collected and one's is not, for the look chips and the
-- transmog ask.
--
-- THE ITEMS. Each sample keeps its slot: Source(drops, gear, factsOf) answers, per equip location,
-- a pool item of that slot (an unused one first), its facts as factsOf reads them, so the icon,
-- name, item level and tooltip are the real item's. The worn items (your baseline, the looter's
-- inspected gear, each candidate's) are pool items of the same slot whose level is nearest the one
-- the sample's change implies. A slot the pool has nothing for borrows any pool item; an empty
-- pool gives no sample at all, never an invented item.
--
-- THE STATES are the spec's fixed values (v1 §11.6): the verdicts, their changes, the trade
-- estimates, the inspect and ask states. It is a preview, not a simulation (`/dw sim` is that).
-- Only the levels come from the items: the drop's own, the worn items', and the trade reason's
-- two levels. Every player name is invented; nothing names a real player.
--
-- THE HISTORY (FB-10). History(nowEpoch, you, src) answers a session-only log of two groups that
-- between them show every outcome (seen, asked, offered, expired, declined, received, traded away),
-- seen by you, and a third seen by an invented alt on your realm (ALT), so the Character dropdown
-- (feedback-2 spec §4) lists two characters and Current hides the alt's group. The alt's group is
-- ten days old, so a Keep history for of 7 days (feedback-2 spec §5) asks to delete it.
-- modules/TestMode.lua holds it while test mode is on; it is never written to the account's history.

NS.TestData = NS.TestData or {}
local TD = NS.TestData
local C  = NS.Constants
local L  = NS.L

-- ── the item source ─────────────────────────────────────────────────────────────────────────

-- The slot an equip location fills first: two items of one slot family share it.
local function slotOf(equipLoc)
    local plan = C.SLOT_PLAN[equipLoc]
    return plan and plan.slots[1] or nil
end

local function firstOf(list, ok)
    for _, e in ipairs(list) do
        if ok(e) then return e end
    end
    return nil
end

-- A drop for `equipLoc`: an unused item of its slot, any item of its slot, an unused item, any.
local function pickDrop(self, equipLoc)
    local slot, used = slotOf(equipLoc), self.used
    local list = self.drops
    return firstOf(list, function(e) return slotOf(e.equipLoc) == slot and not used[e.link] end)
        or firstOf(list, function(e) return slotOf(e.equipLoc) == slot end)
        or firstOf(list, function(e) return not used[e.link] end)
        or list[1]
end

--- The sample drop for `equipLoc`: { link, itemID, facts } (a copy of the facts, the sample's own),
--- or nil when the pool is empty.
--- @param equipLoc string
--- @return table|nil
local function drop(self, equipLoc)
    local e = pickDrop(self, equipLoc)
    if not e then return nil end
    self.used[e.link] = true
    local facts = {}
    for k, v in pairs(self.factsOf(e) or {}) do facts[k] = v end
    facts.ilvl = facts.ilvl or e.ilvl
    facts.equipLoc = facts.equipLoc or e.equipLoc
    return { link = e.link, itemID = e.itemID, facts = facts }
end

--- A worn item of `equipLoc`'s slot whose level is nearest `target`, other than `notLink` when the
--- pool has another: { link, ilvl }, or nil when the pool has none of that slot.
--- @param equipLoc string
--- @param target number
--- @param notLink string|nil
--- @return table|nil
local function worn(self, equipLoc, target, notLink)
    local slot, best, bestGap = slotOf(equipLoc), nil, math.huge
    for _, e in ipairs(self.gear) do
        if slotOf(e.equipLoc) == slot and type(e.ilvl) == "number" then
            local gap = math.abs(e.ilvl - target) + (e.link == notLink and 1000 or 0)
            if gap < bestGap then best, bestGap = e, gap end
        end
    end
    return best and { link = best.link, ilvl = best.ilvl } or nil
end

--- The item source the samples draw on. `drops` are the pool's drops and `gear` its gear (each
--- { link, itemID, equipLoc, ilvl }); `factsOf(entry)` answers an entry's item facts or nil.
--- @param drops table
--- @param gear table
--- @param factsOf function
--- @return table src { Drop(self, equipLoc), Worn(self, equipLoc, target, notLink) }
function TD.Source(drops, gear, factsOf)
    return { drops = drops or {}, gear = gear or {}, factsOf = factsOf or function() return nil end,
        used = {}, Drop = drop, Worn = worn }
end

-- ── the drops (pure) ────────────────────────────────────────────────────────────────────────

-- The members the samples name, all invented.
local MEMBERS = {
    seta        = { name = "Seta", guid = "Player-0-0000T001", classFile = "PRIEST", specID = 257 },
    littlewolf  = { name = "Littlewolf", guid = "Player-0-0000T002", classFile = "DRUID", specID = 105 },
    uniquerogue = { name = "Uniquerogue", guid = "Player-0-0000T003", classFile = "ROGUE", specID = 260 },
    butterz     = { name = "Butterz", guid = "Player-0-0000T004", classFile = "WARRIOR", specID = 71 },
    kaelith     = { name = "Kaelith", guid = "Player-0-0000T005", classFile = "PALADIN", specID = 70 },
    mistveil    = { name = "Mistveil", guid = "Player-0-0000T006", classFile = "MONK", specID = 270 },
    dawnfeather = { name = "Dawnfeather", guid = "Player-0-0000T007", classFile = "EVOKER", specID = 1468 },
}
TD.MEMBERS = MEMBERS

local function looter(key)
    local m = MEMBERS[key]
    return { name = m.name, guid = m.guid, classFile = m.classFile }
end

local function round(n) return math.floor(n + 0.5) end

-- An evaluation as NS.Evaluate answers it: the verdict, the change, the worn item (a pool item
-- near the level the change implies) and the kernel's reason key (`reason`).
local function ev(src, item, spec)
    if not spec then return nil end
    local verdict, delta = spec[1], spec[2]
    local reasons = spec.reason and { { key = spec.reason } } or {}
    local base
    if type(delta) == "number" then
        local w = src:Worn(item.facts.equipLoc, round(item.facts.ilvl - delta), item.link)
        base = w and { link = w.link, ilvl = w.ilvl } or nil
    end
    return { verdict = verdict, ilvlDelta = delta, reasons = reasons, baseline = base }
end

local function trade(state, reasonKey, args, basis, age)
    return { state = state, reasonKey = reasonKey, args = args or {}, basis = basis or "rule", age = age }
end

-- The trade estimate a row names: { state, reasonKey, basis, age }; the two-level reasons read
-- the drop's level and the looter's worn one, `noInspect` the inspect state.
local LEVEL_ARGS = { notUpgrade = true, upgradeForLooter = true }

local function tradeOf(row, item, them, inspect)
    local t = row.trade
    local args
    if LEVEL_ARGS[t[2]] then
        args = { item.facts.ilvl, them and them.baseline and them.baseline.ilvl or item.facts.ilvl }
    elseif t[2] == "noInspect" then
        args = { inspect.status }
    end
    return trade(t[1], t[2], args, t[3], t[4])
end

-- The looter's inspect entry (status, age, the worn item in the drop's slot, the spec), and the
-- drop's own inspect, the same without the gear, as the feed records it.
local function inspected(row, now, them, equipLoc)
    local i = row.inspect
    local status, age, reason = i[1], i[2], i[3]
    local good = status == "fresh" or status == "cached"
    local gear = {}
    if good and them and them.baseline then gear[slotOf(equipLoc)] = them.baseline end
    local at = age and now - age or nil
    return { status = status, reason = reason, at = at, gear = gear,
            specID = good and MEMBERS[row.who].specID or nil },
        { status = status, reason = reason, at = at }
end

-- The other members' drops, board 03 row by row: the looter, the slot, Me and Them as
-- { verdict, change, reason = key }, the trade { state, reasonKey, basis, age }, the inspect
-- { status, age, reason }, the ask state, and the look's state.
local OTHERS_AT_BOSS = {
    { who = "seta", slot = "INVTYPE_HEAD", look = true, me = { "upgrade", 19 }, them = { "downgrade", -13 },
      trade = { "likely", "notUpgrade", "inspect", 40 }, inspect = { "fresh", 40 } },
    { who = "littlewolf", slot = "INVTYPE_FINGER", me = { "upgrade", 4 }, them = { "sidegrade", 1 },
      trade = { "likely", "notUpgrade", "inspect", 360 }, inspect = { "cached", 360 }, ask = { state = "queued" } },
    { who = "uniquerogue", slot = "INVTYPE_TRINKET", me = { "upgrade", 9 },
      trade = { "unknown", "noInspect" }, inspect = { "outOfRange" }, ask = { state = "sent" } },
    { who = "butterz", slot = "INVTYPE_CLOAK", me = { "sidegrade", 0.4, reason = "scoreDisagrees" }, them = { "upgrade", 6 },
      trade = { "yes", "boe", "bind" }, inspect = { "fresh", 90 },
      ask = { state = "failed", reason = L["the chat throttle"] } },
    { who = "kaelith", slot = "INVTYPE_WRIST", me = { "downgrade", -8 }, them = { "upgrade", 12 },
      trade = { "no", "upgradeForLooter", "inspect", 75 }, inspect = { "fresh", 75 } },
    { who = "seta", slot = "INVTYPE_LEGS", me = { "cantUse", reason = "armorType" },
      trade = { "unknown", "noInspect" }, inspect = { "pending" } },
    { who = "mistveil", slot = "INVTYPE_SHOULDER", me = { "upgrade", 6 }, them = { "cantUse", reason = "armorType" },
      trade = { "likely", "notUpgrade", "inspect", 20 }, inspect = { "fresh", 20 }, ask = { state = "traded" } },
    { who = "dawnfeather", slot = "INVTYPE_FEET", me = { "sidegrade", -1 },
      trade = { "unknown", "noInspect" }, inspect = { "unavailable", nil, "notInGroup" } },
}

local OTHERS_IN_RUN = {
    { who = "butterz", slot = "INVTYPE_HAND", me = { "unknown", reason = "noBaseline" },
      trade = { "no", "bonusRoll", "bind" }, inspect = { "failed", nil, "timeout" } },
    { who = "kaelith", slot = "INVTYPE_NECK", me = { "upgrade", 2 }, them = { "downgrade", -4 },
      trade = { "no", "warbound", "bind" }, inspect = { "cached", 900 } },
    { who = "littlewolf", slot = "INVTYPE_WEAPON", look = false, me = { "doesntWant", reason = "undesired" },
      trade = { "unknown", "noInspect" }, inspect = { "combatParked" } },
}

local function other(src, now, row)
    local item = src:Drop(row.slot)
    if not item then return nil end
    if row.look ~= nil then item.facts.transmogKnown = row.look end
    local them = ev(src, item, row.them)
    local testInspect, insp = inspected(row, now, them, item.facts.equipLoc)
    return { looter = looter(row.who), link = item.link, facts = item.facts, me = ev(src, item, row.me),
        them = them, trade = tradeOf(row, item, them, insp), testInspect = testInspect, inspect = insp,
        testAsk = row.ask }
end

-- One candidate for your own drop: `{ who, verdict, change }`, judged, checking or unavailable.
local function cand(src, item, c)
    local m = MEMBERS[c[1]]
    local e = { guid = m.guid, name = m.name, classFile = m.classFile }
    if c[2] == "checking" or c[2] == "unavailable" then
        e.status = c[2]
        return e
    end
    e.status, e.eval = "ready", ev(src, item, { c[2], c[3], reason = c[2] == "cantUse" and "armorType" or nil })
    return e
end

local function timer(now, left)
    local t = trade("yes", "timer", { left }, "timer")
    t.expiresAt = now + left
    return t
end

-- Your own drops' trade estimates.
local MY_TRADE = {
    boe       = function() return trade("yes", "boe", {}, "bind") end,
    expired   = function() return trade("no", "expired", { 0, C.TRADE_WINDOW }, "timer") end,
    groupLoot = function() return trade("yes", "groupLoot", {}, "rule") end,
}

local function tradeMine(now, t)
    if t[1] == "timer" then return timer(now, t[2]) end
    return MY_TRADE[t[1]]()
end

-- Your own drops, board 04 row by row: at the boss an exact countdown and a bind-on-equip drop,
-- in the key run one ending soon, an estimated one and an expired one.
local YOURS_AT_BOSS = {
    { slot = "INVTYPE_TRINKET", me = { "downgrade", -6 }, trade = { "timer", 6600 }, ago = 600, cands = {
        { "seta", "upgrade", 14 }, { "butterz", "upgrade", 6 }, { "littlewolf", "sidegrade", 0 },
        { "kaelith", "downgrade", -7 }, { "uniquerogue", "cantUse" }, { "mistveil", "checking" },
        { "dawnfeather", "unavailable" } } },
    { slot = "INVTYPE_CLOAK", me = { "downgrade", -10 }, trade = { "boe" }, ago = 240,
      cands = { { "butterz", "upgrade", 11 }, { "kaelith", "unavailable" } } },
}

local YOURS_IN_RUN = {
    { slot = "INVTYPE_HEAD", me = { "downgrade", -26 }, trade = { "expired" }, ago = 7300, cands = {} },
    { slot = "INVTYPE_FINGER", me = { "upgrade", 3 }, trade = { "timer", 420 }, ago = 6780,
      cands = { { "seta", "upgrade", 8 }, { "mistveil", "sidegrade", 1 } } },
    { slot = "INVTYPE_WAIST", me = { "downgrade", -5 }, trade = { "groupLoot" }, ago = 1800,
      cands = { { "kaelith", "checking" }, { "seta", "cantUse" } } },
}

local function mine(src, now, you, row)
    local item = src:Drop(row.slot)
    if not item then return nil end
    local candidates = {}
    for _, c in ipairs(row.cands) do
        local e = cand(src, item, c)
        candidates[e.guid] = e
    end
    return { looter = you, link = item.link, facts = item.facts, me = ev(src, item, row.me),
        trade = tradeMine(now, row.trade), candidates = candidates, ago = row.ago }
end

local BOSS = { key = "test:boss", label = L["Placeholder boss"], kind = "encounter" }
local RUN  = { key = "test:run", label = L["Placeholder key run"], kind = "run" }

-- Who was in each sample group (feedback-2 spec §3): you first, then these members. The boss is a
-- raid's, longer than a header names, so its header ends `+n`.
local RUN_PARTY = { "butterz", "kaelith", "littlewolf", "seta" }
local RAID = { "seta", "littlewolf", "uniquerogue", "butterz", "kaelith", "mistveil", "dawnfeather" }

local function roster(you, keys)
    local GR = NS.GroupRoster
    local out = { GR.Entry({ name = you.name, classFile = you.classFile, isSelf = true }) }
    for _, k in ipairs(keys) do out[#out + 1] = GR.Entry(MEMBERS[k]) end
    return out
end

-- `group` with its roster, a fresh table each call (the samples' are shared).
local function withRoster(group, you, keys)
    local g = {}
    for k, v in pairs(group) do g[k] = v end
    g.roster = roster(you, keys)
    return g
end

-- Each row of `rows` made by `make`, placed in `group` at `situation` (`ago` unless its own).
local function place(out, rows, make, group, situation, ago)
    for _, row in ipairs(rows) do
        local spec = make(row)
        if spec then
            spec.group, spec.situation, spec.ago = group, situation, spec.ago or ago
            out[#out + 1] = spec
        end
    end
end

--- Every sample drop, as NS.LootFeed.AddTest takes them: the key run's (yours, then the other
--- members'), then the boss's (theirs, then yours). Empty when `src` has no item. Pure.
--- @param now number GetTime()
--- @param you table your looter { name, guid, classFile, isSelf = true }
--- @param src table TD.Source's
--- @return table specs
function TD.Placeholders(now, you, src)
    local out = {}
    local function theirs(row) return other(src, now, row) end
    local function yours(row) return mine(src, now, you, row) end
    local run, boss = withRoster(RUN, you, RUN_PARTY), withRoster(BOSS, you, RAID)
    place(out, YOURS_IN_RUN, yours, run, "mythicPlus")
    place(out, OTHERS_IN_RUN, theirs, run, "mythicPlus", 3600)
    place(out, OTHERS_AT_BOSS, theirs, boss, "raid", 120)
    place(out, YOURS_AT_BOSS, yours, boss, "raid")
    return out
end

-- ── the history (pure) ──────────────────────────────────────────────────────────────────────

-- The alt that saw the third sample group: an invented character on your realm.
local ALT = { name = "Emberwick", classFile = "WARLOCK" }
TD.ALT = ALT

-- Two groups, every outcome between them, then the alt's: the looter (nil: whoever saw it), the
-- slot, Me and Them, the trade { state, reasonKey }, and the outcome (`before` under a declined
-- one). `alt` marks the group the alt saw.
local HISTORY = {
    { group = { key = "test:history:boss", label = L["Placeholder boss"], kind = "encounter", situation = "raid" },
      party = RAID, ago = 7200, drops = {
        { who = "seta", slot = "INVTYPE_HEAD", me = { "upgrade", 19 }, them = { "downgrade", -13 },
          trade = { "likely", "notUpgrade" }, outcome = "asked" },
        { who = "butterz", slot = "INVTYPE_CLOAK", me = { "upgrade", 7 }, them = { "sidegrade", 0 },
          trade = { "yes", "boe" }, outcome = "received" },
        { who = "kaelith", slot = "INVTYPE_WRIST", me = { "downgrade", -8 }, them = { "upgrade", 12 },
          trade = { "no", "upgradeForLooter" }, outcome = "seen" },
        { who = "mistveil", slot = "INVTYPE_SHOULDER", me = { "upgrade", 6 }, them = { "cantUse" },
          trade = { "likely", "notUpgrade" }, outcome = "declined", before = "seen" },
    } },
    { group = { key = "test:history:run", label = L["Placeholder key run"], kind = "run", situation = "mythicPlus" },
      party = RUN_PARTY, ago = 93600, drops = {
        { slot = "INVTYPE_TRINKET", me = { "downgrade", -6 }, trade = { "yes", "timer" }, outcome = "offered" },
        { slot = "INVTYPE_FINGER", me = { "downgrade", -3 }, trade = { "yes", "groupLoot" }, outcome = "tradedAway" },
        { slot = "INVTYPE_FEET", me = { "downgrade", -20 }, trade = { "no", "expired" }, outcome = "expired" },
    } },
    { group = { key = "test:history:alt", label = L["Placeholder boss (alt)"], kind = "encounter", situation = "raid" },
      party = RUN_PARTY, ago = 864000, alt = true, drops = {
        { who = "seta", slot = "INVTYPE_HAND", me = { "upgrade", 4 }, them = { "downgrade", -6 },
          trade = { "likely", "notUpgrade" }, outcome = "seen" },
        { slot = "INVTYPE_WAIST", me = { "downgrade", -9 }, trade = { "yes", "timer" }, outcome = "offered" },
    } },
}

local function snap(spec)
    if not spec then return nil end
    return { verdict = spec[1], ilvlDelta = spec[2] }
end

-- `seer` is whoever saw the group: you, or the alt (`seenBy`, its recorder key, and its class).
local function historyEntry(src, seer, row, at)
    local item = src:Drop(row.slot)
    if not item then return nil end
    local f, m = item.facts, row.who and MEMBERS[row.who]
    return {
        itemLink = item.link, itemID = item.itemID or NS.Item.ItemIDFromLink(item.link),
        looter = m and m.name or seer.name, class = m and m.classFile or seer.classFile, isMine = m == nil or nil,
        ilvl = f.ilvl, equipLoc = f.equipLoc, quality = f.quality, me = snap(row.me), them = snap(row.them),
        trade = { state = row.trade[1], reasonKey = row.trade[2], basis = "rule", args = {} },
        outcome = row.outcome, before = row.before, at = at, test = true,
        seenBy = seer.seenBy, seenByClass = seer.classFile,
    }
end

-- The alt as a seer: on your realm (the one in your recorder key), else realm-less.
local function altSeer(you)
    local realm = type(you.seenBy) == "string" and you.seenBy:match("%-(.+)$") or nil
    return { name = ALT.name, classFile = ALT.classFile, isSelf = true,
        seenBy = NS.CharFilter.Key(ALT.name, realm) }
end

--- The History tab's session-only sample log (FB-10): { v = 1, groups }, two groups (a boss two
--- hours ago, a key run a day ago) covering every outcome, over real items, and the alt's boss ten
--- days ago. Pure.
--- @param nowEpoch number time()
--- @param you table your looter { name, classFile, seenBy (your recorder key) }
--- @param src table TD.Source's
--- @return table log
function TD.History(nowEpoch, you, src)
    local log = { v = 1, groups = {} }
    for _, g in ipairs(HISTORY) do
        local at, seer = nowEpoch - g.ago, g.alt and altSeer(you) or you
        local group = { key = g.group.key, label = g.group.label, kind = g.group.kind,
            situation = g.group.situation, at = at, roster = roster(seer, g.party), drops = {} }
        for i, row in ipairs(g.drops) do
            group.drops[#group.drops + 1] = historyEntry(src, seer, row, at + i * 30)
        end
        if #group.drops > 0 then log.groups[#log.groups + 1] = group end
    end
    table.sort(log.groups, function(a, b) return a.at < b.at end)   -- oldest first, as the log keeps them
    return log
end
