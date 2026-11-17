local _, NS = ...
-- modules/FooterRow.lua — the window footer's controls (RX-24; WowAddonStandards v2.110.0
-- standalone-windows' *The footer*, anti-pattern #118): each tab's controls are the library
-- footer's `marks`, catalog icon buttons at one size and one pitch with a tooltip naming each, and
-- Expand all / Collapse all, the toggle that opens or closes every header the tab shows.
--
-- THE MARKS. W.Footer lays its `opts.marks` right to left from the grip's corner, built once with the
-- footer; the window passes FR.SLOTS of them (FR.MarkSpecs), the most any tab lays, and each tab
-- binds its own controls to them on every paint (FR.Bind, through NS.WindowFooter.PaintTab): the
-- first control takes the corner's mark, the next the one left of it, and a mark no control takes is
-- hidden. A control is a plain table, built once with its pane (FR.Control): its key, its catalog
-- mark, its tooltip and its action, and the state its paint sets (`enabled`, a new `icon`). Right to
-- left, the same in both layouts:
--
--   Drops     Expand/Collapse · Scan group · Post my tradeables
--   History   Expand/Collapse
--   Insights  Reset filters
--
-- Post my tradeables shows only while one of your drops the tab lists can be traded; it is the
-- leftmost, so the others keep their places. Sort is on the filter bar (modules/WindowFilterBar.lua)
-- and in the compact Filters menu, never on the footer. A mark's art is the host's to pass
-- (NS.Icon, the catalog names CLAUDE.md declares); its tint at rest and under the pointer is the
-- library's (`icon.tint`, `icon.hot`). Until RX-24 these were 150 px labeled buttons on a strip laid
-- over the footer (feedback-15 spec §2, DW-Q2), which the standard's footer has no room for.
--
-- THE TOGGLE (FR.FoldControl). Its mark a chevron (down to expand, up to collapse; feedback-16):
-- `Expand all` while any header the filters show is collapsed, `Collapse all` once every one is open
-- (FR.FoldState, pure). A click sets every shown header of the active tab (FR.FoldAll over the tab's
-- own collapsed map: Drops' NS.State.windowGroup, History's NS.State.windowHistory, so each tab
-- keeps its own); a group the filters hide keeps its state. A header with no drop shown (the View
-- filter hid them all) is drawn open whatever its state, so it has nothing to fold and does not
-- count; with no header that has one the toggle is off.
--
-- The tabs build their controls (modules/DropsStrip.lua, modules/WindowHistory.lua,
-- modules/WindowInsights.lua); this file reads NS.Window at call time only.

NS.FooterRow = NS.FooterRow or {}
local FR = NS.FooterRow
local L  = NS.L

FR.SLOTS = 3   -- the most controls a tab lays on the footer (Drops')

local foot   -- the window's footer, once FR.Attach has run

-- ── pure ────────────────────────────────────────────────────────────────────────────────────

-- A header that folds: one with a drop the filters show (a header kept open with none does not).
local function folds(e) return e.kind == "header" and (e.count or 0) > 0 end

--- What the toggle does now (pure): "expand" while a shown header is collapsed, "collapse" once
--- every one is open, nil (off) with no header that folds.
--- @param entries table|nil the tab's entries (NS.WindowCells.Entries' or NS.WindowHistory.Entries')
--- @return string|nil
function FR.FoldState(entries)
    local any, closed = false, false
    for _, e in ipairs(entries or {}) do
        if folds(e) then
            any = true
            if e.collapsed then closed = true end
        end
    end
    if not any then return nil end
    return closed and "expand" or "collapse"
end

--- Collapse, or open, every header the entries show that folds, in the tab's collapsed map.
--- @param entries table|nil
--- @param collapsed table the tab's view state's `collapsed` ([groupKey] = boolean)
--- @param collapse boolean
function FR.FoldAll(entries, collapsed, collapse)
    for _, e in ipairs(entries or {}) do
        if folds(e) and e.group then collapsed[e.group.key] = collapse == true end
    end
end

--- A control (pure): what one footer mark does while it is bound to it.
--- @param key string its name (`fold`, `scan`, `post`, `reset`)
--- @param icon string a declared catalog name (CLAUDE.md's `LibKa0s icons:`)
--- @param tip function control -> title, lines...
--- @param onClick function control -> nil
--- @return table { key, icon, tip, onClick, enabled = true }
function FR.Control(key, icon, tip, onClick)
    return { key = key, icon = icon, tip = tip, onClick = onClick, enabled = true }
end

-- ── the frame edge ──────────────────────────────────────────────────────────────────────────

-- A mark's press runs its control's action while it has one and is on, then reads the tooltip under
-- the pointer again (RX-28): the toggle's names what its next press does.
local function press(b)
    local c = b.dwControl
    if c and c.enabled ~= false then
        c.onClick(c)
        NS.Window.RefreshTooltip(b)
    end
end

--- W.Footer's `opts.marks` for the window: FR.SLOTS marks with no art yet, each pressing the control
--- bound to it (FR.Bind).
--- @return table
function FR.MarkSpecs()
    local out = {}
    for i = 1, FR.SLOTS do out[i] = { onClick = press } end
    return out
end

local function markTip(b)
    local c = b.dwControl
    if not c then return end
    return c.tip(c)
end

--- Take the window's footer (once per window): each mark's tooltip reads the control bound to it.
--- @param f table the footer (W.Footer's, or NS.BareFooter's with the same marks)
function FR.Attach(f)
    foot = f
    for _, b in ipairs(f.marks or {}) do
        b.dwControl = nil
        b:Hide()
        NS.Window.AttachTooltip(b, function() return markTip(b) end, "chrome")
    end
end

-- One mark bound to one control: its art when it moved, on or off, shown.
local function bindMark(b, c)
    b.dwControl = c
    if b.dwIcon ~= c.icon then
        b.dwIcon = c.icon
        b.icon:SetTexture(NS.Icon(c.icon))
    end
    local on = c.enabled ~= false
    if b.dwOn ~= on then
        b.dwOn = on
        b:SetEnabled(on)
        b:SetAlpha(on and 1 or 0.4)
    end
    if not b:IsShown() then b:Show() end
end

--- Bind the active tab's controls to the footer's marks, the first in the grip's corner; a mark left
--- over is hidden. Nothing is re-painted that did not change, so a repaint costs no texture set.
--- @param controls table|nil right to left
function FR.Bind(controls)
    if not foot then return end
    controls = controls or {}
    for i, b in ipairs(foot.marks) do
        local c = controls[i]
        if c then
            bindMark(b, c)
        elseif b.dwControl or b:IsShown() then
            b.dwControl = nil
            b:Hide()
        end
    end
end

--- The shown mark bound to the control `key`, or nil, for the suites.
--- @param key string
--- @return table|nil
function FR.Mark(key)
    for _, b in ipairs(foot and foot.marks or {}) do
        if b:IsShown() and b.dwControl and b.dwControl.key == key then return b end
    end
end

--- The shown marks' control keys, right to left from the corner, for the suites.
--- @return table
function FR.Shown()
    local out = {}
    for _, b in ipairs(foot and foot.marks or {}) do
        if b:IsShown() and b.dwControl then out[#out + 1] = b.dwControl.key end
    end
    return out
end

local function foldTip(c)
    if c.state == "collapse" then
        return L["Collapse all"], NS.TipMarks.Row(L["Closes"], L["every group this tab shows"])
    end
    return L["Expand all"], NS.TipMarks.Row(L["Opens"], L["every group this tab shows"]),
        NS.TipMarks.Hint(L["Collapse all closes them again."])
end

--- A tab's Expand all / Collapse all. `apply(collapse)` sets the tab's headers and repaints.
--- @param apply function boolean -> nil
--- @return table the control
function FR.FoldControl(apply)
    return FR.Control("fold", "chevron-down", foldTip, function(c)
        if c.state then apply(c.state == "collapse") end
    end)
end

--- Paint the toggle for the tab's entries: its mark, and off with no header that folds.
--- @param c table FR.FoldControl's
--- @param entries table|nil
function FR.PaintFold(c, entries)
    local state = FR.FoldState(entries)
    c.state = state
    c.icon = state == "collapse" and "chevron-up" or "chevron-down"
    c.enabled = state ~= nil
end
