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
   `lua tests/run.lua`: `test_schema` and `test_schema_rows` validate the row against the defaults.

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
`tests/test_disabled.lua` (one entry per receiver), or `test_disabled` 1 fails.

## Add a Compat shim

A version-variant, deprecated or optional client API is called from `core/Compat.lua` only.

1. Add `function Compat.Name(...)` there: read the client global bare, at call time; ask
   `Compat.IsSecret` before comparing or matching anything the client hands back; answer a
   documented absent value (nil, false or `{}`) when the API is missing.
2. Declare the client global in `.luacheckrc` under `files["core/Compat.lua"]` (a stable world read
   in `core/CompatWorld.lua` goes under `files["core/CompatWorld.lua"]`, an exact item read or tooltip setter in `core/CompatItem.lua` under `files["core/CompatItem.lua"]`, an Encounter Journal call in `core/CompatJournal.lua` under `files["core/CompatJournal.lua"]`, a collection read (the mount, pet and toy journals, the professions, a recipe's tooltip) in `core/CompatCollect.lua` under `files["core/CompatCollect.lua"]`), never globally, and
   add its name to `SEAM_ONLY` in `tests/test_compat.lua`.
3. Add a controllable fake to `tests/wow_mock.lua` and cases to `tests/test_compat.lua`, the API
   absent among them (a collection read: its fake in `tests/wow_mock_collect.lua` and its cases, and its name in
   `COLLECT_APIS` rather than `SEAM_ONLY`, in `tests/test_compat_collect.lua`).
4. Add the row to [`compat-layer.md`](compat-layer.md) (and its shim count), and a row to
   [`midnight-quirks.md`](midnight-quirks.md) when the shim works around a client change.

## Add a season's tier tokens

A tier token is judged as the piece it makes (categories design spec §7). The slot comes from the
curated `C.TIER_TOKENS` in `core/Constants.lua` first, then from the token's tooltip: a line that is
exactly the slot's name, else its `Use: Create|Synthesize a soulbound ... set <slot> item appropriate
for your class.` line (TT-1). A token whose enUS tooltip carries that line needs no row; list the
ones it does not (a Curio, another locale).

1. In the client, read each of the season's tokens with `/dump C_Item.GetItemInfo(<itemID>)` and its
   tooltip (`/dump C_TooltipInfo.GetItemByID(<itemID>)`): note the slot it makes and whether it
   names classes (an omni Curio names none).
2. Add one row per token, `[itemID] = { slot = "INVTYPE_HEAD" }` (`INVTYPE_SHOULDER`,
   `INVTYPE_CHEST`, `INVTYPE_HAND`, `INVTYPE_LEGS`), or `{ slot = "any" }` for a Curio, with the
   season in a comment. Never guess an id into the table.
3. Add the ids to smoke check `ITEM-6`'s record in [`smoke-tests.md`](smoke-tests.md).

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
