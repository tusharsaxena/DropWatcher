-- tests/test_vendor_sync.lua — the vendored-payload gate (testing-§11), delegated to the kit.
--
-- libs/LibKa0s/ and tests/_kit/ must be byte-identical to what LibKa0s published at the tag the
-- root CLAUDE.md provenance line names, and the runner must be recorded 100755 in the git index.
-- The comparison is the kit's; nothing is reimplemented here. The icon folder is held to the
-- `LibKa0s icons:` declaration directly under the provenance line.
--
-- PRE-TAG (until the Item Search split's close-out, IS-G1): the payloads were vendored from the
-- LibKa0s release branch at v1.119.0 before its tag exists. While ../LibKa0s is checked out but
-- does not carry the provenance tag yet, the two payload cases are declared skips (registered with
-- their reason, so the inventory counts them as skips) saying the tag is missing, so the payload
-- was NOT compared, and only the runner case runs through the kit. Once the tag exists the kit registers all three with its defaults, with no edit here;
-- the close-out drops this pre-tag branch after the re-vendor check passes. An absent checkout
-- is the kit's own skip, with the kit's own reason.
local VendorSync = dofile("tests/_kit/vendor_sync.lua")
local T = _G.DW_TEST

local SIBLING = "./../LibKa0s"

--- Whether a ref resolves in the sibling checkout: true or false, or nil when git cannot be asked.
local function resolves(ref)
    if not io.popen then return nil end
    local pipe = io.popen(('git -C "%s" cat-file -e "%s" 2>/dev/null && echo yes'):format(SIBLING, ref), "r")
    if not pipe then return nil end
    local out = pipe:read("*a") or ""
    pipe:close()
    return out:find("yes", 1, true) ~= nil
end

--- The tag the CLAUDE.md provenance line names, in the kit's own pattern.
local function provenanceTag()
    local f = io.open("CLAUDE.md", "rb")
    if not f then return nil end
    local doc = f:read("*a")
    f:close()
    return doc:match("[Bb]undles %[LibKa0s%]%b() (v[%d%.]+)")
end

local tag = provenanceTag()
local preTag = tag ~= nil and resolves("HEAD:LibKa0s/Core.lua") == true
    and resolves(tag .. ":LibKa0s/Core.lua") == false

if preTag then
    VendorSync.register(T, { pairs = {} })
    local reason = ("LibKa0s %s is not tagged yet in %s (pre-tag until IS-G1) — the vendored "
        .. "payload was NOT compared"):format(tag, SIBLING)
    -- declared skips (the kit's third argument): known at load, so `--list` counts them as skips,
    -- never in the passed figure or the total (testing-§5)
    local function never() end
    T.test("libs/LibKa0s is the LibKa0s release CLAUDE.md says this addon bundles", never, reason)
    T.test("tests/_kit is the test kit that shipped with that release", never, reason)
else
    VendorSync.register(T, {})
end
