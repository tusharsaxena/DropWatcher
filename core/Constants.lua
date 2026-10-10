local _, NS = ...
-- core/Constants.lua — fixed values the addon reads: fonts, window geometry, colors.
--
-- Data only. The slot plans, quality ids, difficulty ids, trade rules and template defaults of the
-- design spec (§4) are added here by the feature items that read them.

NS.Constants = NS.Constants or {}
local C = NS.Constants

-- The debug console's monospace face, from the shared payload (core/MediaSetup.lua, which loads
-- first). A real client font when the library is absent, never nil and never a dead path.
C.FONT_MONO_NAME = "JetBrains Mono"
C.FONT_MONO = NS.MediaFont and NS.MediaFont(C.FONT_MONO_NAME) or _G.STANDARD_TEXT_FONT
    or "Fonts\\FRIZQT__.TTF"

-- The main window (design spec §11.1). Sizes are pixels at a 1.0 scale.
C.WINDOW = {
    NAME        = "DropWatcherWindow",
    WIDTH       = 760,
    HEIGHT      = 380,
    MIN_WIDTH   = 520,
    MIN_HEIGHT  = 260,
    TITLE_H     = 30,
    -- Where a fresh profile, and Reset position, put the window.
    POINT       = { "CENTER", "CENTER", 0, 0 },
}

-- The gold of the title, the active tab and the test-mode banner (design spec §2).
C.GOLD = { r = 1.0, g = 0.82, b = 0.0 }
