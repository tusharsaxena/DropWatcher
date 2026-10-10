-- tests/wow_mock.lua
--
-- This addon's THIN EXTENDER over the shared kit's mock_base (testing-§1). The base owns everything
-- universal: LibStub with a real NewLibrary, the Ace fakes, AceDB's merge-in-place defaults, the
-- AceGUI recorder, the Settings registrars, the timer queue, the event dispatch and the recorders.
-- This file adds what Ka0s Drop Watcher reads that the base deliberately leaves out, as settable
-- fields on the mock so a suite seeds the client's answers before driving the addon.
--
-- Returns a BUILDER: each call is a fresh, isolated environment. `M._G = M`, so the table a suite
-- reads as `mock` and the table the addon's chunks read as `_G` are the same object.
--
-- Mock fields:
--   inCombat       InCombatLockdown()'s answer, and UnitAffectingCombat("player")'s
--   loadedAddons   the names C_AddOns.IsAddOnLoaded answers true for (this addon's own folder is in)
--   prints         every line handed to the Lua global `print` (the printer's sink)
--   popupsShown    every StaticPopup_Show(which, ...) call, in order
--   ldbObjects     LibDataBroker objects by name; minimapButtons LibDBIcon registrations by name
--   fireEvent      fireEvent(name, ...) dispatches a game event to AceEvent handlers
--   instance       GetInstanceInfo's name and difficultyID; the instance type and inInstance are
--                  the base's __context.instanceType / __context.inInstance (IsInInstance reads them)
--   challengeModeActive  C_ChallengeMode.IsChallengeModeActive()'s answer
--   unknownDifficulties  ids GetDifficultyInfo answers nil for (a retired or renumbered difficulty)
--   tooltips       C_TooltipInfo's answers: .bag["bag:slot"], .inventory["unit:slot"], .hyperlink[link]
--   chatSent       every C_ChatInfo.SendChatMessage call; chatLockdown is InChatMessagingLockdown()
--   restrictionStates  C_RestrictedActions' state per Enum.AddOnRestrictionType value (absent = 0)
--   upgradeInfo, accountBound, accountBoundUE  C_Item's answers per link; bagGUIDs["bag:slot"]
--   items          the item cache C_Item reads: items[link] = { name, quality, ilvl, effectiveIlvl,
--                  equipLoc, classID, subClassID, bindType, setID, stats, specs, unique, transmog,
--                  loadsNeeded }; addItem(link, def) seeds one. While loadsNeeded > 0 the item is
--                  uncached (GetItemInfo answers nil) and each RequestLoadItemDataByID of its id
--                  counts it down on the next timer pass; loadRequests records those ids in order
--   tradeCalls     PickupContainerItem / DropItemOnUnit / InitiateTrade calls, in order
--   inventory      GetInventoryItemLink's answers: inventory[unit][slot] = link
--   bags           C_Container's bags: bags[bag] = { size = n, [slot] = link }; an absent bag has 0 slots
--   specID         GetSpecializationInfo's first return (the base's 250 by default)
--   units          the group's unit tokens: units[token] = { guid, name, realm, class, classFile,
--                  connected }; "player" is read from the base's __context unless set. setGroup()
--                  seeds a party or a raid. normalizedRealm is GetNormalizedRealmName()'s answer
--   Enum           the members core/Compat.lua resolves by name; the enUS GlobalStrings it parses
--                  and the LOOT_ITEM* lines modules/LootParser.lua reads (overwrite one to model a
--                  locale or a chat addon rewriting it)

local base = dofile("tests/_kit/mock_base.lua")

local WINDOW_NAME = "DropWatcherWindow"

-- The main window's geometry, recorded: the kit's frame answers every unmodeled getter with the
-- frame itself, so "the window went back to where it started" could not fail without this.
local function decorateGeometry(M, f)
    -- Regions are objects of their own here: the base answers CreateFontString with the frame
    -- itself, so hiding the banner would hide the window.
    f.__regions = {}
    local function region(kind)
        return function(self)
            local r = M.__stubFrame()
            r.__objType = kind
            self.__regions[#self.__regions + 1] = r
            return r
        end
    end
    f.CreateFontString = region("FontString")
    f.CreateTexture = region("Texture")
    f.__points = {}
    f.SetPoint = function(self, point, rel, relPoint, x, y)
        self.__points[#self.__points + 1] = { point, rel, relPoint, x, y }
        return self
    end
    f.ClearAllPoints = function(self) self.__points = {}; return self end
    f.GetPoint = function(self, i)
        local pt = self.__points[i or 1]
        if pt then return pt[1], pt[2], pt[3], pt[4], pt[5] end
    end
    f.SetSize = function(self, w, h) self.__width, self.__height = w, h; return self end
    f.GetWidth = function(self) return self.__width or 0 end
    f.GetHeight = function(self) return self.__height or 0 end
    f.SetScale = function(self, s) self.__scale = s; return self end
    f.GetScale = function(self) return self.__scale or 1 end
    f.SetAlpha = function(self, a) self.__alpha = a; return self end
    f.GetAlpha = function(self) return self.__alpha or 1 end
    return f
end

-- The enUS GlobalStrings core/Compat.lua builds its patterns from. A case that models another
-- client language overwrites them on the mock after the load (Compat reads them at call time).
local GLOBAL_STRINGS = {
    BIND_TRADE_TIME_REMAINING = "You may trade this item with players that were also eligible to "
        .. "loot this item for the next %s.",
    INT_SPELL_DURATION_HOURS = "%d |4hour:hrs;",
    INT_SPELL_DURATION_MIN = "%d min",
    INT_SPELL_DURATION_SEC = "%d sec",
    TIME_UNIT_DELIMITER = " ",
    ITEM_LEVEL = "Item Level %d",
    ITEM_UPGRADE_TOOLTIP_FORMAT_STRING = "Upgrade Level: %s %d/%d",
    ITEM_CLASSES_ALLOWED = "Classes: %s",
    LIST_DELIMITER = ", ",
    -- The loot lines modules/LootParser.lua reads, and the echoes it rejects.
    LOOT_ITEM = "%s receives loot: %s.",
    LOOT_ITEM_MULTIPLE = "%s receives loot: %sx%d.",
    LOOT_ITEM_SELF = "You receive loot: %s.",
    LOOT_ITEM_SELF_MULTIPLE = "You receive loot: %sx%d.",
    LOOT_ITEM_BONUS_ROLL = "%s receives bonus loot: %s.",
    LOOT_ITEM_BONUS_ROLL_MULTIPLE = "%s receives bonus loot: %sx%d.",
    LOOT_ITEM_BONUS_ROLL_SELF = "You receive bonus loot: %s.",
    LOOT_ITEM_BONUS_ROLL_SELF_MULTIPLE = "You receive bonus loot: %sx%d.",
    LOOT_ITEM_PUSHED = "%s receives item: %s.",
    LOOT_ITEM_PUSHED_MULTIPLE = "%s receives item: %sx%d.",
    LOOT_ITEM_PUSHED_SELF = "You receive item: %s.",
    LOOT_ITEM_PUSHED_SELF_MULTIPLE = "You receive item: %sx%d.",
    CHANGED_OWN_ITEM = "Changed %s to %s.",
    LOOT_ITEM_CREATED_SELF = "You create: %s.",
    LOOT_ITEM_CREATED_SELF_MULTIPLE = "You create: %sx%d.",
    CREATED_ITEM = "%s creates: %s.",
    CREATED_ITEM_MULTIPLE = "%s creates: %sx%d.",
}

-- The client's classFile -> localized class name maps, enUS (both genders spell the same here).
local CLASS_NAMES = {
    WARRIOR = "Warrior", PALADIN = "Paladin", HUNTER = "Hunter", ROGUE = "Rogue", PRIEST = "Priest",
    DEATHKNIGHT = "Death Knight", SHAMAN = "Shaman", MAGE = "Mage", WARLOCK = "Warlock",
    MONK = "Monk", DRUID = "Druid", DEMONHUNTER = "Demon Hunter", EVOKER = "Evoker",
}

-- The item cache behind C_Item's readers and the transmog collection (modules/ItemFacts.lua).
-- Each reader answers only for a cached item (loadsNeeded 0 or nil); GetItemInfo's seventeen
-- returns are the client's order.
local function cachedItem(M, link)
    local d = M.items[link]
    if not d or (d.loadsNeeded or 0) > 0 then return nil end
    return d
end

local function installItemCache(M)
    M.items, M.loadRequests = {}, {}
    local item = M.C_Item
    function M.addItem(link, def)
        def.itemID = tonumber(link:match("item:(%d+)"))
        M.items[link] = def
        return link
    end
    item.GetItemInfo = function(link)
        local d = cachedItem(M, link)
        if not d then return nil end
        return d.name, link, d.quality, d.ilvl, 1, "", "", 1, d.equipLoc or "", 0, 0, d.classID,
            d.subClassID, d.bindType or 0, 0, d.setID, false
    end
    item.GetDetailedItemLevelInfo = function(link)
        local d = cachedItem(M, link)
        if d then return d.effectiveIlvl or d.ilvl, false, d.ilvl end
    end
    item.GetItemStats = function(link)
        local d = cachedItem(M, link)
        return d and d.stats
    end
    item.GetItemSpecInfo = function(link)
        local d = cachedItem(M, link)
        return d and d.specs
    end
    -- unique = { isUnique, categoryName, categoryCount, categoryID }
    item.GetItemUniquenessByID = function(link)
        local d = cachedItem(M, link)
        if d and d.unique then return d.unique[1], d.unique[2], d.unique[3], d.unique[4] end
        return false
    end
    -- The data arrives later, as in the client: on the next timer pass, ahead of LoadItem's callback.
    item.RequestLoadItemDataByID = function(id)
        M.loadRequests[#M.loadRequests + 1] = id
        M.C_Timer.After(0, function()
            for _, d in pairs(M.items) do
                if d.itemID == id and (d.loadsNeeded or 0) > 0 then d.loadsNeeded = d.loadsNeeded - 1 end
            end
        end)
    end
    M.C_TransmogCollection = {
        PlayerHasTransmogByItemInfo = function(link)
            local d = cachedItem(M, link)
            if d then return d.transmog == true end
            return false
        end,
    }
    M.LOCALIZED_CLASS_NAMES_MALE, M.LOCALIZED_CLASS_NAMES_FEMALE = {}, {}
    for classFile, name in pairs(CLASS_NAMES) do
        M.LOCALIZED_CLASS_NAMES_MALE[classFile] = name
        M.LOCALIZED_CLASS_NAMES_FEMALE[classFile] = name
    end
end

-- What core/Compat.lua reaches, as controllable fakes. Enum values are this mock's own numbers;
-- the addon resolves every member by NAME, so a case that deletes a member models a client that
-- renamed it.
local function installCompatSurface(M)
    for k, v in pairs(GLOBAL_STRINGS) do M[k] = v end

    M.Enum = {
        TooltipDataLineType = { ItemBinding = 20, RestrictedRaceClass = 21, ItemUpgradeLevel = 32,
            TradeTimeRemaining = 36, ItemLevel = 41 },
        AddOnRestrictionType = { Combat = 0, Encounter = 1, ChallengeMode = 2, PvPMatch = 3, Map = 4,
            Chat = 5 },
        AddOnRestrictionState = { Inactive = 0, Activating = 1, Active = 2 },
    }

    -- C_TooltipInfo: the data a getter answers, keyed "bag:slot", "unit:slot" and by link.
    M.tooltips = { bag = {}, inventory = {}, hyperlink = {} }
    M.C_TooltipInfo = {
        GetBagItem = function(bag, slot) return M.tooltips.bag[bag .. ":" .. slot] end,
        GetInventoryItem = function(unit, slot) return M.tooltips.inventory[unit .. ":" .. slot] end,
        GetHyperlink = function(link) return M.tooltips.hyperlink[link] end,
    }

    -- C_ChatInfo: every SendChatMessage call is recorded in M.chatSent; chatLockdown is
    -- InChatMessagingLockdown's answer.
    M.chatSent, M.chatLockdown = {}, false
    M.C_ChatInfo = {
        SendChatMessage = function(text, chatType, languageID, target)
            M.chatSent[#M.chatSent + 1] = { text = text, chatType = chatType, languageID = languageID,
                target = target }
        end,
        InChatMessagingLockdown = function() return M.chatLockdown end,
    }

    -- C_RestrictedActions: restrictionStates[type] is the state; absent means Inactive.
    M.restrictionStates = {}
    M.C_RestrictedActions = {
        GetAddOnRestrictionState = function(rtype) return M.restrictionStates[rtype] or 0 end,
        IsAddOnRestrictionActive = function(rtype) return (M.restrictionStates[rtype] or 0) ~= 0 end,
    }

    -- C_Item: upgradeInfo[link], accountBound[link], accountBoundUE[link], bagGUIDs["bag:slot"].
    M.upgradeInfo, M.accountBound, M.accountBoundUE, M.bagGUIDs = {}, {}, {}, {}
    M.C_Item = {
        GetItemUpgradeInfo = function(link) return M.upgradeInfo[link] end,
        IsItemBindToAccount = function(link) return M.accountBound[link] == true end,
        IsItemBindToAccountUntilEquip = function(link) return M.accountBoundUE[link] == true end,
        DoesItemExist = function(loc) return M.bagGUIDs[loc.bag .. ":" .. loc.slot] ~= nil end,
        GetItemGUID = function(loc) return M.bagGUIDs[loc.bag .. ":" .. loc.slot] end,
    }
    M.ItemLocation = {
        CreateFromBagAndSlot = function(_, bag, slot) return { bag = bag, slot = slot } end,
    }
    installItemCache(M)

    -- The trade actions, recorded in order as { name, ... }.
    M.tradeCalls = {}
    local function recorder(name)
        return function(...) M.tradeCalls[#M.tradeCalls + 1] = { name, ... } end
    end
    M.C_Container = { PickupContainerItem = recorder("PickupContainerItem") }

    -- What the player wears and carries (modules/Gear.lua), and the spec the client answers.
    M.inventory, M.bags = { player = {} }, {}
    M.GetInventoryItemLink = function(unit, slot)
        local worn = M.inventory[unit]
        return worn and worn[slot]
    end
    M.C_Container.GetContainerNumSlots = function(bag)
        local b = M.bags[bag]
        return b and b.size or 0
    end
    M.C_Container.GetContainerItemLink = function(bag, slot)
        local b = M.bags[bag]
        return b and b[slot]
    end
    M.specID = 250
    M.GetSpecializationInfo = function() return M.specID, M.__context.spec end
    M.DropItemOnUnit = recorder("DropItemOnUnit")
    M.InitiateTrade = recorder("InitiateTrade")
end

-- The group's units (modules/Roster.lua). The player's row is the base's __context, read live, so
-- the perf context and the roster agree; any other token answers only when units[token] is set.
local PLAYER_GUID = "Player-1-00000001"

local function installUnits(M)
    M.units = {}
    M.normalizedRealm = "Testrealm"
    local function row(unit)
        local r = M.units[unit]
        if r or unit ~= "player" then return r end
        local c = M.__context
        return { guid = PLAYER_GUID, name = c.name, class = c.class, classFile = c.classToken,
            connected = true }
    end
    local baseExists = M.UnitExists
    M.UnitExists = function(unit) return row(unit) ~= nil or baseExists(unit) end
    M.UnitGUID = function(unit)
        local r = row(unit)
        return r and r.guid
    end
    M.UnitName = function(unit)
        local r = row(unit)
        if r then return r.name, r.realm end
    end
    M.UnitClass = function(unit)
        local r = row(unit)
        if r then return r.class, r.classFile end
    end
    M.UnitIsConnected = function(unit)
        local r = row(unit)
        return r ~= nil and r.connected ~= false
    end
    M.GetNormalizedRealmName = function() return M.normalizedRealm end
    M.UNKNOWNOBJECT = "Unknown"

    --- Seed a group: `others` are the rows besides the player, in unit order. A party gives the
    --- player "player" and the others party1..; a raid gives raid1 to the player, then the others.
    function M.setGroup(others, raid)
        M.units = {}
        local first = 1
        if raid then
            M.units.raid1 = row("player")
            first = 2
        end
        for i, r in ipairs(others) do
            local token = raid and ("raid" .. (i + first - 1)) or ("party" .. i)
            M.units[token] = r
        end
        M.__context.inGroup = #others > 0
        M.__context.inRaid = raid and true or false
        M.__context.groupSize = #others > 0 and #others + 1 or 0
    end
end

local function build()
    local M = base()
    M._G = M

    M.inCombat     = false
    M.prints       = {}
    M.popupsShown  = {}
    M.loadedAddons = { DropWatcher = true }

    M.InCombatLockdown    = function() return M.inCombat == true end
    M.UnitAffectingCombat = function() return M.inCombat == true end

    -- The client's addon list; the base leaves C_AddOns out on purpose (its own NOTE).
    M.C_AddOns = {
        IsAddOnLoaded = function(name)
            local on = M.loadedAddons[name] == true
            return on, on
        end,
        GetAddOnMetadata = function() return nil end,
    }

    -- The chat sink core/CoreSetup.lua hands the printer: captured, so a suite can read it back.
    M.print = function(...)
        local parts = {}
        for i = 1, select("#", ...) do parts[i] = tostring((select(i, ...))) end
        M.prints[#M.prints + 1] = table.concat(parts, " ")
    end

    M.StaticPopup_Show = function(which, ...) M.popupsShown[#M.popupsShown + 1] = { which, ... } end

    -- Where the player is (modules/Situations.lua). Outside an instance the client answers type
    -- "none" and difficulty 0; GetDifficultyInfo answers a name for any positive id not retired.
    M.instance = { name = "Silvermoon City", difficultyID = 0 }
    M.challengeModeActive = false
    M.unknownDifficulties = {}
    M.GetInstanceInfo = function()
        return M.instance.name, M.__context.instanceType, M.instance.difficultyID
    end
    M.GetDifficultyInfo = function(id)
        if type(id) ~= "number" or id <= 0 or M.unknownDifficulties[id] then return nil end
        return "Difficulty " .. id
    end
    M.C_ChallengeMode = {
        IsChallengeModeActive = function() return M.challengeModeActive == true end,
    }

    M.fireEvent = function(event, ...) return M.__fireEvent(event, ...) end

    installCompatSurface(M)
    installUnits(M)

    local baseCreateFrame = M.CreateFrame
    M.CreateFrame = function(frameType, name, parent, template)
        local f = baseCreateFrame(frameType, name, parent, template)
        if name == WINDOW_NAME then decorateGeometry(M, f) end
        return f
    end

    -- The launcher's two libraries (launcher-§1), present by default because both are vendored and
    -- TOC-listed. Their whole surface as LibKa0s-Launcher-1.0 uses it; a case that wants the
    -- degraded install clears one through the loader's `mock` option.
    M.ldbObjects = {}
    M.__libs["LibDataBroker-1.1"] = {
        NewDataObject = function(_, name, tbl)
            if M.ldbObjects[name] then return nil end
            M.ldbObjects[name] = tbl
            return tbl
        end,
        GetDataObjectByName = function(_, name) return M.ldbObjects[name] end,
    }
    M.minimapButtons = {}
    M.__libs["LibDBIcon-1.0"] = {
        Register = function(_, name, object, db)
            M.minimapButtons[name] = { object = object, db = db, shown = not (db and db.hide) }
        end,
        IsRegistered = function(_, name) return M.minimapButtons[name] ~= nil end,
        Show = function(_, name)
            local b = M.minimapButtons[name]
            if b then b.shown = true end
        end,
        Hide = function(_, name)
            local b = M.minimapButtons[name]
            if b then b.shown = false end
        end,
        GetMinimapButton = function(_, name) return M.minimapButtons[name] end,
    }

    return M
end

return build
