-- tests/test_item_search_key.lua — the Item Search key (DropWatcher#17, Item Search spec §4.6, the
-- owner's rules; modules/ItemSearchKey.lua): a press over an item tooltip opens that item, with none
-- it opens empty, while open it closes over the same item or no tooltip and switches over another;
-- and the one-time Alt-Ctrl-D default, set once per character and only on a free key (re-tried once,
-- Item Search feedback spec §1, where the first try stored the dead chord CTRL-ALT-D). The binding
-- model is the kit's (tests/_kit/mock_bindings.lua); the item tooltips are tests/mock_tooltip_data.lua's
-- stand-ins. Every ForeverDB value is the kit fake's invented data.

local T = _G.DW_TEST
local test, assertEqual, assertTrue, assertFalse, assertNil =
    T.test, T.assertEqual, T.assertTrue, T.assertFalse, T.assertNil

local FDB = dofile("tests/_kit/mock_foreverdb.lua")
local TDP = dofile("tests/mock_tooltip_data.lua")
local IDS = FDB.IDS

local FOREVER_ONLY = (not T.forever) and "WoW Forever's alone (clients-§4): the Retail case asserts it is inert" or nil
local RETAIL_ONLY = T.forever and "the Retail profile's inert case; the Forever cases cover WoW Forever" or nil

local COMMAND = "CLICK DropWatcherItemSearch:LeftButton"
local KEY = "ALT-CTRL-D"
local DEAD = "CTRL-ALT-D"

-- The addon enabled with the ForeverDB fake and the tooltip stand-ins, before the first
-- PLAYER_ENTERING_WORLD unless `world`.
local function enabled(opts)
    opts = opts or {}
    local tdp
    local NS, _, m = T.enableAddon{ mock = function(mm)
        FDB.install(mm, { preset = "present" })
        tdp = TDP.install(mm)
        if opts.setup then opts.setup(mm) end
    end }
    -- AceDB's per-character section (the mock's database has none until a case gives it one).
    NS.addon.db.char = NS.addon.db.char or {}
    if opts.world then
        m.fireEvent("PLAYER_ENTERING_WORLD", true, false)
        m.advance(5)
    end
    return NS, m, tdp
end

local function press(m) m.DropWatcherItemSearch:__fire("OnClick", "LeftButton", true) end

-- ── what a press does (pure) ────────────────────────────────────────────────────────────────

test("item search key: the press's decision follows the owner's table", function()
    local NS = T.newAddon()
    local D = NS.ItemSearchKey.Decide
    assertEqual(D(false, nil, nil), "open", "closed, no tooltip: open empty")
    assertEqual(D(false, nil, 7), "show", "closed, over an item: open on it")
    -- red under: a press over the same item that switches instead of closing (the owner's rule)
    assertEqual(D(true, 7, 7), "close", "open, over the item shown: close")
    assertEqual(D(true, 7, nil), "close", "open, no tooltip: close")
    assertEqual(D(true, 7, 8), "show", "open, over another item: switch")
end)

-- ── a press ─────────────────────────────────────────────────────────────────────────────────

test("item search key: with no item tooltip a press opens the window empty, and the next press closes it", function()
    local NS, m = enabled({ world = true })
    local W = NS.ItemSearchWindow
    -- red under: the binding's button wired to nothing
    press(m)
    assertTrue(W.IsShown()); assertNil(W.ShownItem())
    press(m)
    assertFalse(W.IsShown(), "no tooltip while open: close")
end, FOREVER_ONLY)

test("item search key: over an item tooltip it opens that item; over the same one it closes, over another it switches", function()
    local NS, m, tdp = enabled({ world = true })
    local W = NS.ItemSearchWindow
    local tip = tdp.tooltip("GameTooltip")
    tdp.show(tip, IDS.blade)
    press(m)
    assertTrue(W.IsShown()); assertEqual(W.ShownItem(), IDS.blade, "prefilled and shown")
    tdp.show(tip, IDS.leather)
    press(m)
    -- red under: a press over another item that closes the window
    assertTrue(W.IsShown()); assertEqual(W.ShownItem(), IDS.leather, "switched")
    press(m)
    assertFalse(W.IsShown(), "over the item shown: close")
end, FOREVER_ONLY)

test("item search key: a chat link's tooltip and a comparison tooltip count; a hidden one does not", function()
    local NS, m, tdp = enabled({ world = true })
    local W = NS.ItemSearchWindow
    local game = tdp.tooltip("GameTooltip")
    local ref = tdp.tooltip("ItemRefTooltip")
    local shop = tdp.tooltip("ShoppingTooltip1")
    tdp.show(game, IDS.blade); tdp.hide(game)
    tdp.show(ref, IDS.cloak)
    press(m)
    -- red under: a read of GameTooltip alone, or of a hidden tooltip's stale item
    assertEqual(W.ShownItem(), IDS.cloak, "ItemRefTooltip")
    W.Close()
    tdp.hide(ref)
    tdp.show(shop, IDS.shard)
    press(m)
    assertEqual(W.ShownItem(), IDS.shard, "a comparison tooltip")
end, FOREVER_ONLY)

test("item search key: stood down, a press refuses with the one line and opens nothing", function()
    local NS, m = enabled({ world = true })
    NS.addon:SlashEnabled(false)
    m.prints = {}
    press(m)
    -- red under: a silent press, or one that opens the window while the addon is off (launcher-§6)
    assertFalse(NS.ItemSearchWindow.IsShown())
    assertEqual(#m.prints, 1)
    assertTrue(m.prints[1]:find("disabled", 1, true) ~= nil, m.prints[1])
end, FOREVER_ONLY)

test("item search key: on Retail a press does nothing and no key is set", function()
    local NS, m = enabled({ world = true })
    m.prints = {}
    press(m)
    assertEqual(NS.ItemSearchKey.Press(), "off")
    -- red under: a Retail default key (spec §1: no default on Retail)
    assertEqual(#m.__bindingWrites, 0)
    assertEqual(m.GetBindingKey(COMMAND), nil)
    assertEqual(#m.prints, 0)
end, RETAIL_ONLY)

-- ── the default key ─────────────────────────────────────────────────────────────────────────

test("item search key: Alt-Ctrl-D is bound at the first PLAYER_ENTERING_WORLD on a free key, saved to the set in force", function()
    local NS, m = enabled()
    assertEqual(m.GetBindingKey(COMMAND), nil)
    m.fireEvent("PLAYER_ENTERING_WORLD", true, false)
    -- red under: no default, or a default written into Bindings.xml instead (launcher-§6)
    assertEqual(m.GetBindingKey(COMMAND), KEY)
    assertEqual(m.GetBindingAction(KEY), COMMAND)
    assertEqual(table.concat(m.__savedBindingSets, ","), tostring(m.GetCurrentBindingSet()))
    assertEqual(NS.addon.db.char.itemSearch.keyDefaultedV, 2)
end, FOREVER_ONLY)

test("item search key: a key that runs something else is never taken", function()
    local NS, m = enabled({ setup = function(mm) mm.bindKey(KEY, "TOGGLEWORLDMAP") end })
    m.fireEvent("PLAYER_ENTERING_WORLD", true, false)
    -- red under: a default that steals a bound key (ItemTree's rule, the spec)
    assertEqual(m.GetBindingAction(KEY), "TOGGLEWORLDMAP")
    assertEqual(m.GetBindingKey(COMMAND), nil)
    assertEqual(NS.addon.db.char.itemSearch.keyDefaultedV, 2, "tried: never again on this character")
end, FOREVER_ONLY)

test("item search key: a binding that already has a key keeps it", function()
    local _, m = enabled({ setup = function(mm) mm.bindKey("F9", COMMAND) end })
    m.fireEvent("PLAYER_ENTERING_WORLD", true, false)
    assertEqual(m.GetBindingKey(COMMAND), "F9")
    assertEqual(m.GetBindingAction(KEY), "", "Alt-Ctrl-D left free")
end, FOREVER_ONLY)

test("item search key: once per character: a key the player clears is not put back", function()
    local NS, m = enabled()
    m.fireEvent("PLAYER_ENTERING_WORLD", true, false)
    assertEqual(m.GetBindingKey(COMMAND), KEY)
    m.SetBinding(KEY, nil)
    m.fireEvent("PLAYER_ENTERING_WORLD", false, false)
    -- red under: a default set again on every login
    assertEqual(m.GetBindingKey(COMMAND), nil)
    assertEqual(NS.ItemSearchKey.TryDefaultKey(), "done")
end, FOREVER_ONLY)

test("item search key: in combat the default waits for the combat's end", function()
    local _, m = enabled()
    m.inCombat = true
    m.fireEvent("PLAYER_ENTERING_WORLD", true, false)
    -- red under: a SetBinding in combat (#nocombat)
    assertEqual(#m.__bindingRefusals, 0, "no binding call in combat")
    assertEqual(m.GetBindingKey(COMMAND), nil)
    m.inCombat = false
    m.fireEvent("PLAYER_REGEN_ENABLED")
    assertEqual(m.GetBindingKey(COMMAND), KEY)
end, FOREVER_ONLY)

test("item search key: the tooltip block's hint and the window's footer name the bound key", function()
    local NS, m = enabled({ world = true })
    assertEqual(NS.Compat.BindingKeyText(NS.Constants.ITEM_SEARCH.BINDING), KEY)
    NS.ItemSearchWindow.Open()
    assertEqual(NS.ItemSearchWindow.Frame().foot.right:GetText(), KEY .. ": open in Item Search")
    m.SetBinding(KEY, nil)
    NS.ItemSearchWindow.Refresh()
    assertEqual(NS.ItemSearchWindow.Frame().foot.right:GetText(), "", "unbound: no hint")
end, FOREVER_ONLY)

-- ── the canonical chord and the re-try (Item Search feedback spec §1) ──────────────────────

-- The client writes a chord's modifiers ALT, CTRL, SHIFT, META (the kit's chord builder, BindingUtil's
-- order): a constant in any other order is a key no press ever matches.
local MOD_RANK = { ALT = 1, CTRL = 2, SHIFT = 3, META = 4 }
local function canonical(chord)
    local last = 0
    local parts = {}
    for part in chord:gmatch("[^-]+") do parts[#parts + 1] = part end
    for i = 1, #parts - 1 do
        local rank = MOD_RANK[parts[i]]
        if not rank or rank <= last then return false end
        last = rank
    end
    return #parts >= 1
end

test("item search key: every key constant the addon binds is in the client's canonical modifier order", function()
    local NS = T.newAddon()
    local IS = NS.Constants.ITEM_SEARCH
    -- red under: the first default, "CTRL-ALT-D", which never fired (the owner's report)
    assertFalse(canonical("CTRL-ALT-D"), "the check is falsifiable")
    assertTrue(canonical("ALT-CTRL-SHIFT-F1") and canonical("F8"))
    assertEqual(IS.DEFAULT_KEY, "ALT-CTRL-D")
    local seen = 0
    local function walk(t, depth)
        for k, v in pairs(t) do
            if type(v) == "string" and type(k) == "string" and k:find("_KEY$") and k ~= "DEAD_KEY" then
                seen = seen + 1
                assertTrue(canonical(v), k .. " = " .. v)
            elseif type(v) == "table" and depth < 3 then
                walk(v, depth + 1)
            end
        end
    end
    walk(NS.Constants, 0)
    assertTrue(seen >= 1, "the walk found the default key")
end)

test("item search key: a character the first try marked is re-tried once: the dead chord cleared, Alt-Ctrl-D bound", function()
    local NS, m = enabled({ setup = function(mm) mm.bindKey(DEAD, COMMAND) end })
    NS.addon.db.char.itemSearch = { keyDefaulted = true }
    m.fireEvent("PLAYER_ENTERING_WORLD", true, false)
    -- red under: the old marker honored (no re-try), or the dead chord left on the binding (the
    -- binding then counts as keyed and the re-try leaves it)
    assertEqual(m.GetBindingAction(DEAD), "", "the dead chord cleared")
    assertEqual(m.GetBindingKey(COMMAND), KEY)
    assertEqual(NS.addon.db.char.itemSearch.keyDefaultedV, 2)
    assertEqual(NS.ItemSearchKey.TryDefaultKey(), "done", "once")
end, FOREVER_ONLY)

test("item search key: the re-try keeps the rules: a key the player bound stays, a taken Alt-Ctrl-D is not taken", function()
    local NS, m = enabled({ setup = function(mm)
        mm.bindKey("F9", COMMAND)
        mm.bindKey(DEAD, "TOGGLEWORLDMAP")
    end })
    NS.addon.db.char.itemSearch = { keyDefaulted = true }
    m.fireEvent("PLAYER_ENTERING_WORLD", true, false)
    -- red under: a clear of a dead chord that runs something else, or a key put over the player's own
    assertEqual(m.GetBindingAction(DEAD), "TOGGLEWORLDMAP", "a CTRL-ALT-D that is not ours is left alone")
    assertEqual(m.GetBindingKey(COMMAND), "F9")
    assertEqual(m.GetBindingAction(KEY), "")

    local NS2, m2 = enabled({ setup = function(mm) mm.bindKey(KEY, "TOGGLEWORLDMAP") end })
    NS2.addon.db.char.itemSearch = { keyDefaulted = true }
    m2.fireEvent("PLAYER_ENTERING_WORLD", true, false)
    assertEqual(m2.GetBindingAction(KEY), "TOGGLEWORLDMAP")
    assertEqual(m2.GetBindingKey(COMMAND), nil)
    assertEqual(NS2.addon.db.char.itemSearch.keyDefaultedV, 2)
end, FOREVER_ONLY)

test("item search key: the re-try waits out combat before it clears anything", function()
    local NS, m = enabled({ setup = function(mm) mm.bindKey(DEAD, COMMAND) end })
    NS.addon.db.char.itemSearch = { keyDefaulted = true }
    m.inCombat = true
    m.fireEvent("PLAYER_ENTERING_WORLD", true, false)
    -- red under: a SetBinding in combat (#nocombat)
    assertEqual(#m.__bindingRefusals, 0)
    assertEqual(m.GetBindingAction(DEAD), COMMAND)
    m.inCombat = false
    m.fireEvent("PLAYER_REGEN_ENABLED")
    assertEqual(m.GetBindingAction(DEAD), "")
    assertEqual(m.GetBindingKey(COMMAND), KEY)
end, FOREVER_ONLY)
