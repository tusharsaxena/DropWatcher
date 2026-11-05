local _, NS = ...
-- locales/enUS_Insights.lua — the Insights tab's strings (issue #12, Insights design spec §6, Q8), a
-- topic file on localization-§6's shape: its consumer is a feature, the Insights tab's modules
-- (modules/InsightsFilters.lua, modules/InsightsStats.lua, modules/InsightsRows.lua and the tab's
-- body, modules/WindowInsights.lua). locales/enUS.lua
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

-- The Insights tab (modules/InsightsRows.lua, modules/WindowInsights.lua): the cards, their hovers,
-- the period caption, the empty lines and the strip
L["%d looted by you, %d by others; %d on another spec"] = "%d looted by you, %d by others; %d on another spec"
L["%d of %d asks ended in a trade"] = "%d of %d asks ended in a trade"
L["%d recorded before asks were stamped (counted from items received)"] = "%d recorded before asks were stamped (counted from items received)"
L["%d recorded before offers were stamped (counted from items traded away)"] = "%d recorded before offers were stamped (counted from items traded away)"
L["%d yours, %d by others"] = "%d yours, %d by others"
L["%s – %s"] = "%s – %s"
L["%s of %d kept"] = "%s of %d kept"
L["%s · %d drops in %d groups"] = "%s · %d drops in %d groups"
L["Active days"] = "Active days"
L["Ask success"] = "Ask success"
L["Asks sent"] = "Asks sent"
L["Asks you sent for others' drops."] = "Asks you sent for others' drops."
L["Drops seen"] = "Drops seen"
L["Every kept day"] = "Every kept day"
L["Every kept day: since %s"] = "Every kept day: since %s"
L["From %d group members"] = "From %d group members"
L["Items received"] = "Items received"
L["Kept for %s"] = "Kept for %s"
L["Kept for %s: %s"] = "Kept for %s: %s"
L["Last %d days (%s)"] = "Last %d days (%s)"
L["Legacy asks are inferred from items received, so the rate reads high."] = "Legacy asks are inferred from items received, so the rate reads high."
L["No asks in these filters."] = "No asks in these filters."
L["No drops match these filters."] = "No drops match these filters."
L["No history yet. Drops your group receives are kept for %s."] = "No history yet. Drops your group receives are kept for %s."
L["No history yet. Drops your group receives are kept until you clear them."] = "No history yet. Drops your group receives are kept until you clear them."
L["Offers and announcements you sent for your own drops."] = "Offers and announcements you sent for your own drops."
L["Offers sent"] = "Offers sent"
L["Reset filters"] = "Reset filters"
L["The charts need LibKa0s-Charts-1.0, which did not load."] = "The charts need LibKa0s-Charts-1.0, which did not load."
L["Today (%s)"] = "Today (%s)"
L["Upgrades for me"] = "Upgrades for me"
L["Your own drops you traded to someone."] = "Your own drops you traded to someone."
