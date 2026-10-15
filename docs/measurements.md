# Measurements

These are development observations from one Mac, not a performance guarantee. The final paced profile felt good to the tester. The original target of at least 120 real FPS through the slow tail **was not met**.

## Test setup

| Item | Value |
| --- | --- |
| Machine | Mac Studio, Apple M5 Max, 36 GiB unified memory |
| OS | macOS 27.0.1 |
| Runtime | Sikarugir Template 1.0.22, Wine Sikarugir 11.0_1 |
| Renderer | Bundled DXMT `v0.80-244-g7c8dee1` |
| Display | 5120 x 1440, fixed 144 Hz |
| Game | Borderless 2560 x 1440, ordinary offline Dust II play |
| Video settings | VSync off; game FPS limit disabled; FSR Quality; 2x MSAA; high textures; 16x filtering; medium shadows with all dynamic shadows; low shader and particle detail; ambient occlusion off; HDR Quality |
| Measurement | Approximately 60 seconds of per-frame Metal diagnostics per pass |

The final profile used MSync and DXMT's `d3d11.preferredMaxFrameRate=144`. The game's own FPS limit stayed disabled so only one limiter was active.

## Presentation interval results

Each column is one manual pass. Rates are derived from **Metal-reported drawable presentation intervals**. They are not counts of complete physical display scans, input-latency measurements, or a guarantee that each update was fully visible. DXMT's layer had display synchronization disabled. Unsynchronized presentation rates can exceed the panel's fixed refresh rate.

| Metric | ESync, uncapped | MSync, uncapped | MSync, renderer cap 144 |
| --- | ---: | ---: | ---: |
| Captured interval duration | 59.987 s | 59.995 s | 59.994 s |
| Presentation intervals | 8,746 | 9,960 | 8,388 |
| Mean presentation rate | 145.80/s | 166.01/s | 139.81/s |
| Median interval | 6.117 ms | 5.298 ms | 6.945 ms |
| 95th percentile interval | 10.871 ms | 10.044 ms | 6.945 ms |
| 99th percentile interval | 12.380 ms | 11.883 ms | 13.889 ms |
| Longest interval | 169.084 ms | 77.625 ms | 76.391 ms |
| Intervals over 8.333 ms | 3,111 (35.57%) | 1,781 (17.88%) | 226 (2.69%) |
| Intervals over 16.667 ms | 13 | 12 | 7 |
| Intervals over 25 ms | 3 | 5 | 3 |
| Intervals over 50 ms | 2 | 3 | 2 |

At 120 FPS, a frame budget is approximately 8.333 ms. At 144 FPS, it is approximately 6.944 ms. The capped pass concentrated most intervals near the 144 Hz period, but still contained longer gaps. Its 99th percentile was about two refresh periods. This is why a good average or median does not establish the original slow-tail target.

The pacing improvement also came with more presentation delay. In the MSync passes, mean reported wait for glass rose from about **3.57 ms uncapped to 16.45 ms capped**; mean drawable-acquisition wait rose from about **0.014 ms to 1.86 ms**. These timing components do not measure mouse-to-photon latency, but they prevent claiming that the smoother profile also minimized competitive input latency.

## Limits of this comparison

- One approximately 60-second pass per configuration, with manually played routes. Camera motion, effects, cache state, and background work were not controlled.
- The ESync pass used game build 25944058; both MSync passes used build 25947352. Two inspected engine libraries were unchanged, but the full game build changed. This is not a controlled proof that MSync caused the difference.
- The two MSync passes used the same game build and checked renderer libraries, but a process restart remains a confound. The renderer cap's exact causal benefit has not been isolated by repeated matched replays.
- Instrumentation overhead was not quantified. Per-second focus checks were true throughout each selected capture, but do not independently prove visibility of every drawable.
- The trace's `Detached` field has no verified public definition in the Apple documentation examined. It was not interpreted as a count of dropped frames or proof of visible frames.
- A percentile interval is not the same statistic as an average of the slowest 1% of frames. Earlier in-game benchmark figures used different methods and are not mixed into this table.
- Offline results do not validate protected matchmaking, voice chat, other maps, prolonged sessions, or other Macs.
- These are measurements of the development runtime, not an end-to-end test of this public installer. Installer tests use synthetic fixtures. Real fresh prefix creation, Steam installation and sign-in, game download, and play have not been validated together for this release.

## Reproducing a useful comparison

Record the hardware, OS, display refresh, game build, runtime pins, settings, and exact limiter in use. Warm the same route, then compare repeated matched passes with one change at a time. Preserve caches between repeated runs. Report interval distributions and long-gap counts alongside averages, and record latency-related timing when adding a limiter.

Apple documents the relevant [HUD metrics](https://developer.apple.com/documentation/xcode/understanding-metal-performance-hud-metrics) and [diagnostic logging](https://developer.apple.com/documentation/xcode/monitoring-your-metal-apps-graphics-performance). The macOS 27 `metalperftrace` tool can collect recorded metrics; detailed per-frame capture is a separate diagnostic option. Diagnostics should be opt-in and disabled after collection.

This public report contains sanitized aggregates only. Raw traces and logs can contain local paths, process information, account identifiers, and session details. Do not attach them publicly without reviewing and redacting them first.
