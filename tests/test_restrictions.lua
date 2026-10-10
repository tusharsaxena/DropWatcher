-- tests/test_restrictions.lua — modules/Restrictions.lua (design spec §4): the four answers
-- (CanSendChat, CanInspect, CanTrade, ActiveReason) from the restriction event's hints, the
-- client's restriction and chat-lockdown answers and the combat edges; RESTRICTION_CHANGED; the
-- secret payloads; and the stand-down.

local T = _G.DW_TEST
local test, assertEqual, assertTrue, assertFalse, assertNil =
    T.test, T.assertEqual, T.assertTrue, T.assertFalse, T.assertNil

local EVENT = "ADDON_RESTRICTION_STATE_CHANGED"

-- An enabled instance with a receiver recording every RESTRICTION_CHANGED as { reason, canSend }.
local function live()
    local NS, _, m = T.enableAddon()
    local heard = {}
    local rx = NS.Bus:NewTarget()
    rx:RegisterMessage(NS.MSG.RESTRICTION_CHANGED, function(_, reason, canSend)
        heard[#heard + 1] = { reason, canSend }
    end)
    return NS, m, heard, m.Enum.AddOnRestrictionType, m.Enum.AddOnRestrictionState
end

-- The kit's secret simulator, installed on the client so the guards see it.
local function installSecrets(m)
    m.issecretvalue = T.isSecret
    m.canaccessvalue = function(v) return not T.isSecret(v) end
end

local function answers(R)
    return ("%s %s %s %s"):format(tostring(R.ActiveReason()), tostring(R.CanSendChat()),
        tostring(R.CanInspect()), tostring(R.CanTrade()))
end

test("restrictions: nothing restricted, everything allowed and nothing announced", function()
    local NS, m, heard = live()
    assertEqual(answers(NS.Restrictions), "nil true true true")
    assertTrue(m.__fire(EVENT, 4, 0) > 0, "the event is registered")
    assertEqual(#heard, 0)
end)

test("restrictions: an encounter stops chat and is the reason; its lift is announced", function()
    local NS, m, heard, RT, RS = live()
    m.__fire(EVENT, RT.Encounter, RS.Activating)
    assertEqual(answers(NS.Restrictions), "encounter false true true", "Activating counts at once")
    assertEqual(#heard, 1)
    assertEqual(heard[1][1], "encounter"); assertFalse(heard[1][2])
    m.restrictionStates[RT.Encounter] = RS.Active
    m.__fire(EVENT, RT.Encounter, RS.Active)
    assertEqual(#heard, 1, "no change, no message")
    m.restrictionStates[RT.Encounter] = nil
    m.__fire(EVENT, RT.Encounter, RS.Inactive)
    assertEqual(answers(NS.Restrictions), "nil true true true")
    assertEqual(#heard, 2)
    assertNil(heard[2][1]); assertTrue(heard[2][2], "the lift says chat may be sent")
end)

test("restrictions: a lift the client does not confirm yet keeps the restriction", function()
    local NS, m, _, RT, RS = live()
    m.restrictionStates[RT.Encounter] = RS.Active
    m.__fire(EVENT, RT.Encounter, RS.Inactive)
    assertFalse(NS.Restrictions.CanSendChat(), "the client still says Active")
    m.restrictionStates[RT.Encounter] = nil
    assertTrue(NS.Restrictions.CanSendChat(), "read live, so the next ask sees the lift")
end)

test("restrictions: the event's boolean payload is read too", function()
    local NS, m, heard, RT = live()
    m.__fire(EVENT, RT.ChallengeMode, true)
    assertEqual(NS.Restrictions.ActiveReason(), "challengeMode")
    m.__fire(EVENT, RT.ChallengeMode, false)
    assertNil(NS.Restrictions.ActiveReason())
    assertEqual(#heard, 2)
end)

test("restrictions: each type gives its reason; Map blocks nothing", function()
    local NS, m, _, RT, RS = live()
    local R = NS.Restrictions
    local CASES = {
        { "Encounter", "encounter false true true" },
        { "ChallengeMode", "challengeMode false true true" },
        { "PvPMatch", "pvpMatch false true true" },
        { "Chat", "chat false true true" },
        { "Combat", "combat true false false" },
        { "Map", "nil true true true" },
    }
    for _, c in ipairs(CASES) do
        m.restrictionStates = { [RT[c[1]]] = RS.Active }
        assertEqual(answers(R), c[2], c[1])
    end
    m.restrictionStates = { [RT.Map] = RS.Active }
    assertTrue(R.ActiveSet().map, "Map is tracked for the report")
end)

test("restrictions: the reason is the highest in priority", function()
    local NS, m, _, RT, RS = live()
    local R = NS.Restrictions
    m.restrictionStates = { [RT.Combat] = RS.Active, [RT.Chat] = RS.Active, [RT.Encounter] = RS.Active }
    assertEqual(R.ActiveReason(), "encounter")
    m.restrictionStates[RT.Encounter] = nil
    assertEqual(R.ActiveReason(), "chat")
    m.restrictionStates[RT.Chat] = nil
    m.chatLockdown = true
    assertEqual(R.ActiveReason(), "chatLockdown")
    m.chatLockdown = false
    assertEqual(R.ActiveReason(), "combat")
end)

test("restrictions: a type the client adds later is reported by name and blocks nothing", function()
    local NS, m, _, RT, RS = live()
    RT.Housing = 9
    m.restrictionStates[9] = RS.Active
    assertTrue(NS.Restrictions.ActiveSet().Housing)
    assertEqual(answers(NS.Restrictions), "nil true true true")
end)

test("restrictions: the chat lockdown stops chat, a secret answer too", function()
    local NS, m = live()
    installSecrets(m)
    m.chatLockdown = true
    assertEqual(answers(NS.Restrictions), "chatLockdown false true true")
    m.chatLockdown = T.secret(false)
    assertFalse(NS.Restrictions.CanSendChat(), "a secret lockdown reads as locked")
    m.chatLockdown = false
    assertTrue(NS.Restrictions.CanSendChat())
end)

test("restrictions: the combat edges stop inspect and trade, ahead of the client's flag", function()
    local NS, m, heard = live()
    local R = NS.Restrictions
    m.inCombat = false
    assertTrue(m.__fire("PLAYER_REGEN_DISABLED") > 0)
    assertEqual(answers(R), "combat true false false", "the edge wins over a lagging flag")
    assertEqual(#heard, 1)
    assertEqual(heard[1][1], "combat"); assertTrue(heard[1][2], "combat alone leaves chat open")
    m.inCombat = true
    m.__fire("PLAYER_REGEN_ENABLED")
    assertEqual(answers(R), "nil true true true")
    assertEqual(#heard, 2)
end)

test("restrictions: before any edge, the client's combat flag decides", function()
    local NS, m = live()
    m.inCombat = true
    assertFalse(NS.Restrictions.CanInspect())
    assertFalse(NS.Restrictions.CanTrade())
end)

test("restrictions: combat under an encounter announces the change of what is allowed", function()
    local NS, m, heard, RT, RS = live()
    m.__fire(EVENT, RT.Encounter, RS.Active)
    m.__fire("PLAYER_REGEN_DISABLED")
    assertEqual(#heard, 2, "the reason stays encounter, but inspect and trade closed")
    assertEqual(heard[2][1], "encounter")
    assertFalse(NS.Restrictions.CanInspect())
    m.__fire("PLAYER_REGEN_ENABLED")
    assertEqual(#heard, 3)
end)

test("restrictions: a secret payload never raises; a secret state reads as active", function()
    local NS, m, heard, RT = live()
    installSecrets(m)
    m.__fire(EVENT, RT.Encounter, T.secret(0))
    assertEqual(NS.Restrictions.ActiveReason(), "encounter")
    m.__fire(EVENT, T.secret(RT.Chat), T.secret(2))
    assertEqual(NS.Restrictions.ActiveReason(), "encounter", "a secret type keys no hint")
    m.__fire(EVENT, nil, nil)
    assertEqual(#heard, 1)
end)

test("restrictions: a client without the restriction APIs restricts nothing but combat", function()
    local NS, m = live()
    m.C_RestrictedActions, m.Enum.AddOnRestrictionType = nil, nil
    m.C_ChatInfo = nil
    assertEqual(answers(NS.Restrictions), "nil true true true")
    m.__fire("PLAYER_REGEN_DISABLED")
    assertEqual(NS.Restrictions.ActiveReason(), "combat")
end)

test("restrictions: Refresh announces a lift no event reported", function()
    local NS, m, heard = live()
    m.chatLockdown = true
    assertTrue(NS.Restrictions.Refresh("ENCOUNTER_END"))
    m.chatLockdown = false
    assertTrue(NS.Restrictions.CanSendChat())
    assertTrue(NS.Restrictions.Refresh("ENCOUNTER_END"))
    assertEqual(#heard, 2)
    assertFalse(NS.Restrictions.Refresh("ENCOUNTER_END"), "nothing moved")
end)

test("restrictions: stood down, nothing is heard; the stand-up announces what is in effect", function()
    local NS, m, heard, RT, RS = live()
    m.__fire(EVENT, RT.Encounter, RS.Active)
    NS.addon:OnSlashCommand("disable")
    assertNil(NS.State.restrictionHints, "the stand-down drops the stale hints")
    assertNil(NS.State.restrictionSignature)
    assertEqual(m.__fire(EVENT, RT.Chat, RS.Active), 0, "the event is down")
    m.restrictionStates[RT.Chat] = RS.Active
    local before = #heard
    NS.addon:OnSlashCommand("enable")
    assertEqual(#heard, before + 1, "the replayed receiver heard the stand-up")
    assertEqual(heard[#heard][1], "chat")
end)
