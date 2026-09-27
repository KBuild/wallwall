# Third-party tools and components

Dependencies and their terms are listed here. Installation requirements are in [REQUIREMENT.md](REQUIREMENT.md); project responsibilities are in [DISCLAIMER.md](DISCLAIMER.md).

| Dependency | When needed |
| --- | --- |
| Python, AssetRipper | Recover and generate `Port/` |
| Unity Editor, Apple command-line tools/SDK | Build the macOS app |
| Recovered Spine DLLs, pinned Spine shaders, Unity runtime/uGUI | Generated project and live app |
| FFmpeg with libx264 | MP4 export only; not needed to run the live app |
| Unity Hub | Editor installation/management; not invoked by build scripts |

No external wallpaper host or replacement Web/Metal renderer is required by the current scripts. Apple AppKit and CoreGraphics are system frameworks used by the desktop plug-in.

## Recovery and build

- **Unity Hub and Unity Editor 6000.3.23f1** (changeset `09d2ecc7fb28`, with macOS Standalone Support): used to build the generated project and export video frames. Unity's own license and package terms apply; users must sign in and activate any required entitlement themselves. The generated app includes Unity runtime components, and `com.unity.ugui` 2.0.0 is declared in the local `Port/Packages/manifest.json`. [Editor release](https://unity.com/releases/editor/whats-new/6000.3.23f1), [Hub CLI](https://docs.unity.com/en-us/hub/use-hub-cli), [Unity legal terms](https://unity.com/legal).
- **AssetRipper Free 2.0.0**: `Scripts/generate-port.py` downloads the official macOS release into `.tools/` and checks pinned SHA-256 hashes in the script. **GPLv3**, as stated by the [2.0.0 license](https://raw.githubusercontent.com/AssetRipper/AssetRipper/2.0.0/LICENSE.md); its own [credits](https://assetripper.github.io/AssetRipper/articles/Credits.html) cover additional dependencies. AssetRipper is a separate tool, not copied into `Scripts/`. [Release](https://github.com/AssetRipper/AssetRipper/releases/tag/2.0.0).
- **Python 3**: standard-library-only recovery orchestration in `Scripts/generate-port.py`. Python comes from the user's installation and retains that distribution's terms. [Python license](https://docs.python.org/3/license.html).
- **Xcode command-line tools**: Apple `xcrun clang++ -std=c++23` compiles the macOS desktop plug-in. Apple developer tooling and SDK terms apply. [Xcode](https://developer.apple.com/xcode/), [Apple agreements](https://developer.apple.com/support/terms/).

## Retained in the local generated project

- **Spine Runtime 4.3**: the owner's Windows build contains `spine-csharp.dll` and `spine-unity.dll`; recovery keeps these DLLs in the ignored `Port/` project. The generator fetches Spine Unity shader/include files at a pinned commit and checks hashes in `Scripts/generate-port.py`. These files replace AssetRipper's dummy shader output in `Port/`, not repository source. The [Spine Runtimes license](https://github.com/EsotericSoftware/spine-runtimes/blob/4.3/LICENSE) and relevant [Spine Editor license](https://esotericsoftware.com/spine-editor-license) set their own integration conditions. Entitlement for a new native integration or distribution has **not** been established. Keep upstream copyright and license notices with any legally distributable copy; do not infer rights from the presence of DLLs in the supplied build.
- **Recovered Unity content and managed assemblies**: AssetRipper's output includes the owner's scene, artwork, shaders, and assembly-derived C# in `Port/`. These are local recovery artifacts, not new WALLWALL GPL source. Original provenance and redistribution rights must be checked with the relevant owners; generated output is excluded from Git.

## Video

- **FFmpeg**: encodes Unity-rendered frames into H.264 MP4. FFmpeg is separately installed, invoked as an external executable, and not bundled with WALLWALL. Its license obligations depend on the installed build and enabled codecs. [Official licensing guidance](https://ffmpeg.org/legal.html).
