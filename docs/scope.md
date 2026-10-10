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
latch, the message catalog, and the situation classifier (it knows where the player is; nothing
consumes it yet). The verdict kernel, the quality gate and the trade estimator exist as pure
modules that nothing calls yet. The feed that wires them in, inspection, asking and the
situation settings arrive with the plan's later items
([`superpowers/plans/2026-10-10-drop-watcher-v1.md`](superpowers/plans/2026-10-10-drop-watcher-v1.md)).

## What it deliberately does not do (v1)

- Loot council, voting and rolls.
- Wishlists, BiS lists, tier and catalyst flags, Droptimizer import.
- Addon-to-addon communication, and interop with other loot-trading addons.
- Void Core tracking, loot-spec nudges.

Each is a GitHub issue rather than a silent omission (design spec §14). It never sends a chat
message the player did not ask for, never uses SAY or YELL, and never trades without a click.
