local _, NS = ...
-- settings/SchemaSetup.lua — Settings.SchemaLib: LibKa0s-Schema-1.0, or the host's stub of it.
--
-- settings/Schema.lua builds the one write seam with Settings.SchemaLib:New{...}. With the library
-- present that is the library. Without it, HostSchemaStub answers the same members with the plain
-- read / write / validate / normalize / onChange path, so the host verbs and the stored profile keep
-- working on a library-absent install; the bulk bracket and the reset counter degrade to no-ops.
--
-- A DELIBERATE, DOCUMENTED DUPLICATION: LibKa0s docs/api/Schema/version-2-docs.md, "The degradation
-- stub" (write-completing and log-silent), trimmed to what this addon calls. It honors the same
-- `writeThrough` list the live instance takes (options-ui-§1 route (a)): `/dw enable`, `disable`,
-- `lock` and `unlock` write the composed Master controls rows, which do not exist on a load where
-- the composers are hollow. tests/test_surface_parity.lua pins both surfaces.
local DW = NS.addon
DW.Settings = DW.Settings or {}
local Settings = DW.Settings
local BRAND = NS.BRAND
local HostSchemaStub = {}
local function copy(v)
    if type(v) ~= "table" then return v end
    local out = {}
    for k, x in pairs(v) do out[k] = copy(x) end
    return out
end
function HostSchemaStub.SplitPath(path)
    local parts = {}
    if path ~= nil then
        for seg in tostring(path):gmatch("[^%.]+") do parts[#parts + 1] = seg end
    end
    return parts
end
local function partsOf(p) return type(p) == "table" and p or HostSchemaStub.SplitPath(p) end
function HostSchemaStub.Read(root, p, first)
    local parts, node = partsOf(p), root
    first = first or 1
    if type(root) ~= "table" or #parts < first then return nil end
    for i = first, #parts do
        if type(node) ~= "table" then return nil end
        node = node[parts[i]]
    end
    return node
end
function HostSchemaStub.Write(root, p, value, first)
    local parts, node = partsOf(p), root
    first = first or 1
    if type(root) ~= "table" or #parts < first then return end
    for i = first, #parts - 1 do
        if type(node[parts[i]]) ~= "table" then node[parts[i]] = {} end
        node = node[parts[i]]
    end
    node[parts[#parts]] = value
end
function HostSchemaStub.SameValue(a, b)
    if a == b then return true end
    if type(a) ~= "table" or type(b) ~= "table" then return false end
    for k, v in pairs(a) do if not HostSchemaStub.SameValue(v, b[k]) then return false end end
    for k in pairs(b) do if a[k] == nil then return false end end
    return true
end
local function addReads(S, d, rows)
    local function resolve(parts, id)
        if type(d.resolveRoot) ~= "function" then return nil end
        return d.resolveRoot(parts, id)
    end
    function S.AllRows() return rows end
    function S.FindRow(path)
        if type(path) ~= "string" then return nil end
        for _, row in ipairs(rows) do
            if type(row) == "table" and row.path == path then return row end
        end
    end
    function S.AddRows(list, at)
        if type(list) ~= "table" then return 0 end
        at = type(at) == "number" and math.floor(at) or #rows + 1
        if at > #rows + 1 then at = #rows + 1 elseif at < 1 then at = 1 end
        for i, row in ipairs(list) do table.insert(rows, at + i - 1, row) end
        return #list
    end
    function S.Reindex() end
    function S.Get(path, id)
        local row = S.FindRow(path)
        if row and type(row.get) == "function" then return row.get(id) end
        if type(path) ~= "string" or (row and row.sessionOnly) then return nil end
        local parts = HostSchemaStub.SplitPath(path)
        local root, first = resolve(parts, id)
        if type(root) ~= "table" then return nil end
        return HostSchemaStub.Read(root, parts, first)
    end
    return resolve
end
local function writeThroughRows(d)
    local out = {}
    for _, path in ipairs(type(d.writeThrough) == "table" and d.writeThrough or {}) do
        if type(path) == "string" and path ~= "" then out[path] = { path = path, writeThrough = true } end
    end
    return out
end
-- The row's validate, then its normalize, in the seam's order; the normalized value replaces w.value.
local function checkValue(w)
    local row = w.row
    if type(row.validate) == "function" then
        local ok, why = row.validate(w.value, w.rid)
        if not ok then return false, why end
    end
    if type(row.normalize) == "function" then
        local out, why = row.normalize(w.value, w.rid)
        if out == nil then return false, why end
        w.value = out
    end
    return true
end
local function addWrites(S, d, resolve)
    local through = writeThroughRows(d)
    local function prepare(path, value, id)
        local row = S.FindRow(path) or through[path]
        if not row then return nil, BRAND .. ": no setting " .. tostring(path) end
        local w = { row = row, path = path, value = value, rid = id }
        w.stored = type(row.set) ~= "function" and not row.sessionOnly
        if w.stored then
            w.parts = HostSchemaStub.SplitPath(path)
            local r, f, got = resolve(w.parts, id)
            if type(r) == "table" then w.root, w.first = r, f end
            if got ~= nil then w.rid = got end
        end
        local ok, why = checkValue(w)
        if not ok then return nil, BRAND .. ": invalid value for " .. path, why end
        if w.stored and not w.root then return nil, BRAND .. ": nowhere to store " .. path end
        return w
    end
    local function store(w)
        if type(w.row.set) == "function" then
            w.row.set(w.value)
        elseif w.stored then
            HostSchemaStub.Write(w.root, w.parts, copy(w.value), w.first)
        end
    end
    local function react(w)
        if type(w.row.onChange) == "function" then w.row.onChange(w.value, w.rid) end
    end
    function S.Set(path, value, id)
        local w, err, why = prepare(path, value, id)
        if not w then return false, err, why end
        store(w)
        react(w)
        if type(d.announce) == "function" then d.announce(w.row, path, w.value, w.rid) end
        return true
    end
    -- Phase 1 of a batch: every entry prepared, nothing stored; the first refusal and its index.
    local function prepareAll(entries, id)
        local ws = {}
        for i, e in ipairs(type(entries) == "table" and entries or {}) do
            if type(e) ~= "table" then e = {} end
            local w, err, why = prepare(e.path, e.value, id)
            if not w then return nil, err, why, i end
            ws[i] = w
        end
        return ws
    end
    function S.SetMany(entries, opts)
        local id = type(opts) == "table" and opts.instanceId or nil
        local ws, err, why, index = prepareAll(entries, id)
        if not ws then return false, err, why, index end
        for _, w in ipairs(ws) do store(w) end
        for _, w in ipairs(ws) do react(w) end
        if #ws > 0 and type(d.announce) == "function" then
            for _, w in ipairs(ws) do d.announce(w.row, w.path, w.value, w.rid) end
        end
        return true
    end
end
local function addBracket(S, d)
    local depth = 0
    function S.Default(path)
        local row = S.FindRow(path)
        return row and copy(row.default)
    end
    function S.ApplyDefault(row, id)
        if type(row) ~= "table" or type(row.path) ~= "string" or row.default == nil then
            return false
        end
        local exempt = d.resetExempt
        if depth > 0 and type(exempt) == "table" and exempt[row.path] then return false end
        return S.Set(row.path, copy(row.default), id)
    end
    function S.BulkBegin() depth = depth + 1 end
    function S.BulkEnd() if depth > 0 then depth = depth - 1 end end
    function S.BulkRun(act, scope, fn)
        S.BulkBegin(act, scope)
        local ok, err = pcall(fn, { profileReset = false })
        S.BulkEnd(act, scope)
        if not ok then error(err, 0) end
    end
    function S.BulkAdd() end
    function S.InBulk() return depth > 0 end
    function S.CountOffDefault() return 0 end
    function S.ResetCounted(fn) fn() end
    function S.ConsumeResetCount() return nil end
    function S.Validate()
        if type(d.print) == "function" then
            d.print(BRAND .. ": LibKa0s-Schema-1.0 is missing, so the schema was not checked")
        end
        return 0, 0, 0
    end
end
function HostSchemaStub.New(_, d)
    local S = {}
    local rows = d.rows
    local resolve = addReads(S, d, rows)
    addWrites(S, d, resolve)
    addBracket(S, d)
    return S
end
Settings.SchemaLib = LibStub and LibStub("LibKa0s-Schema-1.0", true) or HostSchemaStub
