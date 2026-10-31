# Testing — Ka0s Drop Watcher

## The green commit gate

Both MUST pass before every commit (testing-§4):

```sh
lua tests/run.lua      # the headless suite, Lua 5.1
luacheck .             # 0 warnings / 0 errors
```

No authored `.lua` file may pass 1500 lines (layout-§1); the kit's `test_layout_cap` reads the
census in [`ARCHITECTURE.md`](ARCHITECTURE.md). Toolchain: [`DEPENDENCIES.md`](../DEPENDENCIES.md).
The suite needs a sibling `../LibKa0s` checkout for the vendor gate's two payload cases (they SKIP
without it).

## The harness

`tests/run.lua` on the vendored LibKa0s kit (`tests/_kit/`, revision 46, never edited).
`tests/loader.lua` builds a fresh, isolated addon per case from the TOC's own file list and the
library files `libs/LibKa0s/LibKa0s.xml` names; `tests/wow_mock.lua` extends the kit's base mock with
what this addon reads (combat state, the client's addon list, the chat sink, the launcher's two
libraries, the main window's whole frame tree (each region its own object, with its points, size,
text, text color, texture and check state recorded, and its backdrop, edit-box font and insets, checked texture and hit insets), and the client APIs `core/Compat.lua` wraps: the tooltip
data, the chat sender and lockdown, the restriction state, `C_Item`'s upgrade, bind and GUID
answers, the trade action, the enums it resolves by name and the enUS GlobalStrings it parses),
and a mocked clock: `advance(seconds)` runs the kit's timer queue in due order, and
`C_Timer.NewTicker` is a repeating ticker on the same queue (its handle carries `ticker`).
Suites that need a secret value use `T.secret(v)` and install the kit's `issecretvalue` on the
mock (`m.issecretvalue = function(v) return T.isSecret(v) end`).

Suites reach the harness as `local T = _G.DW_TEST` and build instances with the three factories,
each taking an `opts` table (`skip`, `mock`, `inCombat`) and returning `(NS, env, mock)`:

- `T.newAddon(opts)` — every file loaded.
- `T.bootAddon(opts)` — plus `OnInitialize` (the database, the migrations, the chat commands).
- `T.enableAddon(opts)` — plus `OnEnable` (events, settings category, launcher, the latch).

`opts.skip = T.loadAddon.libFiles` loads the addon with the whole LibKa0s payload absent, which is how
every degradation stub is tested: by a real load, never by a hand-written stub (testing-§8).

Named suites the standard requires: `test_surface_parity` (testing-§8; since AT-A2 it also holds
`core/ToastSetup.lua`'s `NS.ToastStub` to a live LibKa0s-Toast-1.0 instance), `test_vendor_sync`
(testing-§11, delegating to the kit), `test_disabled` (slash-commands-§7; its own cases 9 and 10 hold
every stood-down refusal to `NS.StoodDownRefusal()`: the capture line under the `perf` hold alone, the
one refusal line, unwrapped, while disabled; review F01/F10, DW-P16. Case 3 is step 6: it fires
every event in `NS.FeatureEventNames()` through the kit's `__fireUnconditional` and asserts each
returned count is at least 1, so a fire that reaches no handler fails rather than passing on silence.
Cases 4 and 5 are step 7 over every verb in `NS.COMMANDS` and the bare command, case 8 is step 8 over
both launcher buttons and the Show window key binding's press (one refusal line, no toggle, no write;
case 9 holds the press to the capture line under the perf hold alone), and case 11 is step 10 through `Kit.assertLatchHoldOrder`; review F04 F05 F18,
DW-P25). The addon's own:
`test_harness` (the load, the repository's shape, and the TOC's position labels: no `Conventional:`
comment on a load-bearing position, nor one stating handler order, toc-file-§5), `test_setup` (each
adopted module's wiring, and the shared event dispatcher running every handler when one raises, the
first error raised after the rest; review F03, DW-P18; and `evaluate` and `quality.gate` declared
within `feed.add`, observed inside it on a Receive-only capture, mixed with top level on a later
load or re-judge, and the depth counter cleared when Receive raises; review F06, DW-P24),
`test_database` (the defaults tree and the migration runner: the stamp, a raising step, step 2
reaching a stored profile that is not the active one, step 3 folding the View and its checkboxes
into the View set, step 4 retiring the History's group cap and pruning nothing, step 6 retiring `feed.showOwn`, step 7 retiring the `myEq` and `theirEq` column toggles; step 8 is in `test_content_tabs`), `test_schema`, `test_schema_rows` (every
spec §12.1 setting has a row whose default is `defaults/Profile.lua`'s and passes its own check,
the refused values, the per-spec maps, the readers that go through `NS.Setting`, the M3 handoffs
through the seam, the account-wide Keep history for, the CLI and the degraded load; the item-020 guard,
every stored path with its type and default pinned so a layout change cannot move one; Alerts › Upgrade
glow, feedback-21: every glow row and its default (both proc since DW-03, D-18; `pixelFrequency` 0.1,
H6; the colors `C.TONE.glowMain` `#19FF19` and `C.TONE.glowOffSpec` `#3FC7EB`, apart from the verdicts' tones), the
main | off-spec alternation on every line, the two swatches on one line and their Use class color
companions on the next (off, player-scoped; the pinned options-ui-§17 deviation), the refused values and colors, a style's knobs dimmed
for another style and the style while its glow is off, the color pair never, the
`NS.Glow.Refresh` reaction, `/dw set` on a color and `0 (Automatic)`, its subsections in the Style dropdown's order with Offset first (feedback-24); Alerts › Toast's Scale, feedback-21
G10: its 0.5-2 by 0.05 range, `isPercent`, default 1, dimmed with the toast off, the refused values and its
place after Play a sound; Window › Icons, feedback-21 G11: the Zoom row then the composed Border block in
order (the composer's labels, the quality extra after the mandated four), the H6 defaults (zoom 0.1, a
Solid black border 2 pixels thick), the
color pair player-scoped, starting its line and never dimmed, the refused values, style, thickness and
quality dimmed with Show border off, `/dw set` on the color, and the degraded load keeping Zoom with the
border's profile defaults), `test_settings_pages` (the settings
pages built headless, as feedback-24 and item 020 regrouped them: the page list and each page's strip, a page's rows by its key, the Drops › Situations
table (one line per situation, its Loot rule column, its gold headers and stripe, each cell's value, a toggle writing its
path, the dimmed cells, Defaults and a profile switch repainting it, built once and re-hosted, parked
by its placeholder's own `OnRelease` outside the renderer (options-ui-§19, DW-P21), the rows still schema rows and `skipRender`, stamped to the Drops page), the Drops page's Defaults tooltip and reset reaching the situations, the Drops page's "in force now" readout and its pairings, the switches alone on their line with their knobs paired under them, Messages opening on Sending, Window's Columns note and moved rows, the Comparison page's per-spec
weights and unwanted types written whole through the seam, the Messages page's live counters,
preview, token chips and Reset templates, Drops › Retention's Clear history beside Keep history for
(asking first, clearing on Yes, test mode's samples only while it is on; feedback-15 spec §3), each
page's Defaults, and the editors' pure halves),
`test_slash`, `test_window`, `test_window_shell` (the window's
chrome built headless: the title bar (no Scan group since feedback-16: the Drops strip's, in both
layouts, feedback-7 spec §4), the restriction badge, the tabs and their lazy
panes, the filter bar's per-tab state and its Loot History flat skin, the multi-select View (its values,
label, grayed values and bullet tooltip), the footer's composer, minimize, auto-open on every drop, the
default size, 1080 x 600, as the least width, a tooltip on
every control, the build without the Widgets library, and the pure row predicates),
`test_window_compact` (compact mode's switch, DW-C0: the pure layout, run, size, bounds and corner
reads, schema step 5, the title-bar toggle, each layout's own size and point on the one frame, the
Layout row, and the run override taken on an auto-open and let go when the run ends),
`test_compact_cards` (compact mode's cards, DW-C1, pure: each Drops and History card's
four lines (Trade on line 3, its word and short reason, You and Them on line 4: feedback-22, feedback-25) in every verdict, trade, inspect, ask and outcome state (line 1's item level before the
name and the freshness bracketed right after it or left out (`FreshMark`; a pending read left out too,
Them's `…` saying it, feedback-11 spec §0), `No action` on line 2 with no action (feedback-11 spec
§1, where feedback-10 left the slot empty), no trade window on the card with or without a countdown,
feedback-10 spec §2; your own card's Offer, `Upgrade for N` and ` [YOU]`, feedback-5 spec §2, feedback-7 spec §2; line 4's `You 321/308 ▼8`, feedback-6 spec §1), each piece's tone and
tooltip checked against the full view's composer, the cross-realm mark, and the header's short form, an LFR header cut piece by piece to fit the default width, feedback-15),
`test_compact_group` (the Drops tab in the compact layout, DW-C2: the card's metrics and the
scroll carry-over, the stacked detail card's action flow and height, pure; then the cards built
headless: one pooled card per drop under a one-line header, each piece's text, color and full-view
reason tooltip, every tooltip at the card's top right, the stacked detail card inline, Ask in its
state's tone and no card dismissable, the ask states and the gray `No action` with its reason, never an empty slot (feedback-11 spec §1), the text size, the pool's reuse, the
collapsing headers; each card indented under its header with the muted-white chevron, no card
showing a trade window and a second's tick leaving the cards as they are (feedback-10 spec §2), Them's last piece cut at the
card's right inset (feedback-11 spec §0), and
the least compact width, 400 (440 until feedback-23), at which line 2's fullest pieces end before the
action button, feedback-5 spec §0, §4, Trade on line 3 ends before the button (lines 2 and 3's) and is
cut there, and line 4's two dual marks, under the button, still read both rings, feedback-21 H7, feedback-25,
and at a wider character measure give way to the one mark each, feedback-21 R5),
`test_compact_history` (the History tab in the compact layout, DW-C3: the kept entries as cards
under one-line headers, the outcome in its tone, the time, the row menu on a right-click, declined
repainting, the collapsing headers, every tooltip at the card's top right, the strip without Clear
history in both layouts, the text size and test mode's samples),
`test_history_card` (the History tab's detail card, feedback-15 spec §4, DW-Q4: the pure `Model`
over a kept entry, the header's chips, For you at the time, For the group and your own drop's, the
recorded trade estimate, when and where and the actions; then headless, a row click expanding it
under the row with the chevron up and the rows below moved, one at a time, a right-click still the
menu, the columns after the indent and chevron, Link in chat, Mark and Clear declined, Show in Drops
selecting the Drops tab with the drop's header open and its card expanded, and the stacked card
under a compact card),
`test_compact_chrome` (the window's chrome in the compact layout, DW-C4: the short tab labels, `TEST`
and `SIM`, the badge's count, the footer's one line and its tooltip, the Filters count, label and
tooltip, pure; then headless: the short title centered with its word, the badge at the left with its
tooltip, Scan group as an icon button, the short tabs at their width with the full names in their
tooltips, View, the search box and Filters on one row with Quality, Content, Character and Sort
moved into the Filters panel and filtering as on the full bar, the panel closing on hide, minimize
and the switch, the full layout taking every control back (Sort to the tab's strip, feedback-10
spec §3), the one-line footer
under the ticker, and the filter state kept across a switch),
`test_compact_modes` (the two layouts over one engine, DW-C5, compact spec §5: the same drop set, the
full table and the compact cards drawing the same drops and headers in the same order on every tab,
for test mode's samples and a simulated dungeon and open-world run, under every View, Content,
Character, search and Sort, with a group collapsed, a drop expanded and your own drops shown;
switching back and forth on every tab leaving every verdict, trade state, inspect status, feed
count, history entry and send as it was; and every test-mode state on a compact card saying what
its full row says: the verdicts, trade words, ask states, inspect freshness and worn levels on
Drops, your own drops' Offer and `Upgrade for N` among them (and no countdown on the card,
feedback-10 spec §2), and every outcome on
History),
`test_window_group` (the Drops table: every cell's text, glyph, tone and reason tooltip for
each verdict, trade, inspect and ask state (one tone per verdict in Me and Them, the arrow first;
`ActionTone`, Offer's cyan; the Type column's every value; feedback-4 spec §0, §1, §3, feedback-6 spec §2), the merged Me and Them cells,
the column sets and the entry order, then the table
built headless: pooled rows, collapsing headers, the item button's tooltip, link and dressing room,
the item tooltip at the row's top right, else its top left,
the Ask button, its repaint and its tone by state, the gray `No action` (`ban`) with its reason where
there is no ask (feedback-11 spec §1), no row dismissable, the Type column after Slot,
the shed order (Trade window among it), the Trade window column on every drop (another player's an
estimate, its bar, the row taller by the bar's room, the countdown moving each second, feedback-5
spec §1), the hand-off to the compact cards, the filters, the empty
state and its two buttons centered as a pair (feedback-7 spec §4), and the filters' empty line), `test_drops_layout` (the Drops table's
geometry, split from `test_window_group`: every column shown at the least width, 1080, and neither
tab shedding there, the search box spanning from Character to the bar's edge, the gold column
labels, the 84px Actions, each drop row's muted-white chevron and indent under its header and the
header's gold chevron, the Trade window column pinned to its widest `MineCells.TradeWindow` answer
plus its padding, 76, feedback-4 spec §4, feedback-5 spec §0, §4, feedback-6 spec §0; every action
button's icon and word fitting its width, feedback-7 spec §1, `No action` in the 84px `ASK_W` and the Offer
panel's 80px `PANEL_BTN_W` included, feedback-11 spec §1),
`test_side_cells` (the Me and Them cells, feedback-6 spec §1, DW-F1, pure: every verdict kind, two
worn items, an empty slot, every inspect state, your own drop's `Upgrade for N` and `No upgrades`,
the merged tooltip with its gear grid (two worn items two rows, the arrow on the replaced one, a slot
worn empty its own row) and History's verdict alone; the dual mark on two worn items both read, a
mark per item in its own tone, and every case that keeps one (feedback-21 H7), a drop judged against
one of two worn items or a bag item among them (feedback-21 R5); the Offer panel's Their eq
(`SideCells.Candidate`, feedback-7 spec §0) in every candidate state and at least Them's width; then each column's width measured over every kind at the harness's
character measure (the dual mark's longest realistic cell inside them), the shed order, and the cells
painted headless on the Drops table, a dual mark too wide for its cell painted as the one mark, R5),
`test_detail_card` (the detail card: the header's chips, both comparisons, the trade box and
the actions with their reasons, state by state, then the card built headless: the row click that
expands it inline and moves the rows below, one row at a time, a reason on every line, each action
through its host handler, the first action's `No action` with its reason where there is none
(feedback-11 spec §1), no Hide this item, the card indented with its row, Offer (cyan), `Upgrade for N`, no
Looter row and a row per member it upgrades on your own drop, a looter who left the group: the Spec row from the drop's kept read, `not in your group` without one (feedback-21 H2), the card's marks as the table's glyphs in the monospace face, the titles' muted gold and class-colored name, the Stats row's colors and the Replaces row's item level first and quality color (feedback-21 H5), the Item level row's dual mark, composed and painted (feedback-21 H7), and the Edit message box), `test_mine_cells` (`NS.MineCells`, pure: the countdown and
the Trade window cell, exact and estimated, another player's naming its looter, ending soon in tone
and tooltip only; the candidates ranked with their judgment, the buttons' lifecycles and tones
(`ToneState`), the Trade button gone, every state of every action look table carrying a shipped
icon and the detail card's actions wearing their state's (feedback-7 spec §1), the strip's summary and its short compact form, Post my tradeables' lines, the
Offer panel's header and its dock), `test_own_drops` (your own drops on Drops, feedback-5 spec §2,
DW-E2: always listed; Trade's `Yes` with the upgrade count in its tooltip, Them's `Upgrade for N`
and its grid ranked by gain, the looter's gold `[YOU]`, Trade's `No` in red (feedback-7 spec §2), the keep? rule's `Hidden` until the Offer panel is opened, Offer toned by the furthest offer
sent and `No action` with the reason where it cannot be traded (a dash until feedback-11 spec §1); then the table, the detail card and the compact card painted
headless), `test_tip_marks` (the tooltips' verdict marks and lines, feedback-6 spec §3, DW-F3:
`NS.TipMarks`' escape strings, the TGA size, each mark and its fallback without the media library,
the class and quality colors, the non-wrapping line added unwrapped, `Upgrade for N`'s grid rows ranked and
colored with the lower of two rings named; the gear grid, feedback-7 spec §3: the arrow cell's glyph and
number in the verdict tone, a member's rows, the columns' widths and gap (`TipGrid.Columns`), a grid
painted headless as columns on reserved lines with the glyph in the monospace face, and
`Compat.TooltipLeftLine`; and audits that no column tip, `L[]` string or test-mode
tooltip on either tab in either layout carries → ▲ ▼ ≈ ⊘ or ⊕; DW-F5: the arrow texture, the
drawn-width count, and an audit that no text test mode draws in the default face, on Drops, the
detail card, the Offer panel or History in either layout, carries one; the tooltip rows, feedback-21:
`TM.Row`'s `• Label: value` and its nil value, `TM.Hint`, `TM.BULLET`, one row-shape case per builder
family, and an audit that every tooltip test mode attaches is its title, rows and grids, then only a
closing hint), `test_glow` (the upgrade glow, feedback-21: `Glow.KindOf` on every verdict shape and
your own drop, and no glow on an upgrade whose trade is not Yes or Likely, feedback-22, the headless `glowKind` and each glow's `enabled`, each style's arguments through a
fake LibCustomGlow, no library call on an unchanged repaint and a restart on a setting or a size, the
drawn color with and without Use class color (the player's class, the swatch's alpha, the swatch for
a class with no color), each
of the three surfaces' icons, the toast's never, a reused or unused pooled row losing it, a glow row's write and a profile
copy re-applying), `test_icon_style` (every item icon's look, feedback-21 G11: the H6 defaults (0.1
cropped a side, the Solid flat edge 2 pixels thick, black, drawn without LibSharedMedia too), Solid
registered with LibSharedMedia at load, zoom 0 with no border drawing the whole texture with no frame
made, the zoom's crop and its clamp, an unchanged repaint making
no call, a row's write restyling every button made so far (one showing nothing too), the border's child
frame made on first use with LibSharedMedia's texture, Solid's flat edge or the tooltip's edge, its size and swatch, Use class
color (the player's class, the swatch's alpha), Color by item quality (the cached item's quality color,
an uncached link's own color, the swatch's mode for no quality), the Drops row, its Me icons, the detail
card's header, the compact card and the toast styled live, the glow's frame level over the border, and a
profile copy re-reading it), the six skin suites (the skinning rollout, DW-01 to DW-04): `test_skin_setup` (the seam: the owner and its facade, the twenty-one `dw.*` owner tokens at Ka0s Default's pixels and their follow tokens elsewhere, `C.TONE` refilled in place, the seven `skin.*` rows, `/dw set` on a skin, an exception and an override, the write seam, the Skin tab's place, one pick one repaint, the profile's skin applied after AceDB and on every profile event, the factories built for the owner, the TOC's place and EllesmereUI, and the degraded facade), `test_skin_chrome` (the window's pixels under Ka0s Default, a switch repainting every surface and the cells' tones, the font size held across a switch, the verdict glyphs in `font.mono`, the shown toast's repaint, the token escapes, the quality colors as the skin's `q.*` tokens (Ka0s Default's the client's own) and the degraded window), `test_skin_hud` (the icon border's companion: on by default, the stored style and thickness unread while it is on, a switch restyling every button, a skin's None, the glows' colors kept, the composed row and its dimming, the degraded load; migration step 10 running once per stored profile, keeping a later pick, idempotent and sentinel-free, handing the library an unseeded companion with `{ companions = true }`), `test_skin_picker` (the first-run picker: its row and spec, an unseen profile showing it, the login fuse, the stand-down and stand-up, the combat hold, the off and perf holds, a new or reset profile, who marks it seen, preview, Apply, the close's put-back, the gear, the eye, a pending preview on a stand-down or a profile switch, and the degraded load), `test_skin_settings` (the pages' own AceGUI widgets painted past the proxy and restored on release, the Situations placeholder's undo and its cells following a switch and Ignore settings panel, the Profiles tree, the degraded load, and the tool windows owned by this addon) and `test_skin_literals` (no color literal outside `core/SkinSetup.lua` and the named allow-list in `ARCHITECTURE.md` → Skins, each entry reasoned, and the gate falsifiable), `test_layers` (frame-layering, item 030: the one `NS.Constants.LAYERS`
table's strata keys and level order, then every frame class through the kit's frame-layer recorder,
which `tests/wow_mock.lua` installs on every instance: the window MEDIUM, toplevel and clamped, the
Offer panel in the window's strata at W+1 docked and W+30 floating, the compact Filters panel at W+35
with its dropdowns over it, the Edit message box DIALOG at W+40 and toplevel, the toast HIGH and
toplevel (LibKa0s-Toast-1.0's T5 tier, `LAYERS.STRATA.ALERT`), an item
button's border explicit at +1 under the glow at +2, and a static scan for strata literals and absolute
levels in `core/`, `modules/` and `settings/`), `test_drops_strip` (the tab strip, Drops and History, the retired `mine` opening Drops;
the strip under the table or the cards counting your listed tradeable drops, its filters applied,
collapsed or not, its next expiry moving each second and keeping
the ticker running, Post my tradeables through its handler, and the compact strip's summary
shortened, shown there with nothing tradeable too; feedback-5 spec §3, DW-E3; feedback-7 spec §4,
feedback-10 spec §3 and feedback-15 spec §2: one right-aligned row, `[Post my tradeables] [Scan group]
[Expand all] [Sort]`, Post at Sort's size, Scan group through its handler, Sort following the active
tab to History's strip right of the toggle and back, the pure `Row`, and the full
layout's strip shown with nothing tradeable, Scan group in its place),
`test_footer_row` (one footer button kind and Expand all / Collapse all, feedback-15 spec §2: the pure
`Slots`, `FoldState` and `FoldAll`; every footer button `FOOTER_BUTTON_W` wide with the same label in
both layouts, each tab's row right to left in both layouts, the info ending where the row starts, the
compact Drops strip always shown, no Clear history on History's strip; the toggle's words, both directions, on both tabs in both layouts,
off with no header, each tab's collapsed state its own), `test_offer_panel` (the Offer panel opened from your own drop's
Offer, built headless: docked beside the full or compact window on the side with room, the
candidates ranked with Their eq in the Them look (both worn items from the read), no class bar and
every second row striped, every part's reason tooltip (Their eq's holding the old pill's
explanation), Offer and Announce to group through their host handlers and toned by whose move it
is (Offer cyan, Offered yellow, Retry and Announce red), a member it is no upgrade or equal for showing
the gray `No action` with its reason (feedback-11 spec §1), the Edit message box, closing, the Offer
button's toggle from a row, a compact card and the detail card (feedback-21 H4); then the
host handlers Post my tradeables, Offer and Announce),
`test_row_tooltip` (the one row-tooltip placement, DW-B2: the tooltip's bottom left at the row's
top just outside the window, else its bottom right outside the left edge, at the UI scale, the row
a cell sits in, the docked Offer panel as part of the window, the fallback on unknown geometry, then
every cell, button and header of both tabs placed by it, the column labels and tabs not),
`test_test_mode`
(test mode's samples: every Me and Them verdict, trade estimate, inspect state, ask state, countdown
and candidate status covered by the data, over pool items that keep their slot and level, the worn
items the nearest of their slot, an empty pool giving none; feedback-17's realism: each group the
size its content brings (five, twenty, twenty-five), the session's seven groups and twenty-nine drops (feedback-22: the unique ring on both sides, every
short trade reason, an upgrade that glows and ones that cannot),
History's twenty-plus groups across every content within 30 days, each group one real place whose
loot is that boss's or dungeon's at the group's difficulty, the keys' loot read at Mythic+ 10 with the
journal's preview put back; feedback-18's Me: with your real gear all at 999, every sample's You in both
layouts is its own worn gear, the first slot the item its detail card replaces; feedback-19's off-spec
samples: every off-spec verdict, an empty slot, a bag item and a worn one, askable only for an upgrade or a
sidegrade (each tradeable, so a downgrade's No action says it is not an upgrade), a wrong armor type
left Can't use, an Offer candidate's off-spec ranked below main-spec upgrades and above a downgrade,
History's asked and received off-spec entries (none in the alt's group), and the drawn Me cell
cyan with the spec's name and its detail card's Spec row; the History sample with every outcome;
`AddTest` and the test feed filled from the mock journal's pool (`seedGearJournal`) and emptied
with test mode, while the pool loads, with no pool at all, by combat and by the stand-down; the
History tab's samples never written to `global.history`; the window built headless with every
sample drawn with a real icon, a reason on every cell, the TEST MODE text and banner, your own
samples on Drops; no button label or Trade window cell ending in an ellipsis; Ask and Post my tradeables printed,
never sent), `test_compat` (the compat seam: the
secret guards on both load paths, the localized duration decoder in three client languages, the
tooltip line reader, the trade window's items and partner, the row menu, the optional-addon probe
`IsAddOnLoaded` (DW-P20), the Pawn seam against a fake shaped like Pawn 2.13.6 (its `PawnIsReady()`,
the scale asked by spec index, the unenchanted value; feedback-21 H1; the scale you show, a custom one
first, R4), and each shim's fallback with its API absent), `test_text_parse` (the pure text parsers of `core/TextParse.lua`, the
localized strings passed in, and that the module reads no global), `test_constants` and
`test_class_data`
(the game-data tables and their lookups, each spec's place in its class among them), `test_evaluate` (the verdict kernel, table-driven over
every slot plan and every equippability path, the `either` of a baseline picked from two worn items
(feedback-21 R5), plus nil and garbage inputs), `test_offspec` (feedback-19 spec §0: the off-spec
verdict `modules/OffSpec.lua` attaches to a main-spec Can't use whose refusal depends on the spec,
each other spec of the class judged against its own gear by item level, the best kept as
`eval.offSpec`, the main verdict never changed), `test_offspec_cells` (DW-O1: how off-spec looks:
the `offspec` cyan, the verdict cell through `WindowCells.Verdict`, the Me cell from the off-spec
baseline, the compact line, the marks' tone override, the detail card and the History snapshot and
card, the filter bar and the legends; a Can't use with no off-spec pinned unchanged),
`test_offspec_ask` (DW-O2: the `askOffSpec` template's pick, text, row and editor, {mygain} from
the off-spec result, the Ask button's tooltip, the toast and auto-ask, main spec first),
`test_offspec_offer` (DW-O3: an off-spec Offer candidate ranked after every main-spec upgrade and
equal, its Their eq cell `311 ▲14 Holy`, Upgrade for N and keep-hidden staying main-spec only, and
the Offer whisper's {gain}), `test_scoring` (the
scorers: the Pawn scale import, the weights score and its unknown keys, the adapter in use for each
setting, the Pawn adapter's scales (for you, the scale you show in Pawn before a starter one you hid;
feedback-21 R4) and `pending`, and the sidegrade item level and score reach
through the kernel and the feed), `test_quality_gate`
(the minimum-quality gate: each mode, the floor, empty slots, ties, both overrides),
`test_situations` (the situation classifier's truth table for every key, the per-situation settings
and their spec defaults, the six re-evaluation events and the stand-down), `test_trade_rules` (the
trade estimator: every row of the Estimate table in order, the trade window, the rule per situation
and the owner's override map), `test_messaging` (the messaging core: token expansion, the length
limit, the one-ask guard, queueing under restriction, the flush order, cancel and a failed send's
retry, and `FurthestState`, the furthest state any ask of a kind reached for one drop), `test_restrictions`
(the restriction tracker: each restriction type's reason and what it
blocks, the priority order, the chat lockdown, the combat edges ahead of the client's flag, the
event's numeric, boolean and secret payloads, `RestrictionChanged` and the stand-down), `test_roster` (the roster: solo, party and raid
tokens, the realm normalization, resolving by GUID, Name-Realm and bare name, the same-name tie
settled by classFile and by the player's realm, the re-read on a miss, the shared
`GROUP_ROSTER_UPDATE`, secret unit answers and the stand-down), `test_item_facts` (the item facts: every field of a
cached item, the track tier by string id and by name, the tooltip track, uniqueness, tier tokens and
class gear, the link-color quality, the facts feeding the verdict kernel, the cache and its cap, the
appearance event, the load with its retries, the give-up, a client that cannot load, and the
stand-down), `test_item_read` (BUG-1 and BUG-2 of the M8 feedback, DW-80: the reproduction with
realistic 12.x links per loot source and each hypothesis proved or refuted, the merge keeping the most
complete link (loading and hidden drops included), `core/ItemRead.lua`'s link detail, better link,
identity, effective level, location reads and quality, the bag match by identity, an own drop read
from its bag item, the `drops` diagnostics line, and the real game tooltip: bag slot, worn slot,
link, and the addon's line after the game's), `test_gear` (the gear snapshot: each worn slot at its current level, empty and loading
slots, the candidate's class, spec and hand flags, the per-slot qualities, the owned best per slot
with pairs, dual wield, held off hands and Titan's Grip, tier tokens and secret links left out, the
candidate judged by the verdict kernel with and without the bags, the throttled rebuild and
`GearChanged`, a bag event in combat deferred to its end, a bag-only rebuild keeping the worn slots,
bag items with no slot plan never asked of the item facts, the spec event, the quiet first read, an item still loading, and the stand-down),
`test_loot_parser` (the loot parser: every `LOOT_ITEM*` variant, self and third person, single and
multiple, bonus roll and pushed; same-realm, cross-realm, hyperlinked, colored and unknown looters;
the upgrade and crafting echoes rejected; non-receipt lines and non-item links ignored; secret text,
a secret GUID and secret, empty or absent globals; globals rewritten at runtime and rebuilt; a deDE
client and positional arguments; the event's sinks, counters and twelfth argument; and the
stand-down), `test_inspect` (the inspect broker on the mock's clock, `advance(seconds)`: one inspect
in flight, the 2s spacing, the priority order and a raised job, the ready timeout and its one retry,
the range and identity waits, `CanInspect` false and an offline member, incomplete and nameless
links retried and kept, the tooltip level, the fast path and its hidden-slot guard, a read with no
data (cleared before the read, or a moved unit token) re-queued, failed or dropped and never stored
as `fresh`, a foreign inspect before and after the
data arrived, anyone's `INSPECT_READY` read, the combat park, the open inspect window, the TTL, the
invalidation and its echo guard, the roster prune, the warm-up and `Scan`, the candidate judged by
the verdict kernel, `InspectDone` after the items load, one debug line per job, secrets, and the
stand-down), `test_feed` (the feed: a member's drop judged for you, its looter's inspect asked for
and their verdict and trade arriving with `DropUpdated`, the read kept on the drop once its looter leaves the group, through any later re-judge (feedback-21 H2, R4); the trade re-made over time, a group drop
past its window turning `no expired` on the sweep, your own drop taking the timer's `yes` and then
`no expired`, a timer moving it off `no` asking for its candidates, a BoE drop keeping its bind; the dedupe across chat, the encounter loot
event and the loot history in either order, by GUID or by name, a GUID learned from a later source,
two copies and another looter's copy kept apart, the window's end; the loot history taken once with
a winner; the grouping by trash, a kill's loot window, a wipe, an earlier encounter's late loot, a
keystone run with its chest, the open world; the gate order, the situation hiding a drop before its
item loads and the quality gate before any inspect, the upgrade override, the stored quality
settings and a situation's mode; the pure filters row by row and the relative item level; an item
still loading and one that never loads; your own drop with its trade by your verdict and every
member a candidate, no inspects for an untradeable one, pushed items; `GearChanged`; the score
retry and its limit; `Add`, the test feed and `Clear`; the cap; secret payloads; and the
stand-down), `test_feed_counts` (feedback-2 spec §0: the owner's two-Yoke chat lines through the
real parser and feed, the accented cross-realm looter, both Yokes kept apart, the reagent and the
altar hidden by the gear-only rule and the reagent by the quality rule with it off, the currency
and money lines never read as loot; every hidden and refused receipt counted by reason, logged
under FEED and reported in the `drops` diagnostics section; the group headers' `2 drops · 1 shown`
and the tooltip naming each hidden drop and its filter, on Drops and History),
`test_group_roster` (feedback-2 spec §3: the roster snapshot's pure core, `Entry`, `Merge` (it
only grows, you first, never the same character twice), `Copy`, `Names` (the first few then `+n`,
every name by default, class-colored, the realm when not yours) and `TipRows` (the tooltip's
`Group (n)` rows, five names a row, every member, feedback-17); a feed
group taking the party with its first drop and a mid-run joiner on the roster event or with the
next drop, its History group keeping it; the Drops and History headers naming only the
recorder (feedback-3 spec §4), and an older History group with no `Group` rows; test mode's sample
rosters are `test_test_mode`'s and a simulated run's `test_sim_e2e`'s),
`test_group_place` (feedback-3 spec §4, DW-B4: `GroupPlace`'s pure `DifficultyName`, `Parts` (with its roles and
`ShortNames`' LFR, feedback-15) and `Who`; Compat's `DifficultyName` and `KeystoneLevel`; the owner's Timewalking drop through the real
feed, its header `Gate of the Setting Sun · Commander Ri'mok · Timewalking · 1 drop · Testchar` and
its History group keeping the place and the recorder; a group keeping the place it opened in; a
key's end chest reading `Mythic+ <level>` after the run completed; the open world's situation-word
fallback; test mode's and the simulator's realistic instance and difficulty names),
`test_char_filter` (feedback-2 spec §4: the Character dropdown's pure core, `Key`, `IconMarkup`,
`Passes` (All passes everything, a drop with no recorder only All, the session sentinel is you),
`Canonical`, `Label` and `IsCurrent`, `Characters` and `Options`; your recorder read live and
unknown until the realm is; every drop record, test placeholder and History entry stamped with who
saw it; the dropdown after Content on every tab, multi-select, Current by default on Drops and All on History (feedback-13 spec §0), the session
tabs listing you alone and History every recorder; History filtered by it, unknown only under All,
a group it leaves empty with no `0 shown` header in either layout (feedback-12 spec §1);
`HiddenBy`'s `char` reason and its label; test mode's alt group is `test_test_mode`'s and a
simulated run's recorder `test_sim_e2e`'s),
`test_trade_timer` (your own drops' trade timer: the `TradeTimeRemaining` line read
by its type and keyed by item GUID, a line of another type ignored, the localized sentence decoded
from deDE-shaped globals without the line type, no line read as `no expired`; the match by exact
link then item id, one item per drop, a stranger's item, a member's drop and a test drop untimed,
a moved item kept and a removed one dropped; the three scan triggers sharing one throttled scan;
the ticker slow while the window is hidden, fast while it is shown and off with nothing live, one
ticker for every item; the warning once per item at the threshold with its message and chat line,
at once below it, off at 0; secret links, GUIDs and lines; and the stand-down keeping the warned
flags), `test_trade_helper` (the trade helper: combat refused before the range is read; a
stranger, yourself, an offline member and one out of range; the stand-down; every reason's tooltip
line; `Open` and its missing API; the diagnostics line), `test_asks` (the messaging edge: a
whisper to the looter's Name-Realm with the template expanded from the drop's tokens and one
confirmation line; an empty slot's gain read as `an empty-slot upgrade`, never the item level, its `+` dropped; the one-ask guard and `messages.oneAsk`; an edited text over 255 bytes; a
stranger, yourself, an offline member and a missing or secret target refused; an offer to a
candidate; a raising sender failed with its message and retried, a secret error, no sender, the
deprecated global fallback; the announce channel (a stored Party, Raid or Instance channel refused
`noChannel` outside that kind of group, and retryable; Post my tradeables the same; DW-P17); queueing under a restriction and the flush on
the lift, `ENCOUNTER_END` and `CHALLENGE_MODE_COMPLETED`, one send every 1.5 seconds first in first
out, stopped by a lockdown mid-flush; cancel by a second press and when the looter leaves, and a
queued announce once it has no channel; test mode printing instead of sending; the stand-down),
`test_transmog` (the transmog-known flag: CanIMogIt answering first when loaded, its no-appearance
answer, a raise or a non-boolean falling back to `C_TransmogCollection`, and the source named; the
item facts reading through it; the ask template picked for a drop (the plain ask for a gain, the For
transmog ask only with `messages.transmogAsk` on and the look known missing); its default text and a
request that names it; the detail card's `New look` and `Look known` chips; the Ask button and the
card's actions offering it; the edge sending its text under the ask's key; its settings rows and
preview sample; the test mode placeholders; the diagnostics lines),
`test_history` (the history: the shape made in place with the retention row kept, the snapshot
kept small, no group cap, 50 drops a group and the safety ceiling (the oldest drops first, an
emptied group with them), outcomes moving forward only, an expired trade, declined set and cleared
by hand, the trade match by partner then item id and your own drops traded away; then the edge on
the bus: a live drop recorded and a test drop never, `DropUpdated`, a sent ask, offer or announce;
a completed trade marking `received` and the Ask button `Traded`, one given away, and an
unfinished or changed trade marking nothing; Clear history behind its
confirmation (`History.AskClear`; the strip has none since DW-Q3); the diagnostics line; and the History tab built headless: kept groups newest first,
the outcome column in the action buttons' tones (feedback-12 spec §0), a reason on every cell, a header toggle, Content's This session, the row menu
with and without the client's menu, the empty line and `HistoryChanged`'s repaint),
`test_history_retention` (Keep history for, feedback-2 spec §5: the labels, choices and footer, a
group's age by its newest entry, Count deleting nothing and Prune deleting whole groups; the row,
account-wide with its listed windows; a longer window or one that deletes nothing taken at once, a
shorter one asking first with Yes pruning and No writing the agreed window back, headless pruning
at once; the login prune once per session, deferred, taken back by the stand-down and armed again
by the stand-up, Never delete keeping everything; test mode's ten-day-old alt sample pruned by a
7-day window while the account's log is kept),
`test_feed_restore` (the session is the login and the Drops tab survives a reload, feedback-15
spec §0: the per-character session start an initial login sets, a reload keeps and a zone change
leaves, stable with no stored value; after a reload this session's drops back in the feed under
their History group's key, label, place and roster, dated by the client clock, judged anew and
linked to their entries, nothing recorded twice; an initial login restoring nothing; this session's
and this character's entries only, gone ones skipped, the newest `MAX_DROPS`; restored drops never
merging with each other while a live line merges in; the quality gate kept and the situation gate
and filters skipped; no auto-open, toast or automatic ask for a restored drop; a drop asked for
before the reload reading Asked after it; drops cleared from the Drops tab (`/dw clear`, Clear on
boss kill) staying cleared; the false Expired a
live timer read undoes, and nothing else does; This instance kept across a reload in the same
situation and instance only),
`test_content_tabs` (Content per tab, feedback-15 spec §1: Drops offers This instance and This session,
History adds All, a value the tab does not offer refused; the dropdown's rows the active tab's in both
layouts; the one tooltip; Drops' This session from the stored login in the client clock; the
`feed.content` row's two values; step 8 turning a stored `all` into `session`, per profile, idempotent),
`test_toast` (the toast: the pure qualifier, someone else's upgrade for you of `toast.minGain` or
more (or into an empty slot, whatever the least gain) with a `likely` or `yes` trade, and every
reason it refuses, and the board 06 C texts, `empty` for an empty slot, the dual marks on a two-item
slot and the width they widen the toast to (feedback-21 H7), the scaled figures (DW-05: 90 tall,
DpsRace's new-best toast, every size times 90 / 74); then
the edge: on for a new profile and nothing built while it is off, a qualifying drop shown and painted and gone after its duration, one at a
time with each drop once, the queue's cap, a drop that turns likely on its `DropUpdated`, the hover
pause and its resume, combat holding it and `toast.inCombat`, a drop asked for or gone skipped, the
Ask button through the host handler, the sound, the drag only in test mode with the point saved and
Reset position, `toast.scale` applied live and at the build about the saved anchor, the point saved in
UIParent's units and unchanged by a scale change, a profile switch taking the incoming scale
(feedback-21 G10), test mode's placeholder toast, a drop leaving the feed (a clear, the cap's trim)
taking its toast and its place in the queue, an Ask on a gone drop, no typed `×` close mark when
Core has no close mark (Ask in its corner, a right-click still closes; DW-P21), no toast at all
without LibKa0s (the seam's stub), turning the toast off
or switching to a profile with it off, the stand-down and the diagnostics line; and, on the
LibKa0s-Toast-1.0 shell since AT-A2, what the player saw before kept: a point saved before the
shell placed with no migration, the icon and Ask holding the countdown, a drop met in combat after a
switch's Clear still held and `toast.inCombat` turned on mid-combat showing the next, a toast
held for combat coming back with its full duration, `toast.inCombat` turned off mid-combat (by its
row or a profile switch) keeping the toast on screen up and holding the next (AT-A3), and the
drops gone from the feed leaving the queue on a shell whose `Stats` names no waiting keys),
`test_auto_ask` (auto-ask: the pure `DueAt` and the delay's clamp; then the edge: off by default, a
qualifying drop whispered after the delay once with the ask template, the delay and least gain
read from the rows, an upgrade into an empty slot asked for whatever the least gain, a sidegrade,
your own drop or an unknown trade left alone and a later `likely`
scheduled, held through an encounter and due after its end, a loading screen or a new zone ending
a hold with no Encounter restriction left (and keeping it while one is, until its lifting after the
world event; a lifting with no world event keeping it), an encounter ending after
the drop pushing it back, each cancel rule (your own ask, the looter leaving, the item
received, a drop gone or no longer qualifying when due, turning it off, the stand-down), only drops
from after it was turned on, the one-time notice, test mode printing instead of sending and the
diagnostics lines),
`test_sim_core` (the simulator's core: the seam wraps every Compat member that answers for the
client and no pure one, a provider answers only while a simulation runs and a live read skips it,
the guarded sender prints `[sim]` and never reaches the client (an ask through the real messaging
edge included), no real inspect or trade, each refusal and the line it prints, test mode refused
while one runs, an event delivered to the handlers its registration calls, the simulated Encounter
restriction and lockdown, its timers, the session-only history log with saved history untouched,
a real drop or trade arriving while one runs kept real and saved, a raising handler or stop step
isolated so the driver and the rest of the cleanup go on,
a stop that takes its drops, groups, inspect entries and restrictions and leaves a real drop, a
queued ask canceled before the lift so it never goes out, the situation re-read, the automatic stop
on joining a group or entering an instance, and the stand-down),
`test_sim_pool` (the simulator's item pool and group: the journal shims and their absent
answers, the world-boss flag, the boss names and the keys' preview level set and restored, an
`everything` read covering both sides (feedback-17), each situation's side and difficulty, a read of every instance of the newest tier at every
difficulty with the player's selection restored, even when a read raises, no read while the
journal's frame is shown, the wait for `EJ_LOOT_DATA_RECIEVED` and its timeout keeping what loaded,
the class filter, the own-items fallback reported once, the stop ending a waiting build; the seeded
random source, a party of four and a raid of nine to nineteen with distinct names and GUIDs and
each spec its class's, the gear drawn inside the band from what the class can wear with the rest
left empty and the off hand empty behind a two-hander, and the group kept on the session and
forgotten by the stop),
`test_sim_events` (the simulator's event drivers and its world: every `LOOT_ITEM*` shape written
from its GlobalString and read back by the parser, a reordering locale written in its own order, a
burst's size, your own lines and its looter from another realm; the roster, the situation and the
announce channel reading the invented party or raid while a live read sees the real world, and the
stop putting it back; a member's line, bare or Name-Realm, reaching the feed under their GUID with
saved history untouched; an inspect read through the broker's queue after the reply, never the
fast path, giving the looter's verdict, a failing member timing out and one out of range giving up,
the reply delay replayed by its seed; a pull's combat edge and Encounter restriction with the ask
queued and flushed (printed) after the kill, loot after a kill grouped under the boss, a wipe not
counted, a keystone run's group and ChallengeMode restriction; your own drops in your bags with
their trade windows (the ending-soon one closing) and the scenario's window; a simulated trade
settling `tradedAway` and `received` in the session's log with no real trade, and its refusals; and
the stop ending the combat edge and the bag items),
`test_sim_scenario` (the simulator's scenarios, timeline and controls: the pure verb parser and
timeline; `/dw sim` through the real dispatcher with its status, usage and refusals, refused while
disabled, in combat and with test mode on; a scenario's pool, group, situation and window, a raid
sized by its argument; the timeline waiting for the pool, a step at a time, a run a few seconds per
step to its end, the stop and the stand-down ending a playing run; the SIMULATION text, the footer's
`Simulating` line, the `sim` diagnostics section and the `SIM` debug lines; and the end-to-end
scenarios (spec §7): a `key` and a `raid` run headless, asserting drops parsed from the written
lines, your verdict and the looter's after the simulated inspect, the ask held in the lockdown and
flushed, auto-ask firing after its delay, your own drop's countdown, a simulated trade in the
session's log, saved history untouched and the real chat sender, inspect and trade never called),
`test_sim_e2e` (the sim feedback regression, DW-90: a scan failing any module that names a world
global the simulator answers, the seam wrapping every world read, the combat flags and the
GlobalStrings; every scenario run in the real solo, out-of-instance world, at the content's level and
outgearing it, with drops in the feed, your verdict and the looter's, a chat line per step, the
footer's `Simulating` and `Inspect n/n`, and rows on Drops, yours among them, under the default
filters, and the History footer's `kept for 30 days` with a shorter window that deletes nothing of
the fresh run and so asks nothing; the combat flags during and after the simulated fight, the loot lines written from the
GlobalStrings Compat reads, `raid1` as you and online in a raid, and Raid Finder's instance chat;
every scenario runs once in each layout, DW-C5: the full table with Compact view when it auto-opens in a
run off, and the compact cards with no piece of any card blank; and a simulated key's auto-open is
compact by default and full with the option off, the stored layout back once the run is stopped),
`test_sim_report` (the owner's `Loot: 2 drops` with one drop shown, DW-B0, feedback-3 spec §0: the
root cause reproduced, your own drop on Drops and nothing lost; the pure `Place`, `Summarize` and
`TipLines`; the panel row, its tooltip and the chat line; a Drops header no longer counting drops of
yours apart; `/dw sim loot`'s line; and the regression over every scenario: each loot step's drops on
Drops and hidden add up to its count, the minimum item level gate hiding them all included; and the
report honoring test mode's feed, `feed.showOwn` retired, feedback-5 spec §2-§3),
`test_sim_panel` (the simulation step panel's DropWatcher content, DW-04: the panel is
LibKa0s-Sim-1.0's, whose own suites pin its rows, states, controls, click-ahead, stale-click guard and
placement order; here the descriptor's presentation fields and nothing else, the step names with
their bosses and loot counts, each kind's tooltip and Start's and Stop's, the scenarios' names and a
raid's sizes in the picker, the done tick's texture, `/dw sim` and `panel` opening or toggling it,
the dock beside the window, also once a slow pool opens it, a drag writing nothing to the profile
and Reset position redocking, and the stand-down hiding it, idle or running),
`test_bindings` (the Show window key binding, launcher-§6: `Bindings.xml` held to `NS.BINDINGS` by
the kit's `Kit.assertBindingsXml`, its own category and no header, no default key and no TOC line,
the plain hidden `AnyDown` button, one press per toggle, the two labels, and the button on a
library-less install; and General → Keybindings, options-ui-§20: the strip's last tab, its rows and
labels, a key bound through it with `Kit.keybindThroughTab`, a key set elsewhere repainting it, the
one key button and Clear with a second key counted on it (`F7 +1`, OptionsKeybinds minor 4), its
combat refusal and the Defaults tooltip; on the kit's `tests/_kit/mock_bindings.lua`, which
`tests/wow_mock.lua` installs), `test_diagnostics`, `test_debug_coverage` (what the debug log and the report carry, debug-logging-§8, §9,
§14: a drop's item level and trade reason, a re-judged drop, the encounter and keystone edges, each
hold and its release over an encounter or combat, the trade scan logged on change only, the search
box once on focus lost, and the report's drop, toast-queue and auto-ask lines), `test_locale` (every literal `L["..."]` / `NS.L["..."]` in an addon file has a raw
entry in `locales/enUS.lua` or `locales/enUS_Settings.lua`, the key-on-miss fallback bypassed, and
every enUS key's text appears in an addon file, a loose reverse since some keys are reached
dynamically; review F07, decision D8. Both read the union of the enUS files, listed from the TOC
and loaded in its order (localization-§6), and it fails on a key written in two of them, on a topic
file's key read outside its folder, and on a topic file misnamed, out of the block after
`enUS.lua`, or keeping its own table). Kit suites,
declared by directory: `test_eol`, `test_prose`, `test_layout_cap`, `test_diagnostics_contract`,
`test_lizard_sighted`.

**Simulator suites on LibKa0s-Sim-1.0.** Since DW-02..DW-04 the simulator's seam, session, two-phase
stop, step machine, verb grammar and step panel are LibKa0s-Sim-1.0's, and their generic behavior
is pinned in the library's own `test_sim_*` suites (LK-12..LK-17: the seam, the session and its stop,
the timeline, the verbs, the panel, isolation, the reference stub and a DropWatcher-shaped mini
host, `test_sim_host`). The seven DropWatcher suites
stay as integration over this addon's host half: `test_sim_core` (the seam's members and guards,
the refusals, the session log, the stop's host steps), `test_sim_e2e` (the H1 scan and `Unwrapped`,
every scenario through the real engine), `test_sim_events` (the event drivers and the world
providers), `test_sim_pool` (the item pool and group), `test_sim_report` (the loot step's report),
`test_sim_scenario` (the scenarios, the timeline's steps, the five verbs through `/dw sim`) and
`test_sim_panel` (the panel's presentation fields). Where a DropWatcher case was deleted because a
library case asserts the same line, the DW-02, DW-03 and DW-04 commit bodies record each mapping,
DropWatcher case to library case.

Write tests first for pure logic. Extend `tests/wow_mock.lua` for a new client API, never
`tests/_kit/`.

`lua tests/run.lua --list` prints the case inventory; it is committed as
[`test-cases.md`](test-cases.md), and its Total is the README's `[tests]` badge. Regenerate both in
the change that moves the count (testing-§5).

## The four suites, and which checkpoint each gates

| Suite | Command | Commit / run | Release (the tag) |
|---|---|---|---|
| `lint` | `luacheck .` | **gates** | gates |
| `tests` | `lua tests/run.lua` | **gates** | gates |
| `perf` | `lua tests/perf.lua` (offline scenarios; see [`performance.md`](performance.md)) | recorded, never fails a run or blocks a commit | gates |
| `complexity` | `bash tests/_kit/run-automated-tests.sh --suite complexity` (the sighted shadow) | recorded, never fails a run or blocks a commit | gates, with zero functions above CCN 15 and `blindFiles` 0, and no crashed run (a crashed or bounded lizard run is a fail, its files listed as crashedFiles) |

The release gate is evaluated by `/dev-copilot:bump-version` from the run's `manifest.json`
(automated-tests-§3). The record itself: [`automated-tests/README.md`](automated-tests/README.md).
For long batteries run through the bounded runner, `~/.claude/dev-copilot/bin/ka0s-bounded`.

## In game

[`smoke-tests.md`](smoke-tests.md) — the checks the headless suite cannot make. They are the owner's
to run; an agent never marks one passed.
