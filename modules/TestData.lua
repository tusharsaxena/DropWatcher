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
-- or two, a raid boss four or five, and six for the boss that drops the item kinds beside its gear.
--
-- THE DROPS (the Drops tab: this session). Two key runs earlier on, then six Heroic raid bosses
-- tonight, thirty-five drops between them. Up to the sixth boss, the other members' twenty-one cover
-- board 03 (Me and Them: upgrade, sidegrade, downgrade, can't use, doesn't want, unknown; Trade:
-- yes, likely, unknown, no, with every reason the Trade cell words in a few: BoE, warbound, bonus
-- roll, legacy and group loot, their upgrade and not, gear not read, your upgrade, a window open or
-- passed, feedback-22; a unique-equipped ring on both sides; an upgrade that glows and ones that
-- can't, being untradeable; inspect: fresh, cached, pending, out of range, combat, failed, not in
-- the group; Ask: ready, queued, asked, retry, traded and the dash) and your eight cover board 04
-- (an exact countdown, one ending soon, an estimated one, a bind-on-equip drop and an expired one,
-- with candidates in every status the Offer panel shows: upgrade, equal, off-spec upgrade, no
-- upgrade, can't use, checking and unavailable).
-- CAN'T USE (feedback-21). A drop you can use in no spec reads Can't use on Trade where the
-- estimate is Yes or Likely: Mistveil's shoulders (Likely), a wrong armor type; Ashveil's chest stays
-- No (an upgrade for its looter), and every off-spec sample keeps its Likely. Kaelith (second boss)
-- was read before they left the group, so the detail card keeps their spec and says they are not
-- in your group; Dawnfeather left before any read, so it says that instead of spec unknown
-- (feedback-21 H2).
-- Each drop's age is its countdown's: four hours less what is left. One drop's look is collected
-- and one's is not, for the look chips and the transmog ask.
-- ITEM KINDS (issue #13, categories design spec §8). A sixth Heroic boss drops what is not gear:
-- someone's mount new to your collection (its Ask reads No action), a pet you have one of three of,
-- a toy the game gave no answer for, a cosmetic with a New look (no transmog ask) and a tier token
-- that makes a Head, an upgrade you can ask for; and you a recipe for a profession you lack. A
-- collectible is feed-only: no inspect, no candidates, its trade `unknown` for its looter. Its Me
-- carries the collection verdict (`{ verdict, collect = kind, count, limit }`), and its facts the
-- kind and the state NS.Collectibles.Read leaves (`category`, `collect`; a token's `isTierToken`,
-- `tokenSlot` and made `equipLoc`). The item is one of the pool's of that kind (its `extras`), else
-- another pool item that stands in for it.
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
-- weeks (HISTORY): twenty-two groups you saw across Mythic+ 10 runs, Heroic dungeons, Heroic,
-- Mythic and Raid Finder raids and world bosses, mostly drops you only saw and every outcome among
-- them (seen, asked, offered, expired, declined, received, traded away), and one seen by an invented
-- alt on your realm (ALT), so the Character dropdown (feedback-2 spec §4) lists two characters and
-- Current hides the alt's group, a world boss's mount new to your collection beside a pet of yours
-- you already have and a toy, and a raid boss's cosmetic, your recipe and a tier token (issue #13). For the
-- Insights tab (issue #12) the entries carry the stamps a live one does (`askedAt`, `offeredAt`,
-- `settledAt`, `got`), one ask expired unanswered, one received item is legacy (no stamps: its ask
-- inferred, its gain as last judged), Kragmar traded you twice, and the raid bosses' upgrades fill
-- Upgrades for me by boss. The alt's group is ten days old, so a Keep history for of 7 days
-- (feedback-2 spec §5) asks to delete it with the older ones. modules/TestMode.lua holds it while
-- test mode is on; it is never written to the account's history.

NS.TestData = NS.TestData or {}
local TD = NS.TestData
local C  = NS.Constants
local L  = NS.L
local D  = C.DIFFICULTY

-- The client picked once (clients-§5): the people, the places and the groups below are each
-- client's own lists (Forever port design §4.4, §8). The rows a group drops (its `yours` and
-- `theirs`, the boards' states) are the showcase both clients share.
local CLIENT = NS.Compat.ClientKey() == "forever" and "forever" or "retail"

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

-- Retail: the places of one content, in the pool's order: { instance, encounter, items, content } (content:
-- every item of that content, for a drop its place runs short of). A key run's place is its dungeon
-- (the chest drops any of its loot); a boss's is its encounter. A content the pool has nothing of
-- takes every drop, placed the same way.
local function journalPlaces(self, content)
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
    return list
end

-- WoW Forever: no journal places its pool (it is your own gear, Forever port design §4.4), so a
-- content's one place holds every drop and the group names the content's own place (TD.Group).
local function onePlace(self)
    return { { items = self.drops, content = self.drops } }
end

local PLACES = { retail = journalPlaces, forever = onePlace }
local placesFor = PLACES[CLIENT]

local function placesOf(self, content)
    if not self.places[content] then self.places[content] = placesFor(self, content) end
    return self.places[content]
end

--- The `n`th place of `content` (they repeat once the pool runs out of them), or nil for an empty
--- pool.
--- @param content string a CONTENT key: Retail's `key`, `heroicDungeon`, `raidHeroic`, `raidMythic`,
---   `raidLFR`, WoW Forever's `dungeon`, `raid20`, `raid`, and `worldBoss`
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

-- The item kind a sample is (issue #13): a tier token's `kind`, else its Me's collectible kind.
local function kindOf(spec)
    return spec.kind or (type(spec.me) == "table" and spec.me.collect) or nil
end

-- What a collection verdict says of the state: known (collected), not known (new), no answer.
local KNOWN = { newCollect = false, collected = true }

-- The kind on a sample's facts copy, as NS.ItemFacts and NS.Collectibles.Read leave it: a token's
-- made slot (its equipLoc, so it is judged as the piece), a collectible's state and no slot (a
-- cosmetic keeps its own; its state is its look's).
local function stampKind(facts, spec, kind)
    facts.category = kind
    if kind == "tierToken" then
        facts.isTierToken, facts.tokenSlot, facts.tokenSlotSource = true, spec.slot, "table"
        facts.rawEquipLoc, facts.equipLoc = facts.rawEquipLoc or facts.equipLoc, spec.slot
        return
    end
    local me = spec.me
    facts.collect = { kind = kind, known = KNOWN[me[1]], count = me.count, limit = me.limit,
        hasProfession = me[1] == "cantUse" and false or nil }
    if kind == "cosmetic" then
        facts.collect.known, facts.transmogKnown = nil, KNOWN[me[1]]
    else
        facts.equipLoc = ""
    end
end

-- The first unused pool item of a kind (the pool's `extras`), or nil.
local function kindEntry(self, kind)
    if not kind then return nil end
    return firstOf(self.extras[kind] or {}, function(e) return not self.used[e.link] end)
end

--- The sample drop for `spec` at `where`: { link, itemID, facts } (a copy of the facts, the
--- sample's own), or nil when the pool is empty. `spec` is an equip location or { slot | armor,
--- strict, kind | me = { collect = kind } }; `where` a place (nil: anywhere). An item kind draws
--- on the pool's items of that kind first.
--- @param spec string|table
--- @param where table|nil
--- @return table|nil
local function drop(self, spec, where)
    if type(spec) ~= "table" then spec = { slot = spec } end
    local kind = kindOf(spec)
    local e = kindEntry(self, kind) or pickDrop(self, spec, where)
    if not e then return nil end
    self.used[e.link] = true
    local facts = {}
    for k, v in pairs(self.factsOf(e) or {}) do facts[k] = v end
    facts.ilvl = facts.ilvl or e.ilvl
    facts.equipLoc = facts.equipLoc or e.equipLoc
    if kind then stampKind(facts, spec, kind) end
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
--- nil; `extras` are the pool's items that are not gear, by kind ({ [category] = { entry, ... } }).
--- @param drops table
--- @param gear table
--- @param factsOf function
--- @param extras table|nil
--- @return table src { Drop(self, spec, where), Worn(self, equipLoc, target, notLink),
---   Above(self, equipLoc, floor, skip), Place(self, content, n) }
function TD.Source(drops, gear, factsOf, extras)
    return { drops = drops or {}, gear = gear or {}, factsOf = factsOf or function() return nil end,
        extras = extras or {}, used = {}, places = {}, Drop = drop, Worn = worn, Above = above, Place = place }
end

-- ── the people ──────────────────────────────────────────────────────────────────────────────

-- The members the samples name, all invented, one list per client: Retail's thirteen classes, and
-- WoW Forever's nine (no Death Knight, Monk, Demon Hunter or Evoker), each with a spec of that
-- client's list (core/ClassDataForever.lua's "<classFile>:<tree>" rows). The keys are the rows'.
local MEMBER_LISTS = {}
MEMBER_LISTS.retail = {
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
MEMBER_LISTS.forever = {
    seta        = { name = "Seta", guid = "Player-0-0000T001", classFile = "PRIEST", specID = "PRIEST:3" },
    littlewolf  = { name = "Littlewolf", guid = "Player-0-0000T002", classFile = "DRUID", specID = "DRUID:2" },
    uniquerogue = { name = "Uniquerogue", guid = "Player-0-0000T003", classFile = "ROGUE", specID = "ROGUE:2" },
    butterz     = { name = "Butterz", guid = "Player-0-0000T004", classFile = "WARRIOR", specID = "WARRIOR:2" },
    kaelith     = { name = "Kaelith", guid = "Player-0-0000T005", classFile = "PALADIN", specID = "PALADIN:3" },
    mistveil    = { name = "Mistveil", guid = "Player-0-0000T006", classFile = "HUNTER", specID = "HUNTER:1" },
    dawnfeather = { name = "Dawnfeather", guid = "Player-0-0000T007", classFile = "MAGE", specID = "MAGE:2" },
    thornbrew   = { name = "Thornbrew", guid = "Player-0-0000T008", classFile = "WARRIOR", specID = "WARRIOR:3" },
    ashveil     = { name = "Ashveil", guid = "Player-0-0000T009", classFile = "MAGE", specID = "MAGE:3" },
    grimhollow  = { name = "Grimhollow", guid = "Player-0-0000T010", classFile = "WARLOCK", specID = "WARLOCK:1" },
    solenne     = { name = "Solenne", guid = "Player-0-0000T011", classFile = "PRIEST", specID = "PRIEST:2" },
    kragmar     = { name = "Kragmar", guid = "Player-0-0000T012", classFile = "SHAMAN", specID = "SHAMAN:1" },
    vexxa       = { name = "Vexxa", guid = "Player-0-0000T013", classFile = "ROGUE", specID = "ROGUE:1" },
    brightmane  = { name = "Brightmane", guid = "Player-0-0000T014", classFile = "PALADIN", specID = "PALADIN:1" },
    quillshot   = { name = "Quillshot", guid = "Player-0-0000T015", classFile = "HUNTER", specID = "HUNTER:2" },
    nythera     = { name = "Nythera", guid = "Player-0-0000T016", classFile = "WARLOCK", specID = "WARLOCK:2" },
    ironpaw     = { name = "Ironpaw", guid = "Player-0-0000T017", classFile = "DRUID", specID = "DRUID:3" },
    starhollow  = { name = "Starhollow", guid = "Player-0-0000T018", classFile = "SHAMAN", specID = "SHAMAN:3" },
    rookfang    = { name = "Rookfang", guid = "Player-0-0000T019", classFile = "WARRIOR", specID = "WARRIOR:1" },
    mossvale    = { name = "Mossvale", guid = "Player-0-0000T020", classFile = "SHAMAN", specID = "SHAMAN:2" },
    frostlace   = { name = "Frostlace", guid = "Player-0-0000T021", classFile = "MAGE", specID = "MAGE:1" },
    emberclaw   = { name = "Emberclaw", guid = "Player-0-0000T022", classFile = "HUNTER", specID = "HUNTER:3" },
    duskmire    = { name = "Duskmire", guid = "Player-0-0000T023", classFile = "ROGUE", specID = "ROGUE:3" },
    palehorn    = { name = "Palehorn", guid = "Player-0-0000T024", classFile = "WARLOCK", specID = "WARLOCK:3" },
}
local MEMBERS = MEMBER_LISTS[CLIENT]
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

-- Each content's group: its kind, its situation and its difficulty's name (a key run's is its level),
-- one list per client. WoW Forever's has no key run, Heroic, Mythic or Raid Finder: a dungeon (its
-- one difficulty, which the header leaves to the situation's word), a 20-player and a 40-player
-- raid, and a world boss. Its pool is your own gear (no journal places it), so each content names
-- its own place (`place`: an instance and the bosses its groups take in turn).
local CONTENT_LISTS = {
    retail = {
        key           = { kind = "run", situation = "mythicPlus" },
        heroicDungeon = { kind = "encounter", situation = "dungeon", difficulty = L["Heroic"] },
        raidHeroic    = { kind = "encounter", situation = "raid", difficulty = L["Heroic"] },
        raidMythic    = { kind = "encounter", situation = "raid", difficulty = L["Mythic"] },
        raidLFR       = { kind = "encounter", situation = "raidLFR", difficulty = L["Looking For Raid"] },
        worldBoss     = { kind = "encounter", situation = "openWorldGroup" },
    },
    forever = {
        dungeon   = { kind = "encounter", situation = "dungeon", place = { instance = L["Shadowfang Keep"],
            bosses = { L["Razorclaw the Butcher"], L["Baron Silverlaine"], L["Commander Springvale"], L["Archmage Arugal"] } } },
        raid20    = { kind = "encounter", situation = "raid", difficulty = L["20 Player"],
            place = { instance = L["Zul'Gurub"], bosses = { L["High Priestess Jeklik"], L["High Priest Venoxis"],
                L["High Priestess Mar'li"], L["Bloodlord Mandokir"], L["High Priest Thekal"], L["Hakkar"] } } },
        raid      = { kind = "encounter", situation = "raid", difficulty = L["40 Player"],
            place = { instance = L["Molten Core"], bosses = { L["Lucifron"], L["Magmadar"], L["Garr"],
                L["Baron Geddon"], L["Golemagg the Incinerator"], L["Ragnaros"] } } },
        worldBoss = { kind = "encounter", situation = "openWorldGroup", place = { bosses = { L["Azuregos"], L["Lord Kazzak"] } } },
    },
}
local CONTENT = CONTENT_LISTS[CLIENT]
TD.CONTENT = CONTENT

-- The `n`th group of a content's own place (WoW Forever's): its instance and its boss, nil, nil
-- for a content that names none.
local function ownPlace(c, n)
    local p = c.place
    if not p then return nil, nil end
    return p.instance, p.bosses[((n or 1) - 1) % #p.bosses + 1]
end

--- A sample group at `where` (a place, or nil): { key, label, kind, situation, instance,
--- difficulty }. A key run is labeled its dungeon at `Mythic+ 10`; a boss its encounter, in its
--- instance at the content's difficulty; a world boss names neither. A place the pool does not name
--- takes the content's own (WoW Forever's, its `n`th boss), else a placeholder. Pure.
--- @param content string
--- @param where table|nil
--- @param key string
--- @param n number|nil the group's turn among its content's
--- @return table
function TD.Group(content, where, key, n)
    local c = CONTENT[content]
    local g = { key = key, kind = c.kind, situation = c.situation }
    where = where or {}
    if c.kind == "run" then
        g.label = where.instance or L["Placeholder key run"]
        g.instance, g.difficulty = where.instance, L["Mythic+ %d"]:format(TD.KEY_LEVEL)
    else
        local instance, boss = ownPlace(c, n)
        g.label = where.encounter or boss or L["Placeholder boss"]
        if content ~= "worldBoss" then g.instance, g.difficulty = where.instance or instance, c.difficulty end
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
    -- Off-spec is Retail's alone (modules/OffSpec.lua): no sample has one on WoW Forever.
    if not (off and NS.OffSpec.Initialized()) then return nil end
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
-- for `spec.mainSpec`, else OFF_MAIN). `unique` is a unique-equipped ring already worn: the kernel's
-- uniqueEquipped reason, judged against that ring, both rings marked (`either`, feedback-22), the
-- other ring lower (TD.GearFor).
-- A collection verdict as NS.Collectibles.Verdict answers it (issue #13): `spec` = { verdict,
-- collect = kind, count, limit }, its reason the verdict's, a pet's partial count beside it.
local COLLECT_REASON = { newCollect = "collectNew", collected = "collectKnown", collectUnknown = "collectNoAnswer",
    cantUse = "notYourProfession" }

local function collectEv(spec)
    local count, limit = spec.count, spec.limit
    local reasons = { { key = COLLECT_REASON[spec[1]] } }
    if count and limit and count > 0 and count < limit then
        reasons[2] = { key = "petPartial", detail = ("%d/%d"):format(count, limit) }
    end
    return { verdict = spec[1], equip = "collect", collect = true, category = spec.collect, count = count,
        limit = limit, reasons = reasons }
end

local function ev(src, item, spec)
    if not spec then return nil end
    if spec.collect then return collectEv(spec) end
    local verdict, delta = spec[1], spec[2]
    local reasons = spec.reason and { { key = spec.reason } } or {}
    if spec.unique then reasons[#reasons + 1] = { key = "uniqueEquipped" } end
    local base, plan = baselineOf(src, item, delta), C.SLOT_PLAN[item.facts.equipLoc]
    return { verdict = verdict, ilvlDelta = delta, reasons = reasons, baseline = base,
        either = (base and plan and EITHER[plan.kind]) or nil,
        offSpec = offSpecOf(src, item, spec.off, spec.mainSpec) }
end

-- Whether a sample's evaluation is a unique-equipped redirection (`unique` in its spec).
local function isUnique(eval)
    for _, r in ipairs(type(eval) == "table" and eval.reasons or {}) do
        if r.key == "uniqueEquipped" then return true end
    end
    return false
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
--- another of that slot at least as high, so the baseline is the one the drop replaces (lower, for a
--- unique-equipped ring: the drop can replace only the copy worn, feedback-22); a
--- two-hander's or a ranged weapon's off hand empty. Nothing for an `unknown` verdict (no gear to
--- judge by), a collection verdict (judged for your collection, not your gear) or an item that is
--- not worn. Pure.
--- @param src table TD.Source's
--- @param item table { link, facts }
--- @param eval table|nil the evaluation the cell shows
--- @return table gear
-- What a plan's second slot wears beside `first`: a lower copy for a unique-equipped ring, another
-- at least as high for a pair or a one-hander, nothing (false) for a two-hander's off hand.
local function otherWorn(src, item, plan, eval, first)
    local loc = item.facts.equipLoc
    if plan.kind == "pair" and isUnique(eval) then
        local low = src:Worn(loc, first.ilvl - 20, first.link)
        return (low and low.link ~= item.link and low.ilvl < first.ilvl) and low or first
    end
    if plan.kind == "pair" or plan.kind == "weapon1H" then
        return src:Above(loc, first.ilvl, { [first.link] = true, [item.link] = true }) or first
    end
    return false
end

function TD.GearFor(src, item, eval)
    local loc = item.facts.equipLoc
    local plan = C.SLOT_PLAN[loc]
    if not plan or (eval and (eval.verdict == "unknown" or eval.collect)) then return {} end
    local first = eval and eval.baseline or src:Worn(loc, item.facts.ilvl, item.link)
    if not first then return {} end
    local gear = { [plan.slots[1]] = first }
    local other = plan.slots[2]
    if other then gear[other] = otherWorn(src, item, plan, eval, first) end
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
    -- The look is Retail's alone (Forever port design §4.4): no sample has one on WoW Forever.
    if row.look ~= nil and C.FEATURE.transmog then item.facts.transmogKnown = row.look end
    local them, me = ev(src, item, row.them), ev(src, item, row.me)
    local testInspect, insp
    if row.inspect then testInspect, insp = inspected(src, row, now, them, item) end   -- a collectible: none
    return { looter = looter(row.who), link = item.link, facts = item.facts, me = me, testGear = TD.GearFor(src, item, me),
        testOffGear = TD.OffGearFor(item, me), them = them, trade = tradeOf(row, item, them, insp),
        testInspect = testInspect, inspect = insp, testAsk = row.ask, testLeft = row.left or nil }
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
    bonusRoll = function() return trade("no", "bonusRoll", {}, "bind") end,
    -- no trade window showed: the game took it as your upgrade (the drop's level and the worn one's)
    upgradeForYou = function(item, me)
        local wornIlvl = me and me.baseline and me.baseline.ilvl
        return trade("no", "upgradeForYou", { item.facts.ilvl, wornIlvl }, "timer")
    end,
}

local function tradeMine(now, t, item, me)
    if t[1] == "timer" then return timer(now, t[2]) end
    return MY_TRADE[t[1]](item, me)
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
        testOffGear = TD.OffGearFor(item, me), trade = tradeMine(now, row.trade, item, me), candidates = candidates }
end

-- This session, oldest first: two key runs four and a half hours ago and more, then six Heroic raid
-- bosses, the fourth the off-spec showcase, the fifth the trade showcase (feedback-22) and the sixth
-- the item kinds (issue #13). The
-- second key run is the owner's own screenshot: your neck from a bonus roll (No Bonus roll, an
-- upgrade you can't trade on), and another player's copy of a unique-equipped ring you wear, their
-- gear never read (not in your group): You `315 ▲3 / 295 ▲23`, Them `–`, Trade `? Not inspected`.
-- The fifth boss: a unique ring judged for both of you (a mark per ring on both sides, it glows: Yes),
-- an upgrade on group loot (Yes Group loot, it glows), upgrades no one can trade you (legacy loot,
-- their own upgrade: no glow), and your own ring the game took as your upgrade (No Your upgrade). Each group's `theirs` are the other members' drops, board 03 row by row: the
-- looter, the slot (`strict`: it must be that slot, being armor), Me and Them as { verdict, change,
-- reason = key, off = off-spec }, the trade { state, reasonKey, basis, age }, the inspect
-- { status, age, reason }, the ask state, the look's state, and `left` for a looter who has since
-- left the group (the card keeps their read: `testLeft`). `yours` are yours, board 04: the slot, Me, the trade and the candidates. Every drop
-- is the group's age; a countdown's is four hours less what is left.
local SESSION_LISTS = {}
SESSION_LISTS.retail = {
    { content = "key", n = 2, party = PARTIES[2], ago = 16200,
      yours = {
        { slot = "INVTYPE_NECK", me = { "upgrade", 23 }, trade = { "bonusRoll" }, cands = {} },
      },
      theirs = {
        { who = "vexxa", slot = "INVTYPE_FINGER", me = { "upgrade", 3, unique = true },
          trade = { "unknown", "noInspect" }, inspect = { "unavailable", nil, "notInGroup" }, left = true },
      } },
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
          trade = { "no", "upgradeForLooter", "inspect", 75 }, inspect = { "fresh", 75 }, left = true },
        { who = "seta", slot = "INVTYPE_LEGS", strict = true, me = { "cantUse", reason = "primaryStat", off = { 65, "upgrade", 20 } },
          trade = { "unknown", "noInspect" }, inspect = { "pending" } },
        { who = "dawnfeather", slot = "INVTYPE_FEET", me = { "sidegrade", -1 },
          trade = { "unknown", "noInspect" }, inspect = { "unavailable", nil, "notInGroup" }, left = true },
      } },
    { content = "raidHeroic", n = 3, party = RAID_20, ago = 240,
      yours = {
        { slot = "INVTYPE_CLOAK", me = { "downgrade", -10 }, trade = { "boe" },
          cands = { { "butterz", "upgrade", 11 }, { "kaelith", "unavailable" } } },
      },
      theirs = {
        { who = "seta", slot = "INVTYPE_HEAD", look = true, me = { "upgrade", 19 }, them = { "downgrade", -13 },
          trade = { "likely", "notUpgrade", "inspect", 40 }, inspect = { "fresh", 40 }, ask = { state = "traded" } },
        { who = "littlewolf", slot = "INVTYPE_FINGER", me = { "upgrade", 4 }, them = { "sidegrade", 1 },
          trade = { "likely", "notUpgrade", "inspect", 360 }, inspect = { "cached", 360 }, ask = { state = "queued" } },
        { who = "butterz", slot = "INVTYPE_CLOAK", me = { "sidegrade", 0.4, reason = "scoreDisagrees" },
          them = { "upgrade", 6 }, trade = { "yes", "boe", "bind" }, inspect = { "fresh", 90 },
          ask = { state = "failed", reason = L["the chat throttle"] } },
        { who = "mistveil", slot = "INVTYPE_SHOULDER", strict = true, me = { "cantUse", reason = "armorType" },
          them = { "cantUse", reason = "armorType" }, trade = { "likely", "notUpgrade", "inspect", 20 },
          inspect = { "fresh", 20 } },
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
    { content = "raidHeroic", n = 5, party = RAID_20, ago = 30,
      yours = {
        { slot = "INVTYPE_FINGER", me = { "upgrade", 9 }, trade = { "upgradeForYou" }, cands = {} },
      },
      theirs = {
        { who = "mistveil", slot = "INVTYPE_FINGER", me = { "upgrade", 5, unique = true }, them = { "sidegrade", 1 },
          trade = { "likely", "notUpgrade", "inspect", 25 }, inspect = { "fresh", 25 } },
        { who = "grimhollow", slot = "INVTYPE_TRINKET", me = { "upgrade", 8 }, them = { "sidegrade", 2 },
          trade = { "likely", "groupLoot", "rule" }, inspect = { "fresh", 35 } },
        { who = "vexxa", slot = "INVTYPE_WAIST", me = { "upgrade", 6 }, them = { "downgrade", -3 },
          trade = { "no", "legacy", "rule" }, inspect = { "cached", 200 } },
        { who = "quillshot", slot = "INVTYPE_CLOAK", me = { "upgrade", 11 }, them = { "upgrade", 4 },
          trade = { "no", "upgradeForLooter", "inspect", 40 }, inspect = { "fresh", 40 } },
      } },
    -- issue #13: the item kinds (see ITEM KINDS). A collectible's row has no inspect and no candidates.
    { content = "raidHeroic", n = 6, party = RAID_20, ago = 15,
      yours = {
        { me = { "cantUse", collect = "recipe" }, trade = { "boe" }, cands = {} },
      },
      theirs = {
        { who = "seta", me = { "newCollect", collect = "mount" }, trade = { "unknown", "collectible" } },
        { who = "littlewolf", me = { "collected", collect = "pet", count = 1, limit = 3 }, trade = { "yes", "boe", "bind" } },
        { who = "butterz", me = { "collectUnknown", collect = "toy" }, trade = { "unknown", "collectible" } },
        { who = "kaelith", armor = true, me = { "newCollect", collect = "cosmetic" }, trade = { "unknown", "collectible" } },
        { who = "mistveil", kind = "tierToken", slot = "INVTYPE_HEAD", strict = true, me = { "upgrade", 7 },
          them = { "downgrade", -3 }, trade = { "likely", "notUpgrade", "inspect", 30 }, inspect = { "fresh", 30 } },
      } },
}
-- WoW Forever's session, oldest first: two dungeon bosses some four hours ago, then six bosses of a
-- 20-player raid tonight, each dropping the same rows as Retail's group in its place (the showcase).
SESSION_LISTS.forever = {
    { content = "dungeon", n = 1, party = PARTIES[2], ago = 16200 },
    { content = "dungeon", n = 2, party = PARTIES[1], ago = 15000 },
    { content = "raid20", n = 1, party = RAID_20, ago = 14000 },
    { content = "raid20", n = 2, party = RAID_20, ago = 7800 },
    { content = "raid20", n = 3, party = RAID_20, ago = 240 },
    { content = "raid20", n = 4, party = RAID_20, ago = 60 },
    { content = "raid20", n = 5, party = RAID_20, ago = 30 },
    { content = "raid20", n = 6, party = RAID_20, ago = 15 },
}
for i, g in ipairs(SESSION_LISTS.forever) do
    g.yours, g.theirs = SESSION_LISTS.retail[i].yours, SESSION_LISTS.retail[i].theirs
end
local SESSION = SESSION_LISTS[CLIENT]
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
        local group = TD.Group(s.content, where, "test:session:" .. i, s.n)
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

-- ── the pending samples (pure) ──────────────────────────────────────────────────────────────

-- Who is on the sample roll besides you, and what each has chosen so far (Enum.EncounterLootDropRollState:
-- 0 Need, 3 Greed, 4 still choosing, 5 Pass).
local ROLLERS = { { "seta", 0 }, { "kaelith", 0 }, { "brightmane", 0 }, { "butterz", 3 }, { "littlewolf", 3 },
    { "solenne", 4 }, { "kragmar", 4 }, { "ashveil", 5 } }

--- Test mode's pending samples (Forever port design §8), as NS.Pending.AddTest takes them: one open
--- group-loot roll on a drop of the session's last boss, an upgrade for you, with you and eight
--- members on it: three Need, two Greed, two still choosing, one Pass, you not chosen yet, no
--- numbers until it closes. Empty when `src` has no item. Pure.
--- @param you table your looter
--- @param src table TD.Source's
--- @return table specs
function TD.PendingSamples(you, src)
    local last = SESSION[#SESSION]
    local item = src:Drop({ me = { "upgrade", 9 } }, src:Place(last.content, last.n))
    if not item then return {} end
    local rows = { { name = you.name, guid = you.guid, classFile = you.classFile, isSelf = true, state = 4,
        isWinner = false } }
    for _, x in ipairs(ROLLERS) do
        local m = MEMBERS[x[1]]
        rows[#rows + 1] = { name = m.name, guid = m.guid, classFile = m.classFile, isSelf = false, state = x[2],
            isWinner = false }
    end
    return { { kind = "roll", link = item.link, facts = item.facts, me = ev(src, item, { "upgrade", 9 }), ago = 10,
        roll = { link = item.link, key = 1, allPassed = false, isTied = false, myState = 4, rolls = rows } } }
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
    -- every other reason the Trade cell words (feedback-22)
    { me = { "upgrade", 5 }, them = { "sidegrade", 1 }, trade = { "no", "bonusRoll" }, outcome = "seen" },
    { me = { "upgrade", 8 }, them = { "downgrade", -6 }, trade = { "yes", "boe" }, outcome = "asked" },
    { me = { "sidegrade", 2 }, them = { "upgrade", 5 }, trade = { "no", "warbound" }, outcome = "seen" },
    { me = { "upgrade", 4 }, trade = { "unknown", "noInspect" }, outcome = "expired", beforeExpired = "asked" },
    { me = { "downgrade", -5 }, them = { "sidegrade", 0 }, trade = { "likely", "groupLoot" }, outcome = "seen" },
    { me = { "upgrade", 6 }, them = { "downgrade", -2 }, trade = { "no", "legacy" }, outcome = "seen" },
}

-- A world boss's collectibles (issue #13): its mount, new to your collection, a pet of yours you
-- already have (`mine`), and a toy the game gave no answer for.
local COLLECTED = {
    { me = { "newCollect", collect = "mount" }, trade = { "unknown", "collectible" }, outcome = "seen" },
    { me = { "collected", collect = "pet", count = 2, limit = 3 }, trade = { "yes", "boe" }, outcome = "seen", mine = true },
    { me = { "collectUnknown", collect = "toy" }, trade = { "unknown", "collectible" }, outcome = "seen" },
}

-- A Heroic raid boss's other item kinds: a cosmetic with a new look, your recipe for a profession
-- you lack, and a tier token that makes a Head, an upgrade you asked for.
local RAID_KINDS = {
    { me = { "newCollect", collect = "cosmetic" }, trade = { "unknown", "collectible" }, outcome = "seen" },
    { me = { "cantUse", collect = "recipe" }, trade = { "yes", "boe" }, outcome = "seen", mine = true },
    { kind = "tierToken", slot = "INVTYPE_HEAD", me = { "upgrade", 7 }, them = { "downgrade", -3 },
      trade = { "likely", "notUpgrade" }, outcome = "asked" },
}

-- Two old raid nights' boss drops Kragmar traded you (the Most generous section's member who gave
-- twice): the older one from before asks and trades were stamped (`legacy`: its ask inferred from
-- the item received, its gain as last judged), the other stamped and frozen as a trade now is.
local LEGACY_NIGHT = {
    { me = { "upgrade", 6 }, them = { "downgrade", -3 }, trade = { "likely", "notUpgrade" }, outcome = "received",
      legacy = true, giver = "kragmar" },
    { me = { "downgrade", -4 }, them = { "upgrade", 6 }, trade = { "no", "upgradeForLooter" }, outcome = "seen" },
}
local SECOND_TRADE = {
    { me = { "upgrade", 10 }, them = { "sidegrade", 1 }, trade = { "likely", "notUpgrade" }, outcome = "received",
      giver = "kragmar" },
}

-- Your own drops in turn.
local YOURS = {
    { me = { "downgrade", -8 }, trade = { "yes", "timer" }, outcome = "offered" },
    { me = { "upgrade", 9 }, trade = { "no", "upgradeForLooter" }, outcome = "seen" },
    { me = { "downgrade", -12 }, trade = { "yes", "groupLoot" }, outcome = "tradedAway" },
    { me = { "downgrade", -20 }, trade = { "no", "expired" }, outcome = "expired" },
    { me = { "upgrade", 23 }, trade = { "no", "bonusRoll" }, outcome = "seen" },
}

-- The last four weeks, newest first: the content, how long ago, how many drops, which of them was
-- yours (`mine`, its place in the group's drops), `alt` for the group the alt saw, `rolled` for the
-- drop that kept its group-loot roll table (DW-FP17), and `rows` for a
-- group whose drops are its own list rather than the turn of THEIRS and YOURS. A raid night is
-- bosses some twenty minutes apart; a key run drops two items, a dungeon boss one or two.
local HISTORY_LISTS = {}
HISTORY_LISTS.retail = {
    { content = "raidHeroic", ago = DAY + 2 * HOUR, drops = 5, mine = 2 },
    { content = "raidHeroic", ago = DAY + 2 * HOUR + 25 * MIN, drops = 4 },
    { content = "raidHeroic", ago = DAY + 2 * HOUR + 50 * MIN, drops = 5, mine = 4 },
    { content = "raidHeroic", ago = DAY + 3 * HOUR + 15 * MIN, drops = 4 },
    { content = "key", ago = 2 * DAY + HOUR, drops = 2, mine = 1 },
    { content = "key", ago = 2 * DAY + 2 * HOUR, drops = 2 },
    { content = "raidMythic", ago = 3 * DAY + HOUR, drops = 4, mine = 3 },
    { content = "raidMythic", ago = 3 * DAY + HOUR + 35 * MIN, drops = 4 },
    { content = "raidMythic", ago = 3 * DAY + 2 * HOUR + 10 * MIN, drops = 5 },
    { content = "heroicDungeon", ago = 5 * DAY, drops = 1, rolled = 1 },
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
    { content = "worldBoss", ago = 4 * DAY, drops = #COLLECTED, rows = COLLECTED },
    { content = "raidHeroic", ago = 13 * DAY, drops = #RAID_KINDS, rows = RAID_KINDS },
    { content = "raidHeroic", ago = 24 * DAY, drops = #LEGACY_NIGHT, rows = LEGACY_NIGHT },
    { content = "raidHeroic", ago = 17 * DAY, drops = #SECOND_TRADE, rows = SECOND_TRADE },
}
-- WoW Forever's last four weeks, newest first: 20-player raid nights, 40-player raid nights,
-- dungeon bosses and world bosses (its own contents, CONTENT_LISTS.forever).
HISTORY_LISTS.forever = {
    { content = "raid20", ago = DAY + 2 * HOUR, drops = 5, mine = 2 },
    { content = "raid20", ago = DAY + 2 * HOUR + 25 * MIN, drops = 4 },
    { content = "raid20", ago = DAY + 2 * HOUR + 50 * MIN, drops = 5, mine = 4 },
    { content = "raid20", ago = DAY + 3 * HOUR + 15 * MIN, drops = 4 },
    { content = "dungeon", ago = 2 * DAY + HOUR, drops = 2, mine = 1 },
    { content = "dungeon", ago = 2 * DAY + 2 * HOUR, drops = 2 },
    { content = "raid", ago = 3 * DAY + HOUR, drops = 4, mine = 3 },
    { content = "raid", ago = 3 * DAY + HOUR + 35 * MIN, drops = 4 },
    { content = "raid", ago = 3 * DAY + 2 * HOUR + 10 * MIN, drops = 5 },
    { content = "dungeon", ago = 5 * DAY, drops = 1, rolled = 1 },
    { content = "dungeon", ago = 5 * DAY + 15 * MIN, drops = 2, mine = 2 },
    { content = "dungeon", ago = 5 * DAY + 30 * MIN, drops = 1 },
    { content = "worldBoss", ago = 6 * DAY, drops = 3, mine = 1 },
    { content = "dungeon", ago = 8 * DAY, drops = 2 },
    { content = "raid", ago = 9 * DAY, drops = 4, mine = 1 },
    { content = "raid", ago = 9 * DAY + 20 * MIN, drops = 3 },
    { content = "raid", ago = 9 * DAY + 40 * MIN, drops = 5 },
    { content = "raid20", ago = 10 * DAY, drops = 2, mine = 2, alt = true },
    { content = "dungeon", ago = 12 * DAY, drops = 2, mine = 2 },
    { content = "worldBoss", ago = 15 * DAY, drops = 2 },
    { content = "dungeon", ago = 20 * DAY, drops = 2 },
    { content = "dungeon", ago = 27 * DAY, drops = 2, mine = 1 },
    { content = "worldBoss", ago = 4 * DAY, drops = #COLLECTED, rows = COLLECTED },
    { content = "raid20", ago = 13 * DAY, drops = #RAID_KINDS, rows = RAID_KINDS },
    { content = "raid20", ago = 24 * DAY, drops = #LEGACY_NIGHT, rows = LEGACY_NIGHT },
    { content = "raid20", ago = 17 * DAY, drops = #SECOND_TRADE, rows = SECOND_TRADE },
}
local HISTORY = HISTORY_LISTS[CLIENT]
TD.HISTORY = HISTORY

-- The members of a group of `content`: a raid of twenty's (a 20-player raid's on WoW Forever),
-- Raid Finder's (the 40-player raid's on WoW Forever, the most the samples name), else the `n`th
-- party.
local RAID_OF = { raidHeroic = RAID_20, raidMythic = RAID_20, raid20 = RAID_20, raidLFR = LFR_25, raid = LFR_25 }
local function membersOf(content, n)
    return RAID_OF[content] or PARTIES[(n - 1) % #PARTIES + 1]
end

-- A History snapshot (NS.History's): an off-spec part as its own, { specID, mainSpecID, verdict, ilvlDelta },
-- unless `plain` (the alt's: a Warlock has no Holy spec, so its Can't use stays plain). Off-spec is
-- Retail's alone (modules/OffSpec.lua): no History sample has one on WoW Forever.
local function snap(spec, plain)
    if not spec then return nil end
    if spec.collect then
        return { verdict = spec[1], collect = true, category = spec.collect, count = spec.count, limit = spec.limit,
            reasonKey = spec[1] == "cantUse" and "notYourProfession" or nil }
    end
    local off = not plain and NS.OffSpec.Initialized() and spec.off or nil
    return { verdict = spec[1], ilvlDelta = spec[2],
        offSpec = off and { specID = off[1], mainSpecID = OFF_MAIN, verdict = off[2], ilvlDelta = off[3] } or nil }
end

-- THE STAMPS (issue #12, Insights design spec §1.2), as NS.History writes them on a live entry: an
-- ask or offer held in the outcome (or under an expiry) was sent SENT_AFTER the drop; a received
-- or traded-away one was sent then and settled SETTLED_AFTER it (`settledAt`, and `got` on an item
-- received). A `legacy` row keeps none, as an entry recorded before the stamps.
TD.SENT_AFTER, TD.SETTLED_AFTER = 2 * MIN, 6 * MIN
local SENT_KIND = { asked = "ask", received = "ask", offered = "offer", tradedAway = "offer" }
local SETTLES = { received = true, tradedAway = true }

local function stamp(e, row)
    if row.legacy then return e end
    local kind = SENT_KIND[row.beforeExpired or row.outcome]
    if kind then NS.History.Stamp(e, kind, e.at + TD.SENT_AFTER) end
    if SETTLES[row.outcome] then NS.History.Settle(e, row.outcome, e.at + TD.SETTLED_AFTER) end
    return e
end

-- `seer` is whoever saw the group: you, or the alt (`seenBy`, its recorder key, and its class).
local function historyEntry(src, seer, row, who, at, where)
    local item = src:Drop({ armor = row.armor, strict = row.armor, me = row.me, kind = row.kind, slot = row.slot }, where)
    if not item then return nil end
    local f, m = item.facts, who and MEMBERS[who]
    return stamp({
        itemLink = item.link, itemID = item.itemID or NS.Item.ItemIDFromLink(item.link),
        category = f.category, tokenSlot = f.tokenSlot, tokenUsers = f.tokenUsers,
        looter = m and m.name or seer.name, class = m and m.classFile or seer.classFile, isMine = m == nil or nil,
        ilvl = f.ilvl, equipLoc = f.equipLoc, quality = f.quality, me = snap(row.me, seer.alt), them = snap(row.them),
        trade = { state = row.trade[1], reasonKey = row.trade[2], basis = "rule", args = {} },
        outcome = row.outcome, before = row.before, beforeExpired = row.beforeExpired, at = at, test = true,
        seenBy = seer.seenBy, seenByClass = seer.classFile,
    }, row)
end

-- A kept roll table (NS.History's compact shape, Forever port design §5.4): its looter won with a
-- Need 96, then the group's other members and whoever saw it in the roll cells' order (the numbers
-- high to low, then the passes). No GUIDs.
local ROLLED = { { 3, 77 }, { 0, 58 }, { 5 } }
local function rolledOf(e, seer, members, at)
    local r = { { name = e.looter, class = e.class, s = 0, n = 96 } }
    local others = {}
    for _, k in ipairs(members) do
        if MEMBERS[k].name ~= e.looter then others[#others + 1] = MEMBERS[k] end
    end
    for i, x in ipairs(ROLLED) do
        local m = others[i]
        if m then r[#r + 1] = { name = m.name, class = m.classFile, s = x[1], n = x[2] } end
    end
    table.insert(r, #r, { name = seer.name, class = seer.classFile, s = 3, n = 41 })   -- before the pass
    return { at = at, allPassed = false, n = #r, w = 1, r = r }
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
        local group = TD.Group(g.content, where, "test:history:" .. gi, nth[g.content])
        group.at, group.roster, group.drops = at, roster(seer, members), {}
        group.seenBy, group.seenByClass = seer.seenBy, seer.classFile
        for i = 1, g.drops do
            local row, who
            if g.rows then
                row = g.rows[i]
                who = not row.mine and (row.giver or members[(gi + i - 1) % #members + 1]) or nil
            elseif i == g.mine then
                yours = yours + 1
                row = YOURS[(yours - 1) % #YOURS + 1]
            else
                theirs = theirs + 1
                row, who = THEIRS[(theirs - 1) % #THEIRS + 1], members[(gi + i - 1) % #members + 1]
            end
            local e = historyEntry(src, seer, row, who, at + i * 20, where)
            if e and g.rolled == i then e.rolls = rolledOf(e, seer, members, at + i * 20) end
            group.drops[#group.drops + 1] = e
        end
        if #group.drops > 0 then log.groups[#log.groups + 1] = group end
    end
    table.sort(log.groups, function(a, b) return a.at < b.at end)   -- oldest first, as the log keeps them
    return log
end
