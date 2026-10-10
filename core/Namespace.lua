local addonName, NS = ...
-- core/Namespace.lua — the identity every later file reads at load: name, brand, chat tag, slash.

NS.name = addonName

-- The in-code version, the fallback NS.Version() (core/EnvSetup.lua) answers when the TOC cannot be
-- read. Bumped with the TOC by /dev-copilot:bump-version.
NS.version = "0.1.0"

-- THE BRAND NAME, in plain text. One string, read by the LDB label (launcher-§1), the Slash
-- descriptor's brandName (slash-commands-§7), the DebugLog title and the diagnostics markers
-- (debug-logging-§14). Never the TOC `## Title`, and never carrying a color escape.
NS.BRAND = "Ka0s Drop Watcher"

-- The mandatory cyan chat tag (slash-commands-§4). The cyan 00ffff is the house color.
NS.PREFIX = "|cff00ffff[DW]|r"

-- The primary chat command, with its slash, and the full-name alias (slash-commands-§3).
NS.SLASH       = "/dw"
NS.SLASH_ALIAS = "/dropwatcher"
