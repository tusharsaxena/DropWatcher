local _, NS = ...
-- core/State.lua — session-only runtime state; reset every /reload and never in SavedVariables.

NS.State = NS.State or {}
local State = NS.State

-- The debug-logging flag (debug-logging-§5): default off, independent of the console window.
-- `/dw debug on|off` and the console's own toggle write it through the DebugLog seam.
State.debug = false

-- Test mode (preview-mode, options-ui-§15): placeholder content, on until turned off, ended by
-- combat. The Master controls checkbox, the launcher entry and `/dw test` share one handler,
-- NS.SetTestMode (core/DropWatcher.lua).
State.testMode = false

-- Whether the player has the main window open this session. The window's own show decision
-- (modules/Window.lua) combines it with the General visibility setting and the stand-down latch.
State.windowOpen = false

-- The current situation key and the classifier inputs it came from (modules/Situations.lua,
-- design spec §6.1). Nil until the first re-evaluation event, and again while stood down.
State.situation = nil
State.situationInputs = nil

-- The restriction tracker's memory (modules/Restrictions.lua, design spec §4): the per-type hints
-- ADDON_RESTRICTION_STATE_CHANGED gave ({ [type value] = true }), the last PLAYER_REGEN edge (true
-- fighting, false not, nil before the first) and the answers last announced. All dropped while
-- stood down.
State.restrictionHints = nil
State.combatEdge = nil
State.restrictionSignature = nil

-- The group as modules/Roster.lua last read it (design spec §4): { byGUID, list, signature }, nil
-- until the first read and again while stood down.
State.roster = nil

-- The item facts cache (modules/ItemFacts.lua, design spec §4): { cache = { [link] = facts }, count,
-- loads = { [link] = job } }, created on first use and dropped while stood down.
State.itemFacts = nil

-- The player's gear snapshot (modules/Gear.lua, design spec §4): { equipped, owned, classFile,
-- specID, dualWield, titanGrip, loading, signature }, nil until the first read and again while
-- stood down.
State.gear = nil
