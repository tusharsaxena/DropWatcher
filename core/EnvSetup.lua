local addonName, NS = ...
-- core/EnvSetup.lua — NS.Meta and NS.Version from LibKa0s-Env-1.0 (library-stack-§7).
--
-- The addon reads its own TOC (version, notes) through the Env major. The library is told the
-- FOLDER name, the first vararg, never the ## Title.

local Env = LibStub and LibStub("LibKa0s-Env-1.0", true)

--- One field of this addon's TOC, or nil.
--- @param field string  "Version", "Title", "Notes", ...
--- @return string|nil
function NS.Meta(field)
    if Env then return Env.GetAddOnMetadata(addonName, field) end
    if C_AddOns and C_AddOns.GetAddOnMetadata then
        return C_AddOns.GetAddOnMetadata(addonName, field)
    end
    return nil
end

--- This addon's version, preferring the TOC over the in-code constant (core/Namespace.lua).
--- Never nil.
--- @return string
function NS.Version()
    local fallback = NS.version
    if Env then return Env.Version(addonName, fallback) or "?" end
    return NS.Meta("Version") or fallback or "?"
end
