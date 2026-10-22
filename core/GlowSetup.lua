local _, NS = ...
-- core/GlowSetup.lua — NS.GlowLib, the LibKa0s-Glow-1.0 seam (library-stack-§7). Absent major: no
-- glow, the same thing an absent LibCustomGlow-1.0 already means here. Never a local copy of the
-- mapping.
--
-- The library is the stateless LibCustomGlow-1.0 driver: Start(frame, style, knobs, key,
-- frameLevel) maps the four styles' knobs to LCG's positional arguments, and Stop(frame, style,
-- key) stops one style (nil stops all four). LibCustomGlow-1.0 itself is resolved by the library at
-- every call, never here. modules/Glow.lua keeps the policy: which drops glow, the unchanged-repaint
-- gate and the proc burst's spend.

local G = LibStub and LibStub("LibKa0s-Glow-1.0", true)

-- The library-absent stand-in: Start draws nothing and says so, Stop has nothing to stop.
NS.GlowLib = G or {
    Start = function() return false end,
    Stop = function() end,
}
