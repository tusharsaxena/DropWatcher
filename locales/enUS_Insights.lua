local _, NS = ...
-- locales/enUS_Insights.lua — the Insights tab's strings (issue #12, Insights design spec §6, Q8), a
-- topic file on localization-§6's shape: its consumer is a feature, the Insights tab's modules
-- (modules/InsightsFilters.lua, modules/InsightsStats.lua, and the tab's body). locales/enUS.lua
-- loads first (DropWatcher.toc) and alone creates NS.L and its metatable fallback; this file only
-- fills that table. Each key lives in one enUS file. The key IS the English source string, one
-- heading per first user in TOC load order, as there.

local L = NS.L


-- The Insights filters (modules/InsightsFilters.lua): the dropdowns' heads, the dates, the fallbacks
L["%s (%d)"] = "%s (%d)"
L["All categories"] = "All categories"
L["All characters"] = "All characters"
L["All difficulties"] = "All difficulties"
L["All instances"] = "All instances"
L["All kept days"] = "All kept days"
L["All qualities"] = "All qualities"
L["All situations"] = "All situations"
L["Last %d days"] = "Last %d days"
L["No difficulty"] = "No difficulty"
L["Today"] = "Today"

-- The Insights numbers (modules/InsightsStats.lua): the slot breakdown's fallback
L["Other"] = "Other"
