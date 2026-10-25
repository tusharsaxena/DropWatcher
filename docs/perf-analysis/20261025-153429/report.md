# Report — 20261025-153429

What the client printed for the capture labelled `2026-10-25 15:30`, copied from the debug-log
window. The `HH:MM:SS | [Tag]` prefixes are kept: they are the capture's timestamps.

## The report

The `/dw perf` report, from `capture:` through the bucket table. There is no `(buckets nest: …)`
footer: the one bucket noted, `tradeTimer.scan`, declares no parent, and the library prints the
footer only when a nested bucket is present.

```text
15:34:29 | [Perf] capture: 2026-10-25 15:30  (DropWatcher, schema 2, v1.0.0)
15:34:29 | [Perf] who:       Sacrìlege-Frostmourne, level 90 Protection Paladin
15:34:29 | [Perf] where:     Murder Row
15:34:29 | [Perf] group:     party (5) / party
15:34:29 | [Perf] active:       62.0s    3353 frames    54.1 fps   18.50 ms/frame
15:34:29 | [Perf] suspended:    69.3s    3656 frames    52.7 fps   18.97 ms/frame
15:34:29 | [Perf] delta:                                                   -0.47 ms/frame
15:34:29 | [Perf] 
15:34:29 | [Perf] bucket            calls   total ms       ms/s    max ms
15:34:29 | [Perf] tradeTimer.scan        1       0.02      0.000     0.015
```

## The dump

The record, as the client printed it with its prefix. The bare JSON is [`dump.json`](dump.json).

```text
15:34:29 | [Perf] {"addon":"DropWatcher","buckets":{"tradeTimer.scan":{"calls":1,"maxMs":0.0154,"totalMs":0.0154}},"context":{"character":"Sacrìlege","class":"Paladin","group":"party (5) / party","level":90,"realm":"Frostmourne","spec":"Protection","subZone":"","zone":"Murder Row"},"fps":{"active":{"avgFps":54.0667,"frames":3353,"msPerFrame":18.4957,"seconds":62.0160},"deltaMsPerFrame":-0.4712,"suspended":{"avgFps":52.7234,"frames":3656,"msPerFrame":18.9669,"seconds":69.3430}},"interface":120105,"label":"2026-10-25 15:30","schema":2,"source":"ingame","timestamp":1792922669,"version":"1.0.0"}
```

## Run log

The run's lifecycle lines, in the order the client printed them. The paste carried no other tags.

```text
15:30:19 | [Perf] run started — 2026-10-25 15:30
15:30:19 | [Perf] who:       Sacrìlege-Frostmourne, level 90 Protection Paladin
15:30:19 | [Perf] where:     Murder Row
15:30:19 | [Perf] group:     party (5) / party
15:30:19 | [Perf] perf run STARTED — 2026-10-25 15:30
15:30:22 | [Perf] experiment A armed (addon active) — waiting for combat
15:30:39 | [Perf] Experiment A RECORDING — combat started
15:31:41 | [Perf] Experiment A ENDED — 62.0s, 3353 frames, 54.1 fps
15:33:08 | [Perf] addon SUSPENDED — inert
15:33:08 | [Perf] experiment B armed (addon SUSPENDED) — waiting for combat
15:33:15 | [Perf] Experiment B RECORDING — combat started
15:34:24 | [Perf] Experiment B ENDED — 69.3s, 3656 frames, 52.7 fps
15:34:28 | [Perf] run finished — A 62.0s / 3353 frames, B 69.3s / 3656 frames
15:34:28 | [Perf] addon RESUMED — events and frames restored
15:34:28 | [Perf] perf run FINISHED — saved; `Report` or `Dump` in the panel to read it, `/reload` to flush it to SavedVariables
```
