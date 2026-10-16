# Ka0s Drop Watcher: owner feedback, fifteenth session (M25) — the session survives a reload

- **Source:** the owner's session of 2026-10-16: after a `/reload` the Drops tab was empty with Content: All, the
  History tab kept a false `Expired` on a still-tradeable drop, and a round of footer and History-tab requests.
  Every section below was approved in conversation on 2026-10-16.
- **Plan:** items DW-Q0 … DW-Q4 on `feat/2026-10-16-drop-watcher-feedback-15`
  (`docs/superpowers/plans/2026-10-16-drop-watcher-feedback-15.md`).
- **Already landed before this spec** (merge `1c82395`): the 12.1.5 trade line read (its hour term arrives
  unexpanded, `3 |4hour:hrs; 49 min (including time offline)`), the four-hour trade window
  (`C.TRADE_WINDOW = 14400`), the expired fold's window argument and the slash-separated restriction signature.

## 0. The session is the login, and the Drops tab survives a reload (DW-Q0)

**The session is the login.** A per-character session start (`time()`) is stored in SavedVariables. On
`PLAYER_ENTERING_WORLD` with `isInitialLogin` it is set to now; with `isReloadingUi` the stored value is kept; with
neither (a zone change) nothing moves. With no stored value (first run, a corrupt row) it is now. History's session key
(`feedKey@<sessionStart>`, `H.SessionStart()`) and every tab's "This session" read it; `H.SessionStart()` is no longer
lazy. Until the event has run (the window's first paint can come first), `H.SessionStart()` answers the stored
value when it exists, else now — never nil.

**The feed is rebuilt from history after a reload.** A new module `modules/FeedRestore.lua` runs once per load,
after a reload only (an initial login starts an empty feed, which is what "since login" means). It walks the
account's history log (`H.Store()`, never a test-mode or simulation log) for groups whose key ends in
`@<sessionStart>` and whose drops were seen by the current character (`seenBy == CharFilter.CurrentKey()`), oldest
first, skips entries marked `gone`, and replays at most `LootFeed`'s `MAX_DROPS` (200) of the newest. Each entry
becomes a live drop through a small `LootFeed` entry point (`LF.Restore(r)`; `LootFeed.lua` is 988 lines, so the
logic lives in FeedRestore and LootFeed only gains the hook):

- the record comes from the entry's `itemLink`, `looter` (Name-Realm), `class` and `isMine`; the looter's guid is
  read from the current roster when that member is in the group, else nil;
- its time is the entry's epoch `at` turned into the client clock (`GetTime() - (time() - at)`);
- its group is the history group's: the feed key is the history key without its `@<sessionStart>` suffix, and
  the label, kind, situation, instance, difficulty, seenBy and roster are the history group's, so the boss and
  key headers return as they were;
- it is judged like a fresh drop: item facts load (async), Me against the current gear, Them through the inspect
  broker, the trade estimate anew. The situation gate and the feed filters are skipped (the drop already passed
  them when it was first recorded); the quality gate still runs so the Quality dropdown keeps meaning what it says;
- source `restore`; a restored drop never merges with another restored drop, and a later live chat or encounter
  line for the same item merges into it as any duplicate source would;
- **it links to its history entry instead of recording a new one:** FeedRestore sets the session index
  (`History` gains `H.Adopt(dropId, entry)`) before `DropAdded` is sent, so `H.OnDropAdded` finds the id indexed
  and records nothing, and `DropUpdated` refreshes that entry from then on.

The trade timer needs no change: it reads `LootFeed.Drops()`, so your restored own drops are matched to their bag
items by link, identity or item id, and their countdowns, Offer and Post my tradeables return.

**A false Expired is undone by a live timer read.** An automatic outcome still only moves forward, with one
exception: when `H.Refresh` sees `trade.state == "yes"` with `basis == "timer"` on an entry whose outcome is
`expired`, the outcome returns to the one it replaced (`H.Advance` to `expired` now keeps it in `e.beforeExpired`;
an entry expired before this field existed returns to `seen`). A rule estimate (`basis == "rule"`) never undoes it.
A hand-set `declined`, `received` and `tradedAway` are untouched.

**This instance survives a reload.** The window's `instanceSince` (the last `SITUATION_CHANGED`, `GetTime()`) is
also stored per character as `{ at = time(), situation, instance }`, where instance is the instance map id (or nil
outside one). On a reload, the first situation announcement that names the same situation and instance restores
`instanceSince` from the stored epoch instead of resetting it.

**Accepted limits** (recorded in `known-limitations.md`): a reload mid-key starts a new key header for drops looted
after it (the feed's open-run key is not kept across a reload — unchanged from today); a full relog starts an empty
Drops tab (the session is the login).

## 1. The Content filter (DW-Q1)

- **Drops tab:** This instance and This session. **History tab:** This instance, This session and All. The
  choices are per tab in both layouts (the full filter bar and the compact Filters panel); today both tabs share
  one list.
- This session on Drops filters by the stored session start turned into the client clock; on History by the
  epoch. This instance uses the stored situation change of §0 on both.
- The schema row `feed.content` (Feed page, Filters group) offers This instance and This session, default This
  session. A v7→v8 migration, per profile, idempotent, turns a stored `all` into `session`. History still opens on
  All (`FB.TAB_FIXED`).
- The Content tooltip, both tabs: "This instance shows the drops since you entered this instance or started this
  key. This session shows every drop since you logged in; a /reload keeps them. All (History only) shows every
  kept day."

## 2. The footer, and Expand all / Collapse all (DW-Q2)

- **One button kind.** Every footer button is one shared width (`C.WINDOW.FOOTER_BUTTON_W`, sized so `Post my
  tradeables` fits with its icon), the same icon and label in both layouts. Scan group and Post my tradeables are
  the same size. The info text on the left gives way (ellipsis) when the row is narrow. The compact footer drops
  its short `Post` and `Clear` buttons.
- **Placement** (right to left):

  | | Full | Compact |
  |---|---|---|
  | Drops | Sort · Expand/Collapse · Scan group · Post my tradeables | Expand/Collapse · Post my tradeables (while something is tradeable) |
  | History | Sort · Expand/Collapse | Expand/Collapse |

  In compact, Sort stays in the Filters panel and Scan group stays the title-bar icon. The compact Drops strip is
  now always shown (the toggle lives there).
- **The toggle.** One button: `Expand all` while any header the current filters show is collapsed, `Collapse
  all` once every one is open. It sets every shown header of the active tab, Drops and History keeping their own
  collapsed state, and is disabled when the tab shows no header.

## 3. Clear history lives in Settings (DW-Q3)

- The Clear history button leaves both footers.
- Settings gains a `Clear history` button row on the Window page, beside `Keep history for`. It opens the same
  confirm ("Clear the drop history on every character? This cannot be undone.", `preferredIndex = 3`); accepting
  calls `NS.History.Clear()`. The popup moves from `WindowHistory.lua` into the History module (`H.AskClear`), so
  the settings row reaches it without a UI dependency. While test mode or a simulation is on, it clears that
  session-only log, as the footer button did.

## 4. The History tab's detail card (DW-Q4)

- History rows get the Drops tab's chevron and click-to-expand: one row open at a time (the History view's own
  `expanded`), the chevron up while open, the card indented under the row. Compact History expands the same way
  under the clicked card.
- The card is drawn from the stored snapshot by a new module `modules/HistoryCard.lua`, in the Drops card's
  visual language (the DetailCard frame and its section styles), since a history entry carries no stats, baseline,
  reasons, candidates or trade rule:
  - **Header:** the item icon and name, chips for slot, armor type, item level and the outcome in its tone.
  - **For you:** the verdict then, with the ilvl and score deltas, marked "At the time".
  - **For the group:** the looter, and the Them verdict and deltas (your own drop: who it was an upgrade for,
    when the snapshot holds it).
  - **Trade:** the recorded estimate and its reason, in the Drops card's words.
  - **When and where:** the time, the instance and difficulty, and the character that saw it.
  - **Actions:** Link in chat; Mark declined / Clear declined (the right-click menu stays); Show in Drops while
    the drop is also live in the Drops tab — it selects the Drops tab, opens that drop's header and expands its
    card.

## 5. Testing, docs, standards

- Every item lands test-first: the new case fails without the change. Gate: `lua tests/run.lua` green and
  `luacheck .` 0/0, both through the bounded runner.
- New in-game checks in `docs/smoke-tests.md`: the reload restore (HIST-2 rewritten: the drops come back), the
  undone Expired, This instance across a reload, the toggle on both tabs and layouts, the footer buttons, Clear
  history from Settings, the History card in both layouts.
- Docs synced: `ARCHITECTURE.md` (module map, message bus, known limitations summary), `module-map.md` (FeedRestore,
  HistoryCard and the changed rows), `schema.md` (the stored session and instance rows, step 8), `settings-panel.md`,
  `data-flow.md`, `known-limitations.md`.
- Standards: new modules in the TOC, strings through `locales/enUS.lua`, settings through the schema, files under
  1000 lines. No deviation is expected; one that appears is flagged to the owner, never taken.
