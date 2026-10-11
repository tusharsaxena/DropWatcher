local _, NS = ...
-- modules/TestMode.lua — test mode's placeholder drops (design spec §11.6, boards 03 and 06): one
-- drop for every verdict, trade, inspect and ask state the window draws, put in the test feed when
-- test mode turns on and cleared when it turns off, so the layout and position can be checked
-- anywhere, solo and out of an instance.
--
-- THE DATA (pure). TM.Placeholders(now, you) answers the drop specs NS.LootFeed.AddTest takes:
-- two groups (a boss and a key run), eleven drops of other members covering board 03 (Me and Them:
-- upgrade, sidegrade, downgrade, can't use, doesn't want, unknown; Trade: yes, likely, unknown,
-- no; inspect: fresh, cached, pending, out of range, combat, failed, not in the group; Ask: ready,
-- queued, asked, retry, traded and the dash) and five of your own covering board 04 (an exact countdown,
-- one ending soon, an estimated one, a bind-on-equip drop and an expired one, with candidates in
-- every pill: +n UPGRADE, EQUAL, NO UPGRADE, CAN'T USE, CHECKING… and UNAVAILABLE). The crown's look
-- is collected and the spellblade's is not, for the look chips and the transmog ask. Every name and
-- item is invented; nothing names a real player.
--
-- THE HOOKS. A placeholder carries its own inspect entry (`testInspect`, read in place of
-- NS.Inspect.Get) and its own ask state (`testAsk`, shown while the messaging edge holds none for
-- it): TM.InspectOf and TM.AskState are what the Group drops table and the detail card read. A click
-- on a placeholder's Ask, Offer or Announce goes through the messaging edge, which prints the text
-- instead of sending it (modules/Asks.lua): nothing is ever whispered in test mode.
--
-- THE GATES. Placeholders skip the situation and quality gates, ask for no inspect and are never
-- re-judged (modules/LootFeed.lua AddTest). While test mode is on, the Group drops tab's View is
-- All, so every state is on screen; turning it off puts the player's View back.
--
-- NS.SetTestMode (core/DropWatcher.lua) calls Populate and Clear; the stand-down clears too.

NS.TestMode = NS.TestMode or {}
local TM = NS.TestMode
local C  = NS.Constants
local L  = NS.L
local S  = C.SLOT

local TAG = "State"

local savedView   -- the Group drops tab's View before test mode set it to All

-- ── the data (pure) ─────────────────────────────────────────────────────────────────────────

local QUALITY_HEX = { [3] = "ff0070dd", [4] = "ffa335ee" }

-- A placeholder item link: an invented id and name, in its quality's color.
local function link(id, name, quality)
    return ("|c%s|Hitem:%d::::::::80:::::|h[%s]|h|r"):format(QUALITY_HEX[quality] or QUALITY_HEX[4], id, name)
end

local HERO = { name = "Hero", rank = 2, max = 6 }
local MYTH = { name = "Myth", rank = 1, max = 6 }

local function facts(ilvl, equipLoc, quality, track)
    return { ilvl = ilvl, equipLoc = equipLoc, quality = quality or 4, track = track or HERO }
end

-- The facts with the look's state (transmog-known): the detail card's New look and Look known chips.
local function withLook(f, known)
    f.transmogKnown = known
    return f
end

-- An evaluation as NS.Evaluate answers it: the verdict, the change, the worn item's level and the
-- kernel's reason keys.
local function ev(verdict, delta, baseIlvl, ...)
    local reasons = {}
    for _, key in ipairs({ ... }) do reasons[#reasons + 1] = { key = key } end
    local base = baseIlvl and { link = link(990900, L["Worn placeholder"], 4), ilvl = baseIlvl } or nil
    return { verdict = verdict, ilvlDelta = delta, reasons = reasons, baseline = base }
end

local function trade(state, reasonKey, args, basis, age)
    return { state = state, reasonKey = reasonKey, args = args or {}, basis = basis or "rule", age = age }
end

-- The members the placeholders name, all invented.
local MEMBERS = {
    seta        = { name = "Seta", guid = "Player-0-0000T001", classFile = "PRIEST", specID = 257 },
    littlewolf  = { name = "Littlewolf", guid = "Player-0-0000T002", classFile = "DRUID", specID = 105 },
    uniquerogue = { name = "Uniquerogue", guid = "Player-0-0000T003", classFile = "ROGUE", specID = 260 },
    butterz     = { name = "Butterz", guid = "Player-0-0000T004", classFile = "WARRIOR", specID = 71 },
    kaelith     = { name = "Kaelith", guid = "Player-0-0000T005", classFile = "PALADIN", specID = 70 },
    mistveil    = { name = "Mistveil", guid = "Player-0-0000T006", classFile = "MONK", specID = 270 },
    dawnfeather = { name = "Dawnfeather", guid = "Player-0-0000T007", classFile = "EVOKER", specID = 1468 },
}

local function looter(key)
    local m = MEMBERS[key]
    return { name = m.name, guid = m.guid, classFile = m.classFile }
end

-- The looter's inspect entry: its status, age, worn item in `slot` and spec; `drop.inspect` is
-- the same without the gear, as the feed would record it.
local function inspected(key, status, age, now, slot, wornIlvl, reason)
    local gear = {}
    if slot and wornIlvl then gear[slot] = { link = link(990901, L["Worn placeholder"], 4), ilvl = wornIlvl } end
    local good = status == "fresh" or status == "cached"
    local at = age and now - age or nil
    return { status = status, reason = reason, at = at, gear = gear, specID = good and MEMBERS[key].specID or nil },
        { status = status, reason = reason, at = at }
end

local function other(key, item, f, me, them, tr, ti, ask)
    local testInspect, insp = ti[1], ti[2]
    return { looter = looter(key), link = item, facts = f, me = me, them = them, trade = tr,
        testInspect = testInspect, inspect = insp, testAsk = ask }
end

local function pack(...) return { ... } end

-- The other members' drops, board 03 row by row.
local function othersAtBoss(now)
    return {
        other("seta", link(990001, L["Placeholder Crown"], 4), withLook(facts(311, "INVTYPE_HEAD"), true),
            ev("upgrade", 19, 292), ev("downgrade", -13, 324),
            trade("likely", "notUpgrade", { 311, 324 }, "inspect", 40),
            pack(inspected("seta", "fresh", 40, now, S.HEAD, 324)), nil),
        other("littlewolf", link(990002, L["Placeholder Band"], 4), facts(298, "INVTYPE_FINGER"),
            ev("upgrade", 4, 294), ev("sidegrade", 1, 297),
            trade("likely", "notUpgrade", { 298, 297 }, "inspect", 360),
            pack(inspected("littlewolf", "cached", 360, now, S.FINGER1, 297)), { state = "queued" }),
        other("uniquerogue", link(990003, L["Placeholder Charm"], 4), facts(305, "INVTYPE_TRINKET"),
            ev("upgrade", 9, 296), nil, trade("unknown", "noInspect", { "outOfRange" }),
            pack(inspected("uniquerogue", "outOfRange", nil, now)), { state = "sent" }),
        other("butterz", link(990004, L["Placeholder Drape"], 4), facts(301, "INVTYPE_CLOAK", 4, MYTH),
            ev("sidegrade", 0.4, 301, "scoreDisagrees"), ev("upgrade", 6, 295),
            trade("yes", "boe", {}, "bind"),
            pack(inspected("butterz", "fresh", 90, now, S.BACK, 295)), { state = "failed", reason = L["the chat throttle"] }),
        other("kaelith", link(990005, L["Placeholder Vambraces"], 4), facts(300, "INVTYPE_WRIST"),
            ev("downgrade", -8, 308), ev("upgrade", 12, 288),
            trade("no", "upgradeForLooter", { 300, 288 }, "inspect", 75),
            pack(inspected("kaelith", "fresh", 75, now, S.WRIST, 288)), nil),
        other("seta", link(990006, L["Placeholder Legplates"], 4), facts(304, "INVTYPE_LEGS"),
            ev("cantUse", nil, nil, "armorType"), nil, trade("unknown", "noInspect", { "pending" }),
            pack(inspected("seta", "pending", nil, now)), nil),
        other("mistveil", link(990007, L["Placeholder Mantle"], 4), facts(302, "INVTYPE_SHOULDER"),
            ev("upgrade", 6, 296), ev("cantUse", nil, nil, "armorType"),
            trade("likely", "notUpgrade", { 302, 310 }, "inspect", 20),
            pack(inspected("mistveil", "fresh", 20, now, S.SHOULDER, 310)), { state = "traded" }),
        other("dawnfeather", link(990008, L["Placeholder Treads"], 3), facts(289, "INVTYPE_FEET", 3),
            ev("sidegrade", -1, 290), nil, trade("unknown", "noInspect", { "unavailable" }),
            pack(inspected("dawnfeather", "unavailable", nil, now, nil, nil, "notInGroup")), nil),
    }
end

local function othersInRun(now)
    return {
        other("butterz", link(990011, L["Placeholder Gauntlets"], 4), facts(299, "INVTYPE_HAND"),
            ev("unknown", nil, nil, "noBaseline"), nil, trade("no", "bonusRoll", {}, "bind"),
            pack(inspected("butterz", "failed", nil, now, nil, nil, "timeout")), nil),
        other("kaelith", link(990012, L["Placeholder Pendant"], 4), facts(297, "INVTYPE_NECK"),
            ev("upgrade", 2, 295), ev("downgrade", -4, 301), trade("no", "warbound", {}, "bind"),
            pack(inspected("kaelith", "cached", 900, now, S.NECK, 301)), nil),
        other("littlewolf", link(990013, L["Placeholder Spellblade"], 4), withLook(facts(296, "INVTYPE_WEAPON"), false),
            ev("doesntWant", nil, nil, "undesired"), nil, trade("unknown", "noInspect", { "combatParked" }),
            pack(inspected("littlewolf", "combatParked", nil, now)), nil),
    }
end

-- One candidate for your own drop: `verdict` and `delta` when judged, else `checking` or
-- `unavailable`.
local function cand(key, verdict, delta, wornIlvl)
    local m = MEMBERS[key]
    local e = { guid = m.guid, name = m.name, classFile = m.classFile }
    if verdict == "checking" or verdict == "unavailable" then
        e.status = verdict
        return e
    end
    e.status, e.eval = "ready", ev(verdict, delta, wornIlvl, verdict == "cantUse" and "armorType" or nil)
    return e
end

local function byGuid(list)
    local out = {}
    for _, c in ipairs(list) do out[c.guid] = c end
    return out
end

local function mine(you, item, f, me, tr, candidates, ago)
    return { looter = you, link = item, facts = f, me = me, trade = tr, candidates = byGuid(candidates), ago = ago }
end

local function timer(now, left)
    local t = trade("yes", "timer", { left }, "timer")
    t.expiresAt = now + left
    return t
end

-- Your own drops, board 04 row by row: at the boss an exact countdown and a bind-on-equip drop,
-- in the key run one ending soon, an estimated one and an expired one.
local function yoursAtBoss(now, you)
    return {
        mine(you, link(990021, L["Placeholder Idol"], 4), facts(305, "INVTYPE_TRINKET"), ev("downgrade", -6, 311),
            timer(now, 6600), {
                cand("seta", "upgrade", 14, 291), cand("butterz", "upgrade", 6, 299), cand("littlewolf", "sidegrade", 0, 305),
                cand("kaelith", "downgrade", -7, 312), cand("uniquerogue", "cantUse"), cand("mistveil", "checking"),
                cand("dawnfeather", "unavailable"),
            }, 600),
        mine(you, link(990023, L["Placeholder Shroud"], 4), facts(301, "INVTYPE_CLOAK", 4, MYTH), ev("downgrade", -10, 311),
            trade("yes", "boe", {}, "bind"), { cand("butterz", "upgrade", 11, 290), cand("kaelith", "unavailable") }, 240),
    }
end

local function yoursInRun(now, you)
    return {
        mine(you, link(990025, L["Placeholder Cowl"], 3), facts(285, "INVTYPE_HEAD", 3), ev("downgrade", -26, 311),
            trade("no", "expired", { 0, C.TRADE_WINDOW }, "timer"), {}, 7300),
        mine(you, link(990022, L["Placeholder Signet"], 4), facts(298, "INVTYPE_FINGER"), ev("upgrade", 3, 295),
            timer(now, 420), { cand("seta", "upgrade", 8, 290), cand("mistveil", "sidegrade", 1, 297) }, 6780),
        mine(you, link(990024, L["Placeholder Girdle"], 4), facts(299, "INVTYPE_WAIST"), ev("downgrade", -5, 304),
            trade("yes", "groupLoot", {}, "rule"), { cand("kaelith", "checking"), cand("seta", "cantUse") }, 1800),
    }
end

local BOSS = { key = "test:boss", label = L["Placeholder boss"], kind = "encounter" }
local RUN  = { key = "test:run", label = L["Placeholder key run"], kind = "run" }

local function place(list, group, situation, ago)
    for _, spec in ipairs(list) do
        spec.group, spec.situation, spec.ago = group, situation, spec.ago or ago
    end
    return list
end

--- Every placeholder drop, as NS.LootFeed.AddTest takes them: the key run's (yours, then the
--- other members'), then the boss's (theirs, then yours). Pure.
--- @param now number GetTime()
--- @param you table your looter { name, guid, classFile, isSelf = true }
--- @return table specs
function TM.Placeholders(now, you)
    local out = {}
    local parts = {
        place(yoursInRun(now, you), RUN, "mythicPlus"), place(othersInRun(now), RUN, "mythicPlus", 3600),
        place(othersAtBoss(now), BOSS, "raid", 120), place(yoursAtBoss(now, you), BOSS, "raid"),
    }
    for _, list in ipairs(parts) do
        for _, spec in ipairs(list) do out[#out + 1] = spec end
    end
    return out
end

-- ── the hooks the UI reads ──────────────────────────────────────────────────────────────────

--- A drop's looter's inspect entry: a placeholder's own, else NS.Inspect.Get's. Nil for your own
--- drop or a looter with no GUID.
--- @param drop table
--- @return table|nil
function TM.InspectOf(drop)
    if type(drop) ~= "table" or drop.isMine then return nil end
    if drop.test then return drop.testInspect end
    local guid = type(drop.looter) == "table" and drop.looter.guid
    if not guid then return nil end
    return NS.Inspect.Get(guid)
end

--- The ask state a row shows: the messaging edge's, or a placeholder's own while the edge holds
--- none for it (a click on it is the edge's from then on).
--- @param drop table
--- @param state string NS.Asks.StateOf's state
--- @param reason string|nil
--- @return string state, string|nil reason
function TM.AskState(drop, state, reason)
    local own = type(drop) == "table" and drop.test and drop.testAsk
    if state == "ready" and type(own) == "table" then return own.state, own.reason end
    return state, reason
end

-- ── populate and clear ──────────────────────────────────────────────────────────────────────

local function you()
    local name = UnitName("player")
    local _, classFile = UnitClass("player")
    return { name = name or L["You"], guid = UnitGUID("player"), classFile = classFile, isSelf = true }
end

local function showEverything()
    local FB = NS.WindowFilterBar
    if not FB then return end
    savedView = FB.State("group").view
    FB.Set("group", "view", "all")
end

local function restoreView()
    local FB, v = NS.WindowFilterBar, savedView
    savedView = nil
    if FB and v then FB.Set("group", "view", v) end
end

--- Fill the test feed with the placeholders (test mode turned on). The test feed is emptied first.
--- @return number the drops added
function TM.Populate()
    local LF = NS.LootFeed
    LF.Clear("test")
    local n = 0
    for _, spec in ipairs(TM.Placeholders(GetTime(), you())) do
        if LF.AddTest(spec) then n = n + 1 end
    end
    showEverything()
    NS.Debug(TAG, "test mode: %d placeholder drops", n)
    return n
end

--- Empty the test feed (test mode turned off) and put the Group drops tab's View back.
function TM.Clear()
    NS.LootFeed.Clear("test")
    restoreView()
end

NS.STAND_DOWN[#NS.STAND_DOWN + 1] = function()
    TM.Clear()
end
