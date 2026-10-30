# Test Cases

The full inventory of every headless test case in this repo, grouped by the suite file it
lives in. The `## Totals` table below counts the cases that run: its **Total** is the
authoritative pass count, and the README test badge and any count quoted in the docs must equal
it. A declared skip is listed by name in its group and counted on the `Skipped` row, never in
Total.

**Generated — do not hand-edit.** Regenerate with `lua tests/run.lua --list > docs/test-cases.md`.

### test_harness.lua (12)

- harness: the addon's file list is the TOC's, Namespace first and Profiles last
- harness: every LibKa0s file comes from LibKa0s.xml, in its order
- harness: every adopted LibKa0s module is the live library, not its stub
- toc: the fixed field order, a single Retail Interface line and the X-Standard field
- toc: the icon is the 128x128 logo, and the file exists
- toc: OptionalDeps names Pawn and CanIMogIt, and no hard Dependencies
- toc: no Conventional comment states the order of handlers on a shared event (toc-file-§5)
- toc: no position labeled Conventional is load-bearing under toc-file-§5 (a) or (b)
- repo: no stored copy of the context pack (documentation-§3, anti-pattern #49)
- repo: the root doc set is README, the CLAUDE stub, DEPENDENCIES and LICENSE
- repo: every authored file opens with the bootstrap and a comment naming its path
- repo: the .pkgmeta has no externals and ignores the dev-only entries

### test_surface_parity.lua (24)

- parity: the degraded load really is library-absent, and the live one is not
- parity: the Core seam's namespace surface survives the library's absence
- parity: the DebugLog stub carries the whole live surface
- parity: the Slash stub carries the whole live surface
- parity: the Slash stub's one library string is the library's, byte for byte
- parity: the Options helpers stub carries the whole live surface
- parity: the Schema host stub's instance carries the whole live instance surface
- parity: the Schema host stub carries the library's own members
- parity: the Launcher stub carries the whole live surface
- parity: the Lifecycle stand-in carries every member of the live latch
- parity: the Sim stub carries the whole live instance surface
- parity: the Sim seam stub carries the live seam surface
- parity: the Bus stand-in carries every member of the live bus
- parity: the Pool stub carries the LibKa0s-Pool-1.0 surface this addon calls
- parity: the Item stub carries the LibKa0s-Item-1.0 surface this addon calls
- parity: the Glow stub carries the whole LibKa0s-Glow-1.0 surface
- parity: the Toast stub carries the whole LibKa0s-Toast-1.0 instance surface
- parity: the Perf stub carries every Perf member the addon reaches
- parity: the Env seam publishes the same NS members on both paths
- parity: the Media seam publishes the same NS members on both paths
- parity: the Compat seam carries every library member it wires
- parity: the Compat seam publishes the same members on both load paths
- parity: the degraded Skin facade answers every name the live facade carries
- parity: each host-copy skin token is the live library's Ka0s Default value

### test_setup.lua (24)

- core: NS.Print is NS.Util.print after AceConsole's embed (architecture-§2)
- core: the printer tags every line with the cyan [DW] prefix
- core: the close-button wrapper passes the addon folder as the third argument
- core: no file but the wrapper calls a close-button factory directly
- core: no file builds a typed × close mark (the close control degrades to nothing)
- core: a raising shared handler costs only itself; the first error is raised after the rest ran
- media: FONT_MONO is the shipped face live, and a real client font degraded
- bus: the catalog holds the ten messages of the design, each Ka0s_DropWatcher_<Event>
- bus: a tracked target's registrations come down with the stand-down and back with the stand-up
- bus: the seam answers tracked once; without the library the modules take their receivers down
- perf: every declared bucket is reached by a real bracket
- perf: evaluate and quality.gate declare themselves within feed.add
- perf: a capture of Receive alone observes evaluate and quality.gate inside feed.add
- perf: a later load and a gear re-judge are observed at top level, so the record reads mixed
- perf: a Receive that raises does not leave later work counted inside feed.add
- perf: with capture off the bracket notes nothing
- perf: the `perf` hold stands the addon down, and the verbs keep answering
- perf: the descriptor's SavedVariables global is declared in the TOC
- launcher: one object, labeled with the brand, the logo as its icon, registered on enable
- launcher: the right-click menu is Enabled, Locked, Test mode, Show window, in that order
- launcher: each menu entry calls the same handler its verb and its row call
- options: the category registers eagerly, with the General page under it
- options: the General page's first group is exactly `Master controls`
- options: the degraded load completes, and the panel says once that it is unavailable

### test_database.lua (13)

- database: the defaults stamp schemaVersion 0, and the runner moves it to the code's target
- database: the runner is idempotent, and a stored stamp at the target runs no step
- database: the steps rise one by one, and the target is the highest step
- database: a step that raises leaves the stamp at the last completed step
- database: step 2 reaches a stored profile that is not the active one
- database: step 2 passes a fresh default profile through unchanged
- database: step 3 folds the View and the three checkboxes into the View set, per profile
- database: step 3 passes a profile already in the new shape through unchanged
- database: the profile defaults carry every Master controls value, and no debug flag
- database: step 4 retires the History's group cap and prunes nothing
- database: step 6 retires feed.showOwn in every stored profile and keeps the rest
- database: step 7 retires window.columns.myEq and theirEq in every stored profile and keeps the rest
- migrate 9: a stored simPanel point is retired, idempotently, and nothing else changes

### test_schema.lua (11)

- schema: every row validates against the defaults
- schema: a stored row whose path has no default is counted, not passed vacuously
- schema: the Minimap button row's backing key resolves against the global defaults
- schema: the Master controls rows are the canonical set, in the canonical order
- schema: an unknown path is refused and stores nothing
- schema: the Minimap button row inverts onto LibDBIcon's own hide, with no shown key
- schema: neither reset touches the minimap button (launcher-§3)
- schema: Reset all asks first, through the confirmation popup
- schema: a write to `scale` reaches the window through the row's reaction
- schema: degraded, `enabled` and `locked` are written through and still react
- schema: degraded, a row-less path not in the list is still refused

### test_schema_rows.lua (23)

- rows: every spec §12.1 setting has a row
- rows: every hand-written row names its page, tab, label and a type the schema knows
- rows: every default is defaults/Profile.lua's, and passes the row's own check
- rows: NS.Setting answers the default before the database, and the stored value after
- rows: a value outside a row's list or range is refused and stores nothing
- rows: the per-spec maps take keyed values whole, and refuse a malformed one
- rows: the feed, the situations and the messaging edge read the rows
- rows: the filter bar seeds a fresh tab from the rows
- rows: the Quality control and the window's layout write through the seam (handoff from M3)
- rows: Keep history for is account-wide, and a profile reset leaves it
- rows: `/dw set` reaches a hand-written row
- rows: degraded, the hand-written rows still read, write and refuse
- glow: both glows have every knob's row on Alerts › Upgrade glow, with the plan's defaults
- glow: the main and off-spec rows alternate, so each line reads main left, off-spec right
- glow: the style subsections read in the Style dropdown's order, Offset first
- glow: an out-of-range knob, an unknown style and a malformed color are refused
- glow: a knob is dimmed while its glow is in another style, the style while the glow is off, the color pair never
- glow: a glow row's write asks NS.Glow to repaint, and `/dw` reads a color and Automatic
- toast scale: a 50-200 % slider by 5 on Alerts › Toast, after Play a sound, live only with the toast on
- icons: Window › Icons is the Zoom row then the composed Border block, with the owner's defaults
- icons: the border rows refuse what they cannot draw, and dim with Show border off
- icons: without LibKa0s the tab keeps its Zoom row and the border reads its defaults
- rows: the layout changes keep every stored path, its type and its default (DW-LY guard)

### test_settings_pages.lua (46)

- pages: General, Drops, Comparison, Messages, Window and Alerts are built, in that order
- pages: each page's strip is its own tabs, one per group, in declaration order
- pages: a page's rows are the rows whose page is its key
- pages: every schema row with a page but the Profiles page's is drawn by one of these pages
- situations: the global Auto-open row, then one table line per situation and no per-situation rows
- situations: five gold, left-aligned column headers, and a stripe on every second line
- situations: the five columns fit beside the panel's scroll gutter, Loot rule included (DW-02)
- situations: each cell paints its stored value, and a toggle writes its path
- situations: an untracked situation's Auto-open, Quality and Loot rule are dimmed, and so is every Auto-open with the master off
- situations: Defaults repaints the table
- situations: a profile switch repaints the table and re-hosts it
- situations: the table is built once, parked before each render, and re-hosted on the new placeholder
- situations: releasing the placeholder outside the renderer parks the table (its OnRelease, options-ui-§19)
- situations: the per-situation rows are still schema rows, skipRender, with no subsection
- situations: the pure rows carry each situation's label, values and live cells
- feed: the Quality tab closes with the threshold in force now, repainted on a write
- feed: the Quality tab pairs the mode with Always show upgrades, then Fixed minimum with Quality floor
- feed: Items draws Minimum item level alone, then Absolute minimum beside Levels under my average
- feed: the fixed minimum is live in the fixed mode only, and the floor in the matching modes only
- feed: the readout names the situation whose own quality setting is in force
- comparison: Weights draws your class's specs as a sub-strip and one slider per stat
- comparison: a weight slider writes the whole map through the seam, for the spec on screen
- comparison: the Pawn import box replaces the spec on screen's weights and says what came in
- comparison: Unwanted types lists the class's weapon types and marks one unwanted per spec
- messages: three editors whose labels count the template's bytes against 255
- messages: typing repaints the counter and the preview live, and stores nothing until Enter
- messages: the preview flags an unknown token and a text past the chat limit
- messages: an empty template is refused by the seam and the box shows the stored one again
- messages: a token chip goes into the template last edited and is stored at once
- messages: Reset templates puts the three back and repaints the boxes
- feed: Retention draws Clear history beside Keep history for; it asks first and clears only on Yes
- feed: with test mode on, Clear history clears the samples and leaves the account's log
- pages: a switch is alone on its line and its knobs pair under it (Toast, Auto-ask)
- pages: Messages opens on Sending, its per-send switches on one line, the transmog switch named apart from its template
- pages: Window's Columns note shows on Columns only; its Trade window mark and Starting view moved in
- pages: a page's Defaults resets that page's rows and no other page's
- pages: the Drops page's Defaults tooltip names the situations it now resets (DRO-L03)
- editors: a weight write is a fresh map; 0 removes the stat and an emptied spec
- editors: a spec's stats are its primary stat, Stamina and the four secondaries
- editors: unwanted types are the class's weapons, then shields where a spec carries one
- editors: an unwanted mark is a fresh map, and the last one cleared drops the spec
- editors: the spec strip keeps the remembered spec, else yours, else the first
- editors: the counter label counts bytes and turns red past the limit
- editors: the preview's drop is the newest that fits its template, an upgrade for you first
- editors: the preview's lines name who it goes to, the length and what is wrong
- asks: TokenContext fills the tokens from a drop for who it goes to

### test_skin_setup.lua (18)

- Skin seam: the owner is the folder name, and NS.Skin is its facade
- Skin seam: the read answers Ka0s Default before the profile store exists
- Skin seam: every owner token is namespaced dw. and taken by the library
- Skin seam: under Ka0s Default each owner token is today's pixel; elsewhere its follow token's
- Skin seam: the palette's Ka0s Default values are the owner tokens' defaults
- Skin seam: C.TONE is filled from its tokens, and refilled in place by a skin switch
- Skin seam: the skin keys default to Ka0s Default, as skip-render rows of General's Skin tab
- Skin seam: the skin row's values are every registered skin, in the library's order
- Skin seam: /dw set refuses a skin that is not registered and applies one that is, once
- Skin seam: /dw set reaches an exception and an override, each its own half
- Skin seam: the write seam writes every half through NS.SchemaRuntime.Set
- Skin seam: the Skin tab sits after Simulator and before Keybindings, labeled Skin
- Skin seam: one tab pick is one effective SetChoice, one repaint, and lands in the profile
- Skin seam: the profile's skin, scope and overrides are applied right after AceDB exists
- Skin seam: a profile switch, copy and reset each apply the incoming profile's skin
- Skin seam: the window edge, dropdowns, search box and mode strips are built for the owner
- Skin seam: the TOC loads the seam after Core and before the widgets, and names EllesmereUI
- Skin seam: without the library the facade answers Ka0s Default, owner tokens included

### test_skin_outline.lua (9)

- outline: a fresh profile stores All text, the library's default
- outline: the schema row offers the library's three modes, in its order, on the Skin tab
- outline: the write seam stores media.outline, and leaves it alone when it is nil
- outline: another addon's copy reaches the store through WriteChoice
- outline: the row's write applies the mode live
- outline: /dw set refuses a mode the library does not know
- outline: the stored mode is applied right after AceDB exists
- outline: a profile switch and a reset apply the incoming profile's mode
- outline: without the skin engine the apply is a quiet no-op and the store still takes it

### test_skin_chrome.lua (11)

- skin chrome: under Ka0s Default the window draws the pixels it drew before skins
- skin chrome: a skin switch repaints every surface in the new skin's colors, with no reload
- skin chrome: the tones a cell is painted in are the new skin's after a switch
- skin chrome: the rows' font size holds across a skin switch
- skin chrome: the verdict glyphs are the skin's monospace face, Ka0s Default's JetBrains Mono
- skin chrome: the shown toast repaints its rows' tones on a skin switch
- skin chrome: a toast on screen repaints once on a skin switch, its tones in the new skin's
- skin chrome: the refusal red and the trade reason's gray are escapes of the skin's tokens
- skin chrome: an item quality is the skin's q.* token, the client's own color under Ka0s Default
- skin chrome: the main window's resize grip takes the skin's icon.grip, live, like the tool windows'
- skin chrome: without the library the window's own colors are Ka0s Default's

### test_skin_literals.lua (3)

- no color literal outside core/SkinSetup.lua and the named allow-list
- every allow-list entry carries its reason
- the gate is falsifiable: a planted literal of each shape is reported

### test_skin_hud.lua (10)

- skin HUD: the icon border's companion is on by default, and Ka0s Default draws today's Solid 2px black
- skin HUD: while the companion is on the stored style and thickness are not read; off, they are
- skin HUD: a skin switch restyles every item button; its None draws no edge; the color stays the player's
- skin HUD: the glow's two colors are the player's under every skin (E6)
- skin HUD: the companion is a composed row with a check, dimmed with Show border off, dimming style and size
- skin HUD: without LibKa0s the stored picks draw and the companion's default changes nothing
- migrate 10: every stored profile's icon border goes back on the skin once, its pick kept
- migrate 10: it runs once; a player's later pick survives the next load
- migrate 10: idempotent on a raw table, the companion set so no sentinel lands; without the library too
- migrate 10: the library sets the companion itself (ResetToSkin's companions, LibKa0s v1.81.0)

### test_skin_picker.lua (17)

- Skin picker: skin.pickerSeen defaults to false, a skip-render row of General's Skin tab
- Skin picker: the spec names this owner, its seams, the Skin tab and the eye
- Skin picker: an unseen profile shows it; a seen one does not
- Skin picker: the login fuse shows it once a session, two seconds after OnEnable
- Skin picker: the stand-down puts the fuse out; the stand-up lights it again
- Skin picker: in combat a start waits for PLAYER_REGEN_ENABLED, once
- Skin picker: a held start is dropped by HideSkinPicker
- Skin picker: never while the addon is switched off or a perf capture holds it down
- Skin picker: a new profile and a reset profile show it again
- Skin picker: the player's close marks it seen; this addon's own hide does not
- Skin picker: a pick previews, unsaved; Apply saves it and marks the picker seen
- Skin picker: the close control puts the stored skin back, saves nothing, and marks it seen
- Skin picker: the gear saves the pick and opens General on its Skin tab
- Skin picker: the eye opens the window in test mode and leaves the picker up
- Skin picker: the stand-down with a preview pending puts the stored skin back, unsaved, unseen
- Skin picker: a profile switch with a preview pending wears the new profile's skin
- Skin picker: degraded, nothing shows and nothing raises

### test_skin_verb.lua (6)

- skin verb: the row sits right after config, with the library's help words
- skin verb: /dw skin shows the library's picker on a profile that has closed it
- skin verb: NS.RunSkinVerb hands O.SkinVerb this addon's first-run spec
- skin verb: in combat every call prints the library's gray line and shows nothing
- skin verb: refused while the addon is disabled, and the picker is never asked
- skin verb: without LibKa0s the verb prints the library-absent line

### test_skin_settings.lua (10)

- skin settings: under a non-default skin the pages' own widgets paint, past the proxy
- skin settings: under Ka0s Default the pages' own widgets paint like every skin's
- skin settings: a release hands a painted widget back stock
- skin settings: the Situations placeholder's undo rides the release chain and still parks the table
- skin settings: the Situations cells follow a skin switch and the Ignore settings panel, live
- skin settings: the Situations headers, labels and stripes stay Ka0s Default with the settings panel ignored
- skin settings: the Profiles page paints the tree AceConfigDialog drew
- skin settings: degraded, PaintAce and PaintAceTree paint nothing and a release still runs
- skin tools: the debug console, perf panel, sim panel, test strip and toast are this owner's
- skin tools: the live debug console is painted for this owner

### test_slash.lua (26)

- slash: NS.COMMANDS is positional triples, every reserved verb present
- slash: `diagnostics` has no alias of any kind (debug-logging-§14)
- slash: both chat commands are registered through AceConsole, and both dispatch
- slash: the bare command opens the settings panel
- slash: lock and unlock write `locked` through the seam
- slash: show, hide and toggle drive the window
- slash: `test` toggles test mode through the shared handler
- slash: `perf` is the addon's verb and prints the harness's lines
- slash: `reset` with no path explains itself rather than resetting everything
- slash: degraded, the host verbs still work and the CLI names the missing library
- slash: every verb of spec §12.3 is in the table, after the reserved ones
- slash: SplitLink takes a whole link, spaces and all, and leaves the rest
- slash: `scan` is the window's Scan group handler
- slash: `add` injects a drop for you, or for a named player, and says what happened
- slash: `add` with no link prints its usage; a refused drop says why
- slash: `add` of an item still loading says it shows once it loads
- slash: `clear` empties this session's feed and leaves the test feed alone
- slash: `clear` closes an Offer panel whose drop it took
- slash: `history` opens the window on that tab, expanded; `mine` opens Drops
- slash: a tab verb the Visibility setting keeps hidden says so
- slash: `compact` toggles the layout through the seam, `full` sets it back, each printing it
- slash: `situation` prints the situation, its settings and the classifier's inputs
- slash: `offer` opens the panel on your newest drop of that item
- slash: `offer` of a bag item the feed never saw adds it as yours first
- slash: `offer` refuses an item not in your bags, and prints its usage without a link
- slash: every feature verb is refused while disabled

### test_window.lua (19)

- window: built lazily, on the first show, and not before
- window: a tooltip shows on a disabled button too, so the gray No action says why
- window: Escape closes it (UISpecialFrames) and it wears the shared close mark
- window: General visibility `never` keeps it hidden even when opened
- window: `inCombat` shows it only in combat, re-read on both combat edges
- window: a drag stores the point, and Reset position forgets it
- window: locked, a drag does not start
- window: resizable from the corner grip, with the design's minimum size
- window: test mode shows the banner (not the TEST MODE text), and its rows replace the empty state
- window: the test banner is LibKa0s-Widgets' TestStrip with DW's text and the info mark
- window: K.BANNER_H - 4 == W.TEST_STRIP.HEIGHT
- compact chrome: the full layout's text has a RIGHT point and no wrap; compact wraps
- window: with no Widgets the window builds, test mode on raises nothing, f.banner is nil, the panes reserve 0 and the title word shows
- window: combat ends test mode, and test mode cannot start in combat
- window: with test mode on, Close and Toggle still change what is shown
- window: turning test mode off closes the window only when test mode opened it
- window: the combat edge decides, even while the player's combat flag lags it
- window: a resize saves the anchor with the size, so a settings repaint does not move it
- window: the least width is the sum of Drops' columns, their gaps, the row lead and the chrome (feedback-5 §4, feedback-6 §1)

### test_window_shell.lua (62)

- shell: the title bar holds the centered gold title, the badge, minimize and close, and no logo
- shell: TEST MODE is bright-red text beside the title, SIMULATION the same in cyan, each shown only in its mode and only where its strip is not
- shell: the default size is 1080 x 600, the least width every column fits (feedback-4 spec §4)
- shell: Escape and every close path close the dropdowns' shared menu too
- shell: the title bar is its own module, and the shell's BadgeText and TextButton are its
- shell: minimized, the title bar wears the plus mark and the `n new` counter; expanded, neither
- shell: BadgeText names the restriction and counts the queued asks
- shell: RestrictionChanged shows the badge, AskStateChanged counts the queue, its tooltip lists it
- shell: Scan group asks the inspect broker through the shared handler, and says what it did
- shell: Scan group is refused while the addon is disabled
- shell: two tabs, Drops active in gold with its underline, History gray
- shell: clicking a tab shows its pane and moves the gold underline; an unknown tab is refused
- shell: the tab labels carry no count; their tooltips say what each holds
- shell: a tab's body is built on its first show, and refreshed with the tab's view
- shell: a tab with no body says what it will hold, never a blank pane
- shell: the filter bar holds View, Quality, Content and the search box, and no checkbox
- shell: the View is multi-select: its values combine, the label counts them, and All clears them
- shell: each tab grays the View values it does not use, and a grayed value does not toggle
- shell: the View tooltip lists every value as a bullet, and grays the ones a tab does not use
- filter bar tooltip: AboveSide is right when the screen has room past the control, else left
- filter bar tooltip: every bar control and the footer's Sort open above the control, top right
- filter bar tooltip: with no room on the right it opens above the control, top left
- filter bar tooltip: the room is measured in screen pixels, at each frame's scale
- filter bar tooltip: the tab strip keeps its own anchor (only the bar moved)
- shell: the search box is Loot History's flat, square box (LibKa0s-Widgets' SearchBox)
- shell: the search box is LibKa0s-Widgets' SearchBox with DW's hint, and a focus loss still writes the filter's debug line
- shell: with no Widgets the filter bar builds without a search box and filters nothing by text
- shell: the dropdowns are LibKa0s's, the widget Loot History's bar uses, spaced as it spaces them
- shell: each tab keeps its own filter state, and grays what it does not use
- shell: a filter change redraws the active tab with the new state
- shell: each tab opens on its own defaults, Drops this session's and yours, History everything (feedback-13 spec §0)
- shell: a fresh tab's state is seeded from the profile's feed settings when valid
- shell: the Quality control shows the mode in force and sets it through the shared handler
- shell: IsInteresting is an upgrade for you, or a drop its looter has no use for and can trade
- shell: Drops lists your own drops; a stored feed.showOwn is ignored
- shell: Matches applies only the controls a tab honors
- shell: Usable by me hides what you can't use or don't want; Upgrade for me keeps your upgrades
- shell: Comparator orders newest, oldest, by item level and by your gain
- shell: the footer composer says inspect freshness, last loot, the situation and Pawn
- shell: the not-tracking situation tooltip points at Settings > Drops > Situations
- shell: the live footer reads the client, and its Sort follows the active tab
- shell: the footer's ticker runs only while the whole window is on screen
- shell: minimize collapses to the title bar, keeps the size, and counts every drop added
- shell: a double-click on the title bar expands a minimized window
- shell: minimized, the corner grip does not resize and the stored size is kept
- shell: a minimized window comes back minimized after a settings repaint
- shell: minimize and expand keep the title bar in place, whatever point it was saved at
- shell: a parent's hide (Alt-Z, a cinematic) is not the player closing the window
- shell: a burst of bus messages repaints once, on the next frame
- shell: a countdown tick on the Drops tab repaints nothing of the window
- shell: every drop added in an auto-open situation opens the window, each time it is closed
- shell: a drop opens a closed window on Drops; an open window keeps the tab it shows
- shell: your own drop opens the window too, whatever showOwn says, and counts as new
- shell: a minimized window the player closed opens minimized, its count rising
- shell: a test placeholder opens the window while test mode is on, and a live drop does not then
- shell: in a dungeon, turning test mode off closes the window its drops opened
- shell: a test drop that reopens a window the player closed in test mode closes with test mode
- shell: no auto-open for a test drop outside test mode, outside an auto-open situation, or with the master off
- shell: every control on the chrome has a tooltip with a reason
- shell: without the Widgets library the window builds with no dead dropdown
- filter bar tooltip: AboveFits is true when the screen has room over the control, else false
- filter bar tooltip: near the top of the screen it opens below the control, never over it

### test_window_compact.lua (25)

- compact: the layout in force is the stored one, compact while a run holds it, full for junk
- compact: a run is a dungeon, raid, key or delve, and nothing else
- compact: each layout's default size and bounds; a stored size is kept within them
- compact: CornerPoint puts compact's top right on the full window's, whatever its anchor
- compact: step 5 maps the retired preset to the compact layout and moves the geometry
- compact: step 5 runs for every stored profile on load
- compact: a fresh profile stores the full layout, and opens in a run compact by default
- compact: the title-bar toggle sits left of minimize, with a catalog mark
- compact: the toggle swaps the layout: compact is 400 x 560 at the full window's top right
- compact: each layout remembers its own size and position
- compact: switching keeps the tab, the minimized state, and builds no second window
- compact: the Layout row lays the window out, and the stored layout is the next build's
- compact: the toggle's tooltip names the layout it switches to and the setting
- compact: an auto-open inside a run opens compact, and the stored layout is untouched
- compact: the run ending lets go when the window is next hidden, so the next open is full
- compact: a run ending while the window is hidden lets go at once
- compact: a parent's hide (Alt-Z) is not the window closing, so the run's layout stays
- compact: with Compact view when it auto-opens in a run off, an auto-open keeps the stored layout
- compact: the player's own toggle during a run lets the override go
- compact: the chest after a key completes still belongs to the run, so its auto-open is compact
- compact: a key's grace running out with the window shown lets go when it is next hidden, and nothing re-arms it
- compact: a key's grace running out with the window hidden lets go at once
- compact: the completion latch clears on leaving, so the next run opens compact again
- compact: a window the player opened is never switched by a drop
- compact: the diagnostics report names the layout, the override and each layout's geometry

### test_compact_cards.lua (27)

- compact cards: Truncate cuts by characters, not bytes, and marks the cut with …
- compact cards: Age is the short duration, then whole days
- compact cards: a verdict reads the glyph and the unsigned difference; a worded one takes ⊘
- compact cards: the worn level comes before the verdict, plain; a word for the state muted
- compact cards: a cross-realm looter takes no mark, the realm in the tooltip
- compact cards: inspect freshness reads its age or state, dimmed, and the tooltip says why
- compact cards: the Drops card reads the spec's four lines
- compact cards: no trade window on the card; the freshness on line 1 with or without a countdown (feedback-10 §2)
- compact cards: the freshness mark is bracketed, and left out where there is nothing to say (feedback-10 §2)
- compact cards: the Drops card's pieces keep the full view's tones and tooltips
- compact cards: every trade state keeps its short word, reason and tone on its own line
- compact cards: the Ask button keeps its states, and a drop you cannot ask for shows a dash
- compact cards: your own drop on Drops reads Name [YOU], No upgrades for Them, and offers it
- compact cards: your own drop's trade tooltip counts its upgrades and Them names them, unless kept
- compact cards: an unread looter's Them says why in the gear's place, and the tooltip too
- compact cards: a different upgrade track is in the verdict's tooltip, not on line 3
- compact cards: a drop whose details have not loaded is never blank
- compact cards: the History card reads the spec's four lines
- compact cards: every History outcome keeps its word and tone
- compact cards: an older kept drop reads its day, and one with no time `?`
- compact cards: a kept drop whose looter was never read, and your own kept drop
- compact cards: the header's short form drops `ago` and `drops`
- compact cards: a filter that hides drops reads `1 of 2`, the hidden ones in the tooltip
- compact cards: a long instance name is cut, the full name in the tooltip
- compact cards: an LFR header fits the default width, each piece cut to its own limit
- compact cards: a group with no time or recorder, and the open world's area header
- compact cards: the History header reads days once a day old, its tooltip the full view's

### test_compact_group.lua (23)

- compact group: a card is four lines at the text size, about 64 pixels at Default, the icon spanning them
- compact group: switching layouts carries the scroll offset over as a fraction of the range
- compact group: the stacked detail card flows its actions into lines and grows by them
- compact group: one pooled card per drop under a one-line header, each line what CompactCards says
- compact group: the pieces are colored by quality, class and tone, the worn levels dimmed
- compact group: every piece keeps its full-view reason tooltip
- compact group: every tooltip opens at the card's top right, just outside the window
- compact group: a card click opens the stacked detail card under it; the cards below move down
- compact group: Ask presses the ask; no card can be dismissed
- compact group: an ask in flight shows the full table's state; no ask offered shows No action and why
- compact group: the text follows the Font size row and the card's height follows the text
- compact group: cards are pooled: a repaint reuses them and builds none
- compact group: a header click collapses its group, and the filters' line and empty state still show
- compact group: test mode fills a card for every sample, no piece blank, and each opens its card
- compact group: each card is indented under its header and draws the row chevron on line 1, before the icon
- compact group: the open card's chevron points up and its detail card indents with it; the header chevron is gold
- compact group: no card shows a trade window; every card keeps its freshness on line 1
- compact group: a second's tick leaves the cards as they are
- compact group: at the least width line 2's pieces end before the action button
- compact group: at the least width Trade fits beside the button, You and Them on line 4
- compact group: at the least width Trade's longest reason ends before the button
- compact group: at the least width line 4's two dual marks fit, each worn item its own mark (H7)
- compact group: dual marks that do not fit the card are the one mark instead (R5)

### test_compact_history.lua (11)

- compact history: kept groups as one-line headers, the newest open, each entry a three-line card
- compact history: at the least width Trade's longest reason ends before the date
- compact history: the outcome is in its tone, and every piece keeps its full-view tooltip
- compact history: a right-click on a card, or on any piece of it, opens the row menu
- compact history: marking an entry declined repaints its card
- compact history: a header click opens a collapsed group
- compact history: every tooltip opens at the card's top right, just outside the window
- compact history: the strip is the kept-history line and the toggle, no Clear history (feedback-15 spec §3)
- compact history: cards are pooled and follow the Font size row
- compact history: test mode's kept samples fill a card each, no piece blank
- history: your own entry's looter reads Name [YOU] in both layouts, the mark in gold (feedback-7 spec §2)

### test_history_card.lua (15)

- history card: the header's chips name slot, type, item level and the outcome in its tone
- history card: For you is the verdict then, with its deltas, marked at the time
- history card: For the group names the looter and the Them verdict with its deltas
- history card: on your own drop the looter is you and the upgrade list is not kept
- history card: the trade box is the recorded estimate in the Drops card's words
- history card: when and where reads the time, the place and the character that saw it
- history card: the actions link, mark or clear declined, and show the drop while it is live
- history card: a row click expands the card under it; the row below moves down; one at a time
- history card: a right-click still opens the row menu and expands nothing
- history card: the columns start after the row's indent and chevron, as on Drops
- history card: the card paints the snapshot, each part with a tooltip
- history card: Link in chat links the item; Mark declined marks it and reads Clear declined
- history card: Show in Drops selects the Drops tab, opens the drop's header and expands its card
- history card: compact cards expand the stacked card under the clicked card
- history card: the stacked card's actions fit one line at the compact width

### test_compact_chrome.lua (23)

- chrome: the tabs' labels are Drops and History in both layouts (feedback-5 spec §3)
- chrome: TEST MODE and SIMULATION shorten to TEST and SIM
- chrome: the compact badge shows the queued count beside its lock, or nothing
- chrome: the footer's one line is inspect freshness and the situation
- chrome: the footer's tooltip carries every full segment
- chrome: the Filters count is Quality, Content and Character off their default, on a tab that honors them
- chrome: the Filters label counts, and its tooltip lists each value, the active ones in yellow
- chrome: compact shows the short title; in test mode the strip marks it, so the title stays centered alone
- chrome: compact and minimized in test mode, TEST shows beside the title and the two center together
- chrome: a simulation reads SIM in compact, in its cyan; expanded, the sim strip marks it with the short wrapped line
- chrome: the panes reserve the sim strip's height while a simulation runs
- chrome: the badge collapses to its lock and the queued count at the left, its tooltip unchanged
- chrome: the title bar has no Scan group in either layout; compact's is the Drops strip's icon
- chrome: the two tabs keep a reduced width, their names in their tooltips
- chrome: the bar is one row: View, the search box (Filter…) and Filters on the right
- chrome: Filters opens the panel of the full bar's own dropdowns, and a pick there filters as it does
- chrome: the panel closes when the window hides, minimizes or goes back to full
- chrome: the full layout takes every control back to its place on the bar and the tab's strip
- chrome: the test-mode strip keeps its tooltip with shorter words that may wrap
- chrome: the compact strip takes a second line exactly when its words wrap at the window's width
- chrome: the compact sim strip takes a second line when its words wrap at 380 px
- chrome: the footer is one line, inspect and situation, the rest in its tooltip, ticker included
- chrome: switching the chrome keeps every tab's filter state and builds no second window

### test_compact_modes.lua (7)

- modes: test mode's samples are the same drops in both layouts, on every tab, under every filter
- modes: a collapsed group, an expanded drop and your own drops shown are the same in both layouts
- modes: a simulated run is the same drops in both layouts, on every tab, under every filter
- modes: switching layouts on every tab changes nothing the engine recorded, judged or sent
- modes: test mode's Drops cards show every state, each saying what its full row says
- modes: test mode's own drops on Drops show Offer as the full rows, no countdown on the card
- modes: test mode's History cards show every outcome, each saying what its full row says

### test_window_group.lua (51)

- cells: Me shows ▲ ≈ ▼ and the signed change, green up, yellow side, red down (feedback-4 §0)
- cells: a verdict with no glyph says a word, and every verdict's tooltip says why
- cells: the Them column takes the Me tones: their upgrade green, their downgrade red, can't use dim red
- cells: Them is a dash on your own drop and `?` with the inspect's reason while unread
- cells: Trade shows Yes, No or ? and a short reason, with board 03's reasons in its tooltip
- cells: Trade's Yes on another player's drop none of your specs can use is dim red, its reason Can't use
- cells: Their eq shows both rings' levels for a ring, one for a helm, and the read's age in the tooltip
- cells: My eq shows what you wear in the drop's slot, both rings for a ring, and empty slot
- cells: Their eq says pending, range, combat or failed beside the icons
- cells: Ask moves Ask -> Queued -> Asked, with Retry on a failure
- cells: no Ask is offered on your own drop, an untradeable one or one that is no use to you
- cells: Item, Ilvl, Slot and Looter are never blank, each with a reason tooltip
- cells: an encounter header reads `Label · Situation · age · n drops`
- cells: a header's tooltip is its facts in rows, gold labels, every member named five a row (feedback-17)
- table: the default columns, and a column the profile turns off
- table: the Item column takes the slack, never less than its minimum
- table: a row too narrow for every column sheds Type, Slot, Looter, Trade window and Ilvl, in that order
- table: groups newest first, the first open and older ones collapsed; a group the View hid whole keeps a header
- cells: KeepsHeader keeps a group the View hid whole; Character leaves one out, recorder or not
- table: built at the least width, every column shows and Ask stays inside the row (feedback-4 §4)
- rows: the pure metrics read Default as the template's size and keep the row height in range
- rows: a stored row height and font size stay as the player set them
- rows: Font size reads `0 (Default)` on the CLI, and its slider reaches 0
- table: the Window page's row height and font size lay out and size the drop rows
- table: a sized text keeps the skin's flags, read again after a repaint (D-07 From skin)
- table: built headless, one header and one row per drop, each column painted
- table: the verdicts wear their tones, the looter their class color, the item its quality
- table: every shown cell has a reason tooltip; nothing is blank
- table: rows come from the pool: a repaint reuses them, fewer drops park the rest
- table: a header click collapses its group, and a second expands it
- table: an item button shows the game's tooltip, shift-click links it and ctrl-click tries it on
- item tooltip: a row's item button opens the game's tooltip at the row's top right, else on its own
- table: Them shows the looter's worn item from their inspect read before their verdict
- table: Me shows your worn item from the gear snapshot, its icon showing your own slot
- table: the Ask button asks through the shared handler, and AskStateChanged repaints it
- table: a drop with no ask offered shows the gray No action button with its reason (feedback-11 §1)
- table: no row can be dismissed: no ×, no handler, no dismissed state (feedback-4 spec §2)
- table: the compact layout draws cards instead of the table, and the full layout the table again
- cells: another player's drop is always the estimate, its tooltip naming the looter; ending soon is no words
- table: Trade window paints every drop's countdown over its bar; the row grows by the bar's room
- table: the countdowns move each second while one runs, repainting the Trade window cells alone
- table: with no countdown running (nothing tradeable, or the column off) no each-second ticker runs
- table: a column the profile turns off is not drawn
- table: the filter bar filters the rows, and the empty line says why nothing shows
- table: with no drop at all the empty state says so, and holds no button
- table: PressAsk says why it asked nobody: your own drop, a gone drop, the addon disabled
- cells: ActionTone is red for your move, yellow while waiting, green once done
- cells: an Offer is cyan while it is your move, its other states as any button's (feedback-6 spec §2)
- table: the Ask button wears its state's tone: red to ask, yellow once asked, green once traded
- cells: Type names the armor type, Jewelry, Trinkets, Cloak or Weapons, else a dash with why
- table: the Type column sits after Slot and is painted on every row

### test_drops_layout.lua (10)

- layout: at the least width no tab sheds a column, and one pixel less would shed on Drops
- layout: the Trade window column is its widest answer plus its bar's padding (feedback-6 spec §0)
- layout: the search box spans from the bar's gap after Character to the bar's right edge
- layout: the column labels are gold on both full tables
- layout: Actions is 84 pixels, the Ask button's width, so every state's icon and word fits
- layout: every action button's icon and word fit its width (feedback-7 spec §1)
- rows: each row draws the header's chevron at its left, muted white, down while closed and up while open
- rows: the Item cell starts after the chevron and a 4px gap; the chevron is no column
- rows: every drop row and its detail card sit ROW_INDENT in from the header; the labels shift over their cells
- headers: a group header's chevron is gold, as its text, collapsed or open

### test_side_cells.lua (26)

- side cells: Me reads the worn level, then the glyph and the unsigned difference in the verdict's tone
- side cells: Can't use and Not wanted stay words after the gear, dim red and gray
- side cells: two worn items read both levels and carry both icons
- side cells: two worn items both read take a mark each, in the items' order and each its own tone (H7)
- side cells: one worn item, an empty or unread slot, a word or an off-spec verdict keep one mark (H7)
- side cells: a drop judged against one of two worn items, or a bag item, keeps one mark (R5)
- side cells: nothing worn reads `empty`, muted, and the verdict follows
- side cells: an unknown verdict's ? goes where the gear part says why, and stays where it does not
- side cells: a dash gear part goes when the verdict says something, and stays alone when it does not
- side cells: the tooltip is the verdict's title, the worn gear as a grid, then the read's age and the verdict's lines
- side cells: two worn items are two rows, each with its own arrow against the drop; a slot worn empty reads empty
- side cells: a dual slot gives each worn item its own arrow and tone against the drop, the band as the kernel's
- side cells: History's verdict alone keeps its own one-row grid from the judged item
- side cells: your own drop's Them is Upgrade for N or No upgrades, in its tones, with every upgrade in the tooltip
- side cells: History's Me and Them are the verdict alone, worded as the Drops table's
- side cells: History's Me grid names you in your class color, as on Drops
- side cells: Them read but not judged names the looter in the grid, in their class color
- side cells: the Offer panel's Their eq reads like Them: both worn items from the read, glyph and difference
- side cells: the Offer panel's Their eq says Can't use, …, Unavailable and empty in words
- side cells: the Offer panel's Their eq lists a ring slot read empty as its own row, as Them does
- widths: Me and Them are each their widest cell, measured (two icons, 321/308, then a word)
- widths: the Offer panel's Their eq is at least Them's width and fits its widest cell
- widths: the column set and the shed order keep Me and Them where the verdict columns sat
- table: the Me cell paints its icons, level, glyph and difference left to right
- table: a dual mark that does not fit its cell at a larger font is the one mark instead (R5)
- table: a word starts after the level, and a cell with nothing worn starts at its left edge

### test_detail_card.lua (30)

- cells: the header's chips name slot, armor, bind, track and rank, primary stat, socket and tertiary
- cells: StatChange lists the secondary stats gained and lost, the largest first
- cells: For you shows what it replaces, the ilvl, track and stat change, and Pawn's score
- cells: For you without a score says why: no scorer, Pawn or your weights not scored yet
- cells: an empty slot and an unread baseline each say so, never blank
- cells: For the looter compares their inspected gear and names their spec and the read's age
- cells: a looter who left the group: the kept read's spec, else `not in your group`, never spec unknown
- cells: on your own drop the looter's side is FOR THE GROUP, no Looter row, Upgrade for N then a row per member
- cells: the trade box says the state, the reason, the rule in force and how fresh the data is
- cells: the trade box reads Can't use in dim red, as the row does, on a drop none of your specs can use
- cells: the actions, ready: Ask Seta, Edit message, Link in chat, Trade; Retry waits on a fresh read
- cells: a disabled action says why: Trade out of range, Retry already queued, Edit once asked
- cells: on your own drop Offer takes the Ask's place; Edit, Retry and Trade are off, each with its reason
- card: a row click expands it inline; the rows below move down by the card's height
- card: one row at a time; a click on a cell or the item button opens it too
- card: the header, both comparisons and the trade box are painted, each with a reason
- cells: the titles name YOU and LOOTER in the muted gold, the looter's name in its class color
- cells: the Stats row colors each value by its sign and each stat's name in its own color
- cells: Replaces reads the item level, then the icon, then the name in its quality color
- card: the glyphs are drawn in the monospace face; Replaces puts its item level before the icon
- cells: on a two-item slot read in full, Item level is each worn item's level and mark; Replaces the one taken off (H7)
- card: a dual Item level paints its second part after the first mark, in the monospace face (H7)
- card: a looter who left the group: the Spec row reads the drop's kept read, not spec unknown
- card: the actions go through their host handlers; Trade is off with its reason
- card: the card has no Hide this item; its row stays
- card: a filtered-out or collapsed row hides its card; it comes back with the row
- card: Edit message opens the box with the ask filled in; Send asks with the edited text
- card: with Edit before sending on, the row's Ask opens the box; its Send asks; a queued ask still cancels
- card: the Edit message box says why when the ask would be refused, and Cancel closes it
- card: RetryInspect and TradeWithLooter say why they did nothing

### test_own_drops.lua (16)

- own drops: Trade reads its word alone and counts the upgrades in its tooltip (feedback-7 spec §2)
- own drops: the keep? rule: an upgrade for you says no count until its Offer panel is opened
- own drops: Them reads Upgrade for N, green, each one ranked by gain
- own drops: No upgrades is muted and says why: nobody's, checking, solo
- own drops: Offer is labeled and toned by the furthest offer sent, No action where it cannot be traded
- own drops: Reveal is session state; the tone states read the offer and announce halves
- own drops table: listed with the others: Trade's word, Upgrade for N in Them, Offer
- own drops table: Offer opens the Offer panel and reveals a kept upgrade's Upgrade for N
- own drops table: Offer turns yellow once offered and green once given away; No action when untradeable
- own drops: the detail card shows Offer in place of Ask and Upgrade for N for Them
- own drops compact: line 1's Offer, line 2's trade word and line 3's Upgrade for N with its tooltip
- own drops: the Looter cell marks your own drop [YOU], never another player's
- own drops: the name is cut before the mark: WindowRows.MarkedWidth
- own drops table: Looter reads Name [YOU], the name in class color and the mark in gold
- own drops: the detail card's FOR THE GROUP names each member it upgrades, in class color, best first
- own drops: the detail card has no Looter row; the compact card's line 2 reads Name [YOU]

### test_tip_marks.lua (27)

- tip marks: the escape is the whole 64x64 canvas at the text's height, tinted as 0..255
- tip marks: up is arrow-up in green, side is transfer in yellow, down is arrow-down in red
- tip marks: with the media library absent a mark falls back to a plain character
- tip marks: a non-wrapping line and its text; names in class and quality colors
- tip marks: a row is `• Label: value`, the bullet and label muted gold, the value plain or in its tone
- tip rows: the table's cells (WindowCells, SideCells) are rows, the Trade cell's reason one row per fact
- tip rows: your own drop's cells and buttons (MineCells) and the off-spec cells are rows
- tip rows: the detail card's chips, sides, trade box and actions (DetailCells) are rows
- tip rows: the compact cards and chrome (CompactCards, CompactChrome) are rows
- tip rows: History's cells and card (WindowHistory, HistoryCard) are rows
- tip rows: the column headers and the Offer panel's columns are rows, the settings keep their prose
- tip rows: the chrome's own tooltips (title bar, footer) are rows
- tooltip: a non-wrapping line is added with wrap off; every other line still wraps
- grid: the arrow cell is the table's glyph and the unsigned difference, both in the verdict's tone
- grid: a member's rows, the name on the first, the arrow on the item it replaces, empty for a slot worn empty
- grid: a column is as wide as its widest cell, a fixed gap between, an empty column takes no room
- tooltip: a grid reserves a line per row and paints its cells as columns, the glyph in the monospace face
- tooltip: a secret width or line count in combat paints the grid on the estimate, never raising (feedback-14 spec §0)
- compat: a tooltip's line by number is its TextLeft global; nil for an unnamed tooltip or a missing line
- details: one grid row per upgrade, ranked by gain, every part colored, the gain unsigned
- details: of two worn rings the line names the lower, the one the drop would replace
- audit: no column tooltip on Drops or History carries a verdict glyph; their marks are textures
- audit: no localized string in the addon's source puts a verdict glyph in a tooltip
- audit: every tooltip of test mode's drops, both layouts, the detail card and History is glyph-free and in rows
- tip marks: the arrow between two values is arrow-right in the muted tone, -> without the library
- tip marks: Chars counts what a text draws: an escape two, a color code none, a UTF-8 character one
- audit: no text in the default face carries a glyph: Drops, the detail card, the Offer panel, History

### test_drops_strip.lua (15)

- drops tab: the tabs are Drops and History, and the retired `mine` opens Drops
- drops strip: under the table, it counts your tradeable drops and the next expiry, Post beside it
- drops strip: one row, right-aligned: [Post my tradeables] [Scan group] [Expand all] [Sort] (feedback-15 spec §2)
- drops strip: Sort follows the active tab to History's strip, right of the toggle, and back
- drops strip: Scan group goes through the shared handler
- drops strip: the row, pure: full Sort, the toggle, Scan group, Post; compact the same without Sort, icon wide
- drops strip: full layout, nothing tradeable: shown with Scan group beside Sort, no summary
- drops strip: a repaint that changes neither the layout nor Post re-anchors nothing; either change places it again
- drops strip: compact, shown while none of your listed drops can be traded: no summary, no Post (feedback-15 spec §2)
- drops strip: it counts the drops the tab lists, its filters applied, collapsed or not
- drops strip: its next expiry moves each second with the countdowns
- drops strip: its next expiry keeps the each-second ticker running with no row's countdown drawn
- drops strip: Post my tradeables goes through the shared handler
- drops strip: under the compact cards, the summary shortened, Post my tradeables its icon
- drops strip: the compact countdown tick moves its next expiry too

### test_footer_row.lua (8)

- footer row: the slots, pure: right to left, a gap between, a hidden control takes no room
- footer row: the toggle's state, pure: Expand all while a shown header is collapsed, none without one
- footer row: full Drops, right to left: Sort, the toggle, Scan group, Post my tradeables, one width
- footer row: compact Drops is always shown: the toggle at the right, Post my tradeables left of it
- footer row: History, full Sort then the toggle, compact the toggle; no Clear history
- footer row: the Drops toggle opens every shown header, then closes them, in both layouts
- footer row: the toggle is off when the tab shows no header
- footer row: the History toggle in both layouts, and each tab keeps its own collapsed state

### test_offer_panel.lua (21)

- offer panel: Offer opens it docked right, the candidates ranked with Their eq in the Them look
- offer panel: no class bar; every second row striped as the main window's; the name in its class color
- offer panel: each member's Offer is cyan, Offered yellow, Retry red; Announce to group unchanged
- offer panel: every part has a reason tooltip; Their eq's holds the old pill's explanation
- offer panel: Offer whispers through the shared handler
- offer panel: Their eq shows both worn items from the member's inspect read
- offer panel: opening an upgrade for you reveals who it would help on its row
- offer panel: the close mark closes it, and it closes itself when its drop is gone
- offer panel: a row's Offer closes the panel it opened, and opens it again
- offer panel: another drop's Offer switches the open panel to that drop
- offer panel: a compact card's Offer and the detail card's Offer toggle it too
- offer panel: /dw offer always opens it, never closes it
- offer panel: minimizing the window closes the panel and the Edit message box
- offer panel: with Edit before sending on, Offer and Announce open the box for their kind
- offer panel: Announce to group announces the drop
- handlers: Post my tradeables announces every tradeable drop of yours, line by line
- handlers: Post my tradeables to a stored PARTY while solo says not announced and sends nothing
- handlers: Offer and Announce say why they did nothing
- offer panel: it keeps its own least height beside the compact window
- offer panel: Offer on a compact card opens it docked beside the compact window, its width unchanged
- offer panel: beside the compact window it goes on the side with room, and floats centered when neither has

### test_mine_cells.lua (14)

- mine cells: Clock reads h:mm:ss
- mine cells: the countdown is exact from the item's timer, estimated from the drop before it
- mine cells: the Trade window says the countdown, ending soon, not tradeable or no limit
- mine cells: the candidates are ranked upgrades first by gain, each with its judgment and why
- mine cells: Offer and Announce follow the ask's lifecycle; the Trade button is gone
- action icons: every state of every action button's look table carries a shipped icon (feedback-7 spec §1)
- action icons: the detail card's actions wear their state's icon, Ask and Offer as on the row
- mine cells: the summary counts the tradeable drops and names the next expiry
- mine cells: Post my tradeables lists every link, cut at the chat limit without splitting one
- mine cells: the Offer panel docks right, else left, else floats
- mine cells: the panel's header reads your change, the item level and the trade window
- mine cells: ToneState is the button's own state, or tradedAway once you traded the drop away
- drops strip: it counts your drops the tab lists, its filters applied, in the feed's order
- drops strip: the compact layout's summary is shortened

### test_row_tooltip.lua (13)

- row tooltip: it rises from the row's top right, just outside the window
- row tooltip: with no room on the right it rises from the row's top left, outside the window
- row tooltip: the room is measured at the UI scale (a scaled-down window, a full-size tooltip)
- row tooltip: unknown geometry places nothing; a marked panel is the frame it goes beside
- row tooltip: a window row's tooltip goes beside the docked Offer panel, not over it
- row tooltip: a docked panel's row never opens over the window; a hidden or floating panel is ignored
- row tooltip: a cell, a button or an icon in a marked row opens at the row's top, not its own
- row tooltip: unknown geometry falls back to the hovered frame's top right
- row tooltip: Drops, every cell, Ask and the header open at the row's top right
- row tooltip: with no room on the right a row tooltip rises from the row's top left, outside the window
- row tooltip: your own drops' rows on Drops and their Offer open at the row's top right
- row tooltip: History rows and headers open at the row's top right
- row tooltip: the column labels and the tabs keep their own anchor (rows only)

### test_test_mode.lua (40)

- test mode data: each sample group names who was in it, you first, as many as its content brings (fb17)
- test mode data: the session drops what such groups see; History holds far more, every content (fb17)
- test mode data: each group is one real place, its loot that place's at the group's difficulty (fb17)
- test mode data: the other members' drops cover every Me and Them verdict (board 03)
- test mode data: every trade estimate, inspect state and ask state is there
- test mode data: your own drops cover every countdown and every candidate status (board 04)
- test mode data: off-spec samples show every off-spec verdict, an empty slot, a bag item and a worn one
- test mode data: an Offer candidate's off-spec upgrade ranks below main-spec upgrades, above a downgrade
- test mode data: History holds an off-spec entry you asked for and one you received
- window: test mode shows an off-spec verdict, cyan with the spec's name, and its detail card's Spec row
- test mode data: a key run and four bosses, every item a pool item that keeps its slot
- test mode data: worn items are other pool items of the slot, nearest the level the change implies
- test mode data: the trade reason's two levels are the drop's and the looter's worn item's
- test mode data: an empty pool gives no sample, and a pool short of a slot borrows a real item
- test mode data: the History sample has your groups, every outcome, and an alt's, oldest first
- feed: AddTest puts a sample in the test feed as given, never in the live one
- feed: AddTest refuses a spec with no item, no looter or no group, and while stood down
- test mode: on fills the test feed from the item pool, off empties it; the live feed is never touched
- test mode: while the pool loads the tab says so and holds no drop; the drops fill in when it is ready
- test mode: turned off while the pool loads, nothing arrives later
- test mode: with no journal and no gear of your own there is no sample, and it says so
- test mode: combat and the stand-down both empty the test feed
- test mode: the Drops tab shows View: All while on, and the player's View comes back
- history: test mode shows its sample groups, every outcome, and never writes the account's history
- history: the account's kept groups come back when test mode ends
- window: test mode draws every sample, under the two key runs and the five bosses, with real icons
- window: every cell of every sample row says something and has a reason
- window: the rows show every ask state, every Them gear state and every trade chip
- window: test mode's Can't use samples read Can't use on Trade, a No stays No, an off-spec keeps Yes
- window: test mode's looter who left keeps their spec on the detail card, and says they are gone
- window: a sample's You is its own worn gear in both layouts, the item its card replaces, never yours (fb18)
- window: a sample's Them shows its own worn item, and its detail card its own inspect
- window: Drops lists your samples with the others, and its strip counts the tradeable ones
- window: the empty state comes back once test mode ends with nothing in the live feed
- labels: your own rows on Drops say Offer, and no cell of theirs ends in an ellipsis
- labels: no button the addon builds is labeled with a trailing ellipsis
- sends: Ask on a sample prints the text and sends nothing; its state is the edge's from then on
- sends: Post my tradeables in test mode prints its lines and sends nothing
- hooks: AskState shows a sample's own state only while the edge holds none
- window: test mode's unique ring reads both rings, and only a tradeable upgrade glows (feedback-22)

### test_compat.lua (72)

- compat: the secret guards are the library's members on a live load
- compat: the guards answer the library's answers under the same fixture, on both load paths
- compat: with canaccessvalue present the degraded CanAccess asks it
- compat: ChatSender prefers C_ChatInfo.SendChatMessage
- compat: ChatSender falls back to the global, then to nil
- compat: IsAddOnLoaded answers a plain boolean, and false without the API
- compat: FormatToPattern captures %s and %d and escapes every magic character
- compat: DecodeDuration reads every enUS unit and their sums
- compat: DecodeDuration refuses anything that is not wholly a duration
- compat: DecodeDuration never touches a secret
- compat: DecodeDuration reads the client's own language (deDE, with a two-form plural)
- compat: DecodeDuration reads a three-form plural and a multi-character delimiter
- compat: DecodeDuration answers nil when the client has no duration globals
- compat: ParseTradeTimeRemaining reads the whole trade line and nothing else
- compat: TradeTimeRemaining reads the TradeTimeRemaining line of a bag item
- compat: with the line type known, a line of that type is read before any other
- compat: the enum member exists but the line carries another type: the text still reads
- compat: without the enum member the reader falls back to the localized text
- compat: the tooltip reader skips a secret line and survives a malformed answer
- compat: InventoryItemLevel prefers the line's number, then its text
- compat: GetItemUpgradeInfo takes the API's table, plain fields only
- compat: GetItemUpgradeInfo falls back to the ItemUpgradeLevel tooltip line
- compat: GetItemUpgradeInfo answers nil with no track, no API and a secret answer
- compat: InChatMessagingLockdown reads the client, a secret as locked, absent as open
- compat: IsRestrictionActive asks the client, falling back to the state
- compat: IsRestrictionStateActive reads the state by the enum's Inactive
- compat: IsRestrictionStateActive takes the event's boolean payload as it is
- compat: RestrictionTypes is the enum, or an empty table
- compat: the account-bind helpers read C_Item and answer false without it
- compat: a secret bind answer reads as not bound
- compat: GetBagItemGUID reads through an ItemLocation, nil for an empty slot or no API
- compat: GetItemInfo copies the cached fields, nil while uncached or without a link
- compat: GetItemInfo answers nil without C_Item.GetItemInfo; the dead global is never read
- compat: a secret item answer is never copied
- compat: ItemEquipLoc reads the instant info with no cache; nil when secret or absent
- compat: GetDetailedItemLevel reads the effective level, nil without the API
- compat: GetItemStats copies every key, unknown ones too, and is empty without an answer
- compat: GetItemSpecs is a set, nil for an empty list or no API
- compat: GetItemUniqueness reads the category and the item's own uniqueness
- compat: PlayerHasTransmog answers the collection, nil when absent or secret
- compat: ItemClassRestriction reads the classes line by type, else by text
- compat: ItemPrimaryStats reads every primary stat line, the inactive ones too
- compat: CanRequestItemLoad needs the load request and a timer
- compat: without Pawn every reader answers nil and nothing raises
- compat: Pawn's own PawnIsReady() is the readiness test, with no global flag
- compat: Pawn loaded but not initialized is not ready
- compat: Pawn ready answers the upgrade list, an empty list, or nil while uncached
- compat: Pawn's scale for a spec is asked by the spec's place in its class, not its specID
- compat: an item's Pawn value is its unenchanted one, the value Pawn's upgrade test compares
- compat: an error inside Pawn reads as not ready, never as this addon's error
- compat: your visible Pawn scale is the one you show, a custom one before a starter
- compat: without PawnIsReady, a global PawnIsInitialized (flag or function) still counts
- compat: InitiateTrade calls through, and reports false when absent
- compat: InTradeRange reads interact distance 2; secret is out of range, no API lets it through
- compat: NormalizedRealm reads the normalized realm, then the plain one stripped
- compat: PlayerSpecID reads the index then its spec id, nil without an answer or the library
- compat: InventoryItemLink reads the worn link, nil when empty, secret or absent
- compat: the bag readers call C_Container, guard a secret answer, and answer empty without it
- compat: the inspect gates answer plain booleans; a secret answer or no API is the safe side
- compat: the inspect calls, the spec, the item id, the inspect window and the hook
- compat: LootHistoryDrop answers a won drop's plain fields, else nil
- compat: ChallengeMapName answers a keystone dungeon's name, else nil
- compat: ItemIcon answers C_Item.GetItemIconByID's texture, else nil
- compat: ClassColor reads C_ClassColor first, then RAID_CLASS_COLORS
- compat: InsertChatLink prefers ChatFrameUtil.InsertLink, then ChatEdit_InsertLink
- compat: DressUpItem calls DressUpItemLink, then DressUpLink
- compat: SpecName reads GetSpecializationInfoByID's name, else nil
- compat: TradeItemLinks reads slots 1-6 of both sides, plain links only
- compat: TradePartnerName names the trade window's partner, with a realm when given
- compat: IsTradeCompleteMessage knows the client's "Trade complete.", by type, else by text
- compat: ContextMenu builds one button per entry through MenuUtil, else answers false
- compat: no other shipped file names a seam-only client API in code

### test_text_parse.lua (10)

- textparse: the module is pure — it names no client global and reads no _G
- textparse: EscapePattern makes every magic character literal
- textparse: FormatToPattern captures %s and %d, positional forms included
- textparse: ExpandPlural spells out two- and three-form grammars, and leaves plain text alone
- textparse: DecodeDuration sums the terms it is given and refuses leftovers
- textparse: TradeTimeRemaining reads only the whole trade line
- textparse: ItemLevel and UpgradeLine read their lines and nothing else
- textparse: StatLine reads a primary stat line's value, grouping marks dropped
- textparse: ClassSet maps the listed names and asks for the map only on a match
- textparse: ScanLines answers the first parse over the wanted type, through the guards it is handed

### test_constants.lua (12)

- constants: without Enum the item ids fall back to the documented literals
- constants: with Enum present the ids are read from it, not from the literals
- constants: the quality defaults are Rare fixed and an Uncommon floor (spec §6.2)
- constants: the upgrade tracks ascend Explorer through Myth (spec §5.2 step 3)
- constants: the inventory slot ids are the client's, 1 through 19 with no slot 18 in use
- constants: every slot plan has a known kind and real slot ids
- constants: the slot plan maps each equip location to the spec §5.2 kind
- constants: universal and armor-typed equip locations partition the armor plans
- constants: every situation key is listed once, in order, with the spec §6.1 defaults
- constants: every difficulty id maps to a situation kind the classifier knows
- constants: the trade rules are the spec §7.2 table, and every situation has a rule
- constants: the bind ids are Enum.ItemBind's, and the trade bind sets name BoE and account binds

### test_class_data.lua (13)

- classdata: thirteen classes with their client classIDs, each with an armor type
- classdata: every spec row is well-formed and its class lists it
- classdata: every spec has its place in its class, 1 to n with none twice
- classdata: the Devourer Demon Hunter spec (1480) is an Intellect leather dual wielder
- classdata: dual wield and Titan's Grip are the right specs
- classdata: dual wield and Titan's Grip by spec, or by class when every spec agrees
- classdata: shields go to Protection, Holy, Elemental and Restoration Shaman only
- classdata: held off hands go to the caster and healer specs
- classdata: a spec of another class is not trusted over the class
- classdata: armor type is exact, and an unknown class or subclass cannot tell
- classdata: weapon proficiencies by class
- classdata: primary stat is the spec's, or the class's when every spec shares one
- classdata: lookups never throw on junk input

### test_evaluate.lua (38)

- evaluate: every equip location in SLOT_PLAN compares against its slot
- evaluate: an equip location with no plan is unknown (not gear)
- evaluate: pair compares against the lower of the two slots
- evaluate: an empty slot is an upgrade with the emptySlot reason
- evaluate: a slot that is not known is unknown, never an upgrade
- evaluate: a one-hander compares against the main hand only, unless the candidate dual wields
- evaluate: a dual wielder holding a two-hander compares a one-hander against the two-hander
- evaluate: a two-hander compares against the average of both hands
- evaluate: Titan's Grip compares a two-hander as a pair over both hands
- evaluate: `either` marks a baseline picked as the lower of two worn items the drop could take (feedback-21 R5)
- evaluate: an off hand against a wielded two-hander compares with the two-hander, never an empty slot
- evaluate: ranged weapons are two-handers for hunters and main hand for wand users
- evaluate: a gun, crossbow or wand in the main hand is a two-hander for off hands and one-handers
- evaluate: a unique-equipped drop compares against the item holding its category
- evaluate: a unique drop whose own slot holds the category replaces that item
- evaluate: compareOwned takes the better of equipped and owned per slot
- evaluate: a known spec is judged by the item's own spec list
- evaluate: a spec list read for another class leaves the candidate to the class tables
- evaluate: the primary stat check takes every primary the item carries
- evaluate: spec unknown falls back to ClassData for armor, jewelry, shields and off hands
- evaluate: a known spec with no item spec list uses the spec's own class data
- evaluate: the primary stat decides when every spec agrees, and is ambiguous otherwise
- evaluate: an unknown class cannot be judged
- evaluate: tier tokens are judged by their class list
- evaluate: a class-restricted item refuses other classes
- evaluate: an undesired subclass is doesntWant, but only when the item is usable
- evaluate: the sidegrade band splits upgrade, sidegrade and downgrade
- evaluate: ItemVerdict judges one item level as step 4 does, and the band is kept only when it is not 0
- evaluate: with a score, the verdict takes the sign only when ilvl and score agree in sign
- evaluate: the scorer is optional, may be pending, and may fail without harm
- evaluate: a two-hander's score baseline is the average of both hands' scores
- evaluate: verdict precedence is cant, then doesntWant, then unknown, then the comparison
- evaluate: the track delta orders tracks by tier, then rank
- evaluate: the output carries every field of spec 5.2 step 5
- evaluate: nil and garbage inputs never throw and answer unknown with a reason
- evaluate: garbage inside the tables never throws
- evaluate: an internal failure is caught and reported as unknown
- evaluate: heirloom protection keeps a slot holding an heirloom from being called an upgrade

### test_offspec.lua (11)

- offspec: a Protection paladin's Intellect axe is an off-spec upgrade for Holy over an empty hand
- offspec: against the best Holy item owned, the off-spec verdict takes the band
- offspec: a refusal on the class skips the pass; so does a drop the main spec can use
- offspec: an unknown spec is skipped
- offspec: the spec list and the dual-wield flag are spec refusals too
- offspec: the best spec wins: verdict, then the larger difference (an empty slot largest), then the lower id
- offspec: doesntWant, cantUse and unknown are never chosen; with none left there is no off-spec
- offspec: item level only: the scorer is never asked, so it never waits on a score
- offspec: junk off-spec gear and junk undesired lists are tolerated and skip the spec
- offspec: Who derives a spec's candidate from ClassData, never from the main spec
- offspec: WornGear keeps each worn item the spec could wear, false where it could not

### test_offspec_cells.lua (23)

- off-spec cells: the offspec tone is its own cyan, apart from Offer's
- off-spec cells: OffSpec.Of answers the off-spec part of a Can't use, else nil
- off-spec cells: the Me verdict is the off-spec one, in the offspec tone, with the spec's name
- off-spec cells: a sidegrade, a downgrade and an empty slot keep their glyphs, all in the offspec tone
- off-spec cells: an unknown spec name falls back to words, and the looter's cell says their
- off-spec cells: a Can't use with no off-spec is unchanged
- off-spec cells: the Me cell's gear half is the off-spec baseline, a bag item with no slot
- off-spec cells: a Can't use with no off-spec keeps the worn gear
- off-spec cells: the looter's Them cell pairs its off-spec verdict with the item it was judged against
- off-spec cells: the detail card's looter side takes its rows from the off-spec result
- off-spec cells: the compact line reads You 291 ▲20 Holy
- off-spec cells: TipMarks' Mark and ArrowCell take a tone override
- off-spec cells: the detail card's FOR YOU takes its chip and rows from the off-spec result
- off-spec cells: the detail card's Can't use with no off-spec is unchanged
- off-spec cells: the History snapshot keeps the off-spec part small
- off-spec cells: an unchanged off-spec part never reports a change
- off-spec cells: the History card takes its chip, Spec row and deltas from the snapshot
- off-spec cells: a History row's tooltip names the level compared with, not an empty slot
- off-spec cells: Upgrades and Interesting count an off-spec upgrade, not a sidegrade
- off-spec cells: Usable by me counts an off-spec upgrade or sidegrade
- off-spec cells: Gain sorts the off-spec difference below a main-spec upgrade of the same size
- off-spec cells: the Me column's tooltip and the Offer panel's legend name the cyan
- table: an off-spec Me cell paints the baseline's icon, its tooltip from the link for a bag item

### test_offspec_ask.lua (15)

- off-spec ask: AskTemplate takes the main spec, then the off-spec, then transmog
- off-spec ask: the template is listed after transmog, with its default text inside the limit
- off-spec ask: its row sits after the transmog template on the Templates tab
- off-spec ask: the editor names it and previews it over an off-spec drop
- off-spec ask: Reset templates speaks of five messages
- off-spec ask: EvalFor answers the off-spec result when it counts, else the eval itself
- off-spec ask: {mygain} reads the off-spec result, and an empty slot its words
- off-spec ask: the Ask button fills askOffSpec, and its tooltip names the spec
- off-spec toast: Qualifies adds a third value, offSpec, and tests the off-spec gain
- off-spec toast: Compose titles it Off-spec upgrade for you (Holy)
- off-spec auto-ask: DueAt takes an optional lag; the off-spec lag is 5 seconds
- off-spec auto-ask: an off-spec upgrade is asked for the lag after the delay, with its own template
- off-spec auto-ask: main spec goes first; an off-spec ask due while a main one waits is re-armed
- off-spec auto-ask: the least gain applies to the off-spec difference
- off-spec auto-ask: whether an ask is off-spec is read again when it comes due (a re-judge moves it)

### test_offspec_offer.lua (11)

- off-spec offer: an off-spec upgrade or sidegrade is its own status, ranked after main-spec equals
- off-spec offer: doesntWant ranks with cantUse, and an off-spec downgrade stays Can't use
- off-spec offer: both off-spec statuses are offerable, read the off-spec gain and baseline
- off-spec offer: an off-spec upgrade into an empty slot sorts last in its tier
- off-spec offer: each off-spec status explains itself
- off-spec offer: Upgrade for N counts main-spec upgrades only
- off-spec offer: an off-spec upgrade for you does not hide the drop
- off-spec offer: the candidate cell is cyan with the spec's name, 311 ▲14 Holy
- off-spec offer: the candidate cell's gear is the item compared with, not the main spec's worn pair
- off-spec offer: the Offer whisper's {gain} reads the candidate's off-spec gain
- off-spec offer: the panel paints Kaelith 311 ▲ 14 Holy in the offspec cyan, with Offer

### test_scoring.lua (16)

- scoring: a Pawn v1 string imports its stats under GetItemStats' keys
- scoring: an import that is empty, not a Pawn string, or has no stat is refused with its reason
- scoring: ImportInto replaces one spec's weights in a fresh map and keeps the others
- scoring: a weights score is the sum of stat times weight
- scoring: a weight on an unknown stat key counts 0 and is logged once per key
- scoring: HasWeights is true once any spec has a weight
- scoring: Resolve picks the adapter for every setting, Pawn presence and weights
- scoring: InUse and Scorer follow the settings and whether Pawn is initialized
- scoring: for you, Pawn values the drop and the baseline on the drop's best visible scale
- scoring: for you, a drop that upgrades no scale is valued on your spec's scale
- scoring: for you, a drop that upgrades no scale is valued on the scale you show in Pawn
- scoring: for a looter, Pawn uses the scale for their class and spec
- scoring: Pawn answers pending while it is not ready or has not read the item
- scoring: the kernel hands the scorer the drop beside each item
- scoring: with weights, a higher item level that scores lower is a sidegrade
- scoring: the feed judges your drop with your weights once they are set

### test_quality_gate.lua (24)

- quality gate: fixed passes at or above the threshold and hides below it
- quality gate: fixed defaults to Rare, and the floor does not apply to it
- quality gate: no mode or an unknown mode is the default fixed mode
- quality gate: dynamicSlot uses the baseline slot's equipped quality
- quality gate: dynamicSlot is floored, Uncommon by default
- quality gate: dynamicSlot with an empty or unread baseline slot uses the floor
- quality gate: dynamicSlot without a baseline slot takes the lower of the plan's slots
- quality gate: gear entries may be item facts carrying a quality
- quality gate: dynamicCharacter uses the most common equipped quality
- quality gate: dynamicCharacter ties go to the lower quality
- quality gate: dynamicCharacter ignores shirt, tabard and empty slots
- quality gate: dynamicCharacter is floored, and with no gear uses the floor
- quality gate: the upgrade override shows a below-threshold upgrade for me, on by default
- quality gate: the override needs an upgrade verdict, nothing less
- quality gate: a drop at the threshold passes on quality, not on the override
- quality gate: the override applies in the dynamic modes too
- quality gate: a situation's quality setting overrides the global mode
- quality gate: absent, global or unknown situation quality falls back to the global mode
- quality gate: the resolved situation mode decides the drop
- quality gate: Threshold answers the threshold and where it came from
- quality gate: the filter bar label for each mode
- quality gate: every quality id has a display name
- quality gate: an unknown drop quality passes, so the feed never hides what it cannot read
- quality gate: nil and garbage inputs never throw

### test_situations.lua (14)

- situations: the classifier truth table
- situations: the truth table reaches every situation key
- situations: garbage inputs classify as solo and never throw
- situations: with nothing stored, every key takes the spec's track and auto-open
- situations: a stored row overrides, and a malformed field falls back to the default
- situations: an unknown key tracks nothing
- situations: each re-evaluation event classifies and announces a change once
- situations: an event that changes nothing sends nothing
- situations: the edge's inputs are what the client says
- situations: a difficulty the client does not know falls back to the instance type
- situations: a client with no C_ChallengeMode still classifies
- situations: Current classifies live before the first event, without a message
- situations: IsTracking, ShouldAutoOpen and QualityOverride read the profile, then the spec
- situations: stood down, the events are gone; the stand-up announces where the player is

### test_trade_rules.lua (24)

- trade rules: a warbound or account-bound drop is no warbound
- trade rules: a bonus roll is no bonusRoll, and warbound wins over it
- trade rules: a BoE or BoU drop is yes boe, in any situation and past the window
- trade rules: the legacy rule is no legacy (follower dungeons and PvP)
- trade rules: the group rule (ilvlRule none) is likely groupLoot without inspect
- trade rules: personal, the looter's evaluation known and not an upgrade, is likely notUpgrade
- trade rules: personal, an upgrade for the looter, is no upgradeForLooter
- trade rules: the item level decides, not the scored verdict (the game's rule is ilvl)
- trade rules: an empty slot on the looter is an upgrade for them
- trade rules: the looter unknown is unknown noInspect, carrying the inspect reason
- trade rules: an estimate has no expiresAt; only the own-item timer sets one
- trade rules: past the rule's window the drop is no expired
- trade rules: at exactly the window the drop has not expired
- trade rules: with no clock or no drop time there is no expiry check
- trade rules: binds and legacy are decided before the window
- trade rules: each situation's default rule is its `trade.rules` default, raid conservatively personal
- trade rules: the override map replaces a situation's rule
- trade rules: an override naming no rule, or equal to the default, is not an override
- trade rules: an unknown or missing situation takes the default personal rule
- trade rules: Rules lists every situation in order with its rule, default and override flag
- trade rules: Reset clears the override map in place, restoring the defaults
- trade rules: IsRule knows the three rule names and nothing else
- trade rules: nil and garbage inputs never throw
- trade rules: bad facts are unknown badFacts

### test_messaging.lua (26)

- messaging: the default templates are the spec §9.1 text, one per kind
- messaging: Template takes the owner's text, and the default for an empty or absent one
- messaging: Expand fills every token, and formats the gains as numbers
- messaging: unknown tokens are left as they are, and reported once each in order
- messaging: a known token with no value reads as ?, and is reported as missing
- messaging: a + before a worded gain is dropped; before a number or a missing one it stays
- messaging: a value with pattern characters is inserted literally
- messaging: Preview gives the text, its length and the too-long flag
- messaging: a request that can send answers send, with the expanded text, state ready
- messaging: the owner's template and an edited text override the default
- messaging: the one-ask guard refuses a repeat once sent, alreadyAsked
- messaging: with oneAsk off a sent ask can be repeated; an ask in flight never can
- messaging: a message over 255 characters is refused tooLong, with its length
- messaging: the guard runs before the length check
- messaging: a malformed request is refused badRequest
- messaging: under restriction a request is queued, state queued
- messaging: a failed send is failed with its reason, and a retry is allowed
- messaging: MarkSent and MarkFailed act only on an ask that is ready
- messaging: the flush hands back queued asks first in, first out, each ready to send
- messaging: the flush triggers are a lift to can-send, ENCOUNTER_END and CHALLENGE_MODE_COMPLETED
- messaging: cancel drops a queued ask, which the flush then skips
- messaging: a canceled ask can be asked again
- messaging: a looter leaving drops every ask queued to them, and only theirs
- messaging: Counts reports the registry for diagnostics
- messaging: garbage never throws
- messaging: FurthestState is the furthest state any ask of a kind reached for one drop (feedback-4 §1)

### test_restrictions.lua (15)

- restrictions: nothing restricted, everything allowed and nothing announced
- restrictions: an encounter stops chat and is the reason; its lift is announced
- restrictions: a lift the client does not confirm yet keeps the restriction
- restrictions: the event's boolean payload is read too
- restrictions: each type gives its reason; Map blocks nothing
- restrictions: the reason is the highest in priority
- restrictions: a type the client adds later is reported by name and blocks nothing
- restrictions: the chat lockdown stops chat, a secret answer too
- restrictions: the combat edges stop inspect and trade, ahead of the client's flag
- restrictions: before any edge, the client's combat flag decides
- restrictions: combat under an encounter announces the change of what is allowed
- restrictions: a secret payload never raises; a secret state reads as active
- restrictions: a client without the restriction APIs restricts nothing but combat
- restrictions: Refresh announces a lift no event reported
- restrictions: stood down, nothing is heard; the stand-up announces what is in effect

### test_roster.lua (13)

- roster: solo, the player alone, read lazily
- roster: a party, in unit order, keyed by GUID, with realm, class and online
- roster: a raid reads raid1..N, the player among them
- roster: Resolve by GUID, by Name-Realm and by a bare same-realm name, without case
- roster: a bare name two members share is settled by classFile, else unresolved
- roster: a bare name prefers the member on the player's own realm
- roster: GROUP_ROSTER_UPDATE re-reads the group; the specID survives
- roster: the event fans out to the situation edge and the roster both
- roster: a miss re-reads the client once, so a name still Unknown at the event resolves
- roster: secret answers never raise; a secret GUID drops the unit, a secret name hides it
- roster: garbage queries answer nil
- roster: NormalizeRealm drops spaces and hyphens
- roster: stood down, the roster is dropped and the event is down; the stand-up re-reads

### test_item_facts.lua (21)

- item facts: a cached ring reads every field of spec §5.1
- item facts: a chest reads its appearance, account binds and no specs or track
- item facts: the stats carry every primary stat on the tooltip, not the playing spec's alone
- item facts: the spec list says which class the client read it for
- item facts: a three-stat cloak read on a hunter suits a Blood death knight and a Retribution paladin
- item facts: the track tier, by string id first, then by enUS name, else unset
- item facts: the track falls back to the tooltip's upgrade line
- item facts: an item unique on its own takes its item id as the category
- item facts: a token naming classes is a tier token; class gear carries classes only
- item facts: the quality falls back to the link's color
- item facts: the facts feed the verdict kernel
- item facts: Get caches by link until invalidated
- item facts: at its cap the cache drops its least recently used quarter, never the whole
- item facts: garbage links answer nil and never raise
- item facts: learning an appearance re-reads the flag on the cached facts
- item facts: Request answers a cached item at once and never calls back
- item facts: an uncached item loads, and every waiter is called back once
- item facts: the callback retries until the item arrives
- item facts: an item that never arrives is given up after MAX_LOAD_TRIES, with nil
- item facts: a client that cannot load items answers unavailable
- item facts: stood down, the cache and the loads are dropped and a late answer is ignored

### test_item_read.lua (24)

- BUG-1 repro: chat first, the drop reads 311 Epic
- BUG-1 repro: the encounter's bare link first, then chat's complete one: the complete link wins
- BUG-1 repro: a complete link first is never replaced by a later bare one
- BUG-1 repro: a merge while the first link is still loading judges the complete link
- BUG-1 hypothesis 2: ItemFacts reads a complete link right and a bare one at the base
- BUG-1 hypothesis 3: an own drop recorded from a bare link reads level and quality from its bag item
- BUG-1: the history entry takes the complete link, 311 and Epic when chat merges in
- BUG-1: the history entry takes the bag item's link, level and quality
- BUG-1: the history's Refresh never trades a complete link for a bare one
- BUG-1: a drop the bare link's base quality hid comes back when the complete link merges in
- ItemRead: LinkDetail reads the bonus ids, the modifiers, the context and how complete a link is
- ItemRead: BetterLink keeps the more complete link, the first on a tie, and never a non-item
- ItemRead: the identity is the item and its bonus ids; unique id, level, spec and modifiers do not count
- ItemRead: EffectiveItemLevel answers gear's detailed level, else its base, and nothing for non-gear
- ItemRead: a bag location answers the exact level and quality; an empty slot answers nothing
- ItemRead: QualityOf answers the client's quality for the link, else the link's color
- ItemFacts: the level and quality say where they came from
- FeedRecords: a merge keeps the more complete link, chat's on a tie
- trade timer: two own copies of one item id each match the bag item of their own identity
- diagnostics: one drops line per drop names its sources, link, level and quality with their sources, and the bag match
- BUG-2: your own drop matched to its bag item shows the bag item; moved away, its link
- BUG-2: an item you wear shows your inventory slot; someone else's item its link
- BUG-2: a row's item button and its name show the real tooltip, the addon's line after the game's
- BUG-2: the detail card's Replaces row keeps your worn slot for the real tooltip, never the looter's

### test_gear.lua (27)

- gear: each worn slot is a copy of its facts at the current level; an empty slot is false
- gear: the candidate carries the class, the spec and the hand flags from ClassData
- gear: a spec the class flags disagree on leaves the hand flag unknown
- gear: the qualities are per worn slot, false for an empty one
- gear: a better bag item you can wear is owned for its slot; one you cannot is not
- gear: a worn item better than any bag item is its own slot's owned best
- gear: a pair gets your best two rings, one ring never fills both
- gear: a dual wielder's one-handers fill both hands, each once
- gear: a one-hander fills the main hand only for a spec that does not dual wield
- gear: with Titan's Grip a two-hander can fill the off hand too
- gear: a bag item with no slot plan (a reagent, a potion) is never asked of the item facts
- gear: a tier token and a secret bag link are not owned gear
- gear: the candidate judges a drop against the worn item, and against the bags with compareOwned
- gear: the pool keeps every gear item read, the off-spec ones too
- gear: OffSpecGear is the best item per slot that spec could wear, false where nothing fits
- gear: a worn slot still loading leaves no off-spec gear until it loads
- gear: a bag item still loading leaves no off-spec gear, so no slot reads as empty
- gear: the candidate brings its off-spec gear, and the kernel judges Holy against the bag mace
- gear: a bag change that touches only an off-spec item still sends GearChanged
- gear: sorting your bags moves no gear, so it sends no GearChanged
- gear: the gear events share one throttled rebuild, which announces a change once
- gear: a bag event in combat arms nothing; the combat's end rebuilds once
- gear: a bag-only rebuild keeps the worn slots as read; an equipment change reads them again
- gear: the player's spec change rebuilds; another unit's does not
- gear: the first lazy read announces nothing
- gear: an item still loading leaves its slot unknown, and its arrival rebuilds
- gear: the stand-down cancels the rebuild and drops the snapshot; the stand-up rebuilds

### test_loot_parser.lua (28)

- loot parser: loot (self) x1
- loot parser: loot (self) x3
- loot parser: bonus (self) x1
- loot parser: bonus (self) x2
- loot parser: pushed (self) x1
- loot parser: pushed (self) x5
- loot parser: loot (other) x1
- loot parser: loot (other) x4
- loot parser: bonus (other) x1
- loot parser: bonus (other) x2
- loot parser: pushed (other) x1
- loot parser: pushed (other) x12
- loot parser: a cross-realm looter resolves to the member
- loot parser: a player hyperlink or color around the name is stripped
- loot parser: a looter the roster cannot place keeps the name and the event's GUID
- loot parser: the roster's member wins over the event's GUID
- loot parser: the upgrade echo and the crafting echoes are rejected
- loot parser: a line that is not a receipt, a non-item link and an empty line are ignored
- loot parser: secret text is dropped before any pattern touches it
- loot parser: a secret event GUID is not used
- loot parser: a secret, empty or absent GlobalString is left out of the set
- loot parser: a GlobalString rewritten at runtime (PrettyChat) is rebuilt on the next line
- loot parser: a pushed or created string identical to a loot string reads as loot (PrettyChat)
- loot parser: a deDE client reads its own lines
- loot parser: positional arguments are read in the locale's order
- loot parser: CHAT_MSG_LOOT hands each receipt to every sink and counts the lines
- loot parser: the event's twelfth argument is the GUID it uses
- loot parser: stood down, CHAT_MSG_LOOT reaches nothing; the counters survive

### test_inspect.lua (33)

- inspect: a request sends one NotifyInspect, and the ready read stores gear and spec
- inspect: a slot's level comes from its tooltip, else from the link
- inspect: one in flight at a time, spaced SPACING seconds apart
- inspect: looters first, then offer candidates, then warm-up; a later ask can raise a job
- inspect: no INSPECT_READY in 2.5s retries once, then the job fails with a timeout
- inspect: out of range waits without using an attempt, then sends once in range
- inspect: 25s out of range ends the job as outOfRange; CanInspect false waits the same way
- inspect: a GUID with no unit fails after 10s; an offline member waits the same way
- inspect: an incomplete link is read again, 0.3s apart, and completes when it arrives
- inspect: still incomplete after three retries, the read is kept and says so
- inspect: every link already readable completes at once, cached, with no inspect
- inspect: a foreign inspect re-queues the job in flight, free, and resets the spacing
- inspect: a foreign inspect after the data arrived lets the read finish, and clears nothing
- inspect: anyone's INSPECT_READY for a group member is read, completing its queued job
- inspect: the fast path needs neck, rings and trinkets; visible slots alone send the inspect
- inspect: an INSPECT_READY whose data is gone by the read is never stored as fresh
- inspect: the data arriving within the retries is read; a moved unit token is no data
- inspect: an empty read nobody asked for is dropped, and the entry kept as it was
- inspect: combat parks the queue, the job in flight still finishes, and its end resumes
- inspect: the queue waits while the inspect window is open
- inspect: with the old data still held, a request completes on the fast path
- inspect: a read is good for 600s; after that a request inspects again
- inspect: UNIT_INVENTORY_CHANGED marks a group member stale and re-queues it
- inspect: the roster event drops the entries of members who left
- inspect: 2s after a roster update in a tracked situation, the idle queue warms up
- inspect: entering an instance warms up too; untracked or busy, nothing is queued
- inspect: Scan queues every other member that has no good read
- inspect: the candidate carries the roster's class, the read spec and the hand flags
- inspect: the candidate's off-spec gear is the worn gear each other spec could wear
- inspect: InspectDone waits for the read's items to load
- inspect: one debug line per job
- inspect: secret GUIDs, units and specs are never used
- inspect: the stand-down clears this broker's inspect, every timer and the state

### test_feed.lua (50)

- feed: a member's loot is added once, judged for you, and asks for the looter's inspect
- feed: the looter's inspect re-judges the drop: their verdict and the trade estimate
- feed: a looter who leaves the group keeps the read the drop was judged with: spec and worn gear
- feed: a re-judge after the looter left keeps the read and the verdict the drop was judged with
- feed: a looter who leaves before any read reads not in your group
- feed: an upgrade for the looter cannot be traded under the personal rule
- feed: a bonus roll is never tradeable
- dedupe: chat, the encounter loot event and the loot history report one drop
- dedupe: the encounter event first, chat second, merges the same way
- dedupe: a looter the roster cannot place is matched by name without the realm
- dedupe: a GUID learned from a second source asks for the looter's inspect
- dedupe: two copies from one source are two drops; another looter's copy is its own
- dedupe: a report after the window is a new drop
- history: a drop is taken once it has a winner, and only once
- history: your own won drop is yours
- groups: trash, a boss kill's loot window, then trash again
- groups: a wipe opens no loot window
- groups: clear on boss kill empties the live feed at a kill, not at a wipe
- groups: loot naming an earlier encounter joins that encounter's group
- groups: a keystone run gathers every drop, the chest after completion included
- groups: a bonus roll minutes after the key, still in the dungeon, joins the run; once you leave it does not
- groups: outside an instance the area is the open world
- gates: an untracked situation hides the drop before its item is even loaded
- gates: below the quality threshold a downgrade for you is hidden, and costs no inspect
- gates: the upgrade override shows an upgrade for you below the threshold
- gates: the stored quality settings and the situation's override are read
- comparison: heirloom protection (on by default) calls your upgrade over an heirloom a sidegrade
- comparison: heirloom protection is yours alone; the looter's verdict is plain
- gates: the filters run after the situation and before the verdict
- filter: every rule of spec §6.3 (pure)
- gates: the relative minimum item level reads your average equipped level
- load: an uncached item waits for its facts; a second source merges meanwhile
- load: an item that never loads is shown, judged unknown
- own: your drop is judged for you, its trade by your verdict, and every member a candidate
- own: an upgrade for you cannot trade, so no candidate is inspected for it
- own: an item pushed to you (a quest reward, a purchase) is not a drop
- update: GearChanged re-judges you on every drop
- update: a pending score is retried on one shared timer, five times at most
- trade: a group drop past its rule's window turns no expired on the sweep
- trade: your own drop takes the timer's exact read: yes with expiresAt, then no expired
- trade: your own fresh drop with no trade-time line is your upgrade, not a window passed
- trade: your own drop the rule had as tradeable but with no trade-time line says the game gave no window
- trade: your own drop the rule called no, with a live timer, asks for its candidates then
- trade: a BoE own drop keeps the bind's answer; the timer folds nothing in
- add: injects a drop past the situation gate; a stranger is judged without an inspect
- add: the test feed skips every gate and every inspect, and stays apart
- cap: the oldest drop goes first, and an emptied group with it
- removal: the sinks hear every clear and every trim, with the feed's name (DW-62)
- secrets: a secret link, name or encounter id is never used
- stand-down: timers and pending loads are dropped, the drops kept

### test_feed_counts.lua (10)

- two yokes: both Yokes are separate drops with the right looters, the accented name resolved
- two yokes: the reagent and the altar are hidden by the gear-only rule and counted, not lost
- two yokes: with gear-only off, the common reagent is hidden by the quality rule
- two yokes: each hidden drop is logged with its reason under the FEED tag
- refused: every receipt the feed turns away is counted by reason and logged under FEED
- refused: a C_LootHistory drop already taken is counted as seen
- diagnostics: the drops section reports the hidden and the refused counts by reason
- header: View Interesting hides Bùnian's Yoke and the header reads `2 drops · 1 shown`
- header: your own drop is listed in Drops with the others, never counted as hidden
- header: History names its hidden drops too, and a long list is cut with a count

### test_group_roster.lua (13)

- roster entry: the short name, the realm only when it is not yours, the class, you marked
- roster merge: the snapshot only grows, you first, the same character never twice
- roster merge and copy: the entries are copied, never shared
- roster names: the first few, class-colored, then +n; none for no roster
- roster tooltip: Group (n) rows, five names a row, the realm when it is not yours, class-colored (fb17)
- feed roster: the group takes everyone in it when its first drop makes it, you first
- feed roster: someone who joins mid-run is added on the roster event, and to the History group
- feed roster: a joiner is also taken by the next drop, with no roster event between
- feed roster: a roster event with no group open yet changes nothing and raises nothing
- history roster: Record copies the group's roster in and merges it with each entry
- group header: you alone after the count, class-colored; the tooltip's Group rows name the party
- group header: a raid's party is not in the header; its tooltip rows name all twenty
- history header: the recorder alone; an older group with no place and no roster keeps its label

### test_group_place.lua (15)

- group place: a keystone's difficulty reads Mythic+ and its level; any other is the client's name
- group place: an encounter names its instance, its boss, then its difficulty
- group place: a key run's and an area's label is the instance, named once
- group place: with no difficulty name the situation word stands in; an older group keeps its label
- group place: Looking For Raid reads LFR, a stored name too, and Parts names each part's role
- group place: Who names the recorder alone, its short name class-colored; History falls back to an entry
- compat: DifficultyName answers the client's name, nil for an unknown id or no API
- compat: KeystoneLevel answers the active key, else the completed run's, else nil
- feed: the owner's Timewalking drop names the instance, the boss, Timewalking and you (07)
- feed: GetInstanceInfo's own difficulty name wins over GetDifficultyInfo's; an empty one falls back
- feed: a group keeps the place it opened in
- feed: a key run's end chest reads Mythic+ and the completed run's level
- feed: in the open world no place is read and the situation word stands in
- test mode: the sample groups carry real instance names and realistic difficulties
- sim: a dungeon boss and a key run name the pool's instance and the client's difficulty

### test_char_filter.lua (19)

- char filter: a recorder key is Name-Realm; a name that carries its realm is kept
- char filter: the class icon is the classicon atlas as inline markup, nothing with no class
- char filter: All passes everything; a recorder passes when chosen; none passes only All
- char filter: Canonical swaps the sentinel for your key once it is known, in a fresh set
- char filter: the label reads All, Current, the one character, or n selected
- char filter: the characters are every recorder in the log once, you always, sorted by name
- char filter: the menu is All, Current, then each character with its class icon and color
- recorder: you are Name-Realm and your class, read live and kept
- recorder: unknown while the client has no realm yet, then known
- recorder: every drop record and its History entry say who saw it
- recorder: a test placeholder is stamped too, and a stamp already there is kept
- filter bar: the Character dropdown sits after Content, multi-select, Current by default
- filter bar: Drops lists All, Current and you alone; History every recorder
- filter bar: History shows your drops under Current, every recorder chosen, and unknown only under All
- filter bar: a group Character and Content leave empty shows no header, full or compact (feedback-12 spec §1)
- filter bar: a drop the Character filter hides is named in the header's reason
- filter bar: a Character selection is a set of keys; anything else is refused
- filter bar: Drops keeps every drop under any Character choice it offers
- filter bar: each sync reuses the Character and View rows; HistoryChanged rebuilds History's

### test_trade_timer.lua (16)

- read: your drop's TradeTimeRemaining line gives its exact expiry, keyed by item GUID
- read: the sentence on a line of another type is still the timer (the text fallback)
- decoder: without the line type, the localized sentence is decoded with the client's globals
- read: no timer line (bound, or the window gone) means no: expired, never live
- read: a BoE drop has no timer line and no window: permanent, never expired, never live
- match: by exact link first, then by item id; each drop takes one item
- match: an item that is none of your drops, and another member's drop, are not timed
- match: test drops are never timed
- match: an item that left the bags drops its entry; a moved one keeps it
- scan: BAG_UPDATE_DELAYED, LOOT_CLOSED and your DropAdded ask for it; once per 2 seconds
- ticker: slow while the window is hidden, fast while it is shown, off when nothing is live
- ticker: a second live item shares the one ticker
- warn: once per item at the threshold, with TradeTimerExpiring and one chat line
- warn: an item first read below the threshold warns at once; warnAt 0 turns it off
- secrets: a secret bag link, GUID or tooltip text is never used
- stand-down: the ticker and the scan stop, the entries are kept; the stand-up scans again

### test_trade_helper.lua (6)

- guards: combat refuses before the range is read
- guards: a stranger, yourself, an offline member and one out of range are refused
- guards: stood down, nothing is traded
- guards: every reason has its tooltip line, and none has none
- open: InitiateTrade with the member's unit; noApi without it
- diagnostics: the trade section reports the helper's counts once it has been used

### test_asks.lua (26)

- send: an ask whispers the looter's Name-Realm with the expanded template, and confirms in chat
- send: every token comes from the drop: item, ilvl, slot, track and both gains
- send: into an empty slot the gain reads as words, never the item level or a ? (DW-62)
- send: the one-ask guard refuses a repeat; with messages.oneAsk off a sent ask goes again
- send: an edited text over 255 bytes is refused tooLong and nothing is sent
- send: a stranger, yourself, an offline member and a missing target are refused
- preview: the template filled in for the drop, with its length; nothing sent or filed
- send: an offer whispers the candidate, named in {player}
- fail: a raising sender fails with its message, prints nothing, and may be retried
- fail: a secret or empty error reads as error; no sender at all is noApi
- fail: the deprecated global sender is the fallback
- announce: auto picks INSTANCE_CHAT, then RAID, then PARTY, and never SAY or YELL
- announce: outside a group it fails noChannel
- announce: a stored PARTY while solo fails noChannel, confirms nothing, and may be retried
- announce: a stored RAID or INSTANCE_CHAT without that kind of group fails noChannel
- queue: under a restriction the ask is queued, and the lift sends it at once
- flush: one send every 1.5 seconds, first in first out
- flush: a restriction back mid-flush stops it; the rest wait for the next trigger
- flush: ENCOUNTER_END and CHALLENGE_MODE_COMPLETED re-read a lockdown that lifted silently
- flush: a trigger with nothing queued, or while chat is still restricted, sends nothing
- cancel: pressing a queued ask cancels it; the lift sends nothing and the button is ready
- cancel: an ask queued to a looter who leaves is dropped; others stay
- cancel: a queued announce is dropped once you leave the group
- cancel: a queued announce to a stored channel is dropped once that kind of group is gone
- test mode: nothing is sent; the text is printed and the ask is marked sent, even restricted
- stand-down: a request is refused, the flush timer is canceled and the queue is dropped

### test_transmog.lua (13)

- transmog compat: CanIMogIt answers first when it is loaded, else the client's collection
- transmog compat: CanIMogIt's no-appearance answer is nil; a raise or a non-boolean falls back
- transmog facts: the item facts read the look through CanIMogIt when it is loaded
- transmog template: the plain ask for a gain; For transmog only when on and the look is missing
- transmog template: its default text, the owner's own, and a request that names it
- transmog card: the header's look chip says New look, Look known or nothing
- transmog ask: offered for a missing look only with transmogAsk on, with its own tooltip
- transmog edge: with transmogAsk on, an ask for a missing look sends the For transmog text
- transmog edge: a collected look keeps the plain ask
- transmog settings: the template and the opt-in are rows, the opt-in off by default
- transmog settings: the preview sample is a drop whose look you have not collected
- transmog test mode: one sample's look is collected and one's is not
- transmog diagnostics: the integrations name the look's source, messaging the opt-in

### test_history.lua (30)

- history: Normalize gives the shape in place and keeps the retention row
- history: Snapshot keeps the drop small: link, looter, verdicts, trade, `seen`
- history: Record groups by key, newest last; no group cap, 50 drops a group
- history: the safety ceiling drops the oldest drops first, and an emptied group goes
- history: an automatic outcome only moves forward
- history: Refresh takes the latest verdicts, and an expired trade makes it `expired`
- history: Refresh's second answer says whether anything it stores changed
- history: declined is set by hand, and clearing it puts back what it replaced
- history: a completed trade matches the partner's drop first, then any, one entry per item
- history: an item you gave marks your own drop traded away, never someone else's
- history edge: DropAdded records a live drop in DB.global, never a test drop, and keeps the retention row
- history edge: DropUpdated refreshes the entry; an expired trade makes it `expired`
- history edge: a DropUpdated that changes nothing kept sends no HistoryChanged
- history edge: a sent ask is `asked`, a sent offer or announce `offered`; other states nothing
- history trade: a completed trade marks the drop you got `received`, and the Ask button `Traded`
- history trade: "Trade complete." before the close completes it too
- history trade: a close after both accepted with no "Trade complete." completes nothing
- history trade: an item you gave marks your drop `tradedAway`
- history trade: a canceled trade completes nothing; the offer is the last one accepted
- history: Clear history asks first, and empties the log only on Yes; the retention row stays
- history: the diagnostics' feed section reports the history and the trade
- history tab: kept groups newest first, the first open, each row's outcome painted
- history tab: rows take the Window page's row height and font size
- history tab: a header click opens a collapsed group; the filter's Content cuts earlier sessions
- history tab: a right-click marks a row declined, through the menu when the client has one
- history tab: with nothing kept it says what it will hold, and the strip has no Clear history
- history tab: HistoryChanged repaints the shown window on the next frame
- history tab: a DropUpdated that changes the history still repaints the window once
- history tab: the pure Ago reads seconds, hours, then days
- history tab: rows draw the Drops rows' chevron and indent; the headers' chevrons are gold

### test_history_retention.lua (16)

- retention: the labels, the choices and the footer
- retention: a group's age is its newest entry's, else its own
- retention: Count says what a window deletes, and deletes nothing; Prune deletes it
- retention row: account-wide, on Drops › Retention, the listed windows only
- retention: a longer window, or one that deletes nothing, is taken at once
- retention: a shorter window that deletes asks first; Yes prunes
- retention: No writes the last agreed window back and deletes nothing
- retention: an unanswered popup (a /reload with it open) leaves nothing to prune at the next login
- retention: a later change that deletes nothing retires the open popup; its Yes does nothing
- retention: of two deleting changes, only the latest popup's answer counts
- retention: headless (no popup), a shorter window prunes at once
- retention: the login prune runs once, deferred off the login, over the account's log
- retention: the stand-down takes the pending prune back; the stand-up arms it again
- retention: enabled later in a session that started disabled, the prune still runs once
- retention: Never delete keeps every group at login
- retention: in test mode a shorter window prunes test mode's older sample, not the account's

### test_feed_restore.lua (14)

- session: an initial login starts it now; a zone change moves nothing; a reload keeps it
- session: with no stored value (a first run, a corrupt row) it is now, and it holds
- restore: after a reload this session's drops come back under their headers, linked to their entries
- restore: an initial login starts an empty feed
- restore: this session's and this character's entries only, gone ones skipped, the newest MAX_DROPS
- restore: restored drops never merge; a live line for the same drop merges into one
- restore: the quality gate still runs; the situation gate and the feed filters do not
- restore: a restored drop opens no window, queues no toast and asks nothing
- restore: an area group made after the reload never takes a key from before it
- restore: restored drops are not counted new on a window minimized before the reload
- restore: a drop asked for before the reload reads Asked, not Ask, after it
- restore: drops cleared from the Drops tab before the reload stay cleared
- history: a live timer read undoes Expired; a rule estimate, declined and received do not
- session: This instance survives a reload in the same instance, and only then

### test_content_tabs.lua (6)

- content per tab: Drops offers This instance and This session, History adds All
- content per tab: the Content menu lists the active tab's values, in both layouts
- content per tab: the Content tooltip is the same on both tabs and names each value
- content per tab: Drops' This session starts at the stored session start, in the client clock
- content per tab: the feed.content row offers This instance and This session, default This session
- database: step 8 turns a stored feed.content all into session in every profile, and keeps the rest

### test_toast.lua (45)

- toast: Qualifies wants someone else's upgrade for you of minGain or more, likely or yes to trade
- toast: Compose answers the four rows' parts (feedback-9 spec §0)
- toast: Compose keeps the table's words, the empty slot and each trade reason
- toast: the longest rows fit at Toast.WIDTH, nothing cut (feedback-9 spec §0)
- toast edge: on for a new profile; turned off, nothing is built or shown
- toast edge: a qualifying drop shows at once, painted, and goes after its duration
- toast edge: the four rows beside a four-row icon, painted (feedback-9 spec §0)
- toast: on a two-item slot read in full each verdict is the cells' dual mark, and the toast widens for it (H7)
- toast edge: a dual mark is painted part by part, and the toast is only as wide as row 3 needs (H7)
- toast edge: the widened toast holds the Them verdict too, not only up to `· Them` (H7)
- toast edge: a verdict in a word takes no glyph's room
- toast edge: a looter of unknown class is a plain name in row 3's muted tone
- toast edge: a right-click anywhere closes it as the close mark does; the left button does not
- toast edge: in test mode the left button still drags it and a left click keeps it
- toast edge: without LibKa0s the seam's stub answers: nothing builds or shows, nothing raises
- toast edge: a Core without a close mark draws none; Ask takes its corner, a right-click still closes
- toast edge: a right-click on the item button closes it too
- toast edge: one at a time; the next waits its turn, and each drop toasts once
- toast edge: the queue keeps the newest MAX_QUEUE drops
- toast edge: a drop that turns likely later toasts on its DropUpdated
- toast edge: a hover pauses the countdown, and leaving resumes it with the time left
- toast edge: leaving through the close button resumes the countdown
- toast edge: not shown in combat; held until it ends, unless toast.inCombat
- toast edge: a drop asked for, or gone from the feed, is skipped when its turn comes
- toast edge: Ask goes through the shared host handler, and the button follows its state
- toast edge: toast.sound plays the client's alert from SOUNDKIT
- toast edge: only test mode drags it; the position is saved and Reset position forgets it
- toast edge: toast.scale scales a toast on screen live about its saved anchor, the point unchanged
- toast edge: the first toast is built at toast.scale, and a profile switch takes the incoming scale
- toast edge: test mode's placeholder toasts and stays until test mode ends
- toast edge: a drop that leaves the feed takes its toast and its place in the queue
- toast edge: the cap's trim takes the trimmed drop's toast, through the real feed
- toast edge: Ask on a toast whose drop is gone takes the toast down and asks nothing
- toast edge: turning the toast off takes it down and empties the queue; on again, new drops toast
- toast edge: a test toast goes when the toast is turned off, though it has no countdown
- toast edge: a profile switch to one with the toast off takes it down
- toast edge: the stand-down empties the queue and takes the toast down
- toast edge: a point saved before the shell moved to LibKa0s places it, with no migration
- toast edge: hovering the item button or Ask holds the countdown too
- toast edge: a drop met in combat waits after a switch's Clear; toast.inCombat on mid-combat shows the next
- toast edge: a toast held for combat comes back with its full duration
- toast edge: Show in combat turned off mid-combat keeps the toast on screen and holds the next
- toast edge: a profile switch mid-combat to one without Show in combat holds the next
- toast edge: on a shell that names no waiting keys, the drops gone from the feed still leave the queue
- toast: the diagnostics' window section reports the toast

### test_glow.lua (14)

- glow: KindOf is main for your upgrade, offSpec for an off-spec upgrade, nothing else glows
- glow: an upgrade its looter can't trade, or not yet estimated, never glows
- glow: without the library Apply still records its decision; a glow turned off clears it
- glow: each style starts with the knob table's arguments, under the addon's key
- glow: a repaint that changes nothing calls the library not at all; a setting or a size restarts it
- glow: Use class color draws in the player's class color with the swatch's alpha, and restarts it
- glow: Use class color with a class that has no color falls through to the swatch
- glow: the proc style's opening burst plays once, not again on every repaint's re-show
- glow: the full table's Drops row icon wears its drop's glow; the detail card's header too
- glow: a pooled row reused for a sidegrade, or left unused, loses its glow
- glow: the compact card's icon wears it; the table's rows stop theirs in the compact layout
- glow: the toast's icon never glows, for a main-spec or an off-spec upgrade (feedback-21 G9)
- glow: a glow row's write re-applies every drawn icon at once
- glow: a profile switch re-reads the glow settings

### test_icon_style.lua (10)

- icon style: by default an item icon is cropped 0.1 a side in a Solid black border 2 pixels thick
- icon style: zoom 0 and no border draw an item icon as it was before G11
- icon style: Solid is registered with LibSharedMedia as the flat white texture, so the dropdown offers it
- icon style: a repaint that changes nothing costs nothing; a row's write restyles every button made so far
- icon style: Show border draws the swatch over the icon; Use class color the player's class with its alpha
- icon style: a border style LibSharedMedia knows draws its texture
- icon style: Color by item quality draws each item's quality color, the swatch's alpha kept
- icon style: the Drops row's icon, its Me icons and the detail card's header take a row's write live
- icon style: the compact card's icon and the toast's icon wear it too
- icon style: the glow starts over the border, and a profile switch re-reads the look

### test_layers.lua (9)

- layers: one table names the addon's strata by the standard's tier keys
- layers: the level bands keep border < glow, content < grip < popovers < modal
- layers: the main window is MEDIUM, toplevel and clamped
- layers: the Offer panel stays in the window's strata; floating, it is W+30, docked W+1
- layers: the compact Filters panel is W+35 in the window's strata, its dropdowns over it
- layers: the Edit message box is DIALOG at W+40 and toplevel
- layers: the toast is HIGH, above the window and under the modal
- layers: an item button's border is button + 1, explicit, and the glow button + 2
- layers: no strata literal and no absolute level in the addon's own source

### test_auto_ask.lua (24)

- auto-ask: DueAt is the delay after the later of the drop and the encounter's end
- auto-ask: ClampDelay keeps the delay inside 3..30 and defaults to 10
- auto-ask edge: off by default; a qualifying drop is never asked for
- auto-ask edge: a qualifying drop is whispered for after the delay, once, with the ask template
- auto-ask edge: the delay and the least gain are the settings'
- auto-ask edge: an upgrade into an empty slot is asked for, whatever the least gain (DW-62)
- auto-ask edge: a sidegrade, your own drop or an unknown trade is not asked for; a later likely is
- auto-ask edge: held while an encounter is in progress, then due the delay after its end
- auto-ask edge: a loading screen out of an encounter lets the held asks go (DW-62)
- auto-ask edge: the restriction lifting after the loading screen ends the hold (M6 review)
- auto-ask edge: a restriction change with no world event never ends a held encounter
- auto-ask edge: a zone change with no encounter restriction ends a held encounter too
- auto-ask edge: an encounter that ends after the drop pushes the ask back
- auto-ask edge: asking yourself cancels it
- auto-ask edge: the looter leaving the group cancels it
- auto-ask edge: receiving the item cancels it
- auto-ask edge: a drop gone from the feed, or no longer qualifying, is dropped when due
- auto-ask edge: turning it off cancels the waiting asks; turned on, older drops do not count
- auto-ask edge: a profile switch that turns it on never asks for the drops already there
- auto-ask edge: a profile switch that turns it off cancels the waiting asks
- auto-ask edge: the first time it is turned on, a one-time notice explains it
- auto-ask edge: the stand-down cancels every waiting ask
- auto-ask edge: in test mode a placeholder's ask is printed, never sent
- auto-ask: the diagnostics' messaging section reports auto-ask

### test_sim_core.lua (27)

- sim seam: every Compat member that answers for the client is wrapped; the pure ones are not
- sim seam: a provider answers only while a simulation runs; Live reads the client again
- sim seam: the sender prints [sim] with the channel and the target, and sends nothing
- sim seam: an ask goes through the real messaging edge and is printed, never whispered
- sim seam: no real inspect and no real trade while a simulation runs
- sim start: refused while stood down, and it says which
- sim start: refused while test mode is on, and it says which
- sim start: refused in combat, and it says which
- sim start: refused inside an instance, and it says which
- sim start: refused in a real group, and it says which
- sim start: a second start is refused; test mode is refused while one runs
- sim fire: an event reaches the handlers its registration calls, with its payload
- sim restrictions: Encounter and the lockdown are answered by the client seam and stop the sends
- sim timers: run while the simulation does, and never after its stop
- sim history: drops go to the session log, never to DropWatcherDB.global.history
- sim history: a real drop while a simulation runs is real: saved, and it survives the stop
- sim history: a real trade while a simulation runs settles against the saved history
- sim fire: a handler that raises never unwinds into the driver; the later handlers run
- sim stop: a step that raises never skips the rest of the cleanup
- sim fire: an event the client rejected at registration is never delivered
- sim deliver: NS.DeliverEvent answers the handler count and isolates a raising handler
- sim stop: its drops, groups, inspect entries, restrictions and lockdown go; real drops stay
- sim stop: a queued ask is canceled before the lift, so it never goes out
- sim stop: the situation is classified from the real client again
- sim auto-stop: joining a real group ends the simulation
- sim auto-stop: entering an instance ends the simulation
- sim stand-down: disabling the addon stops the simulation and leaves no timer

### test_sim_pool.lua (21)

- compat journal: the selection is read whole, the frame's part only once it loads
- compat journal: Select applies the selection in the journal's order and resets the filters
- compat journal: Instances lists the tier's dungeons or raids; Loot answers the loaded and the pending
- compat journal: world bosses are flagged, bosses named, the keys' preview level set and put back (fb17)
- sim pool: each situation reads its side and difficulty; the class filter is yours or none
- sim pool: a loot burst draws the pool's gear, and every drop only when it has none
- sim pool: a read takes every instance of the newest tier at every difficulty and restores the selection
- sim pool: the selection is restored even when a read raises
- sim pool: the journal is not read while its frame is shown
- sim pool: a frame shown the whole time ends in the fallback at the timeout
- sim pool: entries still loading are awaited through EJ_LOOT_DATA_RECIEVED
- sim pool: at the timeout the build keeps what has loaded
- sim pool: loot for me sets the journal's class filter to yours; any lists every class
- sim pool: an empty journal falls back to your own gear, reported once
- sim pool: without the journal API the fallback answers at once
- sim pool: the stop ends a waiting build, and a late event does nothing
- sim roster: the random source replays a seed and stays in range
- sim roster: a party has four members, a raid nine to nineteen, each distinct and whole
- sim roster: gear is what the class can wear, worn at a level inside the band; the rest stays empty
- sim roster: the content's level is the median of the pool's drops
- sim roster: Create draws the group from the session's pool and the stop forgets it

### test_sim_events.lua (21)

- sim lines: every LOOT_ITEM* shape is written from its GlobalString and read back by the parser
- sim lines: a locale that reorders its arguments is written in its own order
- sim lines: a burst has one to three lines, your own when asked, and a looter from another realm
- sim world: the roster, the situation and the announce channel read the invented party
- sim world: in a raid you are raid1 and the members raid2 onward; the channel is RAID
- sim world: the stop puts the real world back
- sim loot: a member's line goes through the parser into the feed, under their GUID
- sim loot: n random lines, and nothing without a running simulation or a pool
- sim inspect: a looter is read through the broker's queue after the reply, never the fast path
- sim inspect: a failing member times out; a member out of range waits and gives up
- sim inspect: the reply delay is the session's seeded random source
- sim encounter: a pull raises combat and the lockdown; the ask waits and goes out after the kill
- sim encounter: loot after a kill joins the boss's group, named by the pull
- sim encounter: a keystone run groups its loot and holds the ChallengeMode restriction
- sim combat: the stop ends a combat edge it raised
- sim own drops: they land in your bags with a trade window the trade timer counts down
- sim own drops: read at their bag slot from their link, and their tooltip is their link's (DW-80)
- sim own drops: the scenario sets the window and the ending-soon count
- sim trade: your drop traded away and another's received land in the session's history log
- sim trade: refused for an unknown drop, a real one and an expired own drop
- sim stop: your simulated bag items leave the gear snapshot and the trade timer

### test_sim_scenario.lua (31)

- sim verbs: DropWatcher's five host verbs on the descriptor, each parsing its arguments
- sim timeline: a boss is pull, lockdown, kill, loot, lockdown lifted; a key ends with its completion
- sim verbs: `/dw sim` through RunVerb prints the status and the usage and opens the panel
- sim verbs: every verb but the free ones needs a running simulation; an unknown word prints the usage
- sim verbs: each host verb runs through RunVerb with its line, and says why it did nothing
- sim verbs: a refused start prints its one line and nothing more
- sim verbs: `/dw sim run` while disabled prints the one refusal line
- sim verbs: refused while the addon is disabled, like every feature verb
- sim start: refused in combat and with test mode on, each with its line
- sim start: the scenario's pool, group and situation, and the window open
- sim start: a raid takes its size; a party is always four
- sim step: the timeline waits for the pool, then plays one step at a time
- sim restart: a stale pool callback from the first session never readies the restarted one (C.1)
- sim run: Run while the panel's click-ahead plays answers playing (C.2)
- sim run: a typed start plays on its own
- sim run: a typed start waits for the pool, then plays
- sim step: a typed step while it plays pauses it and plays one step
- sim pause before the pool is ready: the ready pool plays nothing
- sim run: plays every step a few seconds apart, each with its line, then says it has finished
- sim step delay: one second by default, read from `sim.stepDelay`; a bad value falls back
- sim step delay: an untouched setting runs the steps one second apart
- sim step delay: ValidStepDelay takes 0.5 to 10 in steps of 0.5
- sim step delay: `/dw set sim.stepDelay` takes a half step, clamps to the range, refuses a quarter step
- sim step delay: a run waits the set delay, and a change takes effect from the next step
- sim stop: ends a playing timeline and its timers
- sim stand-down: disabling mid-run stops the timeline; nothing fires afterward
- sim window: the sim strip (not the SIMULATION text) with the scenario tooltip, and the footer says Simulating
- sim diagnostics: the section reads the session, the pool, the timeline and the sends
- sim debug: the SIM tag logs every injected event and every step
- sim e2e key: parsed drops, both verdicts, the ask held in the lockdown and flushed, countdowns, a trade
- sim e2e raid: a large roster, auto-ask after its delay, a trade received, nothing sent or saved

### test_sim_e2e.lua (20)

- sim e2e: no module reads the world the simulator answers except through NS.Compat
- sim e2e: the seam wraps every world read, the combat flags and the GlobalStrings
- sim e2e: nothing escapes the seam
- sim e2e key, full: a run fills Drops, yours too, under the default filters
- sim e2e dungeon, full: a run fills Drops, yours too, under the default filters
- sim e2e raid, full: a run fills Drops, yours too, under the default filters
- sim e2e lfr, full: a run fills Drops, yours too, under the default filters
- sim e2e delve, full: a run fills Drops, yours too, under the default filters
- sim e2e world, full: a run fills Drops, yours too, under the default filters
- sim e2e key, compact: a run fills Drops, yours too, under the default filters
- sim e2e dungeon, compact: a run fills Drops, yours too, under the default filters
- sim e2e raid, compact: a run fills Drops, yours too, under the default filters
- sim e2e lfr, compact: a run fills Drops, yours too, under the default filters
- sim e2e delve, compact: a run fills Drops, yours too, under the default filters
- sim e2e world, compact: a run fills Drops, yours too, under the default filters
- sim e2e: a simulated key's auto-open is compact by default, full with the option off, then the stored layout
- sim e2e: the combat flags answer the simulated fight, and the client's again after it
- sim e2e: the loot lines are written from the GlobalStrings Compat reads
- sim e2e: in a raid, raid1 is you, online, for every unit read
- sim e2e: Raid Finder is an instance group, so asks announce in instance chat

### test_sim_report.lua (16)

- sim report: the owner's key run: the second drop is yours, on Drops, nothing lost
- sim report: the step's chat line says where its drops went
- sim report: /dw sim loot says where its drops went
- sim report: each drop's place: Drops (yours too), hidden by its gate, loading, cleared
- sim report: the detail counts the drops and says which are hidden or otherwise placed
- sim report: the tooltip names each drop, its looter and its tab or gate
- sim report: a Drops header no longer counts drops of yours apart
- sim report regression key: Drops + hidden = every loot step's drops
- sim report regression dungeon: Drops + hidden = every loot step's drops
- sim report regression raid: Drops + hidden = every loot step's drops
- sim report regression lfr: Drops + hidden = every loot step's drops
- sim report regression delve: Drops + hidden = every loot step's drops
- sim report regression world: Drops + hidden = every loot step's drops
- sim report: a place lists yours on Drops and honors the feed the window shows
- sim report: View reads the feed the window shows; feed.showOwn is retired
- sim report: the owner's step lists yours on Drops, and the tabs agree

### test_sim_panel.lua (13)

- sim panel: the descriptor carries DropWatcher's presentation fields and nothing else
- sim panel: a key's preview names every step with its boss, and every command, before a run
- sim panel: a step names the boss it played, and a loot step its count or its detail
- sim panel: every step kind's tooltip says what it injects; Start and Stop say what they do
- sim panel: the scenarios carry their names, and the raids the sizes the picker offers
- sim panel: `/dw sim` opens it with DropWatcher's title, `/dw sim panel` toggles it
- sim panel: picking Raid offers its sizes, and Start starts it at the chosen size
- sim panel: the controls are Pause, Restart and Stop
- sim panel: a played step shows the catalog's confirm tick and names its boss
- sim panel: opened after `/dw sim start`, it docks beside the Drop Watcher window
- sim panel: opened before the window, it docks beside the window once a slow pool opens it
- sim panel: dragging writes nothing to the profile; Reset position redocks
- sim panel: standing down hides it, idle or running, and it does not open while stood down

### test_bindings.lua (14)

- bindings: Bindings.xml puts every binding in the addon's own category, no header, no default, in NS.BINDINGS order, and the TOC does not list it
- bindings: NS.BINDINGS is the one table, Show window first, with a localized tooltip, on a library-less install too
- bindings: the button is a plain hidden Button named DropWatcherToggleWindow, registered for AnyDown only
- bindings: one press is one NS.Window.Toggle
- bindings: the category label is the brand and the binding label is localized, with no brand in it
- bindings: the button exists on a library-less install too
- keybindings: the General page's strip ends with Keybindings
- keybindings: the tab's rows are NS.BINDINGS, in order, labeled with the BINDING_NAME_ globals
- keybindings: a key bound through the tab is the binding's key, saved to the set in force
- keybindings: a key set on the client's page shows in the tab after UPDATE_BINDINGS
- keybindings: a row is one key button and Clear, a second key counted on it as '<key> +1'
- keybindings: in combat the tab refuses and calls no binding API
- keybindings: the General page's Defaults tooltip says the keys are not changed
- keybindings: the General page's Defaults tooltip is Reset all settings' own, then the keys line (DRO-L-new4)

### test_disabled.lua (13)

- disabled 1: enabled, the addon registers exactly the events it declares
- disabled 2: through /dw disable, nothing is registered, scheduled or shown
- disabled 2: through the write seam, nothing is registered, scheduled or shown
- disabled 3: every feature event, fired anyway while disabled, reaches its handler and writes, prints and shows nothing
- disabled 4: every reserved verb, and the bare command, keeps answering while disabled
- disabled 5: every feature verb answers with the one refusal line and writes nothing
- disabled 6: the stand-up re-registers from current state and the window comes back
- disabled 7: a disabled profile loads stood down, with nothing registered
- disabled 8: the launcher and the key binding: left-click opens settings and writes nothing; the menu grays every entry but Enabled; a key press refuses
- disabled 9: under the perf hold alone, each feature refusal names the capture, never 'is disabled'
- disabled 10: while disabled, each feature refusal is the one refusal line, unwrapped
- disabled 11: the latch holds in both orders, perf first and disabled first
- disabled 12: disabling hides the simulation panel, idle or running, and it stays shut

### test_diagnostics.lua (15)

- diagnostics: the sections are the addon's, in report order
- diagnostics: the report names the schema, the profile, the holds and the window decision
- diagnostics: the situation section names the key, its settings and the inputs
- diagnostics: it runs while stood down and says so, without acting
- diagnostics: a non-default setting is listed, and `enabled` always is
- diagnostics: the restrictions section names the answers, the reasons and the last announced
- diagnostics: the roster section lists the stored members without reading the client
- diagnostics: the gear section lists the stored slots without reading the client
- diagnostics: the feed section counts the parser's lines and names the last loot
- diagnostics: the feed section counts the drops, the hidden ones and the context
- diagnostics: the trade section shows the timers, the ticker and each entry
- diagnostics: the inspect section shows the queue and each member's entry
- diagnostics: the messaging section counts the registry, the sends and lists each queued ask
- diagnostics: the state section is one read of enabled, situation, test mode, restriction and queue
- diagnostics: the scoring section names the scorer, the one in use, Pawn and the pending retries

### test_debug_coverage.lua (11)

- debug: a drop added names its item level and source, and its trade estimate with the reason
- debug: the encounter and the keystone run edges each write one FEED line
- debug: a drop re-judged on new facts says what it reads now
- debug: the inspect queue logs its park and resume over combat, only with jobs waiting
- debug: auto-ask's waiting asks are held for an encounter and released at its end, each one line
- diagnostics: an auto-ask waiting is listed with its looter and when it is due
- debug: the toast queue held over combat says so when combat ends
- diagnostics: the toast queue is listed while toasts wait
- diagnostics: each drop line names its looter, both verdicts and the trade estimate
- debug: the trade timer's bag scan logs on change only, not on every scan
- debug: the search box logs its text once, when it loses focus, never per keystroke

### test_vendor_sync.lua (3)

- libs/LibKa0s is the LibKa0s release CLAUDE.md says this addon bundles
- tests/_kit is the test kit that shipped with that release
- the automated-test runner is recorded executable (100755)

### test_locale.lua (7)

- locale: the enUS files are the TOC's, the base file first and its topic files after it
- locale: every enUS key lives in exactly one enUS file
- locale: a topic file holds only what its folder alone reads
- locale: the scan finds routed literals in the addon's files
- locale: enUS carries every string routed through NS.L
- locale: every enUS key is still read by the addon's files
- locale: display strings use only characters every shipped skin face draws

### test_eol.lua (2)

- eol: every tracked file carries the terminator .gitattributes declares for it
- eol: .gitattributes is line-endings-§5's canonical body for this repo kind

### test_prose.lua (15)

- prose: no authored file carries a British spelling from localization-§5's published list
- prose: the gate carries localization-§5's two lists whole, and nothing of its own
- prose self-test: the carve-out suppresses the named generated folder, and only it
- prose self-test: a path the carve-out does not name is not covered by one that looks like it
- prose self-test: a carve-out that is not a set of path strings is a failure, not a silence
- prose self-test: a TOC's file lines are read as paths, and its directives and comments are not
- prose self-test: a .pkgmeta's ignore block is read, and the keys around it are not
- prose self-test: an ignore entry covers a path exactly, by folder, and by wildcard
- prose self-test: the carve-out admits a generated dump and refuses a file the TOC loads
- prose self-test: a waiver-file exclusion meets the same two refusals as the carve-out
- prose self-test: each list is refused on the matching rule its own scan uses
- prose self-test: the scan and the refusals read the added exclusions through one reader
- prose self-test: a narrowing is refused by what it suppresses, not by how it is written
- prose self-test: the disclosure names what each entry suppressed, and says when it is bounded
- prose self-test: a malformed waived is a failure, not a silence

### test_layout_cap.lua (13)

- layoutcap: every authored file over the 1500-line cap is named in the census
- layoutcap: no census row outlives the breach it records
- layoutcap: every over-cap census row carries one of layout-§1's three terminal states
- layoutcap: the census and the exempt set agree about which paths were exempted
- layoutcap: an empty census is written as a result rather than left standing empty
- layoutcap self-test: the parser reads the census nested under the register, and stops there
- layoutcap self-test: a census outside its register, or at the wrong level, is not read
- layoutcap self-test: an over-cap file missing from the census is reported, and an exempt one is not
- layoutcap self-test: a census row that outlives its breach is reported
- layoutcap self-test: an over-cap row that names no terminal state is reported
- layoutcap self-test: the census and the exempt set are held to naming the same paths
- layoutcap self-test: a census that states nothing is told apart from one that states none
- layoutcap self-test: the exempt set takes folders as well as paths

### test_diagnostics_contract.lua (9)

- diagnostics contract: both forms run the report
- diagnostics contract: the debug word is matched in any case
- diagnostics contract: both markers carry the brand and the end counts the report
- diagnostics contract: the report appends after what the console already holds
- diagnostics contract: the report lands with logging off and turns it on for the session
- diagnostics contract: an addon that opts out lands the report and leaves logging off (skipped: this addon keeps the default (Kit.diagnostics.enablesLogging is not false), so its report turns logging on; the case above holds it)
- diagnostics contract: with logging already on, the report writes no second enable line
- diagnostics contract: both forms run while the addon is disabled
- diagnostics contract: no other name runs the report

### test_lizard_sighted.lua (8)

- lizard sighted: every hazard lizard loses a function over is neutralized
- lizard sighted: fields, strings, comments and look-alike names come through unchanged
- lizard sighted: a method definition is rewritten to its dot form with self
- lizard sighted: no line is added or removed, CRLF included
- lizard sighted: countFunctions counts the keyword, not strings, comments or longer names
- lizard sighted: listedCounts reads the per-file table, once per file
- lizard sighted: parity names every file whose counts differ, and only those
- lizard sighted: lizard lists every function of a hazard fixture once it is sanitized

## Totals

| Suite | Cases |
|-------|------:|
| test_harness.lua | 12 |
| test_surface_parity.lua | 24 |
| test_setup.lua | 24 |
| test_database.lua | 13 |
| test_schema.lua | 11 |
| test_schema_rows.lua | 23 |
| test_settings_pages.lua | 46 |
| test_skin_setup.lua | 18 |
| test_skin_outline.lua | 9 |
| test_skin_chrome.lua | 11 |
| test_skin_literals.lua | 3 |
| test_skin_hud.lua | 10 |
| test_skin_picker.lua | 17 |
| test_skin_verb.lua | 6 |
| test_skin_settings.lua | 10 |
| test_slash.lua | 26 |
| test_window.lua | 19 |
| test_window_shell.lua | 62 |
| test_window_compact.lua | 25 |
| test_compact_cards.lua | 27 |
| test_compact_group.lua | 23 |
| test_compact_history.lua | 11 |
| test_history_card.lua | 15 |
| test_compact_chrome.lua | 23 |
| test_compact_modes.lua | 7 |
| test_window_group.lua | 51 |
| test_drops_layout.lua | 10 |
| test_side_cells.lua | 26 |
| test_detail_card.lua | 30 |
| test_own_drops.lua | 16 |
| test_tip_marks.lua | 27 |
| test_drops_strip.lua | 15 |
| test_footer_row.lua | 8 |
| test_offer_panel.lua | 21 |
| test_mine_cells.lua | 14 |
| test_row_tooltip.lua | 13 |
| test_test_mode.lua | 40 |
| test_compat.lua | 72 |
| test_text_parse.lua | 10 |
| test_constants.lua | 12 |
| test_class_data.lua | 13 |
| test_evaluate.lua | 38 |
| test_offspec.lua | 11 |
| test_offspec_cells.lua | 23 |
| test_offspec_ask.lua | 15 |
| test_offspec_offer.lua | 11 |
| test_scoring.lua | 16 |
| test_quality_gate.lua | 24 |
| test_situations.lua | 14 |
| test_trade_rules.lua | 24 |
| test_messaging.lua | 26 |
| test_restrictions.lua | 15 |
| test_roster.lua | 13 |
| test_item_facts.lua | 21 |
| test_item_read.lua | 24 |
| test_gear.lua | 27 |
| test_loot_parser.lua | 28 |
| test_inspect.lua | 33 |
| test_feed.lua | 50 |
| test_feed_counts.lua | 10 |
| test_group_roster.lua | 13 |
| test_group_place.lua | 15 |
| test_char_filter.lua | 19 |
| test_trade_timer.lua | 16 |
| test_trade_helper.lua | 6 |
| test_asks.lua | 26 |
| test_transmog.lua | 13 |
| test_history.lua | 30 |
| test_history_retention.lua | 16 |
| test_feed_restore.lua | 14 |
| test_content_tabs.lua | 6 |
| test_toast.lua | 45 |
| test_glow.lua | 14 |
| test_icon_style.lua | 10 |
| test_layers.lua | 9 |
| test_auto_ask.lua | 24 |
| test_sim_core.lua | 27 |
| test_sim_pool.lua | 21 |
| test_sim_events.lua | 21 |
| test_sim_scenario.lua | 31 |
| test_sim_e2e.lua | 20 |
| test_sim_report.lua | 16 |
| test_sim_panel.lua | 13 |
| test_bindings.lua | 14 |
| test_disabled.lua | 13 |
| test_diagnostics.lua | 15 |
| test_debug_coverage.lua | 11 |
| test_vendor_sync.lua | 3 |
| test_locale.lua | 7 |
| test_eol.lua | 2 |
| test_prose.lua | 15 |
| test_layout_cap.lua | 13 |
| test_diagnostics_contract.lua | 8 |
| test_lizard_sighted.lua | 8 |
| Skipped | 1 |
| **Total** | **1810** |
