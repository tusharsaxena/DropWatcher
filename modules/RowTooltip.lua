local _, NS = ...
-- modules/RowTooltip.lua — the addon's one seam onto LibKa0s-Tooltip-1.0 (LibKa0s#92, AD-92-DW;
-- WowAddonStandards standalone-windows, *Tooltip placement*): where every tooltip the addon places
-- itself opens. Each one is a BODY element's or a CHROME element's.
--
-- BODY (RT.Place, RT.PlaceOrFallback): a table row's item tooltip, every cell's reason tooltip, the
-- Ask, Offer and Announce-row buttons, the group headers, the History rows and cards, the detail
-- card's lines and chips, the column labels, the Offer and Rolls panels' rows, the toast and a roll
-- card. The library's PlaceBeside puts the tooltip beside the WINDOW GROUP, outside its outer edge:
-- its TOPLEFT a TIP_GAP right of the group's right edge, else its TOPRIGHT a TIP_GAP left of its
-- left edge, its top level with the ROW's top (the nearest ancestor marked `tipRow`: a drop row, a
-- group header, a compact card, an Offer panel candidate; else the hovered frame), clamped on
-- screen. With room on neither side, it attaches above the row (the library's fallback).
--
-- THE WINDOW GROUP (RT.GroupOf). The outermost frame under UIParent the row sits in (the window,
-- the toast, a roll card), and every frame that frame names in `tipDocks` (the Offer panel `offer`
-- and the Rolls panel `rolls`) while it is shown and docked beside it (`dock` right or left). A
-- docked panel's own rows prefer its side away from the window (the library's companion side), and
-- go past the window when that side has no room. A panel floating over the window is inside the
-- window's span, so it takes no room.
--
-- FLUSH FIRST (AF-DW-TIP, the owner's img-15 and img-16 of 2026-11-19). A WINDOW row's tooltip sits
-- flush beside the window itself, the body rule on the window alone (right when it fits, else left,
-- TIP_GAP off), and goes past the docked panels only when that flush rectangle would overlap one of
-- them (RT.FlushOverlaps). A Trade tooltip low on the window clears a short Rolls panel and stays
-- beside the window; one level with the panel goes past it, as before. A panel that cannot be
-- measured takes no room, as the library's span ignores it; a flush spot that cannot be predicted
-- (no screen, no tooltip size) keeps the whole group.
--
-- CHROME (RT.PlaceChrome): a title-bar control, a mode strip, a tab, a filter-bar control, a footer
-- line or mark, and the Edit message box's Send and Cancel (a modal's controls). The library's
-- PlaceAttached centers the tooltip on the control, TIP_GAP above it, below only when the screen
-- has no room above.
--
-- NEVER THE CURSOR. Every placement is applied after Show (so the tooltip's real size is measured)
-- and the tooltip is owned at ANCHOR_NONE. When the library is absent or a geometry read is not a
-- plain number, the fallback attaches the tooltip centered above the element (BOTTOM on its TOP,
-- TIP_GAP up), as the library's own sites do; never at the pointer, never at a corner.
--
-- THE KIND ROWS (issue #13, categories design spec §6.1). Under the game's own lines, an item
-- tooltip names a token's or a collectible's kind and, for a collectible, its collection verdict
-- now (RT.AddKindRows: NS.CollectCells.KindRows over the item's facts, NS.ItemFacts.Get). Gear
-- gets none: the game's tooltip names its kind.
--
-- THE ROLL ROW (Forever port design §5.3). Under them, a rolled drop's summary line
-- (RT.AddRollRow: NS.RollCells.Summary over the drop's or the pending item's roll table).

NS.RowTooltip = NS.RowTooltip or {}
local RT = NS.RowTooltip
local K  = NS.Constants.WINDOW

-- The placement major, read at call time (a suite's spy and a newer copy both reach it), or nil.
local function tipLib()
    local Tip = LibStub and LibStub("LibKa0s-Tooltip-1.0", true)
    if type(Tip) == "table" and type(Tip.PlaceBeside) == "function" and type(Tip.PlaceAttached) == "function" then
        return Tip
    end
    return nil
end

local function parentOf(frame)
    local p = frame.GetParent and frame:GetParent()
    if type(p) ~= "table" or p == frame or p == UIParent then return nil end
    return p
end

local function isRow(f) return f.tipRow == true end

--- The row `owner` sits in: its nearest ancestor marked `tipRow`, else `owner` itself.
--- @param owner table the hovered frame
--- @return table
function RT.RowOf(owner)
    local f = owner
    for _ = 1, 32 do
        if isRow(f) then return f end
        f = parentOf(f)
        if not f then return owner end
    end
    return owner
end

-- The outermost frame under UIParent `f` sits in (`f` itself when it is one).
local function outerOf(f)
    for _ = 1, 32 do
        local p = parentOf(f)
        if not p then return f end
        f = p
    end
    return f
end

local function dockedBeside(panel)
    return panel.dock == "right" or panel.dock == "left"
end

--- The window group `element` sits in, as LibKa0s-Tooltip-1.0's PlaceBeside reads one:
--- `{ main, panels }`, `main` the outermost frame under UIParent and `panels` every frame it names
--- in `tipDocks` that is docked beside it (the library keeps the shown ones), in name order.
--- @param element table
--- @return table
function RT.GroupOf(element)
    local main = outerOf(element)
    local names, panels = {}, {}
    for name, panel in pairs(main.tipDocks or {}) do
        if type(panel) == "table" and panel ~= main and dockedBeside(panel) then names[#names + 1] = name end
    end
    table.sort(names)
    for _, name in ipairs(names) do panels[#panels + 1] = main.tipDocks[name] end
    return { main = main, panels = panels }
end

-- A plain, non-secret number, or nil (the library's guard: no arithmetic touches a secret).
local function num(v)
    if type(v) ~= "number" or NS.Compat.IsSecret(v) then return nil end
    return v
end

local function read(frame, method)
    local fn = type(frame) == "table" and frame[method]
    if type(fn) ~= "function" then return nil end
    return num(fn(frame))
end

-- A frame's left, bottom, right and top in screen units (its own times its effective scale), or nil.
local function screenRect(frame)
    local l, b, r, t = read(frame, "GetLeft"), read(frame, "GetBottom"), read(frame, "GetRight"), read(frame, "GetTop")
    if not (l and b and r and t) then return nil end
    local s = read(frame, "GetEffectiveScale") or 1
    return l * s, b * s, r * s, t * s
end

-- The docked panel of `group` that `row` sits in, or nil (a window row).
local function hostPanel(row, group)
    local set = {}
    for _, p in ipairs(group.panels) do set[p] = true end
    local f = row
    for _ = 1, 32 do
        if set[f] then return f end
        f = parentOf(f)
        if not f then return nil end
    end
    return nil
end

local function isShown(frame)
    local fn = frame.IsShown
    return type(fn) ~= "function" or fn(frame) and true or false
end

--- Whether `tip` placed flush beside the window `group.main` (the body rule on the window alone:
--- right when it fits, else left, TIP_GAP off, its top level with `row`'s, clamped on screen) would
--- overlap a shown docked panel of `group`. True too when the flush spot cannot be predicted (no
--- screen, no tooltip size, an unreadable window or row, no room beside the window), so the caller
--- keeps the whole group; a panel that cannot be measured takes no room.
--- @param tip table a GameTooltip, shown
--- @param row table the row the hovered frame sits in
--- @param group table RT.GroupOf(row)
--- @return boolean
function RT.FlushOverlaps(tip, row, group)
    local ui = UIParent
    local uiS = read(ui, "GetEffectiveScale") or 1
    local sw, sh = read(ui, "GetWidth"), read(ui, "GetHeight")
    local tw, th = read(tip, "GetWidth"), read(tip, "GetHeight")
    local ml, _, mr = screenRect(group.main)
    local _, _, _, rt = screenRect(row)
    if not (sw and sh and tw and th and ml and rt) then return true end
    sw, sh = sw * uiS, sh * uiS
    local ts = read(tip, "GetEffectiveScale") or 1
    tw, th = tw * ts, th * ts
    local gap = K.TIP_GAP
    local l
    if mr + gap + tw <= sw then l = mr + gap elseif ml - gap - tw >= 0 then l = ml - gap - tw else return true end
    local top = rt
    if top - th < 0 then top = th end
    if top > sh then top = sh end
    local r, b = l + tw, top - th
    for _, p in ipairs(group.panels) do
        if isShown(p) then
            local pl, pb, pr, pt = screenRect(p)
            if pl and l < pr and pl < r and b < pt and pb < top then return true end
        end
    end
    return false
end

--- The main window's group, for a host the library places for (the Insights charts' `host.group`,
--- core/ChartsSetup.lua): RT.GroupOf the window, or nil before it is built (the library then reads
--- the group the hovered mark sits in).
--- @return table|nil
function RT.WindowGroup()
    local win = NS.Window and NS.Window.Frame and NS.Window.Frame()
    return win and RT.GroupOf(win) or nil
end

--- The body rule on a shown tooltip, its top level with the row's top (LibKa0s-Tooltip-1.0's
--- PlaceBeside): a window row's flush beside the window unless that would overlap a docked panel
--- (RT.FlushOverlaps), else, and for a panel's own row, beside the whole window group. Answers
--- `right` or `left`, the library's fallback `above` or `below` (no room beside the group), or nil
--- with nothing placed (no library, or geometry that cannot be read; the caller attaches it).
--- @param tip table a GameTooltip, shown
--- @param owner table the hovered frame
--- @return string|nil
function RT.Place(tip, owner)
    local Tip = tipLib()
    if not Tip then return nil end
    local row = RT.RowOf(owner)
    local group = RT.GroupOf(row)
    if #group.panels > 0 and not hostPanel(row, group) and not RT.FlushOverlaps(tip, row, group) then
        return Tip.PlaceBeside(tip, row, { main = group.main, panels = {} })
    end
    return Tip.PlaceBeside(tip, row, group)
end

-- The fallback of both rules: centered above `element`, TIP_GAP up, by a relative point.
local function attachAbove(tip, element)
    tip:ClearAllPoints()
    tip:SetPoint("BOTTOM", element, "TOP", 0, K.TIP_GAP)
    return "attached"
end

--- The chrome rule on a shown tooltip: centered on `owner`, above it, below only when the screen
--- has no room above (LibKa0s-Tooltip-1.0's PlaceAttached); else (no library, unreadable
--- geometry) attached above it. Answers `above`, `below` or `attached`.
--- @param tip table a GameTooltip, shown
--- @param owner table the hovered control
--- @return string
function RT.PlaceChrome(tip, owner)
    local Tip = tipLib()
    local side = Tip and Tip.PlaceAttached(tip, owner)
    if side then return side end
    return attachAbove(tip, owner)
end

--- Add the item's Kind row and its collection row under the game's lines (the item tooltip, before
--- its hint and Show). Nothing for gear, a link with no facts yet, or a tooltip with no AddLine.
--- @param tip table a GameTooltip
--- @param link string|nil the item's link
--- @return number the rows added
function RT.AddKindRows(tip, link)
    local f = type(link) == "string" and NS.ItemFacts and NS.ItemFacts.Get(link) or nil
    local lines = NS.CollectCells.KindRows(f)
    if not (tip and tip.AddLine) then return 0 end
    local r, g, b = NS.Skin.Color("gtip.value")   -- the skin's tooltip value color, as every cell tip's lines
    for _, line in ipairs(lines) do tip:AddLine(line, r, g, b, true) end
    return #lines
end

--- Add a drop's roll summary under the game's lines (Forever port design §5.3): `Rolls: Won by
--- Name (Need 87)` for a resolved drop with a roll table (`button.dropId`, the feed's `rec.roll`),
--- or the live summary for a pending item (`button.pendingId`, NS.Pending). Nothing while
--- `rolls.show` is off, with no table, or for a tooltip with no AddLine.
--- @param tip table a GameTooltip
--- @param button table the hovered item button
--- @return number the rows added
function RT.AddRollRow(tip, button)
    if not (tip and tip.AddLine and type(button) == "table") or NS.Setting("rolls.show") == false then return 0 end
    local src = button.pendingId and NS.Pending.Get(button.pendingId)
        or button.dropId and NS.LootFeed.Get(button.dropId) or nil
    local roll = type(src) == "table" and src.roll or nil
    if type(roll) ~= "table" then return 0 end
    local s = NS.RollCells.Summary(roll, NS.Compat.LootHistoryNow(), src.state, src.rollID)
    local r, g, b = NS.Skin.Color("gtip.value")
    tip:AddLine(NS.TipMarks.Row(NS.L["Rolls"], s.text), r, g, b, true)
    return 1
end

--- Place a shown body tooltip: RT.Place, else (no library, unreadable geometry) attached above the
--- row the hovered frame sits in. Answers what RT.Place did, or `attached`.
--- @param tip table a GameTooltip, shown
--- @param owner table the hovered frame
--- @return string
function RT.PlaceOrFallback(tip, owner)
    local side = RT.Place(tip, owner)
    if side then return side end
    return attachAbove(tip, RT.RowOf(owner))
end
