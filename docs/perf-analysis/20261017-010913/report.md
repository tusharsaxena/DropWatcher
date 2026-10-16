# Report — 20261017-010913

What the client printed for the capture labelled `2026-10-17 01:04`, copied from the debug-log
window. The `HH:MM:SS | [Tag]` prefixes are kept: they are the capture's timestamps.

## The report

The `/dw perf` report, from `capture:` through the bucket table. The table has a header and no
rows, and there is no `(buckets nest: …)` footer: no bucket was noted during either recording
window (the dump's `buckets` is `{}`), and the library prints the footer only when a nested bucket
is present.

```text
01:09:13 | [Perf] capture: 2026-10-17 01:04  (DropWatcher, schema 2, v0.1.0)
01:09:13 | [Perf] who:       Sacrìlege-Frostmourne, level 90 Protection Paladin
01:09:13 | [Perf] where:     Murder Row
01:09:13 | [Perf] group:     party (5) / party
01:09:13 | [Perf] active:       19.1s    1357 frames    71.2 fps   14.04 ms/frame
01:09:13 | [Perf] suspended:    15.0s     913 frames    61.0 fps   16.39 ms/frame
01:09:13 | [Perf] delta:                                                   -2.35 ms/frame
01:09:13 | [Perf] 
01:09:13 | [Perf] bucket            calls   total ms       ms/s    max ms
```

## The dump

The record, as the client printed it with its prefix. The bare JSON is [`dump.json`](dump.json).

```text
01:09:13 | [Perf] {"addon":"DropWatcher","buckets":{},"context":{"character":"Sacrìlege","class":"Paladin","group":"party (5) / party","level":90,"realm":"Frostmourne","spec":"Protection","subZone":"","zone":"Murder Row"},"fps":{"active":{"avgFps":71.2299,"frames":1357,"msPerFrame":14.0391,"seconds":19.0510},"deltaMsPerFrame":-2.3531,"suspended":{"avgFps":61.0049,"frames":913,"msPerFrame":16.3921,"seconds":14.9660}},"interface":120105,"label":"2026-10-17 01:04","schema":2,"source":"ingame","timestamp":1792179553,"version":"0.1.0"}
```

## Run log

The run's lifecycle lines, in the order the client printed them. The paste carried no other tags.

```text
01:04:31 | [Perf] run started — 2026-10-17 01:04
01:04:31 | [Perf] who:       Sacrìlege-Frostmourne, level 90 Protection Paladin
01:04:31 | [Perf] where:     Murder Row
01:04:31 | [Perf] group:     party (5) / party
01:04:31 | [Perf] perf run STARTED — 2026-10-17 01:04
01:04:37 | [Perf] experiment A armed (addon active) — waiting for combat
01:04:49 | [Perf] Experiment A RECORDING — combat started
01:05:08 | [Perf] Experiment A ENDED — 19.1s, 1357 frames, 71.2 fps
01:08:45 | [Perf] addon SUSPENDED — inert
01:08:45 | [Perf] experiment B armed (addon SUSPENDED) — waiting for combat
01:08:54 | [Perf] Experiment B RECORDING — combat started
01:09:09 | [Perf] Experiment B ENDED — 15.0s, 913 frames, 61.0 fps
01:09:13 | [Perf] run finished — A 19.1s / 1357 frames, B 15.0s / 913 frames
01:09:13 | [Perf] addon RESUMED — events and frames restored
01:09:13 | [Perf] perf run FINISHED — saved; `Report` or `Dump` in the panel to read it, `/reload` to flush it to SavedVariables
```
