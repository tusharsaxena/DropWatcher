-- tests/test_roll_popup.lua — modules/RollPopup.lua, your verdict on Blizzard's roll popup
-- (Forever port design §7, plan DW-FP20): one owned overlay per GroupLootFrame1..4, anchored above
-- the popup, drawn by one-way OnShow / OnHide hooks that gate on the disabled state, re-check the
-- popup is still shown with a rollID, and never write to Blizzard's frame. Line 1 is the verdict
-- (on WoW Forever a bound-on-pickup drop reads `Need: upgrade` or `Greed / Pass: you can't use it`),
-- line 2 `Need so far: N` from the pending roll its popup claimed (joined by item ID, the oldest
-- unclaimed first: Review Focus 1). Gamepad mode (Forever's GamepadGroupLootRollFrame) is skipped.
-- The popup mark is a both-clients feature, so every case runs on both kit profiles; the BoP
-- wording picks its expectation by NS.Compat.ClientKey().

local T = _G.DW_TEST
local test, assertEqual, assertTrue, assertFalse =
    T.test, T.assertEqual, T.assertTrue, T.assertFalse

local BRAKK, LYRA = "Player-1-0000000A", "Player-2-0000000B"

local function link(id) return ("|cnIQ4:|Hitem:%d::::::::90:::::|h[Item %d]|h|r"):format(id, id) end

local function ring(ilvl)
    return { name = "Item", quality = 4, ilvl = ilvl, equipLoc = "INVTYPE_FINGER", classID = 4,
        subClassID = 0, bindType = 1, stats = {} }
end

local function row(guid, name, realm, classFile)
    return { guid = guid, name = name, realm = realm, class = classFile, classFile = classFile }
end

-- An enabled addon in a party in a Heroic dungeon: the player wears two 600 rings; Brakk and Lyra
-- are in the group; item 300 is a 620 ring (an upgrade for you, +20).
local function party()
    local NS, _, m = T.enableAddon({ mock = function(m)
        m.__context.inInstance, m.__context.instanceType = true, "party"
        m.instance = { name = "The Rookery", difficultyID = 2 }
        m.__decorateUIParent = true   -- the overlays' text regions answer what they say
    end })
    m.addItem(link(100), ring(600))
    m.addItem(link(101), ring(600))
    m.inventory.player[11], m.inventory.player[12] = link(100), link(101)
    m.setGroup({ row(BRAKK, "Brakk", nil, "WARRIOR"), row(LYRA, "Lyra", "Area 52", "PRIEST") })
    NS.Roster.Refresh("test")
    m.addItem(link(300), ring(620))
    return NS, m, NS.RollPopup
end

-- An open drop of item `id`: `needs` players chose Need so far, one more not chosen yet.
local function openDrop(id, needs)
    local rolls = {}
    for i = 1, needs do
        rolls[#rolls + 1] = { playerName = "N" .. i, playerGUID = "Player-9-0000000" .. i, playerClass = "WARRIOR",
            isSelf = false, state = 0, roll = 10 + i, isWinner = false }
    end
    rolls[#rolls + 1] = { playerName = "Lyra", playerGUID = LYRA, playerClass = "PRIEST", isSelf = false,
        state = 4, isWinner = false }
    return { itemHyperlink = link(id), playerRollState = 4, isTied = false, allPassed = false,
        startTime = 100, duration = 60, rollInfos = rolls }
end

-- Your roll popup `rollID` for item `id` (bop by default false).
local function myRoll(m, rollID, id, bop)
    m.lootRolls[rollID] = { link = link(id), quality = 4, bop = bop == true, canNeed = true, canGreed = true }
end

-- Blizzard shows popup `i` for `rollID`.
local function show(m, i, rollID)
    local f = m["GroupLootFrame" .. i]
    f.rollID = rollID
    f:Show()
    return f
end

local function plain(s) return (tostring(s or ""):gsub("|T.-|t", ""):gsub("^%s+", "")) end

local function line1(RP, i) return plain(RP.Overlay(i).line1:GetText()) end
local function line2(RP, i) return plain(RP.Overlay(i).line2:GetText()) end

-- ---------------------------------------------------------------------------------------------

test("roll popup: an upgrade roll shows the mark on GroupLootFrame1", function()
    local NS, m, RP = party()
    myRoll(m, 11, 300)
    m.__fire("START_LOOT_ROLL", 11, 60000)
    local popup = show(m, 1, 11)
    local o = RP.Overlay(1)
    assertTrue(o:IsShown(), "the overlay is up")
    assertEqual(line1(RP, 1), "Upgrade +20")
    local point, rel, relPoint = o:GetPoint()
    assertEqual(point, "BOTTOM"); assertTrue(rel == popup, "anchored to the popup"); assertEqual(relPoint, "TOP")
    assertEqual(o:GetFrameStrata(), NS.Constants.LAYERS.STRATA.ALERT)
    popup:Hide()
    assertFalse(o:IsShown(), "the popup's OnHide takes it down")
end)

-- Review Focus 1: two copies of one item on one boss, each on its own popup, each with its own
-- pending roll (claimed by item ID, the oldest unclaimed first) and its own Need so far.
test("roll popup: two identical items on two popups each show their own Need so far", function()
    local NS, m, RP = party()
    m.lootHistory["2900:1"], m.lootHistory["2900:2"] = openDrop(300, 1), openDrop(300, 2)
    myRoll(m, 11, 300); myRoll(m, 12, 300)
    m.__fire("LOOT_HISTORY_UPDATE_ENCOUNTER", 2900)
    m.__fire("START_LOOT_ROLL", 11, 60000)
    m.__fire("START_LOOT_ROLL", 12, 60000)
    show(m, 1, 11); show(m, 2, 12)
    assertEqual(line2(RP, 1), "Need so far: 1")
    assertEqual(line2(RP, 2), "Need so far: 2")
    -- a third Need on the second drop repaints the second popup only
    local d2 = m.lootHistory["2900:2"]
    d2.rollInfos[3].state, d2.rollInfos[3].roll = 0, 70
    m.__fire("LOOT_HISTORY_UPDATE_DROP", 2900, 2)
    assertEqual(line2(RP, 1), "Need so far: 1")
    assertEqual(line2(RP, 2), "Need so far: 3")
    assertTrue(NS.Pending.ForRoll(12).key == "2900:2")
end)

test("roll popup: a popup closed at once draws nothing", function()
    local _, m, RP = party()
    myRoll(m, 11, 300)
    m.__fire("START_LOOT_ROLL", 11, 60000)
    local popup = m.GroupLootFrame1
    popup.blizzOnShow = function(self) self:Hide() end   -- GroupLootFrame_OnShow removing it again
    show(m, 1, 11)
    assertFalse(RP.Overlay(1):IsShown(), "the hook re-checks IsShown")
    popup.blizzOnShow = nil
    popup.rollID = nil
    popup:Show()
    assertFalse(RP.Overlay(1):IsShown(), "and a nil rollID")
end)

test("roll popup: disabled, the hook draws nothing", function()
    local NS, m, RP = party()
    myRoll(m, 11, 300)
    m.__fire("START_LOOT_ROLL", 11, 60000)
    show(m, 1, 11)
    assertTrue(RP.Overlay(1):IsShown())
    NS.addon:OnSlashCommand("disable")
    assertFalse(RP.Overlay(1):IsShown(), "the stand-down hides it")
    m.GroupLootFrame1:Hide()
    show(m, 1, 11)
    assertFalse(RP.Overlay(1):IsShown(), "the one-way hook gates on the disabled state")
    NS.addon:OnSlashCommand("enable")
    m.activeLootRolls = { 11 }
    m.GroupLootFrame1:Hide()
    show(m, 1, 11)
    assertTrue(RP.Overlay(1):IsShown(), "enabled again, the same hook draws")
    assertEqual(line1(RP, 1), "Upgrade +20")
end)

test("roll popup: popupMark off draws nothing", function()
    local NS, m, RP = party()
    myRoll(m, 11, 300)
    m.__fire("START_LOOT_ROLL", 11, 60000)
    show(m, 1, 11)
    assertTrue(RP.Overlay(1):IsShown())
    assertTrue(NS.SchemaRuntime.Set("rolls.popupMark", false))
    assertFalse(RP.Overlay(1):IsShown(), "turning it off takes the shown mark down")
    m.GroupLootFrame1:Hide()
    show(m, 1, 11)
    assertFalse(RP.Overlay(1):IsShown())
    assertTrue(NS.SchemaRuntime.Set("rolls.popupMark", true))
    assertTrue(RP.Overlay(1):IsShown(), "and back on, the open popup is marked")
end)

test("roll popup: no write to the Blizzard frame table", function()
    local NS, m, RP = party()
    local popup = m.GroupLootFrame1
    local function snapshot()
        local out = {}
        for k, v in pairs(popup) do
            if k ~= "hooks" and k ~= "shown" and k ~= "rollID" then out[#out + 1] = tostring(k) .. "=" .. tostring(v) end
        end
        table.sort(out)
        return table.concat(out, ",")
    end
    assertEqual(#popup.hooks.OnShow, 1, "one OnShow hook, installed once at enable")
    assertEqual(#popup.hooks.OnHide, 1)
    local before = snapshot()
    m.lootHistory["2900:1"] = openDrop(300, 1)
    myRoll(m, 11, 300)
    m.__fire("LOOT_HISTORY_UPDATE_ENCOUNTER", 2900)
    m.__fire("START_LOOT_ROLL", 11, 60000)
    show(m, 1, 11)
    assertTrue(RP.Overlay(1):IsShown())
    m.__fire("CANCEL_LOOT_ROLL", 11)
    popup:Hide()
    NS.addon:OnSlashCommand("disable")
    NS.addon:OnSlashCommand("enable")
    assertEqual(snapshot(), before, "nothing added to or changed on Blizzard's frame")
    assertEqual(#popup.hooks.OnShow, 1, "the stand-up installs no second hook")
end)

test("roll popup: gamepad mode skips", function()
    local _, m, RP = party()
    m.gamepadUI = true
    myRoll(m, 11, 300)
    m.__fire("START_LOOT_ROLL", 11, 60000)
    show(m, 1, 11)
    assertFalse(RP.Overlay(1):IsShown(), "GamepadGroupLootRollFrame shows the rolls: nothing drawn")
    m.gamepadUI = false
    m.GroupLootFrame1:Hide()
    show(m, 1, 11)
    assertTrue(RP.Overlay(1):IsShown())
end)

test("roll popup: Forever BoP cantUse says Greed / Pass", function()
    local NS, m, RP = party()
    local forever = NS.Compat.ClientKey() == "forever"
    -- the pure lines, both shapes
    local cant, up = { verdict = "cantUse", reasons = {} }, { verdict = "upgrade", ilvlDelta = 12, scoreDelta = 4.1, reasons = {} }
    assertEqual(plain(RP.Lines(cant, true, nil, "forever").text), "Greed / Pass: you can't use it")
    assertEqual(RP.Lines(cant, true, nil, "forever").tone, "redMuted")
    assertEqual(plain(RP.Lines(up, true, nil, "forever").text), "Need: upgrade +12 · score +4.1")
    assertEqual(plain(RP.Lines(up, false, nil, "forever").text), "Upgrade +12 · score +4.1", "a BoE drop keeps the verdict word")
    assertEqual(plain(RP.Lines(cant, true, nil, "retail").text), "Can't use")
    assertEqual(plain(RP.Lines(up, true, nil, "retail").text), "Upgrade +12 · score +4.1")
    -- live, on this client
    NS.LootFeed.JudgeMe = function() return { verdict = "cantUse", reasons = {} } end
    myRoll(m, 11, 300, true)
    m.__fire("START_LOOT_ROLL", 11, 60000)
    show(m, 1, 11)
    assertEqual(line1(RP, 1), forever and "Greed / Pass: you can't use it" or "Can't use")
    assertFalse(RP.Overlay(1).line2:IsShown(), "no pending roll: no second line")
end)

test("roll popup: the sim draws it against a stand-in of the popup's size", function()
    local NS, m, RP = party()
    myRoll(m, 11, 300)
    NS.Sim.IsDelivering = function() return true end
    m.__fire("START_LOOT_ROLL", 11, 60000)
    NS.Sim.IsDelivering = function() return false end
    local s = RP.StandIn()
    assertTrue(s and s:IsShown(), "the stand-in is up")
    local o = RP.Overlay("standIn")
    assertTrue(o:IsShown())
    local _, rel = o:GetPoint()
    assertTrue(rel == s, "the overlay sits on the stand-in")
    assertEqual(plain(o.line1:GetText()), "Upgrade +20")
    m.__fire("CANCEL_LOOT_ROLL", 11)
    assertFalse(s:IsShown()); assertFalse(o:IsShown())
end)

-- The popup can come up before its drop reaches the loot history: the item admitted later claims
-- the popup before its PendingChanged goes out, so that message repaints line 2.
test("roll popup: a popup shown before its history drop gets Need so far when the drop lands", function()
    local _, m, RP = party()
    myRoll(m, 11, 300)
    m.__fire("START_LOOT_ROLL", 11, 60000)
    show(m, 1, 11)
    assertTrue(RP.Overlay(1):IsShown())
    assertFalse(RP.Overlay(1).line2:IsShown(), "no pending roll yet")
    m.lootHistory["2900:1"] = openDrop(300, 1)
    m.__fire("LOOT_HISTORY_UPDATE_ENCOUNTER", 2900)
    assertTrue(RP.Overlay(1).line2:IsShown(), "the admitted drop repaints the mark")
    assertEqual(line2(RP, 1), "Need so far: 1")
end)
