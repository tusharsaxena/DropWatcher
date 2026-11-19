-- tests/test_roll_popup.lua — modules/RollPopup.lua, your verdict on Blizzard's roll popup
-- (Forever port design §7, plan DW-FP20; the side card, rolls UX design §3.3, RX-07): one owned
-- card per GroupLootFrame1..4, beside the popup's right edge (top-aligned, gap 4) and flipped to its
-- left near the screen's right edge, in the window's skin (S.Shell), drawn by one-way OnShow /
-- OnHide hooks that gate on the disabled state, re-check the popup is still shown with a rollID, and
-- never write to Blizzard's frame. Line 1 is the verdict (on WoW Forever a bound-on-pickup drop
-- reads `Need: upgrade` or `Greed / Pass: you can't use it`; a non-gear item its kind), line 2 the
-- RollCells count line of the pending roll its popup claimed (joined by item ID, the oldest
-- unclaimed first: Review Focus 1), and a hover shows every roll (RollCells.Tooltip). Gamepad mode
-- (Forever's GamepadGroupLootRollFrame) is skipped.
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
    m.setGroup({ row(BRAKK, "Brakk", nil, "WARRIOR"), row(LYRA, "Lyra", "Mock 52", "PRIEST") })
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

-- ---------------------------------------------------------------------------------------------

test("roll popup: an upgrade roll shows the mark on GroupLootFrame1", function()
    local NS, m, RP = party()
    myRoll(m, 11, 300)
    m.__fire("START_LOOT_ROLL", 11, 60000)
    local popup = show(m, 1, 11)
    local o = RP.Overlay(1)
    assertTrue(o:IsShown(), "the overlay is up")
    assertEqual(line1(RP, 1), "Upgrade +20")
    local point, rel, relPoint, x, y = o:GetPoint()
    assertEqual(point, "TOPLEFT"); assertTrue(rel == popup, "anchored to the popup"); assertEqual(relPoint, "TOPRIGHT")
    assertEqual(x, 4, "a 4 px gap"); assertEqual(y, 0, "top-aligned")
    assertEqual(#o.__points, 1, "one point: the card is placed afresh, never stacked")
    assertEqual(o:GetFrameStrata(), NS.Constants.LAYERS.STRATA.ALERT)
    popup:Hide()
    assertFalse(o:IsShown(), "the popup's OnHide takes it down")
end)

-- RX-04 (rolls UX design §3.5): a lockbox's popup reads Lockbox, a reagent's Reagent (DW-RG1) and
-- an item of no kind Item, never Unknown, and none carries a gain.
-- red under: the popup judging a lockbox through the gear kernel
test("roll popup: a lockbox reads Lockbox, a reagent Reagent and a quest item Item, never Unknown", function()
    local NS, m, RP = party()
    m.addItem(link(400), { name = "Ornate Bronze Lockbox", quality = 2, ilvl = 20, equipLoc = "", classID = 15,
        subClassID = 0, bindType = 0, stats = {} })
    m.tooltips.hyperlink[link(400)] = { lines = { { type = 0, leftText = "Locked" } } }
    m.addItem(link(401), { name = "Linen Cloth", quality = 2, ilvl = 5, equipLoc = "", classID = 7, subClassID = 5,
        bindType = 0, stats = {} })
    myRoll(m, 12, 400)
    m.__fire("START_LOOT_ROLL", 12, 60000)
    show(m, 1, 12)
    assertEqual(line1(RP, 1), NS.L["Lockbox"])
    myRoll(m, 13, 401)
    m.__fire("START_LOOT_ROLL", 13, 60000)
    show(m, 2, 13)
    assertEqual(line1(RP, 2), NS.L["Reagent"])
    m.addItem(link(402), { name = "Sealed Missive", quality = 2, ilvl = 5, equipLoc = "", classID = 12, subClassID = 0,
        bindType = 0, stats = {} })
    myRoll(m, 14, 402)
    m.__fire("START_LOOT_ROLL", 14, 60000)
    show(m, 3, 14)
    assertEqual(line1(RP, 3), NS.L["Item"])
end)

-- Review Focus 1: two copies of one item on one boss, each on its own popup, each with its own
-- pending roll (claimed by item ID, the oldest unclaimed first) and its own count line.
local function needs(NS, rollID) return NS.RollCells.Counts(NS.Pending.ForRoll(rollID).roll).need end

local function countLine(NS, rollID) return NS.RollCells.CountLine(NS.Pending.ForRoll(rollID).roll) end

test("roll popup: two identical items on two popups each show their own count line", function()
    local NS, m, RP = party()
    m.lootHistory["2900:1"], m.lootHistory["2900:2"] = openDrop(300, 1), openDrop(300, 2)
    myRoll(m, 11, 300); myRoll(m, 12, 300)
    m.__fire("LOOT_HISTORY_UPDATE_ENCOUNTER", 2900)
    m.__fire("START_LOOT_ROLL", 11, 60000)
    m.__fire("START_LOOT_ROLL", 12, 60000)
    show(m, 1, 11); show(m, 2, 12)
    assertEqual(RP.Overlay(1).line2:GetText(), countLine(NS, 11), "line 2 is the RollCells count line")
    assertEqual(needs(NS, 11), 1); assertEqual(needs(NS, 12), 2)
    assertEqual(RP.Overlay(2).line2:GetText(), countLine(NS, 12))
    -- a third Need on the second drop repaints the second popup only
    local before = RP.Overlay(1).line2:GetText()
    local d2 = m.lootHistory["2900:2"]
    d2.rollInfos[3].state, d2.rollInfos[3].roll = 0, 70
    m.__fire("LOOT_HISTORY_UPDATE_DROP", 2900, 2)
    assertEqual(RP.Overlay(1).line2:GetText(), before)
    assertEqual(needs(NS, 12), 3)
    assertEqual(RP.Overlay(2).line2:GetText(), countLine(NS, 12))
    assertTrue(NS.Pending.ForRoll(12).key == "2900:2")
    assertFalse(tostring(RP.Overlay(2).line2:GetText()):find("Need so far", 1, true) ~= nil, "Need so far is gone")
end)

-- The side card's place (rolls UX design §3.3): beside the popup's right edge, top-aligned, and to
-- its left once the screen has no room on the right.
local SCREEN_W, POPUP_W, POPUP_H = 1920, 280, 82

local function placePopup(m, i, left, bottom)
    m["GroupLootFrame" .. i].rect = { left, bottom, POPUP_W, POPUP_H }
end

test("roll popup: the side card flips to the popup's left near the screen's right edge", function()
    local _, m, RP = party()
    m.UIParent:__setGeom(SCREEN_W, 1080)
    myRoll(m, 11, 300); myRoll(m, 12, 300)
    m.__fire("START_LOOT_ROLL", 11, 60000)
    m.__fire("START_LOOT_ROLL", 12, 60000)
    placePopup(m, 1, 800, 200)                     -- room on the right
    placePopup(m, 2, SCREEN_W - POPUP_W - 10, 286) -- 10 px from the edge
    local p1, p2 = show(m, 1, 11), show(m, 2, 12)
    local point, rel, relPoint, x = RP.Overlay(1):GetPoint()
    assertEqual(point, "TOPLEFT"); assertTrue(rel == p1); assertEqual(relPoint, "TOPRIGHT"); assertEqual(x, 4)
    local y
    point, rel, relPoint, x, y = RP.Overlay(2):GetPoint()
    assertEqual(point, "TOPRIGHT", "flipped"); assertTrue(rel == p2); assertEqual(relPoint, "TOPLEFT")
    assertEqual(x, -4); assertEqual(y, 0)
    assertEqual(#RP.Overlay(2).__points, 1)
    -- the pure side: right when the popup's right edge, the gap and the card fit
    assertEqual(RP.Side(1000, 200, SCREEN_W), "right")
    assertEqual(RP.Side(SCREEN_W - 100, 200, SCREEN_W), "left")
    assertEqual(RP.Side(nil, 200, SCREEN_W), "right", "an unplaced popup: right")
    assertEqual(RP.Side(1000, 200, nil), "right", "no screen width read: right")
    -- a popup at a larger scale is measured in UIParent's units
    m.GroupLootFrame1.scale = 2
    m.GroupLootFrame1:Hide(); show(m, 1, 11)
    point = RP.Overlay(1):GetPoint()
    assertEqual(point, "TOPRIGHT", "1080 x 2 + the card is past the edge: flipped")
end)

-- A card's rect from its one point and its size, in UIParent's units (popups at scale 1).
local function cardRect(o)
    local point, rel, _, x = o:GetPoint()
    local w, h = o:GetWidth(), o:GetHeight()
    local top = rel:GetTop()
    if point == "TOPLEFT" then return { rel:GetRight() + x, top - h, rel:GetRight() + x + w, top } end
    return { rel:GetLeft() + x - w, top - h, rel:GetLeft() + x, top }
end

local function popupRect(p) return { p:GetLeft(), p:GetBottom(), p:GetRight(), p:GetTop() } end

local function overlaps(a, b) return a[1] < b[3] and b[1] < a[3] and a[2] < b[4] and b[2] < a[4] end

-- Review Focus 1 of the rolls UX plan: four popups at once by the screen's right edge.
test("roll popup: four popups by the right edge each flip and no card overlaps a frame", function()
    local NS, m, RP = party()
    m.UIParent:__setGeom(SCREEN_W, 1080)
    m.lootHistory["2900:1"] = openDrop(300, 2)
    m.__fire("LOOT_HISTORY_UPDATE_ENCOUNTER", 2900)
    local rects = {}
    for i = 1, 4 do
        myRoll(m, 10 + i, 300)
        m.__fire("START_LOOT_ROLL", 10 + i, 60000)
        placePopup(m, i, SCREEN_W - POPUP_W, 200 + (i - 1) * (POPUP_H + 4))
        rects[#rects + 1] = popupRect(show(m, i, 10 + i))
    end
    for i = 1, 4 do
        local o = RP.Overlay(i)
        assertTrue(o:IsShown())
        assertEqual((o:GetPoint()), "TOPRIGHT", "card " .. i .. " flipped")
        assertTrue(o:GetHeight() <= POPUP_H, "a card is no taller than its popup")
        rects[#rects + 1] = cardRect(o)
    end
    for a = 1, #rects do
        for b = a + 1, #rects do
            assertFalse(overlaps(rects[a], rects[b]), ("rect %d and rect %d do not overlap"):format(a, b))
        end
    end
    assertTrue(NS.Pending.ForRoll(11) ~= nil)
end)

-- The window's own skin tokens, not the gray detail box.
test("roll popup: the side card wears the window's skin (S.Shell, no detail box)", function()
    local _, m, RP = party()
    myRoll(m, 11, 300)
    m.__fire("START_LOOT_ROLL", 11, 60000)
    show(m, 1, 11)
    local Skin = m.LibStub("LibKa0s-Skin-1.0")
    local rec = Skin.painted[RP.Overlay(1)]
    assertTrue(rec ~= nil and rec.calls.Shell ~= nil, "S.Shell: win.bg under win.border, as the window")
    assertTrue(rec.calls.Card == nil, "not the detail card's dw.cardBg box")
end)

-- AF-DW-ROLLHDR (the owner's img-17 and img-18, 2026-11-19): the side card carries a small header
-- reading Drop Watcher in the main window's header styling (S.TitleBar: the skin's title band fill,
-- title font and title color), RP.HEADER_H tall, with no window control on it.
-- red under: a card with no header (line 1 at the card's top, RP.PAD in)
test("roll popup: the side card carries a small Drop Watcher header in the window header's skin, no controls", function()
    local NS, m, RP = party()
    myRoll(m, 11, 300)
    m.__fire("START_LOOT_ROLL", 11, 60000)
    show(m, 1, 11)
    local o = RP.Overlay(1)
    local h = o.header
    assertTrue(h ~= nil, "a header")
    assertEqual(h.title:GetText(), NS.L["Drop Watcher"], "it reads Drop Watcher")
    assertEqual(h:GetHeight(), RP.HEADER_H, "a small band, shorter than the window's title bar")
    assertTrue(RP.HEADER_H < NS.Constants.WINDOW.TITLE_H, "scaled down from the window's " .. NS.Constants.WINDOW.TITLE_H)
    local point, rel, relPoint = h:GetPoint(1)
    assertEqual(point, "TOPLEFT"); assertTrue(rel == o, "on the card's top"); assertEqual(relPoint, "TOPLEFT")
    local Skin = m.LibStub("LibKa0s-Skin-1.0")
    local rec = Skin.painted[h]
    assertTrue(rec ~= nil and rec.calls.TitleBar ~= nil, "S.TitleBar, as the window's title bar")
    NS.ShowWindow()
    local bar = Skin.painted[NS.Window.Frame().titleBar]
    assertTrue(bar ~= nil and bar.calls.TitleBar ~= nil, "the window's bar is painted the same way")
    assertTrue(rec.calls.TitleBar[1] and rec.calls.TitleBar[1].text == h.title, "its title is the bar's text")
    for _, key in ipairs({ "closeButton", "settingsButton", "lockButton", "minimizeButton", "headerButtons" }) do
        assertTrue(o[key] == nil and h[key] == nil, "no window control: " .. key)
    end
    assertFalse(h:IsMouseEnabled(), "the header takes no click and no drag")
    local lp, lrel, lrelPoint, lx, ly = unpack(o.line1.__points[1])   -- a region records its points
    assertEqual(lp, "TOPLEFT"); assertTrue(lrel == h, "line 1 under the header"); assertEqual(lrelPoint, "BOTTOMLEFT")
    assertEqual(ly, -RP.PAD)
    assertEqual(lx, RP.PAD - RP.Inset(), "line 1 RP.PAD in from the card's edge")
end)

-- red under: the card's height leaving the header out, so line 2 spills under its bottom edge
test("roll popup: the card's height counts the header and stays shorter than Blizzard's popup", function()
    local _, m, RP = party()
    m.lootHistory["2900:1"] = openDrop(300, 2)
    myRoll(m, 11, 300)
    m.__fire("LOOT_HISTORY_UPDATE_ENCOUNTER", 2900)
    m.__fire("START_LOOT_ROLL", 11, 60000)
    show(m, 1, 11)
    local o = RP.Overlay(1)
    assertTrue(o.line2:IsShown(), "two lines")
    assertEqual(o:GetHeight(), RP.CardHeight(2, RP.Inset()))
    assertEqual(RP.CardHeight(1, 1), 1 + RP.HEADER_H + RP.PAD + RP.LINE + RP.PAD)
    assertEqual(RP.CardHeight(2, 1), 1 + RP.HEADER_H + RP.PAD + 2 * RP.LINE + 2 + RP.PAD)
    for inset = 0, 3 do
        assertTrue(RP.CardHeight(2, inset) <= POPUP_H, "two lines and the header fit the popup's height at inset " .. inset)
    end
    assertTrue(o:GetWidth() >= RP.WIDTH, "at least the least width")
    local point, _, relPoint, x, y = o:GetPoint()
    assertEqual(point, "TOPLEFT"); assertEqual(relPoint, "TOPRIGHT"); assertEqual(x, RP.GAP); assertEqual(y, 0,
        "still top-aligned on Blizzard's popup: the header is inside the card")
end)

-- A non-gear item: its kind word in the neutral tone, no gain (rolls UX design §3.3, §3.5).
test("roll popup: a lockbox's line 1 is its kind in the neutral tone", function()
    local _, _, RP = party()
    local v = RP.Verdict({ collect = true, verdict = "lockbox", category = "lockbox", reasons = {} }, false)
    assertEqual(plain(v.text), "Lockbox"); assertEqual(v.tone, "plain")
    v = RP.Verdict({ collect = true, verdict = "item", category = "other", reasons = {} }, true, "forever")
    assertEqual(plain(v.text), "Item"); assertEqual(v.tone, "plain", "BoP on Forever: still the kind")
end)

-- A hover over the card shows every roll (RollCells.Tooltip): the item, the groups, your verdict.
test("roll popup: a hover over the side card shows every roll", function()
    local NS, m, RP = party()
    m.lootHistory["2900:1"] = openDrop(300, 2)
    myRoll(m, 11, 300)
    m.__fire("LOOT_HISTORY_UPDATE_ENCOUNTER", 2900)
    m.__fire("START_LOOT_ROLL", 11, 60000)
    show(m, 1, 11)
    local o = RP.Overlay(1)
    local tip = NS.Window.TooltipOf(o)
    local want = NS.RollCells.Tooltip(NS.Pending.ForRoll(11).roll, {})
    assertEqual(tip[1], want[1], "the item's name first")
    assertTrue(#tip >= 3, "a row per choice and your verdict")
    o:__fire("OnEnter")
    assertTrue(m.GameTooltip:IsShown(), "the hover shows it")
    assertEqual(m.GameTooltip.__lines[1].text, want[1])
    local all = {}
    for _, l in ipairs(m.GameTooltip.__lines) do all[#all + 1] = tostring(l.text) end
    local text = table.concat(all, "\n")
    assertTrue(text:find("Need", 1, true) ~= nil, "the Need group")
    assertTrue(text:find("Upgrade", 1, true) ~= nil, "your verdict at the foot")
    o:__fire("OnLeave")
    assertFalse(m.GameTooltip:IsShown())
    -- a popup with no pending roll still names its item
    myRoll(m, 12, 300)
    m.__fire("START_LOOT_ROLL", 12, 60000)
    show(m, 2, 12)
    assertTrue(NS.Window.TooltipOf(RP.Overlay(2))[1]:find("Item 300", 1, true) ~= nil)
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

test("roll popup: the sim draws it beside a stand-in of the popup's size, stacked per roll", function()
    local NS, m, RP = party()
    myRoll(m, 11, 300); myRoll(m, 12, 300)
    NS.Sim.IsDelivering = function() return true end
    m.__fire("START_LOOT_ROLL", 11, 60000)
    m.__fire("START_LOOT_ROLL", 12, 60000)
    NS.Sim.IsDelivering = function() return false end
    local s1, s2 = RP.StandIn(1), RP.StandIn(2)
    assertTrue(s1 and s1:IsShown(), "the first stand-in is up")
    assertTrue(s2 and s2:IsShown() and s2 ~= s1, "a second roll stacks a second stand-in")
    assertEqual(s1:GetWidth(), RP.STAND_IN_W); assertEqual(s1:GetHeight(), RP.STAND_IN_H)
    local _, _, _, _, y1 = s1:GetPoint()
    local _, _, _, _, y2 = s2:GetPoint()
    assertEqual(y2 - y1, RP.STAND_IN_H + RP.STAND_IN_GAP + NS.TestStripHeight(), "stacked upward, as the game's own, clear of the strip")
    for n, s in ipairs({ s1, s2 }) do
        local o = RP.Overlay(RP.StandInKey(n))
        assertTrue(o:IsShown())
        local point, rel, relPoint = o:GetPoint()
        assertTrue(rel == s, "the card sits beside its stand-in")
        assertEqual(point, "TOPLEFT"); assertEqual(relPoint, "TOPRIGHT")
        assertEqual(plain(o.line1:GetText()), "Upgrade +20")
    end
    m.__fire("CANCEL_LOOT_ROLL", 11)
    assertFalse(s1:IsShown()); assertFalse(RP.Overlay(RP.StandInKey(1)):IsShown())
    assertTrue(s2:IsShown(), "the other roll's stand-in stays")
    m.__fire("CANCEL_LOOT_ROLL", 12)
    assertFalse(s2:IsShown())
end)

-- The popup can come up before its drop reaches the loot history: the item admitted later claims
-- the popup before its PendingChanged goes out, so that message repaints line 2.
test("roll popup: a popup shown before its history drop gets its count line when the drop lands", function()
    local NS, m, RP = party()
    myRoll(m, 11, 300)
    m.__fire("START_LOOT_ROLL", 11, 60000)
    show(m, 1, 11)
    assertTrue(RP.Overlay(1):IsShown())
    assertFalse(RP.Overlay(1).line2:IsShown(), "no pending roll yet")
    m.lootHistory["2900:1"] = openDrop(300, 1)
    m.__fire("LOOT_HISTORY_UPDATE_ENCOUNTER", 2900)
    assertTrue(RP.Overlay(1).line2:IsShown(), "the admitted drop repaints the mark")
    assertEqual(RP.Overlay(1).line2:GetText(), countLine(NS, 11))
    assertEqual(needs(NS, 11), 1)
end)

-- Rolls panel round 2, ruling A11 (plan RX-22): test mode shows the simulated roll popup and its
-- side card for each sample roll, as `/dw sim roll` does, and takes them down when it ends (by
-- hand or on combat). The stand-in reads the sample's own pending item: no Blizzard rollID.
local function testMode()
    local NS, _, m = T.enableAddon({ mock = function(m) m.__decorateUIParent = true end })
    m.seedGearJournal()
    return NS, m, NS.RollPopup
end

local function quietTest(NS, m, on)
    local p0 = m.print
    m.print = function() end
    NS.SetTestMode(on)
    m.print = p0
end

-- red under: test mode drawing no stand-in (RX-22, ruling A11)
test("roll popup: test mode shows a stand-in popup with its side card per sample roll, and off hides them", function()
    local NS, m, RP = testMode()
    quietTest(NS, m, true)
    local samples = NS.Pending.All("test")
    assertTrue(#samples > 0, "test mode holds a sample roll")
    for n, item in ipairs(samples) do
        local s = RP.StandIn(n)
        assertTrue(s ~= nil and s:IsShown(), "a stand-in per sample roll")
        assertEqual(s.title:GetText(), NS.L["Roll popup (test)"], "titled as test mode's")
        assertEqual(s.item:GetText(), item.link)
        local o = RP.Overlay(RP.StandInKey(n))
        assertTrue(o:IsShown(), "its side card")
        local _, rel = o:GetPoint()
        assertTrue(rel == s, "beside its stand-in")
        assertTrue(o.line1:GetText():find(NS.L["Upgrade"], 1, true) ~= nil, "the sample's verdict")
        assertEqual(o.line2:GetText(), NS.RollCells.CountLine(item.roll), "the sample's count line")
        assertTrue(T.tipPlainJoined(NS.Window.TooltipOf(o)):find(NS.L["Need"], 1, true) ~= nil, "every roll on hover")
    end
    assertTrue(RP.StandIn(#samples + 1) == nil or not RP.StandIn(#samples + 1):IsShown(), "no more than the samples")
    quietTest(NS, m, false)
    for n = 1, #samples do
        assertFalse(RP.StandIn(n):IsShown(), "test mode off takes the stand-in down")
        assertFalse(RP.Overlay(RP.StandInKey(n)):IsShown(), "and its side card")
    end
    quietTest(NS, m, true)
    assertTrue(RP.StandIn(1):IsShown(), "test mode on again shows it again")
    quietTest(NS, m, false)
end)

-- red under: the stand-in left up when combat ends test mode
test("roll popup: combat ends test mode and takes its stand-in down; the popup mark off draws none", function()
    local NS, m, RP = testMode()
    quietTest(NS, m, true)
    assertTrue(RP.StandIn(1):IsShown())
    m.inCombat = true
    m.__fire("PLAYER_REGEN_DISABLED")
    assertFalse(NS.State.testMode)
    assertFalse(RP.StandIn(1):IsShown(), "combat takes it down")
    assertFalse(RP.Overlay(RP.StandInKey(1)):IsShown())
    m.inCombat = false
    m.__fire("PLAYER_REGEN_ENABLED")
    NS.SchemaRuntime.Set("rolls.popupMark", false)
    quietTest(NS, m, true)
    assertFalse(RP.StandIn(1):IsShown(), "the popup mark off: no stand-in")
    quietTest(NS, m, false)
end)

-- A HUD strip docked on frame `f`'s top edge, outside it (preview-mode, *Where the strip sits*).
local function onTop(strip, f)
    local pt = strip and strip.__points and strip.__points[1]
    return pt ~= nil and pt[1] == "BOTTOMLEFT" and pt[2] == f and pt[3] == "TOPLEFT"
end

-- red under: the stand-in and its side card drawing test mode's samples with no strip (RX-23:
-- preview-mode's *Where the strip sits*, a HUD display of test data carries the strip on its top
-- edge, outside it; anti-pattern #97)
test("roll popup: in test mode each stand-in and its side card carry the test strip on their top edge", function()
    local NS, m, RP = testMode()
    quietTest(NS, m, true)
    local s, o = RP.StandIn(1), RP.Overlay(RP.StandInKey(1))
    assertTrue(s.testStrip ~= nil and s.testStrip:IsShown(), "the stand-in's test strip")
    assertTrue(onTop(s.testStrip, s), "docked on the stand-in's top edge, outside it")
    assertFalse(s.simStrip:IsShown(), "not the sim flavor")
    assertEqual(s.testStrip.text:GetText(), NS.L["TEST: a sample roll. Nothing is rolled."])
    assertTrue(o.testStrip ~= nil and o.testStrip:IsShown(), "the side card's test strip")
    assertTrue(onTop(o.testStrip, o), "docked on the card's top edge")
    assertFalse(o.simStrip:IsShown())
    quietTest(NS, m, false)
    assertFalse(s:IsShown())
end)

-- red under: the simulation's stand-in with no sim strip, or stacked with no room for it
test("roll popup: a simulated roll's stand-in and side card carry the sim strip, stacked clear of it", function()
    local NS, m, RP = party()
    myRoll(m, 11, 300); myRoll(m, 12, 300)
    NS.Sim.IsDelivering = function() return true end
    m.__fire("START_LOOT_ROLL", 11, 60000)
    m.__fire("START_LOOT_ROLL", 12, 60000)
    NS.Sim.IsDelivering = function() return false end
    local s1, s2 = RP.StandIn(1), RP.StandIn(2)
    for n, s in ipairs({ s1, s2 }) do
        local o = RP.Overlay(RP.StandInKey(n))
        assertTrue(s.simStrip ~= nil and s.simStrip:IsShown(), "the stand-in's sim strip")
        assertTrue(onTop(s.simStrip, s))
        assertFalse(s.testStrip:IsShown())
        assertEqual(s.simStrip.text:GetText(), NS.L["SIM: a simulated roll. Nothing is rolled."])
        assertTrue(o.simStrip ~= nil and o.simStrip:IsShown() and onTop(o.simStrip, o), "the card's sim strip")
    end
    local _, _, _, _, y1 = s1:GetPoint()
    local _, _, _, _, y2 = s2:GetPoint()
    assertEqual(y2 - y1, RP.STAND_IN_H + RP.STAND_IN_GAP + NS.TestStripHeight(), "the next stand-in clears the strip")
    m.__fire("CANCEL_LOOT_ROLL", 11); m.__fire("CANCEL_LOOT_ROLL", 12)
end)

-- red under: the stack's base fixed at STAND_IN_Y, so on a 768-high screen the third and fourth
-- stand-ins ran off its top (RX-30: the sim stand-ins stay on screen)
test("rx30: StandInY keeps the whole stack of stand-ins on the screen, the first at STAND_IN_Y while it fits", function()
    local RP = T.newAddon().RollPopup
    local pitch = RP.STAND_IN_H + RP.STAND_IN_GAP + 18
    assertEqual(RP.StandInY(1, 1440, 18), RP.STAND_IN_Y, "a tall screen: the first where it always was")
    assertEqual(RP.StandInY(2, 1440, 18) - RP.StandInY(1, 1440, 18), pitch, "each next a pitch higher")
    for n = 1, RP.STAND_INS do
        local top = 768 / 2 + RP.StandInY(n, 768, 18) + RP.STAND_IN_H / 2 + 18
        assertTrue(top <= 768, "stand-in " .. n .. " and its strip inside a 768-high screen: " .. top)
    end
    assertEqual(RP.StandInY(1, nil, 18), RP.STAND_IN_Y, "no screen read: as before")
end)

-- red under: a stand-in fixed where it was built, and never clamped (RX-30: it can show the flip)
test("rx30: a stand-in is clamped to the screen and drags, its card taking the side the screen leaves", function()
    local NS, m, RP = party()
    local base = m.CreateFrame
    m.CreateFrame = function(...)
        local f = base(...)
        f.SetClampedToScreen = function(self, on) self.__clamped = on end
        f.SetMovable = function(self, on) self.__movable = on end
        return f
    end
    myRoll(m, 11, 300)
    NS.Sim.IsDelivering = function() return true end
    m.__fire("START_LOOT_ROLL", 11, 60000)
    NS.Sim.IsDelivering = function() return false end
    m.CreateFrame = base
    local s, o = RP.StandIn(1), RP.Overlay(RP.StandInKey(1))
    assertTrue(s.__clamped == true, "clamped to the screen")
    assertTrue(s.__movable == true, "movable")
    o.GetWidth = function() return RP.WIDTH end
    m.UIParent.GetWidth = function() return 1920 end
    s.GetRight = function() return 1100 end
    NS.RollPopup.Refresh()
    assertEqual((o:GetPoint()), "TOPLEFT", "centered: the card on the right")
    -- Dragged to the screen's right edge: on the drop the card flips to the left.
    s.GetRight = function() return 1916 end
    s:__fire("OnDragStart")
    s:__fire("OnDragStop")
    assertEqual((o:GetPoint()), "TOPRIGHT", "flipped: the card on the left")
    m.__fire("CANCEL_LOOT_ROLL", 11)
end)
