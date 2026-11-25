-- tests/test_item_search_key.lua — the Item Search key (DropWatcher#17, Item Search spec §4.6, the
-- owner's rules; modules/ItemSearchKey.lua): a press over an item tooltip opens that item, with none
-- it opens empty, while open it closes over the same item or no tooltip and switches over another;
-- and the one-time Ctrl-Alt-D default, set once per character and only on a free key. The binding
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
local KEY = "CTRL-ALT-D"

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

test("item search key: Ctrl-Alt-D is bound at the first PLAYER_ENTERING_WORLD on a free key, saved to the set in force", function()
    local NS, m = enabled()
    assertEqual(m.GetBindingKey(COMMAND), nil)
    m.fireEvent("PLAYER_ENTERING_WORLD", true, false)
    -- red under: no default, or a default written into Bindings.xml instead (launcher-§6)
    assertEqual(m.GetBindingKey(COMMAND), KEY)
    assertEqual(m.GetBindingAction(KEY), COMMAND)
    assertEqual(table.concat(m.__savedBindingSets, ","), tostring(m.GetCurrentBindingSet()))
    assertTrue(NS.addon.db.char.itemSearch.keyDefaulted == true)
end, FOREVER_ONLY)

test("item search key: a key that runs something else is never taken", function()
    local NS, m = enabled({ setup = function(mm) mm.bindKey(KEY, "TOGGLEWORLDMAP") end })
    m.fireEvent("PLAYER_ENTERING_WORLD", true, false)
    -- red under: a default that steals a bound key (ItemTree's rule, the spec)
    assertEqual(m.GetBindingAction(KEY), "TOGGLEWORLDMAP")
    assertEqual(m.GetBindingKey(COMMAND), nil)
    assertTrue(NS.addon.db.char.itemSearch.keyDefaulted == true, "tried: never again on this character")
end, FOREVER_ONLY)

test("item search key: a binding that already has a key keeps it", function()
    local _, m = enabled({ setup = function(mm) mm.bindKey("F9", COMMAND) end })
    m.fireEvent("PLAYER_ENTERING_WORLD", true, false)
    assertEqual(m.GetBindingKey(COMMAND), "F9")
    assertEqual(m.GetBindingAction(KEY), "", "Ctrl-Alt-D left free")
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
