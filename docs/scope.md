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

## What exists at v1.0.0

Everything design spec §1 puts in v1 is built; what is still owed is the in-game sign-off
([`smoke-tests.md`](smoke-tests.md)).

- **The feed.** Each drop is taken from the loot lines in chat, the encounter loot event and the
  loot history, the reports of one drop merged and grouped by boss or keystone run. The situation,
  the filters and the minimum-quality gate decide what shows before anyone is inspected.
- **The verdicts.** Each drop is judged for you (against your gear snapshot) and for its looter
  (against the inspect broker's read of their gear), by item level and, when one is in use, a score:
  Pawn (its own scale for your spec, with no setup), your own per-spec weights (with the Pawn scale string import), or none. The verdict is an
  upgrade, a sidegrade, a downgrade, can't use, doesn't want or unknown. A drop your current spec
  can't use but another spec of your class can is also judged for that spec, on item level alone
  against the best item you own for it, and shows as an off-spec upgrade, sidegrade or downgrade in
  cyan with the spec's name (feedback-19); a looter's off-spec is judged on what they wear, and a looter who leaves the group keeps the read their drop was judged with (feedback-21). The
  detail card also says whether you have collected the look (CanIMogIt when installed).
- **The trade estimate.** Yes, likely, unknown or no, with its reason: the bind, the trade window,
  the situation's rule and the looter's item level. On another player's drop that none of your specs can use, a Yes or Likely reads Can't use (feedback-21). Your own drops get the exact countdown read
  from the item's tooltip, with one chat warning at ten minutes.
- **The sends.** Ask, offer and announce, each one click and one confirmation line, guarded by the
  one-ask registry, queued while chat is restricted and sent when the restriction lifts; an
  edit-first box when wanted; never SAY or YELL.
- **The window.** Drops (every drop, your own included, in rows under collapsible boss headers, each
  row's Me and Them showing the worn gear beside the verdict (a mark per worn item on a two-item slot), with a detail card that expands inline and a trade countdown on every row; on your own drops the
  upgrade count, who it would help and Offer, which opens the "Who could use this?" panel with an
  Offer per member (its Trade button retired by feedback-7), and a strip with Post my tradeables, Expand all / Collapse all and,
  in the full layout, Scan group and the tab's Sort; a `/reload` brings this session's drops back) and History (every drop the feed showed, kept across sessions
  on every character, with its outcome and a detail card that expands inline), plus the filter bar, the footer's health line, the
  restriction badge, Scan group, minimize, test mode and auto-open.
- **The upgrade glow** (feedback-21). A drop that is an upgrade for you, and whose trade estimate
  is Yes or Likely (feedback-22), glows on its icon in the Drops table, the compact card and the
  detail card (never the toast): one glow for your current spec, one
  for an off-spec, each with its own switch, LibCustomGlow style, color and that style's knobs
  (Window › Upgrade glow). Every tooltip is bulleted rows, one fact per row.
- **Item icon style** (feedback-21 G11). Every item icon the addon draws takes one look from
  Window › Icons: a zoom that crops its edges, and the standard border block (style, thickness,
  color and Use class color) with Color by item quality. The defaults (feedback-21 H6) trim the icon's
  baked-in edge and draw a Solid black border 2 pixels thick.
- **Compact mode** (M12, [`superpowers/specs/2026-10-11-drop-watcher-compact-mode-design.md`](superpowers/specs/2026-10-11-drop-watcher-compact-mode-design.md)).
  The same window in a second layout, about 400 pixels wide: each drop a four-line card on both
  tabs, a one-row filter bar with a Filters menu, a short title and a one-line footer. It reads
  the same feed, filters and engine, so it never changes what is recorded, judged or sent. The
  title-bar toggle, the Layout setting, `/dw compact` and `/dw full` switch it, each layout keeps its
  own size and place, and an auto-open inside a run opens it compact until the run ends (on by
  default).
- **Opt-in extras.** The upgrade toast (with its own scale) and auto-ask, both off by default.
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
