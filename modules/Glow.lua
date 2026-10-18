local _, NS = ...
-- modules/Glow.lua — the upgrade glow on a drop's icon (feedback-21): LibCustomGlow-1.0's effect
-- on the item button of the three surfaces that show someone's drop to you, the full table's Drops
-- row, the compact card and the detail card's header. Not the toast (it only ever shows an upgrade,
-- so a glow there says nothing), History, the Offer panel or the detail card's Replaces rows: they
-- never call Apply.
--
-- TWO GLOWS. `main` for an upgrade for your current spec (`me.verdict == "upgrade"`), `offSpec`
-- for a drop your spec can't use whose off-spec part (NS.OffSpec.Of) is an upgrade. Sidegrades,
-- downgrades and your own drops never glow. Each glow is its own Window › Upgrade glow rows
-- (`glow.main.*`, `glow.offSpec.*`, settings/SchemaRows.lua): on or off, the style (button, proc,
-- pixel, autocast), the color and its Use class color companion, and that style's knobs, the
-- feedback-21 plan's knob table.
--
-- FREE WHEN NOTHING CHANGED. A repaint calls Apply on every painted icon, so Apply remembers on the
-- button what it drew: the kind, the settings generation and the button's width (the proc, button and
-- pixel styles size themselves from it at start). The same three again return at once; anything else stops
-- the old effect and starts the new one. A glow row's write (and a profile switch) calls Refresh,
-- which moves the generation on and repaints the window, so every icon restarts once.
--
-- ON THE BUTTON, JUST ABOVE THE ICON AND ITS BORDER. The effect's frame is a child of the item
-- button at FRAME_LEVEL over it (the library's own default is 8): over the icon's art, which is the
-- button's own texture, over Window › Icons' border (modules/IconStyle.lua's child frame, one level
-- over the button; feedback-21 G11), and no higher than it needs. The item buttons carry no text
-- over the icon; the text beside an icon belongs to the cell or card that holds the button.
--
-- POOLED FRAMES. A pooled row or card repainted for another drop re-applies, so it keeps, changes or
-- loses its glow; StopFree stops the glow on every row or card a repaint left in its pool's free
-- list. A repaint's hide and show of a pooled frame would replay the proc style's opening burst;
-- spendBurst keeps it to the effect's first appearance.
--
-- HEADLESS. Without the library (the suites load no libs/ beyond LibKa0s, or a LibStub miss) Apply
-- still records its decision on the button (`glowKind`) and draws nothing.

NS.Glow = NS.Glow or {}
local Glow = NS.Glow

-- The key every effect is started and stopped under, so another addon's glow on the same frame is
-- never touched (the button style has no key: one per frame).
Glow.KEY = "DropWatcherUpgrade"
Glow.FRAME_LEVEL = 2   -- the icon's border (modules/IconStyle.lua) is at 1
Glow.KINDS = { "main", "offSpec" }

local function lib() return LibStub and LibStub("LibCustomGlow-1.0", true) or nil end

local gen = 1      -- the settings generation: Refresh moves it on
local configs = {} -- kind -> its settings read at `gen` (false while that glow is off)

--- Which glow a drop's icon wears: "main", "offSpec" or nil. Never your own drop.
--- @param drop table|nil a feed record
--- @return string|nil
function Glow.KindOf(drop)
    if type(drop) ~= "table" or drop.isMine then return nil end
    local me = drop.me
    if type(me) ~= "table" then return nil end
    if me.verdict == "upgrade" then return "main" end
    local off = NS.OffSpec.Of(me)
    if off and off.verdict == "upgrade" then return "offSpec" end
    return nil
end

-- A glow's settings as the library takes them: `color` as { r, g, b, a }; false while it is off.
-- The color is resolved here, through its Use class color companion (NS.ResolveColor,
-- options-ui-§17): THE PLAYER'S CLASS, hence the nil unit, since the glow says the drop is an
-- upgrade for you, whoever looted it. The swatch's alpha survives the mode. A write to either row
-- moves the generation on (Refresh), so the icons restart in the new color.
local function read(kind)
    local base = "glow." .. kind .. "."
    if NS.Setting(base .. "enabled") ~= true then return false end
    local cfg = {}
    for key in pairs(NS.C.PROFILE.glow[kind]) do cfg[key] = NS.Setting(base .. key) end
    cfg.color = { NS.ResolveColor(cfg.color, cfg.useClassColor == true, nil) }
    return cfg
end

local function config(kind)
    local cfg = configs[kind]
    if cfg == nil then
        cfg = read(kind)
        configs[kind] = cfg
    end
    return cfg or nil
end

local function num(v, fallback) return type(v) == "number" and v or fallback end

local START = {
    button = function(L, b, c)
        L.ButtonGlow_Start(b, c.color, num(c.buttonFrequency), Glow.FRAME_LEVEL)
    end,
    proc = function(L, b, c)
        L.ProcGlow_Start(b, { color = c.color, startAnim = c.procStartAnim ~= false,
            duration = num(c.procDuration, 1), xOffset = num(c.xOffset, 0), yOffset = num(c.yOffset, 0),
            key = Glow.KEY, frameLevel = Glow.FRAME_LEVEL })
    end,
    pixel = function(L, b, c)
        -- A length of 0 is automatic (the library sizes the lines from the icon); `border` must be
        -- a boolean, since the library draws its dark border for nil.
        local length = num(c.pixelLength, 0)
        L.PixelGlow_Start(b, c.color, num(c.pixelLines), num(c.pixelFrequency), length > 0 and length or nil,
            num(c.pixelThickness), num(c.xOffset, 0), num(c.yOffset, 0), c.pixelBorder == true, Glow.KEY,
            Glow.FRAME_LEVEL)
    end,
    autocast = function(L, b, c)
        L.AutoCastGlow_Start(b, c.color, num(c.autocastParticles), num(c.autocastFrequency),
            num(c.autocastScale), num(c.xOffset, 0), num(c.yOffset, 0), Glow.KEY, Glow.FRAME_LEVEL)
    end,
}

local STOP = {
    button   = function(L, b) L.ButtonGlow_Stop(b) end,
    proc     = function(L, b) L.ProcGlow_Stop(b, Glow.KEY) end,
    pixel    = function(L, b) L.PixelGlow_Stop(b, Glow.KEY) end,
    autocast = function(L, b) L.AutoCastGlow_Stop(b, Glow.KEY) end,
}

-- The proc style's frame replays its opening burst from its own OnShow (the library's
-- SetupProcGlow), and a repaint hides and shows every pooled row and card (NS.Pool.ReleaseAll, then
-- Acquire) and the detail card. Once the button has been on screen with the effect started, the
-- burst has played (or is playing, and finishes into its loop), so the frame is told to show its
-- loop only from then on. A restart is a fresh Start that arms it again. The loop itself still
-- starts over on each re-show: the library stops its animations on hide.
local function spendBurst(b)
    if b.glowStyle ~= "proc" or not b:IsVisible() then return end
    local f = b["_ProcGlow" .. Glow.KEY]
    if type(f) == "table" then f.startAnim = false end
end

--- Stop the glow on an item button and forget it (a no-op on a button that has none).
--- @param b table|nil the item button
function Glow.Stop(b)
    if not (b and b.glowKind) then return end
    local L, stop = lib(), STOP[b.glowStyle]
    if L and stop then stop(L, b) end
    b.glowKind, b.glowStyle, b.glowGen, b.glowW = nil, nil, nil, nil
end

--- Glow an item button for `drop` as its kind and settings say: start, keep, restart or stop the
--- effect. Answers the kind it wears now (nil for none), also left on the button as `glowKind`.
--- @param b table|nil the item button
--- @param drop table|nil the feed record it shows
--- @return string|nil
function Glow.Apply(b, drop)
    if not b then return nil end
    local kind = Glow.KindOf(drop)
    local cfg = kind and config(kind)
    if not cfg then kind = nil end
    if kind == nil then
        Glow.Stop(b)
        return nil
    end
    local w = b:GetWidth()
    if b.glowKind == kind and b.glowGen == gen and b.glowW == w then
        spendBurst(b)
        return kind
    end
    Glow.Stop(b)
    local L, start = lib(), START[cfg.type]
    if L and start then start(L, b, cfg) end
    b.glowKind, b.glowStyle, b.glowGen, b.glowW = kind, cfg.type, gen, w
    spendBurst(b)
    return kind
end

--- Stop the glow on every object a repaint left in `pool`'s free list (NS.Pool's array shape).
--- @param pool table
--- @param buttonOf function object -> its item button
function Glow.StopFree(pool, buttonOf)
    for _, o in ipairs(pool and pool.free or {}) do Glow.Stop(buttonOf(o)) end
end

--- The glow settings changed (a glow row's write, a profile switch): every icon restarts with the
--- new settings on its next paint, and the window repaints now.
function Glow.Refresh()
    gen = gen + 1
    configs = {}
    local W = NS.Window
    if W and W.IsShown and W.IsShown() then W.Refresh() end
end
