#!/bin/sh
set -eu

script_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
repo_dir=$(CDPATH= cd -- "$script_dir/.." && pwd)
video="$repo_dir/Builds/WALLWALL.mp4"
bundle="$repo_dir/Builds/WALLWALL.saver"

if [ ! -s "$video" ]; then
    echo "Missing MP4: $video" >&2
    exit 1
fi

mkdir -p "$bundle/Contents/MacOS" "$bundle/Contents/Resources"
cp "$video" "$bundle/Contents/Resources/WALLWALL.mp4"
python3 - "$bundle/Contents/Info.plist" <<'PY'
from pathlib import Path
import plistlib
import sys

target = Path(sys.argv[1])
target.write_bytes(plistlib.dumps({
    "CFBundleIdentifier": "app.wallwall.saver",
    "CFBundleExecutable": "WALLWALL",
    "CFBundleName": "WALLWALL",
    "CFBundlePackageType": "BNDL",
    "CFBundleShortVersionString": "1.0",
    "CFBundleVersion": "1",
    "NSPrincipalClass": "WallwallSaverView",
}))
PY

xcrun clang++ -std=c++23 -fobjc-arc \
    -mmacosx-version-min=12.0 -arch arm64 -arch x86_64 \
    -bundle -framework AppKit -framework AVFoundation -framework ScreenSaver \
    "$script_dir/saver/WallwallSaverView.mm" -o "$bundle/Contents/MacOS/WALLWALL"
codesign --force --sign - "$bundle" >/dev/null
echo "Built: $bundle"
