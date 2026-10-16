local _, NS = ...
-- modules/FooterRow.lua — one footer button kind, and Expand all / Collapse all (feedback-15 spec §2,
-- DW-Q2): the row of controls at the right of each tab's strip, and the toggle that opens or closes
-- every header the tab shows.
--
-- ONE BUTTON KIND. Every button on a strip is K.FOOTER_BUTTON_W wide (sized so `Post my tradeables`
-- fits beside its icon) with the same icon and label in both layouts: no short `Post` or `Clear`.
-- The row, right to left, a GAP between two controls:
--
--             Full                                                 Compact (icon only)
--   Drops     Sort · Expand/Collapse · Scan group · Post my tradeables   Expand/Collapse · Scan group · Post
--   History   Sort · Expand/Collapse                                     Expand/Collapse
--
-- Post my tradeables shows only while one of your drops the tab lists can be traded; a hidden
-- control takes no room. In compact, Sort stays in the Filters panel (modules/CompactChrome.lua),
-- and every button is its mark alone, K.FOOTER_ICON_W wide and centered, its tooltip naming it
-- (FR.SetCompact; feedback-16: three labeled buttons do not fit the 440 pane; Scan group joins the
-- strip, as in full, and stays the title bar's icon too). FR.Slots is that placement, pure; the info text on the strip's
-- left ends GAP short of the leftmost control (its `left`), one line, so a narrow row cuts it with an
-- ellipsis rather than run it under the buttons. (Clear history left the strips for Settings ›
-- Window › Layout in DW-Q3, feedback-15 spec §3.)
--
-- THE TOGGLE. One button per strip, its mark a chevron (down to expand, up to collapse; feedback-16):
-- `Expand all` while any header the filters show is collapsed,
-- `Collapse all` once every one is open (FR.FoldState, pure). A click sets every shown header of the
-- active tab (FR.FoldAll over the tab's own collapsed map: Drops' NS.State.windowGroup, History's
-- NS.State.windowHistory, so each tab keeps its own); a group the filters hide keeps its state. A
-- header with no drop shown (the View filter hid them all) is drawn open whatever its state, so it
-- has nothing to fold and does not count; with no header that has one the button is off.
--
-- The tabs build and place it (modules/DropsStrip.lua, modules/WindowHistory.lua); this file reads
-- NS.Window at call time only.

NS.FooterRow = NS.FooterRow or {}
local FR = NS.FooterRow
local K  = NS.Constants.WINDOW
local L  = NS.L

FR.GAP = 8   -- between two controls of the row

-- ── pure ────────────────────────────────────────────────────────────────────────────────────

--- Where each control of a row goes (pure): its right edge, in pixels left of the strip's right
--- edge, right to left with `gap` between two shown controls; a hidden one (`shown == false`) is nil
--- and takes no room. `left` is the leftmost shown control's left edge, where the info text ends.
--- @param row table right to left: { { key, w, shown }, ... }
--- @param gap number
--- @param start number|nil the first control's inset (0)
--- @return table { [key] = number|nil, left = number }
function FR.Slots(row, gap, start)
    local out, x, first = {}, start or 0, true
    for _, c in ipairs(row) do
        if c.shown ~= false then
            if not first then x = x + gap end
            out[c.key] = x
            x = x + c.w
            first = false
        end
    end
    out.left = x
    return out
end

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

-- ── the frame edge ──────────────────────────────────────────────────────────────────────────

--- A footer button: NS.Window.TextButton at the one width (K.FOOTER_BUTTON_W).
--- @return table
function FR.Button(parent, icon, text, onClick)
    return NS.Window.TextButton(parent, K.FOOTER_BUTTON_W, icon, text, onClick)
end

--- The width of a strip button in the layout in force: the labeled one, or compact's icon alone.
--- @param compact boolean
--- @return number
function FR.Width(compact)
    return compact and K.FOOTER_ICON_W or K.FOOTER_BUTTON_W
end

--- Draw a strip button labeled (full) or as its mark alone, centered (compact); its tooltip
--- names it either way.
--- @param b table FR.Button's
--- @param compact boolean
function FR.SetCompact(b, compact)
    compact = compact == true
    if b.dwCompact == compact then return end
    b.dwCompact = compact
    b:SetWidth(FR.Width(compact))
    b.label:SetShown(not compact)
    b.art:ClearAllPoints()
    if compact then b.art:SetPoint("CENTER", b, "CENTER", 0, 0) else b.art:SetPoint("LEFT", b, "LEFT", 6, 0) end
end

--- Put one control `inset` pixels left of the strip's right edge, or hide it (inset nil).
--- @param strip table
--- @param b table
--- @param inset number|nil
function FR.Place(strip, b, inset)
    b:SetShown(inset ~= nil)
    if inset == nil then return end
    b:ClearAllPoints()
    b:SetPoint("RIGHT", strip, "RIGHT", -inset, 0)
end

--- End the strip's info `region` GAP short of the row's leftmost control (FR.Slots' `left`).
--- @param strip table
--- @param region table the info frame or font string
--- @param left number
function FR.PlaceInfo(strip, region, left)
    region:ClearAllPoints()
    region:SetPoint("LEFT", strip, "LEFT", 2, 0)
    region:SetPoint("RIGHT", strip, "RIGHT", -(left + FR.GAP), 0)
end

local function foldTip(b)
    if b.foldState == "collapse" then
        return L["Collapse all"], L["Close every group this tab shows."]
    end
    return L["Expand all"], L["Open every group this tab shows. Collapse all closes them again."]
end

--- Build a strip's Expand all / Collapse all. `apply(collapse)` sets the tab's headers and repaints.
--- @param strip table
--- @param apply function boolean -> nil
--- @return table the button
function FR.BuildFold(strip, apply)
    local b
    b = FR.Button(strip, "chevron-down", L["Expand all"], function()
        if b.foldState then apply(b.foldState == "collapse") end
    end)
    NS.Window.AttachTooltip(b, function() return foldTip(b) end)
    return b
end

--- Paint the toggle for the tab's entries: its word and mark, and off with no header that folds.
--- @param b table FR.BuildFold's
--- @param entries table|nil
function FR.PaintFold(b, entries)
    local state = FR.FoldState(entries)
    b.foldState = state
    if state == "collapse" then
        NS.Window.SetButtonMark(b, L["Collapse all"], "chevron-up")
    else
        NS.Window.SetButtonMark(b, L["Expand all"], "chevron-down")
    end
    b:SetEnabled(state ~= nil)
    b:SetAlpha(state and 1 or 0.5)
end
