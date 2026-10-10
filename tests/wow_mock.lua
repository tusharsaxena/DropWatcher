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
--   tradeCalls     PickupContainerItem / DropItemOnUnit / InitiateTrade calls, in order
--   Enum           the members core/Compat.lua resolves by name; the enUS GlobalStrings it parses

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
}

-- What core/Compat.lua reaches, as controllable fakes. Enum values are this mock's own numbers;
-- the addon resolves every member by NAME, so a case that deletes a member models a client that
-- renamed it.
local function installCompatSurface(M)
    for k, v in pairs(GLOBAL_STRINGS) do M[k] = v end

    M.Enum = {
        TooltipDataLineType = { ItemBinding = 20, ItemUpgradeLevel = 32, TradeTimeRemaining = 36,
            ItemLevel = 41 },
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

    -- The trade actions, recorded in order as { name, ... }.
    M.tradeCalls = {}
    local function recorder(name)
        return function(...) M.tradeCalls[#M.tradeCalls + 1] = { name, ... } end
    end
    M.C_Container = { PickupContainerItem = recorder("PickupContainerItem") }
    M.DropItemOnUnit = recorder("DropItemOnUnit")
    M.InitiateTrade = recorder("InitiateTrade")
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
