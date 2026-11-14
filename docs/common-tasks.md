# Common tasks — Ka0s Drop Watcher

## Add a setting

1. Add its default to `defaults/Profile.lua` (`NS.C.PROFILE`).
2. Declare the row in `settings/SchemaRows.lua` with `path`, `type`, `default` (from `NS.C`, never a
   literal), `page`, `group` (its tab), `label`, `tooltip` and a `validate` check; the file splices
   every row in with `NS.SchemaRuntime.AddRows`. A row that only matters when another is on takes a
   `disabledIf` predicate.
3. Add every new `label` and `tooltip` string to `locales/enUS_Settings.lua`, the settings panel's
   topic file split out of `locales/enUS.lua` at the 1500-line cap (localization-§6). A string a
   module also reads goes in `locales/enUS.lua` instead, under its first reader, and each key lives
   in one file. `test_locale` fails on any string routed through `NS.L` that has no entry in either,
   on a key written in both, and on a key in `enUS_Settings.lua` that a file outside `settings/` reads.
4. React in the row's `onChange` (or in `Settings.REACTIONS` when other surfaces write the same
   path). Never write the profile directly.
5. Read it with `NS.Setting(path)` in the module that uses it.
6. Add it to [`schema.md`](schema.md) and [`settings-panel.md`](settings-panel.md), then run
   `lua tests/run.lua` and `KA0S_KIT_CLIENT=forever lua tests/run.lua`: `test_schema` and
   `test_schema_rows` validate the row against the defaults on each client.

A setting of a feature one client lacks takes that feature's declaration on its row (`clients =
K.FEATURE_CLIENTS.<feature>`), and its default goes in `defaults/Profile.lua`'s Retail-only block
(added where `NS.Constants.FEATURE.<feature>` is true), so the other client has neither (see *Add a
feature that serves one client*).

## Add a feature that serves one client

Drop Watcher serves Retail and WoW Forever (clients-§4 to §6).

1. Name it in `C.FEATURE_CLIENTS` (`core/Constants.lua`) with its client, `{ "retail" }` or
   `{ "forever" }`; `C.FEATURE.<name>` is its `ForClient` answer, read once at load.
2. Declare it where it registers: `clients = ...` on its schema rows, its `NS.FEATURE_EVENTS` rows,
   its Drops column (`WG.COLUMNS`), its glow kind; gate a module's load-time work and a default on
   `C.FEATURE.<name>`. Never read `WOW_PROJECT_*` or the interface number outside `NS.Compat`.
3. A list both clients have in their own shape (seeds, situations, slots, rules) is one list per
   client picked once by `NS.Compat.ClientKey()` (clients-§5), never a filtered Retail list.
4. Add a per-client case: present where declared, absent where not, picking the expectation with
   `NS.Compat.ClientKey()`; a Retail-only feature's own cases take `T.RETAIL_ONLY`, and a case that
   mixes it with something both clients share is split so the shared half runs on both.
5. Add its rows to `ARCHITECTURE.md` → Per-client features (`retail`, `forever` or `both`, and the
   file that gates it), and its checks to `smoke-tests.md` naming their client.

## Add a slash verb

Add a positional triple `{ "name", L["description"], function(rest) ... end }` to `NS.COMMANDS` in
`settings/Slash.lua`, calling the same handler as any other surface that does the same thing. A
feature verb is refused while disabled by the dispatcher itself. Update `docs/slash-dispatch.md`.

## Add a game event

Append `{ "EVENT_NAME", "HandlerMethod" }` to `NS.FEATURE_EVENTS` from the owning file, and define
`DW.HandlerMethod`. The stand-up registers it, the stand-down unregisters it, and `test_disabled`
pins the list by name: add the event there too. Its case 3 fires the new event while disabled and
fails unless the fire reaches your handler.

## Add a bus message

Add `KEY = "Ka0s_DropWatcher_Event"` to the catalog in `core/Bus.lua`, with its one sender in the
comment. Receivers take their own target, `NS.Bus:NewTarget()`, and use `NS.MSG.KEY`, never the literal. Each new receiver adds its message to `PINNED_MESSAGES` in
`tests/test_disabled.lua` (one entry per receiver), or `test_disabled` 1 fails. Add its row (sender,
payload, consumers) to [`message-bus.md`](message-bus.md) and its count to `ARCHITECTURE.md` →
Message Bus.

## Add a Compat shim

A version-variant, deprecated or optional client API is called from `core/Compat.lua` only.

1. Add `function Compat.Name(...)` there: read the client global bare, at call time; ask
   `Compat.IsSecret` before comparing or matching anything the client hands back; answer a
   documented absent value (nil, false or `{}`) when the API is missing.
2. Declare the client global in `.luacheckrc` under `files["core/Compat.lua"]` (a stable world read
   in `core/CompatWorld.lua` goes under `files["core/CompatWorld.lua"]`, a character read (the realm, a name, a spec, the role) in `core/CompatClient.lua` under `files["core/CompatClient.lua"]`, an exact item read or tooltip setter in `core/CompatItem.lua` under `files["core/CompatItem.lua"]`, an Encounter Journal call in `core/CompatJournal.lua` under `files["core/CompatJournal.lua"]`, a loot history, roll, loot method, loot window or roll popup read in `core/CompatLoot.lua` under `files["core/CompatLoot.lua"]` (its fakes in `tests/wow_mock_loot.lua`), a collection read (the mount, pet and toy journals, the professions, a recipe's tooltip) in `core/CompatCollect.lua` under `files["core/CompatCollect.lua"]`), never globally, and
   add its name to `SEAM_ONLY` in `tests/test_compat.lua`.
3. Add a controllable fake to `tests/wow_mock.lua` and cases to `tests/test_compat.lua`, the API
   absent among them (a collection read: its fake in `tests/wow_mock_collect.lua` and its cases, and its name in
   `COLLECT_APIS` rather than `SEAM_ONLY`, in `tests/test_compat_collect.lua`).
4. Add the row to [`compat-layer.md`](compat-layer.md) (and its shim count), and a row to
   [`midnight-quirks.md`](midnight-quirks.md) when the shim works around a client change.

## Add a season's tier tokens

Normally there is nothing to do. A tier token is judged as the piece it makes (categories design spec
§7), and since TT-1 its slot is read from its own text (`modules/TierTokens.lua`, `SlotOf`): its Use
text's `set <slot> item ... appropriate for your class`, else a tooltip line that is exactly the slot's
name, else a slot noun in its item name (`Gauntlets of the Foreseen Conqueror`), else it is judged in
its best tier slot (`any`). An omni Curio is told by its name. The words are the enUS locale table's
(`locales/enUS.lua`, the TT-1 block; a documented localization-§4 deviation in
[`ARCHITECTURE.md`](ARCHITECTURE.md)).

To check a new season's wording:

1. In the client, for each of the season's tokens, `/dump C_Item.GetItemSpell(<itemID>)`, then
   `/dump C_Spell.GetSpellDescription(<spellID>)`, and note the text.
2. Still `appropriate for your class` with `set <slot> item`, and the slot word one of the table's
   (`head`, `shoulder` or `shoulders`, `chest`, `hand` or `hands`, `leg` or `legs`): nothing to do. Run smoke check
   `ITEM-6` to confirm.
3. New wording, or a new slot word or name noun: change the words in `locales/enUS.lua`'s TT-1 block
   (never in the code), and add a case with the season's real text to `tests/test_tier_token.lua`.

The override table, for an oddity the text misreads: `C.TIER_TOKENS` in `core/Constants.lua`, one
row per token, `[itemID] = { slot = "INVTYPE_HEAD" }` (`INVTYPE_SHOULDER`, `INVTYPE_CHEST`,
`INVTYPE_HAND`, `INVTYPE_LEGS`), or `{ slot = "any" }`, with the season and the reason in a comment.
It is the first rung and makes the item a token on its own. Never guess an id into it; record the id
in smoke check `ITEM-6`'s notes.

## Add a perf bucket

Declare `{ key = "..." }` in `core/PerfSetup.lua` and bracket the hot path with the gated form
(performance-§2). `test_setup` fails until the bracket reaches it; add an offline scenario to
`tests/perf.lua` when the path is hot.

## Add a diagnostics section

Add a `{ "name", function(out) ... end }` entry to `NS.Diagnostics.Sections()`. Read state only and
pass raw values to `out:add`. Document it in `docs/debug.md`.

## Regenerate the test inventory

```sh
lua tests/run.lua --list > docs/test-cases.md
```

Then update the README's `[tests]` badge to the new Total, in the same commit.
