local _, NS = ...
-- modules/IconStyle.lua — the one look of every item icon the addon draws (feedback-21 G11):
-- Window › Icons' zoom and border, applied to each item button NS.WindowGroup.ItemButton builds
-- (the Drops rows and their Me and Them gear icons, the compact cards, the detail card's header and
-- Replaces rows, the toast, History, the Offer panel). Item buttons alone: the title bar's, the
-- footers' and the cards' action buttons draw an icon of the media library's, not an item's.
--
-- THE ZOOM crops the texture symmetrically (KickCD's shape, `icons.zoom` 0 to 0.25 off each side):
-- a little trims the dark edge baked into most item icons. 0 is the whole texture, as the icons
-- were drawn before G11; 0.1 is the default (feedback-21 H6).
--
-- THE BORDER is LibKa0s-Options' composed block (options-ui-§16; settings/ComposedRows.lua): Show
-- border, Border style (a LibSharedMedia border), Border thickness, Border color and its Use class
-- color companion (options-ui-§17: THE PLAYER'S CLASS, hence the nil unit, since the icons are the
-- player's own view of the loot), then the block's one extra, Color by item quality: on, the border
-- takes the item's quality color in place of the swatch, the swatch's alpha kept, as AuraMaster's
-- border takes a dispel color. The quality is the link's (NS.ItemRead.QualityOf: the client's answer,
-- else the link's color), in ITEM_QUALITY_COLORS, else the link's own color code: TipMarks.ItemName's
-- source. An item with no quality known keeps the swatch. Off by default; the border is on, Solid,
-- black, 2 pixels (feedback-21 H6).
--
-- SOLID, the default style, is a flat edge: the client's WHITE8X8 stretched to the border's
-- thickness and tinted by its color. It is no file this addon ships, so this file registers it with
-- LibSharedMedia at load under AuraMaster's name, "Solid" (the first registration of a name wins,
-- and AuraMaster's is the same texture), and the Border style dropdown offers it. Without the media
-- library the name still draws the flat edge.
--
-- A CHILD FRAME, MADE ON FIRST USE. The border is a BackdropTemplate frame over the button (a frame
-- of its own, so the edge draws over the icon's art, which is the button's texture), made the first
-- time a border is shown; a button that never shows one never makes it. A child frame sits one
-- level over its parent, so the upgrade glow (modules/Glow.lua) starts its effect two levels over
-- the button, over the border.
--
-- FREE WHEN NOTHING CHANGED. SetItem calls Apply on every repaint of every icon, so Apply remembers
-- on the button the settings generation it drew and, while the quality colors the border, the link
-- it drew it for. The same again return at once. A write to any Window › Icons row (and a profile
-- switch) calls Refresh, which moves the generation on and walks every item button made so far,
-- pooled or not, shown or not, so each takes the new look now.
--
-- THE SKIN'S BORDER (skinning-§6; DW-03 of the 2026-10-29 skinning rollout). While the block's
-- skin companion `icons.borderStyleFromSkin` is on (by default, X3, and after core/Database.lua's
-- one-time step 10, O2), the style and the thickness are the skin's icon border family
-- (`icon.borderStyle`, `icon.borderSize`, read through NS.Skin.Resolve), Ka0s Default's being the
-- look above, Solid 2px. Only those two follow (X4): the color, its class and quality companions,
-- Show border and the zoom stay the player's. A style of "None" draws no edge. A skin switch is a
-- Refresh (the OnLooksChanged listener at the end of this file). The degraded facade answers no
-- string token, so without the library the stored picks draw.
--
-- HEADLESS. The decision is recorded on the button (`iconZoom`, and `iconBorder`, the color drawn,
-- nil for none) whatever the frame answers.

NS.IconStyle = NS.IconStyle or {}
local IS = NS.IconStyle

IS.ZOOM_MAX = 0.25
-- A border style no addon registers any more (a profile can name one a removed addon supplied)
-- draws the tooltip's edge, as KickCD's and ConsumableMaster's do.
IS.BORDER_FALLBACK = "Interface\\Tooltips\\UI-Tooltip-Border"
-- The flat edge (SOLID above): its LibSharedMedia name and the client texture it draws.
IS.SOLID = "Solid"
IS.SOLID_EDGE = "Interface\\Buttons\\WHITE8X8"

do
    local LSM = LibStub and LibStub("LibSharedMedia-3.0", true)
    if LSM and LSM.Register then LSM:Register("border", IS.SOLID, IS.SOLID_EDGE) end
end

local gen = 1                                     -- the settings generation: Refresh moves it on
local cfg                                         -- the settings read at `gen`
local made = setmetatable({}, { __mode = "k" })   -- every item button styled so far

-- A Window › Icons value through the seam, else its defaults/Profile.lua value: a load without the
-- composer has no border rows to answer for.
local function setting(key)
    local v = NS.Setting("icons." .. key)
    if v == nil then v = NS.C.PROFILE.icons[key] end
    return v
end

local function borderTexture(name)
    local LSM = LibStub and LibStub("LibSharedMedia-3.0", true)
    local path = LSM and LSM.Fetch and LSM:Fetch("border", name, true)
    if not path and name == IS.SOLID then path = IS.SOLID_EDGE end
    return path or IS.BORDER_FALLBACK
end

--- A border setting as drawn: the skin's token `kind` while `fromSkin` is on (or the stored value is
--- the FROM_SKIN sentinel), else the stored value. A token the facade cannot answer (the degraded
--- facade carries no string token) keeps the stored value, so nothing draws blank; a stored sentinel
--- with no token answers the shipped default. ConsumableMaster's BB.Follow, the same ladder.
--- @param kind string the token (`icon.borderStyle`, `icon.borderSize`)
--- @param key string the Window › Icons key the stored value is read from
--- @param fromSkin boolean|nil the companion
function IS.Follow(kind, key, fromSkin)
    local stored = setting(key)
    local S = NS.Skin
    local v = S and S.Resolve and S.Resolve(kind, stored, fromSkin)
    if v == nil or v == (S and S.FROM_SKIN) then
        if S and stored == S.FROM_SKIN then return NS.C.PROFILE.icons[key] end
        return stored
    end
    return v
end

local function read()
    local zoom = tonumber(setting("zoom")) or 0
    if zoom < 0 then zoom = 0 elseif zoom > IS.ZOOM_MAX then zoom = IS.ZOOM_MAX end
    local c = { zoom = zoom, show = setting("borderShow") == true }
    if not c.show then return c end
    local fromSkin = setting("borderStyleFromSkin") == true
    local style = IS.Follow("icon.borderStyle", "borderStyle", fromSkin)
    c.style = style
    if style == "None" then c.show = false; return c end   -- the skin's "no edge"
    -- One backdrop table for every button: SetBackdrop keeps it and nothing here writes to it.
    c.backdrop = { edgeFile = borderTexture(style),
                   edgeSize = math.max(1, tonumber(IS.Follow("icon.borderSize", "borderSize", fromSkin)) or 1) }
    c.r, c.g, c.b, c.a = NS.ResolveColor(setting("borderColor"), setting("useClassColorBorder") == true, nil)
    c.quality = setting("borderQuality") == true
    return c
end

local function config()
    if cfg == nil then cfg = read() end
    return cfg
end

--- An item link's quality color, TipMarks.ItemName's source: the quality's NS.QualityColor (the
--- skin's q.* token, else ITEM_QUALITY_COLORS), else the link's own `|cAARRGGBB` code. Nil when
--- neither answers.
--- @param link string|nil
--- @return number|nil, number|nil, number|nil
function IS.QualityColor(link)
    if type(link) ~= "string" then return nil end
    local q = NS.ItemRead.QualityOf(link)
    local qr, qg, qb
    if q ~= nil then qr, qg, qb = NS.QualityColor(q) end   -- the skin's q.*, else the client's (E4)
    if type(qr) == "number" then return qr, qg, qb end
    local r, g, b = link:match("^|c%x%x(%x%x)(%x%x)(%x%x)")
    if not r then return nil end
    return tonumber(r, 16) / 255, tonumber(g, 16) / 255, tonumber(b, 16) / 255
end

local function paintBorder(b, c, link)
    if not c.show then
        if b.iconBorderFrame then b.iconBorderFrame:Hide() end
        b.iconBorder = nil
        return
    end
    local f = b.iconBorderFrame
    if not f then
        f = CreateFrame("Frame", nil, b, "BackdropTemplate")
        f:SetAllPoints(b)
        -- Explicit, never the CreateFrame default, so the glow at EFFECT stays over it.
        f:SetFrameLevel(b:GetFrameLevel() + NS.Constants.LAYERS.LEVEL.BORDER)
        b.iconBorderFrame = f
    end
    local r, g, bl = c.r, c.g, c.b
    if c.quality then
        local qr, qg, qb = IS.QualityColor(link)
        if qr then r, g, bl = qr, qg, qb end
    end
    f:SetBackdrop(c.backdrop)
    f:SetBackdropBorderColor(r, g, bl, c.a)
    f:Show()
    b.iconBorder = { r, g, bl, c.a }
end

--- Give an item button the Window › Icons look for `link` (its zoom, its border, the border's color);
--- a no-op when nothing it reads changed since the last call.
--- @param b table|nil the item button (its icon texture `b.art`)
--- @param link string|nil the item it shows
function IS.Apply(b, link)
    if not (b and b.art) then return end
    made[b] = true
    local c = config()
    local q = c.quality and link or nil
    if b.iconGen == gen and b.iconLink == q then return end
    b.iconGen, b.iconLink = gen, q
    local z = c.zoom
    b.art:SetTexCoord(z, 1 - z, z, 1 - z)
    b.iconZoom = z
    paintBorder(b, c, link)
end

--- The Window › Icons settings changed (a row's write, a profile switch): every item button made so
--- far takes the new look now, the ones in a pool's free list too.
function IS.Refresh()
    gen = gen + 1
    cfg = nil
    for b in pairs(made) do IS.Apply(b, b.link) end
end

-- A skin switch: the border's style and thickness may be the skin's, so every item button made so
-- far takes the new skin's now (after the library's repaint; the degraded facade never fires).
if NS.Skin and NS.Skin.OnLooksChanged then NS.Skin.OnLooksChanged(function() IS.Refresh() end) end
