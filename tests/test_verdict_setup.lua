-- tests/test_verdict_setup.lua — core/VerdictSetup.lua and core/VerdictViews.lua (Item Search split
-- plan, task C1): this addon on LibKa0s-Verdict-1.0. What is pinned is the host, not the engine
-- (the library's own suites, and the golden suite, pin the verdicts): the one instance and its
-- client; every read through NS.Compat at call time (the simulator's seam) with this addon's own
-- PlayerRole; the instance's events as NS.FEATURE_EVENTS rows the simulator's replay reaches; the
-- gear change as GearChanged and the collection change as the feed's pass; the lazy, quiet first
-- read; the stand-down; the client named on every kernel view; the scorer from the settings; the
-- Comparison rows; and the library-absent stand-in's surface.

local T = _G.DW_TEST
local test, assertEqual, assertTrue, assertFalse, assertNil =
    T.test, T.assertEqual, T.assertTrue, T.assertFalse, T.assertNil

local INT, CRIT, HASTE = "ITEM_MOD_INTELLECT_SHORT", "ITEM_MOD_CRIT_RATING_SHORT", "ITEM_MOD_HASTE_RATING_SHORT"

local function link(id) return ("|cnIQ4:|Hitem:%d::::::::90:::::|h[Item %d]|h|r"):format(id, id) end

local function ring(ilvl, stats)
    return { name = "Ring", quality = 4, ilvl = ilvl, equipLoc = "INVTYPE_FINGER", classID = 4, subClassID = 0,
        bindType = 1, stats = stats or {} }
end

-- Counts GearChanged on a receiver of its own.
local function listen(NS)
    local seen = { n = 0 }
    NS.Bus:NewTarget():RegisterMessage(NS.MSG.GEAR_CHANGED, function() seen.n = seen.n + 1 end)
    return seen
end

-- ── the instance and its host ────────────────────────────────────────────────────────────────

test("verdict setup: one instance of the library's major, on this client", function()
    local NS, m = T.newAddon()
    -- red under: a host that names no client, or the stand-in on a live load
    assertTrue(NS.Verdict == m.LibStub("LibKa0s-Verdict-1.0"), "NS.Verdict is the major")
    assertEqual(NS.VerdictEngine:Client(), NS.Compat.ClientKey())
    assertEqual(NS.ClassData.ClientKey(), NS.Compat.ClientKey(), "the class list in force is the client's")
    assertTrue(NS.ClassData.SPECS == NS.Verdict.ClassData.ForClient(NS.Compat.ClientKey()).SPECS)
end)

test("verdict setup: every read is NS.Compat's member at the call, so the simulator's seam guards it", function()
    local NS = T.newAddon()
    local R = NS.VerdictEngine.R
    -- Answers, not identities: from Verdict minor 3 a member of v.R is a forwarder, never rawequal
    -- to the host's function (LibKa0s v1.120.0, docs/releasing.md step 8).
    local function sentinel(owner, name)
        local mark = {}
        owner[name] = function() return mark end
        return mark
    end
    local role = sentinel(NS.Compat, "PlayerRole")
    assertTrue(R.PlayerRole() == role, "this addon's own role read (its role override)")
    local info = sentinel(NS.Compat, "GetItemInfo")
    assertTrue(R.GetItemInfo(1) == info)
    -- red under: a host that hands the reads over once, at load (a seam installed later is missed)
    local slot = sentinel(NS.Compat, "InventoryItemLink")
    assertTrue(R.InventoryItemLink("player", 11) == slot, "looked up at each call")
    local load = sentinel(NS.Item, "LoadItem")
    assertTrue(R.LoadItem(1) == load, "the item load is NS.Item's")
end)

test("verdict setup: the instance's events are NS.FEATURE_EVENTS rows, the replay reaches them", function()
    local NS = T.enableAddon()
    local rows = {}
    for _, row in ipairs(NS.FEATURE_EVENTS) do
        if row[2] == "OnVerdictEvent" then rows[row[1]] = row end
    end
    for _, event in ipairs({ "PLAYER_EQUIPMENT_CHANGED", "BAG_UPDATE_DELAYED", "SPELL_TEXT_UPDATE",
        "NEW_MOUNT_ADDED", "SKILL_LINES_CHANGED" }) do
        assertTrue(rows[event] ~= nil, event .. " is a row")
    end
    local names = {}
    for _, name in ipairs(NS.FeatureEventNames()) do names[name] = true end
    assertEqual(names.PLAYER_SPECIALIZATION_CHANGED == true, not T.forever, "Retail's spec event alone")
    assertEqual(names.CHARACTER_POINTS_CHANGED == true, T.forever == true, "Forever's talent event alone")
    -- red under: an instance registering its events past NS.FEATURE_EVENTS (the replay misses them)
    assertFalse(NS.Gear.IsScheduled())
    assertTrue(NS.DeliverEvent("PLAYER_EQUIPMENT_CHANGED", 1, false) >= 1)
    assertTrue(NS.Gear.IsScheduled(), "the replayed event armed the engine's rebuild")
end)

test("verdict setup: every event the instance registers has its row on this client, and no row is dead", function()
    local NS = T.enableAddon()
    local client = NS.Compat.ClientKey()
    local rows = {}
    for _, row in ipairs(NS.FEATURE_EVENTS) do
        local serves = row.clients == nil
        for _, c in ipairs(row.clients or {}) do serves = serves or c == client end
        if row[2] == "OnVerdictEvent" and serves then rows[row[1]] = true end
    end
    local registered = NS.VerdictEngine.__registered
    assertTrue(type(registered) == "table" and #registered > 0, "the instance stood up and registered")
    local seen = {}
    for _, event in ipairs(registered) do
        seen[event] = true
        -- red under: a library minor adding an event (lib.__events) the hand-kept list lacks
        assertTrue(rows[event], event .. " is registered by the instance but has no row on " .. client)
    end
    for event in pairs(rows) do
        assertTrue(seen[event], event .. " has a row on " .. client .. " but the instance does not listen to it")
    end
end)

-- The rows' clients tag, as a set key: "both" for a row with none.
local function tagOf(row)
    if row.clients == nil then return "both" end
    local tags = {}
    for _, c in ipairs(row.clients) do tags[#tags + 1] = c end
    table.sort(tags)
    return table.concat(tags, ",")
end

test("verdict setup: the rows are the library's EventsFor of both clients, tagged by the set they are in", function()
    local NS = T.newAddon()
    local want = {}
    for _, client in ipairs({ "retail", "forever" }) do
        for _, event in ipairs(NS.Verdict.EventsFor(client)) do
            want[event] = want[event] and "both" or client
        end
    end
    local got, n = {}, 0
    for _, row in ipairs(NS.FEATURE_EVENTS) do
        if row[2] == "OnVerdictEvent" then
            assertNil(got[row[1]], row[1] .. " has one row")
            got[row[1]], n = tagOf(row), n + 1
        end
    end
    -- red under: a hand-kept list (an event a later library minor adds has no row)
    for event, tag in pairs(want) do
        assertEqual(got[event], tag, event .. "'s row")
    end
    for event in pairs(got) do assertTrue(want[event] ~= nil, event .. " is no client's event") end
    assertTrue(n > 0, "the instance's events have rows")
end)

test("verdict setup: without the library the stand-in's EventsFor answers nothing, so no row is dead", function()
    local NS = T.newAddon{ skip = T.loadAddon.libFiles }
    -- red under: rows built from a list the stand-in's instance never registers
    assertEqual(type(NS.Verdict.EventsFor), "function", "the stand-in carries EventsFor")
    for _, row in ipairs(NS.FEATURE_EVENTS) do
        assertTrue(row[2] ~= "OnVerdictEvent", row[1] .. " is a row no instance listens to")
    end
end)

test("verdict setup: the first read is lazy and quiet, a later change sends GearChanged", function()
    local NS, _, m = T.enableAddon()
    NS.ArmSkinPicker(false)
    local seen = listen(NS)
    assertNil(NS.State.gear, "nothing seen before something asks")
    m.addItem(link(100), ring(600)); m.inventory.player[11] = link(100)
    -- red under: the stand-up's read at OnEnable kept as the snapshot (the ring worn after it unseen)
    assertEqual(NS.Gear.Snapshot().equipped[11].link, link(100), "the first ask reads the client now")
    assertEqual(seen.n, 0, "the first read announces nothing")
    assertTrue(NS.State.gear ~= nil, "the mirror holds what was seen")
    m.addItem(link(101), ring(620)); m.inventory.player[11] = link(101)
    m.__fire("PLAYER_EQUIPMENT_CHANGED", 11, false)
    m.advance(NS.Gear.THROTTLE)
    assertEqual(seen.n, 1, "the engine's gear change is GearChanged")
    assertEqual(NS.State.gear.equipped[11].link, link(101))
end)

test("verdict setup: OnEnable stands the instance up lazily; the latch's stand-up reads at once", function()
    local NS = T.bootAddon()
    local got = {}
    local standUp = NS.VerdictEngine.StandUp
    NS.VerdictEngine.StandUp = function(self, opts)
        got[#got + 1] = opts == nil and "plain" or (type(opts) == "table" and opts.lazy == true and "lazy") or "other"
        return standUp(self, opts)
    end
    NS.addon:OnEnable()
    -- red under: a host standing up with a plain StandUp() and a provisional re-read of its own
    assertEqual(got[1], "lazy", "OnEnable's stand-up is the library's lazy one")
    NS.VerdictStandUp()
    assertEqual(got[#got], "plain", "the latch's stand-up reads and announces")
    assertNil(NS.VerdictFresh, "no provisional re-read is left on the host")
end)

test("verdict setup: a gear event before the first ask reads the client and announces", function()
    local NS, _, m = T.enableAddon()
    NS.ArmSkinPicker(false)
    local seen = listen(NS)
    m.addItem(link(100), ring(600)); m.inventory.player[11] = link(100)
    m.__fire("PLAYER_EQUIPMENT_CHANGED", 11, false)
    m.advance(NS.Gear.THROTTLE)
    assertEqual(seen.n, 1, "the rebuild before any ask is GearChanged")
    assertEqual(NS.State.gear.equipped[11].link, link(100))
    assertEqual(NS.Gear.Snapshot().equipped[11].link, link(100), "the ask keeps that snapshot")
    assertEqual(seen.n, 1, "and announces nothing more")
end)

test("verdict setup: a stand-up that throws at OnEnable keeps the settings category and its message", function()
    local NS, _, m = T.bootAddon()
    local registered = false
    local register = NS.addon.Settings.Register
    NS.addon.Settings.Register = function(...) registered = true; return register(...) end
    NS.VerdictEngine.StandUp = function() error("verdict boom") end
    local ok, err = pcall(NS.addon.OnEnable, NS.addon)
    -- red under: the engine stood up ahead of the category (a throw there costs the settings panel)
    assertFalse(ok, "the stand-up's error still reaches the client")
    assertTrue(registered, "the settings category registered before the engine stood up")
    assertTrue(tostring(err):find("verdict boom", 1, true) ~= nil, "the message is kept")
    NS.VerdictEngine.StandUp = nil
    local seen = listen(NS)
    m.addItem(link(100), ring(600)); m.inventory.player[11] = link(100)
    NS.VerdictStandUp()
    -- red under: a stand-up that stays quiet after a throw (no gear change is ever announced again)
    assertEqual(seen.n, 1, "a later stand-up announces its read")
end)

test("verdict setup: the stand-down stands the instance down and drops the mirror; the stand-up returns", function()
    local NS = T.enableAddon()
    NS.ArmSkinPicker(false)
    NS.Gear.Snapshot()
    NS.addon:OnSlashCommand("disable")
    assertTrue(NS.VerdictEngine:IsStoodDown())
    assertNil(NS.State.gear)
    NS.addon:OnSlashCommand("enable")
    assertFalse(NS.VerdictEngine:IsStoodDown())
end)

test("verdict setup: the gear rebuild is timed while a capture is on, through the harness itself", function()
    local NS = T.enableAddon()
    local noted = {}
    NS.Perf.Note = function(key) noted[#noted + 1] = key end
    NS.Perf.on = false
    NS.Gear.Refresh("test")
    assertEqual(#noted, 0, "no note while the capture is off")
    NS.Perf.on = true
    NS.Gear.Refresh("test")
    NS.Perf.on = false
    assertEqual(noted[1], "gear.rebuild", "the rebuild noted while it is on")
    -- red under: a proxy whose `on` is a metatable lookup (a function call on every dormant bracket)
    assertTrue(NS.VerdictEngine.host.perf == NS.Perf, "the host's perf is NS.Perf, `on` a plain field")
end)

test("verdict setup: the engine's collection change runs the feed's pass", function()
    local NS = T.newAddon()
    local ran = 0
    NS.CollectFeed.OnCollectionsChanged = function() ran = ran + 1 end
    NS.VerdictEngine.host.onChange("collection")
    assertEqual(ran, 1)
end)

-- ── the views name the client ───────────────────────────────────────────────────────────────

test("verdict views: every kernel call names the client in force, and the caller's opts stay unwritten", function()
    local NS = T.newAddon()
    local V, got = NS.Verdict, {}
    local evaluate, equip = V.Evaluate, V.Equippability
    V.Evaluate = function(f, c, o) got.eval = o.client; return evaluate(f, c, o) end
    V.Equippability = function(f, c, client) got.equip = client; return equip(f, c, client) end
    local opts = { sidegradeBand = 1 }
    NS.Evaluate.Evaluate({}, {}, opts)
    NS.Evaluate.Equippability({}, {})
    -- red under: a view that leaves the client out (the library reads none as Retail's, no off-spec)
    assertEqual(got.eval, NS.Compat.ClientKey()); assertEqual(got.equip, NS.Compat.ClientKey())
    assertNil(opts.client, "a fresh table is handed on")
    NS.ClassData.Install(NS.ClassData.LISTS.forever)
    NS.Evaluate.Evaluate({}, {}, {})
    assertEqual(got.eval, "forever", "the installed list's client")
end)

-- ── the scorer from the settings (moved from test_scoring) ──────────────────────────────────

test("verdict setup: InUse and Scorer follow the settings and whether Pawn is initialized", function()
    local NS, _, m = T.enableAddon()
    T.retailList(NS)   -- weights keyed by Retail's specID
    local S, Set = NS.Scoring, NS.SchemaRuntime.Set
    assertEqual(S.InUse(NS.LootFeed.VerdictConfig()), "none")
    assertNil(S.Scorer(NS.LootFeed.VerdictConfig()), "no Pawn and no weights: item level alone")
    Set("comparison.weights", { [250] = { [INT] = 1 } })
    assertEqual(S.InUse(NS.LootFeed.VerdictConfig()), "weights")
    m.loadedAddons.Pawn = true
    -- red under: an InUse that counts a loaded Pawn
    assertEqual(S.InUse(NS.LootFeed.VerdictConfig()), "weights", "loaded but not initialized: your weights")
    Set("comparison.scorer", "pawn")
    assertEqual(S.InUse(NS.LootFeed.VerdictConfig()), "none", "pawn asked for, not initialized: item level alone")
    m.PawnIsReady = function() return true end
    assertEqual(S.InUse(NS.LootFeed.VerdictConfig()), "pawn")
    Set("comparison.scorer", "none")
    assertNil(S.Scorer(NS.LootFeed.VerdictConfig()))
    m.loadedAddons.Pawn, m.PawnIsReady = nil, nil
end)

test("verdict setup: the feed judges your drop with your weights once they are set", function()
    local NS, _, m = T.enableAddon({ mock = function(m)
        m.__context.inInstance, m.__context.instanceType = true, "party"
        m.instance = { name = "The Rookery", difficultyID = 2 }
    end })
    m.addItem(link(100), ring(600, { [CRIT] = 100 }))
    m.addItem(link(101), ring(600, { [CRIT] = 100 }))
    m.inventory.player[11], m.inventory.player[12] = link(100), link(101)
    if T.forever then m.seedTalents(1487, { { name = "Arcane", spent = 31 } }) end
    local key = T.forever and "MAGE:1" or 250
    NS.Gear.Refresh("test")
    NS.SchemaRuntime.Set("comparison.weights", { [key] = { [CRIT] = 1, [HASTE] = 0.5 } })
    m.addItem(link(300), ring(610, { [HASTE] = 100 }))
    NS.LootFeed.Add(link(300))
    local rec = NS.LootFeed.Drops()[1]
    assertEqual(rec.me.scoreDelta, -50)
    -- Retail: item level up, score down, a sidegrade; Forever: score first, a downgrade.
    assertEqual(rec.me.verdict, T.forever and "downgrade" or "sidegrade")
end)

-- ── the Comparison rows ─────────────────────────────────────────────────────────────────────

test("verdict setup: the Comparison rows are the library's six, their defaults the profile's", function()
    local NS = T.newAddon()
    local P = NS.C.PROFILE.comparison
    for _, key in ipairs(NS.Verdict.Settings.KEYS) do
        local row = NS.SchemaRuntime.FindRow("comparison." .. key)
        assertTrue(row ~= nil, key .. " is a row")
        assertTrue(row.default == P[key], key .. ": the default is defaults/Profile.lua's")
    end
    local d = NS.Verdict.Settings.DEFAULTS
    assertEqual(P.scorer, d.scorer); assertEqual(P.sidegradeBand, d.sidegradeBand)
    assertEqual(P.compareOwned, d.compareOwned); assertEqual(P.heirloomProtect, d.heirloomProtect)
end)

-- ── the library-absent stand-in ─────────────────────────────────────────────────────────────

-- The instance's hooks for the library's own secondary files: this addon calls none of them
-- (`grep -rn "VerdictEngine:\(Changed\|Debug\|PerfStart\|PerfNote\|Config\|ClassData\)" core modules
-- settings` finds no call site).
local HOOKS = { Changed = true, Debug = true, DebugOnce = true, PerfStart = true, PerfNote = true,
    Config = true, ClassData = true }

test("verdict setup: without the library the stand-in carries the instance's surface and judges unknown", function()
    local live = T.newAddon()
    local NS = T.newAddon{ skip = T.loadAddon.libFiles }
    assertTrue(NS.Verdict.MISSING == true, "the stand-in")
    for name in pairs(getmetatable(live.VerdictEngine).__index) do
        if not HOOKS[name] then
            assertEqual(type(NS.VerdictEngine[name]), "function", name .. " is on the stand-in")
        end
    end
    assertEqual(NS.Evaluate.Evaluate({}, {}, {}).verdict, "unknown")
    assertNil(NS.ItemFacts.Get(link(1)))
    assertEqual(type(NS.Gear.Snapshot().equipped), "table")
end)
