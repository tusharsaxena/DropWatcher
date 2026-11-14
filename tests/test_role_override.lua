-- tests/test_role_override.lua — General › Role, WoW Forever's role override (Forever port design
-- §11.4): the `char.role` row, saved per character in `db.char.role` through Role.SetOverride, on
-- Forever alone (clients-§4); Automatic is Role.Resolve's ladder, and the row's tooltip names what
-- Automatic answers now and where from. The role decides the Druid's Feral scale (Pawn 2 or 3), so a
-- Feral tank whose group role reads NONE can pick Tank. Each case runs on both profiles
-- (`KA0S_KIT_CLIENT=forever lua tests/run.lua`) and picks its expectation by ClientKey() (clients-§6).

local T = _G.DW_TEST
local test, assertEqual, assertTrue, assertNil = T.test, T.assertEqual, T.assertTrue, T.assertNil

local FOREVER = (os.getenv("KA0S_KIT_CLIENT") or "retail") == "forever"

local function boot()
    local NS, _, m = T.enableAddon()
    NS.addon.db.char = NS.addon.db.char or {}   -- AceDB's per-character table (the kit's fake seeds none)
    m.UnitGroupRolesAssigned = function() return "NONE" end
    return NS, m
end

test("role override: the Role row is General's on WoW Forever alone", function()
    local NS = boot()
    local row = NS.SchemaRuntime.FindRow("char.role")
    if not FOREVER then
        -- Retail never reads the role (design §11.4): the row is not in the schema at all.
        assertNil(row, "no Role row on Retail")
        return
    end
    -- red under: no Role row (whole-run review: SetRoleOverride had no caller)
    assertTrue(row ~= nil, "the Role row exists on Forever")
    assertEqual(row.page, "general"); assertEqual(row.group, "Role"); assertEqual(row.label, "Role")
    local values = {}
    for i, e in ipairs(row.values) do values[i] = e.value .. "=" .. e.text end
    assertEqual(table.concat(values, ","), "auto=Automatic,tank=Tank,healer=Healer,damage=Damage")
    assertEqual(NS.addon.Settings.Helpers.ValidateSchema(), 0)
    -- Not a profile path: nothing at `char` in the profile defaults.
    assertNil(NS.addon.Settings.BuildDefaults().profile.char, "no profile default for a per-character row")
end)

test("role override: a pick lands in db.char.role through SetOverride, and Automatic clears it", function()
    if not FOREVER then return end
    local NS, m = boot()
    local Compat = NS.Compat
    assertEqual(NS.SchemaRuntime.Get("char.role"), "auto", "Automatic while no override is set")
    -- The Feral tank of the finding: no group role, so the ladder falls to the talents.
    assertTrue(NS.SchemaRuntime.Set("char.role", "tank"))
    assertEqual(NS.addon.db.char.role.override, "TANK", "saved per character")
    local role, source = Compat.PlayerRole()
    assertEqual(role, "TANK"); assertEqual(source, "override")
    assertEqual(NS.SchemaRuntime.Get("char.role"), "tank")
    assertTrue(NS.SchemaRuntime.Set("char.role", "damage"))
    assertEqual(NS.addon.db.char.role.override, "DAMAGER")
    assertTrue(not NS.SchemaRuntime.Set("char.role", "pilot"), "not one of the four")
    assertEqual(NS.addon.db.char.role.override, "DAMAGER", "a refused value stores nothing")
    assertTrue(NS.SchemaRuntime.Set("char.role", "auto"))
    assertNil(NS.addon.db.char.role.override, "Automatic is no override")
    m.UnitGroupRolesAssigned = function() return "HEALER" end
    assertEqual((Compat.PlayerRole()), "HEALER", "Automatic follows the ladder again")
end)

test("role override: the CLI reaches the row, and Reset all leaves a per-character pick", function()
    if not FOREVER then return end
    local NS = boot()
    NS.addon:OnSlashCommand("set char.role healer")
    assertEqual(NS.addon.db.char.role.override, "HEALER", "/dw set char.role healer")
    NS.addon.Settings.Helpers.RestoreAllDefaults()
    assertEqual(NS.addon.db.char.role.override, "HEALER", "a profile reset cannot reach db.char")
    NS.addon:OnSlashCommand("reset char.role")
    assertNil(NS.addon.db.char.role.override, "/dw reset char.role is Automatic")
end)

test("role override: the tooltip names what Automatic answers now, and its source", function()
    if not FOREVER then return end
    local NS, m = boot()
    m.UnitGroupRolesAssigned = function() return "HEALER" end
    NS.SchemaRuntime.Set("char.role", "tank")
    NS.addon.Settings.RefreshRoleTooltip()
    local tip = NS.SchemaRuntime.FindRow("char.role").tooltip
    -- The override does not hide what Automatic would pick.
    assertTrue(tip:find("Automatic now picks Healer: the role your group gave you.", 1, true) ~= nil, tip)
    assertEqual(NS.addon.db.char.role.override, "TANK", "reading Automatic leaves the override set")
    m.UnitGroupRolesAssigned = function() return "NONE" end
    NS.addon.Settings.RefreshRoleTooltip()
    tip = NS.SchemaRuntime.FindRow("char.role").tooltip
    -- The kit's character has no talent role to give, so the ladder has nothing left to answer.
    assertTrue(tip:find("Automatic has no answer yet.", 1, true) ~= nil, tip)
    assertTrue(tip:find("picks Healer", 1, true) == nil, "no group role now: " .. tip)
end)
