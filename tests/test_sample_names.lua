-- tests/test_sample_names.lua — one source of sample names (LibKa0s#104, decision D1 of
-- Ka0sAddonsCommonTasks docs/2026-11-24-FEEDBACK_BATCH, FB2-DW-01; WowAddonStandards v2.120.0): every
-- named sample person Drop Watcher draws, in test mode (modules/TestData.lua) and in the simulator
-- (modules/SimRoster.lua), comes from LibKa0s-Sim-1.0 (Sim.Sample's five and Sim.SampleCrowd's
-- seeded crowd), never from a list or a literal of the addon's own. This suite holds the source to
-- it: no `Sample*` or `Mock*` word (the convention's name shape) in any of the addon's own code. The
-- tests (which pin a seed's names), the vendored libs/ and the docs (prose, and the frozen bundles)
-- are outside it. The English word "Samples" is no name.

local T = _G.DW_TEST
local test, assertEqual, assertTrue = T.test, T.assertEqual, T.assertTrue

local ALLOWED = { Samples = true }

-- The addon's own code: every Lua, XML and TOC file git tracks outside tests/, libs/ and docs/.
local function ownCode()
    local out = {}
    for path in io.popen("git ls-files 2>/dev/null"):lines() do
        local top = path:match("^([^/]+)/")
        if top ~= "tests" and top ~= "libs" and top ~= "docs"
            and (path:match("%.lua$") or path:match("%.xml$") or path:match("%.toc$")) then
            out[#out + 1] = path
        end
    end
    return out
end

-- Each `Sample*` / `Mock*` name word in `text` past ALLOWED.
local function names(text)
    local out = {}
    for word in text:gmatch("%f[%w_]([SM][%w_]*)") do
        if (word:match("^Sample%l+$") or word:match("^Mock%l+$")) and not ALLOWED[word] then
            out[#out + 1] = word
        end
    end
    return out
end

test("sample names: the scan sees the addon's code, and a planted name is caught", function()
    local files = ownCode()
    assertTrue(#files > 50, "git lists the addon's code: " .. #files)
    assertEqual(table.concat(names('local x = { name = "Samplemist" } -- Mockwind'), ","), "Samplemist,Mockwind")
    assertEqual(#names("Samples skip the gates; SAMPLE_KEYS, NS.Sim:Sample(), SampleCrowd"), 0,
        "the English word and the library's members are no names")
end)

test("sample names: no Sample or Mock name lives in the addon's own code", function()
    -- red under: modules/TestData.lua's nineteen others and Samplealt, its SAMPLE_COPY of the five,
    -- and modules/SimRoster.lua's own pools (Brakk, Seta, ... before AD-87-DW and LibKa0s#104)
    local bad = {}
    for _, path in ipairs(ownCode()) do
        local fh = io.open(path, "rb")
        if fh then
            local n = 0
            for line in fh:lines() do
                n = n + 1
                for _, word in ipairs(names(line)) do bad[#bad + 1] = path .. ":" .. n .. " " .. word end
            end
            fh:close()
        end
    end
    assertEqual(table.concat(bad, "; "), "", "every sample name is the library's (Sim.Sample, Sim.SampleCrowd)")
end)

test("sample names: the simulator's group and raiders are the session's seeded crowd, the same per seed", function()
    -- red under: SimRoster's NAMES, RAID_NAMES, REALMS and SURNAMES
    local NS, _, m = T.newAddon()
    local R = NS.SimRoster
    local Sim = m.LibStub("LibKa0s-Sim-1.0")
    local client = T.forever and "forever" or "retail"
    local crowd = R.Crowd(client, 42)
    assertEqual(#crowd, Sim.CROWD_MAX)
    local want = Sim.SampleCrowd(client, Sim.CROWD_MAX, 42)
    for i, row in ipairs(want) do assertEqual(crowd[i].fullName, row.fullName, "row " .. i) end
    local opts = { kind = "raid", size = 12, ownRealm = "Testrealm", client = client, crowd = crowd }
    local members = R.Members(opts, R.Random(5))
    local raiders = R.Raiders(39 - #members, members, opts, R.Random(6))
    assertEqual(#members + #raiders, 39, "a 40-player raid besides you")
    for i, mem in ipairs(members) do
        local row = crowd[i]
        assertEqual(mem.classFile, row.classFile, "member " .. i .. ": the person's class")
        if T.forever then
            assertEqual(mem.name, row.fullName, "member " .. i)
        else
            assertEqual(mem.name, row.name, "member " .. i)
            assertTrue(mem.realm == "Testrealm" or mem.realm == row.realm, "your realm or the crowd's")
        end
    end
    for i, mem in ipairs(raiders) do
        local row = crowd[#members + i]
        assertEqual(mem.name, T.forever and row.fullName or row.name, "raider " .. i .. ": the next person")
    end
    local again = R.Members(opts, R.Random(5))
    for i, mem in ipairs(members) do assertEqual(again[i].name, mem.name, "a seed replays " .. i) end
end)

test("sample names: a running simulation's group is its seed's crowd, kept on the session", function()
    local NS = T.enableAddon()
    local Sim = T.simBare(NS)
    assertTrue(Sim:Start({ scenario = "test", seed = 9 }))
    local members = NS.SimRoster.Create({ kind = "party", seed = 9 })
    local s = Sim:Session()
    assertTrue(type(s.crowd) == "table" and #s.crowd > 0, "the session keeps its crowd")
    local client = NS.Compat.ClientKey() == "forever" and "forever" or "retail"
    local want = NS.SimRoster.Crowd(client, 9)
    for i, mem in ipairs(members) do
        assertEqual(mem.name:match("^(%S+)"), want[i].name, "member " .. i)
    end
    Sim:Stop()
    Sim:HidePanel()
end)
