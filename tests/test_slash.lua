-- tests/test_slash.lua — the verb table and the host verbs (slash-commands-§1/§2/§3).

local T = _G.DW_TEST
local test, assertEqual, assertTrue, assertFalse = T.test, T.assertEqual, T.assertTrue, T.assertFalse

local NO_LIBKA0S = T.loadAddon.libFiles

local RESERVED = { "help", "config", "enable", "disable", "version", "list", "get", "set", "reset",
    "resetall", "profile", "debug", "diagnostics", "perf" }

local function verbs(NS)
    local out = {}
    for _, entry in ipairs(NS.COMMANDS) do out[entry[1]] = entry end
    return out
end

test("slash: NS.COMMANDS is positional triples, every reserved verb present", function()
    local NS = T.newAddon()
    for _, entry in ipairs(NS.COMMANDS) do
        -- red under: write one entry as { name = ..., desc = ..., fn = ... }
        assertTrue(type(entry[1]) == "string" and type(entry[2]) == "string" and type(entry[3]) == "function",
            "positional triple: " .. tostring(entry[1]))
    end
    local v = verbs(NS)
    for _, name in ipairs(RESERVED) do assertTrue(v[name] ~= nil, "reserved verb " .. name) end
end)

test("slash: `diagnostics` has no alias of any kind (debug-logging-§14)", function()
    local NS = T.newAddon()
    local v = verbs(NS)
    assertTrue(v.diag == nil and v.dump == nil and v.dx == nil)
end)

test("slash: both chat commands are registered through AceConsole, and both dispatch", function()
    local _, _, m = T.bootAddon()
    local AC = m.LibStub("AceConsole-3.0")
    assertTrue(AC.commands.dw ~= nil and AC.commands.dropwatcher ~= nil, "dw and dropwatcher")
    m.prints = {}
    AC:__slash("dropwatcher", "version")
    assertTrue(m.prints[1]:find("0.1.0", 1, true) ~= nil, tostring(m.prints[1]))
end)

test("slash: the bare command opens the settings panel", function()
    local NS = T.enableAddon()
    local opened = 0
    local H = NS.addon.Settings.Helpers
    local real = H.OpenOptionsPanel
    H.OpenOptionsPanel = function() opened = opened + 1 end
    NS.addon:OnSlashCommand("")
    H.OpenOptionsPanel = real
    assertEqual(opened, 1)
end)

test("slash: lock and unlock write `locked` through the seam", function()
    local NS = T.enableAddon()
    NS.addon:OnSlashCommand("lock")
    assertEqual(NS.addon.db.profile.locked, true)
    NS.addon:OnSlashCommand("unlock")
    assertEqual(NS.addon.db.profile.locked, false)
end)

test("slash: show, hide and toggle drive the window", function()
    local NS = T.enableAddon()
    NS.addon:OnSlashCommand("show")
    assertTrue(NS.IsWindowShown())
    NS.addon:OnSlashCommand("hide")
    assertFalse(NS.IsWindowShown())
    NS.addon:OnSlashCommand("toggle")
    assertTrue(NS.IsWindowShown())
end)

test("slash: `test` toggles test mode through the shared handler", function()
    local NS = T.enableAddon()
    NS.addon:OnSlashCommand("test")
    assertTrue(NS.State.testMode)
    assertTrue(NS.IsWindowShown(), "test mode shows the window")
    NS.addon:OnSlashCommand("test")
    assertFalse(NS.State.testMode)
end)

test("slash: `perf` is the addon's verb and prints the harness's lines", function()
    local NS, _, m = T.enableAddon()
    m.prints = {}
    NS.addon:OnSlashCommand("perf")
    assertTrue(#m.prints > 0, "the library returned lines and the addon printed them")
end)

test("slash: `reset` with no path explains itself rather than resetting everything", function()
    local NS, _, m = T.enableAddon()
    NS.SchemaRuntime.Set("scale", 1.5)
    m.prints = {}
    NS.addon:OnSlashCommand("reset")
    assertEqual(NS.addon.db.profile.scale, 1.5)
    assertTrue(m.prints[1]:find("takes a setting path", 1, true) ~= nil)
end)

test("slash: degraded, the host verbs still work and the CLI names the missing library", function()
    local D, _, m = T.enableAddon{ skip = NO_LIBKA0S }
    m.prints = {}
    D.addon:OnSlashCommand("lock")
    assertEqual(D.addon.db.profile.locked, true)
    D.addon:OnSlashCommand("list")
    assertTrue(m.prints[#m.prints]:find("settings CLI is unavailable", 1, true) ~= nil)
    D.addon:OnSlashCommand("disable")
    m.prints = {}
    D.addon:OnSlashCommand("test")
    -- The degraded dispatcher refuses a feature verb while disabled, with the library's line.
    assertTrue(m.prints[1]:find("is disabled", 1, true) ~= nil, tostring(m.prints[1]))
    assertFalse(D.State.testMode)
end)

-- ── the feature verbs (design spec §12.3) ───────────────────────────────────────────────────

local FEATURE = { "show", "hide", "toggle", "test", "scan", "clear", "history", "mine", "compact", "full",
    "situation", "offer", "add" }

local function itemLink(id, name)
    return ("|cnIQ4:|Hitem:%d::::::::90:::::|h[%s]|h|r"):format(id, name or ("Item " .. id))
end

local function ring(ilvl)
    return { name = "Item", quality = 4, ilvl = ilvl, equipLoc = "INVTYPE_FINGER", classID = 4,
        subClassID = 0, bindType = 1, stats = {} }
end

local BAND = itemLink(300, "Band of Many Words")

-- An enabled instance outside any instance, wearing two 600 rings, with item 300 (a 620 ring) known.
local function equipped()
    local NS, _, m = T.enableAddon()
    m.addItem(itemLink(100), ring(600)); m.addItem(itemLink(101), ring(600))
    m.inventory.player[11], m.inventory.player[12] = itemLink(100), itemLink(101)
    m.addItem(BAND, ring(620))
    m.prints = {}
    return NS, m
end

local function printed(m, needle)
    for _, line in ipairs(m.prints) do
        if line:find(needle, 1, true) then return true end
    end
    return false
end

test("slash: every verb of spec §12.3 is in the table, after the reserved ones", function()
    local NS = T.newAddon()
    local v, at = verbs(NS), {}
    for i, entry in ipairs(NS.COMMANDS) do at[entry[1]] = i end
    for _, name in ipairs(FEATURE) do assertTrue(v[name] ~= nil, "feature verb " .. name) end
    for _, name in ipairs(RESERVED) do assertTrue(at[name] < at.show, name .. " before the feature verbs") end
end)

test("slash: SplitLink takes a whole link, spaces and all, and leaves the rest", function()
    local V = T.newAddon().SlashVerbs
    local link = BAND
    local got, tail = V.SplitLink("  " .. link .. "  Brakk-Silvermoon ")
    assertEqual(got, link); assertEqual(tail, "Brakk-Silvermoon")
    got, tail = V.SplitLink(link)
    assertEqual(got, link); assertEqual(tail, "")
    local plain = "|Hitem:300::|h[Band of Many Words]|h"
    got, tail = V.SplitLink(plain .. " Lyra")
    assertEqual(got, plain); assertEqual(tail, "Lyra")
    -- red under: a split on the first space (the name's own spaces end the link early)
    got, tail = V.SplitLink("Brakk " .. link)
    assertTrue(got == nil); assertEqual(tail, "Brakk " .. link)
    assertTrue(V.SplitLink("|cff71d5ff|Hspell:1::|h[Spell Name]|h|r") == nil, "a spell is no item")
    assertTrue(V.SplitLink(nil) == nil)
end)

test("slash: `scan` is the window's Scan group handler", function()
    local NS = T.enableAddon()
    local calls = 0
    NS.ScanGroup = function() calls = calls + 1; return 0 end
    NS.addon:OnSlashCommand("scan")
    assertEqual(calls, 1)
end)

test("slash: `add` injects a drop for you, or for a named player, and says what happened", function()
    local NS, m = equipped()
    NS.addon:OnSlashCommand("add " .. BAND)
    local drops = NS.LootFeed.Drops()
    assertEqual(#drops, 1); assertTrue(drops[1].isMine); assertEqual(drops[1].source, "manual")
    assertTrue(printed(m, "for you (drop 1)"), tostring(m.prints[1]))
    NS.addon:OnSlashCommand("add " .. BAND .. " Nobody-Elsewhere")
    assertEqual(#NS.LootFeed.Drops(), 2)
    assertEqual(NS.LootFeed.Drops()[2].looter.name, "Nobody-Elsewhere")
    assertFalse(NS.LootFeed.Drops()[2].isMine)
end)

test("slash: `add` with no link prints its usage; a refused drop says why", function()
    local NS, m = equipped()
    NS.addon:OnSlashCommand("add Brakk")
    assertTrue(printed(m, "/dw add <item link> [player]"), tostring(m.prints[1]))
    assertEqual(#NS.LootFeed.Drops(), 0)
    m.prints = {}
    NS.LootFeed.Add = function() return nil, "quality" end
    NS.addon:OnSlashCommand("add " .. BAND)
    assertTrue(printed(m, "Not added: below the minimum quality."), tostring(m.prints[1]))
end)

test("slash: `add` of an item still loading says it shows once it loads", function()
    local NS, m = equipped()
    NS.LootFeed.Add = function() return 7, "loading" end
    NS.addon:OnSlashCommand("add " .. BAND)
    assertTrue(printed(m, "its item data is loading"), tostring(m.prints[1]))
end)

test("slash: `clear` empties this session's feed and leaves the test feed alone", function()
    local NS, m = equipped()
    NS.LootFeed.Add(BAND)
    NS.LootFeed.Add(BAND, "Brakk", { test = true })
    NS.addon:OnSlashCommand("clear")
    assertEqual(#NS.LootFeed.Drops(), 0)
    assertEqual(#NS.LootFeed.Drops("test"), 1)
    assertTrue(printed(m, "Cleared this session's drops."))
end)

test("slash: `clear` closes an Offer panel whose drop it took", function()
    local NS = equipped()
    local id = NS.LootFeed.Add(BAND)
    NS.ShowWindow()
    assertTrue(NS.OfferPanel.Open(id) ~= nil)
    NS.addon:OnSlashCommand("clear")
    assertFalse(NS.OfferPanel.IsShown())
end)

test("slash: `history` and `mine` open the window on that tab, expanded", function()
    local NS = T.enableAddon()
    NS.addon:OnSlashCommand("history")
    assertTrue(NS.IsWindowShown()); assertEqual(NS.Window.ActiveTab(), "history")
    NS.Window.SetMinimized(true)
    NS.addon:OnSlashCommand("mine")
    assertEqual(NS.Window.ActiveTab(), "mine")
    assertFalse(NS.Window.IsMinimized(), "a tab verb expands the window")
end)

test("slash: a tab verb the Visibility setting keeps hidden says so", function()
    local NS, _, m = T.enableAddon()
    NS.SchemaRuntime.Set("visibility", "never")
    m.prints = {}
    NS.addon:OnSlashCommand("mine")
    assertFalse(NS.IsWindowShown())
    assertTrue(printed(m, "Visibility setting"), tostring(m.prints[1]))
end)

test("slash: `compact` toggles the layout through the seam, `full` sets it back, each printing it", function()
    local NS, _, m = T.enableAddon()
    assertEqual(NS.Setting("window.mode"), "full")
    m.prints = {}
    NS.addon:OnSlashCommand("compact")
    assertEqual(NS.addon.db.profile.window.mode, "compact")
    assertTrue(printed(m, "Compact view."), tostring(m.prints[1]))
    NS.addon:OnSlashCommand("compact")
    assertEqual(NS.Setting("window.mode"), "full", "compact toggles")
    assertTrue(printed(m, "Full view."))
    NS.addon:OnSlashCommand("compact")
    m.prints = {}
    NS.addon:OnSlashCommand("full")
    assertEqual(NS.Setting("window.mode"), "full")
    assertTrue(printed(m, "Full view."))
    NS.addon:OnSlashCommand("full")
    assertEqual(NS.Setting("window.mode"), "full", "full only sets, never toggles")
end)

test("slash: `situation` prints the situation, its settings and the classifier's inputs", function()
    local NS, _, m = T.enableAddon{ mock = function(mk)
        mk.__context.inInstance, mk.__context.instanceType = true, "party"
        mk.instance = { name = "The Rookery", difficultyID = 2 }
    end }
    m.prints = {}
    NS.addon:OnSlashCommand("situation")
    assertEqual(#m.prints, 3)
    assertTrue(m.prints[1]:find("(dungeon)", 1, true) ~= nil, m.prints[1])
    assertTrue(m.prints[1]:find("Track yes", 1, true) ~= nil, m.prints[1])
    assertTrue(m.prints[2]:find("in instance yes · type party · difficulty 2", 1, true) ~= nil, m.prints[2])
    assertTrue(m.prints[3]:find("raid no", 1, true) ~= nil, m.prints[3])
    assertEqual(#NS.SlashVerbs.SituationLines(), 3)
end)

test("slash: `offer` opens the panel on your newest drop of that item", function()
    local NS = equipped()
    NS.LootFeed.Add(BAND)
    local newest = NS.LootFeed.Add(BAND)
    NS.addon:OnSlashCommand("offer " .. BAND)
    assertTrue(NS.OfferPanel.IsShown()); assertEqual(NS.OfferPanel.DropId(), newest)
    assertEqual(NS.Window.ActiveTab(), "mine")
end)

test("slash: `offer` of a bag item the feed never saw adds it as yours first", function()
    local NS, m = equipped()
    m.bags[1] = { size = 4, [3] = BAND }
    NS.addon:OnSlashCommand("offer " .. BAND)
    local drops = NS.LootFeed.Drops()
    assertEqual(#drops, 1); assertTrue(drops[1].isMine)
    assertTrue(NS.OfferPanel.IsShown()); assertEqual(NS.OfferPanel.DropId(), drops[1].id)
end)

test("slash: `offer` refuses an item not in your bags, and prints its usage without a link", function()
    local NS, m = equipped()
    NS.addon:OnSlashCommand("offer " .. BAND)
    assertTrue(printed(m, "is not in your bags"), tostring(m.prints[1]))
    assertEqual(#NS.LootFeed.Drops(), 0); assertFalse(NS.OfferPanel.IsShown())
    m.prints = {}
    NS.addon:OnSlashCommand("offer")
    assertTrue(printed(m, "/dw offer <item link>"), tostring(m.prints[1]))
end)

test("slash: every feature verb is refused while disabled", function()
    local NS, m = equipped()
    NS.addon:OnSlashCommand("disable")
    for _, verb in ipairs({ "scan", "clear", "history", "mine", "compact", "full", "situation", "offer", "add" }) do
        m.prints = {}
        NS.addon:OnSlashCommand(verb .. " " .. BAND)
        assertTrue(m.prints[1] ~= nil and m.prints[1]:find("is disabled", 1, true) ~= nil, verb)
    end
    assertEqual(#NS.LootFeed.Drops(), 0)
end)
