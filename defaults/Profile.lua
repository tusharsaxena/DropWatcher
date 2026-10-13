local _, NS = ...
-- defaults/Profile.lua — every default VALUE the addon hardcodes (savedvariables-§2).
--
-- Two scopes, each one AceDB defaults table (settings/Schema.lua's Settings.BuildDefaults assembles
-- them with the schema rows' own defaults, which reference these values):
--   profile  every setting of design spec §12.1 and the window's geometry;
--   global   the schema stamp, LibDBIcon's table and the History's Keep history for.
--
-- The Master controls rows are composed by LibKa0s-Options-1.0, so their values live here too: with
-- the library absent the schema has no `enabled` row, and a schema-only defaults tree would hand
-- AceDB a profile whose `enabled` reads nil. A kernel that needs a setting's default without a
-- database (a pure call, a read before OnInitialize) reads it from this table, never from a literal
-- of its own.

-- One situation's defaults (design spec §6.1): `quality` "global" means the feed's own mode.
local function situation(track, autoOpen)
    return { track = track, autoOpen = autoOpen, quality = "global" }
end

NS.C = {
    PROFILE = {
        enabled    = true,       -- master switch (the `disabled` hold reads it)
        visibility = "always",   -- General visibility: always | inCombat | outOfCombat | never
        scale      = 1.0,        -- Master scale, applied to the main window
        alpha      = 1.0,        -- Master alpha
        locked     = false,      -- Lock frame: the window cannot be dragged or resized
        autoOpen   = true,       -- master auto-open: false keeps every situation from opening the window

        -- Where Drop Watcher is active (design spec §6.1), keyed like C.SITUATIONS.
        situations = {
            mythicPlus      = situation(true, true),
            dungeon         = situation(true, true),
            followerDungeon = situation(false, false),
            raidLFR         = situation(true, false),
            raid            = situation(true, true),
            delve           = situation(false, false),
            scenario        = situation(false, false),
            pvp             = situation(false, false),
            openWorldGroup  = situation(false, false),
            solo            = situation(false, false),
        },

        -- The feed's gates and the filter bar's seeds (design spec §6.2, §6.3, §11.1).
        feed = {
            -- The View a fresh filter bar tab opens on: a set, every value off is All (feedback-2
            -- spec §1). Each value is a `feed.view.<value>` row; they combine as AND.
            view    = { interesting = false, likely = false, usable = false, upgrade = false },
            content = "instance",      -- instance | session | all
            sort    = "newest",        -- newest | oldest | ilvl | gain
            quality = {
                mode            = "fixed",   -- fixed | dynamicSlot | dynamicCharacter
                fixed           = 3,         -- Rare (Enum.ItemQuality.Rare)
                floor           = 2,         -- Uncommon: the dynamic modes' least threshold
                upgradeOverride = true,      -- an upgrade for me shows below the threshold
            },
            gearOnly        = true,      -- armor, weapons, jewelry and trinkets only
            includeTokens   = true,      -- tier tokens pass the gear-only filter
            minIlvlMode     = "off",     -- off | absolute | relative
            minIlvl         = 0,         -- the absolute floor
            relativeIlvl    = 10,        -- how far below your average equipped level a drop may be
            clearOnBossKill = false,     -- the feed's session drops cleared at each boss kill
        },

        -- How a drop is judged (design spec §5). `weights` and `undesired` are keyed by specID:
        -- weights[specID] = { STAT_KEY = weight }, undesired[specID] = { ["<classID>:<subClassID>"] = true }.
        comparison = {
            scorer          = "auto",   -- auto | pawn | weights | none
            weights         = {},
            sidegradeBand   = 0,        -- item levels either side of equal that read as a sidegrade
            compareOwned    = false,    -- compare against the best of worn and owned
            heirloomProtect = true,     -- a slot holding an heirloom is not called an upgrade
            undesired       = {},
        },

        -- The trade estimate (design spec §7). `rules` is the rule each situation takes (§7.2), the
        -- owner's override once changed (§7.3); `raid` is the conservative `personal` until smoke
        -- check TRADE-3 confirms it.
        trade = {
            rules = {
                mythicPlus = "personal", dungeon = "personal", followerDungeon = "legacy",
                raidLFR = "personal", raid = "personal", delve = "personal", scenario = "personal",
                pvp = "legacy", openWorldGroup = "personal", solo = "personal",
            },
            warnAt     = 600,     -- seconds left when your own item's trade timer warns; 0 is off
        },

        -- Messaging (design spec §9).
        messages = {
            templates = {
                ask      = "Hi {player}, if you don't need {item}, could I have it? It'd be +{mygain} for me. No worries if not!",
                offer    = "Hi {player}, {item} is tradeable and looks like +{gain} for you. Want it?",
                announce = "{item} is up for grabs, whisper me.",
                transmog = "Hi {player}, if you don't need {item}, could I have it for transmog? I haven't collected its look. No worries if not!",
            },
            transmogAsk     = false,    -- offer the For transmog ask on a drop whose look you lack
            editFirst       = false,    -- open the edit box before a send
            oneAsk          = true,     -- each (drop, target, kind) is sent once
            announceChannel = "auto",   -- auto | INSTANCE_CHAT | RAID | PARTY
            autoAsk = {
                enabled = false,
                delay   = 10,   -- seconds after the later of the boss kill or the drop
                minGain = 5,    -- the least item-level gain for you
            },
        },

        -- The window (design spec §11.1). `geometry.full` and `geometry.compact` (each { point,
        -- width, height }, one per layout: compact spec §1) and `minimized` are geometry and a
        -- remembered view, written by modules/Window.lua and modules/WindowCompact.lua alone
        -- (architecture-§5): each is absent until the player moves, sizes or minimizes the window,
        -- and no row addresses it.
        window = {
            columns = {
                ilvl = true, slot = true, armorType = true, looter = true, myEq = true, theirEq = true,
                me = true, them = true, trade = true, tradeWindow = true, actions = true,
            },
            -- The layout (compact spec §1): `full` (the tables) or `compact` (the narrow card
            -- view). Schema step 5 maps the retired `compact` preset to it.
            mode          = "full",
            -- An auto-open inside a dungeon, raid, key or delve opens the compact layout, whatever
            -- `mode` says, until that run ends.
            compactInRuns = true,
            -- Like Ka0s Loot History's table (feedback-2 spec §8, FB2-9): 18-pixel rows, and the
            -- text at its template's own size (0 is Default). Both tabs read both; a Drops row
            -- while Trade window shows adds the room its countdown bar needs. A value the player stored stays as it is.
            rowHeight = 18,      -- one drop row, in pixels
            fontSize  = 0,       -- the tables' text: 0 is the template's own size, else 8 to 20
        },

        -- The upgrade toast (design spec §11.5). Its `point` is geometry, like the window's.
        toast = {
            enabled  = false,
            minGain  = 10,      -- the least item-level gain for you
            duration = 8,       -- seconds on screen
            inCombat = false,
            sound    = false,
        },

        -- The simulator (feedback-2 spec §8): the seconds an automatic run waits between steps.
        sim = {
            stepDelay = 2,
        },
    },

    -- schemaVersion is 0, never the current version (savedvariables-§1).
    GLOBAL_DEFAULTS = {
        schemaVersion = 0,
        minimap = { hide = false },
        -- How long the History tab keeps a group, in days (feedback-2 spec §5; 0 = never delete).
        -- The history itself (`history.v`, `history.groups`) is modules/History.lua's (DW-51), which
        -- never replaces the table whole.
        history = { retentionDays = 30 },
    },
}
