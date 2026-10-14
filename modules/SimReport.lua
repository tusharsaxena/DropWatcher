local _, NS = ...
-- modules/SimReport.lua — where a simulated loot burst's drops went (feedback-3 spec §0, DW-B0).
--
-- THE OWNER'S CASE. The key scenario's loot step read `Loot: 2 drops` while the window showed one
-- drop. Reproduced headless (every scenario, every seed): nothing was lost. A random burst of two or
-- more lines always has one line of yours (modules/SimEvents.lua's Plan, sim feedback §0), and your
-- own drop was then listed apart from the others. The step now says where its drops went, and the
-- window reconciles with it.
--
-- THE REPORT. Loot marks the feed's receipt sequence and merge count (Mark), plays the drivers'
-- burst (NS.SimEvents.Loot), then collects the receipts made since the mark (Collect): the records
-- the feed took (each with its state: added, loading or hidden by a gate), how many lines merged
-- into an earlier drop, and how many lines went out. Place says where one drop is now (pure, given
-- the feed's reader and the window's view, View): Drops, hidden by a gate (its reason), loading,
-- cleared from the feed since, or not shown while test mode is on. Drops lists your own drops too
-- (feedback-5 spec §2 and §3: `feed.showOwn` and the third tab are retired), so a drop of yours
-- is on Drops like any other. It honors the feed the window shows. Summarize counts the places (pure) and words the step's
-- detail: `2 drops`, `3 drops (1 hidden)`; TipLines names each drop, its looter and its place, for the
-- panel row's tooltip. The panel reads the report again on every repaint, so a drop that was still
-- loading when the step ran is placed once it lands.
--
-- It reads NS.State.feed (the receipts, read-only, as the diagnostics do), NS.LootFeed.Get,
-- NS.Window.FeedView and NS.WindowCells' name helpers at call time.
--
--   report = { drops = { rec, ... } (oldest first), merged, sent }

NS.SimReport = NS.SimReport or {}
local R = NS.SimReport
local L = NS.L

-- The words for each gate that hides a drop (modules/FeedCounts.lua's reasons).
local GATE = {
    notTracking = L["not tracked here"], heirloom = L["an heirloom"], cosmetic = L["cosmetic"],
    token = L["a token"], notGear = L["not gear"], minIlvl = L["below the minimum item level"],
    quality = L["below the quality gate"],
}

-- The extras a detail lists after the count, in order, and their words.
local EXTRAS = {
    { key = "hidden", fmt = L["%d hidden"] },
    { key = "loading", fmt = L["%d loading"] }, { key = "merged", fmt = L["%d merged"] },
    { key = "cleared", fmt = L["%d cleared"] }, { key = "offscreen", fmt = L["%d not shown in test mode"] },
    { key = "refused", fmt = L["%d refused"] },
}

--- The feed's receipt sequence and merge count now, before a burst.
--- @return table { seq, merged }
function R.Mark()
    local s = NS.State.feed
    return { seq = s and s.seq or 0, merged = s and s.merged or 0 }
end

--- The receipts made since `mark`: the records the feed took, oldest first, how many lines merged
--- into an earlier drop and how many lines went out (`sent`).
--- @param mark table R.Mark's
--- @param sent number|nil
--- @return table report
function R.Collect(mark, sent)
    local s, out = NS.State.feed, { drops = {}, merged = 0, sent = tonumber(sent) or 0 }
    if not s then return out end
    out.merged = math.max(0, (s.merged or 0) - (mark.merged or 0))
    for _, rec in ipairs(s.recent or {}) do
        if rec.id > (mark.seq or 0) then out.drops[#out.drops + 1] = rec end
    end
    table.sort(out.drops, function(a, b) return a.id < b.id end)
    return out
end

--- Mark, play the drivers' burst (`/dw sim loot`'s arguments), collect. Answers the lines sent,
--- the drivers' refusal when none went out, and the report.
--- @param n number|nil
--- @param who string|nil
--- @return number, string|nil, table
function R.Loot(n, who)
    local mark = R.Mark()
    local sent, why = NS.SimEvents.Loot(n, who)
    return sent, why, R.Collect(mark, sent)
end

--- What the window shows (the edge): its feed (NS.Window.FeedView), so a place honors it.
--- @return table { feed }
function R.View()
    return NS.Window.FeedView()
end

--- Where one drop is now (pure, given `get`, the feed's reader, and `view`, the window's R.View;
--- nil is the live feed): `group` (yours too: Drops lists every drop, feedback-5 spec §2),
--- `hidden` (and the gate's reason), `loading`, `cleared` (taken out of the feed since) or
--- `offscreen` (in a feed the window does not show: test mode is on).
--- @param rec table
--- @param get function|nil id -> drop (NS.LootFeed.Get)
--- @param view table|nil { feed }
--- @return string place, string|nil why
function R.Place(rec, get, view)
    view = view or {}
    if rec.state == "hidden" then return "hidden", rec.hidden end
    if rec.state ~= "added" then return "loading" end
    if get and get(rec.id) ~= rec then return "cleared" end
    if (rec.feed or "live") ~= (view.feed or "live") then return "offscreen" end
    return "group"
end

--- A report's counts and its detail (pure, given `get` and `view`, as R.Place's): { total, group,
--- hidden, loading, merged, cleared, offscreen, refused, text }. `text` is `3 drops (1 hidden)`, the
--- count alone when every drop is on Drops.
--- @param report table
--- @param get function|nil
--- @param view table|nil
--- @return table
function R.Summarize(report, get, view)
    report = type(report) == "table" and report or {}
    local drops = report.drops or {}
    local c = { total = tonumber(report.sent) or #drops, group = 0, hidden = 0, loading = 0,
        cleared = 0, offscreen = 0, merged = tonumber(report.merged) or 0 }
    for _, rec in ipairs(drops) do
        local place = R.Place(rec, get, view)
        c[place] = c[place] + 1
    end
    c.refused = math.max(0, c.total - #drops - c.merged)
    local text = c.total == 1 and L["1 drop"] or L["%d drops"]:format(c.total)
    local parts = {}
    for _, x in ipairs(EXTRAS) do
        if c[x.key] > 0 then parts[#parts + 1] = x.fmt:format(c[x.key]) end
    end
    if #parts > 0 then text = L["%s (%s)"]:format(text, table.concat(parts, ", ")) end
    c.text = text
    return c
end

local PLACE_WORDS = { group = L["Drops"], loading = L["still loading"],
    cleared = L["cleared from the feed"], offscreen = L["not shown while test mode is on"] }

local function where(rec, get, view)
    local place, why = R.Place(rec, get, view)
    if place == "hidden" then return L["hidden: %s"]:format(GATE[why] or tostring(why)) end
    return PLACE_WORDS[place]
end

--- The tooltip's lines for a report (pure, given `get`): each drop, its looter and where it is
--- (`Item (Seta): Drops`, `Item (Seta): hidden: below the quality gate`, `Item (you): Drops`), then
--- the merged and refused lines' counts. `view` as R.Place's.
--- @param report table
--- @param get function|nil
--- @param view table|nil
--- @return table lines
function R.TipLines(report, get, view)
    local WC, out = NS.WindowCells, {}
    report = type(report) == "table" and report or {}
    for _, rec in ipairs(report.drops or {}) do
        local who = rec.isMine and L["you"] or WC.ShortName(type(rec.looter) == "table" and rec.looter.name or nil)
        out[#out + 1] = L["%s (%s): %s"]:format(WC.ItemName(rec.link) or "?", who, where(rec, get, view))
    end
    local c = R.Summarize(report, get, view)
    if c.merged > 0 then out[#out + 1] = L["%d merged into an earlier drop"]:format(c.merged) end
    if c.refused > 0 then out[#out + 1] = L["%d refused by the feed"]:format(c.refused) end
    return out
end
