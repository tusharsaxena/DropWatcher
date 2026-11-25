local _, NS = ...
-- modules/ItemSearchKey.lua — the Item Search key (DropWatcher#17, Item Search spec §4.6, the
-- owner's rules): what a press does, and the one-time default key. WoW Forever's alone
-- (C.FEATURE.itemSearch, clients-§4): on Retail a press does nothing and no key is set.
--
-- THE BINDING. Bindings.xml's second row, `CLICK DropWatcherItemSearch:LeftButton`
-- (C.ITEM_SEARCH.BINDING), in Drop Watcher's category beside the unchanged Show window binding,
-- labeled "Item Search" (the owner). Its button, labels and NS.BINDINGS entry are made in
-- core/LauncherSetup.lua with the Show window one (launcher-§6: one module owns the binding
-- globals); the button's click is IK.Press. The row carries `clients = { "forever" }`, so General >
-- Keybindings draws it on WoW Forever alone; the client's own Keybindings page lists it on both
-- clients, since the client reads one Bindings.xml for both (spec §1).
--
-- A PRESS (spec §4.6, the owner):
--   * an item tooltip is showing (GameTooltip, ItemRefTooltip or a comparison tooltip, the first
--     that is shown and holds an item): the window opens with that item shown;
--   * none: the window opens empty with the search box focused;
--   * while the window is open: pressed over the item it already shows, or with no item tooltip
--     showing, it closes; pressed over another item, it switches to that one.
-- Stood down, a press refuses as the Show window key does (NS.StoodDownRefusal's one line).
--
-- THE DEFAULT KEY (spec §4.6): Alt-Ctrl-D (C.ITEM_SEARCH.DEFAULT_KEY, `ALT-CTRL-D`, the client's
-- canonical modifier order), set ONCE per character and only while that key runs nothing and the
-- binding has no key of its own, so it never steals a key the player bound (ItemTree's rule). The
-- try runs at the session's first PLAYER_ENTERING_WORLD, out of combat (in combat it waits for
-- PLAYER_REGEN_ENABLED; SetBinding is #nocombat), and is recorded in
-- db.char.itemSearch.keyDefaultedV (= C.ITEM_SEARCH.KEY_DEFAULT_V) whatever it found, so a key the
-- player clears later is never put back. Bindings.xml itself carries no `default` attribute
-- (launcher-§6's MUST NOT).
--
-- THE RE-TRY (Item Search feedback spec §1). The first default was stored as `CTRL-ALT-D`, a chord
-- no key press ever matches (the client writes a press ALT-CTRL-...), and every character that ran
-- it has the old marker `keyDefaulted = true`. The version marker makes the try run once more where
-- it is missing; before it, a binding that holds the dead chord (C.ITEM_SEARCH.DEAD_KEY) is cleared,
-- so the binding counts as keyless. A character with the old marker whose binding no longer holds
-- the dead chord is NOT re-tried (answered "moved"): the player cleared or rebound the key after the
-- first try, and a key the player clears is never put back. Whether GetBindingAction answers the
-- stored dead chord as written (not normalized to ALT-CTRL-D) is smoke ITEM-SEARCH-19's probe. The
-- old marker is otherwise left alone.

NS.ItemSearchKey = NS.ItemSearchKey or {}
local IK = NS.ItemSearchKey
local IS = NS.ItemSearch
local C  = NS.Constants

local Compat = NS.Compat

--- The tooltips a press reads, in order: the hovered one, the chat link's, then the comparisons.
IK.TOOLTIPS = { "GameTooltip", "ItemRefTooltip", "ShoppingTooltip1", "ShoppingTooltip2",
    "ItemRefShoppingTooltip1", "ItemRefShoppingTooltip2" }

local waitCombat = false

--- The item an item tooltip on screen holds (the first of IK.TOOLTIPS that is shown and holds
--- one), or nil.
--- @return number|nil
function IK.HoveredItem()
    return Compat.ShownItemTooltipItemID(IK.TOOLTIPS)
end

--- What a press does, from the window's state and the hovered item (pure): "close", "show" (the
--- hovered item) or "open" (empty, search focused).
--- @param open boolean the window is shown
--- @param shown number|nil the item it shows
--- @param hovered number|nil the item tooltip's item
--- @return string
function IK.Decide(open, shown, hovered)
    if open then
        if hovered == nil or hovered == shown then return "close" end
        return "show"
    end
    if hovered then return "show" end
    return "open"
end

--- The key's press (the binding button's click). Answers what it did: "refused", "off", "close",
--- "show" or "open".
--- @return string
function IK.Press()
    if not IS.Enabled() then return "off" end
    local line = NS.StoodDownRefusal()
    if line then
        NS.Print(line)
        return "refused"
    end
    local W = NS.ItemSearchWindow
    if not W.Available() then
        NS.Print(NS.L["Item Search's window is switched off."])
        return "off"
    end
    local hovered = IK.HoveredItem()
    local act = IK.Decide(W.IsShown(), W.ShownItem(), hovered)
    if act == "close" then
        W.Close()
    elseif act == "show" then
        W.ShowItem(hovered)
    else
        W.Open()
    end
    return act
end

-- ── the default key ─────────────────────────────────────────────────────────────────────────

local function charStore()
    local db = NS.addon and NS.addon.db
    local c = db and db.char
    if type(c) ~= "table" then return nil end
    if type(c.itemSearch) ~= "table" then c.itemSearch = {} end
    return c.itemSearch
end

--- Set the default key once per character (see the header). Answers what happened: "bound",
--- "taken" (the key runs something else), "has" (the binding already has a key), "moved" (the first
--- try ran here and its dead chord is gone: the player cleared or rebound it), "done" (tried
--- before), "combat" (waits for the combat's end), "off" (Retail) or "unavailable".
--- @return string
function IK.TryDefaultKey()
    if not IS.Enabled() then return "off" end
    local store = charStore()
    if not store then return "unavailable" end
    local V = C.ITEM_SEARCH.KEY_DEFAULT_V
    if store.keyDefaultedV == V then return "done" end
    if Compat.InCombatLockdown() then
        waitCombat = true
        return "combat"
    end
    waitCombat = false
    local command, key = C.ITEM_SEARCH.BINDING, C.ITEM_SEARCH.DEFAULT_KEY
    local cleared = IK.ClearDeadKey(command)
    local has, action = Compat.HasBinding(command), Compat.BindingAction(key)
    if has == nil or action == nil then return "unavailable" end
    store.keyDefaultedV = V
    if has then return "has" end
    if store.keyDefaulted == true and not cleared then
        NS.Debug("SEARCH", "default key not re-tried: the first try's %s is gone", C.ITEM_SEARCH.DEAD_KEY)
        return "moved"
    end
    if action ~= "" then
        NS.Debug("SEARCH", "default key %s left alone: it runs %s", key, action)
        return "taken"
    end
    if not Compat.BindKey(key, command) then
        store.keyDefaultedV = nil
        return "unavailable"
    end
    NS.Debug("SEARCH", "default key %s bound to Item Search", key)
    return "bound"
end

--- Clear the first default's dead chord (C.ITEM_SEARCH.DEAD_KEY) off `command`, when that chord
--- still runs it (spec §1's re-try). Out of combat only (the caller asks). Answers whether it cleared.
--- @param command string
--- @return boolean
function IK.ClearDeadKey(command)
    local dead = C.ITEM_SEARCH.DEAD_KEY
    if Compat.BindingAction(dead) ~= command then return false end
    if not Compat.BindKey(dead, nil) then return false end
    NS.Debug("SEARCH", "dead chord %s cleared off Item Search", dead)
    return true
end

-- PLAYER_ENTERING_WORLD and PLAYER_REGEN_ENABLED are shared (core/DropWatcher.lua's dispatcher);
-- modules/ItemSearch.lua's handlers call these.
function IK.OnWorld()
    IK.TryDefaultKey()
end

function IK.OnRegen()
    if waitCombat then IK.TryDefaultKey() end
end
