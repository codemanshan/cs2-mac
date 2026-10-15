# Compatibility

This is an experimental way to run the Windows version of Counter-Strike 2 on an Apple silicon Mac. It uses a separate Windows Steam installation, Sikarugir Wine, and DXMT. It is not an official Mac release or a Valve-supported compatibility layer.

## Requirements

- An Apple silicon Mac with Rosetta 2 installed. The pinned launcher is an Intel `x86_64` executable. Apple provides [Rosetta installation instructions](https://support.apple.com/en-us/102527).
- macOS 14.6 or later is the [upstream wrapper's minimum](https://github.com/Sikarugir-App/Sikarugir#readme), also recorded in Template 1.0.22's `LSMinimumSystemVersion`. DXMT's [system requirements](https://github.com/3Shain/dxmt/wiki/Device-System-Runtime-Specifications) permit macOS 14 and recommend macOS 15. The measurements in this repository cover one Mac on macOS 27.0.1, not every supported OS or chip.
- An internet connection, a Steam account, and room for the Windows game, prefix, downloads, and temporary extraction. Valve currently lists **85 GB for the game alone** in its [system requirements](https://store.steampowered.com/app/730/).
- A display refresh rate appropriate for the selected profile. A 144 FPS profile does not turn a 60 Hz display into a 144 Hz display.

Rosetta availability and future macOS compatibility are controlled by Apple. This kit does not install Rosetta silently or accept Apple's terms on the user's behalf.

## What has been tested

The measured setup used Template 1.0.22, Wine Sikarugir 11.0_1, and the template's matched DXMT `v0.80-244-g7c8dee1`. It ran ordinary offline Dust II gameplay on a Mac Studio with M5 Max and 36 GiB memory, on macOS 27.0.1, at 2560 x 1440 on a fixed 144 Hz display. See [measurements](measurements.md) for results and limits.

The final profile felt good to the tester. It **did not meet the original requirement of staying at or above 120 FPS through the slow tail**. No minimum FPS or latency is guaranteed on this or another Mac.

**Online matchmaking is reported working by the maintainer on the same M5 Max development setup.** This is a user report, separate from the offline timing captures. The specific matchmaking mode, server details and session duration were not recorded; it does not establish that every mode or future game build works. Voice chat, every map, and a clean end-to-end installation on other Macs still need separate validation.

The measurements came from the development runtime. Installer tests use synthetic fixtures; a complete new installation through prefix creation, the real Steam installer, sign-in, game download, and play has not been verified end to end for this release.

## Steam and anti-cheat

Valve's [CS2 store page](https://store.steampowered.com/app/730/) lists Windows and SteamOS/Linux requirements; it does not list macOS. This project does not claim Valve certification for Wine, Sikarugir, or DXMT.

The installer and launcher must leave the native Mac Steam app alone. Users sign in to their own separate Windows Steam installation and obtain CS2 from Valve. The project does not distribute Steam account data, session files, game files, or modified game executables. It does not provide a DRM or anti-cheat bypass.

Valve's [VAC policy](https://help.steampowered.com/en/faqs/view/571A-97DA-70E9-FF74) describes bans for cheats and modifications designed to give an advantage. The working matchmaking report above is not Valve certification or a ban-safety guarantee. If Steam or the game refuses a protected session, stop and use official support; do not patch checks to enter it.

**FACEIT Anti-cheat is unsupported.** FACEIT says it includes a Windows kernel driver and has no Mac or Linux version. This Wine setup cannot meet that requirement. See [FACEIT's explanation](https://support.faceit.com/hc/en-us/articles/9394666828188-What-is-FACEIT-Anti-cheat-and-how-does-it-work).

## Security and signatures

The kit fetches pinned upstream archives and verifies their SHA-256 hashes. A matching hash verifies the selected artifact, not an endorsement by Apple or Valve. Download locations and licenses are in [sources](sources.md).

The installer must not disable Gatekeeper, change global security policy, remove quarantine attributes, or alter an existing user's wrapper. It must not use the Sikarugir Creator Homebrew cask as an unattended shortcut: that cask currently removes quarantine and signs the Creator app in its post-install step. If macOS blocks execution, the kit should report the block and leave approval to the user through macOS.

The inspected Template 1.0.22 launcher has an upstream ad hoc signature with its plist unbound and no resource seal. Changing wrapper metadata does not by itself require replacing that executable's signature. The kit preserves the downloaded executables and their existing signatures and entitlements; it does not need a blanket re-signing pass. A future change to Mach-O code, library load paths, or signed resources needs a new, explicit signing review. Do not strip entitlements or disable the hardened runtime as a generic repair.

## Renderer and pacing limits

Keep the template's DXMT and Wine components together. An unrelated DXMT release can require a different Wine Metal-view interface. The [Wine 11 compatibility discussion](https://github.com/3Shain/dxmt/issues/170) identifies [ExtEscape support](https://github.com/3Shain/dxmt/pull/166) as the intended interface.

The pinned DXMT supports `d3d11.preferredMaxFrameRate`. It is a Metal presentation-duration request, not a guarantee that frames finish on time. At a fixed 144 Hz, the measured profile requested 144 and left the game's VSync off. This DXMT build keeps `CAMetalLayer.displaySyncEnabled` false, so the cap does not promise tear-free output or low input latency.

Use a refresh-matched profile and measure it on the actual display. Do not enable frame interpolation to claim that the game reached a real rendering target. The pinned renderer does not implement `dxgi.maxFrameLatency` or `d3d11.maxFrameLatency` configuration keys.
