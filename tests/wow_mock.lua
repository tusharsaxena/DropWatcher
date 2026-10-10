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

    M.fireEvent = function(event, ...) return M.__fireEvent(event, ...) end

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
