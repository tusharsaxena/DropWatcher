-- tests/test_offspec.lua — the off-spec pass's gate in this addon (feedback-19 spec §0, clients-§4):
-- Retail's alone, through C.FEATURE.offSpec, with its rows, template and words. The pass itself is
-- LibKa0s-Verdict-1.0's (its OffSpec, the library's own suite); core/VerdictViews.lua's NS.OffSpec and
-- NS.Evaluate are what this addon reaches it by.

local T = _G.DW_TEST
local test, assertEqual, assertTrue = T.test, T.assertEqual, T.assertTrue

local cached
local function load()
    if not cached then
        -- Off-spec is Retail's spec model (Forever's spec is class-wide): Retail's list, pinned.
        local NS = T.retailList((T.newAddon()))
        cached = { E = NS.Evaluate, C = NS.Constants, OS = NS.OffSpec }
    end
    return cached.E, cached.C, cached.OS
end

local _, C0 = load()
local S, W, IC = C0.SLOT, C0.WEAPON_SUBCLASS, C0.ITEM_CLASS
local STR, INT = "ITEM_MOD_STRENGTH_SHORT", "ITEM_MOD_INTELLECT_SHORT"
local HOLY, PROT, RET = 65, 66, 70

local function item(ilvl, equipLoc, classID, subClassID, over)
    local f = { itemID = 1000, ilvl = ilvl, equipLoc = equipLoc, classID = classID, subClassID = subClassID }
    for k, v in pairs(over or {}) do f[k] = v end
    return f
end

-- The Crescent: an Intellect one-handed axe.
local function intAxe(ilvl) return item(ilvl, "INVTYPE_WEAPON", IC.WEAPON, W.AXE_1H, { stats = { [INT] = 100 } }) end
local function strSword(ilvl) return item(ilvl, "INVTYPE_WEAPON", IC.WEAPON, W.SWORD_1H, { stats = { [STR] = 100 } }) end

-- A paladin of `specID` wearing a Strength sword; `bySpec` is each other spec's gear, and every call
-- to offSpecGear is counted in `calls`.
local function paladin(specID, bySpec, over)
    local calls = {}
    local c = {
        classFile = "PALADIN", specID = specID, gear = { [S.MAINHAND] = strSword(600), [S.OFFHAND] = false },
        offSpecGear = function(x)
            calls[#calls + 1] = x
            return bySpec[x]
        end,
    }
    for k, v in pairs(over or {}) do c[k] = v end
    return c, calls
end

-- ---------------------------------------------------------------------------------------------
-- Per client (Forever port design §4.4, clients-§4, §6)
-- ---------------------------------------------------------------------------------------------

test("offspec: Enabled(client) answers per client; the module's gate is C.FEATURE.offSpec (clients-§4)", function()
    local NS = T.newAddon()
    -- red under: an off-spec gate fixed by the file-load client alone (Item Search split plan, A2)
    assertTrue(NS.OffSpec.Enabled("retail"), "Retail's")
    assertEqual(NS.OffSpec.Enabled("forever"), false, "never Forever's")
    assertEqual(NS.OffSpec.Enabled(nil), false, "no client: none")
    assertEqual(NS.OffSpec.Initialized(), NS.Constants.FEATURE.offSpec == true, "gated through ForClient")
    assertEqual(NS.OffSpec.Enabled(NS.Compat.ClientKey()), NS.Constants.FEATURE.offSpec == true, "the two agree")
end)

-- Off-spec is Retail's alone: WoW Forever's spec is class-wide, so there is no other spec to judge.
-- On Forever the module is not initialized (no off-spec pass, even on Retail's spec model, and no
-- off-spec gear on a candidate), the off-spec glow and the askOffSpec template have no row, there is
-- no askOffSpec template, and no column tip or note speaks of it. On Retail each is there.
test("offspec: not initialized, no rows, no askOffSpec on Forever", function()
    local NS = T.retailList((T.enableAddon()))
    local retail = NS.Compat.ClientKey() == "retail"
    assertEqual(NS.OffSpec.Initialized(), retail, "the module")
    local c = paladin(PROT, { [HOLY] = { [S.MAINHAND] = false }, [RET] = { [S.MAINHAND] = strSword(600) } })
    local res = NS.Evaluate.Evaluate(intAxe(650), c, { sidegradeBand = 2 })
    assertEqual(type(res.offSpec) == "table", retail, "the off-spec pass")
    assertEqual(type(NS.Gear.Candidate().offSpecGear) == "function", retail, "your candidate's off-spec gear")
    local templates = {}
    for _, name in ipairs(NS.Constants.MESSAGE_TEMPLATES) do templates[name] = true end
    assertEqual(templates.askOffSpec == true, retail, "the askOffSpec template")
    local d = { me = { verdict = "cantUse", reasons = {}, offSpec = { specID = HOLY, verdict = "upgrade", ilvlDelta = 5 } } }
    assertEqual(NS.Messaging.AskTemplate(d, false), retail and "askOffSpec" or nil, "never the askOffSpec ask on Forever")
    local rows = NS.SchemaRuntime
    assertEqual(rows.FindRow("messages.templates.askOffSpec") ~= nil, retail, "the template's row")
    assertEqual(rows.FindRow("glow.offSpec.enabled") ~= nil, retail, "the off-spec glow's row")
    assertEqual(NS.OffSpecCells.Legend() ~= nil, retail, "the Cyan legend row")
    local function said(tip)
        local text = type(tip) == "table" and T.tipPlainJoined(tip) or tostring(tip or "")
        return text:find("off-spec", 1, true) ~= nil or text:find("Cyan", 1, true) ~= nil
    end
    local me
    for _, col in ipairs(NS.WindowGroup.COLUMNS) do if col.key == "me" then me = col end end
    assertEqual(said(me.tip) or said(me.desc), retail, "the Me column's tip and description")
    local eq
    for _, col in ipairs(NS.OfferPanel.COLS) do if col.key == "eq" then eq = col end end
    assertEqual(said(eq.tip), retail, "the Offer panel's Their eq tip")
    assertEqual(said(NS.OfferPanel.ORDER_TIP), retail, "the Offer panel's order note")
end)
