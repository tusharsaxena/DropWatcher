local _, NS = ...
-- core/Database.lua — the schemaVersion migration runner (savedvariables-§1).
--
-- The defaults tree is built by settings/Schema.lua's Settings.BuildDefaults (profile rows from the
-- schema, plus defaults/Profile.lua's global table) and handed to AceDB in OnInitialize.
-- global.schemaVersion defaults to 0, never the current version: AceDB strips a value equal to its
-- default at logout and would backfill it onto a legacy account.

-- The runner's target: the highest step below.
NS.SCHEMA_VERSION = 1

-- Each step is idempotent against a fresh default database.
NS.MIGRATIONS = {
    [1] = function(_db) end,  -- 0 -> 1: the stamp itself; nothing to reshape
}

function NS:RunMigrations()
    local g = self.db and self.db.global
    if not g then return end
    local from = g.schemaVersion or 0
    local v = from
    while v < NS.SCHEMA_VERSION do
        local step = NS.MIGRATIONS[v + 1]
        if step then step(self.db) end
        v = v + 1
        g.schemaVersion = v   -- the runner owns the stamp; reached only if the step returned
    end
    local D = NS.DebugLog
    if from ~= g.schemaVersion and D and D.DebugAtEnable then
        D.DebugAtEnable("Migrate", "v%s -> v%s", from, g.schemaVersion)
    end
end
