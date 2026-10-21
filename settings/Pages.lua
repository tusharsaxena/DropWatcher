local addonName, NS = ...
-- settings/Pages.lua — the Situations, Drops, Comparison, Messages, Window and Alerts pages (design
-- spec §12.2; regrouped by feedback-24, which added Situations and Alerts and folded Trade's rows
-- into them and Window's).
--
-- Each page is one canvas subcategory drawn by the library's tabbed renderer from the rows whose
-- `page` is its key (settings/SchemaRows.lua), one tab per `group` in declaration order
-- (options-ui-§13). Where a tab has rows the flow engine cannot draw, a host tab keyed by that group
-- takes its place in the strip (settings/PageEditors.lua); the Situations tab closes with its
-- per-situation table and the Quality tab with its "in force now" readout through `afterGroup`
-- hooks, Drops › Retention's Keep history for has Clear history beside it through `pairWith`
-- (feedback-15 spec §3), and Window › Columns opens with a note through the page's `chrome`. Each
-- page's Defaults button resets that page's rows only (options-ui-§13). Registered here, in the
-- order the settings list shows them: General (settings/Panel.lua) before, Profiles
-- (settings/Profiles.lua) after. The Drops page's key stays `feed`: a page key is no stored path,
-- but it names the page's section in `/dw list`.

local DW       = NS.addon
local Settings = DW.Settings
local Helpers  = Settings.Helpers
local L        = NS.L
local PE       = Settings.PageEditors

--- The pages after General, in list order: key, title, the Defaults tooltip, and the render's
--- host tabs, afterGroup hooks, pairWith partners, `chrome` (drawn under the strip, before the
--- tab's rows) and `beforeClear` (run before each render's ClearScroll).
local PAGES = {
    { key = "situations", title = L["Situations"],
      tip = L["Reset the Situations page's settings (auto-open and every situation's tracking, quality and loot rule) to their defaults."],
      afterGroup = { [L["Situations"]] = function(ctx) PE.SituationTable(ctx) end },
      -- The table is parked first, before ClearScroll hands the placeholder it sits on back to
      -- AceGUI's pool. The placeholder's own OnRelease is the canonical undo (settings/PageEditors.lua);
      -- this park is belt-and-braces.
      beforeClear = function(ctx) PE.ParkSituationTable(ctx) end },
    { key = "feed", title = L["Drops"],
      tip = L["Reset the Drops page's settings (quality, items and how long drops are kept) to their defaults."],
      afterGroup = { [L["Quality"]] = function(ctx) PE.QualityReadout(ctx) end },
      pairWith = { [Settings.HISTORY_RETENTION_PATH] = function(ctx, line) PE.ClearHistoryButton(ctx, line) end } },
    { key = "comparison", title = L["Comparison"],
      tip = L["Reset the Comparison page's settings (scoring, every spec's weights and unwanted types) to their defaults."],
      tabs = {
          { key = L["Weights"], render = function(ctx) PE.WeightsTab(ctx) end },
          { key = L["Unwanted types"], render = function(ctx) PE.PrefsTab(ctx) end },
      } },
    { key = "messages", title = L["Messages"],
      tip = L["Reset the Messages page's settings (sending, auto-ask and templates) to their defaults."],
      tabs = { { key = L["Templates"], render = function(ctx, rows) PE.TemplatesTab(ctx, rows) end } } },
    { key = "window", title = L["Window"],
      tip = L["Reset the Window page's settings (layout, columns, starting view and icons) to their defaults."],
      chrome = function(ctx) PE.ColumnsNote(ctx) end },
    { key = "alerts", title = L["Alerts"],
      tip = L["Reset the Alerts page's settings (toast and upgrade glow) to their defaults."] },
}

local function builder(page)
    return function(parentCategory)
        local ctx = Helpers.CreatePanel(addonName .. page.key .. "Panel", page.title, {
            pageKey = page.key, defaultsButton = true, defaultsTooltip = page.tip,
        })
        ctx.panel.defaultsOnClick = function() Helpers.RestoreDefaults(page.key, ctx) end
        local opts = { tabs = page.tabs, chrome = page.chrome }
        local function render(c)
            if page.beforeClear then page.beforeClear(c) end
            Helpers.ClearScroll(c)
            Helpers.RenderTabbedSchema(c, page.key, page.afterGroup, page.pairWith, opts)
        end
        -- A tab click renders the same way, its park included (`rerender`).
        if page.beforeClear then opts.rerender = render end
        Helpers.SetRenderer(ctx, render)
        return _G.Settings.RegisterCanvasLayoutSubcategory(parentCategory, ctx.panel, page.title)
    end
end

for _, page in ipairs(PAGES) do
    Helpers.RegisterOptionsPage(page.key, page.title, builder(page))
end
