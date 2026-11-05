local addonName, NS = ...
-- core/ChartsSetup.lua — NS.Charts from LibKa0s-Charts-1.0, and NS.ChartsHost(), the Insights tab's
-- host table for that major (issue #12, Insights design spec §4.4). modules/WindowInsights.lua draws
-- its cards and charts through both.
--
-- A seam, nothing else (library-stack-§7): one file leases the major. The skin owner is this
-- addon's folder, the owner core/SkinSetup.lua registers, so the colors, faces, panels, bar
-- textures and the `chart.series` palette all come from the skin in force, and the context reskins
-- itself on the owner's OnLooksChanged. Its `onReskin` marks the tab for a fresh layout, because
-- the colors a row was bound with (class, quality, verdict, trade tone) are the host's and are read
-- when the row is bound. The default GameTooltip hover is kept, and NS.Pool is the pool.
--
-- DEGRADED (the library absent): NS.Charts is nil and there is no drawing stub (anti-pattern #73,
-- as in Ka0s DPS Race). The Insights tab keeps its filters and its strip, says the charts are
-- unavailable, and logs that once when its pane is built (NS.Debug is not up yet at this load).

--- The major, or nil without the library.
NS.Charts = LibStub and LibStub("LibKa0s-Charts-1.0", true)

--- The host table for the Insights tab's chart context (Charts:New's `host`).
--- @return table
function NS.ChartsHost()
    return {
        owner = addonName,
        pool = NS.Pool,
        onReskin = function() if NS.WindowInsights then NS.WindowInsights.MarkLayout() end end,
    }
end
