-- tests/test_quality_gate.lua — modules/QualityGate.lua, the minimum-quality gate (design spec §6.2):
-- the three modes, the floor, an empty slot, ties, the upgrade override, the per-situation
-- override, the filter-bar label, and that no input ever makes it throw.

local T = _G.DW_TEST
local test, assertEqual, assertTrue, assertNil = T.test, T.assertEqual, T.assertTrue, T.assertNil

local cached
local function load()
    if not cached then
        local NS = T.newAddon()
        cached = { Q = NS.QualityGate, C = NS.Constants }
    end
    return cached.Q, cached.C
end

local _, C0 = load()
local S, QL = C0.SLOT, C0.QUALITY
local POOR, COMMON, UNCOMMON, RARE, EPIC = QL.POOR, QL.COMMON, QL.UNCOMMON, QL.RARE, QL.EPIC

-- Equipped qualities: every gear slot at `q`, shirt and tabard included; `over` replaces slots.
local function gearAt(q, over)
    local g = {}
    for _, slot in pairs(S) do g[slot] = q end
    for slot, v in pairs(over or {}) do g[slot] = v end
    return g
end

-- ---------------------------------------------------------------------------------------------
-- fixed
-- ---------------------------------------------------------------------------------------------

test("quality gate: fixed passes at or above the threshold and hides below it", function()
    local Q = load()
    local cases = {
        -- { dropQuality, fixed, pass, reason }
        { EPIC, RARE, true, "atThreshold" },
        { RARE, RARE, true, "atThreshold" },
        { UNCOMMON, RARE, false, "belowThreshold" },
        { POOR, COMMON, false, "belowThreshold" },
        { UNCOMMON, UNCOMMON, true, "atThreshold" },
    }
    for i, c in ipairs(cases) do
        local pass, threshold, reason = Q.Passes(c[1], "fixed", { fixed = c[2], upgradeOverride = false })
        assertEqual(pass, c[3], "case " .. i)
        assertEqual(threshold, c[2], "case " .. i)
        assertEqual(reason, c[4], "case " .. i)
    end
end)

test("quality gate: fixed defaults to Rare, and the floor does not apply to it", function()
    local Q = load()
    local pass, threshold = Q.Passes(UNCOMMON, "fixed", { upgradeOverride = false })
    assertEqual(pass, false)
    assertEqual(threshold, RARE)
    -- A fixed threshold below the floor stands: the floor is the dynamic modes' only.
    pass, threshold = Q.Passes(COMMON, "fixed", { fixed = COMMON, floor = RARE })
    assertEqual(pass, true)
    assertEqual(threshold, COMMON)
end)

test("quality gate: no mode or an unknown mode is the default fixed mode", function()
    local Q = load()
    local _, threshold = Q.Passes(EPIC, nil, {})
    assertEqual(threshold, RARE)
    _, threshold = Q.Passes(EPIC, "bogus", { fixed = EPIC })
    assertEqual(threshold, EPIC)
    assertEqual(Q.NormalizeMode("bogus"), "fixed")
    assertEqual(Q.NormalizeMode("dynamicSlot"), "dynamicSlot")
end)

-- ---------------------------------------------------------------------------------------------
-- dynamicSlot
-- ---------------------------------------------------------------------------------------------

test("quality gate: dynamicSlot uses the baseline slot's equipped quality", function()
    local Q = load()
    local gear = gearAt(EPIC, { [S.HEAD] = RARE })
    local pass, threshold, reason = Q.Passes(RARE, "dynamicSlot",
        { gear = gear, baselineSlot = S.HEAD, upgradeOverride = false })
    assertEqual(pass, true)
    assertEqual(threshold, RARE)
    assertEqual(reason, "atThreshold")
    pass, threshold, reason = Q.Passes(RARE, "dynamicSlot",
        { gear = gear, baselineSlot = S.CHEST, upgradeOverride = false })
    assertEqual(pass, false)
    assertEqual(threshold, EPIC)
    assertEqual(reason, "belowThreshold")
end)

test("quality gate: dynamicSlot is floored, Uncommon by default", function()
    local Q = load()
    local gear = gearAt(COMMON)
    local _, threshold = Q.Passes(RARE, "dynamicSlot", { gear = gear, baselineSlot = S.HEAD })
    assertEqual(threshold, UNCOMMON)
    _, threshold = Q.Passes(RARE, "dynamicSlot", { gear = gear, baselineSlot = S.HEAD, floor = RARE })
    assertEqual(threshold, RARE)
    -- Above the floor, the slot decides.
    _, threshold = Q.Passes(RARE, "dynamicSlot", { gear = gearAt(EPIC), baselineSlot = S.HEAD, floor = RARE })
    assertEqual(threshold, EPIC)
end)

test("quality gate: dynamicSlot with an empty or unread baseline slot uses the floor", function()
    local Q = load()
    local gear = gearAt(EPIC, { [S.HEAD] = false })
    local pass, threshold = Q.Passes(UNCOMMON, "dynamicSlot",
        { gear = gear, baselineSlot = S.HEAD, upgradeOverride = false })
    assertEqual(pass, true)
    assertEqual(threshold, UNCOMMON)
    gear[S.HEAD] = nil
    _, threshold = Q.Passes(UNCOMMON, "dynamicSlot", { gear = gear, baselineSlot = S.HEAD, floor = RARE })
    assertEqual(threshold, RARE)
    -- No gear table at all.
    _, threshold = Q.Passes(UNCOMMON, "dynamicSlot", { baselineSlot = S.HEAD })
    assertEqual(threshold, UNCOMMON)
end)

test("quality gate: dynamicSlot without a baseline slot takes the lower of the plan's slots", function()
    local Q = load()
    -- A ring with no verdict yet: the lower of the pair decides.
    local gear = gearAt(EPIC, { [S.FINGER2] = RARE })
    local _, threshold = Q.Passes(RARE, "dynamicSlot", { gear = gear, equipLoc = "INVTYPE_FINGER" })
    assertEqual(threshold, RARE)
    -- One of the pair empty: the empty slot is the one the drop fills, so the floor.
    gear[S.FINGER1] = false
    _, threshold = Q.Passes(RARE, "dynamicSlot", { gear = gear, equipLoc = "INVTYPE_FINGER" })
    assertEqual(threshold, UNCOMMON)
    -- A single slot plan.
    _, threshold = Q.Passes(RARE, "dynamicSlot", { gear = gearAt(EPIC), equipLoc = "INVTYPE_HEAD" })
    assertEqual(threshold, EPIC)
    -- Neither a baseline slot nor a known equip location: the floor.
    _, threshold = Q.Passes(RARE, "dynamicSlot", { gear = gearAt(EPIC), equipLoc = "INVTYPE_BAG" })
    assertEqual(threshold, UNCOMMON)
end)

test("quality gate: gear entries may be item facts carrying a quality", function()
    local Q = load()
    local gear = { [S.HEAD] = { ilvl = 600, quality = EPIC } }
    local _, threshold = Q.Passes(RARE, "dynamicSlot", { gear = gear, baselineSlot = S.HEAD })
    assertEqual(threshold, EPIC)
    assertEqual(Q.CharacterQuality(gear), EPIC)
end)

-- ---------------------------------------------------------------------------------------------
-- dynamicCharacter
-- ---------------------------------------------------------------------------------------------

test("quality gate: dynamicCharacter uses the most common equipped quality", function()
    local Q = load()
    local gear = gearAt(RARE, { [S.HEAD] = EPIC, [S.CHEST] = EPIC })
    local pass, threshold = Q.Passes(RARE, "dynamicCharacter", { gear = gear, upgradeOverride = false })
    assertEqual(pass, true)
    assertEqual(threshold, RARE)
    gear = gearAt(EPIC, { [S.HEAD] = RARE })
    pass, threshold = Q.Passes(RARE, "dynamicCharacter", { gear = gear, upgradeOverride = false })
    assertEqual(pass, false)
    assertEqual(threshold, EPIC)
end)

test("quality gate: dynamicCharacter ties go to the lower quality", function()
    local Q = load()
    local gear = {
        [S.HEAD] = EPIC, [S.NECK] = EPIC, [S.SHOULDER] = EPIC,
        [S.CHEST] = RARE, [S.WAIST] = RARE, [S.LEGS] = RARE,
    }
    assertEqual(Q.CharacterQuality(gear), RARE)
end)

test("quality gate: dynamicCharacter ignores shirt, tabard and empty slots", function()
    local Q = load()
    -- Two Rare and two Epic tie to Rare; counted, the Common shirt and tabard would make it a
    -- three-way tie that goes to Common.
    local gear = {
        [S.HEAD] = RARE, [S.NECK] = RARE, [S.SHOULDER] = EPIC, [S.CHEST] = EPIC,
        [S.SHIRT] = COMMON, [S.TABARD] = COMMON, [S.WAIST] = false, [S.LEGS] = false, [S.FEET] = false,
    }
    assertEqual(Q.CharacterQuality(gear), RARE)
    gear[S.HEAD] = false
    assertEqual(Q.CharacterQuality(gear), EPIC)
end)

test("quality gate: dynamicCharacter is floored, and with no gear uses the floor", function()
    local Q = load()
    local _, threshold = Q.Passes(RARE, "dynamicCharacter", { gear = gearAt(COMMON) })
    assertEqual(threshold, UNCOMMON)
    _, threshold = Q.Passes(RARE, "dynamicCharacter", { gear = gearAt(COMMON), floor = RARE })
    assertEqual(threshold, RARE)
    _, threshold = Q.Passes(RARE, "dynamicCharacter", { gear = {} })
    assertEqual(threshold, UNCOMMON)
    _, threshold = Q.Passes(RARE, "dynamicCharacter", {})
    assertEqual(threshold, UNCOMMON)
    assertNil(Q.CharacterQuality({}))
end)

-- ---------------------------------------------------------------------------------------------
-- Upgrade override
-- ---------------------------------------------------------------------------------------------

test("quality gate: the upgrade override shows a below-threshold upgrade for me, on by default", function()
    local Q = load()
    local pass, threshold, reason = Q.Passes(UNCOMMON, "fixed", { fixed = RARE, verdict = "upgrade" })
    assertEqual(pass, true)
    assertEqual(threshold, RARE)
    assertEqual(reason, "upgradeOverride")
    -- Turned off, the threshold holds.
    pass, _, reason = Q.Passes(UNCOMMON, "fixed", { fixed = RARE, verdict = "upgrade", upgradeOverride = false })
    assertEqual(pass, false)
    assertEqual(reason, "belowThreshold")
end)

test("quality gate: the override needs an upgrade verdict, nothing less", function()
    local Q = load()
    for _, verdict in ipairs({ "sidegrade", "downgrade", "cantUse", "doesntWant", "unknown" }) do
        local pass, _, reason = Q.Passes(UNCOMMON, "fixed", { fixed = RARE, verdict = verdict })
        assertEqual(pass, false, verdict)
        assertEqual(reason, "belowThreshold", verdict)
    end
    local pass = Q.Passes(UNCOMMON, "fixed", { fixed = RARE })
    assertEqual(pass, false, "no verdict yet")
end)

test("quality gate: a drop at the threshold passes on quality, not on the override", function()
    local Q = load()
    local _, _, reason = Q.Passes(EPIC, "fixed", { fixed = RARE, verdict = "upgrade" })
    assertEqual(reason, "atThreshold")
end)

test("quality gate: the override applies in the dynamic modes too", function()
    local Q = load()
    local ctx = { gear = gearAt(EPIC), baselineSlot = S.HEAD, verdict = "upgrade" }
    local pass, threshold, reason = Q.Passes(RARE, "dynamicSlot", ctx)
    assertEqual(pass, true)
    assertEqual(threshold, EPIC)
    assertEqual(reason, "upgradeOverride")
    pass, _, reason = Q.Passes(RARE, "dynamicCharacter", ctx)
    assertEqual(pass, true)
    assertEqual(reason, "upgradeOverride")
end)

-- ---------------------------------------------------------------------------------------------
-- Per-situation override
-- ---------------------------------------------------------------------------------------------

test("quality gate: a situation's quality setting overrides the global mode", function()
    local Q = load()
    assertEqual(Q.ResolveMode("fixed", "dynamicSlot"), "dynamicSlot")
    assertEqual(Q.ResolveMode("dynamicSlot", "dynamicCharacter"), "dynamicCharacter")
    assertEqual(Q.ResolveMode("dynamicCharacter", "fixed"), "fixed")
end)

test("quality gate: absent, global or unknown situation quality falls back to the global mode", function()
    local Q = load()
    assertEqual(Q.ResolveMode("dynamicSlot", nil), "dynamicSlot")
    assertEqual(Q.ResolveMode("dynamicSlot", "global"), "dynamicSlot")
    assertEqual(Q.ResolveMode("dynamicCharacter", "bogus"), "dynamicCharacter")
    assertEqual(Q.ResolveMode(nil, nil), "fixed")
    assertEqual(Q.ResolveMode("bogus", "global"), "fixed")
end)

test("quality gate: the resolved situation mode decides the drop", function()
    local Q = load()
    local ctx = { fixed = RARE, gear = gearAt(EPIC), baselineSlot = S.HEAD, upgradeOverride = false }
    -- Globally fixed at Rare a Rare drop passes; a dungeon set to match the slot hides it.
    assertEqual((Q.Passes(RARE, Q.ResolveMode("fixed", nil), ctx)), true)
    assertEqual((Q.Passes(RARE, Q.ResolveMode("fixed", "dynamicSlot"), ctx)), false)
end)

-- ---------------------------------------------------------------------------------------------
-- Threshold and label
-- ---------------------------------------------------------------------------------------------

test("quality gate: Threshold answers the threshold and where it came from", function()
    local Q = load()
    local t, src = Q.Threshold("fixed", { fixed = EPIC })
    assertEqual(t, EPIC)
    assertEqual(src, "fixed")
    t, src = Q.Threshold("dynamicSlot", { gear = gearAt(EPIC), baselineSlot = S.HEAD })
    assertEqual(t, EPIC)
    assertEqual(src, "slot")
    t, src = Q.Threshold("dynamicSlot", { gear = gearAt(false), baselineSlot = S.HEAD })
    assertEqual(t, UNCOMMON)
    assertEqual(src, "emptySlot")
    t, src = Q.Threshold("dynamicSlot", { gear = gearAt(COMMON), baselineSlot = S.HEAD })
    assertEqual(t, UNCOMMON)
    assertEqual(src, "floor")
    t, src = Q.Threshold("dynamicCharacter", { gear = gearAt(EPIC) })
    assertEqual(t, EPIC)
    assertEqual(src, "character")
    t, src = Q.Threshold("dynamicCharacter", { gear = {} })
    assertEqual(t, UNCOMMON)
    assertEqual(src, "noGear")
end)

test("quality gate: the filter bar label for each mode", function()
    local Q = load()
    assertEqual(Q.ThresholdLabel("fixed", RARE), "Quality: Rare+")
    assertEqual(Q.ThresholdLabel("fixed", EPIC), "Quality: Epic+")
    assertEqual(Q.ThresholdLabel("dynamicSlot", EPIC), "Quality: Match slot")
    assertEqual(Q.ThresholdLabel("dynamicSlot"), "Quality: Match slot")
    assertEqual(Q.ThresholdLabel("dynamicCharacter", EPIC), "Quality: Match gear (Epic+)")
    assertEqual(Q.ThresholdLabel("dynamicCharacter", nil), "Quality: Match gear")
    assertEqual(Q.ThresholdLabel(nil, UNCOMMON), "Quality: Uncommon+")
    assertEqual(Q.ThresholdLabel("fixed", 99), "Quality: 99+")
end)

test("quality gate: every quality id has a display name", function()
    local Q, C = load()
    for _, q in pairs(C.QUALITY) do
        local name = Q.QualityName(q)
        assertTrue(type(name) == "string" and name ~= "" and name ~= tostring(q), tostring(q))
    end
end)

-- ---------------------------------------------------------------------------------------------
-- Robustness
-- ---------------------------------------------------------------------------------------------

test("quality gate: an unknown drop quality passes, so the feed never hides what it cannot read", function()
    local Q = load()
    local pass, threshold, reason = Q.Passes(nil, "fixed", { fixed = RARE })
    assertEqual(pass, true)
    assertEqual(threshold, RARE)
    assertEqual(reason, "qualityUnknown")
    pass, _, reason = Q.Passes(0 / 0, "fixed", {})
    assertEqual(pass, true)
    assertEqual(reason, "qualityUnknown")
end)

test("quality gate: nil and garbage inputs never throw", function()
    local Q = load()
    local junk = { nil, false, "x", 3, {}, function() end, 0 / 0 }
    for i = 1, 7 do
        for j = 1, 7 do
            local ok, pass = pcall(Q.Passes, junk[i], junk[j], junk[i])
            assertTrue(ok, "Passes " .. i .. "/" .. j)
            assertTrue(type(pass) == "boolean")
            ok = pcall(Q.ThresholdLabel, junk[i], junk[j])
            assertTrue(ok, "ThresholdLabel " .. i .. "/" .. j)
            ok = pcall(Q.ResolveMode, junk[i], junk[j])
            assertTrue(ok, "ResolveMode " .. i .. "/" .. j)
        end
        assertTrue((pcall(Q.CharacterQuality, junk[i])), "CharacterQuality " .. i)
    end
    -- Garbage inside ctx: bad fixed and floor fall back to the defaults.
    local _, threshold = Q.Passes(RARE, "fixed", { fixed = "Epic" })
    assertEqual(threshold, RARE)
    _, threshold = Q.Passes(RARE, "dynamicSlot", { floor = {}, gear = "x", baselineSlot = "head" })
    assertEqual(threshold, UNCOMMON)
    _, threshold = Q.Passes(RARE, "dynamicCharacter", { gear = { [S.HEAD] = "Epic", [S.NECK] = {} } })
    assertEqual(threshold, UNCOMMON)
end)
