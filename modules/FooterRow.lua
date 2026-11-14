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
-- control takes no room. In compact, Sort is in the Filters menu (modules/CompactChrome.lua),
-- and every button is its mark alone, K.FOOTER_ICON_W wide and centered, its tooltip naming it
-- (FR.SetCompact; feedback-16: three labeled buttons do not fit the compact pane; Scan group joins the
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
FR.START = K.GRIP_ROOM   -- the row's first control's inset: clear of the grip in the corner (RX-09)
FR.STATUS_GAP = 12   -- between the strip's info and the status line after it (RX-09)

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

--- The width the strip's info takes ahead of the status line (pure, RX-09): nothing for no words; its
--- words' width, never past the room the row leaves (so the game cuts it with an ellipsis), or its
--- words' width while no room is known yet; the whole room (or none) when its words cannot be measured.
--- @param text string|nil the info's words
--- @param textW number|nil their one-line width
--- @param room number the strip's width less its left margin and the row
--- @return number
function FR.InfoWidth(text, textW, room)
    if text == nil or text == "" then return 0 end
    if type(textW) ~= "number" then return math.max(room, 0) end
    if room <= 0 then return textW end
    return math.min(textW, room)
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

--- End the strip's info `region` GAP short of the row's leftmost control (FR.Slots' `left`), or, while
--- the status line is on the strip, end that line there with the info ahead of it (FR.FitInfo).
--- @param strip table
--- @param region table the info frame or font string
--- @param left number
function FR.PlaceInfo(strip, region, left)
    strip.dwInfo, strip.dwRowLeft = region, left
    strip.dwFitW = nil
    FR.FitInfo(strip)
end

-- The words a strip's info draws: its own font string, or the one inside its frame (Drops').
local function infoText(region) return region.text or region end

local function measure(fs)
    local fn = fs.GetUnboundedStringWidth or fs.GetStringWidth
    local w = fn and fn(fs)
    return type(w) == "number" and w or nil
end

-- One line, two parts (RX-09): the info as wide as its words from the strip's left, then the status
-- line after it, ending GAP short of the row. Re-anchored only when the info's width moves.
local function fitWithStatus(strip, region, status, rowEnd)
    local fs = infoText(region)
    local text = fs:GetText()
    local room = (strip:GetWidth() or 0) - 2 - rowEnd
    local w = FR.InfoWidth(text, measure(fs), room)
    local gap = (text and text ~= "") and FR.STATUS_GAP or 0
    if strip.dwFitW == w and strip.dwFitGap == gap and status.dwFitOn == strip then return end
    strip.dwFitW, strip.dwFitGap, status.dwFitOn = w, gap, strip
    region:ClearAllPoints()
    region:SetPoint("LEFT", strip, "LEFT", 2, 0)
    region:SetWidth(w)
    status:ClearAllPoints()
    status:SetPoint("LEFT", region, "RIGHT", gap, 0)
    status:SetPoint("RIGHT", strip, "RIGHT", -rowEnd, 0)
end

--- Lay out the strip's info for the words it holds now (each strip's paint calls it after setting them):
--- with the window's status line on the strip (NS.WindowFooter.AnchorStatus), the info as wide as its
--- words and the status after it, cut with an ellipsis when the row is narrow (RX-09); without it,
--- the info spans the row to GAP short of its leftmost control.
--- @param strip table
function FR.FitInfo(strip)
    local region, left = strip.dwInfo, strip.dwRowLeft
    if not region then return end
    local rowEnd, status = left + FR.GAP, strip.dwStatus
    if status then return fitWithStatus(strip, region, status, rowEnd) end
    if strip.dwFitW == false then return end
    strip.dwFitW = false
    region:ClearAllPoints()
    region:SetPoint("LEFT", strip, "LEFT", 2, 0)
    region:SetPoint("RIGHT", strip, "RIGHT", -rowEnd, 0)
end

local function foldTip(b)
    if b.foldState == "collapse" then
        return L["Collapse all"], NS.TipMarks.Row(L["Closes"], L["every group this tab shows"])
    end
    return L["Expand all"], NS.TipMarks.Row(L["Opens"], L["every group this tab shows"]),
        NS.TipMarks.Hint(L["Collapse all closes them again."])
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
