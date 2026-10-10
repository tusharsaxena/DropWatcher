-- tests/test_vendor_sync.lua — the vendored-payload gate (testing-§11), delegated to the kit.
--
-- libs/LibKa0s/ and tests/_kit/ must be byte-identical to what LibKa0s published at the tag the
-- root CLAUDE.md provenance line names, and the runner must be recorded 100755 in the git index.
-- The comparison is the kit's; nothing is reimplemented here.

local VendorSync = dofile("tests/_kit/vendor_sync.lua")

VendorSync.register(_G.DW_TEST, {})
