# CS2 for Mac

A free installer and simple app launcher for playing the **Windows version of Counter-Strike 2 on Apple silicon Macs**. No CrossOver purchase needed.

**[Download CS2-Mac.zip](https://github.com/codemanshan/cs2-mac/releases/download/v0.1.1/CS2-Mac.zip)** · [Get help](https://github.com/codemanshan/cs2-mac/issues)

## What you need

- **An Apple silicon Mac** (M1 or newer). Intel Macs are not supported by this kit.
- **macOS 14.6 or newer** and [Rosetta 2](https://support.apple.com/en-us/102527).
- **About 100 GB free**, an internet connection, and your own Steam account.
- An external SSD is fine for the game. The launcher and Windows runtime stay on your Mac.

**Before starting:** set your main display to its desired refresh rate in **macOS System Settings → Displays**. The installer saves that rate as the FPS cap.

## Install

1. **Download and unzip** the ZIP above, then open **Install CS2.command**.
2. **Choose where to store the game** and pick a graphics profile. If unsure, choose **Balanced — 1080p**.
3. Click **Copy Launch Options** when the Mac setup finishes, then **finish installing Windows Steam** and sign in.
4. In **Windows Steam → Settings → Storage**, add **`V:\`** as a game library. This is the game folder you chose in step 2. Install **Counter-Strike 2** there.
5. In **Windows Steam → Library**, right-click **Counter-Strike 2 → Properties → General**. Paste the copied text into **Launch Options**. [Lost the copied text?](docs/setup.md#launch-options)
6. **Open CS2.app** in your home folder's **Applications** folder. Start the game once, quit normally, then reopen CS2.app to finish applying the graphics preset.

Can't find the launcher? In Finder, choose **Go → Go to Folder**, enter `~/Applications`, and open **CS2**. Drag it into the Dock for next time.

If macOS blocks opening a download, see [setup help](docs/setup.md#macos-blocked-a-download). Setup never disables Gatekeeper or removes quarantine.

## Play next time

**Open CS2 from your Dock or `~/Applications`.** It starts this kit's Windows Steam and launches the game. If Steam shows its library instead, press **Play** on Counter-Strike 2.

Keep your external SSD connected if that's where you installed the game. Your native Mac Steam app stays separate.

## Which graphics profile?

| Profile | Start here if… |
| --- | --- |
| **Balanced — 1080p** | You want a conservative starting point for most Macs. |
| **Quality — 1440p** | You have a more powerful Mac and want a sharper picture. This is the profile used on the tested M5 Max. |

The installer saves a matching FPS cap at setup. It does not change the display's refresh rate or automatically follow later display changes. [Full settings](docs/setup.md#graphics-settings)

## What has been tested?

| Check | Status |
| --- | --- |
| Gameplay | The maintainer reports smooth 1440p gameplay on an **M5 Max Mac Studio with 36 GB memory**. |
| Online matchmaking | **Reported working by the maintainer on that same setup.** Specific modes were not recorded. |
| Fresh installation on another Mac | **Needs community testing.** Installer checks use isolated test fixtures. |

This is an **experimental, unofficial setup**, not a native Mac release. Performance varies; occasional hitches remain in the measurements, and no fixed FPS or input-latency result is promised. **FACEIT Anti-cheat is unsupported.** [Compatibility details](docs/compatibility.md) · [Measured results](docs/measurements.md)

## Help and credits

- **[Setup help, launch options, settings and removal](docs/setup.md)**
- **[Report a problem or share your Mac's results](https://github.com/codemanshan/cs2-mac/issues)** — include your Mac model, memory, macOS version, and what happened. Keep account details out of screenshots and logs.
- **[Runtime sources and licenses](docs/sources.md)**

Built on **[Sikarugir](https://github.com/Sikarugir-App/Sikarugir), [Wine](https://www.winehq.org/), and [DXMT](https://github.com/3Shain/dxmt)**. Those projects make the Windows game work on macOS; this kit provides setup scripts, graphics presets, and a launcher.

The download contains this project's scripts and instructions. Runtime files come from verified official downloads, and you install Steam and CS2 from Valve using your own account. The kit makes no game-executable or anti-cheat patches.

Original code is [MIT licensed](LICENSE); downloaded components have their own terms. This project is not affiliated with Valve, Apple, Sikarugir or DXMT.
