# Common tasks — Ka0s Drop Watcher

## Add a setting

1. Add its default to `defaults/Profile.lua` (`NS.C.PROFILE`).
2. Declare the row in `settings/SchemaRows.lua` with `path`, `type`, `default` (from `NS.C`, never a
   literal), `page`, `group` (its tab), `label`, `tooltip` and a `validate` check; the file splices
   every row in with `NS.SchemaRuntime.AddRows`. A row that only matters when another is on takes a
   `disabledIf` predicate.
3. Add every new `label` and `tooltip` string to `locales/enUS_Settings.lua` (the settings panel's
   strings, peeled out of `locales/enUS.lua` at the 1500-line cap); `test_locale` fails on any string
   routed through `NS.L` that has no entry in either.
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
comment. Receivers take their own target, `NS.Bus:NewTarget()`, and use `NS.MSG.KEY`, never the
literal.

## Add a Compat shim

A version-variant, deprecated or optional client API is called from `core/Compat.lua` only.

1. Add `function Compat.Name(...)` there: read the client global bare, at call time; ask
   `Compat.IsSecret` before comparing or matching anything the client hands back; answer a
   documented absent value (nil, false or `{}`) when the API is missing.
2. Declare the client global in `.luacheckrc` under `files["core/Compat.lua"]` (a stable world read
   in `core/CompatWorld.lua` goes under `files["core/CompatWorld.lua"]`), never globally, and
   add its name to `SEAM_ONLY` in `tests/test_compat.lua`.
3. Add a controllable fake to `tests/wow_mock.lua` and cases to `tests/test_compat.lua`, the API
   absent among them.
4. Add the row to [`compat-layer.md`](compat-layer.md) (and its shim count), and a row to
   [`midnight-quirks.md`](midnight-quirks.md) when the shim works around a client change.

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
