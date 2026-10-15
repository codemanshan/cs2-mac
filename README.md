# CS2 for Mac

A free, experimental setup for playing the **Windows version of Counter-Strike 2 on Apple silicon Macs**, with a simple Mac launcher.

It builds a separate Sikarugir Wine runtime, uses its matched DXMT renderer, and installs your own Windows Steam. No CrossOver subscription is needed. Your existing Mac Steam installation stays separate.

**[Download the installer](https://github.com/codemanshan/cs2-mac/releases/download/v0.1.0/CS2-Mac.zip)** · [Help](https://github.com/codemanshan/cs2-mac/issues) · [Measured results](docs/measurements.md)

> Early release: the configuration was played on one M5 Max Mac, while this installer has been tested with isolated fixtures. A fresh installation on another Mac has not yet been validated. Performance varies, and rare hitches remain in the measured setup. No 120 FPS floor, low-latency result, or protected-matchmaking guarantee is claimed.

## Install

You need an **Apple silicon Mac, macOS 14.6 or newer, Rosetta 2, and roughly 100 GB free**. An external SSD can hold the game; the runtime stays on your Mac.

1. Download and unzip the installer. Open **Install CS2.command**.
2. Choose the game folder and a graphics profile. Finish the Windows Steam installer, review its terms, and sign in to **your own account**.
3. In that Windows Steam, add **V:\\** in **Settings → Storage** and install CS2 there. V: points to the folder you chose.
4. Open **CS2 → Properties → General → Launch Options** in Windows Steam. Paste the options copied by the installer.
5. Open **CS2** in your user **Applications** folder. Drag it into the Dock for easy access.

The one-time launch options are:

| Profile | Windows Steam Launch Options |
| --- | --- |
| Balanced, 1080p | `-windowed -noborder -w 1920 -h 1080 +exec cs2mac.cfg` |
| Quality, 1440p | `-windowed -noborder -w 2560 -h 1440 +exec cs2mac.cfg` |

CS2 creates its video settings on first launch. Quit the game normally and open the CS2 launcher again to apply the remaining graphics preset to that new file. Resolution and renderer pacing are configured for the first launch. If a game update changes the video-file format, the toolkit preserves it; use CS2's Video menu in that case.

If Rosetta is missing, install it through Apple's normal flow and review its license yourself. If macOS blocks the downloaded script or upstream wrapper, review the source and use macOS's **Open Anyway** flow in **System Settings → Privacy & Security**. This kit does not remove quarantine or disable Gatekeeper. See [compatibility](docs/compatibility.md).

If setup was interrupted before completion, rerun it with `--resume` using the same library, profile and refresh options. It resumes only a pending runtime created by this toolkit; existing completed installs are preserved. Use `steam-install` if only the Steam installer needs to be reopened.

## Play

Open **CS2.app**. It opens this kit's Windows Steam and asks it to start CS2. If Steam is already open in the same runtime, the launcher reuses it. If CS2 is already running, it leaves that session alone.

Start with an offline practice game. Protected matchmaking has not been validated by this project. **FACEIT Anti-cheat is unsupported.** This is an unofficial compatibility setup; [compatibility and anti-cheat details](docs/compatibility.md) explain the limits.

## Settings

Both profiles use **DXMT, MSync only, VSync off, FSR Quality, and one renderer-controlled FPS cap**. The game's `fps_max` is set to `0`. The cap follows the current main display's detected refresh rate; an unknown or variable rate leaves it uncapped. The toolkit does not change macOS display settings. Keep the game on that display, and set the display's desired refresh rate in macOS before installing.

| Setting | Balanced 1080p | Quality 1440p |
| --- | --- | --- |
| Output | 1920 × 1080 | 2560 × 1440 |
| Textures | Medium | High |
| MSAA | Off | 2× |
| Texture filtering | 16× | 16× |
| Shadows | Medium, all dynamic | Medium, all dynamic |
| Shaders / particles | Low | Low |
| Ambient occlusion | Off | Off |
| HDR | Quality | Quality |

Balanced is the conservative default. Macs with a Max/Ultra chip and at least 24 GiB memory are offered Quality by default; this is a starting recommendation, not a benchmark. The launcher applies its preset once when CS2's video file is available, backing up the original as `cs2_video.txt.cs2mac-original`. Later quality changes you make in CS2 are preserved; the explicit resolution in Steam Launch Options still applies.

Renderer pacing made delivery much steadier on the measured Mac, but also increased queued presentation time. **Smoother does not establish lower input latency.** See the [full measurements and limitations](docs/measurements.md).

## Commands and help

Run these from the downloaded folder:

```sh
./bin/cs2-mac setup --library "$HOME/Games/CS2-Mac Library"
./bin/cs2-mac setup --library "$HOME/Games/CS2-Mac Library" --dry-run
./bin/cs2-mac play
./bin/cs2-mac options
./bin/cs2-mac doctor
./bin/cs2-mac steam-install
./bin/cs2-mac stop
```

Setup also accepts `--profile balanced1080|quality1440`, `--refresh-hz auto|0..360`, and `--no-steam-install`. Use the actual display refresh rate when overriding it. A cap of `0` disables renderer pacing. `stop` requests normal closure, then stops only this kit's Wine prefix if it remains active after 15 seconds.

The installed CLI also lives at:

```sh
"$HOME/Library/Application Support/CS2Mac/toolkit/bin/cs2-mac" doctor
```

Doctor checks installation files and reports missing components. It does not inspect authentication files, upload diagnostics, or benchmark the game. If you file an issue, describe your Mac, OS, display and symptoms. Review logs before sharing them; do not post account or session information.

## Remove or undo

1. Quit CS2 and run `./bin/cs2-mac stop`.
2. Move **~/Applications/CS2.app** and **~/Library/Application Support/CS2Mac** to the Trash. This deletes the kit's Windows Steam and its local sign-in state.
3. Keep or remove the separate game library you selected. It is never removed automatically. The toolkit's only game-root config is `game/csgo/cfg/cs2mac.cfg`.

If you want the original graphics file, stop the runtime first and restore `cs2_video.txt.cs2mac-original`. The adjacent `cs2_video.txt.cs2mac-profile` marker prevents the preset being applied again. For a different renderer cap or a new toolkit setup, preserve or move the existing installation first; this initial release deliberately refuses to overwrite it.

## Source, downloads and tests

This repository and its release ZIP contain **our scripts and documentation only**. Runtime archives and Valve's installer are downloaded separately from their official projects, checked against pinned SHA-256 hashes, and retain their own licenses. A changed download fails verification rather than silently substituting a new build. See [sources and licenses](docs/sources.md) and [runtime-artifacts.json](runtime-artifacts.json).

The kit does not copy anyone's Wine prefix, account files, Steam library, DRM files or game binaries. It makes no game-executable or anti-cheat patches, installs no kernel extension, and requires no global security changes.

The source checkout includes tests using temporary synthetic runtimes and mocked process boundaries. They exercise installation recovery, archive validation, launch isolation and failure paths without launching Wine or Steam:

```sh
for test in tests/test_*.sh; do /bin/bash "$test"; done
```

Original code is [MIT licensed](LICENSE). Downloaded Wine/DXMT, Sikarugir components, Steam and CS2 have separate terms. This project is not affiliated with Valve, Apple, Sikarugir or DXMT.
