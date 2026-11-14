# Scope — Ka0s Drop Watcher

## What it is for

Drop Watcher watches the loot your party or raid receives and answers, per drop: is it an upgrade
for me, is it an upgrade for the looter, and can it be traded. When the answer is "yes, and probably
yes", it asks for the item in one polite click. It also lists your own tradeable drops, with an exact
trade countdown and the group members each one would help (design spec §1, in
[`superpowers/specs/2026-10-10-drop-watcher-v1-design.md`](superpowers/specs/2026-10-10-drop-watcher-v1-design.md)).

It serves Retail and WoW Forever from one codebase (the Forever port,
[`superpowers/specs/2026-11-13-drop-watcher-forever-port-design.md`](superpowers/specs/2026-11-13-drop-watcher-forever-port-design.md)):
each client's own rules, a feature the other lacks absent there (`ARCHITECTURE.md` → Per-client
features), and everyone's loot rolls on both.

It respects Midnight's addon restrictions: asks queue while chat sending is restricted, and every
value the client may hand over as a secret is guarded. It is quiet by default; auto-ask, toasts and
sound are opt-in.

## What exists at v1.1.0

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
- **Insights** (issue #12, [`superpowers/specs/2026-11-05-drop-watcher-insights-design.md`](superpowers/specs/2026-11-05-drop-watcher-insights-design.md)).
  A third tab of charts over the kept history, drawn through LibKa0s-Charts-1.0: eight cards (drops
  seen, upgrades for you, asks sent, items received, ask success, active days, offers sent, traded
  away) and fourteen sections (drops by outcome, your verdicts, trade estimates, upgrades by instance
  and by boss, top instances per visit, the most generous members, the item level items received
  gained you, asks and drops per day, and drops by looter class, quality, slot and item kind). Its
  own bar of seven filters (Character, Instance, Difficulty, Situation, Date, Quality, Category),
  each listing only the values present with their counts; the strip names the period the kept history
  covers. `/dw insights` opens it.
- **The upgrade glow** (feedback-21). A drop that is an upgrade for you, and whose trade estimate
  is Yes or Likely (feedback-22), glows on its icon in the Drops table, the compact card and the
  detail card (never the toast): one glow for your current spec, one
  for an off-spec, each with its own switch, LibCustomGlow style, color and that style's knobs
  (Alerts › Upgrade glow). Every tooltip is bulleted rows, one fact per row.
- **Item icon style** (feedback-21 G11). Every item icon the addon draws takes one look from
  Window › Icons: a zoom that crops its edges, and the standard border block (style, thickness,
  color and Use class color) with Color by item quality. The defaults (feedback-21 H6) trim the icon's
  baked-in edge and draw a Solid black border 2 pixels thick; while Use the skin's border is on (by
  default), the border's style and thickness are the skin's, Solid 1 pixel in every skin.
- **Skins** (the 2026-10-29 skinning rollout, LibKa0s-Skin-1.0). Every surface the addon draws, the
  window, cards, Offer panel, toast, tooltip lines, tool windows and, when asked, the settings panel,
  wears the skin picked on General → Skin (nine Ka0s skins, or EllesmereUI's), live, with font, texture and
  outline settings; Ka0s Default keeps the colors drawn before skins. A first-run picker offers the
  choice once per profile, and `/dw skin` opens it again.
- **Compact mode** (M12, [`superpowers/specs/2026-10-11-drop-watcher-compact-mode-design.md`](superpowers/specs/2026-10-11-drop-watcher-compact-mode-design.md)).
  The same window in a second layout, about 400 pixels wide: each drop a four-line card on both
  tabs, a one-row filter bar with a Filters menu, a short title and a one-line footer. It reads
  the same feed, filters and engine, so it never changes what is recorded, judged or sent. The
  title-bar toggle, the Layout setting, `/dw compact` and `/dw full` switch it, each layout keeps its
  own size and place, and an auto-open inside a run opens it compact until the run ends (on by
  default).
- **Everyone's rolls** (the Forever port, design §5 and §7, both clients). Every group-loot roll
  the client's loot history reports is held beside the feed while it is open, in the Drops tab's
  Rolling now section above the boss groups: the item, your verdict, who chose Need, Greed or Pass
  so far and the time left, with each player's choice and number in a ROLLS box under it. Won, it
  joins the feed as its drop with the final roll table on its detail card and in History (Drops ›
  Rolls' Show rolls and Keep rolls in history). The game's own roll popup carries a small side card
  with your verdict and the roll's count line, every roll on hover (Mark the roll popup).
- **Master-loot pending and Ask the master looter** (design §6, both clients; on Retail Guild Master
  Loot alone). An Epic in a loot window you opened, while someone else is the master looter, waits in
  Rolling now as awaiting the master looter until a receipt names who got it, with one Ask that
  whispers the master looter.
- **WoW Forever** (the port, design §4). The nine classes by talent tree with the armor level rule,
  the ranged slot, Pawn and your weights by talent tree, score-first verdicts, whole two-word names,
  and Forever's trade model: a looted bind-on-pickup drop is soulbound, so only a bind-on-equip drop
  is tradeable. Mythic+, delves, follower dungeons, Raid Finder, scenarios, transmog, upgrade tracks,
  off-spec, the Encounter Journal pool and the trade countdown are Retail's alone.
- **The extras.** The upgrade toast (with its own scale, and up to five stacked at once, three by
  default: DW-T2), on for a new profile since 2026-10-25, and
  auto-ask, off by default.
- **The standard surfaces.** The settings pages (General, Drops, Comparison, Messages, Window,
  Alerts and Profiles; feedback-24, with Situations a Drops tab since item 020), the `/dw` command with the feature verbs of design spec §12.3, the launcher, the
  debug console and the diagnostics report, the performance harness and the stand-down latch.

## Item categories (issue #13)

The triage of [`superpowers/specs/2026-11-05-drop-watcher-categories-design.md`](superpowers/specs/2026-11-05-drop-watcher-categories-design.md)
§1. Every item the client reads gets a category from `NS.Collectibles.CategoryOf`, first match in
the order below, through the collection reads of `core/CompatCollect.lua`. The feed watches the
kinds turned on under Drops › Items › Item kinds (the `feed.categories.<key>` rows, defaults below;
they replaced Gear only and Include tier tokens, DW-CAT2): an item in no category is not watched.
Two item-ID lists override the kinds (Drops › Item lists, or `/dw whitelist|blacklist`): Always watch
lets an item through whatever its kind, the minimum item level and the quality gate say, but not the
situation gate; Never watch hides it, gear included, and wins over Always watch. An ID sits on one
list at a time. The simulator (`/dw sim drop <kind>`, one burst line in eight) and test mode (a
sixth boss's samples) produce every kind. Enum values are resolved by name (the brackets are the
12.x numbers).

| Category | Default | Detection | Collected or known | Shown as |
|---|---|---|---|---|
| Tier tokens | on | an item with no slot plan for its raw equipLoc (usually Miscellaneous [15] › Junk [0] or Reagent [1]) that carries the `RestrictedRaceClass` tooltip line, or whose Use text says `appropriate for your class` (TT-1), or an epic `... Curio`; or one the `C.TIER_TOKENS` override lists, empty by default | n/a: judged as gear against the slot it makes | the slot it makes (or `any slot`, judged in its best tier slot) and its classes (`Any class` for a Curio, `Your class` for a token whose Use text alone names your class) |
| Equipment | on | Armor [4] or Weapon [2], not a tier token, not cosmetic | n/a: the gear verdict | unchanged |
| Mounts | on | `C_MountJournal.GetMountFromItem`, else Miscellaneous › Mount [5] (Mount Equipment [6] is not a mount) | the journal's `isCollected` | New or Collected |
| Battle pets | on | `C_PetJournal.GetPetInfoByItemID`'s species, else Miscellaneous › Companion Pet [2] | `GetNumCollectedInfo`: none is new, else collected with `n/limit` | New or Collected 1/3 |
| Toys | on | `C_ToyBox.GetToyInfo` answers the item | `PlayerHasToy` | New or Collected |
| Recipes | on | Recipe [9]; its subclass names the profession's skill line (`C.RECIPE_SKILL_LINE`; Book and First Aid none) | the tooltip's whole `ITEM_SPELL_KNOWN` line; a profession you lack is can't use | New, Known or Can't use |
| Cosmetics | off | Armor › Cosmetic [5], or `C_Item.IsCosmeticItem` on armor or a weapon (cosmetic weapons are Weapon-class) | the appearance, as today | New look or Look known |
| Lockboxes and containers | on | Container [1] (a bag), or Miscellaneous › Junk [0] whose tooltip carries the whole `LOCKED` ("Locked") or `ITEM_OPENABLE` ("<Right Click to Open>") line (RX-04, rolls UX design §3.5) | n/a: not gear | Lockbox (it reads Locked), else Container |
| Everything else that is rolled on | off | no kind above, and a group rolls on it (a roll table, or Rolling now): the catch-all | n/a: not gear | Item |

A collectible (mount, pet, toy, recipe, cosmetic), a lockbox or container, and an item the
catch-all lets in are feed-only: no Ask, toast, AutoAsk, Offer, Announce, Post my tradeables or
glow, and no Me/Them gain (the kind word stands where gear shows a verdict, never Unknown; your roll
popup reads the same word for any roll). Not watched unless rolled on with the catch-all on: quest
starters, reagents (high quality included), Junk that does not open, keystones, currencies (never `|Hitem:` loot lines), profession tools and accessories,
gems, trade goods, item enhancements, consumables and housing decor. A caged battle pet arrives as
a `|Hbattlepet:` link and is never watched; only companion items are.

## What it deliberately does not do (v1)

- Loot council and voting, and rolling for you: the rolls are shown, but you roll on the game's own
  popup.
- Wishlists, BiS lists, tier and catalyst flags, Droptimizer import.
- Addon-to-addon communication, and interop with other loot-trading addons.
- Void Core tracking, loot-spec nudges.

Each is a GitHub issue rather than a silent omission (design spec §14). It never sends a chat
message the player did not ask for, never uses SAY or YELL, and never trades without a click.
