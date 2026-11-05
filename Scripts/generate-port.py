#!/usr/bin/env python3
"""Reconstruct a local Unity project from an owner-provided WallpaperEV build."""

from __future__ import annotations

import argparse
import hashlib
import json
from pathlib import Path
import platform
import shutil
import socket
import subprocess
import sys
import tarfile
import tempfile
import time
from urllib.parse import urlencode
from urllib.request import Request, urlopen


ROOT = Path(__file__).resolve().parents[1]
ASSET_RIPPER_VERSION = "2.0.0"
ASSET_RIPPER_ARCHIVES = {
    "arm64": (
        "AssetRipper_mac_arm64.tar.xz",
        "237a6da404bf089c5e5c71a5a9a698c2ea580872292dfa5ce21e25fd1dbe9045",
    ),
    "x86_64": (
        "AssetRipper_mac_x64.tar.xz",
        "1b3836f135d16845cb57595fadff5739cbb86d28caaf621005b4301dba9b5a56",
    ),
}
SPINE_COMMIT = "14ac8d7e1ca6b86382e34607933e208dbbf286d2"
SPINE_SHADER_ROOT = (
    "https://raw.githubusercontent.com/EsotericSoftware/spine-runtimes/"
    + SPINE_COMMIT
    + "/spine-unity/Assets/Spine/Runtime/spine-unity/Shaders/"
)
SHADERS = {
    "Spine-Skeleton.shader": (
        "Shader/Spine_Skeleton.shader",
        "40527a2bb5998bc25db8f9918622e056304e4fddab4c05b9dde07eb6ef87ced0",
    ),
    "BlendModes/Spine-Skeleton-PMA-Multiply.shader": (
        "Shader/BlendModes/Spine_Blend Modes_Skeleton PMA Multiply.shader",
        "d9b7270dfae441e4d696aad93a9f1ce1af0f6b2abdeffa9e2a9801cc9500d201",
    ),
    "CGIncludes/Spine-Common.cginc": (
        "Shader/CGIncludes/Spine-Common.cginc",
        "6d7a655ceeef504d8cd2c3129844ab19ee5ca7a00f488c1d378699dfaca82c78",
    ),
    "CGIncludes/Spine-BlendModes-NormalPass.cginc": (
        "Shader/CGIncludes/Spine-BlendModes-NormalPass.cginc",
        "2b03c01a6548bc8a4422986e7b011fc9473c76207252738cc203e83f00886f3d",
    ),
    "CGIncludes/Spine-BlendModes-ShadowCasterPass.cginc": (
        "Shader/CGIncludes/Spine-BlendModes-ShadowCasterPass.cginc",
        "15901cc7d2310d9559911f363e12540b555dc84d6a27656ed5869172ada4896c",
    ),
}
UGUI_REFS = {
    "-619905303": ("76c392e42b5098c458856cdf6ecaaaa1", 1),  # EventSystem
    "-765806418": ("fe87c0e1cc204ed48ad3b37840f39efc", 5),  # Image
    "1301386320": ("dc42784cf147c0c48a680349fa168899", 1),  # GraphicRaycaster
    "1980459831": ("0cd44c1031e13a943bb63640046fad76", 1),  # CanvasScaler
    "1077351063": ("4f231c4fb786f3946a6b90b886c48677", 1),  # StandaloneInputModule
}


def note(message: str) -> None:
    print(f"[WALLWALL] {message}", flush=True)


def sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as source:
        for block in iter(lambda: source.read(1024 * 1024), b""):
            digest.update(block)
    return digest.hexdigest()


def download(url: str, destination: Path, expected_sha256: str) -> None:
    destination.parent.mkdir(parents=True, exist_ok=True)
    if destination.is_file() and sha256(destination) == expected_sha256:
        return
    temporary = destination.with_name(destination.name + ".download")
    temporary.unlink(missing_ok=True)
    note(f"Downloading {url}")
    with urlopen(Request(url, headers={"User-Agent": "WALLWALL-port-script"}), timeout=120) as response:
        with temporary.open("wb") as output:
            shutil.copyfileobj(response, output, 1024 * 1024)
    if sha256(temporary) != expected_sha256:
        temporary.unlink(missing_ok=True)
        raise RuntimeError(f"SHA-256 mismatch for {url}")
    temporary.replace(destination)


def asset_ripper_binary(explicit: Path | None) -> Path:
    if explicit:
        executable = explicit.expanduser().resolve()
        if not executable.is_file():
            raise FileNotFoundError(executable)
        return executable
    architecture = platform.machine()
    if architecture not in ASSET_RIPPER_ARCHIVES:
        raise RuntimeError(f"Unsupported macOS CPU architecture: {architecture}")
    archive_name, archive_hash = ASSET_RIPPER_ARCHIVES[architecture]
    archive = ROOT / ".tools" / "downloads" / archive_name
    url = (
        "https://github.com/AssetRipper/AssetRipper/releases/download/"
        f"{ASSET_RIPPER_VERSION}/{archive_name}"
    )
    download(url, archive, archive_hash)
    directory = ROOT / ".tools" / f"assetripper-{ASSET_RIPPER_VERSION}-{architecture}"
    candidates = list(directory.rglob("AssetRipper.GUI.Free")) if directory.exists() else []
    if not candidates:
        note(f"Extracting {archive.name}")
        directory.mkdir(parents=True, exist_ok=True)
        with tarfile.open(archive, "r:xz") as package:
            for member in package.getmembers():
                target = (directory / member.name).resolve()
                if not target.is_relative_to(directory.resolve()):
                    raise RuntimeError("Unsafe path in AssetRipper archive")
                if member.issym() or member.islnk():
                    raise RuntimeError("Unexpected link in AssetRipper archive")
            package.extractall(directory)
        candidates = list(directory.rglob("AssetRipper.GUI.Free"))
    if len(candidates) != 1:
        raise RuntimeError("Could not locate AssetRipper.GUI.Free in archive")
    executable = candidates[0]
    executable.chmod(executable.stat().st_mode | 0o100)
    return executable


def free_port() -> int:
    with socket.socket() as server:
        server.bind(("127.0.0.1", 0))
        return int(server.getsockname()[1])


def api_post(base: str, path: str, value: Path) -> None:
    data = urlencode({"path": str(value)}).encode("utf-8")
    request = Request(base + path, data=data, method="POST")
    with urlopen(request, timeout=900) as response:
        response.read(4096)


def export_unity_project(executable: Path, source: Path, destination: Path) -> Path:
    port = free_port()
    base = f"http://127.0.0.1:{port}"
    log_path = destination / "assetripper.log"
    with log_path.open("wb") as log:
        process = subprocess.Popen(
            [str(executable), "--headless", "--port", str(port)],
            cwd=executable.parent,
            stdout=log,
            stderr=subprocess.STDOUT,
        )
        try:
            for _ in range(120):
                if process.poll() is not None:
                    raise RuntimeError(f"AssetRipper exited early. See {log_path}")
                try:
                    with urlopen(base + "/openapi.json", timeout=1) as response:
                        if response.status == 200:
                            break
                except OSError:
                    time.sleep(0.5)
            else:
                raise RuntimeError(f"AssetRipper did not start. See {log_path}")
            note("AssetRipper: loading the Windows game folder")
            api_post(base, "/LoadFolder", source)
            note("AssetRipper: exporting the Unity project")
            api_post(base, "/Export/UnityProject", destination)
        finally:
            process.terminate()
            try:
                process.wait(timeout=15)
            except subprocess.TimeoutExpired:
                process.kill()
                process.wait()
    project = destination / "ExportedProject"
    if not (project / "Assets/Scenes/HYYN.unity").is_file():
        raise RuntimeError(f"HYYN scene was not recovered. See {log_path}")
    return project


def replace_exact(path: Path, old: str, new: str, count: int = 1) -> None:
    content = path.read_text(encoding="utf-8")
    actual = content.count(old)
    if actual != count:
        raise RuntimeError(f"{path}: expected {count} occurrences, found {actual}: {old[:70]}")
    path.write_text(content.replace(old, new), encoding="utf-8")


def patch_project(project: Path, uncompressed_atlas: bool) -> list[str]:
    changes: list[str] = []
    version = (project / "ProjectSettings/ProjectVersion.txt").read_text()
    if "6000.3.23f1" not in version:
        raise RuntimeError("Recovered project has a different Unity version")

    plugins = project / "Assets/Plugins"
    keep = {"spine-csharp.dll", "spine-unity.dll", "Unity.Postprocessing.Runtime.dll"}
    for dll in plugins.glob("*.dll"):
        if dll.name not in keep:
            dll.unlink()
            dll.with_name(dll.name + ".meta").unlink(missing_ok=True)
    changes.append("Removed duplicate Windows Player/Unity package DLLs")

    # The recovered VideoClickPlayer is not attached to the only scene and has
    # no prefab reference. It cannot participate in the supported build.
    video_click = project / "Assets/Scripts/Assembly-CSharp/VideoClickPlayer.cs"
    video_click_meta = video_click.with_name(video_click.name + ".meta")
    if video_click_meta.is_file():
        if "969b01a0dcac1e4784fd44e2c9b7d70b" not in video_click_meta.read_text():
            raise RuntimeError("Unexpected VideoClickPlayer GUID; review scene references")
        references = list((project / "Assets").rglob("*.unity")) + list((project / "Assets").rglob("*.prefab"))
        if any("969b01a0dcac1e4784fd44e2c9b7d70b" in path.read_text(encoding="utf-8")
               for path in references):
            raise RuntimeError("VideoClickPlayer is scene/prefab-referenced; do not remove")
        video_click.unlink(missing_ok=True)
        video_click_meta.unlink()
        changes.append("Omitted unreferenced recovered VideoClickPlayer")

    script = project / "Assets/Scripts/Assembly-CSharp/SpineClickSequencePlayer.cs"
    replace_exact(script, "private AnimationState state;", "private Spine.AnimationState state;")
    replace_exact(script, "pos = Input.mousePosition;", "pos = WallwallDesktop.PointerPosition;")
    replace_exact(
        script,
        "\t\tpos = WallwallDesktop.PointerPosition;\n\t\tdown = Input.GetMouseButtonDown(0);",
        "\t\tif (WallwallDesktop.TryGetWallpaperDragInput(out pos, out down, out held, out up)) return;\n"
        "\t\tpos = WallwallDesktop.PointerPosition;\n\t\tdown = Input.GetMouseButtonDown(0);",
    )
    changes.append("Qualified Spine.AnimationState for Unity 6 C# compilation")
    replace_exact(
        script,
        "public class SpineClickSequencePlayer : MonoBehaviour\n{",
        "public partial class SpineClickSequencePlayer : MonoBehaviour\n{\n"
        '\tprivate static readonly bool logInteractions = Array.IndexOf(Environment.GetCommandLineArgs(), "--wallwall-log-interactions") >= 0;',
    )
    replace_exact(
        script,
        "\t\t\toverlayEntry = state.SetAnimation(overlayTrackIndex, text, loop);",
        "\t\t\toverlayEntry = state.SetAnimation(overlayTrackIndex, text, loop);\n"
        '\t\t\tif (logInteractions) Debug.Log("[WALLWALL interaction] overlay=" + text + " track=" + overlayTrackIndex);',
    )
    replace_exact(
        script,
        "\t\t\tpointerActive = enableCursorBoneDrive && !isPlayingSet && activeArea != null;",
        "\t\t\tpointerActive = enableCursorBoneDrive && !isPlayingSet && activeArea != null;\n"
        '\t\t\tif (logInteractions) Debug.Log("[WALLWALL interaction] press pos=" + pos + " screen=" + Screen.width + "x" + Screen.height + " area=" + (activeArea == null ? "none" : activeArea.boneName) + " bone=" + (activeBone == null ? "missing" : "found") + " active=" + pointerActive);',
    )
    replace_exact(
        script,
        "\t\t\t\tpointerDragging = true;",
        "\t\t\t\tpointerDragging = true;\n"
        '\t\t\t\tif (logInteractions) Debug.Log("[WALLWALL interaction] drag area=" + activeArea.boneName + " delta=" + (pos - pointerDownScreen));\n'
        "\t\t\t\tTryPlayWallwallDragSequence(activeArea);",
    )
    replace_exact(
        script,
        "\t\telse if (up)\n\t\t{\n\t\t\tpointerActive = false;",
        "\t\telse if (up)\n\t\t{\n"
        '\t\t\tif (logInteractions) Debug.Log("[WALLWALL interaction] release area=" + (activeArea == null ? "none" : activeArea.boneName) + " dragged=" + hasDraggedThisPress + " offset=" + (activeArea == null ? Vector2.zero : areaOffsets[activeArea]));\n'
        "\t\t\tpointerActive = false;",
    )
    changes.append("Added opt-in Unity head-gesture diagnostics (--wallwall-log-interactions)")

    # Add WALLWALL-only behavior through a partial class. The recovered source
    # stays local; the Git-tracked template contains only new port code.
    replace_exact(
        script,
        "\t\tskeleton = skeletonComponent.Skeleton;\n\t\tCacheAreaBones();",
        "\t\tskeleton = skeletonComponent.Skeleton;\n\t\tInitializeWallwallExtras();\n\t\tCacheAreaBones();",
    )
    replace_exact(
        script,
        "\tprivate void Update()\n\t{\n\t\tUpdatePointerState();",
        "\tprivate void Update()\n\t{\n\t\tUpdateWallwallHover();\n\t\tUpdatePointerState();",
    )
    replace_exact(
        script,
        "\t\tisPlayingSet = false;\n\t}\n\n\tpublic void ResetToIdleAndFirstSet()",
        "\t\tisPlayingSet = false;\n\t\tAmbientSequenceCompleted();\n\t}\n\n\tpublic void ResetToIdleAndFirstSet()",
    )
    replace_exact(
        script,
        "\tprivate void HandleUpdateWorld(ISkeletonRenderer _)\n\t{",
        "\tprivate void HandleUpdateWorld(ISkeletonRenderer _)\n\t{\n\t\tKeepLeafBehindWhiteTail();",
    )
    replace_exact(
        script,
        "\t\tbool num = playOverlayWhileDragging && enableCursorBoneDrive && !isPlayingSet && pointerActive && pointerDragging;",
        "\t\tbool ambientHead = ambientOverlayArea != null && Time.realtimeSinceStartup < ambientOverlayEndsAt && !pointerActive && !isPlayingSet;\n"
        "\t\tif (!ambientHead) ambientOverlayArea = null;\n"
        "\t\tbool num = (playOverlayWhileDragging && enableCursorBoneDrive && !isPlayingSet && pointerActive && pointerDragging) || ambientHead;",
    )
    replace_exact(
        script,
        "\t\t\tif (activeArea != null && activeArea.useOverlay && !string.IsNullOrEmpty(activeArea.overlayAnimation))\n"
        "\t\t\t{\n"
        "\t\t\t\ttext = activeArea.overlayAnimation;\n"
        "\t\t\t\tnum2 = Mathf.Clamp01(activeArea.overlayAlpha);\n"
        "\t\t\t\tloop = activeArea.overlayLoop;",
        "\t\t\tAreaBinding overlayArea = ambientHead ? ambientOverlayArea : activeArea;\n"
        "\t\t\tif (overlayArea != null && overlayArea.useOverlay && !string.IsNullOrEmpty(overlayArea.overlayAnimation))\n"
        "\t\t\t{\n"
        "\t\t\t\ttext = overlayArea.overlayAnimation;\n"
        "\t\t\t\tnum2 = Mathf.Clamp01(overlayArea.overlayAlpha);\n"
        "\t\t\t\tloop = overlayArea.overlayLoop;",
    )
    replace_exact(
        script,
        "!state.GetTrack(0).Animation.Name.Equals(activeArea.overlayExceptionAnimation)",
        "!state.GetTrack(0).Animation.Name.Equals((ambientHead ? ambientOverlayArea : activeArea).overlayExceptionAnimation)",
    )
    replace_exact(
        script,
        "\t\tif (down)\n\t\t{\n\t\t\tactiveArea = FindAreaUnder(pos);",
        "\t\tif (down)\n\t\t{\n\t\t\tCancelAmbientInteraction();\n\t\t\tactiveArea = FindAreaUnder(pos);",
    )
    shutil.copy2(ROOT / "Scripts/templates/WallwallSpineExtras.cs",
                 project / "Assets/Scripts/Assembly-CSharp/WallwallSpineExtras.cs")
    shutil.copy2(ROOT / "Scripts/templates/WallwallAmbientInteraction.cs",
                 project / "Assets/Scripts/Assembly-CSharp/WallwallAmbientInteraction.cs")
    shutil.copy2(ROOT / "Scripts/templates/WallwallConsts.cs",
                 project / "Assets/Scripts/Assembly-CSharp/WallwallConsts.cs")
    changes.append("Layered BG_leaf behind YN tail; added ambient playback and desktop head hover")

    manifest = project / "Packages/manifest.json"
    packages = json.loads(manifest.read_text(encoding="utf-8"))
    packages["dependencies"]["com.unity.ugui"] = "2.0.0"
    packages["dependencies"] = dict(sorted(packages["dependencies"].items()))
    manifest.write_text(json.dumps(packages, indent=2) + "\n", encoding="utf-8")
    changes.append("Added Unity 6.3 built-in uGUI 2.0.0")

    scene = project / "Assets/Scenes/HYYN.unity"
    # AssetRipper exports PostProcessing shaders as single-pass dummy shaders.
    # Keep the volume data, but prevent this camera layer from blitting with
    # pass indices that those recovered shaders cannot provide.
    postprocess_layer = (
        "--- !u!114 &41\n"
        "MonoBehaviour:\n"
        "  m_ObjectHideFlags: 0\n"
        "  m_CorrespondingSourceObject: {fileID: 0}\n"
        "  m_PrefabInstance: {fileID: 0}\n"
        "  m_PrefabAsset: {fileID: 0}\n"
        "  m_GameObject: {fileID: 5}\n"
        "  m_Enabled: 1\n"
        "  m_EditorHideFlags: 0\n"
        "  m_Script: {fileID: -1529857597, guid: e161fae64b898bc22624d03ed611378f, type: 3}"
    )
    replace_exact(
        scene,
        postprocess_layer,
        postprocess_layer.replace("  m_Enabled: 1\n", "  m_Enabled: 0\n"),
    )
    changes.append(
        "Disabled recovered camera PostProcessLayer; antialiasing and postprocessing "
        "are unavailable until real shaders are restored"
    )
    for old_id, (guid, expected) in UGUI_REFS.items():
        old = (
            f"m_Script: {{fileID: {old_id}, "
            "guid: d3e719b59ab71ba3f6b398058c866280, type: 3}"
        )
        new = f"m_Script: {{fileID: 11500000, guid: {guid}, type: 3}}"
        replace_exact(scene, old, new, expected)
    changes.append("Remapped 9 uGUI components to Unity 6.3 source GUIDs")

    shader_dir = project / "Assets/Shader"
    old_multiply = shader_dir / "Spine_Blend Modes_Skeleton PMA Multiply.shader"
    new_multiply = shader_dir / "BlendModes/Spine_Blend Modes_Skeleton PMA Multiply.shader"
    new_multiply.parent.mkdir(parents=True, exist_ok=True)
    old_multiply.with_name(old_multiply.name + ".meta").replace(
        new_multiply.with_name(new_multiply.name + ".meta")
    )
    old_multiply.unlink()
    for upstream, (relative, checksum) in SHADERS.items():
        destination = project / "Assets" / relative
        download(SPINE_SHADER_ROOT + upstream, destination, checksum)
    changes.append(f"Restored Spine 4.3 transparent shaders at {SPINE_COMMIT}")

    # These pages use premultiplied alpha. Unity's straight-alpha color
    # dilation makes transparent RGB visible with the PMA blend function.
    for texture_name in ("skeleton.png", "skeleton_2.png"):
        texture_meta = project / "Assets/Texture2D" / (texture_name + ".meta")
        replace_exact(texture_meta, "alphaIsTransparency: 1", "alphaIsTransparency: 0")
    changes.append("Disabled transparent-color dilation on both PMA atlas pages (foreground stripe fix)")

    desktop_script = ROOT / "Scripts/templates/WallwallDesktop.cs"
    shutil.copy2(desktop_script, project / "Assets/Scripts/Assembly-CSharp/WallwallDesktop.cs")
    shutil.copy2(ROOT / "Scripts/templates/WallwallDesktopPolicy.cs",
                 project / "Assets/Scripts/Assembly-CSharp/WallwallDesktopPolicy.cs")
    shutil.copy2(ROOT / "Scripts/templates/WallwallVideoExport.cs",
                 project / "Assets/Scripts/Assembly-CSharp/WallwallVideoExport.cs")
    changes.append("Added macOS desktop host C# startup")

    if uncompressed_atlas:
        texture_meta = project / "Assets/Texture2D/skeleton.png.meta"
        replace_exact(texture_meta, "textureCompression: 2", "textureCompression: 0", 1)
        changes.append("Disabled compression for the main Spine atlas (glitch workaround)")

    changes.append("Unity will create PlayerSettings on first import; the build script names the app")
    return changes


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--source", type=Path, default=ROOT / "WallpaperEV")
    parser.add_argument("--output", type=Path, default=ROOT / "Port")
    parser.add_argument("--assetripper", type=Path, help="use an existing AssetRipper.GUI.Free")
    parser.add_argument("--force", action="store_true", help="replace an existing generated output")
    parser.add_argument(
        "--uncompressed-atlas",
        action="store_true",
        help="experimental workaround for transient black bars in the main atlas",
    )
    args = parser.parse_args()
    if sys.platform != "darwin":
        parser.error("The current scripts require macOS")
    source = args.source.expanduser().resolve()
    output = args.output.expanduser().resolve()
    if (output == ROOT or ROOT.is_relative_to(output) or
            output.is_relative_to(source) or source.is_relative_to(output)):
        parser.error("Output must be separate from the input and must not contain the repository")
    if not (source / "WallPaper.exe").is_file() or not (
        source / "WallPaper_Data/globalgamemanagers"
    ).is_file():
        parser.error("--source must be the root of the owner-provided WallpaperEV Windows build")
    if output.exists() and not args.force:
        parser.error(f"{output} exists; use --force to replace this generated directory")
    executable = asset_ripper_binary(args.assetripper)
    staging = output.with_name(output.name + ".new")
    if staging.exists():
        if not args.force:
            raise RuntimeError(f"Staging directory already exists: {staging}")
        shutil.rmtree(staging)
    with tempfile.TemporaryDirectory(prefix="wallwall-export-") as directory:
        temporary = Path(directory)
        exported = export_unity_project(executable, source, temporary)
        note("Copying the recovered project")
        shutil.copytree(exported, staging)
        changes = patch_project(staging, args.uncompressed_atlas)
        recovery_log = staging / "RECOVERY_LOG.md"
        recovery_log.write_text(
            "# WALLWALL recovery log\n\n"
            f"AssetRipper: {ASSET_RIPPER_VERSION}\n\n"
            f"Unity: 6000.3.23f1\n\n"
            "Applied changes:\n\n"
            + "".join(f"- {change}\n" for change in changes)
            + "\nOriginal input remains in the owner-provided WallpaperEV directory.\n",
            encoding="utf-8",
        )
    if output.exists():
        shutil.rmtree(output)
    staging.replace(output)
    note(f"Ready: {output}")
    note("Next: Scripts/build-macos.sh")
    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except Exception as error:
        print(f"[WALLWALL] Error: {error}", file=sys.stderr)
        raise SystemExit(1) from error
