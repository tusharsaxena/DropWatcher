local addonName, NS = ...
-- core/SkinSetup.lua — the LibKa0s-Skin-1.0 seam: which skin this addon wears (skinning-§1 to §3).
--
-- ── WHAT IT PUBLISHES ────────────────────────────────────────────────────────────────────────
--
--   NS.Skin                 the owner's facade, `Skin:For("DropWatcher")`: the painting vocabulary
--                           (Shell, TitleBar, Button, ...) and Token / Color / Resolve /
--                           OnLooksChanged. Every surface that draws reads its colors here.
--   NS.SKIN_TOKENS          this addon's owner tokens (LibKa0s v1.81.0, skinning-§1): each a color
--                           no library token holds exactly, named `dw.<name>`, with its Ka0s Default
--                           value (the pixel the addon drew before skins, X1) and the library ROLE
--                           token every other skin draws it in (X2).
--   NS.SkinChoice()         the stored (source, skin) pair, read through NS.SchemaRuntime.Get;
--                           "ka0s", "ka0s" before AceDB has built the profile store.
--   NS.WriteSkinChoice(s,k,i,m) the write seam: every half through NS.SchemaRuntime.Set, the one
--                           seam `/dw set` and the panel already write through (architecture-§5);
--                           `i`, the Scope's `{ panel, fonts }`, writes the two exceptions, and `m`,
--                           the Font and texture section's `{ font, texture }`, the two overrides,
--                           "" for false (the skin's own).
--   NS.ApplySkinChoice(s,k) moves the applied skin: `Skin:SetChoice`, which resolves, repaints every
--                           frame recorded for this owner and THEN fires OnLooksChanged. No argument
--                           applies the stored pair (DW:OnInitialize, the profile events), and with
--                           it the stored exceptions and overrides; a nil half keeps that half (each
--                           Skin tab row's onChange).
--   NS.ApplySkinIgnore(p,f) moves the applied exceptions: `Skin:SetIgnore`, live; no argument
--                           applies the stored pair, a nil half keeps that half.
--   NS.SkinOverride()       the stored overrides: font, texture, each an LSM key or false for the
--                           skin's own; false, false before AceDB.
--   NS.ApplySkinOverride(f,t) moves the applied overrides: `Skin:SetOverride`, live; no argument
--                           applies the stored pair, a nil half keeps that half, false or "" clears.
--   NS.SKIN_SOURCE_OPTIONS  the source row's values, and NS.SKIN_OPTIONS the skin row's (every
--   NS.SKIN_OPTIONS         registered skin, in the library's order). settings/SchemaRows.lua reads
--                           both at file load.
--   NS.SKIN_FALLBACK        the host copy of the Ka0s Default library tokens the degraded facade
--                           answers (the owner tokens answer their own defaults there).
--   NS.SkinColor(name)      a color token as a call site writes it (three components when opaque),
--                           so a literal that became a token keeps its arity on Ka0s Default.
--   NS.SkinEscape(name)     a color token as a "|cffrrggbb" escape, rounded to the byte, so markup
--                           written as a literal keeps its bytes on Ka0s Default.
--   NS.SkinPanelColor(name) NS.SkinColor for a raw surface on the settings panel: Ka0s Default
--   NS.SkinPanelIgnored()   while the Scope's Ignore settings panel is on (SkinPanelIgnored).
--   NS.RefillPalette()      core/Constants.lua's C.TONE filled from the tokens C.TONE_TOKEN names, in
--                           place, at load and first on every OnLooksChanged.
--   NS.SkinPaint(t, fn)     a surface the addon paints itself from a token: painted now and again on
--   NS.SkinRepaint()        every skin switch (after the palette), weak-keyed. SkinRepaint re-runs all.
--   NS.SkinMonoFont()       the skin's `font.mono` as a path; NS.SkinMono(fs, size) sets it on a glyph
--   NS.SkinMono(fs, size)   string and keeps it there on a skin switch.
--   NS.QualityColor(q)      an item quality's r, g, b: the skin's q.* token where it sets one (a
--                           legibility override), else the client's ITEM_QUALITY_COLORS; nil for none.
--   NS.SkinPaintAce(w)      an AceGUI widget this addon acquired itself, painted for this owner:
--   NS.SkinPaintAceTree(c)  `Skin:PaintAce` / `Skin:PaintAceTree` with the owner bound (the facade
--                           carries neither). Release restores stock.
--   NS.SkinOnRelease(w, fn) host release work chained onto the widget's own OnRelease
--                           (`Skin:OnRelease`), so it and the skin's restore both run.
--   NS.MaybeShowSkinPicker() the first-run skin picker (LibKa0s OptionsSkinPicker 1): `O.SkinPicker`
--                           while the profile's `skin.pickerSeen` is false and the addon stands up,
--                           held through combat. NS.HideSkinPicker() takes it down unmarked;
--   NS.SkinPickerSpec()     the spec it hands O.SkinPicker; NS.ArmSkinPicker(on) the login fuse;
--                           NS.SkinPickerCombatEnd() the held start's combat edge.
--
-- ── WHERE IT LOADS ───────────────────────────────────────────────────────────────────────────
--
-- After core/CoreSetup.lua, whose NS.ApplySkin the degraded facade's Shell routes to and whose
-- NS.Print the reload line uses, and before core/WidgetsSetup.lua, every module that builds a frame
-- and settings/SchemaRows.lua, which reads NS.SKIN_OPTIONS at file load. Nothing here reads the
-- profile at load: RegisterOwner calls `get` once, before AceDB exists, and it answers Ka0s Default;
-- the profile's choice is applied by NS.ApplySkinChoice right after AceDB (core/DropWatcher.lua).
--
-- ── WHY A ROW'S onChange PASSES ONE HALF ─────────────────────────────────────────────────────
--
-- The Skin tab and another addon's "Copy to every Ka0s addon" both call Skin:SetChoice FIRST and
-- write the store after, one half at a time. A row reaction that re-applied the whole stored pair
-- would apply the half-written one in between: a second repaint, to a skin the player never
-- picked. Applying only the row's own half against the applied choice makes each write a no-op
-- (SetChoice is idempotent), so a pick is ONE effective SetChoice and one repaint, while a bare
-- `/dw set skin.skin obsidian` still repaints.
--
-- Nothing skin-related keys off SettingsChanged. A surface that has to rebuild on a skin change
-- (markup built once, a pooled row) subscribes to NS.Skin.OnLooksChanged, which fires after the new
-- skin is resolved and the recorded frames are repainted.

local Skin = LibStub and LibStub("LibKa0s-Skin-1.0", true)

local SOURCE_PATH, SKIN_PATH = "skin.source", "skin.skin"
local PANEL_PATH, FONTS_PATH = "skin.ignorePanel", "skin.ignoreFonts"
local FONT_PATH, TEXTURE_PATH = "skin.font", "skin.texture"
local DEFAULT = "ka0s"

-- The owner tokens (LibKa0s-Skin-1.0 minor 7; Ka0sAddonsCommonTasks docs/2026-10-29-SKINNING_ROLLOUT,
-- the DW-G gaps). Each `default` is the value core/Constants.lua's palette (or the chrome literal the
-- gap names) drew under Ka0s Default, exactly (X1: never snapped to the nearest library token, which
-- would move a pixel); each `follow` is the nearest library ROLE token, so every other skin, and the
-- eui source, draws it in its own palette (X2). tests/test_skin_setup.lua holds each default to the
-- palette value it was cut from.
NS.SKIN_TOKENS = {
    -- DW-G1: the verdict and action-state tones (the drop tables, cards, toast, tooltip marks).
    ["dw.upgrade"]    = { default = { 0.30, 0.85, 0.40, 1 }, follow = "sem.good" },       -- C.TONE.good
    ["dw.sidegrade"]  = { default = { 1.00, 0.96, 0.42, 1 }, follow = "sem.statusWarn" }, -- C.TONE.yellow
    ["dw.downgrade"]  = { default = { 1.00, 0.36, 0.32, 1 }, follow = "sem.bad" },        -- C.TONE.red
    ["dw.offer"]      = { default = { 0.35, 0.82, 0.95, 1 }, follow = "sem.info" },       -- C.TONE.cyan
    -- An off-spec verdict follows the Warband blue, not Offer's sem.info, so the two the owner kept
    -- apart under Ka0s Default stay apart in every skin.
    ["dw.offSpec"]    = { default = { 0.30, 0.85, 0.85, 1 }, follow = "sem.warband" },    -- C.TONE.offspec
    ["dw.cantUse"]    = { default = { 0.72, 0.36, 0.34, 1 }, follow = "sem.badAlt" },     -- C.TONE.redMuted
    ["dw.notWanted"]  = { default = { 0.55, 0.55, 0.58, 1 }, follow = "sem.neutral" },    -- C.TONE.bad
    -- DW-G2: a trade window ending soon.
    ["dw.urgent"]     = { default = { 1.00, 0.65, 0.15, 1 }, follow = "sem.warn" },       -- C.TONE.warn
    -- DW-G3: a stat gained on the detail card's Stats row.
    ["dw.statGain"]   = { default = { 0.42, 0.74, 0.46, 1 }, follow = "sem.good" },       -- C.TONE.greenMuted
    -- DW-G4: the tables' plain text, the default of every setTone.
    ["dw.plain"]      = { default = { 0.92, 0.92, 0.92, 1 }, follow = "text.body" },      -- C.TONE.plain
    -- DW-G5: the idle gray (idle tab labels, the footer, side titles, Offer column heads, the
    -- compact separator); G5b its tooltip half, a token of its own (D7).
    ["dw.idle"]       = { default = { 0.62, 0.62, 0.64, 1 }, follow = "text.muted" },     -- C.IDLE
    ["dw.tipHint"]    = { default = { 0.62, 0.62, 0.64, 1 }, follow = "gtip.muted" },     -- C.IDLE
    -- DW-G6: an expanded (selected) row's or card's wash.
    ["dw.rowOpen"]    = { default = { 1.00, 0.82, 0.00, 0.08 }, follow = "list.hover" },
    -- DW-G7: a drop row's chevron.
    ["dw.chevron"]    = { default = { 1.00, 1.00, 1.00, 0.55 }, follow = "icon.tint" },   -- C.CHEVRON_ROW
    -- DW-G9: the restriction badge (lock icon and text).
    ["dw.restricted"] = { default = { 1.00, 0.60, 0.20, 1 }, follow = "sem.warn" },
    -- DW-G10: the flat text button's fill and edge (TB.TextButton).
    ["dw.btnBg"]      = { default = { 0.12, 0.12, 0.14, 1 }, follow = "btn.bg" },
    ["dw.btnBorder"]  = { default = { 0.24, 0.24, 0.27, 0.85 }, follow = "btn.border" },
    -- DW-G12: the Drops and History bottom strips' top rule.
    ["dw.rule"]       = { default = { 1.00, 1.00, 1.00, 0.10 }, follow = "divider" },
    -- DW-G13: the detail card's boxes and chips, and the editor's text box.
    ["dw.cardBg"]     = { default = { 0.08, 0.08, 0.10, 0.9 }, follow = "card.bg" },
    ["dw.cardBorder"] = { default = { 0.24, 0.24, 0.27, 0.85 }, follow = "card.border" },
    -- DW-G15: a tooltip row's label and bullet.
    ["dw.tipLabel"]   = { default = { 0.80, 0.68, 0.36, 1 }, follow = "gtip.title" },     -- C.TONE.mutedGold
}

-- The Ka0s Default library tokens the DEGRADED facade answers, copied from the library and limited
-- to the ones this addon reads. Both arms publish the table, so tests/test_surface_parity.lua can
-- hold each entry to the live library's Ka0s Default value: a copy that drifts goes red there. A
-- surface converted to a token adds the token here in the same change.
NS.SKIN_FALLBACK = {
    ["win.bg"]     = { 0.06, 0.06, 0.08, 0.92 },
    ["win.border"] = { 0, 0, 0, 1 },
    ["win.inner"]  = { 0.24, 0.24, 0.27, 0.85 },
    ["title.text"] = { 1, 0.82, 0, 1 },
    ["divider"]    = { 0.24, 0.24, 0.27, 0.85 },
    -- The window's own surfaces (DW-02): its text roles, lists, tabs, controls and tooltip lines.
    ["text.body"]        = { 0.9, 0.9, 0.9, 1 },
    ["text.muted"]       = { 0.7, 0.7, 0.72, 1 },
    ["text.heading"]     = { 1, 0.82, 0, 1 },
    ["text.headingAlt"]  = { 0.91, 0.77, 0.42, 1 },
    ["text.accent"]      = { 1, 0.82, 0, 1 },
    ["text.disabled"]    = { 0.5, 0.5, 0.5, 1 },
    ["text.bodyAlt"]     = { 0.86, 0.86, 0.86, 1 },
    ["text.highlight"]   = { 1, 1, 1, 1 },
    ["gtip.title"]       = { 1, 0.82, 0, 1 },
    ["gtip.value"]       = { 1, 1, 1, 1 },
    ["list.header.text"] = { 1, 0.82, 0, 1 },
    ["list.stripe"]      = { 1, 1, 1, 0.03 },
    ["list.box"]         = { 1, 1, 1, 0.06 },
    ["list.boxEdge"]     = { 1, 1, 1, 0.12 },
    ["tab.onLine"]       = { 1, 0.82, 0, 1 },
    ["icon.hot"]         = { 1, 1, 1, 1 },
    ["icon.tint"]        = { 0.7, 0.7, 0.72, 1 },
    ["btn.text"]         = { 1, 1, 1, 1 },
    ["input.bg"]         = { 0.1, 0.1, 0.12, 0.9 },
    ["input.border"]     = { 0.24, 0.24, 0.27, 0.9 },
    ["sem.modeTest"]     = { 1, 0.15, 0.15, 1 },
    ["sem.badAlt"]       = { 1, 0.25, 0.25, 1 },
    ["strip.sim"]        = { 0.35, 0.8, 1, 0.12 },
}

--- A color token's components AS A CALL SITE WRITES THEM: r, g, b for an opaque color and r, g, b,
--- a otherwise (the library's own text and vertex rule), so a site that passed three components
--- before it read a token still passes three on Ka0s Default. nil for a token the skin leaves alone.
--- Read through NS.Skin at call time, so it answers the live skin, or the host copy degraded.
function NS.SkinColor(name)
    local r, g, b, a = NS.Skin.Color(name)
    if r == nil then return nil end
    if a == nil or a == 1 then return r, g, b end
    return r, g, b, a
end

--- True while the Scope's Ignore settings panel is applied for this owner (`Skin:GetIgnore`), so
--- a raw frame the settings pages paint themselves (the Situations table's headers, labels and
--- stripes) stays as the client's panel does. False without the library or the member.
function NS.SkinPanelIgnored()
    if not Skin or type(Skin.GetIgnore) ~= "function" then return false end
    return (Skin:GetIgnore(addonName)) == true
end

--- NS.SkinColor for a surface ON THE SETTINGS PANEL: the live skin's color while the panel is
--- skinned, the Ka0s Default value (NS.SKIN_FALLBACK, same arity rule) while it is ignored. A
--- token missing from the host copy answers the skin's, as NS.SkinColor would.
function NS.SkinPanelColor(name)
    local c = NS.SkinPanelIgnored() and NS.SKIN_FALLBACK[name]
    if not c then return NS.SkinColor(name) end
    if c[4] == nil or c[4] == 1 then return c[1], c[2], c[3] end
    return c[1], c[2], c[3], c[4]
end

--- A color token as a "|cffrrggbb" escape, each channel rounded to the nearest byte, so markup a
--- call site wrote as a literal keeps its bytes on Ka0s Default. nil for a token the skin leaves
--- alone.
function NS.SkinEscape(name)
    local r, g, b = NS.Skin.Color(name)
    if r == nil then return nil end
    local function byte(v) return math.floor(v * 255 + 0.5) end
    return ("|cff%02x%02x%02x"):format(byte(r), byte(g), byte(b))
end

-- The six qualities the skin schema names (q.poor .. q.legendary); every other quality (artifact,
-- heirloom, token) is the client's color under every skin.
local QUALITY_TOKEN = { [0] = "q.poor", "q.common", "q.uncommon", "q.rare", "q.epic", "q.legendary" }

--- An item quality's r, g, b: the skin's q.* token. Ka0s Default's are the client's own colors byte
--- for byte (LibKa0s v1.81.0, SkinDefs minor 16), so the pixel is the one the addon drew before
--- skins (X1); a skin may override them for legibility (skinning-§4: the hue keeps its meaning).
--- A quality outside q.poor .. q.legendary, and the degraded facade (which carries no q.*), draw
--- the client's ITEM_QUALITY_COLORS. nil for a quality the client has no color for and no skin
--- answers, so a caller keeps its own fallback (an item link's own color code).
function NS.QualityColor(q)
    local name = QUALITY_TOKEN[q]
    if name then
        local r, g, b = NS.Skin.Color(name)
        if r ~= nil then return r, g, b end
    end
    local c = ITEM_QUALITY_COLORS and q ~= nil and ITEM_QUALITY_COLORS[q]
    if c then return c.r, c.g, c.b end
    return nil
end

--- Fill the drop tables' tones (core/Constants.lua's C.TONE) from the tokens C.TONE_TOKEN names, IN
--- PLACE: the r, g, b of each entry is its token's in the live skin, so a surface that indexes
--- C.TONE[key] at paint time draws the skin's color, and a table a file took at load stays the one
--- refilled. Run at load (both arms) and first on every OnLooksChanged, so the listeners after it,
--- every surface's repaint, read the new skin's tones. A token the skin leaves alone keeps the last.
function NS.RefillPalette()
    local C = NS.Constants
    if not (C and C.TONE_TOKEN and C.TONE) then return end
    for key, token in pairs(C.TONE_TOKEN) do
        local t = C.TONE[key]
        local r, g, b = NS.Skin.Color(token)
        if t and r ~= nil then t.r, t.g, t.b = r, g, b end
    end
end

-- Surfaces this addon paints itself (a texture, a backdrop or a string colored from a token at build),
-- each with the function that paints it: weak-keyed, so a frame the client collects drops out.
local painted = setmetatable({}, { __mode = "k" })

--- Paint `target` with `paint(target)` now, and again after every skin switch (OnLooksChanged, after
--- the palette is refilled), so a color an addon surface took at build follows the skin with no walk
--- of its own. The library's primitives record and replay themselves; this is the same for the host's
--- own calls (`tex:SetColorTexture(NS.SkinColor("list.stripe"))`). A second call on one target
--- replaces its paint. Answers `target`.
function NS.SkinPaint(target, paint)
    if type(target) ~= "table" or type(paint) ~= "function" then return target end
    painted[target] = paint
    paint(target)
    return target
end

--- Re-run every recorded host paint: the OnLooksChanged listener (live arm), and a suite's handle.
function NS.SkinRepaint()
    for target, paint in pairs(painted) do paint(target) end
end

--- The skin's monospace face as a font path: its `font.mono` key through LibSharedMedia (or the
--- shipped face of that name), else core/Constants.lua's FONT_MONO, which is that same face (Ka0s
--- Default's "JetBrains Mono") or the client's own when the library is absent. Every Ka0s skin's
--- `font.mono` carries the verdict glyphs ▲ ≈ ▼.
function NS.SkinMonoFont()
    local key = NS.Skin.Token("font.mono")
    local path
    if type(key) == "string" and key ~= "" then
        local LSM = LibStub and LibStub("LibSharedMedia-3.0", true)
        path = (LSM and LSM:Fetch("font", key, true)) or (NS.MediaFont and NS.MediaFont(key))
    end
    return path or NS.Constants.FONT_MONO
end

--- A glyph string in the skin's monospace face at `size` points, kept on a skin switch (NS.SkinPaint).
--- @param fs table a FontString
--- @param size number
function NS.SkinMono(fs, size)
    return NS.SkinPaint(fs, function(f) f:SetFont(NS.SkinMonoFont(), size, "") end)
end

NS.SKIN_SOURCE_OPTIONS = {
    { value = "ka0s", text = NS.L["Ka0s skins"] },
    { value = "eui",  text = NS.L["EllesmereUI"] },
}

-- The skin row's values: every registered skin, Ka0s Default first. Without the library the one
-- skin the degraded facade can draw.
NS.SKIN_OPTIONS = {}
if Skin and type(Skin.Skins) == "function" then
    for _, def in ipairs(Skin:Skins()) do
        NS.SKIN_OPTIONS[#NS.SKIN_OPTIONS + 1] = { value = def.key, text = def.label or def.key }
    end
end
if #NS.SKIN_OPTIONS == 0 then NS.SKIN_OPTIONS[1] = { value = DEFAULT, text = "Ka0s Default" } end

--- The schema's read, nil-safely: nil until AceDB has built the profile store.
local function stored(path)
    local S = NS.SchemaRuntime
    if not (NS.db and S and S.Get) then return nil end
    return S.Get(path)
end

--- The stored pair, lazily and nil-safely: Ka0s Default until the profile store exists.
function NS.SkinChoice()
    return stored(SOURCE_PATH) or DEFAULT, stored(SKIN_PATH) or DEFAULT
end

--- A stored override as the profile keeps it: the LSM key, or "" for the skin's own (false, nil, "").
local function storedKey(v)
    if type(v) == "string" and v ~= "" then return v end
    return ""
end

--- The write seam: every half through NS.SchemaRuntime.Set (validate, store, the [Set] line,
--- onChange). `media` is `{ font = key|false, texture = key|false }`: the Skin tab's Font and
--- texture pick and another addon's copy both hand it here, after Skin:SetOverride moved the applied
--- pair, so each row's onChange re-applies its own half as a no-op.
function NS.WriteSkinChoice(source, skin, ignore, media)
    local S = NS.SchemaRuntime
    if not (NS.db and S and S.Set) then return end
    if source ~= nil then S.Set(SOURCE_PATH, source) end
    if skin ~= nil then S.Set(SKIN_PATH, skin) end
    if type(ignore) == "table" then
        S.Set(PANEL_PATH, ignore.panel == true)
        S.Set(FONTS_PATH, ignore.fonts == true)
    end
    if type(media) == "table" then
        S.Set(FONT_PATH, storedKey(media.font))
        S.Set(TEXTURE_PATH, storedKey(media.texture))
    end
end

--- The stored overrides, nil-safely: each an LSM key, or false for the skin's own; false, false
--- until the profile store exists.
function NS.SkinOverride()
    local font, texture = storedKey(stored(FONT_PATH)), storedKey(stored(TEXTURE_PATH))
    return font ~= "" and font or false, texture ~= "" and texture or false
end

--- The stored exceptions, nil-safely: the defaults' (the settings panel left the client's, the
--- fonts skinned) until the profile store exists.
local function storedIgnore()
    if not NS.db then return true, false end
    return stored(PANEL_PATH) == true, stored(FONTS_PATH) == true
end

-- ── the first-run skin picker (LibKa0s OptionsSkinPicker 1, LibKa0s#64; the rollout's O3) ───
--
-- WHEN. Once a session, LOGIN_DELAY seconds after OnEnable (off the login spike), on a fuse
-- NS.ArmSkinPicker lights and the stand-down puts out; a session that started stood down lights it
-- at the stand-up instead. And again after every profile event (core/DropWatcher.lua's
-- reloadProfile), because a new, copied or reset profile carries its own `skin.pickerSeen`. Never
-- while the addon stands down (either hold: `disabled` or the perf capture), and never in combat: a
-- start in combat is held for core/DropWatcher.lua's PLAYER_REGEN_ENABLED edge (DW.OnCombatEnd, a
-- feature event, so it too is down while stood down), one start at most. The window's own
-- auto-open in an instance is not a trigger.
--
-- SEEN. The library calls `onClose` once per showing, by any route the player takes (Apply, its
-- close control, the gear, Escape), and once for a picker still queued behind another Ka0s addon's
-- when that addon's "Apply to all Ka0s addons" dismisses it unshown; that is the one write of
-- `skin.pickerSeen`, through NS.SchemaRuntime.Set. A close this addon makes itself
-- (NS.HideSkinPicker: the stand-down, a profile event) is not the player's and writes nothing.
--
-- PREVIEW. A pick only previews (the Skin major moves and the addon repaints); `set`
-- (NS.WriteSkinChoice) runs only on Apply, the gear or Apply to all. The close control and Escape
-- put back the stored choice as `get` reads it at the close, so the host re-applies nothing. A
-- profile event takes the picker down FIRST, before the new profile's skin is applied, so the new
-- profile's whole pair is what stays worn. The eye opens the window in test mode; the library
-- raises its DIALOG window after onPreview returns, so the HIGH window cannot cover it.
--
-- QUEUED. One picker is up at a time across every Ka0s addon: while another addon's is up,
-- O.SkinPicker queues this one and answers nil, "queued", which NS.MaybeShowSkinPicker passes
-- through; it shows when the other closes.

local PICKER_PATH = "skin.pickerSeen"
local LOGIN_DELAY = 2
local pickerHeld = false   -- a start made in combat waits for the PLAYER_REGEN_ENABLED edge
local pickerFuse           -- the login fuse while it is lit
local pickerLoginDone = false
local quietClose = false   -- true while NS.HideSkinPicker takes the picker down

-- The Options instance (settings/OptionsSetup.lua), read at call time: it is built after this file.
local function options()
    local S = NS.addon and NS.addon.Settings
    return S and S.Helpers
end

--- The eye: the window in test mode, so the player sees the skin on this addon's own frames. Test
--- mode's start opens the window itself; a mode already on only needs the window shown. A refused
--- start (combat, a simulation) prints its own line.
local function previewSkin()
    if NS.State and NS.State.testMode then
        if NS.ShowWindow then NS.ShowWindow() end
    elseif NS.SetTestMode then
        NS.SetTestMode(true)
    end
end

--- The player's close: the picker seen, and nothing else (the library's put-back wears the stored
--- choice already).
local function pickerClosed()
    if quietClose then return end
    local S = NS.SchemaRuntime
    if not (NS.db and S and S.Set) then return end
    S.Set(PICKER_PATH, true)
end

--- The spec NS.MaybeShowSkinPicker hands O.SkinPicker: this owner, its read and write seams, the
--- page key settings/Panel.lua registered and its Skin tab's key (the gear's default opens them),
--- the eye and the close.
function NS.SkinPickerSpec()
    return {
        owner = addonName, get = NS.SkinChoice, set = NS.WriteSkinChoice,
        page = "general", tab = "Appearance",
        onPreview = previewSkin, onClose = pickerClosed,
    }
end

--- True while this profile has not closed the picker and the addon stands up.
local function pickerDue()
    if not NS.db then return false end
    if NS.IsStoodDown and NS.IsStoodDown() then return false end
    return stored(PICKER_PATH) == false
end

--- Take the picker down, unmarked, with any start held for combat: the stand-down and a profile
--- event. A queued picker leaves the queue.
function NS.HideSkinPicker()
    pickerHeld = false
    local O = options()
    if not (O and type(O.HideSkinPicker) == "function") then return end
    quietClose = true
    local ok, err = pcall(O.HideSkinPicker)
    quietClose = false
    if not ok then error(err, 0) end
end

--- Show the picker when this profile has not seen it: answers O.SkinPicker's frame, or nil,
--- "queued" while another Ka0s addon's picker is up (it shows when that one closes), or nil. A
--- profile that has seen it takes a shown picker down; a start in combat is held for its end.
function NS.MaybeShowSkinPicker()
    local O = options()
    if not (O and type(O.SkinPicker) == "function") then return nil end
    if not pickerDue() then
        NS.HideSkinPicker()
        return nil
    end
    if NS.Compat and NS.Compat.InCombatLockdown() then
        pickerHeld = true
        return nil
    end
    pickerHeld = false
    return O.SkinPicker(NS.SkinPickerSpec())
end

--- The PLAYER_REGEN_ENABLED edge (DW.OnCombatEnd): a start held through combat shows now.
function NS.SkinPickerCombatEnd()
    if not pickerHeld then return nil end
    pickerHeld = false
    return NS.MaybeShowSkinPicker()
end

--- Light (`on`) or put out the session's login fuse. Lit at OnEnable and at the stand-up, once
--- a session: a fuse that already burned is not lit again. Put out at the stand-down.
function NS.ArmSkinPicker(on)
    if pickerFuse then pickerFuse:Cancel(); pickerFuse = nil end
    if not on or pickerLoginDone or not (C_Timer and C_Timer.NewTimer) then return end
    pickerFuse = C_Timer.NewTimer(LOGIN_DELAY, function()
        pickerFuse = nil
        pickerLoginDone = true
        NS.MaybeShowSkinPicker()
    end)
end

-- AceGUI keeps ONE callback per event name (options-ui-§19). Without the library's chain there is
-- no skin restore to share the release with, so the host's work takes the callback, as it did
-- before the skin engine.
local function releaseByCallback(widget, fn)
    if type(widget) ~= "table" or type(fn) ~= "function" or type(widget.SetCallback) ~= "function" then
        return nil
    end
    widget:SetCallback("OnRelease", function(w) fn(w) end)
    return fn
end

-- ── the degraded arm ─────────────────────────────────────────────────────────────────────────

if not Skin then
    local function color(name)
        local c = NS.SKIN_FALLBACK[name] or (NS.SKIN_TOKENS[name] and NS.SKIN_TOKENS[name].default)
        if c then return c[1], c[2], c[3], c[4] or 1 end
    end
    local function noop() end
    local S = { owner = addonName, apiVersion = 3, FROM_SKIN = "@skin" }
    -- Every vocabulary name answers, and a primitive with no host meaning is a no-op that never
    -- raises. The list is LibKa0s-Skin-1.0's VOCAB; tests/test_surface_parity.lua holds this table
    -- to the live facade key for key.
    for _, name in ipairs({
        "Shell", "Panel", "Inset", "FadeRegions", "FadeNineSlice", "Button", "WhiteButtonLabel",
        "StateButtonLabel", "EditBox", "Checkbox", "Dropdown", "ScrollBar", "Tab", "SetTabSelection",
        "CloseButton", "PageButton", "SquareIcon", "SortHeaderBar", "Font", "White", "ApplyBarFill",
        "GetAccentColor", "GetPanelColor", "GetFont",
        "TitleBar", "Divider", "Footer", "Card", "Slider", "NavItem", "Drawer", "ListRow", "MenuFrame",
        "Tooltip", "Strip", "Cover", "Text", "ChartStyle", "BarStyle", "IconBorder", "GlowColor",
        "BarTexture", "FontFlags", "HudFontSize",
    }) do S[name] = noop end

    S.Token = function(name)
        return NS.SKIN_FALLBACK[name] or (NS.SKIN_TOKENS[name] and NS.SKIN_TOKENS[name].default)
    end
    S.Color = color
    -- A text role (or a color token's name) as its Ka0s Default color, the face left the template's:
    -- the strings the window colors once at build keep today's colors without the library.
    local ROLE = { body = "text.body", muted = "text.muted", heading = "text.heading",
        headingAlt = "text.headingAlt", accent = "text.accent", disabled = "text.disabled", title = "title.text" }
    S.Text = function(fs, role)
        local r, g, b = color(ROLE[role] or role)
        if r ~= nil and type(fs) == "table" and fs.SetTextColor then fs:SetTextColor(r, g, b) end
    end
    -- The filter bar's flat box (modules/CompactChrome.lua): 1px WHITE8X8 in the input colors.
    S.Inset = function(f)
        if type(f) ~= "table" or not f.SetBackdrop then return end
        local white = "Interface\\Buttons\\WHITE8X8"
        f:SetBackdrop({ bgFile = white, edgeFile = white, edgeSize = 1,
                        insets = { left = 1, right = 1, top = 1, bottom = 1 } })
        f:SetBackdropColor(color("input.bg"))
        f:SetBackdropBorderColor(color("input.border"))
    end
    S.Resolve = function(kind, value, fromSkin)
        if fromSkin or value == S.FROM_SKIN then return S.Token(kind) end
        return value
    end
    S.OnLooksChanged = function(fn) return fn end   -- the skin never changes without the library
    S.IsEnabled = function() return false end
    S.GetStyle = function() return "ka0s:" .. DEFAULT end

    -- The window edge is core/CoreSetup.lua's, which degrades to nothing without the library.
    S.Shell = function(frame) if NS.ApplySkin then NS.ApplySkin(frame) end end
    S.GetPanelColor = function() return color("win.bg") end
    S.GetFont = function() return STANDARD_TEXT_FONT end
    S.ChartStyle = function() return {} end
    S.BarStyle = function() return {} end
    -- LibKa0s v1.82.0 (SkinPaintExtras minor 7): never nil, which SetFont would read as no flags or
    -- refuse as a height. A picked flag as stored, "OUTLINE" for From skin (Ka0s Default's outline,
    -- D-06); a positive size as stored, else 12.
    S.FontFlags = function(v)
        if type(v) == "string" and v ~= S.FROM_SKIN then return v end
        return "OUTLINE"
    end
    S.HudFontSize = function(size)
        local n = tonumber(size)
        return (n and n > 0) and n or 12
    end

    NS.Skin = S
    function NS.ApplySkinChoice() return false, false end
    function NS.ApplySkinIgnore() return false, false end
    function NS.ApplySkinOverride() return false end
    -- Nothing to paint an AceGUI row with: stock AceGUI, as the client draws it.
    function NS.SkinPaintAce() return false end
    function NS.SkinPaintAceTree() return 0 end
    NS.SkinOnRelease = releaseByCallback
    NS.RefillPalette()
    return
end

-- ── the live seam ────────────────────────────────────────────────────────────────────────────

NS.Skin = Skin:For(addonName)
Skin:RegisterOwner(addonName, {
    label  = NS.BRAND,
    get    = NS.SkinChoice,
    set    = NS.WriteSkinChoice,
    tokens = NS.SKIN_TOKENS,
})
-- The palette first: every surface's OnLooksChanged listener registers after this file loads, so
-- each reads the refilled tones (the library fires listeners in registration order).
NS.RefillPalette()
NS.Skin.OnLooksChanged(function()
    NS.RefillPalette()
    NS.SkinRepaint()
end)

-- The one line a reload request earns on the path that has no popup of its own (a profile event
-- or a bare `/dw set` leaving an EllesmereUI that painted this session). The Skin tab raises the
-- library's popup for its own picks.
local RELOAD_LINE = NS.L["Reload your interface (/reload) to finish changing the skin."]

-- The AceGUI rows (SkinAce.lua). Each guards on the member, so a copy whose SkinAce secondary did
-- not attach paints nothing.
function NS.SkinPaintAce(widget)
    if type(Skin.PaintAce) ~= "function" then return false end
    return Skin:PaintAce(addonName, widget)
end

function NS.SkinPaintAceTree(container)
    if type(Skin.PaintAceTree) ~= "function" then return 0 end
    return Skin:PaintAceTree(addonName, container)
end

function NS.SkinOnRelease(widget, fn)
    if type(Skin.OnRelease) ~= "function" then return releaseByCallback(widget, fn) end
    return Skin:OnRelease(widget, fn)
end

function NS.ApplySkinIgnore(panel, fonts)
    if type(Skin.SetIgnore) ~= "function" then return false, false end
    if panel == nil and fonts == nil then panel, fonts = storedIgnore() end
    local changed, reload = Skin:SetIgnore(addonName, panel, fonts)
    if reload and NS.Print then NS.Print(RELOAD_LINE) end
    return changed, reload
end

--- No argument applies the stored overrides; a nil half keeps that half, false or "" clears it
--- (the skin's own). A copy without SetOverride moves nothing.
function NS.ApplySkinOverride(font, texture)
    if type(Skin.SetOverride) ~= "function" then return false end
    if font == nil and texture == nil then font, texture = NS.SkinOverride() end
    return Skin:SetOverride(addonName, font, texture)
end

--- No argument applies the stored pair AND the stored exceptions and overrides (DW:OnInitialize,
--- the profile events); a nil half keeps that half and leaves the rest alone (each Skin tab row).
function NS.ApplySkinChoice(source, skin)
    local whole = source == nil and skin == nil
    if whole then source, skin = NS.SkinChoice() end
    local changed, reload = Skin:SetChoice(addonName, source, skin)
    if reload and NS.Print then NS.Print(RELOAD_LINE) end
    if whole then
        NS.ApplySkinIgnore()
        NS.ApplySkinOverride()
    end
    return changed, reload
end
