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

The frame the features plug into: the window shell (position, size, lock, scale, alpha, General
visibility, test mode), the settings panel's landing page, General page and Profiles page, the
`/dw` command with the reserved verbs and `lock`, `unlock`, `show`, `hide`, `toggle` and `test`, the
launcher, the debug console and the diagnostics report, the performance harness, the stand-down
latch, the message catalog, and the situation classifier. The feed wires the engine together: it
takes each drop from the loot lines in chat, the encounter loot event and the loot history, merges
the reports of one drop, groups drops by encounter or keystone run, hides what the situation, the
filters or the quality gate exclude, judges each drop for you (the verdict kernel over your gear
snapshot) and for its looter (over the inspect broker's read), and estimates whether it can be
traded; the diagnostics report counts what it holds. Your own drops' exact trade countdown runs
too: each one's bag item is read for its trade-time line, and a chat line warns once when ten
minutes are left. The trade helper behind the coming Trade and Offer buttons is in too: it hands your
drop to a member or opens a trade, and refuses with a reason in combat or out of range. Nothing draws the drops yet: the window's
feed tabs, the ask and trade buttons, and the settings that tune the feed arrive with the plan's later
items ([`superpowers/plans/2026-10-10-drop-watcher-v1.md`](superpowers/plans/2026-10-10-drop-watcher-v1.md)).
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
