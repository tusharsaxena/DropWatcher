-- tests/test_verdict_golden.lua — the golden verdict suite (Item Search split plan, task A1): TODAY'S
-- "my verdict on this item" engine, pinned on both kit profiles through its current public seams
-- alone, over the plain-data table in tests/fixtures/verdict_golden.lua (its header holds the
-- shape). The library's own golden suite ports the same table unchanged (plan tasks B1, B2), so a
-- move that changes one verdict fails on one side or the other.
--
-- The kernel half (`cases`) runs NS.Evaluate.Evaluate, or NS.Collectibles.Verdict, on an instance
-- with the case's class list installed (pure code over it, on either profile), the scorer built
-- from the case's data (a table of scores, or NS.Scoring.WeightsScorer). The read half (`me`) seeds
-- the mock's client, reads the link through NS.ItemFacts.Get and judges it through
-- NS.LootFeed.JudgeMe, your gear from NS.Gear.Snapshot, the scorer from NS.Scoring.Scorer; each
-- such case runs on its own client's profile and is a declared skip on the other.

local T = _G.DW_TEST
local test, assertEqual, assertTrue = T.test, T.assertEqual, T.assertTrue

local GOLDEN = dofile("tests/fixtures/verdict_golden.lua")
local PROFILE = T.forever and "forever" or "retail"

local function skipFor(client)
    if client == PROFILE then return nil end
    return ("pinned on the %s profile, where its client-gated module initializes (clients-§6)"):format(client)
end

-- ── the comparison ──────────────────────────────────────────────────────────────────────────

local function reasonKeys(res)
    local out = {}
    for i, r in ipairs(res.reasons or {}) do out[i] = r.key end
    return out
end

local function expectFields(got, want, label)
    for k, v in pairs(want or {}) do assertEqual(got[k], v, label .. "." .. k) end
end

local function check(res, expect, label)
    if expect.none then
        assertEqual(res, nil, label .. ": no verdict")
        return
    end
    assertTrue(type(res) == "table", label .. ": a verdict")
    assertEqual(res.verdict, expect.verdict, label .. ": verdict")
    assertEqual(table.concat(reasonKeys(res), ","), table.concat(expect.reasonKeys or {}, ","), label .. ": reasons")
    expectFields(res, expect.fields, label)
    for key, detail in pairs(expect.details or {}) do
        local found
        for _, r in ipairs(res.reasons) do if r.key == key then found = r.detail end end
        assertEqual(found, detail, label .. ": " .. key .. " detail")
    end
    if expect.offSpec then
        assertTrue(type(res.offSpec) == "table", label .. ": an off-spec part")
        expectFields(res.offSpec, expect.offSpec, label .. ".offSpec")
    end
end

-- ── the kernel half ─────────────────────────────────────────────────────────────────────────

-- One instance per class list, the list installed (as test_evaluate does).
local kernels = {}
local function kernel(client)
    if not kernels[client] then
        local NS = T.newAddon()
        NS.ClassData.Install(NS.ClassData.LISTS[client])
        kernels[client] = NS
    end
    return kernels[client]
end

local function scorerOf(NS, spec)
    if spec == nil then return nil end
    if spec.kind == "table" then
        return function(f) return type(f) == "table" and spec.scores[f.itemID] or nil end
    end
    if spec.kind == "weights" then return NS.Scoring.WeightsScorer(spec.weights) end
    error("unknown scorer kind " .. tostring(spec.kind))
end

local function optsOf(NS, data)
    local out = {}
    for k, v in pairs(data or {}) do out[k] = v end
    out.scorer = scorerOf(NS, data and data.scorer)
    return out
end

local function candidateOf(data)
    if type(data) ~= "table" then return data end
    local out = {}
    for k, v in pairs(data) do out[k] = v end
    if type(data.offSpecGear) == "table" then
        local map = data.offSpecGear
        out.offSpecGear = function(specID) return map[specID] end
    end
    return out
end

for _, case in ipairs(GOLDEN.cases) do
    test("golden kernel: " .. case.name, function()
        local NS = kernel(case.client)
        local res
        if case.via == "collect" then
            res = NS.Collectibles.Verdict(case.facts, case.forced == true)
        else
            res = NS.Evaluate.Evaluate(case.facts, candidateOf(case.candidate), optsOf(NS, case.opts))
        end
        check(res, case.expect, case.name)
    end, case.profile and skipFor(case.profile) or nil)
end

-- ── the read half ───────────────────────────────────────────────────────────────────────────

-- A Pawn fake (test_scoring's shape): ready, an item's data for any link, the drop's upgrade list
-- `upgrades[link]` (nil: not read yet) and an item's value `values[scale][link]`.
local function installPawn(m, pawn)
    m.loadedAddons.Pawn = true
    m.PawnIsReady = function() return true end
    m.PawnGetItemData = function(l) return { link = l } end
    m.PawnIsItemAnUpgrade = function(data) return pawn.upgrades[data.link] end
    m.PawnFindScaleForSpec = function(classID, index) return "S" .. classID .. ":" .. index end
    m.PawnGetSingleValueFromItem = function(data, scale) return pawn.values[scale] and pawn.values[scale][data.link] end
end

-- The seed is split in three (who you are, what you carry, what the client knows) so no one
-- function carries every optional field's guard (the library's copy split the same way).
local function seedPlayer(m, s)
    m.__context.class, m.__context.classToken, m.__context.level = s.class, s.classFile, s.level
    if s.talents then m.seedTalents(s.specID, s.talents) else m.specID = s.specID end
end

local function seedItems(m, s)
    for l, d in pairs(s.items or {}) do
        local copy = {}
        for k, v in pairs(d) do copy[k] = v end
        m.addItem(l, copy)
    end
    for slot, l in pairs(s.worn or {}) do m.inventory.player[slot] = l end
    for bag, slots in pairs(s.bags or {}) do
        m.bags[bag] = { size = 16 }
        for slot, l in pairs(slots) do m.bags[bag][slot] = l end
    end
end

local function seedClient(m, s)
    for l, data in pairs(s.tooltips or {}) do m.tooltips.hyperlink[l] = data end
    if s.mounts then
        for id, mount in pairs(s.mounts.byItem or {}) do m.mounts.byItem[id] = mount end
        for mount, known in pairs(s.mounts.collected or {}) do m.mounts.collected[mount] = known end
    end
    if s.pawn then installPawn(m, s.pawn) end
end

local function seed(m, s)
    seedPlayer(m, s)
    seedItems(m, s)
    seedClient(m, s)
end

for _, case in ipairs(GOLDEN.me) do
    test("golden me: " .. case.name, function()
        local NS = T.enableAddon({ mock = function(m) seed(m, case.setup) end })
        for path, value in pairs(case.setup.settings or {}) do
            assertTrue(NS.SchemaRuntime.Set(path, value), case.name .. ": set " .. path)
        end
        NS.Gear.Refresh("test")
        local snap = NS.Gear.Snapshot()
        assertEqual(snap.classFile, case.setup.classFile, case.name .. ": the snapshot's class")
        local facts = NS.ItemFacts.Get(case.link)
        assertTrue(facts ~= nil, case.name .. ": the drop's facts read")
        check(NS.LootFeed.JudgeMe(facts, case.setup.forced), case.expect, case.name)
    end, skipFor(case.client))
end
