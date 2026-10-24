local addonName, NS = ...
-- settings/Panel.lua — the landing page and the General page.
--
-- The landing page is the library's BuildLandingPage (logo, TOC notes, the slash command list) and
-- draws no tab strip (options-ui-§5/§13). The General page renders through the tabbed renderer, its
-- first tab `Master controls`, composed from one declaration with the canonical rows in canonical
-- order (options-ui-§15): the window is positionable, so every frame row is present, plus the
-- Minimap button and Test mode rows. The General page's second tab, `Simulator`, is the simulator's
-- step delay (settings/SchemaRows.lua), and its last, `Keybindings`, is LibKa0s's key editor
-- (options-ui-§20); When to show moved to the Situations page in feedback-24, and that page into Drops ›
-- Situations in item 020 (settings/Pages.lua).
-- The design spec's other pages (§12.2) are DW-41's.

local DW       = NS.addon
local Settings = DW.Settings
local Helpers  = Settings.Helpers
local C        = NS.C
local L        = NS.L

-- The landing page's logo: the larger render of the launcher logo, in the same folder.
local MAIN_LOGO_TEXTURE = ("Interface\\AddOns\\%s\\media\\logos\\%s.logo.tga"):format(addonName, addonName:lower())

-- The landing page body, through the library's builder (options-ui-§5): logo at the library's
-- 300x300 default, the TOC notes line, then the Slash Commands heading and one row per NS.COMMANDS
-- entry. The builder keeps one texture per frame and hides it in the group's OnRelease
-- (options-ui-§19).
function Helpers.BuildMainContent(ctx)
    Helpers.BuildLandingPage(ctx, {
        logo     = MAIN_LOGO_TEXTURE,
        notes    = function() return NS.Meta("Notes") or "" end,
        sections = { {
            heading = L["Slash Commands"],
            rows    = function()
                local Sl = NS.SlashCommands
                return Sl and Sl:LandingRows() or {}
            end,
        } },
    })
end

local function showResetPopup()
    Settings.EnsureResetPopup()
    StaticPopup_Show(Settings.RESET_POPUP)
end

local MASTER_ROWS, MASTER_TAIL = Helpers.MasterControls{
    prefix           = "",
    page             = "general",
    addonName        = NS.BRAND,
    debugConsolePath = "state.debugConsole",
    minimapPath      = Settings.MINIMAP_PATH,
    testModePath     = "state.testMode",
    defaults         = {
        enabled = C.PROFILE.enabled, visibility = C.PROFILE.visibility, scale = C.PROFILE.scale,
        alpha = C.PROFILE.alpha, locked = C.PROFILE.locked, debugConsole = false,
    },
    onResetPosition  = function() if NS.Window then NS.Window.ResetPosition() end end,
    onResetAll       = showResetPopup,
}

-- Each composed row reacts the way every other surface's write to the same path does.
for _, row in ipairs(MASTER_ROWS) do
    row.onChange = Settings.REACTIONS[row.path]
end
Settings.StampClosureRows(MASTER_ROWS)
NS.SchemaRuntime.AddRows(MASTER_ROWS, 1)

-- Master controls closes with the composer's reset pair.
local AFTER_GROUP = {}
if Helpers.MASTER_GROUP then AFTER_GROUP[Helpers.MASTER_GROUP] = MASTER_TAIL end

-- The General page's render, a tab click's included (`rerender`). Its last tab is Keybindings
-- (options-ui-§20): the library's host tab over NS.BINDINGS (core/LauncherSetup.lua), with no
-- `before`, so it follows every schema tab. The stub's KeybindingsTab answers nil: no tab.
local function renderGeneral(c)
    Helpers.ClearScroll(c)
    Helpers.RenderTabbedSchema(c, "general", AFTER_GROUP, nil, {
        rerender = renderGeneral,
        tabs     = { Helpers.KeybindingsTab({ bindings = NS.BINDINGS }) },
    })
end

-- The General page's header Defaults is the global reset (showResetPopup), so its tooltip is the
-- very text Reset all settings carries (options-ui-§12, U-04), read from the library, then its
-- "Key bindings are not changed." (options-ui-§20): keys are the game's, not a setting, so no reset
-- reaches them. No host wording around it (item 020, DRO-L-new4).
local function generalDefaultsTooltip()
    return Helpers.ResetAllTooltip(Helpers.KEYBINDS_UNCHANGED)
end

local function buildGeneralPage(parentCategory)
    local ctx = Helpers.CreatePanel(addonName .. "GeneralPanel", L["General"], {
        pageKey         = "general",
        defaultsButton  = true,
        defaultsTooltip = generalDefaultsTooltip(),
    })
    ctx.panel.defaultsOnClick = showResetPopup
    Helpers.SetRenderer(ctx, renderGeneral)
    return _G.Settings.RegisterCanvasLayoutSubcategory(parentCategory, ctx.panel, L["General"])
end

Helpers.RegisterOptionsPage("general", L["General"], buildGeneralPage)

--- Register the settings category. Idempotent; called from OnEnable and from `/dw config`.
function Settings.Register()
    if DW._settingsRegistered or not _G.Settings
       or not _G.Settings.RegisterCanvasLayoutCategory
       or not _G.Settings.RegisterCanvasLayoutSubcategory then
        return
    end
    Helpers.CreateOptionsPanel()
    DW._settingsRegistered = true
end
