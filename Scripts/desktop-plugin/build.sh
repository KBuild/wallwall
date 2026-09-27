#!/bin/sh
set -eu

script_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
repo_dir=$(CDPATH= cd -- "$script_dir/../.." && pwd)
output_dir=${1:-"$repo_dir/Port/Assets/Plugins/macOS"}
output_bundle="$output_dir/WallwallDesktop.bundle"
binary_dir="$output_bundle/Contents/MacOS"

mkdir -p "$binary_dir"
cat > "$output_bundle/Contents/Info.plist" <<'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
<key>CFBundleExecutable</key><string>WallwallDesktop</string>
<key>CFBundleIdentifier</key><string>app.wallwall.desktop-plugin</string>
<key>CFBundlePackageType</key><string>BNDL</string>
<key>CFBundleVersion</key><string>1</string>
</dict></plist>
EOF
xcrun clang++ -std=c++23 -fobjc-arc -fvisibility=hidden \
    -mmacosx-version-min=12.0 -arch arm64 -arch x86_64 \
    -bundle -framework AppKit -framework CoreGraphics -framework AVFoundation \
    "$script_dir/WallwallDesktop.mm" "$script_dir/WallwallSettings.mm" \
    "$script_dir/WallwallPointer.mm" "$script_dir/WallwallFallback.mm" \
    -o "$binary_dir/WallwallDesktop"
echo "$output_bundle"
