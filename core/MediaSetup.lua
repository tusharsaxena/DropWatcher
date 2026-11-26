local addonName, NS = ...
-- core/MediaSetup.lua — NS.Icon / NS.MediaFont from LibKa0s-Media-1.0 and the one RegisterLSM call.
--
-- The icon catalog, the monospace face and the bar textures ship inside the vendored payload
-- (library-stack-§8). Every call passes the addon's own FOLDER name: the library is vendored and
-- cannot know which folder it was copied into, and a wrong texture path draws nothing and raises
-- nothing. Loads before core/Constants.lua, which resolves FONT_MONO from NS.MediaFont at load.

local Media = LibStub and LibStub("LibKa0s-Media-1.0", true)

--- The texture path for one shipped icon, or nil (library absent, or no such name). Nil is a real
--- answer: the caller draws something else.
--- @param name string  an entry of the library's icon catalog, e.g. "close"
--- @return string|nil
function NS.Icon(name)
    if not Media then return nil end
    return Media.Icon(addonName, name)
end

--- The path of one shipped face, or nil when the library is absent.
--- @param name string  a key of the library's font list, e.g. "JetBrains Mono"
--- @return string|nil
function NS.MediaFont(name)
    if not Media then return nil end
    return Media.Font(addonName, name)
end

--- The path of one shipped background (the library's `BACKGROUNDS`, e.g. "Ka0s Glass", the verdict
--- badge's rounded fill, R5-DW-02), or nil when the library is absent.
--- @param name string
--- @return string|nil
function NS.MediaBackground(name)
    if not Media or type(Media.Background) ~= "function" then return nil end
    return Media.Background(addonName, name)
end

-- At FILE LOAD, not PLAYER_LOGIN: LibSharedMedia is vendored under libs/ and has already run.
if Media then Media.RegisterLSM(addonName) end
