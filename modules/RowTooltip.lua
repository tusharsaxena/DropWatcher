local _, NS = ...
-- modules/RowTooltip.lua — the one placement for every tooltip raised from a table row
-- (feedback-3 spec §2, DW-B2), on all three tabs and the Offer panel: the item tooltip (DW-A2's,
-- moved here from modules/WindowGroup.lua), every cell's reason tooltip, the Ask, Offer and Announce
-- buttons, the group headers and the History rows.
--
-- AT THE ROW'S TOP RIGHT, LIKE KA0S LOOT HISTORY. Loot History anchors its row tooltip with
-- ANCHOR_RIGHT on a row as wide as its window (../LootHistory/modules/BrowserTable.lua, the row's
-- OnEnter), so the tooltip rises from the row's top-right corner, just outside the window. Here the
-- tooltip's BOTTOMLEFT sits at the row's top, on the right edge of the frame the row sits in, a
-- TIP_GAP outside it; when the screen has no room on the right, its BOTTOMRIGHT sits at the row's
-- top on that frame's left edge. The row is the nearest ancestor marked `tipRow` (a drop row, a
-- group header, an Offer panel candidate), else the hovered frame itself, so a cell, a button or an
-- item icon inside a row all open at the same corner.
--
-- THE FRAME BESIDE. The nearest ancestor marked `tipHost` (the Offer panel, docked beside the
-- window), else the outermost one under UIParent (the window, the toast). With the Offer panel
-- docked beside the window (its `dock` right or left, shown), the two count as one span (M10
-- review, FB2-10): the tooltip goes beside the pair, never over the panel from a window row nor
-- over the window from a panel row. The window names its panel as `tipDocked`.
--
-- Placed by hand after Show, so the room is measured on the tooltip's real width, at each frame's
-- effective scale. No client call: the frames' own geometry and UIParent's width.

NS.RowTooltip = NS.RowTooltip or {}
local RT = NS.RowTooltip
local K  = NS.Constants.WINDOW

local function num(v) return type(v) == "number" and v or nil end

-- A geometry read, a number or nil (an unplaced frame answers nil).
local function geom(frame, method)
    local fn = frame and frame[method]
    return fn and num(fn(frame)) or nil
end

local function scaleOf(frame) return geom(frame, "GetEffectiveScale") or 1 end

local function parentOf(frame)
    local p = frame.GetParent and frame:GetParent()
    if type(p) ~= "table" or p == frame or p == UIParent then return nil end
    return p
end

-- The nearest ancestor (or `owner`) that answers `test`, else the outermost one under UIParent
-- when `outermost` is set, else nil.
local function ancestor(owner, test, outermost)
    local f = owner
    for _ = 1, 32 do
        if test(f) then return f end
        local p = parentOf(f)
        if not p then return outermost and f or nil end
        f = p
    end
    return outermost and f or nil
end

local function isHost(f) return f.tipHost == true end
local function isRow(f) return f.tipRow == true end

-- A frame's left and right edges in screen pixels, or nil when it is unplaced.
local function edgesPx(f)
    local l, r, s = geom(f, "GetLeft"), geom(f, "GetRight"), scaleOf(f)
    if not (l and r and geom(f, "GetTop")) then return nil end
    return l * s, r * s
end

local function dockedBeside(panel)
    return panel.dock == "right" or panel.dock == "left"
end

-- The frame docked beside `host` that the tooltip must not cover: the window's shown, docked panel,
-- or, for a docked panel, the window it hangs off.
local function companionOf(host)
    local panel = host.tipDocked
    if panel then
        local shown = panel.IsShown and panel:IsShown()
        return (shown and dockedBeside(panel)) and panel or nil
    end
    if host.tipHost and dockedBeside(host) then return parentOf(host) end
    return nil
end

-- The span the tooltip goes beside, in screen pixels, and the frame at each end of it.
local function spanOf(host)
    local l, r = edgesPx(host)
    local outL, outR = host, host
    local c = companionOf(host)
    local cl, cr
    if c then cl, cr = edgesPx(c) end
    if cl and cl < l then l, outL = cl, c end
    if cr and cr > r then r, outR = cr, c end
    return l, r, outL, outR
end

-- Which side of the span the tooltip goes, in screen pixels: right when it fits, else left.
local function sideOf(l, r, tip, gap)
    local ts = scaleOf(tip)
    local screen = geom(UIParent, "GetWidth")
    local side = NS.MineCells.DockSide(l, r, (geom(tip, "GetWidth") or 0) * ts,
        screen and screen * scaleOf(UIParent), gap * ts)
    return side == "right" and "right" or "left"
end

--- The row `owner` sits in: its nearest ancestor marked `tipRow`, else `owner` itself.
--- @param owner table the hovered frame
--- @return table
function RT.RowOf(owner)
    return ancestor(owner, isRow, false) or owner
end

--- Place a shown tooltip at the top right of the row `owner` sits in, just outside the frame the row
--- sits in (the window, a docked panel, and the one docked beside it), or at its top left when the
--- screen has no room on the right. Measured after Show (the tooltip's width), at each frame's
--- effective scale. Answers `right` or `left`, or nil when the geometry is unknown (nothing is
--- placed; the caller anchors it).
--- @param tip table a GameTooltip, shown
--- @param owner table the hovered frame
--- @return string|nil
function RT.Place(tip, owner)
    local host = ancestor(owner, isHost, true)
    local row = RT.RowOf(owner)
    local rowTop = geom(row, "GetTop")
    if not (rowTop and edgesPx(host)) then return nil end
    local gap = K.TIP_GAP
    local l, r, outL, outR = spanOf(host)
    local side = sideOf(l, r, tip, gap)
    local anchor = side == "right" and outR or outL
    local dy = (rowTop * scaleOf(row) - geom(anchor, "GetTop") * scaleOf(anchor)) / scaleOf(tip)
    tip:ClearAllPoints()
    if side == "right" then
        tip:SetPoint("BOTTOMLEFT", anchor, "TOPRIGHT", gap, dy)
    else
        tip:SetPoint("BOTTOMRIGHT", anchor, "TOPLEFT", -gap, dy)
    end
    return side
end

--- Place a shown tooltip for a row: RT.Place, else (unknown geometry) on the hovered frame's top
--- right, ANCHOR_RIGHT's place.
--- @param tip table a GameTooltip, shown
--- @param owner table the hovered frame
--- @return string
function RT.PlaceOrFallback(tip, owner)
    local side = RT.Place(tip, owner)
    if side then return side end
    tip:ClearAllPoints()
    tip:SetPoint("BOTTOMLEFT", owner, "TOPRIGHT", 0, 0)
    return "owner"
end
