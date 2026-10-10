local _, NS = ...
-- defaults/Profile.lua — every default VALUE the addon hardcodes (savedvariables-§2).
--
-- Two scopes, each one AceDB defaults table (settings/Schema.lua's Settings.BuildDefaults assembles
-- them with the schema rows' own defaults):
--   profile  the Master controls values (options-ui-§15) and the window's geometry;
--   global   the schema stamp and LibDBIcon's table.
--
-- The Master controls rows are composed by LibKa0s-Options-1.0, so their values live here too: with
-- the library absent the schema has no `enabled` row, and a schema-only defaults tree would hand
-- AceDB a profile whose `enabled` reads nil.

NS.C = {
    PROFILE = {
        enabled    = true,       -- master switch (the `disabled` hold reads it)
        visibility = "always",   -- General visibility: always | inCombat | outOfCombat | never
        scale      = 1.0,        -- Master scale, applied to the main window
        alpha      = 1.0,        -- Master alpha
        locked     = false,      -- Lock frame: the window cannot be dragged or resized
        -- The window's geometry, written by modules/Window.lua alone (a drag or a resize sets it;
        -- no control and no schema row addresses it, architecture-§5): `point` = { point,
        -- relativePoint, x, y } and `width` / `height`, each absent until the player moves or sizes
        -- the window.
        window = {},
    },

    -- schemaVersion is 0, never the current version (savedvariables-§1).
    GLOBAL_DEFAULTS = { schemaVersion = 0, minimap = { hide = false } },
}
