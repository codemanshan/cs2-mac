# Sources and runtime pins

Checked on October 14, 2026. This repository contains the project's own scripts and documentation. Runtime downloads remain separate upstream components with their own licenses.

## Pinned downloads

The sizes and SHA-256 values below match the `digest` fields returned by the official repositories' GitHub release API. The downloaded archives were independently checked against those pins during development. Do not replace a pin with a moving `latest` URL.

| Component | Official download | Bytes | SHA-256 |
| --- | --- | ---: | --- |
| Sikarugir Template 1.0.22 | [Template-1.0.22.tar.xz](https://github.com/Sikarugir-App/Template/releases/download/v1.0/Template-1.0.22.tar.xz) | 96,025,412 | `02a8e9e1140121128188bce5380b5adf187fd6084fd2cb266e22cc8ab50e5155` |
| Wine Sikarugir 11.0_1 | [WS12WineSikarugir11.0_1.tar.xz](https://github.com/Sikarugir-App/Engines/releases/download/v1.0/WS12WineSikarugir11.0_1.tar.xz) | 167,322,744 | `67e29fb3d74f363af39c69ba11f9b13a79812c5db07cf4748672658e4a200a0e` |

Metadata: [Template release](https://github.com/Sikarugir-App/Template/releases/tag/v1.0), [Template asset API](https://api.github.com/repos/Sikarugir-App/Template/releases/assets/640377160), [engine release](https://github.com/Sikarugir-App/Engines/releases/tag/v1.0), [engine asset API](https://api.github.com/repos/Sikarugir-App/Engines/releases/assets/602173037).

The verified Template 1.0.22 archive contains DXMT version **`v0.80-244-g7c8dee1`**, corresponding to source revision [`7c8dee1c2d73415301ceb7d1fa810861cef4cd67`](https://github.com/3Shain/dxmt/tree/7c8dee1c2d73415301ceb7d1fa810861cef4cd67). DXMT is not fetched as a separate, interchangeable binary. The release page's abbreviated history does not enumerate every newer template; the embedded version file is the basis for this renderer identification.

Windows Steam's bootstrap installer is provided by [Valve](https://cdn.akamai.steamstatic.com/client/installer/SteamSetup.exe). On the check date, that mutable vendor URL returned 2,380,800 bytes with SHA-256 `7d3654531c32d941b8cae81c4137fc542172bfa9635f169cb392f245a0a12bcb`. This is an observed pin, not a separately published Valve checksum. A changed download needs review and a deliberate pin update. Steam and CS2 subsequently update through Valve; the runtime pins do not freeze those services or the game.

## Licenses and distribution boundaries

| Component | Primary license source | Repository policy |
| --- | --- | --- |
| This kit's original code and documentation | Repository `LICENSE` | MIT applies to this project's work, not upstream payloads. |
| Wine | [Wine license](https://github.com/Sikarugir-App/wine/blob/master/LICENSE) | LGPL 2.1 or later. Keep its notices and upstream source references. |
| Pinned DXMT | [License at the pinned revision](https://github.com/3Shain/dxmt/blob/7c8dee1c2d73415301ceb7d1fa810861cef4cd67/LICENSE) | LGPL 2.1 or later. The older v0.80 release's MIT status must not be applied to this later revision. |
| Sikarugir Configure | [Upstream component list](https://github.com/Sikarugir-App/Sikarugir#readme), [FOSS sources and license](https://github.com/Sikarugir-App/Sikarugir-foss-sources) | Upstream identifies Configure as LGPL 2.1. |
| Sikarugir Launcher and Creator | [Upstream component list](https://github.com/Sikarugir-App/Sikarugir#readme) | Upstream explicitly excludes these newer components from its LGPL component list. Do not assume they are MIT or LGPL. |
| D3DMetal / Game Porting Toolkit components in the template | [Apple license supplied by upstream](https://github.com/Sikarugir-App/Sikarugir/blob/main/D3DMetal/4.0/License.pdf) | Separate Apple terms apply even though DXMT is the selected renderer. |
| Steam and CS2 | [Steam Subscriber Agreement](https://store.steampowered.com/subscriber_agreement/), [CS2 store page](https://store.steampowered.com/app/730/) | Download through Valve; do not include client accounts, session data, or game content in this repository. |

Apple's supplied license limits internal use to developing, testing, or evaluating games on Apple-branded products. It allows non-commercial distribution subject to its conditions, including restrictions on separating components and requirements to retain notices. It is not a general MIT-style license. Selecting DXMT does not relicense the other files in a downloaded template.

This project publishes download instructions and original installer code, not upstream archives, repackaged runtime releases, or generated wrappers. Fetching an upstream component does not transfer its copyright or remove its license obligations. Any future redistribution of binaries or copied upstream source requires a component-by-component review and the corresponding notices and source obligations. No broad redistribution clearance is claimed for the complete template.

## Technical and policy references

- [Sikarugir requirements and supported renderers](https://github.com/Sikarugir-App/Sikarugir#readme).
- [DXMT system and runtime requirements](https://github.com/3Shain/dxmt/wiki/Device-System-Runtime-Specifications): macOS 14 minimum, macOS 15 recommended; this is separate from the wrapper's 14.6 minimum.
- [Creator cask post-install behavior](https://github.com/Sikarugir-App/homebrew-sikarugir/blob/main/Casks/sikarugir.rb). The kit does not automate its quarantine-removal step.
- [Apple Rosetta instructions](https://support.apple.com/en-us/102527).
- [Pinned DXMT configuration discovery](https://github.com/3Shain/dxmt/blob/7c8dee1c2d73415301ceb7d1fa810861cef4cd67/src/util/config/config.cpp#L350), [pacing configuration](https://github.com/3Shain/dxmt/blob/7c8dee1c2d73415301ceb7d1fa810861cef4cd67/docs/CUSTOMIZATION.md), [presentation formula](https://github.com/3Shain/dxmt/blob/7c8dee1c2d73415301ceb7d1fa810861cef4cd67/src/d3d11/d3d11_swapchain.cpp#L768), [layer setup](https://github.com/3Shain/dxmt/blob/7c8dee1c2d73415301ceb7d1fa810861cef4cd67/src/dxmt/dxmt_presenter.cpp#L16).
- [Apple Metal performance metrics](https://developer.apple.com/documentation/xcode/understanding-metal-performance-hud-metrics), [measurement and logging](https://developer.apple.com/documentation/xcode/monitoring-your-metal-apps-graphics-performance), [macOS 27 trace tools](https://developer.apple.com/videos/play/wwdc2026/388/).
- [Valve VAC policy](https://help.steampowered.com/en/faqs/view/571A-97DA-70E9-FF74), [FACEIT Anti-cheat platform requirements](https://support.faceit.com/hc/en-us/articles/9394666828188-What-is-FACEIT-Anti-cheat-and-how-does-it-work).

Links to current upstream documentation may change. The archive hashes and pinned DXMT source revision identify the specific runtime examined here.
