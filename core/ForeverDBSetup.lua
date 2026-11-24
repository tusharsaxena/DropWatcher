local _, NS = ...
-- core/ForeverDBSetup.lua — NS.ForeverDB, the LibKa0s-ForeverDB-1.0 seam (library-stack-§7,
-- clients-§11; SF-DW-01, LibKa0s#105).
--
-- ForeverDB is an OPTIONAL WoW Forever data addon (`## OptionalDeps`, never `## Dependencies`): it
-- knows what the client's own data cannot, which creature drops an item and how often, and who
-- sells it. The library is the one reader of it; this addon never touches the `ForeverDB` global or
-- loads it itself. The library's first lookup is what loads it (some 12 MB), and nothing here makes
-- one: modules/ItemSources.lua asks only when the player opens a detail card on WoW Forever with
-- Window > Layout > Detail card's Show where it drops on.
--
-- The library-absent stand-in answers the all-absent values of the library's own *Degradation*
-- section (docs/api/ForeverDB/version-1-docs.md), member for member, so the card simply shows no
-- sources: tests/test_surface_parity.lua holds it to the live surface.

local FDB = LibStub and LibStub("LibKa0s-ForeverDB-1.0", true)

local function none() return nil end

NS.ForeverDB = FDB or {
    Available     = function() return false, "missing" end,
    IsLoaded      = function() return false end,
    Status        = function() return { present = false, loaded = false } end,
    Meta          = none,
    NPC           = none,
    Item          = none,
    Quest         = none,
    ItemSources   = none,
    VendorPrice   = function() return nil, nil end,
    Spots         = none,
    TrainerSpells = none,
}
