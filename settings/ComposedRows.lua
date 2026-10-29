local _, NS = ...
-- settings/ComposedRows.lua — the composed blocks of the pages after General (options-ui-§16).
--
-- A block LibKa0s-Options composes is declared once and emitted as ordinary schema rows (the order,
-- the labels, the ranges and the class-color companion the library's), so it is written here, after
-- settings/OptionsSetup.lua has made the Options instance, and not in settings/SchemaRows.lua, which
-- loads before it. General's Master controls are settings/Panel.lua's for the same reason.
--
-- WINDOW › ICONS' BORDER (feedback-21 G11): Helpers.BorderGroup with its Show border toggle, under
-- `icons.` (`borderShow`, `borderStyle`, `borderSize`, `borderColor`, `useClassColorBorder`), as
-- ConsumableMaster's settings/MacroBar.lua builds its button border, then the composer's skin
-- companion `icons.borderStyleFromSkin` (DW-03: `fromSkin = "icon"`, the skin's icon border style
-- and thickness, on by default), then the block's one extra
-- after the mandated four, never among them: `icons.borderQuality`, the item's quality color in
-- place of the swatch (AuraMaster's dispel-colored border is the precedent). PLAYER-SCOPED: the
-- icons are the player's own view of the loot, whoever looted it. Appended after SchemaRows' rows,
-- so the block follows that file's Zoom row on the tab. Each row takes SchemaRows' checks
-- (Settings.Checks; the composer emits none) and the one reaction, modules/IconStyle.lua's Refresh.
-- Style, thickness and the quality toggle are dimmed while Show border is off; the color pair never
-- is (options-ui-§17, anti-pattern #74: the swatch's alpha is read under either mode).
--
-- Without the library the composer is hollow and the block has no rows: modules/IconStyle.lua then
-- reads defaults/Profile.lua's values (feedback-21 H6: a Solid black border, 2 pixels, no class or
-- quality color), which no row can change.

local DW       = NS.addon
local Settings = DW.Settings
local Helpers  = Settings.Helpers
local L        = NS.L
local I        = NS.C.PROFILE.icons
local Check    = Settings.Checks

local function borderOff() return NS.Setting("icons.borderShow") ~= true end
-- The style and thickness rows are dimmed while Show border is off, and while the skin companion
-- (`fromSkin = "icon"`, DW-03) draws them from the skin's icon border family: the composer marks both
-- rows governed by the companion, and the DECORATE below keeps the two reasons in one predicate.
local function styleOff()
    return borderOff() or NS.Setting("icons.borderStyleFromSkin") == true
end

local BORDER = Helpers.BorderGroup{
    page = "window", group = L["Icons"], subgroup = L["Border"],
    show = true, prefix = "icons.",
    -- THE SKIN COMPANION (skinning-§6, LibKa0s-Options compose minor 13): `icons.borderStyleFromSkin`
    -- follows `icon.borderStyle` and `icon.borderSize` (Ka0s Default's are today's Solid 2px). Its
    -- default is defaults/Profile.lua's TRUE (X3); the color is never the skin's (X4).
    fromSkin = "icon",
    defaults = {
        borderShow          = I.borderShow,
        borderStyle         = I.borderStyle,
        borderSize          = I.borderSize,
        borderColor         = I.borderColor,
        useClassColorBorder = I.useClassColorBorder,
        borderStyleFromSkin = I.borderStyleFromSkin,
    },
    classColor = { source = "player" },
    extra = { {
        path = "icons.borderQuality", type = "bool", default = I.borderQuality,
        label = L["Color by item quality"],
        tooltip = L["Draw each icon's border in its item's quality color (green, blue, purple ...) instead of the swatch. The swatch's alpha still applies; an item whose quality is not known keeps the swatch."],
    } },
}

-- Each row's check, its own tooltip where the composer's generic one says less, and its dimming.
local DECORATE = {
    ["icons.borderShow"] = { validate = Check.isBool,
        tooltip = L["Draw a border around every item icon: the drop tables, the cards, the toast, the Offer panel and History."] },
    ["icons.borderStyle"] = { validate = Check.nonEmptyString, disabledIf = styleOff,
        tooltip = L["The border's texture, from LibSharedMedia. Any border another addon registers shows up here too."] },
    ["icons.borderSize"] = { validate = Check.inRange(1, 16), min = 1, disabledIf = styleOff },
    ["icons.borderStyleFromSkin"] = { validate = Check.isBool, disabledIf = borderOff,
        label = L["Use the skin's border"],
        tooltip = L["Draw the border in the skin's icon border style and thickness. The Border style and Border thickness rows are not read while this is on; the color always is."] },
    ["icons.borderColor"] = { validate = Check.isColor,
        tooltip = L["The border's color. Not read while Use class color is on, except for its opacity, which always applies; nor, for an item whose quality is known, while Color by item quality is on."] },
    ["icons.useClassColorBorder"] = { validate = Check.isBool },
    ["icons.borderQuality"] = { validate = Check.isBool, disabledIf = borderOff },
}

for _, row in ipairs(BORDER) do
    for k, v in pairs(DECORATE[row.path] or {}) do row[k] = v end
    row.onChange = Settings.RefreshIcons
end
NS.SchemaRuntime.AddRows(BORDER)
