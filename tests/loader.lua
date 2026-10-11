-- tests/loader.lua
--
-- The instance factory: builds one fully ISOLATED addon in a fresh mock environment and returns
-- `(NS, env, mock)`, where `env` and `mock` are the same table (tests/wow_mock.lua sets `_G` to
-- itself). The sandbox, the TOC reader and the XML reader come from the shared kit (testing-§9);
-- what stays here is isolation, because nearly every case builds a fresh addon so no file-local
-- state leaks between cases. Chunks are compiled once and re-run per instance.

local Loader = dofile("tests/_kit/loader.lua")

local ADDON = "DropWatcher"

-- Every file of libs/LibKa0s/LibKa0s.xml, in XML order, READ from the XML rather than remembered:
-- the TOC pulls them in through the .xml, which tocFiles cannot see, and a module missing its floor
-- dependency silently leaves the host measuring its own degradation stub (testing-§9,
-- anti-pattern #48).
local LIBKA0S = Loader.xmlFiles("libs/LibKa0s/LibKa0s.xml")

-- Mock fields a factory's `opts` may seed before any source loads (see tests/wow_mock.lua).
local MOCK_OPTS = { "inCombat" }

return function(root, mockBuilder)
    local function abs(rel) return root .. "/" .. rel end

    -- The addon's own files, in TOC order, derived rather than restated.
    local tocFiles = Loader.tocFiles(abs(ADDON .. ".toc"))

    local sources = {}
    for _, rel in ipairs(LIBKA0S) do sources[#sources + 1] = { path = rel, lib = true } end
    for _, rel in ipairs(tocFiles) do sources[#sources + 1] = { path = rel, lib = false } end

    local compiled = {}
    local function chunkFor(rel)
        local c = compiled[rel]
        if c == nil then
            local err
            c, err = loadfile(abs(rel))
            if not c then error(("loadfile(%s) failed: %s"):format(rel, tostring(err))) end
            compiled[rel] = c
        end
        return c
    end

    --- Build one instance.
    ---   opts.skip      = { "<relative path>", ... } omits those files: the degraded-install cases
    ---                    load the addon with the library genuinely ABSENT (testing-§8).
    ---   opts.mock      = function(mock) end runs against the fresh mock before any source loads.
    ---   opts.<field>   for each MOCK_OPTS name, seeds that mock field.
    local function build(opts)
        opts = opts or {}
        local skipSet = {}
        for _, rel in ipairs(opts.skip or {}) do skipSet[rel] = true end

        local mock = mockBuilder()
        for _, k in ipairs(MOCK_OPTS) do
            if opts[k] ~= nil then mock[k] = opts[k] end
        end
        if type(opts.mock) == "function" then opts.mock(mock) end
        local env = Loader.makeEnv(mock)
        local NS  = {}

        -- The kit's AceDB fake resolves a SavedVariables NAME against the real _G, so a previous
        -- instance's saved tables would otherwise be adopted by this one.
        _G.DropWatcherDB, _G.DropWatcherPerfDB = nil, nil

        for _, src in ipairs(sources) do
            if not skipSet[src.path] then
                local chunk = chunkFor(src.path)
                setfenv(chunk, env)
                if src.lib then chunk() else chunk(ADDON, NS) end
            end
        end

        return NS, mock, mock
    end

    return setmetatable({
        sources  = sources,
        tocFiles = tocFiles,
        libFiles = LIBKA0S,
        root     = root,
    }, { __call = function(_, opts) return build(opts) end })
end
