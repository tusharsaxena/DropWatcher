-- tests/test_item_facts.lua — modules/ItemFacts.lua (design spec §4, §5.1): a link turned into the
-- facts the verdict kernel reads (levels, slot, class, quality, binds, track and its tier, stats,
-- specs, uniqueness, tier tokens, appearance), cached by link; the load of an uncached item through
-- LibKa0s-Item-1.0's LoadItem with its callback as the retry; the cache cap; the appearance event;
-- and the stand-down.

local T = _G.DW_TEST
local test, assertEqual, assertTrue, assertFalse, assertNil =
    T.test, T.assertEqual, T.assertTrue, T.assertFalse, T.assertNil

local RING  = "|cnIQ4:|Hitem:2001::::::::90:::::|h[Band]|h|r"
local CHEST = "|cnIQ3:|Hitem:2002::::::::90:::::|h[Hauberk]|h|r"
local TOKEN = "|cnIQ4:|Hitem:2003::::::::90:::::|h[Dreadful Helm Module]|h|r"

local function ring(extra)
    local def = { name = "Band", quality = 4, ilvl = 250, effectiveIlvl = 263, equipLoc = "INVTYPE_FINGER",
        classID = 4, subClassID = 0, bindType = 1, setID = nil,
        stats = { ITEM_MOD_CRIT_RATING_SHORT = 100, ITEM_MOD_SOMETHING_NEW = 4 }, specs = { 71, 72 },
        unique = { false, "Cat", 2, 55 }, transmog = true }
    for k, v in pairs(extra or {}) do def[k] = v end
    return def
end

local function chest(extra)
    local def = { name = "Hauberk", quality = 3, ilvl = 240, equipLoc = "INVTYPE_CHEST", classID = 4,
        subClassID = 3, bindType = 1, stats = { ITEM_MOD_AGILITY_SHORT = 50 }, transmog = false }
    for k, v in pairs(extra or {}) do def[k] = v end
    return def
end

local function enabled(seed)
    local NS, _, m = T.enableAddon({ mock = seed })
    -- These cases count their own timers: the first-run skin picker's login fuse (core/SkinSetup.lua,
    -- tests/test_skin_picker.lua) is put out.
    NS.ArmSkinPicker(false)
    return NS, m, NS.ItemFacts
end

-- ---------------------------------------------------------------------------------------------
-- Reading the facts
-- ---------------------------------------------------------------------------------------------

test("item facts: a cached ring reads every field of spec §5.1", function()
    local _, _, IF = enabled(function(m)
        m.addItem(RING, ring())
        m.upgradeInfo[RING] = { currentLevel = 3, maxLevel = 6, maxItemLevel = 276, trackString = "Hero",
            trackStringID = 999 }
    end)
    local f = IF.Get(RING)
    assertEqual(f.link, RING); assertEqual(f.itemID, 2001); assertEqual(f.name, "Band")
    assertEqual(f.ilvl, 263, "the effective level"); assertEqual(f.baseIlvl, 250)
    assertEqual(f.equipLoc, "INVTYPE_FINGER"); assertEqual(f.classID, 4); assertEqual(f.subClassID, 0)
    assertEqual(f.quality, 4); assertEqual(f.bindType, 1)
    assertEqual(f.track.name, "Hero"); assertEqual(f.track.rank, 3); assertEqual(f.track.max, 6)
    assertEqual(f.track.tier, 5, "the enUS name, the string id being unknown")
    assertEqual(f.track.stringID, 999); assertEqual(f.track.maxItemLevel, 276)
    assertEqual(f.track.source, "api")
    assertEqual(f.stats.ITEM_MOD_CRIT_RATING_SHORT, 100)
    assertEqual(f.stats.ITEM_MOD_SOMETHING_NEW, 4, "an unknown stat key is kept, not an error")
    assertTrue(f.specs[71]); assertTrue(f.specs[72]); assertNil(f.specs[73])
    assertEqual(f.unique.cat, 55); assertEqual(f.unique.max, 2)
    assertFalse(f.warbound); assertFalse(f.warboundUntilEquip)
    assertNil(f.transmogKnown, "a ring has no appearance")
    assertNil(f.classes); assertFalse(f.isTierToken)
end)

test("item facts: a chest reads its appearance, account binds and no specs or track", function()
    local _, m, IF = enabled(function(m)
        m.addItem(CHEST, chest({ specs = {} }))
        m.accountBoundUE[CHEST] = true
    end)
    local f = IF.Get(CHEST)
    assertEqual(f.ilvl, 240, "no effective level: the base one")
    assertFalse(f.transmogKnown)
    assertNil(f.specs, "an empty spec list names no spec")
    assertNil(f.track); assertNil(f.unique)
    assertTrue(f.warbound); assertTrue(f.warboundUntilEquip)
    m.accountBoundUE[CHEST] = nil
    m.accountBound[CHEST] = true
    IF.Invalidate(CHEST)
    f = IF.Get(CHEST)
    assertTrue(f.warbound); assertFalse(f.warboundUntilEquip)
end)

-- The client answers GetItemStats and GetItemSpecInfo for the character playing, not the item: a
-- three-stat cloak read on a Beast Mastery hunter answers Agility alone and the hunter's specs
-- alone, while its tooltip lists all three primary stats (the drop of 2026-10-15, issue: a Fireproof
-- Drape judged useless to a Blood death knight and a Retribution paladin).
local CLOAK = "|cnIQ4:|Hitem:193763::::::::90:253:::::|h[Fireproof Drape]|h|r"

local function huntersCloak(m)
    m.units.player = { guid = "Player-1-00000001", name = "Hunter", class = "Hunter",
        classFile = "HUNTER", connected = true }
    m.addItem(CLOAK, { name = "Fireproof Drape", quality = 4, ilvl = 311, equipLoc = "INVTYPE_CLOAK",
        classID = 4, subClassID = 1, bindType = 1,
        stats = { ITEM_MOD_AGILITY_SHORT = 86, ITEM_MOD_STAMINA_SHORT = 1689 }, specs = { 253, 254, 255 } })
    m.tooltips.hyperlink[CLOAK] = { lines = { { leftText = "+86 Agility" },
        { leftText = "+1,689 Stamina" }, { leftText = "+86 Intellect" }, { leftText = "+86 Strength" } } }
end

test("item facts: the stats carry every primary stat on the tooltip, not the playing spec's alone", function()
    local _, _, IF = enabled(huntersCloak)
    local s = IF.Get(CLOAK).stats
    assertEqual(s.ITEM_MOD_AGILITY_SHORT, 86); assertEqual(s.ITEM_MOD_STRENGTH_SHORT, 86)
    assertEqual(s.ITEM_MOD_INTELLECT_SHORT, 86); assertEqual(s.ITEM_MOD_STAMINA_SHORT, 1689)
end)

test("item facts: the spec list says which class the client read it for", function()
    local _, _, IF = enabled(huntersCloak)
    local f = IF.Get(CLOAK)
    assertTrue(f.specs[253]); assertEqual(f.specsClass, "HUNTER")
end)

test("item facts: a three-stat cloak read on a hunter suits a Blood death knight and a Retribution paladin", function()
    local NS, _, IF = enabled(huntersCloak)
    local f = IF.Get(CLOAK)
    -- red under: GetItemSpecInfo's hunter-only list refused both (specList), and GetItemStats'
    -- Agility alone refused both again (primaryStat)
    assertEqual(NS.Evaluate.Equippability(f, { classFile = "DEATHKNIGHT", specID = 250 }), "ok")
    assertEqual(NS.Evaluate.Equippability(f, { classFile = "PALADIN", specID = 70 }), "ok")
    assertEqual(NS.Evaluate.Equippability(f, { classFile = "HUNTER", specID = 253 }), "ok")
end)

test("item facts: the track tier, by string id first, then by enUS name, else unset", function()
    local NS, m, IF = enabled(function(m) m.addItem(RING, ring()) end)
    assertEqual(IF.TrackTier(nil, "Champion"), 4)
    assertNil(IF.TrackTier(nil, "Champion (localized)"))
    assertNil(IF.TrackTier(nil, nil))
    NS.Constants.TRACK_TIER_BY_STRING_ID[971] = 2
    assertEqual(IF.TrackTier(971, "Héros"), 2, "the string id wins over a localized name")
    m.upgradeInfo[RING] = { currentLevel = 1, maxLevel = 8, trackString = "Héros", trackStringID = 971 }
    assertEqual(IF.Get(RING).track.tier, 2)
end)

test("item facts: the track falls back to the tooltip's upgrade line", function()
    local _, _, IF = enabled(function(m)
        m.addItem(RING, ring())
        m.tooltips.hyperlink[RING] = { lines = { { type = 32, leftText = "Upgrade Level: Champion 2/8" } } }
    end)
    local t = IF.Get(RING).track
    assertEqual(t.name, "Champion"); assertEqual(t.rank, 2); assertEqual(t.max, 8)
    assertEqual(t.tier, 4); assertEqual(t.source, "tooltip"); assertNil(t.stringID)
end)

test("item facts: an item unique on its own takes its item id as the category", function()
    local _, _, IF = enabled(function(m) m.addItem(RING, ring({ unique = { true, nil, nil, 0 } })) end)
    local u = IF.Get(RING).unique
    assertEqual(u.cat, "item:2001"); assertEqual(u.max, 1)
end)

test("item facts: a token naming classes is a tier token; class gear carries classes only", function()
    local _, _, IF = enabled(function(m)
        m.addItem(TOKEN, { name = "Dreadful Helm Module", quality = 4, ilvl = 263, equipLoc = "",
            classID = 15, subClassID = 0, bindType = 1 })
        m.tooltips.hyperlink[TOKEN] = { lines = { { type = 21, leftText = "Classes: Warrior, Paladin, Death Knight" } } }
        m.addItem(CHEST, chest())
        m.tooltips.hyperlink[CHEST] = { lines = { { type = 21, leftText = "Classes: Hunter" } } }
    end)
    local t = IF.Get(TOKEN)
    assertTrue(t.isTierToken)
    assertTrue(t.classes.WARRIOR); assertTrue(t.classes.PALADIN); assertTrue(t.classes.DEATHKNIGHT)
    assertNil(t.classes.MAGE)
    assertNil(t.transmogKnown, "no equipLoc, no appearance")
    local c = IF.Get(CHEST)
    assertFalse(c.isTierToken); assertTrue(c.classes.HUNTER)
end)

test("item facts: the quality falls back to the link's color", function()
    local _, _, IF = enabled(function(m) m.addItem(RING, ring({ quality = nil })) end)
    assertEqual(IF.Get(RING).quality, 4)
end)

test("item facts: the facts feed the verdict kernel", function()
    local NS, _, IF = enabled(function(m)
        m.addItem(RING, ring())
        m.addItem(CHEST, chest())
    end)
    local S = NS.Constants.SLOT
    local candidate = { classFile = "HUNTER", specID = nil,
        gear = { [S.FINGER1] = { ilvl = 250, equipLoc = "INVTYPE_FINGER" },
                 [S.FINGER2] = { ilvl = 255, equipLoc = "INVTYPE_FINGER" } } }
    local r = NS.Evaluate.Evaluate(IF.Get(RING), candidate, {})
    assertEqual(r.verdict, "upgrade"); assertEqual(r.ilvlDelta, 13)
    candidate.gear[S.CHEST] = { ilvl = 250, equipLoc = "INVTYPE_CHEST" }
    assertEqual(NS.Evaluate.Evaluate(IF.Get(CHEST), candidate, {}).verdict, "downgrade")
end)

-- ---------------------------------------------------------------------------------------------
-- The cache
-- ---------------------------------------------------------------------------------------------

test("item facts: Get caches by link until invalidated", function()
    local _, m, IF = enabled(function(m) m.addItem(RING, ring()) end)
    local a = IF.Get(RING)
    m.items[RING].effectiveIlvl = 289
    assertTrue(IF.Get(RING) == a, "the cached table")
    assertEqual(IF.Counts(), 1)
    IF.Invalidate(RING)
    assertEqual(IF.Counts(), 0)
    assertEqual(IF.Get(RING).ilvl, 289)
    IF.Invalidate()
    assertEqual(IF.Counts(), 0)
end)

test("item facts: at its cap the cache drops its least recently used quarter, never the whole", function()
    local links = {}
    for i = 1, 9 do links[i] = ("|cnIQ4:|Hitem:%d::::::::90:::::|h[Band %d]|h|r"):format(5000 + i, i) end
    local _, m, IF = enabled(function(m)
        for _, l in ipairs(links) do m.addItem(l, ring()) end
    end)
    local cap = IF.CACHE_CAP
    IF.CACHE_CAP = 8
    for i = 1, 8 do IF.Get(links[i]) end
    IF.Get(links[1]); IF.Get(links[2])    -- used again: now the most recent
    m.items[links[3]].name = "changed"    -- a re-read would see it
    IF.Get(links[9])
    -- red under: a cache emptied whole at its cap
    assertEqual(IF.Counts(), 7, "two of eight dropped, then the new link")
    assertEqual(IF.Get(links[1]).name, "Band", "a recently used link stays")
    assertEqual(IF.Get(links[5]).name, "Band")
    assertEqual(IF.Get(links[3]).name, "changed", "the least recently used went, and is read again")
    IF.CACHE_CAP = cap
end)

test("item facts: garbage links answer nil and never raise", function()
    local _, m, IF = enabled()
    m.issecretvalue = T.isSecret
    assertNil(IF.Get(nil)); assertNil(IF.Get(42)); assertNil(IF.Get("no item here"))
    assertNil(IF.Get(T.secret(RING)))
    local f, status = IF.Request("no item here", function() error("never called") end)
    assertNil(f); assertEqual(status, "invalid")
    IF.Invalidate(42)
end)

test("item facts: learning an appearance re-reads the flag on the cached facts", function()
    local _, m, IF = enabled(function(m) m.addItem(CHEST, chest()) end)
    assertFalse(IF.Get(CHEST).transmogKnown)
    m.items[CHEST].transmog = true
    m.__fire("TRANSMOG_COLLECTION_UPDATED")
    assertTrue(IF.Get(CHEST).transmogKnown)
end)

-- ---------------------------------------------------------------------------------------------
-- Loading an uncached item
-- ---------------------------------------------------------------------------------------------

test("item facts: Request answers a cached item at once and never calls back", function()
    local _, m, IF = enabled(function(m) m.addItem(RING, ring()) end)
    local f, status = IF.Request(RING, function() error("not for a ready item") end)
    assertEqual(f.name, "Band"); assertEqual(status, "ready")
    assertEqual(#m.loadRequests, 0)
    assertEqual(m.__fireTimers(), 0)
end)

test("item facts: an uncached item loads, and every waiter is called back once", function()
    local _, m, IF = enabled(function(m) m.addItem(RING, ring({ loadsNeeded = 1 })) end)
    local got = {}
    local f, status = IF.Request(RING, function(facts, link) got[#got + 1] = { facts, link } end)
    assertNil(f); assertEqual(status, "loading")
    assertNil(IF.Get(RING))
    local _, status2 = IF.Request(RING, function(facts) got[#got + 1] = { facts } end)
    assertEqual(status2, "loading")
    assertEqual(#m.loadRequests, 1, "one load for both")
    assertEqual(m.loadRequests[1], 2001)
    local _, loading = IF.Counts()
    assertEqual(loading, 1)
    m.__fireTimers()
    assertEqual(#got, 2)
    assertEqual(got[1][1].name, "Band"); assertEqual(got[1][2], RING)
    assertTrue(got[2][1] == got[1][1], "the same cached facts")
    local cached, after = IF.Counts()
    assertEqual(cached, 1); assertEqual(after, 0)
    assertEqual(m.__fireTimers(), 0, "nothing left scheduled")
end)

test("item facts: the callback retries until the item arrives", function()
    local _, m, IF = enabled(function(m) m.addItem(RING, ring({ loadsNeeded = 3 })) end)
    local got
    IF.Request(RING, function(facts) got = facts end)
    m.__fireTimers(); m.__fireTimers()
    assertNil(got)
    m.__fireTimers()
    assertEqual(got.ilvl, 263)
    assertEqual(#m.loadRequests, 3)
end)

test("item facts: an item that never arrives is given up after MAX_LOAD_TRIES, with nil", function()
    local _, m, IF = enabled(function(m) m.addItem(RING, ring({ loadsNeeded = 99 })) end)
    local calls, got = 0, "unset"
    IF.Request(RING, function(facts)
        calls = calls + 1
        got = facts
    end)
    for _ = 1, 10 do m.__fireTimers() end
    assertEqual(calls, 1); assertNil(got)
    assertEqual(#m.loadRequests, IF.MAX_LOAD_TRIES)
    local _, loading = IF.Counts()
    assertEqual(loading, 0)
    local _, status = IF.Request(RING)
    assertEqual(status, "loading", "a later request starts a fresh load")
end)

test("item facts: a client that cannot load items answers unavailable", function()
    local _, m, IF = enabled(function(m) m.addItem(RING, ring({ loadsNeeded = 1 })) end)
    m.C_Item.RequestLoadItemDataByID = nil
    local f, status = IF.Request(RING, function() error("never called") end)
    assertNil(f); assertEqual(status, "unavailable")
    assertEqual(m.__fireTimers(), 0)
end)

-- ---------------------------------------------------------------------------------------------
-- The lifecycle
-- ---------------------------------------------------------------------------------------------

test("item facts: stood down, the cache and the loads are dropped and a late answer is ignored", function()
    local NS, m, IF = enabled(function(m)
        m.addItem(CHEST, chest())
        m.addItem(RING, ring({ loadsNeeded = 1 }))
    end)
    IF.Get(CHEST)
    local called = false
    IF.Request(RING, function() called = true end)
    NS.addon:OnSlashCommand("disable")
    assertNil(NS.State.itemFacts, "the cache is dropped")
    m.__fireTimers()
    assertFalse(called, "a load from before the stand-down is ignored")
    assertEqual(m.__fire("TRANSMOG_COLLECTION_UPDATED"), 0, "the event is down")
    NS.addon:OnSlashCommand("enable")
    assertEqual(IF.Counts(), 0)
    assertEqual(IF.Get(RING).name, "Band")
end)
