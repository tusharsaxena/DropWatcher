local _, NS = ...
-- modules/GearQualities.lua — Drop Watcher's own reads over your gear snapshot (NS.Gear), peeled out
-- of modules/Gear.lua (Item Search split plan, task A2) so the snapshot holds nothing the feed alone
-- needs: the worn qualities the minimum-quality gate reads, and the combat defer of bag events
-- (NS.Restrictions.InCombat, handed to NS.Gear.SetDeferPredicate at load).

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

-- A bag event in combat waits for the combat's end (the PLAYER_REGEN_ENABLED edge, NS.Gear's).
G.SetDeferPredicate(function() return NS.Restrictions.InCombat() end)
