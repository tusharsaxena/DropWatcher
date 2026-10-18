local _, NS = ...
-- modules/TestData.lua — test mode's sample data (design spec §11.6, boards 03, 04 and 06; ui
-- spec §4, FB-9 and FB-10), pure: the drops NS.LootFeed.AddTest takes and the History tab's
-- session-only entries, built over REAL items that modules/TestMode.lua takes from the
-- simulator's item pool (modules/SimPool.lua).
--
-- THE PLACES. Every sample group is a real place, and it drops what that place drops (feedback-17):
-- a key run is one of the season's dungeons at `Mythic+ 10`, its loot that dungeon's at the key's
-- level; a boss group is one journal encounter, named for the boss, its loot that boss's at the
-- group's difficulty (Heroic or Mythic for a dungeon or a raid, Looking For Raid, or a world boss in
-- the open world, which names no instance and no difficulty). The pool's entries say which
-- (CONTENT_BY_DIFFICULTY, `worldBoss`). A content the pool holds nothing of, and a pool of your own
-- gear, falls back to every drop it has, under a placeholder name where none is known.
--
-- THE GROUPS are the size the content is: a key run, a dungeon boss and a world boss are you and
-- four others (PARTIES), a Heroic or Mythic raid twenty (RAID_20), a Raid Finder group twenty-five
-- (LFR_25); and they drop what such a group sees: a key run's chest two items, a dungeon boss one
-- or two, a raid boss four or five.
--
-- THE DROPS (the Drops tab: this session). A key run earlier on, then four Heroic raid bosses
-- tonight, twenty-two drops between them. The other members' sixteen cover board 03 (Me and Them:
-- upgrade, sidegrade, downgrade, can't use, doesn't want, unknown; Trade: yes, likely, unknown, no;
-- inspect: fresh, cached, pending, out of range, combat, failed, not in the group; Ask: ready,
-- queued, asked, retry, traded and the dash) and your six cover board 04 (an exact countdown, one
-- ending soon, an estimated one, a bind-on-equip drop and an expired one, with candidates in every
-- status the Offer panel shows: upgrade, equal, off-spec upgrade, no upgrade, can't use, checking
-- and unavailable).
-- Each drop's age is its countdown's: four hours less what is left. One drop's look is collected
-- and one's is not, for the look chips and the transmog ask.
--
-- OFF-SPEC (feedback-19 spec §4). Your samples' spec is Protection (paladin, OFF_MAIN) and the
-- off-spec they show is Holy: a Me of `{ "cantUse", reason = "primaryStat", off = { 65, verdict,
-- change, bag = true? } }` carries eval.offSpec as NS.OffSpec.Attach shapes it, its baseline a worn
-- item (with its slot) or a bag one (`bag`, none), or no baseline and no change for an empty slot.
-- Seta's legs are the owner's Crescent (an off-spec upgrade over a worn item); the last boss is the
-- showcase: an off-spec upgrade into an empty slot, one over a bag item, a sidegrade and a downgrade,
-- and your own drop with a candidate whose off-spec is an upgrade (Kaelith, Retribution, for Holy;
-- the trinket's too). Ashveil's chest is the rule's other side: a wrong armor type is a class-wide
-- refusal, so it stays Can't use with no off-spec. Every off-spec sample is tradeable, so its Ask
-- shows the off-spec rule (the downgrade's No action is "not an upgrade", not a trade refusal).
-- History has an off-spec drop you asked for and one you received; the alt's group keeps none. An off-spec sample's Me cell reads its off-spec baseline (`testOffGear`,
-- TD.OffGearFor), not the gear your current spec wears there.
--
-- YOUR GEAR. A sample carries the worn items its Me verdict was judged against (`testGear`,
-- TD.GearFor), as it carries the looter's (`testInspect.gear`), so the Me cell, the compact card and
-- the detail card all read the same items and never your real gear (feedback-18).
--
-- THE ITEMS. A sample draws on its group's place: an unused item of its slot there, else (a drop
-- that must be armor, `strict`) one of that slot from the same content, else any unused item there,
-- else one of the same content (its slot first), and only then any pool item of its slot, so a
-- drop keeps its group's difficulty while the pool has any of it. The worn items (your baseline,
-- the looter's inspected gear, each candidate's) are pool items of the same slot whose level is
-- nearest the one the sample's change implies. An empty pool gives no sample at all, never an
-- invented item.
--
-- THE STATES are the spec's fixed values (v1 §11.6): the verdicts, their changes, the trade
-- estimates, the inspect and ask states. It is a preview, not a simulation (`/dw sim` is that).
-- Only the levels come from the items: the drop's own, the worn items', and the trade reason's
-- two levels. Every player name is invented; nothing names a real player.
--
-- THE HISTORY (FB-10). History(nowEpoch, you, src) answers a session-only log of the last four
-- weeks (HISTORY): twenty-one groups you saw across Mythic+ 10 runs, Heroic dungeons, Heroic,
-- Mythic and Raid Finder raids and world bosses, mostly drops you only saw and every outcome among
-- them (seen, asked, offered, expired, declined, received, traded away), and one seen by an invented
-- alt on your realm (ALT), so the Character dropdown (feedback-2 spec §4) lists two characters and
-- Current hides the alt's group. The alt's group is ten days old, so a Keep history for of 7 days
-- (feedback-2 spec §5) asks to delete it with the older ones. modules/TestMode.lua holds it while
-- test mode is on; it is never written to the account's history.

NS.TestData = NS.TestData or {}
local TD = NS.TestData
local C  = NS.Constants
local L  = NS.L
local D  = C.DIFFICULTY

-- The key run's level the samples name.
TD.KEY_LEVEL = 10

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

-- The content a pool entry is loot of: a world boss's, else its difficulty's. Nil for an entry the
-- journal did not place (a pool of your own gear).
local CONTENT_BY_DIFFICULTY = {
    [D.MYTHIC_KEYSTONE] = "key", [D.HEROIC_DUNGEON] = "heroicDungeon", [D.HEROIC_RAID] = "raidHeroic",
    [D.MYTHIC_RAID] = "raidMythic", [D.LFR] = "raidLFR",
}

local function contentOf(e)
    if e.worldBoss then return "worldBoss" end
    return CONTENT_BY_DIFFICULTY[e.difficulty]
end

-- The places of one content, in the pool's order: { instance, encounter, items, content } (content:
-- every item of that content, for a drop its place runs short of). A key run's place is its dungeon
-- (the chest drops any of its loot); a boss's is its encounter. A content the pool has nothing of
-- takes every drop, placed the same way.
local function placesOf(self, content)
    if self.places[content] then return self.places[content] end
    local list, byKey, all = {}, {}, {}
    local function add(e)
        local key = tostring(e.instance)
        if content ~= "key" then key = key .. ":" .. tostring(e.encounterID) end
        local p = byKey[key]
        if not p then
            p = { instance = e.instance, encounter = content ~= "key" and e.encounter or nil, items = {}, content = all }
            byKey[key], list[#list + 1] = p, p
        end
        p.items[#p.items + 1] = e
        all[#all + 1] = e
    end
    for _, e in ipairs(self.drops) do
        if contentOf(e) == content then add(e) end
    end
    if #list == 0 then
        for _, e in ipairs(self.drops) do add(e) end
    end
    self.places[content] = list
    return list
end

--- The `n`th place of `content` (they repeat once the pool runs out of them), or nil for an empty
--- pool.
--- @param content string `key`, `heroicDungeon`, `raidHeroic`, `raidMythic`, `raidLFR`, `worldBoss`
--- @param n number
--- @return table|nil { instance, encounter, items, content }
local function place(self, content, n)
    local list = placesOf(self, content)
    if #list == 0 then return nil end
    return list[(n - 1) % #list + 1]
end

-- Armor a class can be barred from: cloth to plate, a cloak aside (every class wears one).
local function isArmor(e)
    local sub = tonumber(e.subClassID)
    return e.classID == 4 and sub ~= nil and sub >= 1 and sub <= 4 and e.equipLoc ~= "INVTYPE_CLOAK"
end

-- What a sample wants: its slot's items, armor, or anything.
local function wanting(spec)
    if spec.slot then
        local slot = slotOf(spec.slot)
        return function(e) return slotOf(e.equipLoc) == slot end
    end
    if spec.armor then return isArmor end
    return function() return false end
end

-- A drop for `spec` ({ slot | armor, strict }) at `where` (a place, or nil): see THE ITEMS.
local function pickDrop(self, spec, where)
    local used, list, want = self.used, self.drops, wanting(spec)
    local items, same = where and where.items or list, where and where.content or list
    local function fresh(e) return not used[e.link] end
    local function both(e) return want(e) and fresh(e) end
    return firstOf(items, both)
        or (spec.strict and firstOf(same, both))
        or firstOf(items, fresh)
        or firstOf(same, both) or firstOf(same, fresh)
        or firstOf(list, both) or firstOf(list, want) or firstOf(list, fresh) or list[1]
end

--- The sample drop for `spec` at `where`: { link, itemID, facts } (a copy of the facts, the
--- sample's own), or nil when the pool is empty. `spec` is an equip location or { slot | armor,
--- strict }; `where` a place (nil: anywhere).
--- @param spec string|table
--- @param where table|nil
--- @return table|nil
local function drop(self, spec, where)
    if type(spec) ~= "table" then spec = { slot = spec } end
    local e = pickDrop(self, spec, where)
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

--- A worn item of `equipLoc`'s slot at `floor` or above, the nearest to it, none of `skip`'s links;
--- nil when the pool has none.
--- @param equipLoc string
--- @param floor number
--- @param skip table { [link] = true }
--- @return table|nil { link, ilvl }
local function above(self, equipLoc, floor, skip)
    local slot, best = slotOf(equipLoc), nil
    for _, e in ipairs(self.gear) do
        if slotOf(e.equipLoc) == slot and type(e.ilvl) == "number" and e.ilvl >= floor and not skip[e.link]
            and (not best or e.ilvl < best.ilvl) then
            best = e
        end
    end
    return best and { link = best.link, ilvl = best.ilvl } or nil
end

--- The item source the samples draw on. `drops` are the pool's drops and `gear` its gear (each
--- { link, itemID, equipLoc, ilvl, and from the journal instance, encounterID, encounter,
--- difficulty, worldBoss, classID, subClassID }); `factsOf(entry)` answers an entry's item facts or
--- nil.
--- @param drops table
--- @param gear table
--- @param factsOf function
--- @return table src { Drop(self, spec, where), Worn(self, equipLoc, target, notLink),
---   Above(self, equipLoc, floor, skip), Place(self, content, n) }
function TD.Source(drops, gear, factsOf)
    return { drops = drops or {}, gear = gear or {}, factsOf = factsOf or function() return nil end,
        used = {}, places = {}, Drop = drop, Worn = worn, Above = above, Place = place }
end

-- ── the people ──────────────────────────────────────────────────────────────────────────────

-- The members the samples name, all invented.
local MEMBERS = {
    seta        = { name = "Seta", guid = "Player-0-0000T001", classFile = "PRIEST", specID = 257 },
    littlewolf  = { name = "Littlewolf", guid = "Player-0-0000T002", classFile = "DRUID", specID = 105 },
    uniquerogue = { name = "Uniquerogue", guid = "Player-0-0000T003", classFile = "ROGUE", specID = 260 },
    butterz     = { name = "Butterz", guid = "Player-0-0000T004", classFile = "WARRIOR", specID = 71 },
    kaelith     = { name = "Kaelith", guid = "Player-0-0000T005", classFile = "PALADIN", specID = 70 },
    mistveil    = { name = "Mistveil", guid = "Player-0-0000T006", classFile = "MONK", specID = 270 },
    dawnfeather = { name = "Dawnfeather", guid = "Player-0-0000T007", classFile = "EVOKER", specID = 1468 },
    thornbrew   = { name = "Thornbrew", guid = "Player-0-0000T008", classFile = "MONK", specID = 268 },
    ashveil     = { name = "Ashveil", guid = "Player-0-0000T009", classFile = "MAGE", specID = 63 },
    grimhollow  = { name = "Grimhollow", guid = "Player-0-0000T010", classFile = "DEATHKNIGHT", specID = 250 },
    solenne     = { name = "Solenne", guid = "Player-0-0000T011", classFile = "PRIEST", specID = 256 },
    kragmar     = { name = "Kragmar", guid = "Player-0-0000T012", classFile = "SHAMAN", specID = 263 },
    vexxa       = { name = "Vexxa", guid = "Player-0-0000T013", classFile = "DEMONHUNTER", specID = 577 },
    brightmane  = { name = "Brightmane", guid = "Player-0-0000T014", classFile = "PALADIN", specID = 65 },
    quillshot   = { name = "Quillshot", guid = "Player-0-0000T015", classFile = "HUNTER", specID = 254 },
    nythera     = { name = "Nythera", guid = "Player-0-0000T016", classFile = "WARLOCK", specID = 265 },
    ironpaw     = { name = "Ironpaw", guid = "Player-0-0000T017", classFile = "DRUID", specID = 104 },
    starhollow  = { name = "Starhollow", guid = "Player-0-0000T018", classFile = "EVOKER", specID = 1467 },
    rookfang    = { name = "Rookfang", guid = "Player-0-0000T019", classFile = "WARRIOR", specID = 73 },
    mossvale    = { name = "Mossvale", guid = "Player-0-0000T020", classFile = "SHAMAN", specID = 264 },
    frostlace   = { name = "Frostlace", guid = "Player-0-0000T021", classFile = "MAGE", specID = 64 },
    emberclaw   = { name = "Emberclaw", guid = "Player-0-0000T022", classFile = "HUNTER", specID = 253 },
    duskmire    = { name = "Duskmire", guid = "Player-0-0000T023", classFile = "ROGUE", specID = 261 },
    palehorn    = { name = "Palehorn", guid = "Player-0-0000T024", classFile = "DEATHKNIGHT", specID = 251 },
}
TD.MEMBERS = MEMBERS

-- Who is in a group besides you: four for a key run, a dungeon or a world boss, nineteen for a
-- Heroic or Mythic raid, twenty-four for Raid Finder.
local PARTIES = {
    { "butterz", "kaelith", "littlewolf", "seta" },
    { "rookfang", "solenne", "quillshot", "vexxa" },
    { "grimhollow", "mistveil", "nythera", "duskmire" },
    { "brightmane", "starhollow", "emberclaw", "frostlace" },
}
local RAID_20 = { "seta", "littlewolf", "uniquerogue", "butterz", "kaelith", "mistveil", "dawnfeather",
    "thornbrew", "ashveil", "grimhollow", "solenne", "kragmar", "vexxa", "brightmane", "quillshot",
    "nythera", "ironpaw", "starhollow", "rookfang" }
local LFR_25 = { "mossvale", "frostlace", "emberclaw", "duskmire", "palehorn" }
for i, k in ipairs(RAID_20) do LFR_25[5 + i] = k end
TD.PARTIES, TD.RAID_20, TD.LFR_25 = PARTIES, RAID_20, LFR_25

local function looter(key)
    local m = MEMBERS[key]
    return { name = m.name, guid = m.guid, classFile = m.classFile }
end

local function roster(you, keys)
    local GR = NS.GroupRoster
    local out = { GR.Entry({ name = you.name, classFile = you.classFile, isSelf = true }) }
    for _, k in ipairs(keys) do out[#out + 1] = GR.Entry(MEMBERS[k]) end
    return out
end

-- ── the places ──────────────────────────────────────────────────────────────────────────────

-- Each content's group: its kind, its situation and its difficulty's name (a key run's is its level).
local CONTENT = {
    key           = { kind = "run", situation = "mythicPlus" },
    heroicDungeon = { kind = "encounter", situation = "dungeon", difficulty = L["Heroic"] },
    raidHeroic    = { kind = "encounter", situation = "raid", difficulty = L["Heroic"] },
    raidMythic    = { kind = "encounter", situation = "raid", difficulty = L["Mythic"] },
    raidLFR       = { kind = "encounter", situation = "raidLFR", difficulty = L["Looking For Raid"] },
    worldBoss     = { kind = "encounter", situation = "openWorldGroup" },
}
TD.CONTENT = CONTENT

--- A sample group at `where` (a place, or nil): { key, label, kind, situation, instance,
--- difficulty }. A key run is labeled its dungeon at `Mythic+ 10`; a boss its encounter, in its
--- instance at the content's difficulty; a world boss names neither. Pure.
--- @param content string
--- @param where table|nil
--- @param key string
--- @return table
function TD.Group(content, where, key)
    local c = CONTENT[content]
    local g = { key = key, kind = c.kind, situation = c.situation }
    where = where or {}
    if c.kind == "run" then
        g.label = where.instance or L["Placeholder key run"]
        g.instance, g.difficulty = where.instance, L["Mythic+ %d"]:format(TD.KEY_LEVEL)
    else
        g.label = where.encounter or L["Placeholder boss"]
        if content ~= "worldBoss" then g.instance, g.difficulty = where.instance, c.difficulty end
    end
    return g
end

-- ── the drops (pure) ────────────────────────────────────────────────────────────────────────

local function round(n) return math.floor(n + 0.5) end

-- The spec your samples' off-spec is judged against: Protection, whose off-spec is Holy (65).
local OFF_MAIN = 66
TD.OFF_MAIN = OFF_MAIN

-- The item a change implies (a pool item near that level), or nil for no change.
local function baselineOf(src, item, delta)
    if type(delta) ~= "number" then return nil end
    local w = src:Worn(item.facts.equipLoc, round(item.facts.ilvl - delta), item.link)
    return w and { link = w.link, ilvl = w.ilvl } or nil
end

-- The off-spec part NS.OffSpec.Attach shapes (`off` = { specID, verdict, change, bag }): a worn
-- baseline carries the drop's first slot, a bag one (`bag`) none, no change an empty slot (and the
-- kernel's emptySlot reason, which the toast's gain test and the {mygain} words read).
local function offSpecOf(src, item, off, mainSpecID)
    if not off then return nil end
    local base = baselineOf(src, item, off[3])
    local plan = C.SLOT_PLAN[item.facts.equipLoc]
    if base and not off.bag and plan then base.slot = plan.slots[1] end
    return { specID = off[1], mainSpecID = mainSpecID or OFF_MAIN, verdict = off[2], ilvlDelta = off[3],
        baseline = base, baselineSlot = base and base.slot or nil,
        reasons = (base == nil and off[3] == nil) and { { key = "emptySlot" } } or {} }
end

-- The plans whose second slot the sample gear fills (TD.GearFor's): the drop could take either.
local EITHER = { pair = true, weapon1H = true }

-- An evaluation as NS.Evaluate answers it: the verdict, the change, the worn item (a pool item
-- near the level the change implies), `either` when that is the lower of two the sample wears (the
-- kernel's, feedback-21 R5), the kernel's reason key (`reason`) and the off-spec part (`off`, judged
-- for `spec.mainSpec`, else OFF_MAIN).
local function ev(src, item, spec)
    if not spec then return nil end
    local verdict, delta = spec[1], spec[2]
    local reasons = spec.reason and { { key = spec.reason } } or {}
    local base, plan = baselineOf(src, item, delta), C.SLOT_PLAN[item.facts.equipLoc]
    return { verdict = verdict, ilvlDelta = delta, reasons = reasons, baseline = base,
        either = (base and plan and EITHER[plan.kind]) or nil,
        offSpec = offSpecOf(src, item, spec.off, spec.mainSpec) }
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

--- The worn items in a drop's slots, as the Me and Them cells read them ({ [inventory slot] =
--- { link, ilvl } | false }; feedback-18): the one the verdict was judged against (`eval`'s baseline,
--- else the pool item nearest the drop's level), and in a pair's or a one-hander's other slot
--- another of that slot at least as high, so the baseline is the one the drop replaces; a
--- two-hander's or a ranged weapon's off hand empty. Nothing for an `unknown` verdict (no gear to
--- judge by) or an item that is not worn. Pure.
--- @param src table TD.Source's
--- @param item table { link, facts }
--- @param eval table|nil the evaluation the cell shows
--- @return table gear
function TD.GearFor(src, item, eval)
    local loc = item.facts.equipLoc
    local plan = C.SLOT_PLAN[loc]
    if not plan or (eval and eval.verdict == "unknown") then return {} end
    local first = eval and eval.baseline or src:Worn(loc, item.facts.ilvl, item.link)
    if not first then return {} end
    local gear = { [plan.slots[1]] = first }
    local other = plan.slots[2]
    if other and (plan.kind == "pair" or plan.kind == "weapon1H") then
        gear[other] = src:Above(loc, first.ilvl, { [first.link] = true, [item.link] = true }) or first
    elseif other then
        gear[other] = false
    end
    return gear
end

--- The gear an off-spec sample's Me cell reads (feedback-19 spec §4): the item its off-spec verdict
--- was judged against in the drop's first slot (a bag item's too), `false` there for an empty slot;
--- nil when `eval` has no off-spec part NS.OffSpec.Of shows. Pure.
--- @param item table { link, facts }
--- @param eval table|nil the evaluation the cell shows
--- @return table|nil gear
function TD.OffGearFor(item, eval)
    local off = NS.OffSpec.Of(eval)
    local plan = C.SLOT_PLAN[item.facts.equipLoc]
    if not (off and plan) then return nil end
    return { [plan.slots[1]] = off.baseline and { link = off.baseline.link, ilvl = off.baseline.ilvl } or false }
end

-- The looter's inspect entry (status, age, the worn items in the drop's slots, the spec), and the
-- drop's own inspect, the same without the gear, as the feed records it.
local function inspected(src, row, now, them, item)
    local i = row.inspect
    local status, age, reason = i[1], i[2], i[3]
    local good = status == "fresh" or status == "cached"
    local gear = good and TD.GearFor(src, item, them) or {}
    local at = age and now - age or nil
    return { status = status, reason = reason, at = at, gear = gear,
            specID = good and MEMBERS[row.who].specID or nil },
        { status = status, reason = reason, at = at }
end

local function other(src, now, row, where)
    local item = src:Drop(row, where)
    if not item then return nil end
    if row.look ~= nil then item.facts.transmogKnown = row.look end
    local them, me = ev(src, item, row.them), ev(src, item, row.me)
    local testInspect, insp = inspected(src, row, now, them, item)
    return { looter = looter(row.who), link = item.link, facts = item.facts, me = me, testGear = TD.GearFor(src, item, me),
        testOffGear = TD.OffGearFor(item, me), them = them, trade = tradeOf(row, item, them, insp),
        testInspect = testInspect, inspect = insp, testAsk = row.ask }
end

-- One candidate for your own drop: `{ who, verdict, change, off = off-spec }`, judged, checking or
-- unavailable. A Can't use is a wrong armor type, else (one with an off-spec) a spec list.
local REFUSAL = { [true] = "specList", [false] = "armorType" }

local function cand(src, item, c)
    local m = MEMBERS[c[1]]
    local e = { guid = m.guid, name = m.name, classFile = m.classFile }
    if c[2] == "checking" or c[2] == "unavailable" then
        e.status = c[2]
        return e
    end
    e.status, e.eval = "ready", ev(src, item, { c[2], c[3], reason = c[2] == "cantUse" and REFUSAL[c.off ~= nil] or nil,
        off = c.off, mainSpec = m.specID })
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

local function mine(src, now, you, row, where)
    local item = src:Drop(row, where)
    if not item then return nil end
    local candidates = {}
    for _, c in ipairs(row.cands) do
        local e = cand(src, item, c)
        candidates[e.guid] = e
    end
    local me = ev(src, item, row.me)
    return { looter = you, link = item.link, facts = item.facts, me = me, testGear = TD.GearFor(src, item, me),
        testOffGear = TD.OffGearFor(item, me), trade = tradeMine(now, row.trade), candidates = candidates }
end

-- This session, oldest first: a key run four hours ago, then four Heroic raid bosses, the last the
-- off-spec showcase. Each group's `theirs` are the other members' drops, board 03 row by row: the
-- looter, the slot (`strict`: it must be that slot, being armor), Me and Them as { verdict, change,
-- reason = key, off = off-spec }, the trade { state, reasonKey, basis, age }, the inspect
-- { status, age, reason }, the ask state, and the look's state. `yours` are yours, board 04: the slot, Me, the trade and the candidates. Every drop
-- is the group's age; a countdown's is four hours less what is left.
local SESSION = {
    { content = "key", n = 1, party = PARTIES[1], ago = 15000,
      yours = {
        { slot = "INVTYPE_HEAD", me = { "downgrade", -26 }, trade = { "expired" }, cands = {} },
      },
      theirs = {
        { who = "kaelith", slot = "INVTYPE_NECK", me = { "upgrade", 2 }, them = { "downgrade", -4 },
          trade = { "no", "warbound", "bind" }, inspect = { "cached", 900 } },
      } },
    { content = "raidHeroic", n = 1, party = RAID_20, ago = 14000,
      yours = {
        { slot = "INVTYPE_FINGER", me = { "upgrade", 3 }, trade = { "timer", 400 },
          cands = { { "seta", "upgrade", 8 }, { "mistveil", "sidegrade", 1 } } },
        { slot = "INVTYPE_WAIST", me = { "downgrade", -5 }, trade = { "groupLoot" },
          cands = { { "kaelith", "checking" }, { "seta", "cantUse" } } },
      },
      theirs = {
        { who = "butterz", slot = "INVTYPE_HAND", me = { "unknown", reason = "noBaseline" },
          trade = { "no", "bonusRoll", "bind" }, inspect = { "failed", nil, "timeout" } },
        { who = "littlewolf", slot = "INVTYPE_WEAPON", look = false, me = { "doesntWant", reason = "undesired" },
          trade = { "unknown", "noInspect" }, inspect = { "combatParked" } },
        { who = "ashveil", slot = "INVTYPE_CHEST", strict = true, me = { "cantUse", reason = "armorType" },
          them = { "upgrade", 7 }, trade = { "no", "upgradeForLooter", "inspect", 120 }, inspect = { "fresh", 120 } },
      } },
    { content = "raidHeroic", n = 2, party = RAID_20, ago = 7800,
      yours = {
        { slot = "INVTYPE_TRINKET", me = { "downgrade", -6 }, trade = { "timer", 6600 }, cands = {
            { "seta", "upgrade", 14 }, { "butterz", "upgrade", 6 }, { "littlewolf", "sidegrade", 0 },
            { "kaelith", "cantUse", off = { 65, "upgrade", 9 } }, { "uniquerogue", "downgrade", -7 }, { "mistveil", "checking" },
            { "dawnfeather", "unavailable" } } },
      },
      theirs = {
        { who = "uniquerogue", slot = "INVTYPE_TRINKET", me = { "upgrade", 9 },
          trade = { "unknown", "noInspect" }, inspect = { "outOfRange" }, ask = { state = "sent" } },
        { who = "kaelith", slot = "INVTYPE_WRIST", me = { "downgrade", -8 }, them = { "upgrade", 12 },
          trade = { "no", "upgradeForLooter", "inspect", 75 }, inspect = { "fresh", 75 } },
        { who = "seta", slot = "INVTYPE_LEGS", strict = true, me = { "cantUse", reason = "primaryStat", off = { 65, "upgrade", 20 } },
          trade = { "unknown", "noInspect" }, inspect = { "pending" } },
        { who = "dawnfeather", slot = "INVTYPE_FEET", me = { "sidegrade", -1 },
          trade = { "unknown", "noInspect" }, inspect = { "unavailable", nil, "notInGroup" } },
      } },
    { content = "raidHeroic", n = 3, party = RAID_20, ago = 240,
      yours = {
        { slot = "INVTYPE_CLOAK", me = { "downgrade", -10 }, trade = { "boe" },
          cands = { { "butterz", "upgrade", 11 }, { "kaelith", "unavailable" } } },
      },
      theirs = {
        { who = "seta", slot = "INVTYPE_HEAD", look = true, me = { "upgrade", 19 }, them = { "downgrade", -13 },
          trade = { "likely", "notUpgrade", "inspect", 40 }, inspect = { "fresh", 40 } },
        { who = "littlewolf", slot = "INVTYPE_FINGER", me = { "upgrade", 4 }, them = { "sidegrade", 1 },
          trade = { "likely", "notUpgrade", "inspect", 360 }, inspect = { "cached", 360 }, ask = { state = "queued" } },
        { who = "butterz", slot = "INVTYPE_CLOAK", me = { "sidegrade", 0.4, reason = "scoreDisagrees" },
          them = { "upgrade", 6 }, trade = { "yes", "boe", "bind" }, inspect = { "fresh", 90 },
          ask = { state = "failed", reason = L["the chat throttle"] } },
        { who = "mistveil", slot = "INVTYPE_SHOULDER", strict = true, me = { "upgrade", 6 },
          them = { "cantUse", reason = "armorType" }, trade = { "likely", "notUpgrade", "inspect", 20 },
          inspect = { "fresh", 20 }, ask = { state = "traded" } },
      } },
    { content = "raidHeroic", n = 4, party = RAID_20, ago = 60,
      yours = {
        { slot = "INVTYPE_WEAPON", me = { "downgrade", -9 }, trade = { "groupLoot" }, cands = {
            { "seta", "upgrade", 6 }, { "kaelith", "cantUse", off = { 65, "upgrade", 14 } }, { "mistveil", "downgrade", -5 } } },
      },
      theirs = {
        { who = "brightmane", slot = "INVTYPE_WEAPON", me = { "cantUse", reason = "primaryStat", off = { 65, "upgrade" } },
          them = { "sidegrade", 1 }, trade = { "likely", "notUpgrade", "inspect", 30 }, inspect = { "fresh", 30 } },
        { who = "solenne", slot = "INVTYPE_HAND", strict = true,
          me = { "cantUse", reason = "primaryStat", off = { 65, "upgrade", 13, bag = true } },
          them = { "downgrade", -6 }, trade = { "likely", "notUpgrade", "inspect", 45 }, inspect = { "fresh", 45 } },
        { who = "kragmar", slot = "INVTYPE_WRIST", strict = true, me = { "cantUse", reason = "primaryStat", off = { 65, "sidegrade", 1 } },
          them = { "downgrade", -3 }, trade = { "likely", "notUpgrade", "inspect", 50 }, inspect = { "cached", 50 } },
        { who = "thornbrew", slot = "INVTYPE_FEET", strict = true,
          me = { "cantUse", reason = "primaryStat", off = { 65, "downgrade", -11 } },
          them = { "downgrade", -4 }, trade = { "likely", "notUpgrade", "inspect", 55 }, inspect = { "fresh", 55 } },
      } },
}
TD.SESSION = SESSION

--- Every sample drop, as NS.LootFeed.AddTest takes them: the session's groups oldest first, each
--- group's yours then the other members'. Empty when `src` has no item. Pure.
--- @param now number GetTime()
--- @param you table your looter { name, guid, classFile, isSelf = true }
--- @param src table TD.Source's
--- @return table specs
function TD.Placeholders(now, you, src)
    local out = {}
    for i, s in ipairs(SESSION) do
        local where = src:Place(s.content, s.n)
        local group = TD.Group(s.content, where, "test:session:" .. i)
        group.roster = roster(you, s.party)
        local function put(spec)
            if spec then
                spec.group, spec.situation, spec.ago = group, group.situation, s.ago
                out[#out + 1] = spec
            end
        end
        for _, row in ipairs(s.yours) do put(mine(src, now, you, row, where)) end
        for _, row in ipairs(s.theirs) do put(other(src, now, row, where)) end
    end
    return out
end

-- ── the history (pure) ──────────────────────────────────────────────────────────────────────

-- The alt that saw one sample group: an invented character on your realm.
local ALT = { name = "Emberwick", classFile = "WARLOCK" }
TD.ALT = ALT

local MIN, HOUR, DAY = 60, 3600, 86400

-- The other members' drops in turn: Me and Them, the trade { state, reasonKey }, the outcome
-- (`before` under a declined one), and `armor` for a drop a class can be barred from; Me's `off` is
-- an off-spec part (feedback-19 spec §4).
local THEIRS = {
    { me = { "downgrade", -6 }, them = { "upgrade", 9 }, trade = { "no", "upgradeForLooter" }, outcome = "seen" },
    { me = { "upgrade", 7 }, them = { "downgrade", -4 }, trade = { "likely", "notUpgrade" }, outcome = "asked" },
    { me = { "sidegrade", 1 }, them = { "upgrade", 3 }, trade = { "no", "upgradeForLooter" }, outcome = "seen" },
    { me = { "cantUse" }, them = { "upgrade", 13 }, trade = { "no", "upgradeForLooter" }, outcome = "seen", armor = true },
    { me = { "upgrade", 12 }, them = { "downgrade", -9 }, trade = { "likely", "notUpgrade" }, outcome = "received" },
    { me = { "downgrade", -15 }, them = { "upgrade", 4 }, trade = { "no", "upgradeForLooter" }, outcome = "seen" },
    { me = { "upgrade", 3 }, them = { "sidegrade", -1 }, trade = { "likely", "notUpgrade" }, outcome = "declined",
      before = "seen" },
    { me = { "downgrade", -3 }, them = { "downgrade", -2 }, trade = { "likely", "notUpgrade" }, outcome = "seen" },
    { me = { "cantUse", off = { 65, "upgrade", 11 } }, them = { "downgrade", -5 }, trade = { "likely", "notUpgrade" },
      outcome = "asked" },
    { me = { "cantUse", off = { 65, "upgrade", 16 } }, them = { "sidegrade", 0 }, trade = { "likely", "notUpgrade" },
      outcome = "received" },
}

-- Your own drops in turn.
local YOURS = {
    { me = { "downgrade", -8 }, trade = { "yes", "timer" }, outcome = "offered" },
    { me = { "upgrade", 9 }, trade = { "no", "upgradeForLooter" }, outcome = "seen" },
    { me = { "downgrade", -12 }, trade = { "yes", "groupLoot" }, outcome = "tradedAway" },
    { me = { "downgrade", -20 }, trade = { "no", "expired" }, outcome = "expired" },
}

-- The last four weeks, newest first: the content, how long ago, how many drops, which of them was
-- yours (`mine`, its place in the group's drops), and `alt` for the group the alt saw. A raid night
-- is bosses some twenty minutes apart; a key run drops two items, a dungeon boss one or two.
local HISTORY = {
    { content = "raidHeroic", ago = DAY + 2 * HOUR, drops = 5, mine = 2 },
    { content = "raidHeroic", ago = DAY + 2 * HOUR + 25 * MIN, drops = 4 },
    { content = "raidHeroic", ago = DAY + 2 * HOUR + 50 * MIN, drops = 5, mine = 4 },
    { content = "raidHeroic", ago = DAY + 3 * HOUR + 15 * MIN, drops = 4 },
    { content = "key", ago = 2 * DAY + HOUR, drops = 2, mine = 1 },
    { content = "key", ago = 2 * DAY + 2 * HOUR, drops = 2 },
    { content = "raidMythic", ago = 3 * DAY + HOUR, drops = 4, mine = 3 },
    { content = "raidMythic", ago = 3 * DAY + HOUR + 35 * MIN, drops = 4 },
    { content = "raidMythic", ago = 3 * DAY + 2 * HOUR + 10 * MIN, drops = 5 },
    { content = "heroicDungeon", ago = 5 * DAY, drops = 1 },
    { content = "heroicDungeon", ago = 5 * DAY + 15 * MIN, drops = 2, mine = 2 },
    { content = "heroicDungeon", ago = 5 * DAY + 30 * MIN, drops = 1 },
    { content = "worldBoss", ago = 6 * DAY, drops = 3, mine = 1 },
    { content = "key", ago = 8 * DAY, drops = 2 },
    { content = "raidLFR", ago = 9 * DAY, drops = 4, mine = 1 },
    { content = "raidLFR", ago = 9 * DAY + 20 * MIN, drops = 3 },
    { content = "raidLFR", ago = 9 * DAY + 40 * MIN, drops = 5 },
    { content = "raidHeroic", ago = 10 * DAY, drops = 2, mine = 2, alt = true },
    { content = "key", ago = 12 * DAY, drops = 2, mine = 2 },
    { content = "worldBoss", ago = 15 * DAY, drops = 2 },
    { content = "key", ago = 20 * DAY, drops = 2 },
    { content = "key", ago = 27 * DAY, drops = 2, mine = 1 },
}
TD.HISTORY = HISTORY

-- The members of a group of `content`: the raid's, Raid Finder's, else the `n`th party.
local function membersOf(content, n)
    if content == "raidHeroic" or content == "raidMythic" then return RAID_20 end
    if content == "raidLFR" then return LFR_25 end
    return PARTIES[(n - 1) % #PARTIES + 1]
end

-- A History snapshot (NS.History's): an off-spec part as its own, { specID, mainSpecID, verdict, ilvlDelta },
-- unless `plain` (the alt's: a Warlock has no Holy spec, so its Can't use stays plain).
local function snap(spec, plain)
    if not spec then return nil end
    local off = not plain and spec.off or nil
    return { verdict = spec[1], ilvlDelta = spec[2],
        offSpec = off and { specID = off[1], mainSpecID = OFF_MAIN, verdict = off[2], ilvlDelta = off[3] } or nil }
end

-- `seer` is whoever saw the group: you, or the alt (`seenBy`, its recorder key, and its class).
local function historyEntry(src, seer, row, who, at, where)
    local item = src:Drop({ armor = row.armor, strict = row.armor }, where)
    if not item then return nil end
    local f, m = item.facts, who and MEMBERS[who]
    return {
        itemLink = item.link, itemID = item.itemID or NS.Item.ItemIDFromLink(item.link),
        looter = m and m.name or seer.name, class = m and m.classFile or seer.classFile, isMine = m == nil or nil,
        ilvl = f.ilvl, equipLoc = f.equipLoc, quality = f.quality, me = snap(row.me, seer.alt), them = snap(row.them),
        trade = { state = row.trade[1], reasonKey = row.trade[2], basis = "rule", args = {} },
        outcome = row.outcome, before = row.before, at = at, test = true,
        seenBy = seer.seenBy, seenByClass = seer.classFile,
    }
end

-- The alt as a seer: on your realm (the one in your recorder key), else realm-less.
local function altSeer(you)
    local realm = type(you.seenBy) == "string" and you.seenBy:match("%-(.+)$") or nil
    return { name = ALT.name, classFile = ALT.classFile, isSelf = true, alt = true,
        seenBy = NS.CharFilter.Key(ALT.name, realm) }
end

--- The History tab's session-only sample log (FB-10): { v = 1, groups }, HISTORY's groups over
--- real items, oldest first, each at its place with the group its content brings, its drops
--- looted in turn by its members (and the one `mine` names by whoever saw it), every outcome
--- among them. Pure.
--- @param nowEpoch number time()
--- @param you table your looter { name, classFile, seenBy (your recorder key) }
--- @param src table TD.Source's
--- @return table log
function TD.History(nowEpoch, you, src)
    local log, nth, theirs, yours = { v = 1, groups = {} }, {}, 0, 0
    for gi, g in ipairs(HISTORY) do
        nth[g.content] = (nth[g.content] or 0) + 1
        local at, seer = nowEpoch - g.ago, g.alt and altSeer(you) or you
        local where = src:Place(g.content, nth[g.content])
        local members = membersOf(g.content, gi)
        local group = TD.Group(g.content, where, "test:history:" .. gi)
        group.at, group.roster, group.drops = at, roster(seer, members), {}
        group.seenBy, group.seenByClass = seer.seenBy, seer.classFile
        for i = 1, g.drops do
            local row, who
            if i == g.mine then
                yours = yours + 1
                row = YOURS[(yours - 1) % #YOURS + 1]
            else
                theirs = theirs + 1
                row, who = THEIRS[(theirs - 1) % #THEIRS + 1], members[(gi + i - 1) % #members + 1]
            end
            group.drops[#group.drops + 1] = historyEntry(src, seer, row, who, at + i * 20, where)
        end
        if #group.drops > 0 then log.groups[#log.groups + 1] = group end
    end
    table.sort(log.groups, function(a, b) return a.at < b.at end)   -- oldest first, as the log keeps them
    return log
end
