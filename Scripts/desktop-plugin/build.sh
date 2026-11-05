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
stage=$(mktemp -d "${TMPDIR:-/tmp}/wallwall-native.XXXXXX")
trap 'rm -rf "$stage"' EXIT
trap 'exit 130' INT
trap 'exit 143' HUP TERM
swift_bin=$(xcrun --find swiftc)
swift_lib=$(dirname "$swift_bin")/../lib/swift/macosx
for arch in arm64 x86_64; do
    (cd "$stage"; xcrun swiftc -O -whole-module-optimization -parse-as-library -emit-object -module-name WallwallDesktop \
        -emit-objc-header-path "$stage/WallwallDesktop-Swift.h" \
        -target "$arch-apple-macosx12.0" -module-cache-path "$stage/cache" \
        "$script_dir/WallwallSettings.swift" "$script_dir/WallwallDisplaySelection.swift" "$script_dir/WallwallDragState.swift" "$script_dir/WallwallRenderPolicy.swift" \
        "$script_dir/WallwallPointer.swift" "$script_dir/WallwallFallback.swift" "$script_dir/WallwallDesktopHost.swift" -o "$stage/settings-$arch.o")
    xcrun clang -O2 -fobjc-arc -fvisibility=hidden \
        -mmacosx-version-min=12.0 -arch "$arch" \
        -bundle -framework AppKit -framework CoreGraphics -framework AVFoundation \
        -I "$stage" -L "$swift_lib" -Wl,-rpath,/usr/lib/swift \
        "$script_dir/WallwallBridge.m" "$stage/settings-$arch.o" \
        -o "$stage/plugin-$arch"
done
xcrun lipo -create "$stage/plugin-arm64" "$stage/plugin-x86_64" -output "$stage/WallwallDesktop"
mv "$stage/WallwallDesktop" "$binary_dir/WallwallDesktop"
echo "$output_bundle"
