# Requirements

## Local inputs and tools

| Item | Requirement | Installation / source |
| --- | --- | --- |
| Input | A copy you are authorized to use of the `WallpaperEV` Windows build from **2026 에버리스 1주년 기념 광고 / 반응형 월페이퍼-TUS 작가님**, with `WallPaper.exe` and `WallPaper_Data/` in `WallpaperEV/`. | Obtain it through the original reward channel. This repository does not supply it. |
| macOS | An Apple Silicon or Intel Mac. | [Unity 6.3 system requirements](https://docs.unity.com/en-us/engine/6000.3/manual/get-started/install-and-upgrade/getting-started-installing-unity/system-requirements) |
| Python | Python 3.10 or newer, with standard-library `lzma` support. | Your own Python installation. |
| FFmpeg | `ffmpeg` executable for MP4 export. Install and review its terms independently. | Your own FFmpeg installation; `WALLWALL_FFMPEG` may name a different executable. |
| Xcode tools | `xcrun clang++`, for the GPL macOS native plug-in and `.saver` compiled by the build scripts. | `xcode-select --install` |
| Unity | Editor **6000.3.23f1**, with macOS Standalone Support and a license activated for the installer. | [Unity release](https://unity.com/releases/editor/whats-new/6000.3.23f1) and [Hub CLI instructions](https://docs.unity.com/en-us/hub/use-hub-cli) |
| AssetRipper | 2.0.0. `Scripts/generate-port.py` can download the official macOS archive and verify SHA-256, or use `--assetripper /path/to/AssetRipper.GUI.Free`. | [Official releases](https://github.com/AssetRipper/AssetRipper/releases/tag/2.0.0) |
| Spine shaders | 4.3 source files downloaded at a pinned commit and SHA-256 checked by the generator. Internet access is required for a fresh generation. | [Spine Runtime source](https://github.com/EsotericSoftware/spine-runtimes/tree/4.3/spine-unity/Assets/Spine/Runtime/spine-unity/Shaders) |

If Unity Hub is installed and signed in, an Apple Silicon install can be started with:

```sh
'/Applications/Unity Hub.app/Contents/MacOS/Unity Hub' -- --headless install --version 6000.3.23f1 --changeset 09d2ecc7fb28 --architecture arm64
```

Use `--architecture x86_64` for an Intel Mac. The scripts do not sign in, activate a license, or accept Unity terms on the installer's behalf. The exact `6000.3.23f1` version is part of Unity **6.3 LTS** and matches the input build. Later 6.3 patches and 6.6 might work after validation, but the generator currently checks the original version to keep failures attributable to reconstruction rather than an Editor upgrade.

## Configuration

Execution commands are maintained in [README.en.md](../README.en.md). Tool provenance and licenses are maintained in [THIRD_PARTY.md](THIRD_PARTY.md).

| Variable | Purpose |
| --- | --- |
| `UNITY_EDITOR` | Unity executable path |
| `WALLWALL_PORT_DIR` | Generated project location |
| `WALLWALL_APP_PATH` | Built app location |
| `WALLWALL_BUILD_LOG`, `WALLWALL_PLAYER_LOG`, `WALLWALL_VIDEO_LOG` | Log destinations |
| `WALLWALL_VIDEO_PATH`, `WALLWALL_VIDEO_SECONDS`, `WALLWALL_VIDEO_FPS` | Video destination, duration and frame rate |
| `WALLWALL_FFMPEG` | Installed FFmpeg executable |
| `WALLWALL_WINDOWED=1` | Run without desktop placement |

Do not run two generations at once. Fresh generation requires network access for the pinned downloads.
