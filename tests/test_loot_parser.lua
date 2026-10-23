-- tests/test_loot_parser.lua — modules/LootParser.lua (design spec §4, §15): every LOOT_ITEM*
-- GlobalString variant, self and third person, single and multiple; bonus roll and pushed; the
-- looter resolved through the roster (same realm, cross-realm, unknown); the upgrade and crafting
-- echoes rejected; a non-item link; secret text and secret globals; globals rewritten at runtime
-- (PrettyChat) and another client language, positional arguments included; the CHAT_MSG_LOOT
-- edge with its sinks and counters; and the stand-down.

local T = _G.DW_TEST
local test, assertEqual, assertTrue, assertFalse, assertNil =
    T.test, T.assertEqual, T.assertTrue, T.assertFalse, T.assertNil

local BAND  = "|cnIQ4:|Hitem:2001::::::::90:::::|h[Band]|h|r"
local OTHER = "|cnIQ3:|Hitem:2002::::::::90:::::|h[Hauberk]|h|r"
local PET   = "|cffffd200|Hbattlepet:868:1:3:155:12:12:0x0|h[Pet]|h|r"
local ME    = "Player-1-00000001"
local BRAKK = "Player-1-0000000A"
local LYRA  = "Player-2-0000000B"
local EVENT = "CHAT_MSG_LOOT"

local function row(guid, name, realm, classFile)
    return { guid = guid, name = name, realm = realm, class = classFile, classFile = classFile }
end

-- An enabled instance in a party: the player, a same-realm warrior and a cross-realm priest.
local function party(seed)
    local NS, _, m = T.enableAddon({ mock = seed })
    m.setGroup({ row(BRAKK, "Brakk", nil, "WARRIOR"), row(LYRA, "Lyra", "Area 52", "PRIEST") })
    m.__fire("GROUP_ROSTER_UPDATE")
    return NS, m, NS.LootParser
end

local function installSecrets(m)
    m.issecretvalue = T.isSecret
    m.canaccessvalue = function(v) return not T.isSecret(v) end
end

-- Fire CHAT_MSG_LOOT with the client's twelve leading arguments; `guid` is the twelfth.
local function fireLoot(m, text, guid)
    return m.__fire(EVENT, text, "", "", "", "", "", 0, 0, "", 0, 1, guid)
end

-- ---------------------------------------------------------------------------------------------
-- Every variant
-- ---------------------------------------------------------------------------------------------

-- { line, kind, isSelf, qty }, one per GlobalString the parser reads.
local VARIANTS = {
    { "You receive loot: " .. BAND .. ".",            "loot",   true,  1 },
    { "You receive loot: " .. BAND .. "x3.",          "loot",   true,  3 },
    { "You receive bonus loot: " .. BAND .. ".",      "bonus",  true,  1 },
    { "You receive bonus loot: " .. BAND .. "x2.",    "bonus",  true,  2 },
    { "You receive item: " .. BAND .. ".",            "pushed", true,  1 },
    { "You receive item: " .. BAND .. "x5.",          "pushed", true,  5 },
    { "Brakk receives loot: " .. BAND .. ".",         "loot",   false, 1 },
    { "Brakk receives loot: " .. BAND .. "x4.",       "loot",   false, 4 },
    { "Brakk receives bonus loot: " .. BAND .. ".",   "bonus",  false, 1 },
    { "Brakk receives bonus loot: " .. BAND .. "x2.", "bonus",  false, 2 },
    { "Brakk receives item: " .. BAND .. ".",         "pushed", false, 1 },
    { "Brakk receives item: " .. BAND .. "x12.",      "pushed", false, 12 },
}

for _, v in ipairs(VARIANTS) do
    test("loot parser: " .. v[2] .. (v[3] and " (self)" or " (other)") .. " x" .. v[4], function()
        local _, _, LP = party()
        local loot = LP.Parse(v[1])
        assertTrue(loot ~= nil, v[1])
        assertEqual(loot.link, BAND, "the link stops before the quantity")
        assertEqual(loot.kind, v[2])
        assertEqual(loot.qty, v[4])
        assertEqual(loot.isSelf, v[3])
        if v[3] then
            assertEqual(loot.looterName, "Testchar-Testrealm")
            assertEqual(loot.looterGUID, ME)
        else
            assertEqual(loot.looterName, "Brakk-Testrealm", "a same-realm name gains the realm")
            assertEqual(loot.looterGUID, BRAKK)
        end
    end)
end

-- ---------------------------------------------------------------------------------------------
-- The looter
-- ---------------------------------------------------------------------------------------------

test("loot parser: a cross-realm looter resolves to the member", function()
    local _, _, LP = party()
    local loot = LP.Parse("Lyra-Area52 receives loot: " .. OTHER .. ".")
    assertEqual(loot.looterName, "Lyra-Area52")
    assertEqual(loot.looterGUID, LYRA)
    assertEqual(LP.Parse("Lyra-Area52 receives loot: " .. OTHER .. "x2.").qty, 2)
end)

test("loot parser: a player hyperlink or color around the name is stripped", function()
    local _, _, LP = party()
    local linked = "|Hplayer:Lyra-Area52:12:LOOT|h[Lyra-Area52]|h receives loot: " .. OTHER .. "."
    assertEqual(LP.Parse(linked).looterGUID, LYRA)
    local colored = "|cffc41e3aBrakk|r receives loot: " .. OTHER .. "."
    assertEqual(LP.Parse(colored).looterGUID, BRAKK)
end)

test("loot parser: a looter the roster cannot place keeps the name and the event's GUID", function()
    local _, _, LP = party()
    local loot = LP.Parse("Stranger-Elsewhere receives loot: " .. OTHER .. ".", "Player-9-00000009")
    assertEqual(loot.looterName, "Stranger-Elsewhere")
    assertEqual(loot.looterGUID, "Player-9-00000009")
    assertNil(LP.Parse("Stranger receives loot: " .. OTHER .. ".", "Creature-0-1-2-3-4-5").looterGUID,
        "a GUID that is not a player's is not used")
    assertNil(LP.Parse("Stranger receives loot: " .. OTHER .. ".").looterGUID)
end)

test("loot parser: the roster's member wins over the event's GUID", function()
    local _, _, LP = party()
    assertEqual(LP.Parse("Brakk receives loot: " .. OTHER .. ".", "Player-9-00000009").looterGUID, BRAKK)
end)

-- ---------------------------------------------------------------------------------------------
-- Rejected and ignored lines
-- ---------------------------------------------------------------------------------------------

test("loot parser: the upgrade echo and the crafting echoes are rejected", function()
    local _, _, LP = party()
    local lines = {
        "Changed " .. OTHER .. " to " .. BAND .. ".",
        "You create: " .. BAND .. ".",
        "You create: " .. BAND .. "x2.",
        "Brakk creates: " .. BAND .. ".",
        "Brakk creates: " .. BAND .. "x3.",
    }
    for _, line in ipairs(lines) do
        local loot, why = LP.Parse(line)
        assertNil(loot, line)
        assertEqual(why, "rejected", line)
    end
end)

test("loot parser: a line that is not a receipt, a non-item link and an empty line are ignored", function()
    local _, _, LP = party()
    local loot, why = LP.Parse("Brakk has selected Need for: " .. BAND)
    assertNil(loot); assertEqual(why, "noMatch")
    loot, why = LP.Parse("Brakk receives loot: " .. PET .. ".")
    assertNil(loot); assertEqual(why, "notItem")
    loot, why = LP.Parse("")
    assertNil(loot); assertEqual(why, "empty")
    loot, why = LP.Parse(nil)
    assertNil(loot); assertEqual(why, "empty")
end)

-- ---------------------------------------------------------------------------------------------
-- Secrets
-- ---------------------------------------------------------------------------------------------

test("loot parser: secret text is dropped before any pattern touches it", function()
    local _, m, LP = party()
    installSecrets(m)
    -- red under: drop the IsSecret check in parse(); the line is then dropped as "empty", uncounted
    -- as secret, and the diagnostics could not answer COMBAT-1
    local loot, why = LP.Parse(T.secret("Brakk receives loot: " .. BAND .. "."))
    assertNil(loot)
    assertEqual(why, "secret")
end)

test("loot parser: a secret event GUID is not used", function()
    local _, m, LP = party()
    installSecrets(m)
    local loot = LP.Parse("Stranger receives loot: " .. OTHER .. ".", T.secret("Player-9-00000009"))
    assertEqual(loot.looterName, "Stranger")
    assertNil(loot.looterGUID)
end)

test("loot parser: a secret, empty or absent GlobalString is left out of the set", function()
    local _, m, LP = party()
    installSecrets(m)
    m.LOOT_ITEM = T.secret("%s receives loot: %s.")
    m.LOOT_ITEM_MULTIPLE = ""
    m.LOOT_ITEM_PUSHED = nil
    assertEqual(#LP.Rebuild(), #LP.SHAPES - 3)
    assertNil(LP.Parse("Brakk receives loot: " .. BAND .. "."), "its line is not read")
    assertEqual(LP.Parse("You receive loot: " .. BAND .. ".").kind, "loot", "the others still are")
end)

-- ---------------------------------------------------------------------------------------------
-- Globals rewritten at runtime, and other client languages
-- ---------------------------------------------------------------------------------------------

test("loot parser: a GlobalString rewritten at runtime (PrettyChat) is rebuilt on the next line", function()
    local _, m, LP = party()
    assertEqual(LP.Parse("Brakk receives loot: " .. BAND .. ".").looterGUID, BRAKK)
    local original = m.LOOT_ITEM
    m.LOOT_ITEM = "|cff00ff00Loot|r %s +%s"
    assertNil(LP.Parse("Brakk receives loot: " .. BAND .. "."), "the old spelling no longer reads")
    local loot = LP.Parse("|cff00ff00Loot|r Brakk +" .. BAND)
    assertEqual(loot.looterGUID, BRAKK, "the new spelling does")
    assertEqual(loot.link, BAND)
    m.LOOT_ITEM = original
    assertEqual(LP.Parse("Brakk receives loot: " .. BAND .. ".").looterGUID, BRAKK, "and back again")
end)

test("loot parser: a pushed or created string identical to a loot string reads as loot (PrettyChat)", function()
    -- red under: the parser that tried the pushed shapes first, so with PrettyChat's defaults
    -- (LOOT_ITEM_PUSHED* spelled exactly as LOOT_ITEM*) every loot line read as pushed and your own
    -- drops were refused (the owner's /dw sim on 2026-10-23: `refused [Saptor Salve]: pushed`)
    local _, m, LP = party()
    local SELF, OTHER_FMT = "|cffff0000Loot|r | You | + %s", "|cffff0000Loot|r | %s | + %s"
    m.LOOT_ITEM_SELF, m.LOOT_ITEM_PUSHED_SELF = SELF, SELF
    m.LOOT_ITEM, m.LOOT_ITEM_PUSHED = OTHER_FMT, OTHER_FMT
    m.LOOT_ITEM_SELF_MULTIPLE, m.LOOT_ITEM_PUSHED_SELF_MULTIPLE = SELF .. " x%d", SELF .. " x%d"
    m.CREATED_ITEM = OTHER_FMT
    local mine = LP.Parse("|cffff0000Loot|r | You | + " .. BAND)
    assertEqual(mine.kind, "loot", "your own line is loot, not pushed")
    assertEqual(mine.looterGUID, ME)
    assertEqual(LP.Parse("|cffff0000Loot|r | You | + " .. BAND .. " x2").kind, "loot")
    local theirs = LP.Parse("|cffff0000Loot|r | Brakk | + " .. OTHER)
    assertEqual(theirs.kind, "loot", "a member's line is loot, not pushed or a created echo")
    assertEqual(theirs.looterGUID, BRAKK)
    m.LOOT_ITEM_PUSHED_SELF = "|cffff0000Loot|r | You | item + %s"
    assertEqual(LP.Parse("|cffff0000Loot|r | You | item + " .. BAND).kind, "pushed",
        "a pushed string spelled apart still reads as pushed")
end)

test("loot parser: a deDE client reads its own lines", function()
    local _, m, LP = party()
    m.LOOT_ITEM = "%s erhält Beute: %s."
    m.LOOT_ITEM_MULTIPLE = "%s erhält Beute: %sx%d."
    m.LOOT_ITEM_SELF = "Ihr erhaltet Beute: %s."
    m.LOOT_ITEM_BONUS_ROLL = "%s erhält Bonusbeute: %s."
    assertEqual(LP.Parse("Brakk erhält Beute: " .. BAND .. ".").looterGUID, BRAKK)
    assertEqual(LP.Parse("Brakk erhält Beute: " .. BAND .. "x2.").qty, 2)
    assertEqual(LP.Parse("Ihr erhaltet Beute: " .. BAND .. ".").looterGUID, ME)
    assertEqual(LP.Parse("Brakk erhält Bonusbeute: " .. BAND .. ".").kind, "bonus")
end)

test("loot parser: positional arguments are read in the locale's order", function()
    local _, m, LP = party()
    m.LOOT_ITEM = "%2$s goes to %1$s."
    m.LOOT_ITEM_MULTIPLE = "%2$sx%3$d goes to %1$s."
    local loot = LP.Parse(BAND .. " goes to Brakk.")
    assertEqual(loot.link, BAND)
    assertEqual(loot.looterGUID, BRAKK)
    loot = LP.Parse(BAND .. "x7 goes to Brakk.")
    assertEqual(loot.qty, 7)
    assertEqual(loot.link, BAND)
end)

-- ---------------------------------------------------------------------------------------------
-- The edge: the event, the sinks, the counters, the stand-down
-- ---------------------------------------------------------------------------------------------

test("loot parser: CHAT_MSG_LOOT hands each receipt to every sink and counts the lines", function()
    local NS, m, LP = party()
    local got, second = {}, 0
    LP.AddSink(function() error("a broken sink") end)
    LP.AddSink(function(loot) got[#got + 1] = loot end)
    LP.AddSink(function() second = second + 1 end)
    m.__now = 100
    assertEqual(fireLoot(m, "Lyra-Area52 receives bonus loot: " .. OTHER .. "."), 1)
    fireLoot(m, "Brakk has selected Greed for: " .. BAND)
    fireLoot(m, "Changed " .. OTHER .. " to " .. BAND .. ".")
    installSecrets(m)
    fireLoot(m, T.secret("You receive loot: " .. BAND .. "."))
    assertEqual(#got, 1, "a failing sink costs that sink only")
    assertEqual(second, 1)
    assertEqual(got[1].kind, "bonus")
    assertEqual(got[1].looterGUID, LYRA)
    local s = LP.Stats()
    assertEqual(s.hits, 1); assertEqual(s.ignored, 1); assertEqual(s.rejected, 1); assertEqual(s.secret, 1)
    assertEqual(s.lastAt, 100); assertEqual(s.lastKind, "bonus"); assertEqual(s.lastLooter, "Lyra-Area52")
    assertTrue(NS.State.lootParser == s)
end)

test("loot parser: the event's twelfth argument is the GUID it uses", function()
    local _, m, LP = party()
    local got
    LP.AddSink(function(loot) got = loot end)
    fireLoot(m, "Stranger receives loot: " .. OTHER .. ".", "Player-9-00000009")
    assertEqual(got.looterGUID, "Player-9-00000009")
end)

test("loot parser: stood down, CHAT_MSG_LOOT reaches nothing; the counters survive", function()
    local NS, m, LP = party()
    fireLoot(m, "You receive loot: " .. BAND .. ".")
    NS.addon:OnSlashCommand("disable")
    assertEqual(fireLoot(m, "You receive loot: " .. BAND .. "."), 0)
    assertEqual(LP.Stats().hits, 1, "since login, not since the stand-up")
    NS.addon:OnSlashCommand("enable")
    assertTrue(fireLoot(m, "You receive loot: " .. BAND .. ".") > 0)
    assertEqual(LP.Stats().hits, 2)
    assertFalse(NS.IsStoodDown())
end)
