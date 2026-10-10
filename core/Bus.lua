local addonName, NS = ...
-- core/Bus.lua — every message name declared ONCE (architecture-§4), and the tracked bus.
--
-- Modules talk over AceEvent messages named Ka0s_DropWatcher_<Event>, one sender each, and every
-- SendMessage / RegisterMessage call site uses the NS.MSG constant, never the literal. With
-- LibKa0s-Bus-1.0 present the table is the library's strict Catalog copy, so a mistyped key raises
-- at the call site for a publisher as well as a subscriber.
--
-- NS.Bus records what each receiver is registered for, so the stand-down takes every tracked
-- registration down and the stand-up replays what is wanted NOW (slash-commands-§7). A receiver
-- takes its own target, `NS.Bus:NewTarget()`, never a shared one: CallbackHandler keys callbacks
-- by (message, target), and two receivers on one target clobber each other.

local lib = LibStub and LibStub("LibKa0s-Bus-1.0", true)

-- The catalog of design spec §3. Each line names its one sender.
local MSG = {
    DROP_ADDED           = "Ka0s_DropWatcher_DropAdded",           -- modules/LootFeed.lua
    DROP_UPDATED         = "Ka0s_DropWatcher_DropUpdated",         -- modules/LootFeed.lua
    INSPECT_DONE         = "Ka0s_DropWatcher_InspectDone",         -- modules/Inspect.lua
    GEAR_CHANGED         = "Ka0s_DropWatcher_GearChanged",         -- modules/Gear.lua
    RESTRICTION_CHANGED  = "Ka0s_DropWatcher_RestrictionChanged",  -- modules/Restrictions.lua
    SITUATION_CHANGED    = "Ka0s_DropWatcher_SituationChanged",    -- modules/Situations.lua
    ASK_STATE_CHANGED    = "Ka0s_DropWatcher_AskStateChanged",     -- modules/Messaging.lua
    TRADE_TIMER_TICK     = "Ka0s_DropWatcher_TradeTimerTick",      -- modules/TradeTimer.lua
    TRADE_TIMER_EXPIRING = "Ka0s_DropWatcher_TradeTimerExpiring",  -- modules/TradeTimer.lua
    HISTORY_CHANGED      = "Ka0s_DropWatcher_HistoryChanged",      -- modules/History.lua
}

if not lib then
    -- Degrade, never error. The catalog is the plain table; the bus is an untracked factory whose
    -- targets are bare AceEvent embeds, and whose edges have nothing recorded to take down. The
    -- feature modules unregister their own receivers in their stand-down step on this path.
    NS.MSG = MSG
    NS.Bus = {
        name      = addonName,
        NewTarget = function()
            local AceEvent = LibStub and LibStub("AceEvent-3.0", true)
            return AceEvent and AceEvent:Embed({}) or nil
        end,
        StandDown = function() return 0, 0 end,
        StandUp   = function() return 0, {}, 0 end,
    }
    return
end

NS.MSG = lib.Catalog(addonName, MSG)
NS.Bus = lib:New({
    name   = addonName,
    -- Resolved when asked: the latch (core/LifecycleSetup.lua) loads after this file.
    isDown = function() return NS.IsStoodDown ~= nil and NS.IsStoodDown() end,
})
