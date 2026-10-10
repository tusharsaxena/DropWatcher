local _, NS = ...
-- locales/enUS.lua — NS.L and its metatable fallback; the key IS the English source string.
--
-- Canonical locale (localization-§1). An unknown key answers itself, so a string added to the code
-- before it is added here still renders in English rather than as nil. Input side (localization-§4):
-- game data is matched on stable ids and tokens (itemID, classFile, specID, Enum values), never on a
-- localized display string.

local L = setmetatable({}, {
    __index = function(_, k) return k end,
})
NS.L = L

-- Chat lines and seams that degrade without the library (core/, settings/)
L["%s is unavailable: the LibKa0s library did not load."] = "%s is unavailable: the LibKa0s library did not load."
L["%s, so the debug console window is unavailable."] = "%s, so the debug console window is unavailable."
L["%s, so the perf harness is unavailable."] = "%s, so the perf harness is unavailable."
L["%s, so the settings CLI is unavailable."] = "%s, so the settings CLI is unavailable."
L["%s, so the settings panel is unavailable."] = "%s, so the settings panel is unavailable."
L["%s, so there is no minimap button and no broker plugin."] = "%s, so there is no minimap button and no broker plugin."
L["%s; running on reduced built-in fallbacks."] = "%s; running on reduced built-in fallbacks."
L["The LibKa0s library is missing from this installation of %s (expected in libs/LibKa0s)"] =
    "The LibKa0s library is missing from this installation of %s (expected in libs/LibKa0s)"

-- Slash command descriptions (settings/Slash.lua NS.COMMANDS)
L["Disable the addon"] = "Disable the addon"
L["Enable the addon"] = "Enable the addon"
L["Hide the window"] = "Hide the window"
L["List available commands"] = "List available commands"
L["List every setting and its current value"] = "List every setting and its current value"
L["List profiles, or switch to one: profile <name>"] = "List profiles, or switch to one: profile <name>"
L["Lock the window in place"] = "Lock the window in place"
L["Measure performance — `/dw perf` opens the step panel"] = "Measure performance — `/dw perf` opens the step panel"
L["Open the Ka0s Drop Watcher settings panel"] = "Open the Ka0s Drop Watcher settings panel"
L["Open/close the debug window — `/dw debug on|off` toggles logging"] = "Open/close the debug window — `/dw debug on|off` toggles logging"
L["Print a setting's current value — `/dw get <path>`"] = "Print a setting's current value — `/dw get <path>`"
L["Print the addon version"] = "Print the addon version"
L["Reset every setting to defaults"] = "Reset every setting to defaults"
L["Reset one setting to its default — `/dw reset <path>`"] = "Reset one setting to its default — `/dw reset <path>`"
L["Set a setting — `/dw set <path> <value>` (try /dw list)"] = "Set a setting — `/dw set <path> <value>` (try /dw list)"
L["Show or hide the window"] = "Show or hide the window"
L["Show the window"] = "Show the window"
L["Turn test mode on or off (placeholder drops; combat ends it)"] = "Turn test mode on or off (placeholder drops; combat ends it)"
L["Unlock the window so it can be moved and resized"] = "Unlock the window so it can be moved and resized"
L["Write the diagnostics report to the debug console"] = "Write the diagnostics report to the debug console"

-- Minimum quality (modules/QualityGate.lua): the quality names and the filter bar label
L["Artifact"] = "Artifact"
L["Common"] = "Common"
L["Epic"] = "Epic"
L["Heirloom"] = "Heirloom"
L["Legendary"] = "Legendary"
L["Poor"] = "Poor"
L["Quality: %s+"] = "Quality: %s+"
L["Quality: Match gear"] = "Quality: Match gear"
L["Quality: Match gear (%s+)"] = "Quality: Match gear (%s+)"
L["Quality: Match slot"] = "Quality: Match slot"
L["Rare"] = "Rare"
L["Uncommon"] = "Uncommon"

-- The feed's group labels (modules/LootFeed.lua)
L["Encounter"] = "Encounter"
L["Encounter %s"] = "Encounter %s"
L["Open world"] = "Open world"

-- The trade timer's warning (modules/TradeTimer.lua)
L["%s: %d min left to trade it."] = "%s: %d min left to trade it."

-- Settings panel, window and chat acknowledgments
L["Debug console"] = "Debug console"
L["Diagnostic report written to the debug console: %d lines. Use Copy to share it."] =
    "Diagnostic report written to the debug console: %d lines. Use Copy to share it."
L["General"] = "General"
L["No drops yet. Loot your group receives appears here."] = "No drops yet. Loot your group receives appears here."
L["Profiles"] = "Profiles"
L["Reset every %s setting to its default. Asks for confirmation."] = "Reset every %s setting to its default. Asks for confirmation."
L["Reset this profile to the addon's defaults? Everything you have configured in it is discarded \226\128\148 your other profiles are not affected."] =
    "Reset this profile to the addon's defaults? Everything you have configured in it is discarded \226\128\148 your other profiles are not affected."
L["Settings panel is not available."] = "Settings panel is not available."
L["Slash Commands"] = "Slash Commands"
L["TEST MODE: placeholder drops, nothing is sent"] = "TEST MODE: placeholder drops, nothing is sent"
L["Test mode ended: you entered combat."] = "Test mode ended: you entered combat."
L["Test mode is not available in combat."] = "Test mode is not available in combat."
L["all settings reset to defaults"] = "all settings reset to defaults"
L["debug logging |cff40ff40ON|r"] = "debug logging |cff40ff40ON|r"
L["debug logging |cffff4040OFF|r"] = "debug logging |cffff4040OFF|r"
L["unknown command '%s'"] = "unknown command '%s'"
L["v%s slash commands"] = "v%s slash commands"
L["window locked"] = "window locked"
L["window position reset"] = "window position reset"
L["window unlocked"] = "window unlocked"
L["|cffFFFF00%s|r takes a setting path: |cffFFFF00%s|r (try |cffFFFF00%s|r). To reset everything: |cffFFFF00%s|r."] =
    "|cffFFFF00%s|r takes a setting path: |cffFFFF00%s|r (try |cffFFFF00%s|r). To reset everything: |cffFFFF00%s|r."
