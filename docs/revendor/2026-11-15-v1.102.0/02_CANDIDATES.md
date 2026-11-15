# 02 — Candidates: LibKa0s v1.95.0 -> v1.102.0

Sources: `git -C ../LibKa0s log --oneline v1.95.0..v1.102.0` (78 commits), the CHANGELOG blocks v1.96.0
to v1.102.0 at the tag, and the `docs/api/` documents of every major whose minor moved. The 3g read
found no blocker, so every item below is optional.

## Class A: reached the addon on the re-vendor alone (delivered, not offered)
- OptionsWidgets minor 46 (CHANGELOG v1.101.0, *A slider's box takes no junk*): a number row's slider
  box puts junk text back on Enter and on focus loss. Every slider on the settings pages gets it.
  "What a consumer owes: nothing."
- Media minor 13 (CHANGELOG v1.97.0, *The faces*; `docs/api/Media/version-13.1-docs.md`): Ka0s Bebas
  Neue and Ka0s Russo One join `FONTS`, so any face list fed from the library's registered fonts
  offers them. SkinDefsOthers minor 9 sizes both.
- DebugLogDiagnostics minors 9 and 10: the diagnostics report's `LibKa0s running:` line names the
  two new majors. No member change.
- Test kit revisions 55 and 56: `vendor_sync.lua` gates the `LibKa0s sounds:` line (none here, so no
  voice pack ships) and `glyphs.lua`'s face list gains the two faces.

## Class B: host change required
1. **`O.SideTabs(ctx, spec)`** (OptionsNav minor 7; CHANGELOG v1.100.0, *The one tab*;
   `docs/api/Options/version-38.5.45.3.7.2.9.17.3.1.4.19.13.7.5.8.7.11.1.1.4-docs.md`): a nav-rail
   look inside a page's content, a list on the left and the selected entry's body on the right.
   Would touch `settings/` page builders. Additive. Recommendation: not now; no Drop Watcher page has
   sub-sections that want a side list today. The stub member is already in `settings/OptionsSetup.lua`.

## Class C: whole-module adoption
2. **`LibKa0s-Callout-1.0`** (Callout 4, CalloutSettings 5; CHANGELOG v1.96.0 to v1.102.0;
   `docs/api/Callout/version-4.5-docs.md`): large on-screen call-outs with countdowns, voice packs and
   text to speech, built for Ka0s Combat Trail. Additive, with a new settings tab and a
   `LibKa0s sounds:` declaration. Recommendation: never, unless a feature wants a spoken or large
   on-screen cue (a roll about to expire is the nearest fit, and the owner has not asked for one).
3. **`LibKa0s-WaypointArrow-1.0`** (WaypointArrow 2, WaypointArrowSettings 2; CHANGELOG v1.99.0 and
   v1.101.0; `docs/api/WaypointArrow/version-2.2-docs.md`): a rotating arrow to a map point, built
   for Skill Master. Additive. Recommendation: never; Drop Watcher points at no place in the world.

`gh issue list --search "LibKa0s"` was not run: the owner's ruling for this run is that no issue is
filed, so these three stay listed here for the owner.
