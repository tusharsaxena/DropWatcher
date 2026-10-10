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

### test_surface_parity.lua (18)

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
- parity: the Compat seam carries every library member it wires
- parity: the Compat seam publishes the same members on both load paths

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

### test_compat.lua (58)

- compat: the secret guards are the library's members on a live load
- compat: the guards answer the library's answers under the same fixture, on both load paths
- compat: with canaccessvalue present the degraded CanAccess asks it
- compat: ChatSender prefers C_ChatInfo.SendChatMessage
- compat: ChatSender falls back to the global, then to nil
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
- compat: GetDetailedItemLevel reads the effective level, nil without the API
- compat: GetItemStats copies every key, unknown ones too, and is empty without an answer
- compat: GetItemSpecs is a set, nil for an empty list or no API
- compat: GetItemUniqueness reads the category and the item's own uniqueness
- compat: PlayerHasTransmog answers the collection, nil when absent or secret
- compat: ItemClassRestriction reads the classes line by type, else by text
- compat: CanRequestItemLoad needs the load request and a timer
- compat: without Pawn every reader answers nil and nothing raises
- compat: Pawn loaded but not initialized is not ready
- compat: Pawn ready answers the upgrade list, an empty list, or nil while uncached
- compat: an error inside Pawn reads as not ready, never as this addon's error
- compat: a function-spelled PawnIsInitialized is called
- compat: PickupBagItem calls C_Container, and reports false without it
- compat: DropItemOnUnit and InitiateTrade call through, and report false when absent
- compat: InTradeRange reads interact distance 2; secret is out of range, no API lets it through
- compat: CursorHasItem and ClearCursor call through, and answer false when absent
- compat: NormalizedRealm reads the normalized realm, then the plain one stripped
- compat: PlayerSpecID reads the index then its spec id, nil without an answer or the library
- compat: InventoryItemLink reads the worn link, nil when empty, secret or absent
- compat: the bag readers call C_Container, guard a secret answer, and answer empty without it
- compat: the inspect gates answer plain booleans; a secret answer or no API is the safe side
- compat: the inspect calls, the spec, the item id, the inspect window and the hook
- compat: LootHistoryDrop answers a won drop's plain fields, else nil
- compat: ChallengeMapName answers a keystone dungeon's name, else nil
- compat: no other shipped file names a seam-only client API in code

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

### test_evaluate.lua (33)

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
- evaluate: a gun, crossbow or wand in the main hand is a two-hander for off hands and one-handers
- evaluate: a unique-equipped drop compares against the item holding its category
- evaluate: a unique drop whose own slot holds the category replaces that item
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
- evaluate: with a score, the verdict takes the sign only when ilvl and score agree in sign
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

### test_messaging.lua (24)

- messaging: the default templates are the spec §9.1 text, one per kind
- messaging: Template takes the owner's text, and the default for an empty or absent one
- messaging: Expand fills every token, and formats the gains as numbers
- messaging: unknown tokens are left as they are, and reported once each in order
- messaging: a known token with no value reads as ?, and is reported as missing
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

### test_item_facts.lua (18)

- item facts: a cached ring reads every field of spec §5.1
- item facts: a chest reads its appearance, account binds and no specs or track
- item facts: the track tier, by string id first, then by enUS name, else unset
- item facts: the track falls back to the tooltip's upgrade line
- item facts: an item unique on its own takes its item id as the category
- item facts: a token naming classes is a tier token; class gear carries classes only
- item facts: the quality falls back to the link's color
- item facts: the facts feed the verdict kernel
- item facts: Get caches by link until invalidated
- item facts: the cache is emptied whole when it would pass its cap
- item facts: garbage links answer nil and never raise
- item facts: learning an appearance re-reads the flag on the cached facts
- item facts: Request answers a cached item at once and never calls back
- item facts: an uncached item loads, and every waiter is called back once
- item facts: the callback retries until the item arrives
- item facts: an item that never arrives is given up after MAX_LOAD_TRIES, with nil
- item facts: a client that cannot load items answers unavailable
- item facts: stood down, the cache and the loads are dropped and a late answer is ignored

### test_gear.lua (17)

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
- gear: a tier token and a secret bag link are not owned gear
- gear: the candidate judges a drop against the worn item, and against the bags with compareOwned
- gear: the gear events share one throttled rebuild, which announces a change once
- gear: the player's spec change rebuilds; another unit's does not
- gear: the first lazy read announces nothing
- gear: an item still loading leaves its slot unknown, and its arrival rebuilds
- gear: the stand-down cancels the rebuild and drops the snapshot; the stand-up rebuilds

### test_loot_parser.lua (27)

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
- loot parser: a deDE client reads its own lines
- loot parser: positional arguments are read in the locale's order
- loot parser: CHAT_MSG_LOOT hands each receipt to every sink and counts the lines
- loot parser: the event's twelfth argument is the GUID it uses
- loot parser: stood down, CHAT_MSG_LOOT reaches nothing; the counters survive

### test_inspect.lua (28)

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
- inspect: InspectDone waits for the read's items to load
- inspect: one debug line per job
- inspect: secret GUIDs, units and specs are never used
- inspect: the stand-down clears this broker's inspect, every timer and the state

### test_feed.lua (36)

- feed: a member's loot is added once, judged for you, and asks for the looter's inspect
- feed: the looter's inspect re-judges the drop: their verdict and the trade estimate
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
- groups: loot naming an earlier encounter joins that encounter's group
- groups: a keystone run gathers every drop, the chest after completion included
- groups: outside an instance the area is the open world
- gates: an untracked situation hides the drop before its item is even loaded
- gates: below the quality threshold a downgrade for you is hidden, and costs no inspect
- gates: the upgrade override shows an upgrade for you below the threshold
- gates: the stored quality settings and the situation's override are read
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
- add: injects a drop past the situation gate; a stranger is judged without an inspect
- add: the test feed skips every gate and every inspect, and stays apart
- cap: the oldest drop goes first, and an emptied group with it
- secrets: a secret link, name or encounter id is never used
- stand-down: timers and pending loads are dropped, the drops kept

### test_trade_timer.lua (15)

- read: your drop's TradeTimeRemaining line gives its exact expiry, keyed by item GUID
- read: the sentence on a line of another type is still the timer (the text fallback)
- decoder: without the line type, the localized sentence is decoded with the client's globals
- read: no timer line (bound, or the window gone) means no: expired, never live
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

### test_trade_helper.lua (15)

- give: the drop's bag item is picked up by GUID and dropped on the member
- give: the target may be a name or a Name-Realm as well as a GUID
- give: an item moved since the last scan is found by a walk of the bags
- give: FindBagSlot takes the hinted slot first and refuses a missing or secret GUID
- give: an item gone from the bags, or a drop never matched, is notInBags
- give: an item whose trade window has passed is expired
- give: a busy cursor is never swapped away
- give: with no DropItemOnUnit the pickup is put back, and the reason is noApi
- give: CanGive answers every guard and touches nothing
- guards: combat refuses before the range is read
- guards: a stranger, yourself, an offline member and one out of range are refused
- guards: stood down, nothing is traded
- guards: every reason has its tooltip line, and none has none
- open: InitiateTrade with the member's unit; noApi without it
- diagnostics: the trade section reports the helper's counts once it has been used

### test_asks.lua (21)

- send: an ask whispers the looter's Name-Realm with the expanded template, and confirms in chat
- send: every token comes from the drop: item, ilvl, slot, track and both gains
- send: the one-ask guard refuses a repeat; with messages.oneAsk off a sent ask goes again
- send: an edited text over 255 bytes is refused tooLong and nothing is sent
- send: a stranger, yourself, an offline member and a missing target are refused
- send: an offer whispers the candidate, named in {player}
- fail: a raising sender fails with its message, prints nothing, and may be retried
- fail: a secret or empty error reads as error; no sender at all is noApi
- fail: the deprecated global sender is the fallback
- announce: auto picks INSTANCE_CHAT, then RAID, then PARTY, and never SAY or YELL
- announce: outside a group it fails noChannel
- queue: under a restriction the ask is queued, and the lift sends it at once
- flush: one send every 1.5 seconds, first in first out
- flush: a restriction back mid-flush stops it; the rest wait for the next trigger
- flush: ENCOUNTER_END and CHALLENGE_MODE_COMPLETED re-read a lockdown that lifted silently
- flush: a trigger with nothing queued, or while chat is still restricted, sends nothing
- cancel: pressing a queued ask cancels it; the lift sends nothing and the button is ready
- cancel: an ask queued to a looter who leaves is dropped; others stay
- cancel: a queued announce is dropped once you leave the group
- test mode: nothing is sent; the text is printed and the ask is marked sent, even restricted
- stand-down: a request is refused, the flush timer is canceled and the queue is dropped

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

### test_diagnostics.lua (13)

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
| test_surface_parity.lua | 18 |
| test_setup.lua | 17 |
| test_database.lua | 4 |
| test_schema.lua | 11 |
| test_slash.lua | 10 |
| test_window.lua | 13 |
| test_compat.lua | 58 |
| test_constants.lua | 12 |
| test_class_data.lua | 12 |
| test_evaluate.lua | 33 |
| test_quality_gate.lua | 24 |
| test_situations.lua | 14 |
| test_trade_rules.lua | 24 |
| test_messaging.lua | 24 |
| test_restrictions.lua | 15 |
| test_roster.lua | 13 |
| test_item_facts.lua | 18 |
| test_gear.lua | 17 |
| test_loot_parser.lua | 27 |
| test_inspect.lua | 28 |
| test_feed.lua | 36 |
| test_trade_timer.lua | 15 |
| test_trade_helper.lua | 15 |
| test_asks.lua | 21 |
| test_disabled.lua | 9 |
| test_diagnostics.lua | 13 |
| test_vendor_sync.lua | 3 |
| test_eol.lua | 2 |
| test_prose.lua | 15 |
| test_layout_cap.lua | 13 |
| test_diagnostics_contract.lua | 8 |
| test_lizard_sighted.lua | 8 |
| Skipped | 1 |
| **Total** | **560** |
