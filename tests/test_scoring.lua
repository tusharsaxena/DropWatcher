-- tests/test_scoring.lua — modules/Scoring.lua (design spec §5.4): the Pawn scale import, the
-- weights score and its unknown keys, which adapter is in use for each setting, the Pawn adapter
-- for you and for a looter (its scales, "pending" while Pawn is not ready), and the sidegrade the
-- kernel reaches when item level and score disagree, through the kernel and through the feed.

local T = _G.DW_TEST
local test, assertEqual, assertTrue, assertFalse, assertNil =
    T.test, T.assertEqual, T.assertTrue, T.assertFalse, T.assertNil

local STR, INT = "ITEM_MOD_STRENGTH_SHORT", "ITEM_MOD_INTELLECT_SHORT"
local CRIT, HASTE = "ITEM_MOD_CRIT_RATING_SHORT", "ITEM_MOD_HASTE_RATING_SHORT"

local PAWN = '( Pawn: v1: "Arms": Class=1, Spec=1, Strength=1.50, CritRating=0.8, HasteRating=0.60,'
    .. ' Versatility=0, Dps=3.2, IsPlate=1, Leech=0.1 )'

local function pure()
    local NS = T.newAddon()
    return NS.Scoring, NS
end

local function count(t)
    local n = 0
    for _ in pairs(t) do n = n + 1 end
    return n
end

-- ---------------------------------------------------------------------------------------------
-- The Pawn scale import
-- ---------------------------------------------------------------------------------------------

test("scoring: a Pawn v1 string imports its stats under GetItemStats' keys", function()
    local S = pure()
    local r = S.ParseImport(PAWN)
    assertEqual(r.name, "Arms")
    assertEqual(r.weights[STR], 1.5)
    assertEqual(r.weights[CRIT], 0.8)
    assertEqual(r.weights[HASTE], 0.6)
    assertEqual(r.weights.ITEM_MOD_CR_LIFESTEAL_SHORT, 0.1)
    assertNil(r.weights.ITEM_MOD_VERSATILITY, "a 0 weight is left out")
    assertEqual(count(r.weights), 4)
    -- Class and Spec are the header, read past quietly; the rest is reported, sorted.
    assertEqual(table.concat(r.skipped, ","), "Dps,IsPlate")
end)

test("scoring: an import that is empty, not a Pawn string, or has no stat is refused with its reason", function()
    local S = pure()
    local r, why = S.ParseImport("   ")
    assertNil(r); assertEqual(why, "empty")
    r, why = S.ParseImport(nil)
    assertNil(r); assertEqual(why, "empty")
    r, why = S.ParseImport("Strength=1, Agility=2")
    assertNil(r); assertEqual(why, "format")
    r, why = S.ParseImport('( Pawn: v2: "X": Strength=1 )')
    assertNil(r); assertEqual(why, "format")
    r, why = S.ParseImport('( Pawn: v1: "Tank": Class=1, Armor=2, Dps=1 )')
    assertNil(r); assertEqual(why, "noStats")
    r = S.ParseImport('(Pawn:v1:"Tight":Intellect=2,Stamina=garbage)')
    assertEqual(r.weights[INT], 2, "spacing is free; a pair without a number is ignored")
end)

test("scoring: ImportInto replaces one spec's weights in a fresh map and keeps the others", function()
    local S = pure()
    local stored = { [71] = { [STR] = 9, [CRIT] = 9 }, [72] = { [HASTE] = 1 } }
    local out, r = S.ImportInto(stored, 71, PAWN)
    assertEqual(r.name, "Arms")
    assertEqual(out[71][STR], 1.5)
    assertNil(out[71].ITEM_MOD_VERSATILITY)
    assertEqual(out[72][HASTE], 1)
    assertTrue(out ~= stored and out[72] ~= stored[72], "a fresh table, nothing shared with the stored one")
    assertEqual(stored[71][STR], 9, "the stored map is untouched")
    local none, why = S.ImportInto(stored, nil, PAWN)
    assertNil(none); assertEqual(why, "noSpec")
    none, why = S.ImportInto(stored, 71, "nope")
    assertNil(none); assertEqual(why, "format")
    assertEqual(S.ImportInto(nil, 73, PAWN)[73][STR], 1.5, "from no map")
end)

-- ---------------------------------------------------------------------------------------------
-- The weights score
-- ---------------------------------------------------------------------------------------------

test("scoring: a weights score is the sum of stat times weight", function()
    local S = pure()
    assertEqual(S.WeightsScore({ [STR] = 100, [CRIT] = 50, [HASTE] = 10 }, { [STR] = 2, [CRIT] = 0.5 }), 225)
    assertEqual(S.WeightsScore({}, { [STR] = 2 }), 0, "an item without the stat scores 0")
    assertNil(S.WeightsScore(nil, { [STR] = 2 }))
    assertNil(S.WeightsScore({ [STR] = 1 }, nil))
    assertNil(S.WeightsScore({ [STR] = 1 }, {}), "no weights is no score")
end)

test("scoring: a weight on an unknown stat key counts 0 and is logged once per key", function()
    local S, NS = pure()
    local logged = {}
    NS.DebugOnce = function(key, tag) logged[#logged + 1] = tag .. ":" .. tostring(key) end
    local w = { [STR] = 1, ITEM_MOD_MADE_UP = 5 }
    assertEqual(S.WeightsScore({ [STR] = 10, ITEM_MOD_MADE_UP = 99 }, w), 10)
    S.WeightsScore({ [STR] = 10 }, w)
    assertEqual(logged[1], "SCORE:weight:ITEM_MOD_MADE_UP")
    -- DebugOnce is the gate: the same key every time, so the console hears it once.
    assertEqual(logged[2], logged[1])
end)

test("scoring: HasWeights is true once any spec has a weight", function()
    local S = pure()
    assertFalse(S.HasWeights(nil))
    assertFalse(S.HasWeights({}))
    assertFalse(S.HasWeights({ [62] = {} }))
    assertTrue(S.HasWeights({ [62] = { [INT] = 1 } }))
end)

-- ---------------------------------------------------------------------------------------------
-- The adapter in use
-- ---------------------------------------------------------------------------------------------

test("scoring: Resolve picks the adapter for every setting, Pawn presence and weights", function()
    local S = pure()
    local rows = {
        -- configured, pawnReady, hasWeights, in use
        { "auto",    true,  true,  "pawn" },
        { "auto",    false, true,  "weights" },
        { "auto",    false, false, "none" },
        { "pawn",    true,  false, "pawn" },
        { "pawn",    false, true,  "none" },
        { "weights", true,  true,  "weights" },
        { "weights", true,  false, "none" },
        { "none",    true,  true,  "none" },
        { "bogus",   false, true,  "weights" },
        { nil,       true,  false, "pawn" },
    }
    for _, r in ipairs(rows) do
        assertEqual(S.Resolve(r[1], r[2], r[3]), r[4], tostring(r[1]) .. "/" .. tostring(r[2]) .. "/" .. tostring(r[3]))
    end
end)

test("scoring: InUse and Scorer follow the settings and whether Pawn is initialized", function()
    local NS, _, m = T.enableAddon()
    T.retailList(NS)   -- weights keyed by Retail's specID (Forever's by talent tree is below)
    local S, Set = NS.Scoring, NS.SchemaRuntime.Set
    assertEqual(S.InUse(), "none")
    assertNil(S.Scorer(), "no Pawn and no weights: item level alone")
    Set("comparison.weights", { [250] = { [INT] = 1 } })
    assertEqual(S.InUse(), "weights")
    assertEqual(S.Scorer()({ stats = { [INT] = 7 } }, { specID = 250 }), 7)
    -- Loaded is not enough: the adapter is present only once PawnIsReady() is true (design spec
    -- §5.4; DW-62 review F-003). Until then auto keeps your weights.
    m.loadedAddons.Pawn = true
    -- red under: an InUse that counts a loaded Pawn (modules/Scoring.lua)
    assertEqual(S.InUse(), "weights", "loaded but not initialized: your weights")
    assertEqual(S.Scorer()({ stats = { [INT] = 7 } }, { specID = 250 }), 7)
    Set("comparison.scorer", "pawn")
    assertEqual(S.InUse(), "none", "pawn asked for, not initialized: item level alone")
    m.PawnIsReady = function() return true end
    assertEqual(S.InUse(), "pawn")
    Set("comparison.scorer", "auto")
    assertEqual(S.InUse(), "pawn", "auto prefers an initialized Pawn")
    Set("comparison.scorer", "weights")
    assertEqual(S.InUse(), "weights")
    Set("comparison.scorer", "none")
    assertNil(S.Scorer())
    m.loadedAddons.Pawn, m.PawnIsReady = nil, nil
end)

-- ---------------------------------------------------------------------------------------------
-- The Pawn adapter
-- ---------------------------------------------------------------------------------------------

-- A Pawn fake. `values[scale][link]` is an item's value; `upgrades[link]` the drop's upgrade list
-- against your gear (nil: not read yet). Every call is recorded.
local function installPawn(m, values, upgrades)
    local calls = {}
    m.PawnIsReady = function() return true end
    m.PawnGetItemData = function(link) return { link = link } end
    m.PawnIsItemAnUpgrade = function(data)
        calls[#calls + 1] = "upgrade:" .. data.link
        return upgrades[data.link]
    end
    m.PawnFindScaleForSpec = function(classID, specIndex) return "S" .. classID .. ":" .. specIndex end
    m.PawnGetSingleValueFromItem = function(data, scale)
        calls[#calls + 1] = "value:" .. data.link .. "@" .. scale
        return values[scale] and values[scale][data.link]
    end
    return calls
end

test("scoring: for you, Pawn values the drop and the baseline on the drop's best visible scale", function()
    local NS, _, m = T.enableAddon()
    T.retailList(NS)   -- Retail's model (Forever's by talent tree is below)
    local calls = installPawn(m, { Tank = { drop = 50, worn = 40 }, Dps = { drop = 80, worn = 60 } },
        { drop = { { ScaleName = "Tank", PercentUpgrade = 0.05 }, { ScaleName = "Dps", PercentUpgrade = 0.2 } } })
    local score = NS.Scoring.PawnScorer()
    local drop, me = { link = "drop" }, { isPlayer = true, classFile = "MAGE", specID = 62 }
    assertEqual(score(drop, me, drop), 80)
    assertEqual(score({ link = "worn" }, me, drop), 60)
    local reads = 0
    for _, c in ipairs(calls) do if c == "upgrade:drop" then reads = reads + 1 end end
    assertEqual(reads, 1, "the scale is read once per drop")
end)

test("scoring: for you, a drop that upgrades no scale is valued on your spec's scale", function()
    local NS, _, m = T.enableAddon()
    T.retailList(NS)   -- Pawn's Retail spec index (Forever's by talent tree is below)
    installPawn(m, { ["S8:1"] = { drop = 10, worn = 12 } }, { drop = {} })
    local score = NS.Scoring.PawnScorer()
    local drop, me = { link = "drop" }, { isPlayer = true, classFile = "MAGE", specID = 62 }
    assertEqual(score(drop, me, drop), 10)
    assertEqual(score({ link = "worn" }, me, drop), 12)
end)

test("scoring: for you, a drop that upgrades no scale is valued on the scale you show in Pawn", function()
    local NS, _, m = T.enableAddon()
    T.retailList(NS)   -- Pawn's Retail spec index (Forever's by talent tree is below)
    installPawn(m, { ["S8:1"] = { drop = 90, worn = 10 }, Mine = { drop = 10, worn = 12 } }, { drop = {} })
    m.PawnCommon = { Scales = { ["S8:1"] = { ClassID = 8, SpecID = 1, Provider = "P", ProviderActive = true },
        Mine = {} } }
    m.PawnIsScaleVisible = function(name) return name == "Mine" end
    local score = NS.Scoring.PawnScorer()
    local drop, me = { link = "drop" }, { isPlayer = true, classFile = "MAGE", specID = 62 }
    -- red under: a scorer that falls back to the starter scale you hid (PawnFindScaleForSpec)
    assertEqual(score(drop, me, drop), 10)
    assertEqual(score({ link = "worn" }, me, drop), 12)
end)

test("scoring: for a looter, Pawn uses the scale for their class and spec", function()
    local NS, _, m = T.enableAddon()
    T.retailList(NS)   -- Pawn's Retail spec index (Forever's by talent tree is below)
    installPawn(m, { ["S1:1"] = { drop = 30, theirs = 25 } }, {})
    local score = NS.Scoring.PawnScorer()
    local drop = { link = "drop" }
    local brakk = { isPlayer = false, classFile = "WARRIOR", specID = 71 }
    assertEqual(score(drop, brakk, drop), 30)
    assertEqual(score({ link = "theirs" }, brakk, drop), 25)
    assertNil(score(drop, { classFile = "WARRIOR", specID = 999 }, drop), "a spec Pawn cannot be asked for: no score")
    assertNil(score(drop, { classFile = "WARRIOR" }, drop), "no spec: no score")
    assertNil(score({}, brakk, drop), "no link: no score")
end)

test("scoring: Pawn answers pending while it is not ready or has not read the item", function()
    local NS, _, m = T.enableAddon()
    T.retailList(NS)   -- Pawn's Retail spec index (Forever's by talent tree is below)
    installPawn(m, { ["S1:1"] = { drop = 30 } }, {})
    local score = NS.Scoring.PawnScorer()
    local drop = { link = "drop" }
    local brakk = { classFile = "WARRIOR", specID = 71 }
    assertEqual(score({ link = "uncached" }, brakk, drop), "pending", "a nil value is not ready")
    assertEqual(score(drop, { isPlayer = true, classFile = "MAGE", specID = 62 }, drop), "pending",
        "your drop's upgrade list not read yet")
    m.PawnIsReady = function() return nil end
    assertEqual(score(drop, brakk, drop), "pending")
end)

-- ---------------------------------------------------------------------------------------------
-- Pawn and the weights on WoW Forever (Forever port design §4.3)
-- ---------------------------------------------------------------------------------------------

-- Installs WoW Forever's class list (core/ClassDataForever.lua) on either kit profile: the scoring
-- by talent tree is pure code over it, as T.retailList pins Retail's.
local function foreverList(NS)
    NS.ClassData.Install(NS.ClassData.LISTS.forever)
    return NS
end

-- Forever's Pawn (2.14.1, research R4 §10): no specs, one Classic scale per talent tree, named
-- "<CLASS><index>", carrying ClassID and SpecID = the index; PawnFindScaleForSpec matches SpecID.
-- `classes` = { { "HUNTER", 3, 3 }, ... } (classFile, classID, scales); `values[scale][link]`;
-- `upgrades[link]` PawnIsItemAnUpgrade's list; `visible` the scales Pawn shows (all by default).
local function installClassicPawn(m, classes, values, upgrades, visible)
    local scales = {}
    for _, c in ipairs(classes) do
        for i = 1, c[3] do
            scales[c[1] .. i] = { ClassID = c[2], SpecID = i, Provider = "Classic", ProviderActive = true }
        end
    end
    m.PawnIsReady = function() return true end
    m.PawnCommon = { Scales = scales }
    m.PawnIsScaleVisible = function(name) return scales[name] ~= nil and (visible == nil or visible[name] == true) end
    m.PawnGetItemData = function(link) return { link = link } end
    m.PawnIsItemAnUpgrade = function(data) return (upgrades or {})[data.link] end
    m.PawnFindScaleForSpec = function(classID, specID)
        for name, s in pairs(scales) do
            if s.ClassID == classID and s.SpecID == specID and s.Provider then return name end
        end
    end
    m.PawnGetSingleValueFromItem = function(data, scale) return values[scale] and values[scale][data.link] end
    return scales
end

local HUNTER = { { "HUNTER", 3, 3 } }

test("scoring: on Forever your score uses the scale of your top talent tree", function()
    local NS, _, m = T.enableAddon()
    foreverList(NS)
    local scales = installClassicPawn(m, HUNTER, {
        HUNTER1 = { drop = 10, worn = 8 }, HUNTER2 = { drop = 20, worn = 25 }, HUNTER3 = { drop = 90, worn = 10 },
    }, { drop = { { ScaleName = "HUNTER3", PercentUpgrade = 0.8 } } })
    local drop, me = { link = "drop" }, { isPlayer = true, classFile = "HUNTER", specID = 1485, tree = 2 }
    local score = NS.Scoring.PawnScorer()
    -- red under: a scorer that takes the drop's best visible scale (the tree that gains most, HUNTER3)
    assertEqual(score(drop, me, drop), 20)
    assertEqual(score({ link = "worn" }, me, drop), 25)
    local v, how = NS.Scoring.ScoreFor("drop", me)
    assertEqual(v, 20); assertEqual(how, "tree")
    -- A visible custom scale of your class wins, as on Retail.
    scales.Mine = {}
    m.PawnGetSingleValueFromItem = function(data, scale) return scale == "Mine" and #data.link or nil end
    v, how = NS.Scoring.ScoreFor("drop", me)
    assertEqual(v, 4); assertEqual(how, "custom")
end)

test("scoring: with no tree, the best of your class's scales, how = bestOfClass", function()
    local NS, _, m = T.enableAddon()
    foreverList(NS)
    installClassicPawn(m, HUNTER, {
        HUNTER1 = { drop = 10, worn = 8 }, HUNTER2 = { drop = 30, worn = 25 }, HUNTER3 = { drop = 20, worn = 1 },
    })
    local drop, me = { link = "drop" }, { isPlayer = true, classFile = "HUNTER", specID = 1485 }
    local score = NS.Scoring.PawnScorer()
    assertEqual(score(drop, me, drop), 30)
    assertEqual(score({ link = "worn" }, me, drop), 25, "the baseline on the drop's scale")
    local v, how = NS.Scoring.ScoreFor("drop", me)
    assertEqual(v, 30); assertEqual(how, "bestOfClass")
    m.PawnGetItemData = function(link) if link ~= "drop" then return { link = link } end end
    assertEqual(NS.Scoring.PawnScorer()(drop, me, drop), "pending", "the drop not read by Pawn yet")
end)

test("scoring: another player is scored with the best of their class's scales", function()
    local NS, _, m = T.enableAddon()
    foreverList(NS)
    -- Another class's scales are hidden from you; they still value the item.
    installClassicPawn(m, HUNTER, {
        HUNTER1 = { drop = 10, theirs = 9 }, HUNTER2 = { drop = 30, theirs = 12 }, HUNTER3 = { drop = 20 },
    }, nil, {})
    local drop = { link = "drop" }
    local them = { isPlayer = false, classFile = "HUNTER", specID = 1485 }
    local score = NS.Scoring.PawnScorer()
    assertEqual(score(drop, them, drop), 30)
    assertEqual(score({ link = "theirs" }, them, drop), 12)
    local v, how = NS.Scoring.ScoreFor("drop", them)
    assertEqual(v, 30); assertEqual(how, "bestOfClass")
    -- A class Pawn has no scale for: no score, so item level decides.
    assertNil(score(drop, { isPlayer = false, classFile = "ROGUE", specID = 1484 }, drop))
    v, how = NS.Scoring.ScoreFor("drop", { isPlayer = false, classFile = "ROGUE" })
    assertNil(v); assertEqual(how, "none")
end)

test("scoring: Feral Druid tank uses Pawn 3, damage Pawn 2", function()
    local NS, _, m = T.enableAddon()
    foreverList(NS)
    installClassicPawn(m, { { "DRUID", 11, 4 } }, {
        DRUID1 = { drop = 1 }, DRUID2 = { drop = 2 }, DRUID3 = { drop = 3 }, DRUID4 = { drop = 4 },
    })
    local drop = { link = "drop" }
    local feral = { isPlayer = true, classFile = "DRUID", specID = 1447, tree = 2 }
    NS.addon.db.char = {}   -- AceDB's per-character table, the role store's home (the kit seeds none)
    assertTrue(NS.Compat.SetRoleOverride("TANK"))
    assertEqual(NS.Scoring.PawnScorer()(drop, feral, drop), 3)
    assertTrue(NS.Compat.SetRoleOverride("DAMAGER"))
    assertEqual(NS.Scoring.PawnScorer()(drop, feral, drop), 2)
    local resto = { isPlayer = true, classFile = "DRUID", specID = 1447, tree = 3 }
    assertEqual(NS.Scoring.PawnScorer()(drop, resto, drop), 4, "Restoration is Pawn 4")
    local balance = { isPlayer = true, classFile = "DRUID", specID = 1447, tree = 1 }
    assertEqual(NS.Scoring.PawnScorer()(drop, balance, drop), 1)
end)

test("scoring: on Forever the weights are keyed by class and talent tree", function()
    local NS = foreverList(T.newAddon())
    local S = NS.Scoring
    local AGI = "ITEM_MOD_AGILITY_SHORT"
    local map = { ["HUNTER:1"] = { [AGI] = 1 }, ["HUNTER:2"] = { [AGI] = 3 }, [1485] = { [AGI] = 100 } }
    local scorer = S.WeightsScorer(map)
    local drop = { stats = { [AGI] = 10 } }
    -- red under: a weights scorer that reads map[specID], the class-wide spec every tree shares
    assertEqual(scorer(drop, { isPlayer = true, classFile = "HUNTER", specID = 1485, tree = 1 }, drop), 10)
    assertEqual(scorer(drop, { isPlayer = false, classFile = "HUNTER", specID = 1485 }, drop), 30,
        "no tree: the best of the class's trees")
    assertNil(scorer(drop, { classFile = "HUNTER", specID = 1485, tree = 3 }, drop), "a tree with no weights")
    assertEqual(NS.ClassData.SpecKey("HUNTER", 1485, 2), "HUNTER:2")
    assertNil(NS.ClassData.SpecKey("HUNTER", 1485, nil))
    local out = S.ImportInto(map, "HUNTER:3", '( Pawn: v1: "BM": Agility=2 )')
    assertEqual(out["HUNTER:3"][AGI], 2, "an import into a tree")
end)

test("scoring: ScoreFor with your weights is how = custom, and none without a scorer", function()
    local NS, _, m = T.enableAddon()
    T.retailList(NS)
    local v, how = NS.Scoring.ScoreFor("x", { classFile = "MAGE", specID = 62 })
    assertNil(v); assertEqual(how, "none")
    local link = "|cnIQ4:|Hitem:100::::::::90:::::|h[Item 100]|h|r"
    m.addItem(link, { name = "Item", quality = 4, ilvl = 600, equipLoc = "INVTYPE_FINGER", classID = 4,
        subClassID = 0, bindType = 1, stats = { [CRIT] = 10 } })
    NS.SchemaRuntime.Set("comparison.weights", { [62] = { [CRIT] = 2 } })
    v, how = NS.Scoring.ScoreFor(link, { classFile = "MAGE", specID = 62 })
    assertEqual(v, 20); assertEqual(how, "custom")
end)

-- ---------------------------------------------------------------------------------------------
-- The sidegrade: item level and score through the kernel and the feed
-- ---------------------------------------------------------------------------------------------

local function ring(ilvl, stats)
    return { itemID = 1, ilvl = ilvl, equipLoc = "INVTYPE_FINGER", classID = 4, subClassID = 0, stats = stats }
end

local function wearer(a, b)
    return { classFile = "MAGE", specID = 62, gear = { [11] = a, [12] = b } }
end

test("scoring: the kernel hands the scorer the drop beside each item", function()
    local NS = T.newAddon()
    local seen = {}
    local drop = ring(610, {})
    NS.Evaluate.Evaluate(drop, wearer(ring(600, {}), ring(600, {})), {
        scorer = function(f, _, d) seen[#seen + 1] = d == drop and (f == drop and "drop" or "base") or "?" return 1 end,
    })
    assertEqual(table.concat(seen, ","), "drop,base")
end)

test("scoring: with weights, a higher item level that scores lower is a sidegrade", function()
    local NS = T.newAddon()
    T.retailList(NS)   -- Retail's model (Forever's by talent tree is below)
    local scorer = NS.Scoring.WeightsScorer({ [62] = { [CRIT] = 1, [HASTE] = 0.5 } })
    local who = wearer(ring(600, { [CRIT] = 100 }), ring(600, { [CRIT] = 100 }))
    local out = NS.Evaluate.Evaluate(ring(610, { [HASTE] = 100 }), who, { scorer = scorer })
    assertEqual(out.verdict, "sidegrade")
    assertEqual(out.scoreDelta, -50)
    local disagrees = false
    for _, r in ipairs(out.reasons) do if r.key == "scoreDisagrees" then disagrees = true end end
    assertTrue(disagrees, "the reason says why")
    out = NS.Evaluate.Evaluate(ring(610, { [CRIT] = 120 }), who, { scorer = scorer })
    assertEqual(out.verdict, "upgrade", "both agree")
    out = NS.Evaluate.Evaluate(ring(602, { [CRIT] = 120 }), who, { scorer = scorer, sidegradeBand = 5 })
    assertEqual(out.verdict, "sidegrade", "item level within the band, score up")
    out = NS.Evaluate.Evaluate(ring(610, { [CRIT] = 120 }), wearer(ring(600, {}), ring(600, {})),
        { scorer = NS.Scoring.WeightsScorer({ [63] = { [CRIT] = 1 } }) })
    assertNil(out.scoreDelta, "another spec's weights do not score this one")
    assertEqual(out.verdict, "upgrade")
end)

test("scoring: the feed judges your drop with your weights once they are set", function()
    local NS, _, m = T.enableAddon({ mock = function(m)
        m.__context.inInstance, m.__context.instanceType = true, "party"
        m.instance = { name = "The Rookery", difficultyID = 2 }
    end })
    local function link(id) return ("|cnIQ4:|Hitem:%d::::::::90:::::|h[Item %d]|h|r"):format(id, id) end
    local function def(ilvl, stats)
        return { name = "Item", quality = 4, ilvl = ilvl, equipLoc = "INVTYPE_FINGER", classID = 4,
            subClassID = 0, bindType = 1, stats = stats }
    end
    m.addItem(link(100), def(600, { [CRIT] = 100 }))
    m.addItem(link(101), def(600, { [CRIT] = 100 }))
    m.inventory.player[11], m.inventory.player[12] = link(100), link(101)
    -- WoW Forever: the spec is class-wide and read through C_SpecializationInfo, and the weights are
    -- keyed by class and talent tree (design §4.2, §4.3).
    if T.forever then m.seedTalents(1487, { { name = "Arcane", spent = 31 } }) end
    local key = T.forever and "MAGE:1" or 250
    NS.Gear.Refresh("test")
    NS.SchemaRuntime.Set("comparison.weights", { [key] = { [CRIT] = 1, [HASTE] = 0.5 } })
    m.addItem(link(300), def(610, { [HASTE] = 100 }))
    NS.LootFeed.Add(link(300))
    local rec = NS.LootFeed.Drops()[1]
    assertEqual(rec.me.scoreDelta, -50)
    assertEqual(rec.me.verdict, "sidegrade")
end)
