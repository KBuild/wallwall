# WALLWALL

[한국어](README.md) · [Requirements](Docs/REQUIREMENT.md) · [Disclaimer](Docs/DISCLAIMER.md) · [Third-party tools](Docs/THIRD_PARTY.md)

Scripts for rebuilding the owner-provided Windows `WallpaperEV` as a personal macOS Unity app and exporting MP4. The target is the **2026 에버리스 1주년 기념 광고** reward **「반응형 월페이퍼-TUS 작가님」**. Other wallpapers are not supported or guaranteed.

Developed with AI assistance (*vibe coding*).

**Before use:** read the [Disclaimer](Docs/DISCLAIMER.md) for ownership, license and redistribution conditions.

## Run

1. Prepare the tools and licenses in [Requirements](Docs/REQUIREMENT.md).
2. Place your authorized `WallPaper.exe` and `WallPaper_Data/` in `WallpaperEV/`.
3. From the repository root:

```sh
python3 Scripts/generate-port.py
Scripts/build-macos.sh
Scripts/export-video.sh
```

Output: `Builds/WALLWALL.mp4` — 1920×1080, 30 seconds, 30 FPS, no audio. Open it with a macOS video wallpaper app of your choice. No particular wallpaper app is required.

Keep the export window open without resizing or interacting with it. Export may take longer than the video duration. Existing MP4 files are not overwritten; set `WALLWALL_VIDEO_PATH` to another path. Set `WALLWALL_VIDEO_SECONDS` to change duration.

`--source` selects another input folder. `generate-port.py --force` replaces the generated `Port/` directory.

## Live desktop wallpaper (Unity app)

```sh
Scripts/run-wallpaper.sh
# Or open Builds/WALLWALL.app directly; desktop mode is the default.
# Normal window, without desktop placement:
WALLWALL_WINDOWED=1 Scripts/run-wallpaper.sh
```

The app places one interactive Unity window behind desktop icons. On other connected displays, the same process loops `Builds/WALLWALL.mp4` in a click-through desktop window. The WW menu shows the number of **MP4 fallback** displays. This video-only fallback has no live pointer reactions. Keep the app and MP4 together in `Builds/`.

Use **WW → Interactive Display** to choose and remember the screen with live reactions. Use **WW → Pointer Trigger** for hover or held-drag reactions on the Unity display, and the random-reaction menus for automatic playback. Hover follows the cursor over visible reaction regions without requiring app focus or a click; movement inside the same region preserves dwell. Hover needs no global event monitor; Drag monitors left-button down/up. A foreground-window check suppresses reactions where another app covers the pointer. For direct input, select **Interaction Mode**; Escape returns to wallpaper mode.

## Screen saver candidate

```sh
Scripts/build-saver.sh
cp -R Builds/WALLWALL.saver "$HOME/Library/Screen Savers/"
```

Select WALLWALL in System Settings → Wallpaper → Screen Saver. The native bundle contains the MP4 and requires no extra video player. Screen saver support is experimental and may not work in System Settings.

## Scope and license

- Animated lock screens are unsupported.
- New `Scripts/` code is [GPLv3](LICENSE). Wallpaper content and external tools retain their own rights and terms. Input, generated projects and builds are excluded from Git.
