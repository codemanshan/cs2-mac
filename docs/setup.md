# Setup help and settings

[Back to the simple install guide](../README.md)

## Launch options

The installer offers a **Copy Launch Options** button at the end of setup. If you missed it or copied something else afterward, use the line for the profile you chose:

| Your profile | Copy this whole line |
| --- | --- |
| Balanced — 1080p | `-windowed -noborder -w 1920 -h 1080 +exec cs2mac.cfg` |
| Quality — 1440p | `-windowed -noborder -w 2560 -h 1440 +exec cs2mac.cfg` |

In **Windows Steam → Library**, right-click **Counter-Strike 2 → Properties → General** and paste it into **Launch Options**. You only need to do this once.

## Finding the game folder in Windows Steam

The installer creates **CS2-Mac Library** inside the folder you selected. Windows Steam sees that library as **`V:\`**.

Open **Windows Steam → Settings → Storage → Add Drive**. If V: is not listed, choose the option to select another location and browse to **My Computer → V:**. Add that location, then install CS2 there. Steam's button wording may vary by client version.

For a command-line setup, V: points directly to the path supplied with `--library`.

## Finding the launcher

The launcher is in your **user Applications folder**, which is separate from the main Applications folder.

In Finder, choose **Go → Go to Folder**, enter `~/Applications`, then open **CS2.app**. Drag it into the Dock for daily use. If Windows Steam opens to its library, press **Play** on Counter-Strike 2.

## First launch and graphics

**Start CS2 once, quit it normally, then reopen it with CS2.app.** The game creates its video-settings file on the first launch; the launcher applies the remaining preset on the next launch. Resolution and renderer pacing are configured for the first launch.

The preset is applied once. Later quality changes you make in CS2 are preserved, while the resolution in Steam's Launch Options still applies. If a game update changes the video-file format, the toolkit keeps the existing file and asks you to use CS2's Video menu.

### Graphics settings

Both profiles use **DXMT, MSync only, FSR Quality, VSync off, and one renderer-controlled FPS cap**. The game's own `fps_max` is set to `0`.

| Setting | Balanced — 1080p | Quality — 1440p |
| --- | --- | --- |
| Output | 1920 × 1080 | 2560 × 1440 |
| Textures | Medium | High |
| MSAA | Off | 2× |
| Texture filtering | 16× | 16× |
| Shadows | Medium, all dynamic | Medium, all dynamic |
| Shaders / particles | Low | Low |
| Ambient occlusion | Off | Off |
| HDR | Quality | Quality |

Balanced is the conservative default. Macs with a Max/Ultra chip and at least 24 GiB memory are offered Quality by default. This is a starting suggestion, not a measured performance rating for every Mac.

### Display refresh and FPS cap

Before setup, select the refresh rate you want in **macOS System Settings → Displays** and make the gaming display your main display. For example, select 144 Hz there if that is the mode you want to use.

The installer reads the main display's current refresh rate and **saves that number** as the renderer cap. An unknown or variable rate leaves it uncapped. It does not change macOS display settings, detect the display's maximum supported rate, or update the saved cap when you switch displays later.

The CLI accepts `--refresh-hz auto|0..360` during setup; use the actual display refresh rate if overriding detection. `0` disables renderer pacing. This release does not provide an in-place settings updater: preserve or move an existing installation before setting up a different cap or profile. Do not reinstall just to obtain the v0.1.1 documentation update.

Renderer pacing made presentation intervals steadier on the measured M5 Max, but increased queued presentation time. Smoother delivery does not establish lower input latency or a minimum FPS. [See the measurements](measurements.md).

## macOS blocked a download

Review what you downloaded and its source. Use macOS's normal **Open Anyway** flow in **System Settings → Privacy & Security** if you choose to allow it. An upstream runtime component may also require approval.

The toolkit does not remove quarantine, re-sign downloaded executables, or disable Gatekeeper. See [compatibility and signatures](compatibility.md#security-and-signatures) for details.

## Rosetta is missing

Follow [Apple's Rosetta installation instructions](https://support.apple.com/en-us/102527), review Apple's terms, then run setup again. The toolkit does not install Rosetta or accept its license automatically.

## Setup stopped or Steam didn't finish installing

Read the error in the Terminal window first. From Terminal in the downloaded **CS2-Mac** folder, use:

```sh
./bin/cs2-mac setup --resume
```

This resumes only an incomplete runtime created by this kit, with its saved library, profile and cap. Close that runtime before resuming. It does not overwrite completed setups. If Steam's installer was the only unfinished step, use:

```sh
./bin/cs2-mac steam-install
```

For missing files or a launcher error, run:

```sh
./bin/cs2-mac doctor
```

Doctor checks installation files and prints the saved profile, cap and launch options. It does not read authentication files, upload diagnostics or benchmark the game. If your external game drive is missing, reconnect it before launching.

If you're still stuck, [open an issue](https://github.com/codemanshan/cs2-mac/issues) with your Mac model, memory, macOS version, display refresh and the error text. Review logs before sharing them; keep account and session information private.

## Command-line reference

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

Setup accepts `--profile balanced1080|quality1440`, `--refresh-hz auto|0..360`, `--no-steam-install` and `--resume`. `stop` requests normal closure, then stops only this kit's Wine prefix if it remains active after 15 seconds.

After installation, the CLI is also available at:

```sh
"$HOME/Library/Application Support/CS2Mac/toolkit/bin/cs2-mac" doctor
```

## Remove or undo

1. Quit CS2 and run `./bin/cs2-mac stop` from the downloaded folder.
2. Move **`~/Applications/CS2.app`** and **`~/Library/Application Support/CS2Mac`** to the Trash. This removes the kit's Windows Steam and its local sign-in state. Native Mac Steam stays separate.
3. Keep or remove the game library you selected. It is never removed automatically. The kit's game-root config is `game/csgo/cfg/cs2mac.cfg`; remove it if you no longer want that config, and clear its entry from Steam Launch Options if keeping the Windows Steam install.

The original video file is backed up beside `cs2_video.txt` as **`cs2_video.txt.cs2mac-original`**, inside this kit's Windows Steam userdata folder. To restore it, stop the runtime first and copy that backup over `cs2_video.txt`. Leave the adjacent **`cs2_video.txt.cs2mac-profile`** marker in place so the preset is not applied again.

## For contributors

The source checkout includes tests with temporary synthetic runtimes and mocked process boundaries. They cover installation recovery, archive validation, launch isolation and failure paths without opening Wine or Steam:

```sh
for test in tests/test_*.sh; do /bin/bash "$test"; done
```

[Runtime pins and licenses](sources.md) · [Compatibility](compatibility.md) · [Measurements](measurements.md)
