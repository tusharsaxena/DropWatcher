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

-- One upgrade glow's defaults (feedback-21): on or off, its style, its color (a tone of
-- core/Constants.lua's C.TONE, opaque), its Use class color companion (off, options-ui-§17: the
-- player's class, its alpha the swatch's) and every style's knobs, only the chosen style's read. The
-- knob set, ranges and defaults are shared with KickCD's glow slots (the feedback-21 plan's knob
-- table); `pixelLength` 0 is automatic (the library sizes the lines from the icon). Each default is
-- the value LibCustomGlow-1.0 takes for nil, but `pixelFrequency`: 0.1, slower than the library's
-- 0.25, DropWatcher's own by the owner's choice (feedback-21 H6); KickCD keeps the library's.
local function glow(enabled, style, tone)
    return {
        enabled = enabled,
        type    = style,                                       -- button | proc | pixel | autocast
        color   = { r = tone.r, g = tone.g, b = tone.b, a = 1 },
        useClassColor = false,                                 -- the player's class color instead
        pixelLines = 8, pixelFrequency = 0.1, pixelLength = 0, pixelThickness = 1, pixelBorder = true,
        autocastParticles = 4, autocastFrequency = 0.125, autocastScale = 1,
        buttonFrequency = 0.25,
        procDuration = 1, procStartAnim = true,
        xOffset = 0, yOffset = 0,                              -- pixel, autocast and proc
    }
end
local TONE = NS.Constants.TONE

NS.C = {
    PROFILE = {
        enabled    = true,       -- master switch (the `disabled` hold reads it)
        visibility = "always",   -- General visibility: always | inCombat | outOfCombat | never
        scale      = 1.0,        -- Master scale, applied to the main window
        alpha      = 1.0,        -- Master alpha
        locked     = false,      -- Lock frame: the window cannot be dragged or resized
        autoOpen   = true,       -- master auto-open: false keeps every situation from opening the window

        -- Where Drop Watcher is active (design spec §6.1), keyed like C.SITUATIONS. The owner's defaults
        -- since DW-06: follower dungeons, delves, scenarios and solo tracked and auto-opening too.
        situations = {
            mythicPlus      = situation(true, true),
            dungeon         = situation(true, true),
            followerDungeon = situation(true, true),
            raidLFR         = situation(true, false),
            raid            = situation(true, true),
            delve           = situation(true, true),
            scenario        = situation(true, true),
            pvp             = situation(false, false),
            openWorldGroup  = situation(false, false),
            solo            = situation(true, true),
        },

        -- The feed's gates and the filter bar's seeds (design spec §6.2, §6.3, §11.1).
        feed = {
            -- The View a fresh filter bar tab opens on: a set, every value off is All (feedback-2
            -- spec §1). Each value is a `feed.view.<value>` row; they combine as AND.
            view    = { interesting = false, likely = false, usable = false, upgrade = false },
            content = "session",       -- instance | session (step 8 turns a stored all into session)
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

        -- The trade estimate (design spec §7). `rules` is the rule each situation takes (§7.2; follower
        -- dungeons `personal` since DW-06, the owner's default), the
        -- owner's override once changed (§7.3); `raid` is the conservative `personal` until smoke
        -- check TRADE-3 confirms it.
        trade = {
            rules = {
                mythicPlus = "personal", dungeon = "personal", followerDungeon = "personal",
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
                askOffSpec = "Hi {player}, if you don't need {item}, could I have it for my off-spec? It'd be +{mygain} for me. No worries if not!",
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
                -- `me` and `them` show the worn gear too (feedback-6 spec §1); schema step 7 retired
                -- the `myEq` and `theirEq` toggles.
                ilvl = true, slot = true, armorType = true, looter = true,
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
            -- The rest of the tables' font setting (DW-01, the lead's ruling on D-07: every font
            -- setting carries size, color with a class-color option, flags with From skin, and
            -- shadow), Window › Layout › Tables' composed font block (settings/ComposedRows.lua). Each
            -- default keeps the look the tables had before it: the skin's face (`tableFontFromSkin`;
            -- `tableFont` waits for the player to turn it off), the swatch on Ka0s Default's plain text
            -- color, which modules/WindowRows.lua reads as "the skin's" until another color is picked,
            -- and the skin's shadow. Only the flags moved: From skin ("@skin"), resolved through the
            -- Skin tab's Font outline as window text. Nothing stored before them, so no migration.
            tableFont           = "Friz Quadrata TT",
            tableFontFromSkin   = true,
            tableFontColor      = { r = 0.92, g = 0.92, b = 0.92, a = 1 },   -- = dw.plain's Ka0s Default
            tableFontClassColor = false,
            tableFontFlags      = "@skin",
            tableFontShadow     = true,
        },

        -- The upgrade toast (design spec §11.5). Its `point` is geometry, like the window's.
        toast = {
            enabled  = true,    -- on for a new profile (owner, 2026-10-25); no migration
            minGain  = 10,      -- the least item-level gain for you
            duration = 8,       -- seconds on screen
            inCombat = false,
            sound    = false,
            scale    = 1,       -- the frame's scale, 0.5 to 2 (Window › Toast's Scale, 50 to 200 %)
        },

        -- The upgrade glow on a drop's icon (feedback-21): `main` for an upgrade for your current
        -- spec, `offSpec` for one only another of your specs gains from, each with its own style.
        -- Both Proc (flipbook), in their own colors (DW-03, owner ruling D-18, image-39; two pixel
        -- borders and the main spec's #FFF468 from feedback-21 H6 until then): the main spec's green
        -- #19FF19, the off-spec's blue #3FC7EB. AceDB's defaults carry a profile that never chose a
        -- style or a color onto these; a stored choice stays, so no migration is owed.
        glow = {
            main    = glow(true, "proc", TONE.glowMain),
            offSpec = glow(true, "proc", TONE.glowOffSpec),
        },

        -- Every item icon's look (feedback-21 G11, Window › Icons; modules/IconStyle.lua). The
        -- defaults (feedback-21 H6, the owner's choice) trim the icon's baked-in edge (zoom 0.1) and
        -- draw a flat black border 2 pixels thick. The border rows are LibKa0s-Options' composed
        -- block (options-ui-§16), so their values live here too, as the Master controls' do;
        -- `borderStyle` is a LibSharedMedia border name, "Solid" the flat edge modules/IconStyle.lua
        -- registers (AuraMaster's name for it). A profile that stored a value keeps it (AceDB).
        icons = {
            zoom                = 0.1,                      -- 0 to 0.25, cropped off each side
            borderShow          = true,
            borderStyle         = "Solid",
            borderSize          = 2,                        -- the edge's width, in pixels
            borderColor         = { r = 0, g = 0, b = 0, a = 1 },
            useClassColorBorder = false,                    -- the player's class color instead
            borderQuality       = false,                    -- the item's quality color instead
            -- The border's skin companion (skinning-§6; the composer's `fromSkin = "icon"`, DW-03):
            -- while on, the style and thickness are the skin's icon border family (`icon.borderStyle`,
            -- `icon.borderSize`; Ka0s Default's are Solid 2px, the look above) and their two rows show
            -- the skin's values. TRUE by default (the rollout's X3), so a new or reset profile follows
            -- the skin exactly as a stored one does after core/Database.lua's one-time step 10 (O2).
            -- Only style and thickness follow (X4): the color, its class and quality companions, Show
            -- border and the zoom stay the player's.
            borderStyleFromSkin = true,
        },

        -- The simulator (feedback-2 spec §8): the seconds an automatic run waits between steps.
        sim = {
            stepDelay = 1,
        },

        -- The skin this addon wears (skinning-§2: per addon, per profile), applied through
        -- core/SkinSetup.lua and written only through the schema seam (settings/SchemaRows.lua's
        -- skipRender rows; General › Skin draws them). `source` is "ka0s" (the Ka0s skins) or "eui"
        -- (EllesmereUI's); "ka0s"/"ka0s" is Ka0s Default, the look the addon drew before skins. The
        -- Scope's two exceptions: a new profile leaves the settings panel the client's and skins
        -- the fonts (LootHistory's defaults). `font` and `texture` are the Skin tab's overrides, an
        -- LSM key each, "" for the skin's own. `outline` (LibKa0s v1.82.0, Skin minor 9, ruling
        -- D-06): the Font outline, "all" text, "hud" text only or "off"; the window, the cards and
        -- the toast are window text, so "hud" takes their outline. `pickerSeen`: the first-run skin picker was closed
        -- on this profile; false on every profile, old and new, so every player sees it once (the
        -- rollout's O3). New keys with defaults, so AceDB merges them into every existing profile
        -- and no migration is owed.
        skin = {
            source      = "ka0s",
            skin        = "ka0s",
            ignorePanel = true,
            ignoreFonts = false,
            font        = "",
            texture     = "",
            outline     = "all",
            pickerSeen  = false,
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
