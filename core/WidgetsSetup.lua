local addonName, NS = ...
-- core/WidgetsSetup.lua — NS.MakeDropdown / NS.CloseMenu / NS.MakeTestStrip / NS.MakeSearchBox from
-- LibKa0s-Widgets-1.0: the window's flat dropdowns (the filter bar's View, Quality and Content, the
-- tab's Sort), its mode strips (LibKa0s#48: the amber test-mode strip and, from Widgets minor 14,
-- the cyan simulation flavor) and the filter bar's search box (LibKa0s#52).
--
-- A seam, nothing else (library-stack-§7): one file leases the major, so the art the dropdown
-- draws is resolved once, here. The library is vendored and cannot know which folder it was copied
-- into, so the chevron and the tick arrive as resolved paths from the addon's own media seam
-- (core/MediaSetup.lua); NS.Icon answering nil is a real answer, and the library falls back to the
-- Blizzard chevron and tick. No option this addon builds carries a glyph, so no glyph face is
-- passed.
--
-- THE POPUP IS A PROCESS-WIDE SINGLETON parented to UIParent, so hiding the window does not reach
-- it. Every non-click close path the window has calls NS.CloseMenu(): its OnHide (also the Escape
-- path through UISpecialFrames), and the minimize, which hides the bar the menu dropped from.
--
-- DEGRADED (the library absent): NS.MakeDropdown answers nil and the window draws no dropdown at
-- all rather than a dead control that opens no menu. NS.MakeSearchBox answers nil the same way: the
-- bar draws no search box and filters nothing by text (no hand-built fallback, which would be a
-- private copy of the library's box). NS.CloseMenu is a no-op, because there is no menu that could
-- be open. NS.MakeTestStrip answers nil and the window draws no strip and reserves no room for one;
-- the TEST MODE / SIMULATION word in the title bar then marks the mode. The title words mark a mode
-- only where there is no strip, or while the window is minimized (the strip goes with the body).
--
-- THE SKIN OWNER (skinning-§1: every library factory that takes an owner is given one). Each
-- factory below names this addon's folder as the widget's skin `owner` (LibKa0s-Widgets-1.0 minor
-- 16): the library paints the dropdown and the menu it drops, the search box and the mode strips
-- for the owner core/SkinSetup.lua registered, so they wear the player's skin and follow a switch.
-- On Ka0s Default each is the widget it always was; without the Skin major the field is ignored.

local W = LibStub and LibStub("LibKa0s-Widgets-1.0", true)

--- One flat-skin dropdown, or nil when the library is absent. Nil is a real answer: the caller
--- draws no control.
--- @param parent table the frame to parent it to
--- @param width number the collapsed button's width
--- @return table|nil
function NS.MakeDropdown(parent, width)
    if not W then return nil end
    return W.Dropdown(parent, width, {
        chevron = NS.Icon("chevron-down"),
        check   = NS.Icon("confirm"),
        owner   = addonName,
    })
end

--- The flat filter-bar search box (the library's W.SearchBox: the dropdown's fill and line, the hint
--- while empty, the gold line while focused, Escape and Enter let go of the keys), or nil when the
--- library is absent. The caller extends it with HookScript, never SetScript. No icon is passed:
--- this addon declares no search mark.
--- @param parent table the frame to parent it to
--- @param width number|nil the box's width
--- @param opts table|nil { hint, onChange } (W.SearchBox's opts)
--- @return table|nil
function NS.MakeSearchBox(parent, width, opts)
    if not W then return nil end
    local o = {}
    for k, v in pairs(opts or {}) do o[k] = v end
    o.owner = addonName
    return W.SearchBox(parent, width, o)
end

--- Whether the dropdown seam can build anything at all.
--- @return boolean
function NS.HasWidgets()
    return W ~= nil
end

--- A mode strip (the library's W.TestStrip, born hidden and unanchored): the amber test-mode
--- flavor, or the cyan simulation flavor for kind "sim". Nil when the library is absent. The caller
--- anchors it, tips it and shows it. Its art is host-passed: the catalog's info mark, resolved here.
--- The title bar's mode word stands in for it only where it is nil, or while minimized.
--- @param parent table the frame to parent it to
--- @param text string the localized line it says
--- @param kind string|nil "sim" for the simulation flavor; anything else is the test flavor
--- @return table|nil
function NS.MakeTestStrip(parent, text, kind)
    if not W then return nil end
    return W.TestStrip(parent, { text = text, icon = NS.Icon("info"), kind = kind, owner = addonName })
end

--- Close the shared popup menu behind every dropdown in the process, if one is open. Safe when none
--- ever opened, and a no-op on a degraded install.
function NS.CloseMenu()
    if W then W.CloseMenu() end
end
