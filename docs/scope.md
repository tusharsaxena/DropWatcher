# Scope — Ka0s Drop Watcher

## What it is for

Drop Watcher watches the loot your party or raid receives and answers, per drop: is it an upgrade
for me, is it an upgrade for the looter, and can it be traded. When the answer is "yes, and probably
yes", it asks for the item in one polite click. It also lists your own tradeable drops, with an exact
trade countdown and the group members each one would help (design spec §1, in
[`superpowers/specs/2026-10-10-drop-watcher-v1-design.md`](superpowers/specs/2026-10-10-drop-watcher-v1-design.md)).

It respects Midnight's addon restrictions: asks queue while chat sending is restricted, and every
value the client may hand over as a secret is guarded. It is quiet by default; auto-ask, toasts and
sound are opt-in.

## What exists at v0.1.0

The frame the features plug into: the window shell (the Ka0s-skinned frame with its title bar,
restriction badge, Scan group button, the Group drops, My drops and History tabs, the filter bar,
the footer's health line, minimize, position, size, lock, scale, alpha, General visibility, test
mode and auto-open), the settings panel's pages (the landing page, General, Feed, Comparison,
Trade, Messages, Window and Profiles, with the per-spec weights and unwanted types and the message
templates' editors, counters and preview), the
`/dw` command with the reserved verbs and `lock`, `unlock`, `show`, `hide`, `toggle` and `test`, the
launcher, the debug console and the diagnostics report, the performance harness, the stand-down
latch, the message catalog, and the situation classifier. The feed wires the engine together: it
takes each drop from the loot lines in chat, the encounter loot event and the loot history, merges
the reports of one drop, groups drops by encounter or keystone run, hides what the situation, the
filters or the quality gate exclude, judges each drop for you (the verdict kernel over your gear
snapshot) and for its looter (over the inspect broker's read), and estimates whether it can be
traded; the diagnostics report counts what it holds. Your own drops' exact trade countdown runs
too: each one's bag item is read for its trade-time line, and a chat line warns once when ten
minutes are left. The trade helper behind the Trade buttons is in too: it hands your drop to a
member or opens a trade, and refuses with a reason in combat or out of range. The Group
drops tab draws the feed: one row per drop under a collapsible header per boss or key run, with
the item button, its item level and slot, the looter, the looter's worn item, the verdicts for you
and for them, the trade estimate and an Ask button, every cell with its reason on hover, and a
compact preset. A row click opens its detail card inline: the item's chips, both comparisons side
by side, the trade estimate with its rule, and the Ask, Edit message, Link in chat, Retry inspect,
Trade and Hide this item buttons. The My drops tab lists your own drops with the time left to trade
each (exact once the item is in your bags), whether you would keep it, the best candidates and the
Offer… and Announce buttons, with a summary and Post my tradeables under them; Offer… opens the
"Who could use this?" panel beside the window, every member ranked by their gain with a status pill
and Offer and Trade buttons, and Announce to group. The History table and the settings that tune
the feed arrive with the plan's later items ([`superpowers/plans/2026-10-10-drop-watcher-v1.md`](superpowers/plans/2026-10-10-drop-watcher-v1.md)).
The messaging edge behind the coming ask buttons is in: it whispers the looter (or a candidate, or
announces to the group) with one confirmation line, queues while chat is restricted and sends the
queue when the restriction lifts or the boss dies, and in test mode prints instead of sending.

## What it deliberately does not do (v1)

- Loot council, voting and rolls.
- Wishlists, BiS lists, tier and catalyst flags, Droptimizer import.
- Addon-to-addon communication, and interop with other loot-trading addons.
- Void Core tracking, loot-spec nudges.

Each is a GitHub issue rather than a silent omission (design spec §14). It never sends a chat
message the player did not ask for, never uses SAY or YELL, and never trades without a click.
