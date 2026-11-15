-- tests/test_item_lists.lua — the Always watch and Never watch item lists (issue #13, categories
-- design spec §4.1-§4.3, §5.3): NS.ItemLists, their one writer (ParseId, Add, Remove, List, the
-- refusals, every write a whole copy through the seam); the CLI's `/dw whitelist|blacklist`
-- (add, remove, list, the refusals, the disabled refusal, `/dw get`, `/dw set`'s refusal and a
-- named reset); and the lists through the feed (Never watch hides gear and beats Always watch;
-- Always watch shows an item of no kind as a feed-only `unknown`, passes the kinds and the quality
-- gate, never the situation).

local T = _G.DW_TEST
local test, assertEqual, assertTrue, assertFalse, assertNil =
    T.test, T.assertEqual, T.assertTrue, T.assertFalse, T.assertNil

local BRAKK = "Player-1-0000000A"
local ARMOR, MISC, MOUNT_SUB = 4, 15, 5

local function link(id) return ("|cnIQ4:|Hitem:%d::::::::90:::::|h[Item %d]|h|r"):format(id, id) end

local function ring(ilvl, quality)
    return { name = "Ring", quality = quality or 4, ilvl = ilvl, equipLoc = "INVTYPE_FINGER", classID = ARMOR,
        subClassID = 0, bindType = 1, stats = {} }
end

local function printed(m, needle)
    for _, line in ipairs(m.prints) do
        if line:find(needle, 1, true) then return true end
    end
    return false
end

-- Whether any printed line ends in a colon (slash-commands-§4: no chat line does; DW-CAT5 review).
local function colonEnded(m)
    for _, line in ipairs(m.prints) do
        if line:find(":%s*$") then return line end
    end
    return nil
end

-- An enabled instance in a Heroic dungeon, two 600 rings worn, Brakk in the group.
local function party()
    local NS, _, m = T.enableAddon({ mock = function(m)
        m.__context.inInstance, m.__context.instanceType = true, "party"
        m.instance = { name = "The Rookery", difficultyID = 2 }
    end })
    m.addItem(link(100), ring(600))
    m.addItem(link(101), ring(600))
    m.inventory.player[11], m.inventory.player[12] = link(100), link(101)
    m.setGroup({ { guid = BRAKK, name = "Brakk", class = "WARRIOR", classFile = "WARRIOR" } })
    NS.Roster.Refresh("test")
    return NS, m, NS.LootFeed
end

local function brakkLoots(m, id)
    m.__fire("CHAT_MSG_LOOT", "Brakk receives loot: " .. link(id) .. ".", "", "", "", "", "", 0, 0, "", 0, 1, nil)
end

-- ---------------------------------------------------------------------------------------------
-- The writer
-- ---------------------------------------------------------------------------------------------

test("item lists: ParseId reads a number, a link, item:<id> and a number as text, and nothing else", function()
    local IL = T.newAddon().ItemLists
    assertEqual(IL.ParseId(19019), 19019)
    assertEqual(IL.ParseId(link(19019)), 19019)
    assertEqual(IL.ParseId("item:19019:0:0"), 19019)
    assertEqual(IL.ParseId("  19019 "), 19019)
    for _, bad in ipairs({ "Thunderfury", "19019x", "", 0, -5, 1.5, 0 / 0, true, {} }) do
        assertNil(IL.ParseId(bad), tostring(bad))
    end
    assertNil(IL.ParseId(nil))
end)

test("item lists: Add, Remove, List and Contains, in ID order, with already and notListed", function()
    local IL = T.bootAddon().ItemLists
    assertTrue(IL.Add("whitelist", 300))
    assertTrue(IL.Add("whitelist", link(200)))
    assertTrue(IL.Add("whitelist", "item:250"))
    assertEqual(table.concat(IL.List("whitelist"), ","), "200,250,300")
    assertTrue(IL.Contains("whitelist", "200")); assertFalse(IL.Contains("blacklist", 200))
    local ok, why = IL.Add("whitelist", 300)
    assertFalse(ok); assertEqual(why, "already")
    assertTrue(IL.Remove("whitelist", 250))
    ok, why = IL.Remove("whitelist", 250)
    assertFalse(ok); assertEqual(why, "notListed")
    ok, why = IL.Add("whitelist", "junk")
    assertFalse(ok); assertEqual(why, "badId")
    ok, why = IL.Add("otherlist", 1)
    assertFalse(ok); assertEqual(why, "badList")
    assertEqual(table.concat(IL.List("whitelist"), ","), "200,300")
    assertEqual(#IL.List("otherlist"), 0)
end)

-- red under: Add moving the ID across, or not checking the other list at all
test("item lists: an ID on one list is refused by the other, both ways, and never moved", function()
    local NS = T.bootAddon()
    local IL = NS.ItemLists
    assertTrue(IL.Add("whitelist", 300))
    local ok, why = IL.Add("blacklist", 300)
    assertFalse(ok); assertEqual(why, "onOther")
    assertEqual(IL.WhyText("blacklist", why), "That item is on Always watch: remove it there first.")
    assertTrue(IL.Contains("whitelist", 300), "still on Always watch")
    assertTrue(IL.Add("blacklist", 400))
    ok, why = IL.Add("whitelist", 400)
    assertFalse(ok); assertEqual(IL.WhyText("whitelist", why), "That item is on Never watch: remove it there first.")
    assertTrue(IL.Remove("whitelist", 300))
    assertTrue(IL.Add("blacklist", 300), "once taken off, it goes on the other")
    assertEqual(IL.WhyText("whitelist", "already"), "That item is already on Always watch.")
    assertEqual(IL.WhyText("blacklist", "notListed"), "That item is not on Never watch.")
    assertEqual(IL.WhyText("whitelist", "badId"), "That is not an item ID or an item link.")
end)

-- red under: a write in place (the stored table changed under the seam) or a path of its own
test("item lists: every write is a whole copy through the seam, at the list's own path", function()
    local NS = T.bootAddon()
    local S, IL = NS.SchemaRuntime, NS.ItemLists
    local writes, set = {}, S.Set
    S.Set = function(path, value, ...)
        writes[#writes + 1] = { path = path, value = value }
        return set(path, value, ...)
    end
    assertTrue(IL.Add("blacklist", 300))
    local before = NS.Setting("feed.blacklist")
    assertTrue(IL.Add("blacklist", 301))
    assertTrue(IL.Remove("blacklist", 300))
    S.Set = set
    assertEqual(#writes, 3)
    for _, w in ipairs(writes) do assertEqual(w.path, "feed.blacklist") end
    assertTrue(writes[2].value ~= before, "a fresh table, not the stored one")
    assertTrue(before[301] == nil, "the stored set was not written in place")
    assertTrue(writes[2].value[300] and writes[2].value[301], "the whole set, written whole")
    assertNil(writes[3].value[300]); assertTrue(writes[3].value[301])
end)

-- ---------------------------------------------------------------------------------------------
-- The CLI
-- ---------------------------------------------------------------------------------------------

test("item lists: `/dw whitelist add|remove|list` writes through the writer and says what it did", function()
    local NS, _, m = T.enableAddon()
    m.addItem("item:19019", { name = "Thunderfury", quality = 5, ilvl = 80, equipLoc = "INVTYPE_WEAPON",
        classID = 2, subClassID = 7, stats = {} })
    NS.addon:OnSlashCommand("whitelist")
    assertTrue(printed(m, "Always watch (0)")); assertTrue(printed(m, "(none)"))
    assertNil(colonEnded(m), "the list's header ends in no colon")
    m.prints = {}
    NS.addon:OnSlashCommand("whitelist add " .. link(19019))
    assertTrue(printed(m, "Added 19019 [Thunderfury] to Always watch."), tostring(m.prints[1]))
    NS.addon:OnSlashCommand("whitelist add 300")
    assertTrue(printed(m, "Added item 300 to Always watch."), tostring(m.prints[2]))
    m.prints = {}
    NS.addon:OnSlashCommand("whitelist list")
    assertTrue(printed(m, "Always watch (2)")); assertNil(colonEnded(m))
    assertTrue(printed(m, "  item 300")); assertTrue(printed(m, "  19019 [Thunderfury]"))
    m.prints = {}
    NS.addon:OnSlashCommand("blacklist add 300")
    -- red under: the CLI writing the list itself, past the writer's refusal
    assertTrue(printed(m, "That item is on Always watch: remove it there first."), tostring(m.prints[1]))
    assertFalse(NS.ItemLists.Contains("blacklist", 300))
    m.prints = {}
    NS.addon:OnSlashCommand("whitelist remove 300")
    assertTrue(printed(m, "Removed item 300 from Always watch."), tostring(m.prints[1]))
    NS.addon:OnSlashCommand("whitelist remove 300")
    assertTrue(printed(m, "That item is not on Always watch."))
    m.prints = {}
    NS.addon:OnSlashCommand("blacklist drop 300")
    assertTrue(printed(m, "/dw blacklist add|remove|list"), tostring(m.prints[1]))
    NS.addon:OnSlashCommand("blacklist add Thunderfury")
    assertTrue(printed(m, "That is not an item ID or an item link."))
end)

test("item lists: the verbs are in NS.COMMANDS and the help, and refused while disabled", function()
    local NS, _, m = T.enableAddon()
    local at = {}
    for i, entry in ipairs(NS.COMMANDS) do at[entry[1]] = i end
    assertTrue(at.whitelist ~= nil and at.blacklist ~= nil)
    assertTrue(at.whitelist > at.show, "feature verbs, after the reserved ones")
    m.prints = {}
    NS.addon:OnSlashCommand("help")
    assertTrue(printed(m, "whitelist")); assertTrue(printed(m, "blacklist"))
    NS.addon:OnSlashCommand("disable")
    for _, verb in ipairs({ "whitelist add 300", "blacklist add 300", "whitelist list", "blacklist" }) do
        m.prints = {}
        NS.addon:OnSlashCommand(verb)
        -- red under: the verbs in the dispatcher's live set
        assertTrue(m.prints[1] ~= nil and m.prints[1]:find("is disabled", 1, true) ~= nil, verb)
        assertEqual(#m.prints, 1, verb .. ": one line, nothing else")
    end
    assertEqual(#NS.ItemLists.List("whitelist") + #NS.ItemLists.List("blacklist"), 0)
end)

test("item lists: `/dw get` shows a list as its size, and a named `/dw reset` empties it", function()
    local NS, _, m = T.enableAddon()
    NS.ItemLists.Add("whitelist", 300)
    NS.ItemLists.Add("whitelist", 301)
    m.prints = {}
    NS.addon:OnSlashCommand("get feed.whitelist")
    assertTrue(printed(m, "{2}"), tostring(m.prints[1]))
    NS.addon:OnSlashCommand("reset feed.whitelist")
    -- red under: resetExempt vetoing a named single-row reset as well as the page's sweep
    assertEqual(#NS.ItemLists.List("whitelist"), 0)
end)

test("item lists: `/dw set` on a list is refused by the generic verb, and the list is unchanged", function()
    local NS, _, m = T.enableAddon()
    NS.ItemLists.Add("whitelist", 301)
    m.prints = {}
    NS.addon:OnSlashCommand("set feed.whitelist 300")
    -- The library's parser has no reading for a `map` row: the generic verb refuses, and the list's
    -- one writer (NS.ItemLists, its `onOther` check included) stays the only way in (spec §5.3).
    -- red under: a parse or set that wrote the row past NS.ItemLists
    assertEqual(#m.prints, 2, table.concat(m.prints, " || "))
    assertTrue(printed(m, "Invalid value for feed.whitelist"), tostring(m.prints[1]))
    assertTrue(printed(m, "unknown setting type 'map'"), tostring(m.prints[2]))
    assertEqual(table.concat(NS.ItemLists.List("whitelist"), ","), "301")
end)

-- ---------------------------------------------------------------------------------------------
-- Through the feed
-- ---------------------------------------------------------------------------------------------

test("item lists: Never watch hides gear as blacklist, and beats Always watch on an overlap", function()
    local NS, m, LF = party()
    m.addItem(link(300), ring(620))
    m.addItem(link(301), ring(620))
    assertTrue(NS.ItemLists.Add("blacklist", 300))
    -- An overlap only a hand-edited or copied profile can hold: the writer refuses it.
    assertTrue(NS.SchemaRuntime.Set("feed.whitelist", { [301] = true }))
    assertTrue(NS.SchemaRuntime.Set("feed.blacklist", { [300] = true, [301] = true }))
    brakkLoots(m, 300)
    brakkLoots(m, 301)
    -- red under: LootFeed.Config not reading the lists
    assertEqual(#LF.Drops(), 0)
    assertEqual(LF.Stats().hidden.blacklist, 2)
end)

test("item lists: Always watch shows an item of no kind as a feed-only Item on its list", function()
    local NS, m, LF = party()
    m.addItem(link(300), { name = "Potion", quality = 1, ilvl = 1, equipLoc = "", classID = 0, subClassID = 0,
        stats = {} })
    assertTrue(NS.ItemLists.Add("whitelist", 300))
    brakkLoots(m, 300)
    local rec = LF.Drops()[1]
    -- red under: judgeMe not reading the whitelist (the gear kernel's `unknown notGear`)
    assertTrue(rec ~= nil, "shown past notWatched and the quality gate")
    -- ruling 3 (RX-12 review fix): its kind word, never Unknown
    assertEqual(rec.me.verdict, "item"); assertTrue(rec.me.collect)
    assertEqual(rec.me.reasons[#rec.me.reasons].key, "whitelisted")
    assertTrue(rec.forced); assertEqual(rec.quality.reason, "whitelisted")
    assertTrue(NS.Collectibles.IsFeedOnly(rec), "no Ask, toast or inspect")
    assertNil(rec.them)
end)

test("item lists: Always watch passes a kind turned off and the quality gate, gear judged as gear", function()
    local NS, m, LF = party()
    assertTrue(NS.SchemaRuntime.Set("feed.categories.equipment", false))
    assertTrue(NS.SchemaRuntime.Set("feed.categories.mount", false))
    m.addItem(link(300), ring(620, 2))   -- Uncommon, under the Rare minimum
    m.addItem(link(301), { name = "Reins", quality = 4, ilvl = 1, equipLoc = "", classID = MISC,
        subClassID = MOUNT_SUB, bindType = 1, stats = {} })
    m.mounts.byItem[301] = 77
    m.mounts.collected[77] = false
    NS.ItemLists.Add("whitelist", 300)
    NS.ItemLists.Add("whitelist", 301)
    brakkLoots(m, 300)
    brakkLoots(m, 301)
    local gear, mount = LF.Drops()[1], LF.Drops()[2]
    assertEqual(gear.me.verdict, "upgrade", "gear on the list is still judged as gear")
    assertEqual(gear.quality.reason, "whitelisted")
    assertEqual(mount.me.verdict, "newCollect")
    assertEqual(mount.me.reasons[#mount.me.reasons].key, "whitelisted")
end)

-- red under: the whitelist checked before the situation gate (categories design spec §4.2)
test("item lists: Always watch never overrides the situation gate", function()
    local NS, m, LF = party()
    assertTrue(NS.SchemaRuntime.Set("situations.dungeon.track", false))
    m.addItem(link(300), ring(620))
    NS.ItemLists.Add("whitelist", 300)
    brakkLoots(m, 300)
    assertEqual(#LF.Drops(), 0)
    assertEqual(LF.Stats().hidden.notTracking, 1)
end)
