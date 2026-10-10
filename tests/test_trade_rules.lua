-- tests/test_trade_rules.lua — modules/TradeRules.lua, the trade estimator (design spec §7.1-§7.3):
-- every row of the Estimate table in its order, the trade window's expiry, the per-situation rule
-- with the owner's override map, and that no input ever makes it throw.

local T = _G.DW_TEST
local test, assertEqual, assertTrue, assertFalse, assertNil =
    T.test, T.assertEqual, T.assertTrue, T.assertFalse, T.assertNil

local cached
local function load()
    if not cached then
        local NS = T.newAddon()
        cached = { TR = NS.TradeRules, C = NS.Constants }
    end
    return cached.TR, cached.C
end

local _, C0 = load()
local B = C0.BIND
local NOW = 100000

-- A soulbound (BoP) drop at ilvl 610, with `over` merged in.
local function drop(over)
    local f = { itemID = 1, ilvl = 610, bindType = B.ON_ACQUIRE }
    for k, v in pairs(over or {}) do f[k] = v end
    return f
end

-- The looter's evaluation (modules/Evaluate.lua's output) for a drop `delta` item levels over
-- their baseline; the verdict follows the sign unless given.
local function looter(delta, verdict)
    if not verdict then
        verdict = (delta > 0 and "upgrade") or (delta < 0 and "downgrade") or "sidegrade"
    end
    return { verdict = verdict, equip = "ok", ilvlDelta = delta, baselineSlot = 11, reasons = {} }
end

-- A context in `situation`, dropped `age` seconds ago, with `over` merged in.
local function ctx(situation, age, over)
    local c = { situation = situation, now = NOW, droppedAt = NOW - (age or 60), inspectAge = 30 }
    for k, v in pairs(over or {}) do c[k] = v end
    return c
end

local function check(est, state, reasonKey, basis, label)
    assertEqual(est.state, state, label)
    assertEqual(est.reasonKey, reasonKey, label)
    if basis then assertEqual(est.basis, basis, label) end
end

-- ---------------------------------------------------------------------------------------------
-- the Estimate table, row by row (spec §7.2)
-- ---------------------------------------------------------------------------------------------

test("trade rules: a warbound or account-bound drop is no warbound", function()
    local TR = load()
    check(TR.Estimate(drop({ warbound = true }), looter(-5), ctx("dungeon")), "no", "warbound", "bind")
    for _, bind in ipairs({ B.TO_WOW_ACCOUNT, B.TO_BNET_ACCOUNT, B.TO_BNET_ACCOUNT_EQUIPPED }) do
        check(TR.Estimate(drop({ bindType = bind }), looter(-5), ctx("dungeon")), "no", "warbound", "bind",
            "bind " .. bind)
    end
end)

test("trade rules: a bonus roll is no bonusRoll, and warbound wins over it", function()
    local TR = load()
    check(TR.Estimate(drop({ bonusRoll = true }), looter(-5), ctx("raid")), "no", "bonusRoll", "bind")
    check(TR.Estimate(drop({ bonusRoll = true, warbound = true }), nil, ctx("raid")), "no", "warbound")
end)

test("trade rules: a BoE or BoU drop is yes boe, in any situation and past the window", function()
    local TR = load()
    for _, bind in ipairs({ B.ON_EQUIP, B.ON_USE }) do
        check(TR.Estimate(drop({ bindType = bind }), nil, ctx("dungeon")), "yes", "boe", "bind")
        check(TR.Estimate(drop({ bindType = bind }), looter(20), ctx("pvp")), "yes", "boe", "bind")
        check(TR.Estimate(drop({ bindType = bind }), nil, ctx("raid", 99999)), "yes", "boe", "bind")
    end
    -- A bonus-roll BoE is still a bonus roll: the order puts the bonus roll first.
    check(TR.Estimate(drop({ bindType = B.ON_EQUIP, bonusRoll = true }), nil, ctx("raid")), "no", "bonusRoll")
end)

test("trade rules: the legacy rule is no legacy (follower dungeons and PvP)", function()
    local TR = load()
    check(TR.Estimate(drop(), looter(-5), ctx("followerDungeon")), "no", "legacy", "rule")
    check(TR.Estimate(drop(), nil, ctx("pvp")), "no", "legacy", "rule")
    assertEqual(TR.Estimate(drop(), nil, ctx("pvp")).rule, "legacy")
end)

test("trade rules: the group rule (ilvlRule none) is likely groupLoot without inspect", function()
    local TR = load()
    local est = TR.Estimate(drop(), nil, ctx("raid", 60, { rules = { raid = "group" } }))
    check(est, "likely", "groupLoot", "rule")
    assertEqual(est.rule, "group")
    -- An upgrade for the looter does not matter under the group rule.
    check(TR.Estimate(drop(), looter(15), ctx("raid", 60, { rules = { raid = "group" } })), "likely", "groupLoot")
end)

test("trade rules: personal, the looter's evaluation known and not an upgrade, is likely notUpgrade", function()
    local TR = load()
    for _, delta in ipairs({ -9, -1, 0 }) do
        local est = TR.Estimate(drop(), looter(delta), ctx("dungeon"))
        check(est, "likely", "notUpgrade", "inspect", "delta " .. delta)
        assertEqual(est.args[1], 610, "delta " .. delta)
        assertEqual(est.args[2], 610 - delta, "delta " .. delta)
        assertEqual(est.age, 30)
        assertEqual(est.rule, "personal")
    end
end)

test("trade rules: personal, an upgrade for the looter, is no upgradeForLooter", function()
    local TR = load()
    local est = TR.Estimate(drop(), looter(13), ctx("mythicPlus"))
    check(est, "no", "upgradeForLooter", "inspect")
    assertEqual(est.args[1], 610)
    assertEqual(est.args[2], 597)
end)

test("trade rules: the item level decides, not the scored verdict (the game's rule is ilvl)", function()
    local TR = load()
    -- Scoring may call a higher-ilvl drop a sidegrade; the trade rule still sees an upgrade.
    check(TR.Estimate(drop(), looter(6, "sidegrade"), ctx("dungeon")), "no", "upgradeForLooter")
    -- ... and a drop the looter cannot use is judged on item level as well.
    check(TR.Estimate(drop(), looter(-4, "cantUse"), ctx("dungeon")), "likely", "notUpgrade")
end)

test("trade rules: an empty slot on the looter is an upgrade for them", function()
    local TR = load()
    local eval = { verdict = "upgrade", equip = "ok", baselineSlot = 1, reasons = { { key = "emptySlot" } } }
    local est = TR.Estimate(drop(), eval, ctx("dungeon"))
    check(est, "no", "upgradeForLooter", "inspect")
    assertEqual(est.args[1], 610)
    assertNil(est.args[2])
end)

test("trade rules: the looter unknown is unknown noInspect, carrying the inspect reason", function()
    local TR = load()
    local est = TR.Estimate(drop(), nil, ctx("dungeon", 60, { inspectReason = "outOfRange", inspectAge = nil }))
    check(est, "unknown", "noInspect", "inspect")
    assertEqual(est.args[1], "outOfRange")
    assertNil(est.age)
    -- No reason given: "pending".
    assertEqual(TR.Estimate(drop(), nil, ctx("dungeon")).args[1], "pending")
    -- An evaluation that is itself unknown, or has no item level to compare, is no inspect either.
    local unknown = { verdict = "unknown", equip = "unknown", reasons = { { key = "noBaseline" } } }
    check(TR.Estimate(drop(), unknown, ctx("dungeon")), "unknown", "noInspect")
    check(TR.Estimate(drop(), { verdict = "downgrade", reasons = {} }, ctx("dungeon")), "unknown", "noInspect")
end)

test("trade rules: an estimate has no expiresAt; only the own-item timer sets one", function()
    local TR = load()
    assertNil(TR.Estimate(drop(), looter(-1), ctx("dungeon")).expiresAt)
    assertNil(TR.Estimate(drop(), nil, ctx("dungeon")).expiresAt)
end)

-- ---------------------------------------------------------------------------------------------
-- expiry
-- ---------------------------------------------------------------------------------------------

test("trade rules: past the rule's window the drop is no expired", function()
    local TR = load()
    local est = TR.Estimate(drop(), looter(-5), ctx("dungeon", 7201))
    check(est, "no", "expired", "rule")
    assertEqual(est.args[1], 7201)
    assertEqual(est.args[2], 7200)
    -- Expiry beats every rule-judged answer: unknown, groupLoot and upgradeForLooter alike.
    check(TR.Estimate(drop(), nil, ctx("dungeon", 8000)), "no", "expired")
    check(TR.Estimate(drop(), looter(9), ctx("dungeon", 8000)), "no", "expired")
    check(TR.Estimate(drop(), nil, ctx("raid", 8000, { rules = { raid = "group" } })), "no", "expired")
end)

test("trade rules: at exactly the window the drop has not expired", function()
    local TR = load()
    check(TR.Estimate(drop(), looter(-5), ctx("dungeon", 7200)), "likely", "notUpgrade")
end)

test("trade rules: with no clock or no drop time there is no expiry check", function()
    local TR = load()
    local noClock = ctx("dungeon", 9000)
    noClock.now = nil
    check(TR.Estimate(drop(), looter(-5), noClock), "likely", "notUpgrade")
    check(TR.Estimate(drop(), looter(-5), ctx("dungeon", 9000, { droppedAt = "x" })), "likely", "notUpgrade")
end)

test("trade rules: binds and legacy are decided before the window", function()
    local TR = load()
    check(TR.Estimate(drop({ warbound = true }), nil, ctx("dungeon", 9000)), "no", "warbound")
    check(TR.Estimate(drop({ bonusRoll = true }), nil, ctx("raid", 9000)), "no", "bonusRoll")
    check(TR.Estimate(drop(), nil, ctx("pvp", 9000)), "no", "legacy")
end)

-- ---------------------------------------------------------------------------------------------
-- the rule per situation and the owner override (spec §7.3)
-- ---------------------------------------------------------------------------------------------

test("trade rules: each situation's default rule is CONTENT_RULE, raid conservatively personal", function()
    local TR, C = load()
    for _, s in ipairs(C.SITUATIONS) do
        local rule, overridden = TR.RuleFor(s.key, nil)
        assertEqual(rule, C.CONTENT_RULE[s.key], s.key)
        assertFalse(overridden, s.key)
    end
    assertEqual(TR.RuleFor("raid"), "personal")
end)

test("trade rules: the override map replaces a situation's rule", function()
    local TR = load()
    local rules = { raid = "group", pvp = "personal" }
    local rule, overridden = TR.RuleFor("raid", rules)
    assertEqual(rule, "group")
    assertTrue(overridden)
    assertEqual(TR.RuleFor("pvp", rules), "personal")
    assertEqual(TR.RuleFor("dungeon", rules), "personal")
    -- The estimate follows it: PvP overridden to personal is judged on the looter.
    check(TR.Estimate(drop(), looter(-2), ctx("pvp", 60, { rules = rules })), "likely", "notUpgrade")
    check(TR.Estimate(drop(), nil, ctx("followerDungeon", 60, { rules = { followerDungeon = "group" } })),
        "likely", "groupLoot")
end)

test("trade rules: an override naming no rule, or equal to the default, is not an override", function()
    local TR = load()
    local rule, overridden = TR.RuleFor("raid", { raid = "bogus" })
    assertEqual(rule, "personal")
    assertFalse(overridden)
    rule, overridden = TR.RuleFor("raid", { raid = "personal" })
    assertEqual(rule, "personal")
    assertFalse(overridden)
    assertEqual(TR.RuleFor("raid", "garbage"), "personal")
end)

test("trade rules: an unknown or missing situation takes the default personal rule", function()
    local TR = load()
    assertEqual(TR.RuleFor(nil), "personal")
    assertEqual(TR.RuleFor("nowhere", { nowhere = "group" }), "group")
    assertEqual(TR.RuleFor("nowhere"), "personal")
    check(TR.Estimate(drop(), looter(-1), ctx(nil)), "likely", "notUpgrade")
end)

test("trade rules: Rules lists every situation in order with its rule, default and override flag", function()
    local TR, C = load()
    local list = TR.Rules({ raid = "group", dungeon = "bogus" })
    assertEqual(#list, #C.SITUATIONS)
    for i, s in ipairs(C.SITUATIONS) do
        assertEqual(list[i].situation, s.key)
        assertEqual(list[i].default, C.CONTENT_RULE[s.key])
    end
    local byKey = {}
    for _, row in ipairs(list) do byKey[row.situation] = row end
    assertEqual(byKey.raid.rule, "group")
    assertTrue(byKey.raid.overridden)
    assertEqual(byKey.dungeon.rule, "personal")
    assertFalse(byKey.dungeon.overridden)
end)

test("trade rules: Reset clears the override map in place, restoring the defaults", function()
    local TR = load()
    local rules = { raid = "group", pvp = "personal" }
    assertTrue(TR.Reset(rules) == rules)
    assertNil(next(rules))
    assertEqual(TR.RuleFor("raid", rules), "personal")
    assertEqual(TR.RuleFor("pvp", rules), "legacy")
    assertNil(TR.Reset(nil))
end)

test("trade rules: IsRule knows the three rule names and nothing else", function()
    local TR, C = load()
    for _, name in ipairs(C.TRADE_RULE_NAMES) do assertTrue(TR.IsRule(name), name) end
    assertFalse(TR.IsRule("bogus"))
    assertFalse(TR.IsRule(nil))
    assertFalse(TR.IsRule(1))
end)

-- ---------------------------------------------------------------------------------------------
-- robustness
-- ---------------------------------------------------------------------------------------------

test("trade rules: nil and garbage inputs never throw", function()
    local TR = load()
    local junk = { nil, false, 0, "x", {}, { ilvl = "x" }, { bindType = {} }, function() end }
    for i = 1, 8 do
        for j = 1, 8 do
            local est = TR.Estimate(junk[i], junk[j], junk[(i + j) % 8 + 1])
            assertTrue(type(est) == "table", i .. "," .. j)
            assertTrue(est.state == "yes" or est.state == "likely" or est.state == "unknown" or est.state == "no",
                i .. "," .. j)
            assertTrue(type(est.reasonKey) == "string", i .. "," .. j)
            assertTrue(type(est.args) == "table", i .. "," .. j)
        end
    end
end)

test("trade rules: bad facts are unknown badFacts", function()
    local TR = load()
    check(TR.Estimate(nil, looter(-1), ctx("dungeon")), "unknown", "badFacts")
    check(TR.Estimate("link", looter(-1), ctx("dungeon")), "unknown", "badFacts")
end)
