local _, NS = ...
-- modules/WindowOwn.lua — your own drops on the Group drops tab (feedback-5 spec §2): the session's
-- reveal state, the tone states of a drop's Offer and Announce, and the reads that turn your own
-- drop's cells into what the table, the compact card and the detail card paint.
--
-- ALWAYS LISTED. Group drops lists every drop, your own included (`feed.showOwn` is retired; a
-- stored value is ignored). On your own drop the Trade cell counts the members it upgrades
-- (`Yes (2)`), Them and Their eq read `(Multiple)` with every upgrade in their tooltip, and Actions
-- is Offer, which opens the Offer panel (modules/OfferPanel.lua) and reveals the drop. What each
-- says is NS.MineCells' (pure: OwnTrade, Multiple, OwnOffer); this file reads the state they take.
--
-- THE KEEP? RULE. An upgrade for you is offered to nobody until you open its Offer panel: until then
-- its count is not drawn and (Multiple) reads `Hidden`. Opening the panel reveals it for the session
-- (WO.Reveal, NS.State.windowOwn); the My drops tab's Best candidates honor the same state.
--
-- THE TONES (feedback-4 spec §1). Offer is toned by the furthest offer sent for the drop, Announce
-- by its own state; both green once you traded the drop away (MineCells.ToneState). WO.ToneStates
-- answers both, for the Drops table, the detail card, the compact card and the My drops tab.
--
-- THE CLICK. Every action button that may be an Ask or an Offer goes through WO.PressAction: Offer
-- (`b.offer`) opens the panel, anything else is the Ask (NS.PressAsk).

NS.WindowOwn = NS.WindowOwn or {}
local WO    = NS.WindowOwn
local State = NS.State
local MC    = NS.MineCells

local function view()
    local v = State.windowOwn
    if not v then
        v = { revealed = {} }
        State.windowOwn = v
    end
    return v
end

--- Reveal who drop `id` would help: the player chose to offer it (its Offer panel opened).
--- @param id number
function WO.Reveal(id)
    if id ~= nil then view().revealed[id] = true end
end

--- Whether drop `id` was revealed this session.
--- @param id number
--- @return boolean
function WO.IsRevealed(id) return id ~= nil and view().revealed[id] == true end

--- The states drop `drop`'s Offer and Announce are toned by (feedback-4 spec §1): Offer by the
--- furthest offer sent for it, Announce by its own state; both `tradedAway` once you traded it
--- away (MineCells.ToneState).
--- @param drop table
--- @return string offer, string announce
function WO.ToneStates(drop)
    local outcome = NS.History.OutcomeOf(drop.id)
    return MC.ToneState(outcome, NS.Asks.FurthestStateOf("offer", drop.id)),
        MC.ToneState(outcome, NS.Asks.StateOf("announce", nil, drop.id))
end

--- The Trade cell for any drop: your own drop's counts its upgrades (MineCells.OwnTrade).
--- @param drop table
--- @return table cell
function WO.Trade(drop)
    if drop.isMine then return MC.OwnTrade(drop, WO.IsRevealed(drop.id)) end
    return NS.WindowCells.Trade(drop)
end

--- Them or Their eq on your own drop: `(Multiple)`, or `Hidden` (MineCells.Multiple).
--- @param drop table one of your drops
--- @param title string|nil the tooltip's title
--- @return table cell
function WO.Multiple(drop, title)
    return MC.Multiple(drop, WO.IsRevealed(drop.id), title)
end

--- Your own drop's Offer (MineCells.OwnOffer), toned by the offer half of WO.ToneStates.
--- @param drop table one of your drops
--- @return table WindowCells.Ask's shape, with `offer` true
function WO.Offer(drop)
    return MC.OwnOffer(drop, (WO.ToneStates(drop)))
end

--- An action button's click: Offer opens the Offer panel (`b.offer`), else it is the Ask.
--- @param b table the button (`b.dropId`, `b.offer`)
function WO.PressAction(b)
    if b.offer then
        NS.OfferPanel.Open(b.dropId)
    else
        NS.PressAsk(b.dropId)
    end
end
