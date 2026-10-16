local addonName, NS = ...
-- settings/Pages.lua — the Feed, Comparison, Trade, Messages and Window pages (design spec §12.2).
--
-- Each page is one canvas subcategory drawn by the library's tabbed renderer from the rows whose
-- `page` is its key (settings/SchemaRows.lua), one tab per `group` in declaration order
-- (options-ui-§13). Where a tab has rows the flow engine cannot draw, a host tab keyed by that group
-- takes its place in the strip (settings/PageEditors.lua); the Quality tab closes with its
-- "in force now" readout through an `afterGroup` hook, and Window › Layout's Keep history for has
-- Clear history beside it through `pairWith` (feedback-15 spec §3). Each page's Defaults button
-- resets that page's rows only (options-ui-§13). Registered here, in the order the settings list
-- shows them: General (settings/Panel.lua) before, Profiles (settings/Profiles.lua) after.

local DW       = NS.addon
local Settings = DW.Settings
local Helpers  = Settings.Helpers
local L        = NS.L
local PE       = Settings.PageEditors

--- The pages after General, in list order: key, title, the Defaults tooltip, and the render's
--- host tabs, afterGroup hooks and pairWith partners.
local PAGES = {
    { key = "feed", title = L["Feed"],
      tip = L["Reset the Feed page's settings (quality and filters) to their defaults."],
      afterGroup = { [L["Quality"]] = function(ctx) PE.QualityReadout(ctx) end } },
    { key = "comparison", title = L["Comparison"],
      tip = L["Reset the Comparison page's settings (scoring, every spec's weights and unwanted types) to their defaults."],
      tabs = {
          { key = L["Weights"], render = function(ctx) PE.WeightsTab(ctx) end },
          { key = L["Preferences"], render = function(ctx) PE.PrefsTab(ctx) end },
      } },
    { key = "trade", title = L["Trade"],
      tip = L["Reset the Trade page's settings (loot rules and timers) to their defaults."] },
    { key = "messages", title = L["Messages"],
      tip = L["Reset the Messages page's settings (templates, sending and auto-ask) to their defaults."],
      tabs = { { key = L["Templates"], render = function(ctx, rows) PE.TemplatesTab(ctx, rows) end } } },
    { key = "window", title = L["Window"],
      tip = L["Reset the Window page's settings (columns, layout and toast) to their defaults."],
      pairWith = { [Settings.HISTORY_RETENTION_PATH] = function(ctx, line) PE.ClearHistoryButton(ctx, line) end } },
}

local function builder(page)
    return function(parentCategory)
        local ctx = Helpers.CreatePanel(addonName .. page.key .. "Panel", page.title, {
            pageKey = page.key, defaultsButton = true, defaultsTooltip = page.tip,
        })
        ctx.panel.defaultsOnClick = function() Helpers.RestoreDefaults(page.key, ctx) end
        local opts = { tabs = page.tabs }
        Helpers.SetRenderer(ctx, function(c)
            Helpers.ClearScroll(c)
            Helpers.RenderTabbedSchema(c, page.key, page.afterGroup, page.pairWith, opts)
        end)
        return _G.Settings.RegisterCanvasLayoutSubcategory(parentCategory, ctx.panel, page.title)
    end
end

for _, page in ipairs(PAGES) do
    Helpers.RegisterOptionsPage(page.key, page.title, builder(page))
end
