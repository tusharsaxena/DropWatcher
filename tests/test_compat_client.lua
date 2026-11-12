-- tests/test_compat_client.lua — the client, Role and name reads of the compat family (Forever port
-- design §4.1, §4.2; clients-§3, clients-§4, client-quirks-§5): the client helpers routed from
-- LibKa0s-Compat-1.0 (core/Compat.lua) on each kit profile, the whole character name, the
-- player's talent tree and role through LibKa0s-Role-1.0 (core/CompatClient.lua), the inspect spec
-- ladder, and NS.FEATURE_EVENTS rows gated by their `clients`. Each case runs on both profiles
-- (`KA0S_KIT_CLIENT=forever lua tests/run.lua`) and picks its expectation by ClientKey()
-- (clients-§6).

local T = _G.DW_TEST
local test, assertEqual, assertTrue, assertFalse, assertNil =
    T.test, T.assertEqual, T.assertTrue, T.assertFalse, T.assertNil

local PROFILE = os.getenv("KA0S_KIT_CLIENT") or "retail"

local function fresh(opts)
    local NS, _, m = T.newAddon(opts)
    return NS.Compat, m, NS
end

-- ── the client ──────────────────────────────────────────────────────────────────────────────

test("compat client: ClientKey answers the kit profile", function()
    local Compat = fresh()
    assertEqual(Compat.ClientKey(), PROFILE)
    assertEqual(Compat.IsForever(), PROFILE == "forever")
    assertEqual(Compat.IsRetail(), PROFILE == "retail")
    -- the library-absent stub answers the same from the same constants
    local degraded = fresh{ skip = T.loadAddon.libFiles }
    assertEqual(degraded.ClientKey(), PROFILE)
    assertEqual(degraded.IsForever(), PROFILE == "forever")
    assertEqual(degraded.IsRetail(), PROFILE == "retail")
end)

test("compat client: ForClient(nil) is true, ForClient({\"retail\"}) only on retail", function()
    for _, Compat in ipairs({ (fresh()), (fresh{ skip = T.loadAddon.libFiles }) }) do
        assertTrue(Compat.ForClient(nil))
        assertTrue(Compat.ForClient("both"))
        assertTrue(Compat.ForClient({ "retail", "forever" }))
        assertEqual(Compat.ForClient({ "retail" }), PROFILE == "retail")
        assertEqual(Compat.ForClient({ "forever" }), PROFILE == "forever")
        local ok = pcall(Compat.ForClient, { "classic" })
        assertFalse(ok, "an unknown token raises on any client")
    end
end)

test("compat client: a client that is neither answers nil and serves undeclared features only", function()
    local Compat, m = fresh()
    m.WOW_PROJECT_ID, m.WOW_PROJECT_CAMELOT = 2, nil
    assertNil(Compat.ClientKey())
    assertFalse(Compat.IsForever()); assertFalse(Compat.IsRetail())
    assertTrue(Compat.ForClient(nil))
    assertFalse(Compat.ForClient({ "retail" }))
end)

-- ── names (client-quirks-§5) ────────────────────────────────────────────────────────────────

test("compat client: UnitCharacterName joins name and surname on Forever, keeps one name on Retail", function()
    local Compat, m = fresh()
    m.units.party1 = { guid = "Player-1-1", name = "Traxex", realm = "Silentshot", class = "Hunter",
        classFile = "HUNTER" }
    if Compat.ClientKey() == "forever" then
        assertEqual(Compat.UnitCharacterName("party1"), "Traxex Silentshot", "the whole name, never a realm")
    else
        assertEqual(Compat.UnitCharacterName("party1"), "Traxex", "UnitName's second value is a realm here")
    end
    m.units.party1.realm = nil
    assertEqual(Compat.UnitCharacterName("party1"), "Traxex", "no surname, no realm: the name alone")
    assertNil(Compat.UnitCharacterName("party4"), "no unit")
    m.issecretvalue = T.isSecret
    m.units.party1.name = T.secret("Traxex")
    assertNil(Compat.UnitCharacterName("party1"), "a secret name is never answered")
    -- library absent: UnitName's first value, never a realm or a hyphen
    local degraded, md = fresh{ skip = T.loadAddon.libFiles }
    md.units.party1 = { guid = "Player-1-1", name = "Traxex", realm = "Silentshot" }
    assertEqual(degraded.UnitCharacterName("party1"), "Traxex")
end)

test("compat client: CharacterKey is the AceDB character key of this client", function()
    local Compat, m = fresh()
    m.__context.name = "Traxex"
    if Compat.ClientKey() == "forever" then
        m.UnitNameUnmodified = function() return "Traxex", "Silentshot" end
        assertEqual(Compat.CharacterKey(), "Traxex Silentshot")
    else
        assertEqual(Compat.CharacterKey(), "Traxex - " .. m.GetRealmName())
    end
    local degraded = fresh{ skip = T.loadAddon.libFiles }
    assertNil(degraded.CharacterKey(), "library absent: no key")
end)

-- ── the spec, the talent tree and the role (LibKa0s-Role-1.0) ──────────────────────────────

local function groups(list)
    return function() return list end
end

test("compat client: PlayerTalentTree is the group with most points; a tie is nil", function()
    local Compat, m = fresh()
    local Role = m.LibStub("LibKa0s-Role-1.0", true)
    assertTrue(Role ~= nil, "Role is vendored")
    Role.Groups = groups({
        { index = 1, id = 11, name = "Arms", spent = 5 },
        { index = 2, id = 12, name = "Fury", spent = 31 },
        { index = 3, id = 13, name = "Protection", spent = 0 },
    })
    local tree = Compat.PlayerTalentTree()
    assertEqual(tree and tree.index, 2)
    assertEqual(tree and tree.name, "Fury")
    Role.Groups = groups({
        { index = 1, id = 11, name = "Arms", spent = 20 },
        { index = 2, id = 12, name = "Fury", spent = 20 },
    })
    assertNil(Compat.PlayerTalentTree(), "a tie names no tree")
    Role.Groups = groups({ { index = 1, id = 11, name = "Arms", spent = 0 } })
    assertNil(Compat.PlayerTalentTree(), "no points spent names no tree")
    Role.Groups = groups({})
    assertNil(Compat.PlayerTalentTree(), "Retail: Role has no groups")
    local degraded = fresh{ skip = T.loadAddon.libFiles }
    assertNil(degraded.PlayerTalentTree(), "library absent")
end)

test("compat client: PlayerTalentTree on the live Role is nil on Retail", function()
    local Compat = fresh()
    if Compat.ClientKey() == "retail" then assertNil(Compat.PlayerTalentTree()) end
end)

test("compat client: PlayerRole resolves through Role over db.char.role, and the override sticks", function()
    local NS, _, m = T.bootAddon()
    local Compat = NS.Compat
    NS.addon.db.char = {}   -- AceDB's per-character table (the kit's fake seeds none)
    local store = Compat.RoleStore()
    assertTrue(type(store) == "table", "the store is made on first use")
    assertTrue(NS.addon.db.char.role == store, "db.char.role")
    m.UnitGroupRolesAssigned = function() return "HEALER" end
    local role, source = Compat.PlayerRole()
    assertEqual(role, "HEALER"); assertEqual(source, "assigned")
    assertTrue(Compat.SetRoleOverride("TANK"))
    role, source = Compat.PlayerRole()
    assertEqual(role, "TANK"); assertEqual(source, "override")
    assertFalse(Compat.SetRoleOverride("PILOT"), "not one of the three")
    assertTrue(Compat.SetRoleOverride(nil))
    assertEqual((Compat.PlayerRole()), "HEALER", "cleared: automatic again")
    local degraded = T.newAddon{ skip = T.loadAddon.libFiles }
    assertNil(degraded.Compat.RoleStore(), "no database yet")
    assertNil((degraded.Compat.PlayerRole()))
end)

test("compat client: PlayerSpecID goes through Role.Spec", function()
    local Compat, m = fresh()
    local Role = m.LibStub("LibKa0s-Role-1.0", true)
    Role.Spec = function() return 1485, "Hunter" end
    assertEqual(Compat.PlayerSpecID(), 1485)
    Role.Spec = function() return nil, nil end
    assertNil(Compat.PlayerSpecID())
end)

test("compat client: InspectSpecID reads C_SpecializationInfo first, then the global", function()
    local Compat, m = fresh()
    m.inspect.specs.party1 = 262
    assertEqual(Compat.InspectSpecID("party1"), 262, "the global")
    m.C_SpecializationInfo = m.C_SpecializationInfo or {}
    m.C_SpecializationInfo.GetInspectSpecialization = function(unit) return unit == "party1" and 263 or 0 end
    assertEqual(Compat.InspectSpecID("party1"), 263, "the namespaced rung first")
    assertNil(Compat.InspectSpecID("party2"), "0 is not known")
    m.GetInspectSpecialization, m.C_SpecializationInfo.GetInspectSpecialization = nil, nil
    assertNil(Compat.InspectSpecID("party1"))
end)

-- ── feature events take clients (clients-§4) ────────────────────────────────────────────────

test("feature events: a retail-only row is not registered on forever", function()
    local NS, _, m = T.newAddon()
    NS.FEATURE_EVENTS[#NS.FEATURE_EVENTS + 1] = { "DW_TEST_RETAIL_ONLY", "OnDwTestRetail", clients = { "retail" } }
    NS.FEATURE_EVENTS[#NS.FEATURE_EVENTS + 1] = { "DW_TEST_FOREVER_ONLY", "OnDwTestForever", clients = { "forever" } }
    NS.FEATURE_EVENTS[#NS.FEATURE_EVENTS + 1] = { "DW_TEST_BOTH", "OnDwTestBoth" }
    local calls = {}
    NS.addon.OnDwTestRetail = function() calls[#calls + 1] = "retail" end
    NS.addon.OnDwTestForever = function() calls[#calls + 1] = "forever" end
    NS.addon.OnDwTestBoth = function() calls[#calls + 1] = "both" end
    NS.addon:OnInitialize()
    NS.addon:OnEnable()
    local registered = {}
    for _, r in ipairs(m.__registrations()) do
        if r.kind == "event" then registered[r.event] = true end
    end
    local onRetail = NS.Compat.ClientKey() == "retail"
    assertEqual(registered.DW_TEST_RETAIL_ONLY == true, onRetail, "the retail-only row")
    assertEqual(registered.DW_TEST_FOREVER_ONLY == true, not onRetail, "the forever-only row")
    assertTrue(registered.DW_TEST_BOTH, "an undeclared row serves both clients")
    local names = {}
    for _, name in ipairs(NS.FeatureEventNames()) do names[name] = true end
    assertEqual(names.DW_TEST_RETAIL_ONLY == true, onRetail, "FeatureEventNames lists what is registered")
    -- the simulator's replay delivers only what the client would
    assertEqual(NS.DeliverEvent("DW_TEST_RETAIL_ONLY"), onRetail and 1 or 0)
    assertEqual(NS.DeliverEvent("DW_TEST_FOREVER_ONLY"), onRetail and 0 or 1)
end)
