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

Everything design spec §1 puts in v1 is built; what is still owed is the in-game sign-off
([`smoke-tests.md`](smoke-tests.md)).

- **The feed.** Each drop is taken from the loot lines in chat, the encounter loot event and the
  loot history, the reports of one drop merged and grouped by boss or keystone run. The situation,
  the filters and the minimum-quality gate decide what shows before anyone is inspected.
- **The verdicts.** Each drop is judged for you (against your gear snapshot) and for its looter
  (against the inspect broker's read of their gear), by item level and, when one is in use, a score:
  Pawn, your own per-spec weights (with the Pawn scale string import), or none. The detail card also
  says whether you have collected the look (CanIMogIt when installed).
- **The trade estimate.** Yes, likely, unknown or no, with its reason: the bind, the trade window,
  the situation's rule and the looter's item level. Your own drops get the exact countdown read
  from the item's tooltip, with one chat warning at ten minutes.
- **The sends.** Ask, offer and announce, each one click and one confirmation line, guarded by the
  one-ask registry, queued while chat is restricted and sent when the restriction lifts; an
  edit-first box when wanted; never SAY or YELL.
- **The window.** Group drops (rows under collapsible boss headers, with a detail card that expands
  inline), My drops (the countdown, the best candidates, the "Who could use this?" Offer panel with
  its Trade button, Post my tradeables) and History (every drop the feed showed, kept across sessions
  on every character, with its outcome), plus the filter bar, the footer's health line, the
  restriction badge, Scan group, minimize, test mode and auto-open.
- **Opt-in extras.** The upgrade toast and auto-ask, both off by default.
- **The standard surfaces.** The settings pages (General, Feed, Comparison, Trade, Messages, Window
  and Profiles), the `/dw` command with the feature verbs of design spec §12.3, the launcher, the
  debug console and the diagnostics report, the performance harness and the stand-down latch.

## What it deliberately does not do (v1)

- Loot council, voting and rolls.
- Wishlists, BiS lists, tier and catalyst flags, Droptimizer import.
- Addon-to-addon communication, and interop with other loot-trading addons.
- Void Core tracking, loot-spec nudges.

Each is a GitHub issue rather than a silent omission (design spec §14). It never sends a chat
message the player did not ask for, never uses SAY or YELL, and never trades without a click.
