-- tests/test_tooltip_placement.lua — every tooltip the addon places itself goes through
-- LibKa0s-Tooltip-1.0's placers, by where the hovered element sits (AD-92-DW, LibKa0s#92;
-- WowAddonStandards standalone-windows, *Tooltip placement*; anti-pattern #119). A sweep over every
-- widget Window.AttachTooltip hooks while the window and its tabs are built (the Offer panel's own
-- are tests/test_offer_panel.lua's): each is
-- classified BODY or CHROME by the file that built it, and a hover of each calls the placer its
-- class names on the element its class names (the row it sits in, in its window group; or the
-- control itself), owned at ANCHOR_NONE. Then a source guard: the addon's own Lua names no cursor
-- anchor and no corner anchor, and owns every tooltip at ANCHOR_NONE. The geometry of each placer
-- is tests/test_row_tooltip.lua's.

local T = _G.DW_TEST
local test, assertEqual, assertTrue = T.test, T.assertEqual, T.assertTrue

-- The files whose every AttachTooltip widget is chrome, and those whose every one is a body element.
-- The rest build both, and their chrome widgets are named below (MIXED_CHROME).
local CHROME_FILES = { "WindowTabs", "WindowFilterBar", "WindowFooter", "FooterRow", "WindowTitleBar",
    "CompactChrome" }
local BODY_FILES = { "WindowGroup", "WindowHistory", "WindowPending", "CompactGroup", "HistoryCard", "Toast",
    "RollPopup" }

local function fileOf(src)
    return (tostring(src):match("modules/([%w_]+)%.lua")) or tostring(src)
end

local function setOf(list)
    local s = {}
    for _, v in ipairs(list) do s[v] = true end
    return s
end

-- Record every widget AttachTooltip hooks from here on: { w, place, file }.
local function recorder(NS)
    local seen, list = {}, {}
    local real = NS.Window.AttachTooltip
    NS.Window.AttachTooltip = function(w, fn, place)
        if not seen[w] then
            seen[w] = true
            list[#list + 1] = { w = w, place = place, file = fileOf(debug.getinfo(2, "S").source) }
        else
            for _, r in ipairs(list) do if r.w == w then r.place = place end end
        end
        return real(w, fn, place)
    end
    return list
end

local function outermost(f, UIParent)
    for _ = 1, 32 do
        local p = f.GetParent and f:GetParent()
        if type(p) ~= "table" or p == f or p == UIParent then return f end
        f = p
    end
    return f
end

local function built()
    local NS, _, m = T.enableAddon()
    m.seedGearJournal()
    local list = recorder(NS)
    NS.SetTestMode(true)
    NS.WindowFilterBar.Set("group", "view", "all")
    NS.ShowWindow()
    NS.Window.SelectTab("history")
    NS.Window.SelectTab("group")
    return NS, m, list
end

test("tooltip placement: every hooked widget is classified by the file that built it", function()
    local _, _, list = built()
    local chrome, body = setOf(CHROME_FILES), setOf(BODY_FILES)
    local files = {}
    for _, r in ipairs(list) do
        files[r.file] = true
        if chrome[r.file] then
            assertEqual(r.place, "chrome", r.file .. ": a chrome element")
        elseif body[r.file] then
            assertTrue(r.place == nil, r.file .. ": a body element (no place), got " .. tostring(r.place))
        else
            assertTrue(r.place == nil or r.place == "chrome", r.file .. ": no retired place " .. tostring(r.place))
        end
    end
    for _, need in ipairs({ "WindowTabs", "WindowFilterBar", "WindowFooter", "WindowTitleBar", "WindowGroup",
        "WindowHistory" }) do
        assertTrue(files[need], need .. " was swept")
    end
end)

test("tooltip placement: the mixed files' chrome is chrome and their content is body", function()
    local NS, _, list = built()
    local placeOf = {}
    for _, r in ipairs(list) do placeOf[r.w] = r.place or "body" end
    local f = NS.Window.Frame()
    assertEqual(placeOf[f.banner], "chrome", "the TEST MODE strip")
    assertEqual(placeOf[f.simBanner], "chrome", "the SIM strip")
    for _, key in ipairs({ "lockButton", "modeButton", "minimizeButton" }) do
        assertEqual(placeOf[f[key]], "chrome", key)
    end
end)

test("tooltip placement: a hover of every hooked widget calls its class's placer, owned at ANCHOR_NONE", function()
    local NS, m, list = built()
    local spy = T.tipSpy(m)
    local hovered = 0
    for i, r in ipairs(list) do
        local lines = r.w.tooltip and { r.w.tooltip() } or {}
        if #lines > 0 then
            spy.reset()
            m.GameTooltip.__anchor = nil
            r.w:__fire("OnEnter")
            local c = spy.first()
            local what = r.file .. " #" .. i
            assertEqual(m.GameTooltip.__anchor, "ANCHOR_NONE", what)
            assertTrue(c ~= nil, what .. ": a placer was called")
            if r.place == "chrome" then
                assertEqual(c.fn, "PlaceAttached", what)
                assertTrue(c.el == r.w, what .. ": attached to the control itself")
            else
                assertEqual(c.fn, "PlaceBeside", what)
                assertTrue(c.el == NS.RowTooltip.RowOf(r.w), what .. ": level with the row it sits in")
                assertTrue(c.group.main == outermost(r.w, m.UIParent), what .. ": beside its window group")
            end
            r.w:__fire("OnLeave")
            hovered = hovered + 1
        end
    end
    assertTrue(hovered >= 30, "the sweep hovered " .. hovered .. " widgets")
end)

test("tooltip placement: the Insights charts' marks open beside the window group (host.group)", function()
    local NS = T.enableAddon()
    local host = NS.ChartsHost()
    assertEqual(type(host.group), "function", "the host names its group (Charts minor 2)")
    assertTrue(host.group() == nil, "before the window is built: the mark's own group")
    NS.ShowWindow()
    local g = host.group()
    assertTrue(g and g.main == NS.Window.Frame(), "the window and its docked panels")
end)

-- The addon's own Lua, comments stripped: what each TOC file's code says.
local function codeOf(path)
    local fh = assert(io.open(T.root .. "/" .. path, "rb"))
    local src = fh:read("*a")
    fh:close()
    src = src:gsub("%-%-%[(=*)%[.-%]%1%]", "")
    return (src:gsub("%-%-[^\n]*", ""))
end

test("tooltip placement: the addon's own code names no cursor or corner anchor (anti-pattern #119)", function()
    local Loader = dofile("tests/_kit/loader.lua")
    local files = 0
    for _, rel in ipairs(Loader.tocFiles(T.root .. "/DropWatcher.toc")) do
        if not rel:find("^libs/") and rel:find("%.lua$") then
            files = files + 1
            local code = codeOf(rel)
            for anchor in code:gmatch("ANCHOR_[%u_]+") do
                assertEqual(anchor, "ANCHOR_NONE", rel .. ": only ANCHOR_NONE, the placers do the rest")
            end
            for owner in code:gmatch("SetOwner%b()") do
                assertTrue(owner:find("ANCHOR_NONE", 1, true) ~= nil, rel .. ": " .. owner)
            end
            assertTrue(code:find("GetCursorPosition", 1, true) == nil, rel .. ": no tooltip follows the pointer")
        end
    end
    assertTrue(files > 50, "the TOC's files were read: " .. files)
end)
