local addonName, NS = ...
-- core/ToastSetup.lua — NS.NewToast, the LibKa0s-Toast-1.0 seam (library-stack-§7): the alert-toast
-- shell under the upgrade toast (modules/Toast.lua). The shell owns the queue, the lifetime (the
-- countdown, its hover pause, the close mark and the right-click), the T5 alert tier, the drag, the
-- scale and the sound; modules/Toast.lua owns what the toast says, which drops toast, the combat
-- hold and the settings it reads.
--
-- A seam, nothing else: one file leases the major, and every descriptor it builds carries this
-- addon's folder as its skin owner.
--
-- DEGRADED (the library absent): NS.NewToast answers NS.ToastStub, the instance's surface with every
-- member a no-op answering what an empty toast answers, so no toast ever shows and nothing raises.
-- test_surface_parity holds the stub to a live instance.

local Toast = LibStub and LibStub("LibKa0s-Toast-1.0", true)

-- The instance's surface, each member a no-op (docs/api/Toast/version-1-docs.md in LibKa0s, The
-- degradation stub).
NS.ToastStub = {
    Show = function() return false end, Dismiss = function() end, Remove = function() return 0 end,
    Clear = function() end, Hold = function() end, Release = function() end,
    Preview = function() end, Pause = function() end, Resume = function() end,
    Attach = function() end, Refresh = function() end, ResetPosition = function() end,
    Current = function() return nil end, Frame = function() return nil end,
    Stats = function() return { built = false, shown = false, waiting = 0, held = false,
        paused = false, sticky = false, keys = {} } end,
}

--- A toast for descriptor `d` (the library's Toast:New; `d.owner` defaults to this addon), or the
--- stub when the library is absent.
--- @param d table the descriptor: d.build is required
--- @return table instance
function NS.NewToast(d)
    if not Toast then return NS.ToastStub end
    d.owner = d.owner or addonName
    return Toast:New(d)
end
