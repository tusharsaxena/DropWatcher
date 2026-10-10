# Test Cases

The full inventory of every headless test case in this repo, grouped by the suite file it
lives in. The `## Totals` table below counts the cases that run: its **Total** is the
authoritative pass count, and the README test badge and any count quoted in the docs must equal
it. A declared skip is listed by name in its group and counted on the `Skipped` row, never in
Total.

**Generated — do not hand-edit.** Regenerate with `lua tests/run.lua --list > docs/test-cases.md`.

### test_harness.lua (10)

- harness: the addon's file list is the TOC's, Namespace first and Profiles last
- harness: every LibKa0s file comes from LibKa0s.xml, in its order
- harness: every adopted LibKa0s module is the live library, not its stub
- toc: the fixed field order, a single Retail Interface line and the X-Standard field
- toc: the icon is the 128x128 logo, and the file exists
- toc: OptionalDeps names Pawn and CanIMogIt, and no hard Dependencies
- repo: no stored copy of the context pack (documentation-§3, anti-pattern #49)
- repo: the root doc set is README, the CLAUDE stub, DEPENDENCIES and LICENSE
- repo: every authored file opens with the bootstrap and a comment naming its path
- repo: the .pkgmeta has no externals and ignores the dev-only entries

### test_surface_parity.lua (16)

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
- parity: the Bus stand-in carries every member of the live bus
- parity: the Pool stub carries the LibKa0s-Pool-1.0 surface this addon calls
- parity: the Item stub carries the whole LibKa0s-Item-1.0 surface
- parity: the Perf stub carries every Perf member the addon reaches
- parity: the Env seam publishes the same NS members on both paths
- parity: the Media seam publishes the same NS members on both paths

### test_setup.lua (17)

- core: NS.Print is NS.Util.print after AceConsole's embed (architecture-§2)
- core: the printer tags every line with the cyan [DW] prefix
- core: the close-button wrapper passes the addon folder as the third argument
- core: no file but the wrapper calls a close-button factory directly
- media: FONT_MONO is the shipped face live, and a real client font degraded
- bus: the catalog holds the ten messages of the design, each Ka0s_DropWatcher_<Event>
- bus: a tracked target's registrations come down with the stand-down and back with the stand-up
- perf: every declared bucket is reached by a real bracket
- perf: with capture off the bracket notes nothing
- perf: the `perf` hold stands the addon down, and the verbs keep answering
- perf: the descriptor's SavedVariables global is declared in the TOC
- launcher: one object, labeled with the brand, the logo as its icon, registered on enable
- launcher: the right-click menu is Enabled, Locked, Test mode, Show window, in that order
- launcher: each menu entry calls the same handler its verb and its row call
- options: the category registers eagerly, with the General page under it
- options: the General page's first group is exactly `Master controls`
- options: the degraded load completes, and the panel says once that it is unavailable

### test_database.lua (4)

- database: the defaults stamp schemaVersion 0, and the runner moves it to the code's target
- database: the runner is idempotent, and a stored stamp at the target runs no step
- database: every step up to the target exists
- database: the profile defaults carry every Master controls value, and no debug flag

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

### test_slash.lua (10)

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

### test_window.lua (13)

- window: built lazily, on the first show, and not before
- window: Escape closes it (UISpecialFrames) and it wears the shared close mark
- window: General visibility `never` keeps it hidden even when opened
- window: `inCombat` shows it only in combat, re-read on both combat edges
- window: a drag stores the point, and Reset position forgets it
- window: locked, a drag does not start
- window: resizable from the corner grip, with the design's minimum size
- window: test mode shows the banner and hides the empty-state text
- window: combat ends test mode, and test mode cannot start in combat
- window: with test mode on, Close and Toggle still change what is shown
- window: turning test mode off closes the window only when test mode opened it
- window: the combat edge decides, even while the player's combat flag lags it
- window: a resize saves the anchor with the size, so a settings repaint does not move it

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

### test_class_data.lua (12)

- classdata: thirteen classes with their client classIDs, each with an armor type
- classdata: every spec row is well-formed and its class lists it
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

### test_evaluate.lua (31)

- evaluate: every equip location in SLOT_PLAN compares against its slot
- evaluate: an equip location with no plan is unknown (not gear)
- evaluate: pair compares against the lower of the two slots
- evaluate: an empty slot is an upgrade with the emptySlot reason
- evaluate: a slot that is not known is unknown, never an upgrade
- evaluate: a one-hander compares against the main hand only, unless the candidate dual wields
- evaluate: a dual wielder holding a two-hander compares a one-hander against the two-hander
- evaluate: a two-hander compares against the average of both hands
- evaluate: Titan's Grip compares a two-hander as a pair over both hands
- evaluate: an off hand against a wielded two-hander compares with the two-hander, never an empty slot
- evaluate: ranged weapons are two-handers for hunters and main hand for wand users
- evaluate: a unique-equipped drop compares against the item holding its category
- evaluate: compareOwned takes the better of equipped and owned per slot
- evaluate: a known spec is judged by the item's own spec list
- evaluate: spec unknown falls back to ClassData for armor, jewelry, shields and off hands
- evaluate: a known spec with no item spec list uses the spec's own class data
- evaluate: the primary stat decides when every spec agrees, and is ambiguous otherwise
- evaluate: an unknown class cannot be judged
- evaluate: tier tokens are judged by their class list
- evaluate: a class-restricted item refuses other classes
- evaluate: an undesired subclass is doesntWant, but only when the item is usable
- evaluate: the sidegrade band splits upgrade, sidegrade and downgrade
- evaluate: the score decides with the ilvl when they agree, and sidegrades when they disagree
- evaluate: the scorer is optional, may be pending, and may fail without harm
- evaluate: a two-hander's score baseline is the average of both hands' scores
- evaluate: verdict precedence is cant, then doesntWant, then unknown, then the comparison
- evaluate: the track delta orders tracks by tier, then rank
- evaluate: the output carries every field of spec 5.2 step 5
- evaluate: nil and garbage inputs never throw and answer unknown with a reason
- evaluate: garbage inside the tables never throws
- evaluate: an internal failure is caught and reported as unknown

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
- trade rules: each situation's default rule is CONTENT_RULE, raid conservatively personal
- trade rules: the override map replaces a situation's rule
- trade rules: an override naming no rule, or equal to the default, is not an override
- trade rules: an unknown or missing situation takes the default personal rule
- trade rules: Rules lists every situation in order with its rule, default and override flag
- trade rules: Reset clears the override map in place, restoring the defaults
- trade rules: IsRule knows the three rule names and nothing else
- trade rules: nil and garbage inputs never throw
- trade rules: bad facts are unknown badFacts

### test_disabled.lua (9)

- disabled 1: enabled, the addon registers exactly the events it declares
- disabled 2: through /dw disable, nothing is registered, scheduled or shown
- disabled 2: through the write seam, nothing is registered, scheduled or shown
- disabled 3: no SavedVariables write from a game event while disabled
- disabled 4: every reserved verb keeps answering while disabled
- disabled 5: a feature verb answers with the one refusal line and does nothing
- disabled 6: the stand-up re-registers from current state and the window comes back
- disabled 7: a disabled profile loads stood down, with nothing registered
- disabled 8: the launcher's menu grays every entry but Enabled

### test_diagnostics.lua (5)

- diagnostics: the sections are the addon's, in report order
- diagnostics: the report names the schema, the profile, the holds and the window decision
- diagnostics: the situation section names the key, its settings and the inputs
- diagnostics: it runs while stood down and says so, without acting
- diagnostics: a non-default setting is listed, and `enabled` always is

### test_vendor_sync.lua (3)

- libs/LibKa0s is the LibKa0s release CLAUDE.md says this addon bundles
- tests/_kit is the test kit that shipped with that release
- the automated-test runner is recorded executable (100755)

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
| test_harness.lua | 10 |
| test_surface_parity.lua | 16 |
| test_setup.lua | 17 |
| test_database.lua | 4 |
| test_schema.lua | 11 |
| test_slash.lua | 10 |
| test_window.lua | 13 |
| test_constants.lua | 12 |
| test_class_data.lua | 12 |
| test_evaluate.lua | 31 |
| test_quality_gate.lua | 24 |
| test_situations.lua | 14 |
| test_trade_rules.lua | 24 |
| test_disabled.lua | 9 |
| test_diagnostics.lua | 5 |
| test_vendor_sync.lua | 3 |
| test_eol.lua | 2 |
| test_prose.lua | 15 |
| test_layout_cap.lua | 13 |
| test_diagnostics_contract.lua | 8 |
| test_lizard_sighted.lua | 8 |
| Skipped | 1 |
| **Total** | **261** |
