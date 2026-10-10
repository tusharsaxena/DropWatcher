local _, NS = ...
-- core/PoolSetup.lua — NS.Pool from LibKa0s-Pool-1.0: the free/active frame pool.
--
-- The drop tables re-render their rows on every feed change (design spec §11.1), so rows come from
-- a pool, never from a CreateFrame per render. Only the array shape is used; the keyed family is
-- not wired (tests/test_surface_parity.lua names it).

local Pool = LibStub and LibStub("LibKa0s-Pool-1.0", true)

-- The library-absent stand-in: the four array-shape members, in the library's semantics.
NS.Pool = Pool or {
    New = function() return { free = {}, active = {} } end,
    Acquire = function(pool, factory)
        local o = table.remove(pool.free)
        if not o then o = factory() end
        pool.active[#pool.active + 1] = o
        o:Show()
        return o
    end,
    ReleaseAll = function(pool, before)
        local active = pool.active
        for i = #active, 1, -1 do
            local o = active[i]
            if before then before(o) end
            o:Hide()
            pool.free[#pool.free + 1] = o
            active[i] = nil
        end
    end,
    Counts = function(pool) return #pool.free, #pool.active end,
}
