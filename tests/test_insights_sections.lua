-- tests/test_insights_sections.lua — the Insights tab's chart sections on screen (issue #12, Insights
-- design spec §1.4, §5; modules/InsightsSections.lua through modules/WindowInsights.lua): every
-- section draws on a filled log, in the spec's order under its four dividers; a section with no rows
-- shows its heading and one muted line and never calls its renderer; the two list panels sit side by
-- side, stacked in compact, and keep their title with a line when empty; the hovers carry the
-- numbers; a second pass builds no frame; the whole-tab empty state hides every section; a skin
-- switch re-lays the rows out.

local T = _G.DW_TEST
local test, assertEqual, assertTrue, assertFalse = T.test, T.assertEqual, T.assertTrue, T.assertFalse

local LINK = "|cffa335ee|Hitem:212::|h[Crown of Roaring Storms]|h|r"
local UP = { verdict = "upgrade", ilvlDelta = 9 }

-- An hour ago, but never before today's midnight: the Drops strip's last column is today, so a run
-- in the first hour after midnight must not file the log's recent drops under yesterday.
local function recent(now)
    local d = os.date("*t", now)
    d.hour, d.min, d.sec = 0, 0, 0
    return math.max(os.time(d), now - 3600)
end

local function drop(now, over)
    local e = { itemLink = LINK, itemID = 212, looter = "Brakk-Testrealm", class = "WARRIOR", outcome = "seen",
        at = recent(now), quality = 4, equipLoc = "INVTYPE_HEAD", me = { verdict = "downgrade", ilvlDelta = -3 },
        trade = { state = "likely" } }
    for k, v in pairs(over or {}) do e[k] = v end
    return e
end

local function group(now, over, drops)
    local g = { key = "k", label = "Kyveza", kind = "encounter", instance = "Ruby Life Pools", difficulty = "Mythic",
        situation = "raid", at = recent(now), drops = drops }
    for k, v in pairs(over or {}) do g[k] = v end
    return g
end

-- A log that fills every section: an encounter with upgrades, a second visit, a trade to you with a
-- frozen gain, an ask, your own drop traded away.
local function fullLog(now)
    return {
        group(now, { key = "a" }, {
            drop(now, { me = UP }),
            drop(now, { outcome = "received", settledAt = now, askedAt = now - 120, looter = "Seta-Testrealm",
                class = "PRIEST", got = { verdict = "upgrade", ilvlDelta = 7 } }),
            drop(now, { isMine = true, outcome = "tradedAway", settledAt = now }),
        }),
        group(now, { key = "b", kind = "run", label = "Ruby Life Pools", difficulty = "Mythic+ 12", situation = "mythicPlus",
            at = now - 2 * 86400 }, { drop(now, { at = now - 2 * 86400, me = UP, quality = 3 }) }),
    }
end

-- An enabled addon with `groups` as the account's history, the window on Insights.
local function insights(groups, mode)
    local NS, _, m = T.enableAddon()
    NS.History.Store().groups = groups(m.time())
    if mode then NS.SetWindowMode(mode) end
    NS.ShowWindow()
    NS.Window.SelectTab("insights")
    return NS, m, NS.WindowInsights.Drawn()
end

local function activeOf(NS, d, key)
    local _, active = NS.Pool.Counts(d.ctx:Pool(key))
    return active
end

local function topOf(region)
    for _, p in ipairs(region.__points) do
        if p[1] == "TOPLEFT" then return p[5], p[4] end
    end
end

local function emptyLines(NS, d)
    local out = {}
    local pool = d.ctx:Pool("empty")
    for _, f in ipairs(pool.active or {}) do out[#out + 1] = f.text:GetText() end
    assertEqual(#out, (select(2, NS.Pool.Counts(pool))))
    return out
end

local function has(list, text)
    for _, v in ipairs(list) do if v == text then return true end end
    return false
end

-- ── every section ───────────────────────────────────────────────────────────────────────────

test("insights sections: a filled log draws every section, each heading shown and in the spec's order", function()
    local NS, _, d = insights(fullLog)
    local s = d.sections
    for _, key in ipairs({ "outcomes", "verdicts", "tradeStates", "byInstance", "byBoss", "topRate", "generous",
        "gain", "asks", "drops", "byClass", "byQuality", "bySlot", "byCategory" }) do
        assertTrue((s[key] or 0) > 0, key .. " drew rows")
    end
    local last
    for _, h in ipairs(NS.InsightsSections.HEADERS) do
        local fs = d.headers[h.key]
        assertTrue(fs:IsShown(), h.key .. " heading shown")
        local y = topOf(fs)
        if last then assertTrue(y < last, h.key .. " under the one before") end
        last = y
    end
    for key, div in pairs(d.dividers) do assertTrue(div:IsShown(), key .. " divider") end
    assertEqual(d.headers.outcomes:GetText(), "Drops by outcome")
    assertEqual(d.headers.gain:GetText(), "Item level gained from items received · +7 in all")
    assertEqual(#emptyLines(NS, d), 0, "no empty line on a full log")
    assertTrue(activeOf(NS, d, "outcomesLegend") > 0 and activeOf(NS, d, "byInstanceLegend") == 2, "the legends")
    assertTrue(activeOf(NS, d, "gainScale") == 1, "the gain scale line")
    assertTrue(d.strips.asks:IsShown() and d.strips.drops:IsShown())
    assertTrue(d.pane.content:GetHeight() > 1000, "the content holds every section")
end)

test("insights sections: the hovers carry the numbers", function()
    local NS, m, d = insights(fullLog)
    local bar = d.ctx:Pool("byClass").active[1]
    assertEqual(table.concat(bar._tip, " | "), "Warrior | 3 (75%) drops")
    local seg = d.ctx:Pool("outcomes").active[1].segs[1]
    assertEqual(seg._tip, "Traded to me: 1 (33%)")
    seg:__fire("OnEnter")
    assertEqual(m.GameTooltip.__lines[1].text, "Traded to me: 1 (33%)")
    local row = d.ctx:Pool("generous").active[1]
    assertEqual(row._tip[1], "Seta-Testrealm")
    local col = d.ctx:Pool("drops").active[#d.ctx:Pool("drops").active]
    assertEqual(col._tip[2], "3 drops, 1 upgrade for you")
    assertTrue(NS ~= nil)
end)

-- ── empty sections ──────────────────────────────────────────────────────────────────────────

test("insights sections: a section with no rows shows its heading and one line, its renderer never called", function()
    local NS, _, d = insights(function(now)
        return { group(now, { kind = "run", label = "Ruby Life Pools" }, { drop(now, { isMine = true }) }) }
    end)
    local s = d.sections
    assertEqual(s.byInstance, 0); assertEqual(s.byBoss, 0); assertEqual(s.gain, 0); assertEqual(s.asks, 0)
    assertEqual(s.tradeStates, 0, "your own drop has no trade estimate")
    assertEqual(activeOf(NS, d, "byInstance"), 0, "no bar drawn"); assertEqual(activeOf(NS, d, "gain"), 0)
    assertEqual(activeOf(NS, d, "asks"), 0); assertFalse(d.strips.asks:IsShown(), "no strip")
    assertTrue(d.headers.byInstance:IsShown() and d.headers.byBoss:IsShown() and d.headers.gain:IsShown())
    local lines = emptyLines(NS, d)
    assertTrue(has(lines, "No upgrades for you in these filters."))
    assertTrue(has(lines, "No upgrades for you from a boss kill in these filters. Mythic+ keys are kept as whole runs."))
    assertTrue(has(lines, "No items received in these filters."))
    assertTrue(has(lines, "No asks in these filters."))
    assertTrue(has(lines, "No drops by others in these filters."))
    assertTrue(has(lines, "No instance with an upgrade for you and two visits or more."), "D's line in its panel")
    assertTrue(d.panels.topRate:IsShown() and d.panels.generous:IsShown(), "the empty panels keep their title")
    assertTrue(s.outcomes > 0 and s.drops > 0 and s.byClass > 0, "the rest still draw")
end)

test("insights sections: F with only items no level was compared for says so", function()
    local NS, _, d = insights(function(now)
        return { group(now, nil, { drop(now, { outcome = "received", settledAt = now, got = { at = now } }) }) }
    end)
    assertEqual(d.sections.gain, 0)
    assertTrue(has(emptyLines(NS, d), "No item received here has an item level comparison."))
    assertEqual(d.headers.gain:GetText(), "Item level gained from items received · 1 not compared")
end)

test("insights sections: with no drop through the filters every section hides", function()
    local NS = insights(fullLog)
    NS.WindowInsights.SetFilter("situation", "dungeon")
    local d = NS.WindowInsights.Drawn()
    assertTrue(d.empty:IsShown())
    for key, h in pairs(d.headers) do assertFalse(h:IsShown(), key) end
    for key, p in pairs(d.panels) do assertFalse(p:IsShown(), key) end
    for key, v in pairs(d.dividers) do assertFalse(v:IsShown(), key) end
    assertEqual(activeOf(NS, d, "byClass"), 0)
end)

-- ── the list panels ─────────────────────────────────────────────────────────────────────────

test("insights sections: D and E sit side by side in the full layout and stack in compact", function()
    local _, _, d = insights(fullLog)
    local yD, xD = topOf(d.panels.topRate)
    local yE, xE = topOf(d.panels.generous)
    assertEqual(yD, yE); assertTrue(xE > xD)
    local _, _, c = insights(fullLog, "compact")
    yD, xD = topOf(c.panels.topRate)
    yE, xE = topOf(c.panels.generous)
    assertEqual(xD, xE); assertTrue(yE < yD, "E under D")
    assertEqual(c.panels.topRate:GetWidth(), c.pane.content:GetWidth() - 16, "the whole width, less the margins")
    assertTrue(d.panels.topRate:GetWidth() < d.pane.content:GetWidth() / 2, "half of it in the full layout")
end)

-- ── passes ──────────────────────────────────────────────────────────────────────────────────

test("insights sections: a second pass builds no frame", function()
    local NS, _, d = insights(fullLog)
    local function made()
        local n = 0
        for _, pool in pairs(d.ctx.pools) do
            local free, active = NS.Pool.Counts(pool)
            n = n + free + active
        end
        return n
    end
    local before = made()
    NS.WindowInsights.MarkLayout()
    NS.Window.Refresh()
    assertEqual(made(), before)
    assertEqual(NS.WindowInsights.Drawn().sections.byClass, d.sections.byClass)
end)

test("insights sections: a skin switch marks a fresh layout, so the host's colors are bound again", function()
    local NS, m, d = insights(fullLog)
    local key = d.pane.layoutKey
    d.ctx:Reskin()
    assertTrue(d.pane.layoutKey == nil, "marked")
    m.advance(0.1)
    assertEqual(NS.WindowInsights.Drawn().pane.layoutKey, key, "laid out again")
end)
