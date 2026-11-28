local _, NS = ...
-- modules/GearQualities.lua — Drop Watcher's own read over your gear snapshot (NS.Gear, the verdict
-- engine's: core/VerdictViews.lua), kept out of the library (Item Search split plan, tasks A2, C1)
-- because the feed alone needs it: the worn qualities the minimum-quality gate reads. The combat
-- defer of bag events is the engine host's deferWhile (core/VerdictSetup.lua).

local G = NS.Gear

--- The quality worn in each slot, `{ [slot] = quality | false }` (false = empty), for the
--- minimum-quality gate's ctx.gear (design spec §6.2). A slot still loading is absent.
--- @return table
function G.Qualities()
    local out = {}
    for slot, e in pairs(G.Snapshot().equipped) do
        if e == false then out[slot] = false else out[slot] = e.quality end
    end
    return out
end

